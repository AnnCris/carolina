# carolina/backend/rutas/compras.py
from flask import Blueprint, request, jsonify, current_app
from extensions import db
from modelos.compra import Compra, DetalleCompra
from modelos.inventario import Inventario, MovimientoInventario
from utilidades.permisos import requiere_permiso, obtener_usuario_actual
from utilidades.precios_compra import registrar_precio_compra
from datetime import datetime
import uuid, os

bp_compras = Blueprint('compras', __name__)

ESTADOS_VALIDOS = ['recibida', 'pendiente', 'cancelada']


def _unidades_detalle(item_dict):
    """Calcula unidades totales de un ítem (num_cajas × unidades_x_caja)."""
    return float(
        int(item_dict.get('num_cajas', 1) or 1) *
        int(item_dict.get('unidades_x_caja', 1) or 1)
    )


def _unidades_detalle_obj(det):
    """Calcula unidades de un objeto DetalleCompra guardado."""
    return float((det.num_cajas or 1) * (det.unidades_x_caja or 1))


def _calcular_detalle(item):
    tipo_precio     = item.get('tipo_precio', 'por_unidad')
    precio_unitario = float(item.get('precio_unitario', 0))
    unidades_x_caja = int(item.get('unidades_x_caja', 1) or 1)
    num_cajas       = int(item.get('num_cajas', 1) or 1)
    unidades        = float(num_cajas * unidades_x_caja)

    if tipo_precio == 'por_kg':
        peso_total_kg = float(item.get('peso_total_kg', 0))
        subtotal      = precio_unitario * peso_total_kg
    else:
        peso_total_kg = None
        subtotal      = precio_unitario * unidades

    return {
        'tipo_precio':     tipo_precio,
        'precio_unitario': precio_unitario,
        'unidades_x_caja': unidades_x_caja,
        'num_cajas':       num_cajas,
        'cantidad':        unidades,
        'peso_total_kg':   peso_total_kg,
        'subtotal':        round(subtotal, 2),
        'unidades':        unidades,
    }


def _sumar_stock(inv, producto_id, unidades, compra_id, nota, usuario_id):
    """Suma unidades al inventario y registra movimiento PEPS."""
    inv.stock_actual   = float(inv.stock_actual or 0) + unidades
    inv.ultima_entrada = datetime.utcnow()
    db.session.add(MovimientoInventario(
        inventario_id   = inv.id,
        producto_id     = producto_id,
        tipo            = 'entrada',
        cantidad        = unidades,
        referencia_tipo = 'compra',
        referencia_id   = compra_id,
        nota            = nota,
        usuario_id      = usuario_id,
    ))


def _restar_stock(inv, producto_id, unidades, compra_id, nota, usuario_id):
    """Resta unidades del inventario y registra movimiento PEPS."""
    inv.stock_actual = max(0, float(inv.stock_actual or 0) - unidades)
    db.session.add(MovimientoInventario(
        inventario_id   = inv.id,
        producto_id     = producto_id,
        tipo            = 'salida',
        cantidad        = unidades,
        referencia_tipo = 'compra',
        referencia_id   = compra_id,
        nota            = nota,
        usuario_id      = usuario_id,
    ))


# ─── LISTAR ───────────────────────────────────────────────────────────────────
@bp_compras.route('/compras', methods=['GET'])
@requiere_permiso('compras')
def listar():
    compras = Compra.query.order_by(Compra.fecha.desc()).all()
    return jsonify([c.to_dict() for c in compras])


@bp_compras.route('/compras/<int:id>', methods=['GET'])
@requiere_permiso('compras')
def obtener(id):
    c = Compra.query.get_or_404(id)
    return jsonify(c.to_dict())


