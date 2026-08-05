# carolina/backend/rutas/dashboard.py
"""
Datos reales para la pantalla de Inicio (Dashboard): tarjetas de resumen,
ventas de los últimos días, productos más vendidos, distribución de
métodos de pago y clientes con más saldo pendiente.

No usa @requiere_permiso porque el dashboard lo ve cualquier usuario
logueado (admin, vendedor o almacenero) — cada quien ve las tarjetas que
le sirven, el propio frontend decide cuáles mostrar según su rol.
"""
from flask import Blueprint, request, jsonify
from sqlalchemy import func
from datetime import timedelta
from extensions import db
from modelos.venta import Venta, DetalleVenta
from modelos.pedido import Pedido
from modelos.cliente import Cliente
from modelos.producto import Producto
from modelos.inventario import Inventario
from modelos.devolucion import Devolucion
from modelos.compra import Compra
from modelos.cobranza import Cobranza
from utilidades.permisos import obtener_usuario_actual
from utilidades.tiempo import ahora_bolivia, hoy_bolivia

bp_dashboard = Blueprint('dashboard', __name__)

ESTADOS_PEDIDO_PENDIENTE = ('pendiente', 'confirmado', 'en_camino')


def _requiere_login():
    usuario = obtener_usuario_actual()
    if not usuario:
        return None, (jsonify({'error': 'No autenticado'}), 401)
    if not usuario.activo:
        return None, (jsonify({'error': 'Usuario desactivado'}), 403)
    return usuario, None


@bp_dashboard.route('/dashboard/resumen', methods=['GET'])
def resumen():
    usuario, error = _requiere_login()
    if error:
        return error

    hoy = hoy_bolivia()
    inicio_mes = hoy.replace(day=1)

    # Ventas de hoy (globales y propias del usuario logueado)
    ventas_hoy = (Venta.query
                  .filter(db.func.date(Venta.fecha) == hoy)
                  .filter(Venta.estado != 'anulada')
                  .all())
    ventas_hoy_monto = round(sum(float(v.total or 0) for v in ventas_hoy), 2)
    mis_ventas_hoy = [v for v in ventas_hoy if v.usuario_id == usuario.id]
    mis_ventas_hoy_monto = round(sum(float(v.total or 0) for v in mis_ventas_hoy), 2)

    # Pedidos
    pedidos_hoy_cantidad = (Pedido.query
                             .filter(db.func.date(Pedido.fecha) == hoy)
                             .count())
    pedidos_pendientes = Pedido.query.filter(
        Pedido.estado.in_(ESTADOS_PEDIDO_PENDIENTE)).all()
    mis_pedidos_pendientes = [p for p in pedidos_pendientes if p.usuario_id == usuario.id]

    # Clientes y productos
    clientes_activos = Cliente.query.filter_by(activo=True).count()
    productos_activos = Producto.query.filter_by(activo=True).count()

    # Stock crítico / sin stock
    stock_critico = [i for i in Inventario.query.all()
                      if i.estado_stock in ('critico', 'sin_stock')]

    # Cuentas por cobrar (saldo pendiente de todas las ventas no anuladas)
    ventas_activas = Venta.query.filter(Venta.estado != 'anulada').all()
    cuentas_pendientes = [v for v in ventas_activas if v.saldo_pendiente > 0]
    cuentas_por_cobrar_total = round(
        sum(v.saldo_pendiente for v in cuentas_pendientes), 2)

    # Devoluciones pendientes
    devoluciones_pendientes_cantidad = Devolucion.query.filter_by(
        estado='pendiente').count()

    # Compras del mes (solo las efectivamente recibidas)
    compras_mes = (Compra.query
                    .filter(Compra.estado == 'recibida')
                    .filter(db.func.date(Compra.fecha) >= inicio_mes)
                    .all())
    compras_mes_total = round(sum(float(c.total or 0) for c in compras_mes), 2)

    return jsonify({
        'ventas_hoy_monto':      ventas_hoy_monto,
        'ventas_hoy_cantidad':   len(ventas_hoy),
        'mis_ventas_hoy_monto':      mis_ventas_hoy_monto,
        'mis_ventas_hoy_cantidad':   len(mis_ventas_hoy),
        'pedidos_hoy_cantidad':          pedidos_hoy_cantidad,
        'pedidos_pendientes_cantidad':   len(pedidos_pendientes),
        'mis_pedidos_pendientes_cantidad': len(mis_pedidos_pendientes),
        'clientes_activos':   clientes_activos,
        'productos_activos':  productos_activos,
        'stock_critico_cantidad': len(stock_critico),
        'cuentas_por_cobrar_total':    cuentas_por_cobrar_total,
        'cuentas_por_cobrar_cantidad': len(cuentas_pendientes),
        'devoluciones_pendientes_cantidad': devoluciones_pendientes_cantidad,
        'compras_mes_total':    compras_mes_total,
        'compras_mes_cantidad': len(compras_mes),
    })


