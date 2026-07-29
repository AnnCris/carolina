# carolina/backend/rutas/precios.py
from flask import Blueprint, request, jsonify
from extensions import db
from modelos.precio import Precio
from utilidades.permisos import requiere_permiso

bp_precios = Blueprint('precios', __name__)


@bp_precios.route('/precios', methods=['GET'])
@requiere_permiso('productos_ver')
def listar():
    """Devuelve todos los precios activos agrupados por producto."""
    from modelos.producto import Producto

    productos = Producto.query.filter_by(activo=True).order_by(
        Producto.nombre.asc()).all()

    resultado = []
    for prod in productos:
        precio_venta  = Precio.query.filter_by(
            producto_id=prod.id, tipo='venta', activo=True).first()
        precio_compra = Precio.query.filter_by(
            producto_id=prod.id, tipo='compra', activo=True).first()

        pv = float(precio_venta.precio)  if precio_venta  else None
        pc = float(precio_compra.precio) if precio_compra else None

        ganancia     = round(pv - pc, 2)      if pv and pc else None
        ganancia_pct = round((ganancia / pc) * 100, 1) \
                       if ganancia and pc else None

        resultado.append({
            'producto_id':    prod.id,
            'producto':       prod.nombre,
            'categoria':      prod.categoria.nombre
                              if prod.categoria else None,
            'precio_venta_id':  precio_venta.id  if precio_venta  else None,
            'precio_compra_id': precio_compra.id if precio_compra else None,
            'precio_venta':   pv,
            'precio_compra':  pc,
            'ganancia':       ganancia,
            'ganancia_pct':   ganancia_pct,
            'moneda':         'BOB',
        })

    return jsonify(resultado)


@bp_precios.route('/precios/producto/<int:producto_id>', methods=['GET'])
@requiere_permiso('productos_ver')
def obtener_por_producto(producto_id):
    precio_venta  = Precio.query.filter_by(
        producto_id=producto_id, tipo='venta', activo=True).first()
    precio_compra = Precio.query.filter_by(
        producto_id=producto_id, tipo='compra', activo=True).first()
    return jsonify({
        'precio_venta':  precio_venta.to_dict()  if precio_venta  else None,
        'precio_compra': precio_compra.to_dict() if precio_compra else None,
    })


@bp_precios.route('/precios/guardar', methods=['POST'])
@requiere_permiso('productos')
def guardar():
    """
    Guarda precio de venta y/o compra para un producto en una sola llamada.
    Body: { producto_id, precio_venta, precio_compra }
    """
    datos   = request.get_json() or {}
    errores = {}

    producto_id = datos.get('producto_id')
    if not producto_id:
        errores['producto_id'] = 'El producto es requerido'

    precio_venta  = datos.get('precio_venta')
    precio_compra = datos.get('precio_compra')

    if precio_venta is not None:
        try:
            pv = float(precio_venta)
            if pv <= 0:
                errores['precio_venta'] = 'Debe ser mayor a 0'
        except (ValueError, TypeError):
            errores['precio_venta'] = 'Valor inválido'
            pv = None
    else:
        pv = None

    if precio_compra is not None:
        try:
            pc = float(precio_compra)
            if pc <= 0:
                errores['precio_compra'] = 'Debe ser mayor a 0'
        except (ValueError, TypeError):
            errores['precio_compra'] = 'Valor inválido'
            pc = None
    else:
        pc = None

    if pv is not None and pc is not None and pv < pc:
        errores['precio_venta'] = \
            'El precio de venta no puede ser menor al de compra'

    if errores:
        return jsonify({'errores': errores}), 422

    # Guardar precio de venta
    if pv is not None:
        Precio.query.filter_by(
            producto_id=producto_id, tipo='venta', activo=True
        ).update({'activo': False})
        db.session.add(Precio(
            producto_id=producto_id, tipo='venta',
            precio=pv, moneda='BOB', activo=True))

    # Guardar precio de compra
    if pc is not None:
        Precio.query.filter_by(
            producto_id=producto_id, tipo='compra', activo=True
        ).update({'activo': False})
        db.session.add(Precio(
            producto_id=producto_id, tipo='compra',
            precio=pc, moneda='BOB', activo=True))

    db.session.commit()
    return jsonify({'mensaje': 'Precios guardados correctamente'}), 200


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
    """Devuelve el precio de compra activo de un producto."""
    precio = Precio.query.filter_by(
        producto_id = producto_id,
        tipo        = 'compra',
        activo      = True
    ).first()
    if precio:
        return jsonify({'precio': float(precio.precio), 'moneda': precio.moneda})
    return jsonify({'precio': None})