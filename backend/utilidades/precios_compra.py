# carolina/backend/utilidades/precios_compra.py
"""
El precio de compra de un producto ya NO se ingresa a mano en el
módulo de Precios — se registra automáticamente cada vez que se
guarda una Compra real, por proveedor (el mismo producto puede costar
distinto según a quién se le compre). El módulo de Precios solo pide
el precio de venta y muestra este historial como referencia.
"""
from extensions import db
from modelos.precio import Precio


def registrar_precio_compra(producto_id, proveedor_id, precio):
    """Guarda el precio realmente pagado a un proveedor por un
    producto, desactivando el anterior para esa combinación exacta."""
    if not precio or float(precio) <= 0:
        return
    Precio.query.filter_by(
        producto_id=producto_id, tipo='compra',
        proveedor_id=proveedor_id, activo=True
    ).update({'activo': False})
    db.session.add(Precio(
        producto_id=producto_id, tipo='compra',
        proveedor_id=proveedor_id, precio=float(precio),
        moneda='BOB', activo=True))


def precios_compra_por_producto(producto_id):
    """Todas las combinaciones proveedor -> último precio de compra
    activo para un producto (una por proveedor)."""
    precios = (Precio.query
               .filter_by(producto_id=producto_id, tipo='compra', activo=True)
               .order_by(Precio.vigente_desde.desc())
               .all())
    return [p.to_dict() for p in precios]


def precio_compra_referencia(producto_id):
    """El precio de compra más reciente (de cualquier proveedor), para
    usar como referencia en el cálculo de ganancia del módulo Precios."""
    precio = (Precio.query
              .filter_by(producto_id=producto_id, tipo='compra', activo=True)
              .order_by(Precio.vigente_desde.desc(), Precio.id.desc())
              .first())
    return precio


def ultimo_precio_compra(producto_id, proveedor_id=None):
    """Último precio pagado por este producto. Si se indica proveedor
    y existe historial con él, se usa ese; si no, cae al más reciente
    de cualquier proveedor (marcado como sugerencia, no exacto)."""
    if proveedor_id:
        precio = Precio.query.filter_by(
            producto_id=producto_id, tipo='compra',
            proveedor_id=proveedor_id, activo=True).first()
        if precio:
            return {'precio': float(precio.precio), 'mismo_proveedor': True}

    precio = precio_compra_referencia(producto_id)
    if precio:
        return {'precio': float(precio.precio), 'mismo_proveedor': False}
    return None