@bp_dashboard.route('/dashboard/ventas-semana', methods=['GET'])
def ventas_semana():
    """Total vendido por día, de los últimos N días (por defecto 7),
    incluyendo hoy. ?propias=true filtra solo las ventas del usuario
    logueado (para la vista de un vendedor)."""
    usuario, error = _requiere_login()
    if error:
        return error

    dias = request.args.get('dias', 7, type=int)
    solo_propias = request.args.get('propias', 'false').lower() == 'true'
    hoy = hoy_bolivia()
    desde = hoy - timedelta(days=dias - 1)

    query = Venta.query.filter(
        db.func.date(Venta.fecha) >= desde,
        Venta.estado != 'anulada',
    )
    if solo_propias:
        query = query.filter(Venta.usuario_id == usuario.id)

    ventas = query.all()
    por_dia = {}
    for i in range(dias):
        fecha = desde + timedelta(days=i)
        por_dia[fecha.isoformat()] = {'fecha': fecha.isoformat(), 'total': 0.0, 'cantidad': 0}

    for v in ventas:
        clave = v.fecha.date().isoformat()
        if clave in por_dia:
            por_dia[clave]['total'] += float(v.total or 0)
            por_dia[clave]['cantidad'] += 1

    resultado = list(por_dia.values())
    for fila in resultado:
        fila['total'] = round(fila['total'], 2)
    return jsonify(resultado)


@bp_dashboard.route('/dashboard/top-productos', methods=['GET'])
def top_productos():
    """Productos más vendidos (por cantidad) en los últimos N días."""
    _, error = _requiere_login()
    if error:
        return error

    dias = request.args.get('dias', 30, type=int)
    limite = request.args.get('limite', 5, type=int)
    desde = ahora_bolivia() - timedelta(days=dias)

    filas = (db.session.query(
                Producto.id,
                Producto.nombre,
                func.sum(DetalleVenta.cantidad).label('cantidad'),
                func.sum(DetalleVenta.subtotal).label('total'),
             )
             .join(DetalleVenta, DetalleVenta.producto_id == Producto.id)
             .join(Venta, DetalleVenta.venta_id == Venta.id)
             .filter(Venta.estado != 'anulada')
             .filter(Venta.fecha >= desde)
             .group_by(Producto.id, Producto.nombre)
             .order_by(func.sum(DetalleVenta.cantidad).desc())
             .limit(limite)
             .all())

    return jsonify([
        {
            'producto_id': fila.id,
            'producto': fila.nombre,
            'cantidad': float(fila.cantidad or 0),
            'total': round(float(fila.total or 0), 2),
        }
        for fila in filas
    ])


@bp_dashboard.route('/dashboard/metodos-pago', methods=['GET'])
def metodos_pago():
    """Distribución de lo cobrado (Cobranzas) por método de pago, en los
    últimos N días — para el gráfico de torta/dona."""
    _, error = _requiere_login()
    if error:
        return error

    dias = request.args.get('dias', 30, type=int)
    desde = ahora_bolivia() - timedelta(days=dias)

    filas = (db.session.query(
                Cobranza.metodo_pago,
                func.sum(Cobranza.monto_total).label('monto'),
             )
             .filter(Cobranza.fecha >= desde)
             .group_by(Cobranza.metodo_pago)
             .all())

    total = sum(float(f.monto or 0) for f in filas) or 1.0
    return jsonify([
        {
            'metodo': fila.metodo_pago,
            'monto': round(float(fila.monto or 0), 2),
            'porcentaje': round(float(fila.monto or 0) / total * 100, 1),
        }
        for fila in filas
    ])


@bp_dashboard.route('/dashboard/top-deudores', methods=['GET'])
def top_deudores():
    """Clientes con más saldo pendiente acumulado (para cobrar primero)."""
    _, error = _requiere_login()
    if error:
        return error

    limite = request.args.get('limite', 5, type=int)
    ventas = Venta.query.filter(Venta.estado != 'anulada').all()
    resumen = {}
    for v in ventas:
        saldo = v.saldo_pendiente
        if saldo <= 0 or not v.cliente_id:
            continue
        r = resumen.setdefault(v.cliente_id, {
            'cliente_id': v.cliente_id,
            'cliente': v.cliente.nombre_completo if v.cliente else 'Sin cliente',
            'saldo_total': 0.0,
            'cantidad_cuentas': 0,
        })
        r['saldo_total'] = round(r['saldo_total'] + saldo, 2)
        r['cantidad_cuentas'] += 1

    filas = sorted(resumen.values(), key=lambda r: r['saldo_total'], reverse=True)
    return jsonify(filas[:limite])
