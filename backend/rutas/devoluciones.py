# carolina/backend/rutas/devoluciones.py
from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from extensions import db
from modelos.devolucion import Devolucion, DetalleDevolucion
from modelos.inventario import Inventario
from utilidades.permisos import requiere_permiso

bp_devoluciones = Blueprint('devoluciones', __name__)

@bp_devoluciones.route('/devoluciones', methods=['GET'])
@jwt_required()
@requiere_permiso('devoluciones')
def listar():
    return jsonify([d.to_dict() for d in Devolucion.query.order_by(Devolucion.fecha.desc()).all()])

@bp_devoluciones.route('/devoluciones', methods=['POST'])
@jwt_required()
@requiere_permiso('devoluciones')
def crear():
    datos = request.get_json()
    if not datos.get('tipo') or datos['tipo'] not in ['venta', 'compra']:
        return jsonify({'errores': {'tipo': 'Tipo debe ser venta o compra'}}), 422
    if not datos.get('motivo'):
        return jsonify({'errores': {'motivo': 'El motivo es requerido'}}), 422

    d = Devolucion(tipo=datos['tipo'], usuario_id=get_jwt_identity(),
                   venta_id=datos.get('venta_id'), compra_id=datos.get('compra_id'),
                   motivo=datos['motivo'])
    db.session.add(d)
    total = 0
    for item in datos.get('detalles', []):
        subtotal = float(item['cantidad']) * float(item['precio_unitario'])
        db.session.add(DetalleDevolucion(devolucion=d, producto_id=item['producto_id'],
                                          cantidad=item['cantidad'], precio_unitario=item['precio_unitario']))
        # Devolver al inventario si es devolución de venta
        if datos['tipo'] == 'venta':
            inv = Inventario.query.filter_by(producto_id=item['producto_id']).first()
            if inv:
                inv.stock_actual += float(item['cantidad'])
        total += subtotal
    d.total = total
    db.session.commit()
    return jsonify(d.to_dict()), 201
