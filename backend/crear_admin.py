# carolina/backend/crear_admin.py
"""
Script de inicialización de la base de datos.

Se ejecuta UNA sola vez después de crear la base de datos (o después de
recrearla desde cero, por ejemplo tras una actualización de PostgreSQL):

    cd backend
    python crear_admin.py

Qué hace:
  1. Crea las tablas que falten (db.create_all() — nunca borra ni modifica
     tablas existentes).
  2. Crea los 3 roles del sistema (admin, vendedor, almacenero) con sus
     permisos, si no existen todavía.
  3. Crea un usuario administrador inicial, si todavía no hay ninguno,
     para poder iniciar sesión por primera vez.

Es seguro ejecutarlo varias veces: si los roles o el admin ya existen,
no los vuelve a crear ni los duplica.
"""
import getpass
import re
import sys

import bcrypt

from app import crear_app
from extensions import db
from modelos.rol import Rol
from modelos.usuario import Usuario
from utilidades.permisos import PERMISOS_ROL

REGEX_USUARIO = re.compile(r'^[a-z0-9._]{3,30}$')


def crear_roles():
    creados = []
    for nombre, permisos in PERMISOS_ROL.items():
        rol = Rol.query.filter_by(nombre=nombre).first()
        if not rol:
            rol = Rol(nombre=nombre, permisos=permisos)
            db.session.add(rol)
            creados.append(nombre)
    if creados:
        db.session.commit()
        print(f'✔ Roles creados: {", ".join(creados)}')
    else:
        print('• Los roles ya existían, no se modificó nada.')


def pedir_nombre_usuario(valor_por_defecto='admin'):
    while True:
        entrada = input(
            f'Nombre de usuario del administrador [{valor_por_defecto}]: '
        ).strip().lower()
        nombre_usuario = entrada or valor_por_defecto
        if REGEX_USUARIO.match(nombre_usuario):
            return nombre_usuario
        print('  ✗ Debe tener 3 a 30 caracteres: solo minúsculas, números, '
              'punto o guión bajo.')


def pedir_password():
    while True:
        pw = getpass.getpass('Contraseña del administrador (mínimo 8 caracteres): ')
        if len(pw) < 8:
            print('  ✗ Mínimo 8 caracteres.')
            continue
        pw2 = getpass.getpass('Confirma la contraseña: ')
        if pw != pw2:
            print('  ✗ Las contraseñas no coinciden.')
            continue
        return pw


def crear_admin():
    rol_admin = Rol.query.filter_by(nombre='admin').first()
    if not rol_admin:
        print('✗ No existe el rol "admin". Ejecuta crear_roles() primero.')
        sys.exit(1)

    if Usuario.query.filter_by(rol_id=rol_admin.id).first():
        print('• Ya existe al menos un usuario administrador. No se creó ninguno.')
        return

    print('\nNo hay ningún usuario administrador todavía. Vamos a crear uno:')
    nombre_usuario = pedir_nombre_usuario()

    if Usuario.query.filter_by(nombre_usuario=nombre_usuario).first():
        print(f'✗ El nombre de usuario "{nombre_usuario}" ya está en uso '
              '(pertenece a otro usuario, no administrador). Aborta y '
              'vuelve a ejecutar el script con otro nombre.')
        sys.exit(1)

    password = pedir_password()
    hash_pw = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt(12)).decode('utf-8')

    admin = Usuario(
        nombre='Administrador',
        apellido_paterno='Sistema',
        apellido_materno=None,
        nombre_usuario=nombre_usuario,
        password_hash=hash_pw,
        rol_id=rol_admin.id,
        activo=True,
    )
    db.session.add(admin)
    db.session.commit()
    print(f'✔ Usuario administrador "{nombre_usuario}" creado correctamente.')


if __name__ == '__main__':
    app = crear_app()
    with app.app_context():
        print('Creando tablas que falten (no se borra ni modifica nada existente)...')
        db.create_all()
        print('✔ Tablas listas.\n')

        crear_roles()
        crear_admin()

        print('\nListo. Ya puedes iniciar sesión en el sistema con tu '
              'nombre de usuario y contraseña.')
