# carolina/backend/rutas/precios.py
from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required
from extensions import db
from modelos.precio import Precio
from utilidades.permisos import requiere_permiso

bp_precios = Blueprint('precios', __name__)

@bp_precios.route('/precios', methods=['GET'])
@jwt_required()
def listar():
    producto_id = request.args.get('producto_id')
    tipo = request.args.get('tipo')
    q = Precio.query.filter_by(activo=True)
    if producto_id:
        q = q.filter_by(producto_id=producto_id)
    if tipo:
        q = q.filter_by(tipo=tipo)
    return jsonify([p.to_dict() for p in q.all()])

@bp_precios.route('/precios', methods=['POST'])
@jwt_required()
@requiere_permiso('productos')
def crear():
    datos = request.get_json()
    errores = {}
    if not datos.get('producto_id'):
        errores['producto_id'] = 'El producto es requerido'
    if not datos.get('precio') or float(datos['precio']) <= 0:
        errores['precio'] = 'El precio debe ser mayor a 0'
    if not datos.get('tipo') or datos['tipo'] not in ['compra', 'venta']:
        errores['tipo'] = 'El tipo debe ser compra o venta'
    if errores:
        return jsonify({'errores': errores}), 422

    # Desactivar precio anterior del mismo tipo para ese producto
    Precio.query.filter_by(
        producto_id=datos['producto_id'],
        tipo=datos['tipo'],
        proveedor_id=datos.get('proveedor_id'),
        activo=True
    ).update({'activo': False})

    p = Precio(
        producto_id=datos['producto_id'],
        tipo=datos['tipo'],
        proveedor_id=datos.get('proveedor_id'),
        precio=datos['precio'],
        moneda=datos.get('moneda', 'BOB')
    )
    db.session.add(p)
    db.session.commit()
    return jsonify(p.to_dict()), 201

@bp_precios.route('/precios/<int:id>', methods=['DELETE'])
@jwt_required()
@requiere_permiso('productos')
def eliminar(id):
    p = Precio.query.get_or_404(id)
    p.activo = False
    db.session.commit()
    return jsonify({'mensaje': 'Precio eliminado'})
