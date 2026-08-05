# carolina/backend/rutas/cobranzas.py
"""
Cuentas por cobrar: ventas que el cliente no pagó completas al momento
de la venta (pagó una parte, o quedó todo fiado) y que se van saldando
con una o varias Cobranzas después, por efectivo, QR o transferencia.
Una Cobranza puede saldar una sola cuenta (venta) o varias de una vez.
"""
from flask import Blueprint, request, jsonify
from extensions import db
from modelos.venta import Venta
from modelos.cobranza import Cobranza, DetalleCobranza, METODOS_PAGO_VALIDOS
from utilidades.permisos import requiere_permiso, obtener_usuario_actual
from utilidades.tiempo import ahora_bolivia

bp_cobranzas = Blueprint('cobranzas', __name__)


def _ventas_con_saldo(query):
    return [v for v in query.all() if v.saldo_pendiente > 0]


def _validar_detalles(cliente_id, detalles):
    """Valida la lista de {venta_id, monto} contra el saldo real de cada
    venta. Debe llamarse DESPUÉS de haber revertido (si corresponde) los
    detalles anteriores de la cobranza que se está editando."""
    if not detalles:
        return 'Selecciona al menos una cuenta a pagar'
    for item in detalles:
        venta = Venta.query.get(item.get('venta_id'))
        if not venta or venta.cliente_id != cliente_id:
            return 'Una de las cuentas seleccionadas no pertenece a este cliente'
        if venta.estado == 'anulada':
            return f'La venta {venta.numero_recibo} está anulada'
        try:
            monto = float(item.get('monto') or 0)
        except (TypeError, ValueError):
            return 'Monto inválido'
        if monto <= 0:
            return 'El monto de cada cuenta debe ser mayor a 0'
        if monto > venta.saldo_pendiente + 0.01:
            return (f'El monto para la venta {venta.numero_recibo} supera su '
                     f'saldo pendiente (Bs {venta.saldo_pendiente:.2f})')
    return None


@bp_cobranzas.route('/cobranzas', methods=['GET'])
@requiere_permiso('cobranzas')
def listar():
    query = Cobranza.query.order_by(Cobranza.fecha.desc())
    cliente_id = request.args.get('cliente_id')
    if cliente_id:
        query = query.filter(Cobranza.cliente_id == cliente_id)
    return jsonify([c.to_dict() for c in query.all()])


@bp_cobranzas.route('/cobranzas/<int:id>', methods=['GET'])
@requiere_permiso('cobranzas')
def obtener(id):
    c = Cobranza.query.get_or_404(id)
    return jsonify(c.to_dict())


@bp_cobranzas.route('/cobranzas', methods=['POST'])
@requiere_permiso('cobranzas')
def crear():
    datos = request.get_json() or {}
    errores = {}

    cliente_id = datos.get('cliente_id')
    if not cliente_id:
        errores['cliente_id'] = 'El cliente es requerido'
    if datos.get('metodo_pago') not in METODOS_PAGO_VALIDOS:
        errores['metodo_pago'] = 'Método de pago inválido'
    error_detalles = _validar_detalles(cliente_id, datos.get('detalles')) if cliente_id else None
    if error_detalles:
        errores['detalles'] = error_detalles
    if errores:
        return jsonify({'errores': errores}), 422

    usuario = obtener_usuario_actual()
    monto_total = sum(float(item['monto']) for item in datos['detalles'])

    c = Cobranza(
        cliente_id=cliente_id,
        usuario_id=usuario.id if usuario else None,
        metodo_pago=datos['metodo_pago'],
        monto_total=monto_total,
        nota=(datos.get('nota') or '').strip() or None,
        fecha=ahora_bolivia(),
    )
    db.session.add(c)
    db.session.flush()

    for item in datos['detalles']:
        db.session.add(DetalleCobranza(
            cobranza_id=c.id,
            venta_id=item['venta_id'],
            monto=item['monto'],
        ))

    db.session.commit()
    return jsonify(c.to_dict()), 201


