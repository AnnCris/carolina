# carolina/backend/rutas/ventas.py
from flask import Blueprint, request, jsonify, send_file
from extensions import db
from modelos.venta import Venta, DetalleVenta
from modelos.inventario import Inventario, MovimientoInventario
from modelos.pedido import Pedido
from modelos.devolucion import Devolucion
from modelos.cobranza import Cobranza, DetalleCobranza, METODOS_PAGO_VALIDOS
from utilidades.permisos import requiere_permiso, obtener_usuario_actual
from utilidades.recibo_pdf import generar_recibo
from utilidades.tiempo import ahora_bolivia, hoy_bolivia
from utilidades.sincronizacion import (
    StockInsuficiente, precio_venta_sugerido,
    reemplazar_detalles_venta, sincronizar_venta_a_pedido,
)
import datetime

bp_ventas = Blueprint('ventas', __name__)

ESTADOS_PEDIDO_PENDIENTE = ('pendiente', 'confirmado', 'en_camino')


def _preparar_detalles_pedido(pedido):
    detalles = []
    for d in pedido.detalles:
        inv = Inventario.query.filter_by(producto_id=d.producto_id).first()
        detalles.append({
            'producto_id':      d.producto_id,
            'producto':         d.producto.nombre if d.producto else None,
            'cantidad':         float(d.cantidad or 0),
            'precio_unitario':  0.0 if d.devolucion_id else precio_venta_sugerido(d.producto_id),
            'stock_disponible': float(inv.stock_actual) if inv else 0,
            'devolucion_id':    d.devolucion_id,
        })
    return detalles


@bp_ventas.route('/ventas', methods=['GET'])
@requiere_permiso('ventas')
def listar_ventas():
    """Historial completo. El frontend por defecto usa /ventas/hoy o
    /ventas/fecha/<...> — este endpoint queda para búsquedas puntuales."""
    ventas = Venta.query.order_by(Venta.fecha.desc()).all()
    return jsonify([v.to_dict() for v in ventas])


@bp_ventas.route('/ventas/hoy', methods=['GET'])
@requiere_permiso('ventas')
def ventas_hoy():
    hoy = hoy_bolivia()
    ventas = (Venta.query
              .filter(db.func.date(Venta.fecha) == hoy)
              .order_by(Venta.fecha.desc())
              .all())
    return jsonify([v.to_dict() for v in ventas])


@bp_ventas.route('/ventas/fecha/<string:fecha_str>', methods=['GET'])
@requiere_permiso('ventas')
def ventas_por_fecha(fecha_str):
    """Ventas de una fecha específica (YYYY-MM-DD)."""
    try:
        fecha = datetime.datetime.strptime(fecha_str, '%Y-%m-%d').date()
    except ValueError:
        return jsonify({'error': 'Formato de fecha inválido. Usa YYYY-MM-DD'}), 422
    ventas = (Venta.query
              .filter(db.func.date(Venta.fecha) == fecha)
              .order_by(Venta.fecha.desc())
              .all())
    return jsonify([v.to_dict() for v in ventas])


@bp_ventas.route('/ventas/<int:id>', methods=['GET'])
@requiere_permiso('ventas')
def obtener_venta(id):
    venta = Venta.query.get_or_404(id)
    return jsonify(venta.to_dict())


@bp_ventas.route('/ventas/pedidos-pendientes', methods=['GET'])
@requiere_permiso('ventas')
def pedidos_pendientes():
    """Pedidos del día que aún no se convirtieron en venta."""
    hoy = hoy_bolivia()
    pedidos = (Pedido.query
               .filter(db.func.date(Pedido.fecha) == hoy)
               .filter(Pedido.estado.in_(ESTADOS_PEDIDO_PENDIENTE))
               .order_by(Pedido.id.desc())
               .all())
    return jsonify([p.to_dict() for p in pedidos])


@bp_ventas.route('/ventas/desde-pedido/<int:pedido_id>', methods=['GET'])
@requiere_permiso('ventas')
def preparar_desde_pedido(pedido_id):
    """Arma los datos sugeridos (precio de catálogo, stock) para
    convertir un pedido en venta, sin crear nada todavía."""
    pedido = Pedido.query.get_or_404(pedido_id)
    return jsonify({
        'pedido_id':  pedido.id,
        'cliente_id': pedido.cliente_id,
        'cliente':    pedido.cliente_nombre,
        'nota':       pedido.nota,
        'detalles':   _preparar_detalles_pedido(pedido),
    })


