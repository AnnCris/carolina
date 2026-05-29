# carolina/backend/rutas/pedidos.py
from flask import Blueprint, request, jsonify, current_app
from flask_jwt_extended import jwt_required, get_jwt_identity
from extensions import db
from modelos.pedido import Pedido, DetallePedido
from utilidades.permisos import requiere_permiso
import uuid, os

bp_pedidos = Blueprint('pedidos', __name__)

@bp_pedidos.route('/pedidos', methods=['GET'])
@jwt_required()
@requiere_permiso('pedidos')
def listar():
    return jsonify([p.to_dict() for p in Pedido.query.order_by(Pedido.fecha.desc()).all()])

@bp_pedidos.route('/pedidos', methods=['POST'])
@jwt_required()
@requiere_permiso('pedidos')
def crear():
    datos = request.get_json()
    if not datos.get('cliente_id'):
        return jsonify({'errores': {'cliente_id': 'El cliente es requerido'}}), 422
    p = Pedido(cliente_id=datos['cliente_id'], usuario_id=get_jwt_identity(),
               fecha_entrega=datos.get('fecha_entrega'), nota=datos.get('nota'))
    db.session.add(p)
    total = 0
    for item in datos.get('detalles', []):
        subtotal = float(item['cantidad']) * float(item['precio_estimado'])
        db.session.add(DetallePedido(pedido=p, producto_id=item['producto_id'],
                                     cantidad=item['cantidad'], precio_estimado=item['precio_estimado']))
        total += subtotal
    p.total_estimado = total
    db.session.commit()
    return jsonify(p.to_dict()), 201

@bp_pedidos.route('/pedidos/<int:id>', methods=['PUT'])
@jwt_required()
@requiere_permiso('pedidos')
def actualizar_estado(id):
    p = Pedido.query.get_or_404(id)
    datos = request.get_json()
    p.estado = datos.get('estado', p.estado)
    db.session.commit()
    return jsonify(p.to_dict())