@bp_cobranzas.route('/cobranzas/<int:id>', methods=['PUT'])
@requiere_permiso('cobranzas')
def actualizar(id):
    c = Cobranza.query.get_or_404(id)
    datos = request.get_json() or {}
    errores = {}

    metodo_pago = datos.get('metodo_pago', c.metodo_pago)
    if metodo_pago not in METODOS_PAGO_VALIDOS:
        errores['metodo_pago'] = 'Método de pago inválido'

    if 'detalles' in datos:
        # Revertir primero los detalles actuales para validar los nuevos
        # montos contra el saldo real (sin contar esta misma cobranza).
        DetalleCobranza.query.filter_by(cobranza_id=c.id).delete()
        db.session.flush()
        error_detalles = _validar_detalles(c.cliente_id, datos['detalles'])
        if error_detalles:
            db.session.rollback()
            return jsonify({'errores': {'detalles': error_detalles}}), 422

    if errores:
        db.session.rollback()
        return jsonify({'errores': errores}), 422

    c.metodo_pago = metodo_pago
    if 'nota' in datos:
        c.nota = (datos['nota'] or '').strip() or None

    if 'detalles' in datos:
        for item in datos['detalles']:
            db.session.add(DetalleCobranza(
                cobranza_id=c.id,
                venta_id=item['venta_id'],
                monto=item['monto'],
            ))
        c.monto_total = sum(float(item['monto']) for item in datos['detalles'])

    db.session.commit()
    return jsonify(c.to_dict())


@bp_cobranzas.route('/cobranzas/<int:id>', methods=['DELETE'])
@requiere_permiso('cobranzas')
def eliminar(id):
    c = Cobranza.query.get_or_404(id)
    db.session.delete(c)
    db.session.commit()
    return jsonify({'mensaje': 'Cobranza eliminada — las cuentas vuelven a quedar pendientes'})


# ── Consultas de apoyo (saldos, resumen, historial) ─────────────────────────

@bp_cobranzas.route('/cobranzas/pendientes', methods=['GET'])
@requiere_permiso('cobranzas')
def listar_pendientes():
    """Todas las cuentas (ventas) con saldo pendiente, de todos los clientes."""
    query = Venta.query.filter(Venta.estado != 'anulada').order_by(Venta.fecha.asc())
    return jsonify([v.to_dict() for v in _ventas_con_saldo(query)])


@bp_cobranzas.route('/cobranzas/resumen', methods=['GET'])
@requiere_permiso('cobranzas')
def resumen_por_cliente():
    """Un renglón por cliente: cuántas cuentas pendientes tiene y el
    saldo total que debe, para la pantalla principal de Cobranzas."""
    ventas = Venta.query.filter(Venta.estado != 'anulada').all()
    resumen = {}
    for v in ventas:
        saldo = v.saldo_pendiente
        if saldo <= 0 or not v.cliente_id:
            continue
        r = resumen.setdefault(v.cliente_id, {
            'cliente_id': v.cliente_id,
            'cliente': v.cliente.nombre_completo if v.cliente else 'Sin cliente',
            'telefono': v.cliente.telefono if v.cliente else None,
            'cantidad_cuentas': 0,
            'saldo_total': 0.0,
            'cuenta_mas_antigua': str(v.fecha),
        })
        r['cantidad_cuentas'] += 1
        r['saldo_total'] = round(r['saldo_total'] + saldo, 2)
        if str(v.fecha) < r['cuenta_mas_antigua']:
            r['cuenta_mas_antigua'] = str(v.fecha)
    filas = list(resumen.values())
    filas.sort(key=lambda r: r['cuenta_mas_antigua'])
    return jsonify(filas)


@bp_cobranzas.route('/cobranzas/cliente/<int:cliente_id>', methods=['GET'])
@requiere_permiso('cobranzas')
def ventas_por_cliente(cliente_id):
    """Todas las ventas (con o sin saldo) de un cliente, para ver su
    historial completo de cuentas en la pantalla de Cobranzas."""
    query = (Venta.query
             .filter_by(cliente_id=cliente_id)
             .filter(Venta.estado != 'anulada')
             .order_by(Venta.fecha.desc()))
    return jsonify([v.to_dict() for v in query.all()])


@bp_cobranzas.route('/cobranzas/cliente/<int:cliente_id>/pendientes', methods=['GET'])
@requiere_permiso('cobranzas')
def pendientes_por_cliente(cliente_id):
    """Solo las cuentas con saldo de un cliente — para avisar en Ventas/Pedidos."""
    query = (Venta.query
             .filter_by(cliente_id=cliente_id)
             .filter(Venta.estado != 'anulada')
             .order_by(Venta.fecha.asc()))
    return jsonify([v.to_dict() for v in _ventas_con_saldo(query)])


@bp_cobranzas.route('/cobranzas/cliente/<int:cliente_id>/historial', methods=['GET'])
@requiere_permiso('cobranzas')
def historial_cliente(cliente_id):
    """Cobros ya registrados a este cliente (recibos de cobro), con su detalle."""
    cobranzas = (Cobranza.query
                 .filter_by(cliente_id=cliente_id)
                 .order_by(Cobranza.fecha.desc()).all())
    return jsonify([c.to_dict() for c in cobranzas])
