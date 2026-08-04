# carolina/backend/rutas/precios.py
from flask import Blueprint, request, jsonify
from extensions import db
from modelos.precio import Precio
from utilidades.permisos import requiere_permiso
from utilidades.precios_compra import (
    precio_compra_referencia, precios_compra_por_producto, ultimo_precio_compra,
)

bp_precios = Blueprint('precios', __name__)


@bp_precios.route('/precios', methods=['GET'])
@requiere_permiso('productos_ver')
def listar():
    """Devuelve el precio de venta (editable) de cada producto, junto
    con el precio de compra de referencia (el más reciente registrado
    en Compras — no se ingresa a mano)."""
    from modelos.producto import Producto

    productos = Producto.query.filter_by(activo=True).order_by(
        Producto.nombre.asc()).all()

    resultado = []
    for prod in productos:
        precio_venta = Precio.query.filter_by(
            producto_id=prod.id, tipo='venta', activo=True).first()
        pc_referencia = precio_compra_referencia(prod.id)

        pv = float(precio_venta.precio) if precio_venta else None
        pc = float(pc_referencia.precio) if pc_referencia else None

        ganancia     = round(pv - pc, 2)      if pv and pc else None
        ganancia_pct = round((ganancia / pc) * 100, 1) \
                       if ganancia and pc else None

        resultado.append({
            'producto_id':      prod.id,
            'producto':         prod.nombre,
            'categoria':        prod.categoria.nombre
                                if prod.categoria else None,
            'precio_venta_id':  precio_venta.id if precio_venta else None,
            'precio_venta':     pv,
            'precio_compra':    pc,
            'precio_compra_proveedor':
                pc_referencia.proveedor.nombre_completo
                if pc_referencia and pc_referencia.proveedor else None,
            'precios_compra':   precios_compra_por_producto(prod.id),
            'ganancia':         ganancia,
            'ganancia_pct':     ganancia_pct,
            'moneda':           'BOB',
        })

    return jsonify(resultado)


@bp_precios.route('/precios/producto/<int:producto_id>', methods=['GET'])
@requiere_permiso('productos_ver')
def obtener_por_producto(producto_id):
    precio_venta = Precio.query.filter_by(
        producto_id=producto_id, tipo='venta', activo=True).first()
    return jsonify({
        'precio_venta':   precio_venta.to_dict() if precio_venta else None,
        'precios_compra': precios_compra_por_producto(producto_id),
    })


@bp_precios.route('/precios/guardar', methods=['POST'])
@requiere_permiso('productos')
def guardar():
    """
    Guarda el precio de venta de un producto. El precio de compra ya
    no se ingresa aquí: se registra solo al hacer una Compra real
    (por proveedor), para que refleje lo que realmente se paga.
    Body: { producto_id, precio_venta }
    """
    datos   = request.get_json() or {}
    errores = {}

    producto_id = datos.get('producto_id')
    if not producto_id:
        errores['producto_id'] = 'El producto es requerido'

    precio_venta = datos.get('precio_venta')
    if precio_venta is None:
        errores['precio_venta'] = 'El precio de venta es requerido'
        pv = None
    else:
        try:
            pv = float(precio_venta)
            if pv <= 0:
                errores['precio_venta'] = 'Debe ser mayor a 0'
        except (ValueError, TypeError):
            errores['precio_venta'] = 'Valor inválido'
            pv = None

    if errores:
        return jsonify({'errores': errores}), 422

    Precio.query.filter_by(
        producto_id=producto_id, tipo='venta', activo=True
    ).update({'activo': False})
    db.session.add(Precio(
        producto_id=producto_id, tipo='venta',
        precio=pv, moneda='BOB', activo=True))

    db.session.commit()
    return jsonify({'mensaje': 'Precio de venta guardado correctamente'}), 200


@bp_precios.route('/precios/<int:id>', methods=['PUT'])
@requiere_permiso('productos')
def actualizar(id):
    p       = Precio.query.get_or_404(id)
    datos   = request.get_json() or {}
    errores = {}

    if 'precio' in datos:
        try:
            val = float(datos['precio'])
            if val <= 0:
                errores['precio'] = 'Debe ser mayor a 0'
            else:
                p.precio = val
        except (ValueError, TypeError):
            errores['precio'] = 'Valor inválido'

    if errores:
        return jsonify({'errores': errores}), 422

    db.session.commit()
    return jsonify(p.to_dict())


@bp_precios.route('/precios/<int:id>', methods=['DELETE'])
@requiere_permiso('productos')
def eliminar(id):
    p = Precio.query.get_or_404(id)
    db.session.delete(p)
    db.session.commit()
    return jsonify({'mensaje': 'Precio eliminado'})


@bp_precios.route('/precios/producto/<int:producto_id>/compra', methods=['GET'])
@requiere_permiso('compras')
def precio_compra(producto_id):
    """Sugerencia de precio de compra para armar una Compra nueva.
    Si se pasa ?proveedor_id=, prioriza el último precio pagado a ESE
    proveedor; si no hay historial con él, sugiere el más reciente de
    cualquier proveedor (marcado como mismo_proveedor=False)."""
    proveedor_id = request.args.get('proveedor_id', type=int)
    sugerencia = ultimo_precio_compra(producto_id, proveedor_id)
    if sugerencia:
        return jsonify({
            'precio': sugerencia['precio'],
            'mismo_proveedor': sugerencia['mismo_proveedor'],
            'moneda': 'BOB',
        })
    return jsonify({'precio': None, 'mismo_proveedor': False})
