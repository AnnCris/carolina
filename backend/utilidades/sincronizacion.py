# carolina/backend/utilidades/sincronizacion.py
"""
Mantiene sincronizados Pedido <-> Venta <-> Inventario cuando un
pedido ya generó una venta y alguno de los dos se edita después
(cambio de productos/cantidades de último momento, antes o durante
la entrega).
"""
from extensions import db
from modelos.inventario import Inventario, MovimientoInventario
from modelos.venta import DetalleVenta
from modelos.pedido import DetallePedido
from modelos.precio import Precio
from utilidades.tiempo import ahora_bolivia


class StockInsuficiente(Exception):
    pass


def precio_venta_sugerido(producto_id):
    precio = Precio.query.filter_by(
        producto_id=producto_id, tipo='venta', activo=True).first()
    return float(precio.precio) if precio else 0.0


def reemplazar_detalles_venta(venta, nuevos_items, usuario):
    """
    Reemplaza los productos de una venta ya existente: primero
    devuelve al inventario el stock de los ítems actuales, valida que
    haya stock suficiente para los nuevos y recién entonces aplica el
    cambio (todo dentro de la misma transacción; no hace commit).
    `nuevos_items`: lista de dicts con producto_id, cantidad,
    precio_unitario, precio_editado (opcional), peso_kg (opcional).
    Lanza StockInsuficiente (con rollback ya hecho) si no alcanza.
    """
    if not nuevos_items:
        raise StockInsuficiente('La venta debe tener al menos un producto')

    # 1. Devolver al inventario el stock de los ítems actuales
    for d in venta.detalles:
        inv = Inventario.query.filter_by(producto_id=d.producto_id).first()
        if inv:
            inv.stock_actual = float(inv.stock_actual or 0) + float(d.cantidad)
            db.session.add(MovimientoInventario(
                inventario_id=inv.id,
                producto_id=d.producto_id,
                tipo='entrada',
                cantidad=float(d.cantidad),
                referencia_tipo='edicion_venta',
                referencia_id=venta.id,
                nota=f'Reversión por edición de venta {venta.numero_recibo}',
                usuario_id=usuario.id if usuario else None,
            ))

    # 2. Validar que haya stock suficiente para los nuevos ítems
    for item in nuevos_items:
        cantidad = float(item.get('cantidad') or 0)
        if cantidad <= 0:
            db.session.rollback()
            raise StockInsuficiente('La cantidad debe ser mayor a 0')
        inv = Inventario.query.filter_by(producto_id=item['producto_id']).first()
        stock_actual = float(inv.stock_actual) if inv else 0
        if cantidad > stock_actual:
            nombre = inv.to_dict()['producto'] if inv else item['producto_id']
            db.session.rollback()
            raise StockInsuficiente(
                f'Stock insuficiente de "{nombre}". Disponible: {stock_actual}')

    # 3. Reemplazar los detalles de la venta
    for d in list(venta.detalles):
        db.session.delete(d)
    db.session.flush()

    total = 0
    for item in nuevos_items:
        cantidad = float(item['cantidad'])
        precio_unitario = float(item['precio_unitario'])
        subtotal = cantidad * precio_unitario

        db.session.add(DetalleVenta(
            venta=venta,
            producto_id=item['producto_id'],
            cantidad=cantidad,
            precio_unitario=precio_unitario,
            subtotal=subtotal,
            peso_kg=item.get('peso_kg'),
            precio_editado=bool(item.get('precio_editado', False)),
        ))
        total += subtotal

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
                nota=f'Venta {venta.numero_recibo} (editada)',
                usuario_id=usuario.id if usuario else None,
            ))

    venta.total = total - float(venta.descuento or 0)


def sincronizar_pedido_a_venta(pedido, venta, nuevos_detalles_pedido, usuario):
    """Al editar los productos de un Pedido que ya generó una Venta,
    traslada la misma lista de productos/cantidades a la Venta,
    conservando el precio ya acordado en las líneas que se mantienen
    y usando el precio de catálogo para las líneas nuevas."""
    precios_actuales = {
        d.producto_id: (float(d.precio_unitario), bool(d.precio_editado))
        for d in venta.detalles
    }
    nuevos_items_venta = []
    for item in nuevos_detalles_pedido:
        producto_id = item['producto_id']
        cantidad = float(item.get('cantidad', 0))
        if producto_id in precios_actuales:
            precio, editado = precios_actuales[producto_id]
        else:
            precio, editado = precio_venta_sugerido(producto_id), False
        nuevos_items_venta.append({
            'producto_id': producto_id,
            'cantidad': cantidad,
            'precio_unitario': precio,
            'precio_editado': editado,
        })
    reemplazar_detalles_venta(venta, nuevos_items_venta, usuario)


def sincronizar_venta_a_pedido(venta, nuevos_detalles_venta):
    """Al editar los productos de una Venta que vino de un Pedido,
    refleja la misma lista de productos/cantidades en el Pedido para
    que ambos muestren siempre lo mismo."""
    if not venta.pedido_id or not venta.pedido:
        return
    pedido = venta.pedido
    for det in list(pedido.detalles):
        db.session.delete(det)
    for item in nuevos_detalles_venta:
        db.session.add(DetallePedido(
            pedido=pedido,
            producto_id=item['producto_id'],
            cantidad=float(item['cantidad']),
        ))
