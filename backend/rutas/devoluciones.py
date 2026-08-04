# carolina/backend/rutas/devoluciones.py
from flask import Blueprint, request, jsonify
from extensions import db
from modelos.devolucion import Devolucion, DetalleDevolucion, MOTIVOS_VALIDOS
from utilidades.permisos import requiere_permiso, obtener_usuario_actual
from utilidades.tiempo import ahora_bolivia

bp_devoluciones = Blueprint('devoluciones', __name__)


def _validar_detalles(detalles):
    if not detalles:
        return 'Agrega al menos un producto a devolver'
    for item in detalles:
        if not item.get('producto_id'):
            return 'Cada producto es requerido'
        try:
            cantidad = float(item.get('cantidad') or 0)
        except (TypeError, ValueError):
            return 'Cantidad inválida'
        if cantidad <= 0:
            return 'La cantidad debe ser mayor a 0'
        motivo = item.get('motivo')
        if motivo not in MOTIVOS_VALIDOS:
            return 'Motivo inválido'
        if motivo == 'otro' and not (item.get('motivo_detalle') or '').strip():
            return 'Describe el motivo cuando eliges "Otro"'
    return None


@bp_devoluciones.route('/devoluciones', methods=['GET'])
@requiere_permiso('devoluciones')
def listar():
    query = Devolucion.query
    estado = request.args.get('estado')
    cliente_id = request.args.get('cliente_id')
    if estado:
        query = query.filter(Devolucion.estado == estado)
    if cliente_id:
        query = query.filter(Devolucion.cliente_id == cliente_id)
    devoluciones = query.order_by(Devolucion.fecha.desc()).all()
    return jsonify([d.to_dict() for d in devoluciones])


@bp_devoluciones.route('/devoluciones/pendientes/<int:cliente_id>', methods=['GET'])
@requiere_permiso('devoluciones')
def pendientes_por_cliente(cliente_id):
    devoluciones = Devolucion.query.filter_by(
        cliente_id=cliente_id, estado='pendiente'
    ).order_by(Devolucion.fecha.asc()).all()
    return jsonify([d.to_dict() for d in devoluciones])


@bp_devoluciones.route('/devoluciones/<int:id>', methods=['GET'])
@requiere_permiso('devoluciones')
def obtener(id):
    d = Devolucion.query.get_or_404(id)
    return jsonify(d.to_dict())


@bp_devoluciones.route('/devoluciones', methods=['POST'])
@requiere_permiso('devoluciones')
def crear():
    datos = request.get_json() or {}
    errores = {}

    if not datos.get('cliente_id'):
        errores['cliente_id'] = 'El cliente es requerido'
    error_detalles = _validar_detalles(datos.get('detalles'))
    if error_detalles:
        errores['detalles'] = error_detalles
    if errores:
        return jsonify({'errores': errores}), 422

    usuario = obtener_usuario_actual()
    d = Devolucion(
        cliente_id=datos['cliente_id'],
        venta_id=datos.get('venta_id'),
        usuario_id=usuario.id if usuario else None,
        nota=(datos.get('nota') or '').strip() or None,
        estado='pendiente',
        fecha=ahora_bolivia(),
    )
    db.session.add(d)
    db.session.flush()

    for item in datos['detalles']:
        db.session.add(DetalleDevolucion(
            devolucion_id=d.id,
            producto_id=item['producto_id'],
            cantidad=item['cantidad'],
            motivo=item['motivo'],
            motivo_detalle=(item.get('motivo_detalle') or '').strip() or None,
        ))

    db.session.commit()
    return jsonify(d.to_dict()), 201


@bp_devoluciones.route('/devoluciones/<int:id>', methods=['PUT'])
@requiere_permiso('devoluciones')
def actualizar(id):
    d = Devolucion.query.get_or_404(id)
    datos = request.get_json() or {}
    errores = {}

    if 'cliente_id' in datos and not datos['cliente_id']:
        errores['cliente_id'] = 'El cliente es requerido'
    if 'detalles' in datos:
        error_detalles = _validar_detalles(datos['detalles'])
        if error_detalles:
            errores['detalles'] = error_detalles
    if errores:
        return jsonify({'errores': errores}), 422

    if 'cliente_id' in datos: d.cliente_id = datos['cliente_id']
    if 'venta_id' in datos: d.venta_id = datos['venta_id']
    if 'nota' in datos: d.nota = (datos['nota'] or '').strip() or None

    if 'detalles' in datos:
        DetalleDevolucion.query.filter_by(devolucion_id=d.id).delete()
        for item in datos['detalles']:
            db.session.add(DetalleDevolucion(
                devolucion_id=d.id,
                producto_id=item['producto_id'],
                cantidad=item['cantidad'],
                motivo=item['motivo'],
                motivo_detalle=(item.get('motivo_detalle') or '').strip() or None,
            ))

    db.session.commit()
    return jsonify(d.to_dict())


@bp_devoluciones.route('/devoluciones/<int:id>/resolver', methods=['POST'])
@requiere_permiso('devoluciones')
def resolver(id):
    d = Devolucion.query.get_or_404(id)
    datos = request.get_json() or {}

    d.estado = 'resuelta'
    d.fecha_resolucion = ahora_bolivia()
    if datos.get('venta_resolucion_id'):
        d.venta_resolucion_id = datos['venta_resolucion_id']

    db.session.commit()
    return jsonify(d.to_dict())


@bp_devoluciones.route('/devoluciones/<int:id>', methods=['DELETE'])
@requiere_permiso('devoluciones')
def eliminar(id):
    d = Devolucion.query.get_or_404(id)
    db.session.delete(d)
    db.session.commit()
    return jsonify({'mensaje': 'Devolución eliminada permanentemente'})
