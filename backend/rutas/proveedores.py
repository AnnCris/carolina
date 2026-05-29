from flask import Blueprint, request, jsonify
from extensions import db
from modelos.proveedor import Proveedor
from utilidades.permisos import requiere_permiso
 
bp_proveedores = Blueprint('proveedores', __name__)
 
@bp_proveedores.route('/proveedores', methods=['GET'])
@requiere_permiso('proveedores')
def listar():
    proveedores = Proveedor.query.order_by(Proveedor.id.asc()).all()
    return jsonify([p.to_dict() for p in proveedores])
 
 
@bp_proveedores.route('/proveedores/<int:id>', methods=['GET'])
@requiere_permiso('proveedores')
def obtener(id):
    p = Proveedor.query.get_or_404(id)
    return jsonify(p.to_dict())
 
 
@bp_proveedores.route('/proveedores', methods=['POST'])
@requiere_permiso('proveedores')
def crear():
    datos = request.get_json() or {}
    errores = {}
 
    nombre           = (datos.get('nombre')           or '').strip()
    apellido_paterno = (datos.get('apellido_paterno') or '').strip()
    apellido_materno = (datos.get('apellido_materno') or '').strip()
    nit              = (datos.get('nit')              or '').strip()
    telefono         = (datos.get('telefono')         or '').strip()
    email            = (datos.get('email')            or '').strip().lower()
    direccion        = (datos.get('direccion')        or '').strip()
    contacto         = (datos.get('contacto')         or '').strip()
 
    if len(nombre) < 2:
        errores['nombre'] = 'El nombre es requerido (mínimo 2 caracteres)'
    if len(apellido_paterno) < 2:
        errores['apellido_paterno'] = 'El apellido paterno es requerido'
    if email and ('@' not in email or '.' not in email):
        errores['email'] = 'Correo inválido'
    if telefono and len(telefono) < 7:
        errores['telefono'] = 'Teléfono inválido (mínimo 7 dígitos)'
    if nit and len(nit) < 5:
        errores['nit'] = 'NIT inválido (mínimo 5 caracteres)'
    if errores:
        return jsonify({'errores': errores}), 422
 
    p = Proveedor(
        nombre           = nombre,
        apellido_paterno = apellido_paterno or None,
        apellido_materno = apellido_materno or None,
        nit              = nit       or None,
        telefono         = telefono  or None,
        email            = email     or None,
        direccion        = direccion or None,
        contacto         = contacto  or None,
        activo           = True,
    )
    db.session.add(p)
    db.session.commit()
    return jsonify(p.to_dict()), 201
 
 
@bp_proveedores.route('/proveedores/<int:id>', methods=['PUT'])
@requiere_permiso('proveedores')
def actualizar(id):
    p     = Proveedor.query.get_or_404(id)
    datos = request.get_json() or {}
    errores = {}
 
    nombre           = (datos.get('nombre')           or '').strip()
    apellido_paterno = (datos.get('apellido_paterno') or '').strip()
    email            = (datos.get('email')            or '').strip().lower()
    telefono         = (datos.get('telefono')         or '').strip()
    nit              = (datos.get('nit')              or '').strip()
 
    if nombre and len(nombre) < 2:
        errores['nombre'] = 'Mínimo 2 caracteres'
    if apellido_paterno and len(apellido_paterno) < 2:
        errores['apellido_paterno'] = 'Mínimo 2 caracteres'
    if email and ('@' not in email or '.' not in email):
        errores['email'] = 'Correo inválido'
    if telefono and len(telefono) < 7:
        errores['telefono'] = 'Mínimo 7 dígitos'
    if nit and len(nit) < 5:
        errores['nit'] = 'Mínimo 5 caracteres'
    if errores:
        return jsonify({'errores': errores}), 422
 
    if nombre:           p.nombre           = nombre
    if apellido_paterno: p.apellido_paterno = apellido_paterno
    if 'apellido_materno' in datos:
        p.apellido_materno = (datos['apellido_materno'] or '').strip() or None
    if 'nit'      in datos: p.nit      = nit      or None
    if 'telefono' in datos: p.telefono = telefono or None
    if 'email'    in datos: p.email    = email    or None
    if 'direccion' in datos:
        p.direccion = (datos['direccion'] or '').strip() or None
    if 'contacto' in datos:
        p.contacto = (datos['contacto'] or '').strip() or None
    if 'activo' in datos: p.activo = datos['activo']
 
    db.session.commit()
    return jsonify(p.to_dict())
 
 
@bp_proveedores.route('/proveedores/<int:id>', methods=['DELETE'])
@requiere_permiso('proveedores')
def eliminar(id):
    p = Proveedor.query.get_or_404(id)
    db.session.delete(p)
    db.session.commit()
    return jsonify({'mensaje': 'Proveedor eliminado permanentemente'})
 