@bp_ventas.route('/ventas', methods=['POST'])
@requiere_permiso('ventas')
def crear_venta():
    datos = request.get_json() or {}
    usuario = obtener_usuario_actual()

    if not datos.get('detalles') or len(datos['detalles']) == 0:
        return jsonify({'error': 'La venta debe tener al menos un producto'}), 422

    pedido = None
    if datos.get('pedido_id'):
        pedido = Pedido.query.get(datos['pedido_id'])
        if not pedido:
            return jsonify({'error': 'El pedido indicado no existe'}), 404

    # Validar el pago inicial (cuánto paga el cliente en el momento, si es
    # que paga algo — puede ser 0 si queda todo a cuenta/fiado)
    monto_pagado_inicial = datos.get('monto_pagado')
    if monto_pagado_inicial is not None:
        try:
            monto_pagado_inicial = float(monto_pagado_inicial)
        except (TypeError, ValueError):
            return jsonify({'error': 'Monto pagado inválido'}), 422
        if monto_pagado_inicial < 0:
            return jsonify({'error': 'El monto pagado no puede ser negativo'}), 422
        if monto_pagado_inicial > 0 and datos.get('metodo_pago') not in METODOS_PAGO_VALIDOS:
            return jsonify({'error': 'Selecciona el método de pago (efectivo, QR o transferencia)'}), 422
    else:
        monto_pagado_inicial = 0.0

    # Validar stock disponible antes de tocar nada
    for item in datos['detalles']:
        cantidad = float(item.get('cantidad') or 0)
        if cantidad <= 0:
            return jsonify({'error': 'La cantidad debe ser mayor a 0'}), 422
        inv = Inventario.query.filter_by(producto_id=item['producto_id']).first()
        stock_actual = float(inv.stock_actual) if inv else 0
        if cantidad > stock_actual:
            nombre = inv.to_dict()['producto'] if inv else item['producto_id']
            return jsonify({
                'error': f'Stock insuficiente de "{nombre}". '
                         f'Disponible: {stock_actual}'
            }), 422

    venta = Venta(
        cliente_id=datos.get('cliente_id'),
        usuario_id=usuario.id if usuario else None,
        pedido_id=pedido.id if pedido else None,
        descuento=datos.get('descuento', 0),
        nota=(datos.get('nota') or '').strip() or None,
    )
    db.session.add(venta)
    db.session.flush()  # asigna venta.id
    # Número de recibo correlativo: 001, 002, ... (mismo id de la venta)
    venta.numero_recibo = str(venta.id).zfill(3)

    total = 0
    devoluciones_a_resolver = set()
    for item in datos['detalles']:
        cantidad = float(item['cantidad'])
        devolucion_id = item.get('devolucion_id')
        # Producto de reemplazo por una devolución: siempre sin costo,
        # sin importar lo que haya mandado el frontend.
        precio_unitario = 0.0 if devolucion_id else float(item['precio_unitario'])
        subtotal = cantidad * precio_unitario
        if devolucion_id:
            devoluciones_a_resolver.add(devolucion_id)

        detalle = DetalleVenta(
            venta=venta,
            producto_id=item['producto_id'],
            cantidad=cantidad,
            precio_unitario=precio_unitario,
            subtotal=subtotal,
            peso_kg=item.get('peso_kg'),
            precio_editado=bool(item.get('precio_editado', False)),
            devolucion_id=devolucion_id,
        )
        db.session.add(detalle)
        total += subtotal

        # Actualizar inventario y dejar registro del movimiento
        inv = Inventario.query.filter_by(producto_id=item['producto_id']).first()
        if inv:
            inv.stock_actual = float(inv.stock_actual or 0) - cantidad
            inv.ultima_salida = ahora_bolivia()
            db.session.add(MovimientoInventario(
                inventario_id=inv.id,
                producto_id=item['producto_id'],
                tipo='salida',
                cantidad=cantidad,
                referencia_tipo='venta',
                referencia_id=venta.id,
                nota=f'Venta {venta.numero_recibo}',
                usuario_id=usuario.id if usuario else None,
            ))

    venta.total = total - float(datos.get('descuento', 0))

    # No se puede "pagar" más de lo que cuesta la venta al momento de crearla
    monto_pagado_inicial = min(monto_pagado_inicial, float(venta.total))
    if monto_pagado_inicial > 0:
        cobranza_inicial = Cobranza(
            cliente_id=venta.cliente_id,
            usuario_id=usuario.id if usuario else None,
            metodo_pago=datos.get('metodo_pago'),
            monto_total=monto_pagado_inicial,
            nota=f'Pago al momento de la venta {venta.numero_recibo}',
            fecha=ahora_bolivia(),
        )
        db.session.add(cobranza_inicial)
        db.session.flush()
        db.session.add(DetalleCobranza(
            cobranza_id=cobranza_inicial.id,
            venta_id=venta.id,
            monto=monto_pagado_inicial,
        ))

    if pedido:
        pedido.estado = 'entregado'

    for devolucion_id in devoluciones_a_resolver:
        devolucion = Devolucion.query.get(devolucion_id)
        if devolucion and devolucion.estado == 'pendiente':
            devolucion.estado = 'resuelta'
            devolucion.fecha_resolucion = ahora_bolivia()
            devolucion.venta_resolucion_id = venta.id

    db.session.commit()

    return jsonify({'venta': venta.to_dict(), 'numero_recibo': venta.numero_recibo}), 201


