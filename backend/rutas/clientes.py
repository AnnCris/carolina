# carolina/backend/rutas/clientes.py
from flask import Blueprint, request, jsonify
from extensions import db
from modelos.cliente import Cliente
from utilidades.permisos import requiere_permiso
 
bp_clientes = Blueprint('clientes', __name__)
 
@bp_clientes.route('/clientes', methods=['GET'])
@requiere_permiso('clientes')
def listar():
    # Devuelve todos: activos e inactivos (el filtro lo hace Flutter)
    clientes = Cliente.query.order_by(Cliente.id.asc()).all()
    return jsonify([c.to_dict() for c in clientes])
 
 
@bp_clientes.route('/clientes/<int:id>', methods=['GET'])
@requiere_permiso('clientes')
def obtener(id):
    c = Cliente.query.get_or_404(id)
    return jsonify(c.to_dict())
 
 
@bp_clientes.route('/clientes', methods=['POST'])
@requiere_permiso('clientes')
def crear():
    datos = request.get_json() or {}
    errores = {}
 
    nombre           = (datos.get('nombre')           or '').strip()
    apellido_paterno = (datos.get('apellido_paterno') or '').strip()
    apellido_materno = (datos.get('apellido_materno') or '').strip()
    ci_nit           = (datos.get('ci_nit')           or '').strip()
    telefono         = (datos.get('telefono')         or '').strip()
    email            = (datos.get('email')            or '').strip().lower()
    direccion        = (datos.get('direccion')        or '').strip()
 
    if len(nombre) < 2:
        errores['nombre'] = 'El nombre es requerido (mínimo 2 caracteres)'
    if len(apellido_paterno) < 2:
        errores['apellido_paterno'] = 'El apellido paterno es requerido'
    if email and ('@' not in email or '.' not in email):
        errores['email'] = 'Correo inválido'
    if telefono and len(telefono) < 7:
        errores['telefono'] = 'Teléfono inválido (mínimo 7 dígitos)'
    if errores:
        return jsonify({'errores': errores}), 422
 
    c = Cliente(
        nombre           = nombre,
        apellido_paterno = apellido_paterno or None,
        apellido_materno = apellido_materno or None,
        ci_nit           = ci_nit     or None,
        telefono         = telefono   or None,
        email            = email      or None,
        direccion        = direccion  or None,
        activo           = True,
    )
    db.session.add(c)
    db.session.commit()
    return jsonify(c.to_dict()), 201
 
 
@bp_clientes.route('/clientes/<int:id>', methods=['PUT'])
@requiere_permiso('clientes')
def actualizar(id):
    c     = Cliente.query.get_or_404(id)
    datos = request.get_json() or {}
    errores = {}
 
    nombre           = (datos.get('nombre')           or '').strip()
    apellido_paterno = (datos.get('apellido_paterno') or '').strip()
    email            = (datos.get('email')            or '').strip().lower()
    telefono         = (datos.get('telefono')         or '').strip()
 
    if nombre and len(nombre) < 2:
        errores['nombre'] = 'Mínimo 2 caracteres'
    if apellido_paterno and len(apellido_paterno) < 2:
        errores['apellido_paterno'] = 'Mínimo 2 caracteres'
    if email and ('@' not in email or '.' not in email):
        errores['email'] = 'Correo inválido'
    if telefono and len(telefono) < 7:
        errores['telefono'] = 'Mínimo 7 dígitos'
    if errores:
        return jsonify({'errores': errores}), 422
 
    if nombre:           c.nombre           = nombre
    if apellido_paterno: c.apellido_paterno = apellido_paterno
    if 'apellido_materno' in datos:
        c.apellido_materno = (datos['apellido_materno'] or '').strip() or None
    if 'ci_nit'    in datos: c.ci_nit    = (datos['ci_nit']    or '').strip() or None
    if 'telefono'  in datos: c.telefono  = telefono or None
    if 'email'     in datos: c.email     = email    or None
    if 'direccion' in datos: c.direccion = (datos['direccion'] or '').strip() or None
    if 'activo'    in datos: c.activo    = datos['activo']
 
    db.session.commit()
    return jsonify(c.to_dict())
 
 
@bp_clientes.route('/clientes/<int:id>', methods=['DELETE'])
@requiere_permiso('clientes')
def eliminar(id):
    c = Cliente.query.get_or_404(id)
    db.session.delete(c)
    db.session.commit()
    return jsonify({'mensaje': 'Cliente eliminado permanentemente'})