# carolina/backend/rutas/marcas.py
from flask import Blueprint, request, jsonify
from extensions import db
from modelos.marca import Marca
from utilidades.permisos import requiere_permiso

bp_marcas = Blueprint('marcas', __name__)

@bp_marcas.route('/marcas', methods=['GET'])
@requiere_permiso('productos_ver')
def listar():
    marcas = Marca.query.order_by(Marca.nombre.asc()).all()
    return jsonify([m.to_dict() for m in marcas])

@bp_marcas.route('/marcas/<int:id>', methods=['GET'])
@requiere_permiso('productos_ver')
def obtener(id):
    m = Marca.query.get_or_404(id)
    return jsonify(m.to_dict())

@bp_marcas.route('/marcas', methods=['POST'])
@requiere_permiso('productos')
def crear():
    datos = request.get_json() or {}
    nombre = (datos.get('nombre') or '').strip()
    if len(nombre) < 2:
        return jsonify({'errores': {'nombre': 'El nombre es requerido'}}), 422
    if Marca.query.filter_by(nombre=nombre).first():
        return jsonify({'errores': {'nombre': 'Ya existe esta marca'}}), 422
    m = Marca(
        nombre=nombre,
        descripcion=(datos.get('descripcion') or '').strip() or None
    )
    db.session.add(m)
    db.session.commit()
    return jsonify(m.to_dict()), 201

@bp_marcas.route('/marcas/<int:id>', methods=['PUT'])
@requiere_permiso('productos')
def actualizar(id):
    m = Marca.query.get_or_404(id)
    datos = request.get_json() or {}
    nombre = (datos.get('nombre') or '').strip()
    if nombre and len(nombre) < 2:
        return jsonify({'errores': {'nombre': 'Mínimo 2 caracteres'}}), 422
    if nombre:
        m.nombre = nombre
    if 'descripcion' in datos:
        m.descripcion = (datos['descripcion'] or '').strip() or None
    db.session.commit()
    return jsonify(m.to_dict())

@bp_marcas.route('/marcas/<int:id>', methods=['DELETE'])
@requiere_permiso('todo')
def eliminar(id):
    m = Marca.query.get_or_404(id)
    db.session.delete(m)
    db.session.commit()
    return jsonify({'mensaje': 'Marca eliminada'})