@bp_ventas.route('/ventas/<int:id>', methods=['PUT'])
@requiere_permiso('ventas')
def actualizar_venta(id):
    """Edita una venta existente. Si se envían 'detalles', reemplaza
    por completo los productos de la venta: primero devuelve al
    inventario el stock de los ítems actuales, valida que haya stock
    suficiente para los nuevos, y recién entonces aplica el cambio."""
    venta = Venta.query.get_or_404(id)
    datos = request.get_json() or {}
    usuario = obtener_usuario_actual()

    if venta.estado == 'anulada':
        return jsonify({'error': 'No se puede editar una venta anulada'}), 422

    if 'nota' in datos:
        venta.nota = (datos['nota'] or '').strip() or None

    if 'cliente_id' in datos:
        venta.cliente_id = datos['cliente_id']

    if 'detalles' in datos:
        try:
            reemplazar_detalles_venta(venta, datos['detalles'], usuario)
        except StockInsuficiente as e:
            return jsonify({'error': str(e)}), 422

        # El pedido de origen (si existe) debe mostrar los mismos
        # productos/cantidades que la venta ya editada.
        sincronizar_venta_a_pedido(venta, datos['detalles'])

        for item in datos['detalles']:
            devolucion_id = item.get('devolucion_id')
            if not devolucion_id:
                continue
            devolucion = Devolucion.query.get(devolucion_id)
            if devolucion and devolucion.estado == 'pendiente':
                devolucion.estado = 'resuelta'
                devolucion.fecha_resolucion = ahora_bolivia()
                devolucion.venta_resolucion_id = venta.id

        if 'descuento' in datos:
            total_sin_descuento = sum(float(d.subtotal) for d in venta.detalles)
            venta.descuento = datos['descuento']
            venta.total = total_sin_descuento - float(datos['descuento'])

    elif 'descuento' in datos:
        total_actual = sum(float(d.subtotal) for d in venta.detalles)
        venta.descuento = datos['descuento']
        venta.total = total_actual - float(datos['descuento'])

    db.session.commit()
    return jsonify(venta.to_dict())


@bp_ventas.route('/ventas/<int:id>', methods=['DELETE'])
@requiere_permiso('ventas')
def anular_venta(id):
    """Anula la venta: revierte el stock descontado y libera el pedido
    de origen (si vino de uno) para poder volver a venderlo. No se
    borra el registro — queda como 'anulada' para el historial."""
    venta = Venta.query.get_or_404(id)
    usuario = obtener_usuario_actual()

    if venta.estado == 'anulada':
        return jsonify({'error': 'Esta venta ya fue anulada'}), 422

    for d in venta.detalles:
        inv = Inventario.query.filter_by(producto_id=d.producto_id).first()
        if inv:
            inv.stock_actual = float(inv.stock_actual or 0) + float(d.cantidad)
            inv.ultima_entrada = ahora_bolivia()
            db.session.add(MovimientoInventario(
                inventario_id=inv.id,
                producto_id=d.producto_id,
                tipo='entrada',
                cantidad=float(d.cantidad),
                referencia_tipo='anulacion_venta',
                referencia_id=venta.id,
                nota=f'Anulación de venta {venta.numero_recibo}',
                usuario_id=usuario.id if usuario else None,
            ))

    venta.estado = 'anulada'
    if venta.pedido_id and venta.pedido:
        venta.pedido.estado = 'pendiente'

    db.session.commit()
    return jsonify({'mensaje': 'Venta anulada y stock revertido'})


@bp_ventas.route('/ventas/<int:id>/recibo', methods=['GET'])
@requiere_permiso('ventas')
def obtener_recibo(id):
    venta = Venta.query.get_or_404(id)
    pdf_buffer = generar_recibo(venta)
    return send_file(pdf_buffer, mimetype='application/pdf',
                     download_name=f'recibo_{venta.numero_recibo}.pdf')
