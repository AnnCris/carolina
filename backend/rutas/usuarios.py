# carolina/backend/rutas/usuarios.py
from flask import Blueprint, request, jsonify, session, current_app
from extensions import db
from modelos.usuario import Usuario
from utilidades.permisos import requiere_permiso
from rutas.auth import REGEX_USUARIO
import bcrypt, uuid, os

bp_usuarios = Blueprint('usuarios', __name__)

@bp_usuarios.route('/usuarios', methods=['GET'])
@requiere_permiso('todo')
def listar():
    usuarios = Usuario.query.order_by(Usuario.id.asc()).all()
    return jsonify([u.to_dict() for u in usuarios])

@bp_usuarios.route('/usuarios/<int:id>', methods=['GET'])
@requiere_permiso('todo')
def obtener(id):
    u = Usuario.query.get_or_404(id)
    return jsonify(u.to_dict())

@bp_usuarios.route('/usuarios', methods=['POST'])
@requiere_permiso('todo')
def crear():
    from modelos.rol import Rol
    datos = request.get_json()
    errores = {}

    nombre = (datos.get('nombre') or '').strip()
    apellido_paterno = (datos.get('apellido_paterno') or '').strip()
    nombre_usuario = (datos.get('nombre_usuario') or '').strip().lower()
    password = datos.get('password') or ''

    if len(nombre) < 2:
        errores['nombre'] = 'Mínimo 2 caracteres'
    if len(apellido_paterno) < 2:
        errores['apellido_paterno'] = 'El apellido paterno es requerido'
    if not REGEX_USUARIO.match(nombre_usuario):
        errores['nombre_usuario'] = ('3 a 30 caracteres: solo letras minúsculas, '
                                      'números, punto o guión bajo')
    if len(password) < 8:
        errores['password'] = 'Mínimo 8 caracteres'
    if not datos.get('rol_id'):
        errores['rol_id'] = 'El rol es requerido'
    if errores:
        return jsonify({'errores': errores}), 422

    if Usuario.query.filter_by(nombre_usuario=nombre_usuario).first():
        return jsonify({'errores': {'nombre_usuario': 'Este nombre de usuario ya está en uso'}}), 422

    hash_pw = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')
    u = Usuario(
        nombre=nombre,
        apellido_paterno=apellido_paterno,
        apellido_materno=(datos.get('apellido_materno') or '').strip() or None,
        nombre_usuario=nombre_usuario,
        password_hash=hash_pw,
        rol_id=datos['rol_id'],
        activo=True
    )
    db.session.add(u)
    db.session.commit()
    return jsonify(u.to_dict()), 201

@bp_usuarios.route('/usuarios/<int:id>', methods=['PUT'])
@requiere_permiso('todo')
def actualizar(id):
    u = Usuario.query.get_or_404(id)
    datos = request.get_json()
    errores = {}

    if 'nombre' in datos and len((datos['nombre'] or '').strip()) < 2:
        errores['nombre'] = 'Mínimo 2 caracteres'
    if 'apellido_paterno' in datos and len((datos['apellido_paterno'] or '').strip()) < 2:
        errores['apellido_paterno'] = 'Mínimo 2 caracteres'
    if 'nombre_usuario' in datos:
        nu = (datos['nombre_usuario'] or '').strip().lower()
        if not REGEX_USUARIO.match(nu):
            errores['nombre_usuario'] = ('3 a 30 caracteres: solo letras minúsculas, '
                                          'números, punto o guión bajo')
        elif Usuario.query.filter(Usuario.nombre_usuario == nu, Usuario.id != u.id).first():
            errores['nombre_usuario'] = 'Este nombre de usuario ya está en uso'
    if errores:
        return jsonify({'errores': errores}), 422

    u.nombre = (datos.get('nombre') or u.nombre).strip()
    u.apellido_paterno = (datos.get('apellido_paterno') or u.apellido_paterno).strip()
    u.apellido_materno = datos.get('apellido_materno', u.apellido_materno)
    if 'nombre_usuario' in datos:
        u.nombre_usuario = (datos['nombre_usuario'] or '').strip().lower()
    u.rol_id = datos.get('rol_id', u.rol_id)
    u.activo = datos.get('activo', u.activo)

    if datos.get('password'):
        if len(datos['password']) < 8:
            return jsonify({'errores': {'password': 'Mínimo 8 caracteres'}}), 422
        u.password_hash = bcrypt.hashpw(
            datos['password'].encode('utf-8'), bcrypt.gensalt()).decode('utf-8')

    db.session.commit()
    return jsonify(u.to_dict())

@bp_usuarios.route('/usuarios/<int:id>', methods=['DELETE'])
@requiere_permiso('todo')
def eliminar(id):
    u = Usuario.query.get_or_404(id)
    db.session.delete(u)
    db.session.commit()
    return jsonify({'mensaje': 'Usuario eliminado permanentemente'})

@bp_usuarios.route('/usuarios/<int:id>/foto', methods=['POST'])
@requiere_permiso('todo')
def subir_foto(id):
    u = Usuario.query.get_or_404(id)
    if 'foto' not in request.files:
        return jsonify({'error': 'No se envió imagen'}), 422
    archivo = request.files['foto']
    ext = archivo.filename.rsplit('.', 1)[-1].lower()
    if ext not in current_app.config['ALLOWED_EXTENSIONS']:
        return jsonify({'error': 'Formato no permitido'}), 422
    nombre_archivo = f"usuario_{uuid.uuid4().hex}.{ext}"
    archivo.save(os.path.join(current_app.config['UPLOAD_FOLDER'], nombre_archivo))
    u.foto = nombre_archivo
    db.session.commit()
    return jsonify({'foto': f'/api/subidas/{nombre_archivo}'})

from modelos.rol import Rol

@bp_usuarios.route('/roles', methods=['GET'])
def listar_roles():
    roles = Rol.query.all()
    return jsonify([r.to_dict() for r in roles])