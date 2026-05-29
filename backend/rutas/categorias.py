# carolina/backend/rutas/categorias.py
from flask import Blueprint, request, jsonify
from extensions import db
from modelos.categoria import Categoria
from utilidades.permisos import requiere_permiso

bp_categorias = Blueprint('categorias', __name__)

@bp_categorias.route('/categorias', methods=['GET'])
@requiere_permiso('productos_ver')
def listar():
    categorias = Categoria.query.order_by(Categoria.nombre.asc()).all()
    return jsonify([c.to_dict() for c in categorias])

@bp_categorias.route('/categorias/<int:id>', methods=['GET'])
@requiere_permiso('productos_ver')
def obtener(id):
    c = Categoria.query.get_or_404(id)
    return jsonify(c.to_dict())

@bp_categorias.route('/categorias', methods=['POST'])
@requiere_permiso('productos')
def crear():
    datos = request.get_json() or {}
    nombre = (datos.get('nombre') or '').strip()
    if len(nombre) < 2:
        return jsonify({'errores': {'nombre': 'El nombre es requerido'}}), 422
    if Categoria.query.filter_by(nombre=nombre).first():
        return jsonify({'errores': {'nombre': 'Ya existe esta categoría'}}), 422
    c = Categoria(
        nombre=nombre,
        descripcion=(datos.get('descripcion') or '').strip() or None
    )
    db.session.add(c)
    db.session.commit()
    return jsonify(c.to_dict()), 201

@bp_categorias.route('/categorias/<int:id>', methods=['PUT'])
@requiere_permiso('productos')
def actualizar(id):
    c = Categoria.query.get_or_404(id)
    datos = request.get_json() or {}
    nombre = (datos.get('nombre') or '').strip()
    if nombre and len(nombre) < 2:
        return jsonify({'errores': {'nombre': 'Mínimo 2 caracteres'}}), 422
    if nombre:
        c.nombre = nombre
    if 'descripcion' in datos:
        c.descripcion = (datos['descripcion'] or '').strip() or None
    db.session.commit()
    return jsonify(c.to_dict())

@bp_categorias.route('/categorias/<int:id>', methods=['DELETE'])
@requiere_permiso('todo')
def eliminar(id):
    c = Categoria.query.get_or_404(id)
    # Verificar si tiene productos asociados
    if c.productos:
        return jsonify({'error': 'No se puede eliminar: tiene productos asociados'}), 409
    db.session.delete(c)
    db.session.commit()
    return jsonify({'mensaje': 'Categoría eliminada'})