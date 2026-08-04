from flask import Blueprint, request, jsonify
from extensions import db
from modelos.pedido import Pedido, DetallePedido
from utilidades.permisos import requiere_permiso, obtener_usuario_actual
from utilidades.tiempo import hoy_bolivia
from utilidades.sincronizacion import (
    StockInsuficiente, sincronizar_pedido_a_venta,
)
from datetime import datetime

bp_pedidos = Blueprint('pedidos', __name__)

ESTADOS = ['pendiente', 'confirmado', 'en_camino', 'entregado', 'cancelado']


@bp_pedidos.route('/pedidos', methods=['GET'])
@requiere_permiso('pedidos')
def listar():
    pedidos = Pedido.query.order_by(Pedido.fecha.desc()).all()
    return jsonify([p.to_dict() for p in pedidos])


@bp_pedidos.route('/pedidos/hoy', methods=['GET'])
@requiere_permiso('pedidos')
def pedidos_hoy():
    """Pedidos del día actual (hora Bolivia) para imprimir la lista diaria."""
    hoy = hoy_bolivia()
    pedidos = (Pedido.query
               .filter(db.func.date(Pedido.fecha) == hoy)
               .order_by(Pedido.cliente_id.asc())
               .all())
    return jsonify([p.to_dict() for p in pedidos])
 
 
@bp_pedidos.route('/pedidos/fecha/<string:fecha_str>', methods=['GET'])
@requiere_permiso('pedidos')
def pedidos_por_fecha(fecha_str):
    """Pedidos de una fecha específica (YYYY-MM-DD)."""
    try:
        fecha = datetime.strptime(fecha_str, '%Y-%m-%d').date()
    except ValueError:
        return jsonify({'error': 'Formato de fecha inválido. Usa YYYY-MM-DD'}), 422
    pedidos = (Pedido.query
               .filter(db.func.date(Pedido.fecha) == fecha)
               .order_by(Pedido.cliente_id.asc())
               .all())
    return jsonify([p.to_dict() for p in pedidos])
 
 
@bp_pedidos.route('/pedidos/<int:id>', methods=['GET'])
@requiere_permiso('pedidos')
def obtener(id):
    p = Pedido.query.get_or_404(id)
    return jsonify(p.to_dict())
 
 
@bp_pedidos.route('/pedidos', methods=['POST'])
@requiere_permiso('pedidos')
def crear():
    datos   = request.get_json() or {}
    usuario = obtener_usuario_actual()
    errores = {}
 
    if not datos.get('cliente_id'):
        errores['cliente_id'] = 'El cliente es requerido'
    if not datos.get('detalles') or len(datos['detalles']) == 0:
        errores['detalles'] = 'Debe agregar al menos un producto'
 
    estado = datos.get('estado', 'pendiente')
    if estado not in ESTADOS:
        errores['estado'] = f'Estado inválido'
 
    if errores:
        return jsonify({'errores': errores}), 422
 
    fecha_entrega = None
    if datos.get('fecha_entrega'):
        try:
            fecha_entrega = datetime.strptime(
                datos['fecha_entrega'], '%Y-%m-%d').date()
        except ValueError:
            pass
 
    p = Pedido(
        cliente_id    = datos['cliente_id'],
        usuario_id    = usuario.id if usuario else None,
        fecha_entrega = fecha_entrega,
        estado        = estado,
        nota          = (datos.get('nota') or '').strip() or None,
    )
    db.session.add(p)
 
    total = 0.0
    for item in datos['detalles']:
        cantidad = float(item.get('cantidad', 0))
 
        if cantidad <= 0:
            return jsonify({'error': 'La cantidad debe ser mayor a 0'}), 422
 
        db.session.add(DetallePedido(
            pedido          = p,
            producto_id     = item['producto_id'],
            cantidad        = cantidad,
        ))

    db.session.commit()
    return jsonify(p.to_dict()), 201
 
 
@bp_pedidos.route('/pedidos/<int:id>', methods=['PUT'])
@requiere_permiso('pedidos')
def actualizar(id):
    p       = Pedido.query.get_or_404(id)
    datos   = request.get_json() or {}
    errores = {}
 
    if 'estado' in datos:
        if datos['estado'] not in ESTADOS:
            errores['estado'] = 'Estado inválido'
        else:
            p.estado = datos['estado']
 
    if 'cliente_id' in datos:
        p.cliente_id = datos['cliente_id']
 
    if 'nota' in datos:
        p.nota = (datos['nota'] or '').strip() or None
 
    if 'fecha_entrega' in datos and datos['fecha_entrega']:
        try:
            p.fecha_entrega = datetime.strptime(
                datos['fecha_entrega'], '%Y-%m-%d').date()
        except ValueError:
            errores['fecha_entrega'] = 'Formato inválido. Usa YYYY-MM-DD'
 
    if errores:
        return jsonify({'errores': errores}), 422
 
    if 'detalles' in datos and len(datos['detalles']) > 0:
        for det in p.detalles:
            db.session.delete(det)

        for item in datos['detalles']:
            cantidad        = float(item.get('cantidad', 0))
            if cantidad <= 0:
                return jsonify({'error': 'Cantidad debe ser mayor a 0'}), 422
            db.session.add(DetallePedido(
                pedido          = p,
                producto_id     = item['producto_id'],
                cantidad        = cantidad,
            ))

        # Si este pedido ya generó una venta, trasladarle los mismos
        # productos/cantidades y reconciliar el inventario (revierte
        # el stock de lo anterior y descuenta lo nuevo).
        venta_activa = next(
            (v for v in p.ventas if v.estado != 'anulada'), None)
        if venta_activa:
            usuario = obtener_usuario_actual()
            try:
                sincronizar_pedido_a_venta(
                    p, venta_activa, datos['detalles'], usuario)
            except StockInsuficiente as e:
                return jsonify({'error': str(e)}), 422

    db.session.commit()
    return jsonify(p.to_dict())
 
 
@bp_pedidos.route('/pedidos/<int:id>', methods=['DELETE'])
@requiere_permiso('pedidos')
def eliminar(id):
    p = Pedido.query.get_or_404(id)
    db.session.delete(p)
    db.session.commit()
    return jsonify({'mensaje': 'Pedido eliminado'})