# ─── CREAR ────────────────────────────────────────────────────────────────────
@bp_compras.route('/compras', methods=['POST'])
@requiere_permiso('compras')
def crear():
    datos   = request.get_json() or {}
    usuario = obtener_usuario_actual()
    errores = {}

    if not datos.get('proveedor_id'):
        errores['proveedor_id'] = 'El proveedor es requerido'
    if not datos.get('detalles') or len(datos['detalles']) == 0:
        errores['detalles'] = 'Debe agregar al menos un producto'

    estado = datos.get('estado', 'recibida')
    if estado not in ESTADOS_VALIDOS:
        errores['estado'] = f'Estado inválido. Usa: {", ".join(ESTADOS_VALIDOS)}'

    if errores:
        return jsonify({'errores': errores}), 422

    fecha_str = datos.get('fecha')
    if fecha_str:
        try:
            fecha = datetime.strptime(fecha_str, '%Y-%m-%d')
        except ValueError:
            fecha = datetime.utcnow()
    else:
        fecha = datetime.utcnow()

    compra = Compra(
        proveedor_id = datos['proveedor_id'],
        usuario_id   = usuario.id if usuario else None,
        fecha        = fecha,
        nota         = (datos.get('nota') or '').strip() or None,
        estado       = estado,
    )
    db.session.add(compra)
    db.session.flush()  # para tener compra.id

    total = 0.0
    for item in datos['detalles']:
        d = _calcular_detalle(item)
        detalle = DetalleCompra(
            compra          = compra,
            producto_id     = item['producto_id'],
            cantidad        = d['cantidad'],
            peso_total_kg   = d['peso_total_kg'],
            precio_unitario = d['precio_unitario'],
            subtotal        = d['subtotal'],
            unidades_x_caja = d['unidades_x_caja'],
            num_cajas       = d['num_cajas'],
            tipo_precio     = d['tipo_precio'],
        )
        db.session.add(detalle)
        total += d['subtotal']

        # El precio de compra se registra siempre (sin importar el
        # estado): es lo que se acordó pagar a este proveedor.
        registrar_precio_compra(
            item['producto_id'], compra.proveedor_id, d['precio_unitario'])

        # Solo suma stock si la compra fue RECIBIDA
        if estado == 'recibida':
            inv = Inventario.query.filter_by(
                producto_id=item['producto_id']).first()
            if inv:
                _sumar_stock(
                    inv, item['producto_id'], d['unidades'],
                    compra.id,
                    f"Compra #{compra.id} — {d['num_cajas']} cajas × {d['unidades_x_caja']} unid.",
                    usuario.id if usuario else None,
                )

    compra.total = round(total, 2)
    db.session.commit()
    return jsonify(compra.to_dict()), 201


