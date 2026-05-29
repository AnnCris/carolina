# carolina/backend/modelos/compra.py
from extensions import db
from datetime import datetime

class Compra(db.Model):
    __tablename__ = 'compras'
    id             = db.Column(db.Integer, primary_key=True)
    proveedor_id   = db.Column(db.Integer, db.ForeignKey('proveedores.id'))
    usuario_id     = db.Column(db.Integer, db.ForeignKey('usuarios.id'))
    fecha          = db.Column(db.DateTime, default=datetime.utcnow)
    total          = db.Column(db.Numeric(12, 2))
    estado         = db.Column(db.String(30), default='recibida')
    nota           = db.Column(db.Text)
    imagen_factura = db.Column(db.String(255))

    proveedor = db.relationship('Proveedor', backref='compras')
    usuario   = db.relationship('Usuario',   backref='compras_usuario')
    detalles  = db.relationship('DetalleCompra', backref='compra',
                                lazy='dynamic', cascade='all, delete-orphan')

    def to_dict(self):
        return {
            'id':             self.id,
            'proveedor_id':   self.proveedor_id,
            'proveedor':      self.proveedor.nombre_completo if self.proveedor else None,
            'usuario':        self.usuario.nombre if self.usuario else None,
            'fecha':          str(self.fecha),
            'total':          float(self.total) if self.total else 0,
            'estado':         self.estado,
            'nota':           self.nota,
            'imagen_factura': f'/api/subidas/{self.imagen_factura}'
                              if self.imagen_factura else None,
            'detalles':       [d.to_dict() for d in self.detalles],
        }


class DetalleCompra(db.Model):
    __tablename__ = 'detalle_compras'
    id              = db.Column(db.Integer, primary_key=True)
    compra_id       = db.Column(db.Integer, db.ForeignKey('compras.id'))
    producto_id     = db.Column(db.Integer, db.ForeignKey('productos.id'))
    cantidad        = db.Column(db.Numeric(10, 3))
    peso_total_kg   = db.Column(db.Numeric(10, 3))
    precio_unitario = db.Column(db.Numeric(12, 2))
    subtotal        = db.Column(db.Numeric(12, 2))
    unidades_x_caja = db.Column(db.Integer)
    num_cajas       = db.Column(db.Integer)
    tipo_precio     = db.Column(db.String(20), default='por_unidad')

    # SIN backref — evita conflicto con otros modelos que apuntan a Producto
    producto = db.relationship('Producto')

    def to_dict(self):
        return {
            'id':              self.id,
            'producto_id':     self.producto_id,
            'producto':        self.producto.nombre if self.producto else None,
            'cantidad':        float(self.cantidad) if self.cantidad else 0,
            'peso_total_kg':   float(self.peso_total_kg) if self.peso_total_kg else None,
            'precio_unitario': float(self.precio_unitario) if self.precio_unitario else 0,
            'subtotal':        float(self.subtotal) if self.subtotal else 0,
            'unidades_x_caja': self.unidades_x_caja,
            'num_cajas':       self.num_cajas,
            'tipo_precio':     self.tipo_precio,
        }