# ─── ACTUALIZAR ───────────────────────────────────────────────────────────────
@bp_compras.route('/compras/<int:id>', methods=['PUT'])
@requiere_permiso('compras')
def actualizar(id):
    c       = Compra.query.get_or_404(id)
    datos   = request.get_json() or {}
    usuario = obtener_usuario_actual()

    estado_anterior = c.estado
    nuevo_estado    = datos.get('estado', estado_anterior)

    if nuevo_estado not in ESTADOS_VALIDOS:
        return jsonify({
            'error': f'Estado inválido. Usa: {", ".join(ESTADOS_VALIDOS)}'
        }), 422

    # ── Actualizar campos simples ─────────────────────────────────────────────
    if 'proveedor_id' in datos:
        c.proveedor_id = datos['proveedor_id']

    if 'nota' in datos:
        c.nota = (datos['nota'] or '').strip() or None

    if 'fecha' in datos and datos['fecha']:
        try:
            c.fecha = datetime.strptime(datos['fecha'], '%Y-%m-%d')
        except ValueError:
            return jsonify({'error': 'Formato de fecha inválido. Usa YYYY-MM-DD'}), 422

    # ── Cambio de estado con efecto en inventario ─────────────────────────────
    cambio_estado = nuevo_estado != estado_anterior
    c.estado      = nuevo_estado

    if cambio_estado:
        detalles_actuales = list(c.detalles)

        if estado_anterior != 'recibida' and nuevo_estado == 'recibida':
            # Pendiente/Cancelada → Recibida: SUMA stock
            for det in detalles_actuales:
                inv = Inventario.query.filter_by(
                    producto_id=det.producto_id).first()
                if inv:
                    unidades = _unidades_detalle_obj(det)
                    _sumar_stock(
                        inv, det.producto_id, unidades, c.id,
                        f'Compra #{c.id} marcada como recibida',
                        usuario.id if usuario else None,
                    )

        elif estado_anterior == 'recibida' and nuevo_estado != 'recibida':
            # Recibida → Pendiente/Cancelada: RESTA stock (devuelve)
            for det in detalles_actuales:
                inv = Inventario.query.filter_by(
                    producto_id=det.producto_id).first()
                if inv:
                    unidades = _unidades_detalle_obj(det)
                    _restar_stock(
                        inv, det.producto_id, unidades, c.id,
                        f'Compra #{c.id} cambiada a {nuevo_estado} — stock revertido',
                        usuario.id if usuario else None,
                    )
        # Pendiente ↔ Cancelada: no afecta stock (ninguno sumó)

    # ── Si cambian los detalles ───────────────────────────────────────────────
    if 'detalles' in datos and len(datos['detalles']) > 0:
        # Revertir stock solo si la compra estaba recibida
        if nuevo_estado == 'recibida':
            for det in c.detalles:
                inv = Inventario.query.filter_by(
                    producto_id=det.producto_id).first()
                if inv:
                    unidades = _unidades_detalle_obj(det)
                    _restar_stock(
                        inv, det.producto_id, unidades, c.id,
                        f'Reversión edición compra #{c.id}',
                        usuario.id if usuario else None,
                    )

        # Eliminar detalles anteriores
        for det in c.detalles:
            db.session.delete(det)

        total = 0.0
        for item in datos['detalles']:
            d = _calcular_detalle(item)
            detalle = DetalleCompra(
                compra          = c,
                producto_id     = item['producto_id'],
                cantidad        = d['cantidad'],
                peso_total_kg   = d['peso_total_kg'],
                precio_unitario = d['precio_unitario'],
                subtotal        = d['subtotal'],
                unidades_x_caja = d['unidades_x_caja'],
                num_cajas       = d['num_cajas'],
                tipo_precio     = d['tipo_precio'],
            )
            db.session.add(detalle)
            total += d['subtotal']

            registrar_precio_compra(
                item['producto_id'], c.proveedor_id, d['precio_unitario'])

            # Solo suma stock si está recibida
            if nuevo_estado == 'recibida':
                inv = Inventario.query.filter_by(
                    producto_id=item['producto_id']).first()
                if inv:
                    _sumar_stock(
                        inv, item['producto_id'], d['unidades'],
                        c.id,
                        f"Edición compra #{c.id} — {d['num_cajas']} cajas × {d['unidades_x_caja']} unid.",
                        usuario.id if usuario else None,
                    )

        c.total = round(total, 2)

    db.session.commit()
    return jsonify(c.to_dict())


# ─── ELIMINAR ─────────────────────────────────────────────────────────────────
@bp_compras.route('/compras/<int:id>', methods=['DELETE'])
@requiere_permiso('compras')
def eliminar(id):
    c       = Compra.query.get_or_404(id)
    usuario = obtener_usuario_actual()

    # Solo revierte stock si la compra estaba recibida
    if c.estado == 'recibida':
        for det in c.detalles:
            inv = Inventario.query.filter_by(
                producto_id=det.producto_id).first()
            if inv:
                unidades = _unidades_detalle_obj(det)
                _restar_stock(
                    inv, det.producto_id, unidades, c.id,
                    f'Eliminación compra #{c.id}',
                    usuario.id if usuario else None,
                )

    db.session.delete(c)
    db.session.commit()
    return jsonify({'mensaje': f'Compra eliminada. '
                               f'{"Stock revertido." if c.estado == "recibida" else "No afectó stock."}'})


# ─── FACTURA ──────────────────────────────────────────────────────────────────
@bp_compras.route('/compras/<int:id>/factura', methods=['POST'])
@requiere_permiso('compras')
def subir_factura(id):
    c = Compra.query.get_or_404(id)
    if 'factura' not in request.files:
        return jsonify({'error': 'No se envió imagen'}), 422
    archivo = request.files['factura']
    ext = archivo.filename.rsplit('.', 1)[-1].lower()
    if ext not in current_app.config.get(
            'ALLOWED_EXTENSIONS', {'jpg', 'jpeg', 'png'}):
        return jsonify({'error': 'Formato no permitido'}), 422
    nombre = f"factura_{uuid.uuid4().hex}.{ext}"
    archivo.save(os.path.join(
        current_app.config['UPLOAD_FOLDER'], nombre))
    c.imagen_factura = nombre
    db.session.commit()
    return jsonify({'imagen_factura': f'/api/subidas/{nombre}'}), 200