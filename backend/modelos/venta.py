# carolina/backend/modelos/venta.py
from extensions import db
from utilidades.tiempo import ahora_bolivia

class Venta(db.Model):
    __tablename__ = 'ventas'
    id = db.Column(db.Integer, primary_key=True)
    cliente_id = db.Column(db.Integer, db.ForeignKey('clientes.id'))
    usuario_id = db.Column(db.Integer, db.ForeignKey('usuarios.id'))
    pedido_id = db.Column(db.Integer, db.ForeignKey('pedidos.id'), nullable=True)
    fecha = db.Column(db.DateTime, default=ahora_bolivia)
    total = db.Column(db.Numeric(12, 2))
    descuento = db.Column(db.Numeric(12, 2), default=0)
    estado = db.Column(db.String(30), default='completada')
    nota = db.Column(db.Text)
    numero_recibo = db.Column(db.String(50), unique=True)

    cliente = db.relationship('Cliente', backref='ventas')
    usuario = db.relationship('Usuario', backref='ventas')
    pedido = db.relationship('Pedido', backref='ventas')
    detalles = db.relationship('DetalleVenta', backref='venta', lazy='dynamic')

    def to_dict(self):
        return {
            'id': self.id,
            'cliente_id': self.cliente_id,
            'cliente': self.cliente.nombre if self.cliente else 'Sin cliente',
            'usuario': self.usuario.nombre if self.usuario else None,
            'pedido_id': self.pedido_id,
            'fecha': str(self.fecha),
            'total': float(self.total) if self.total else 0,
            'descuento': float(self.descuento) if self.descuento else 0,
            'estado': self.estado,
            'nota': self.nota,
            'numero_recibo': self.numero_recibo,
            'detalles': [d.to_dict() for d in self.detalles]
        }

class DetalleVenta(db.Model):
    __tablename__ = 'detalle_ventas'
    id = db.Column(db.Integer, primary_key=True)
    venta_id = db.Column(db.Integer, db.ForeignKey('ventas.id'))
    producto_id = db.Column(db.Integer, db.ForeignKey('productos.id'))
    cantidad = db.Column(db.Numeric(10, 3))
    precio_unitario = db.Column(db.Numeric(12, 2))
    subtotal = db.Column(db.Numeric(12, 2))
    peso_kg = db.Column(db.Numeric(10, 3))
    precio_editado = db.Column(db.Boolean, default=False)

    producto = db.relationship('Producto', backref='detalles_venta')

    def to_dict(self):
        return {
            'id': self.id, 'producto_id': self.producto_id,
            'producto': self.producto.nombre if self.producto else None,
            'cantidad': float(self.cantidad),
            'precio_unitario': float(self.precio_unitario),
            'subtotal': float(self.subtotal),
            'peso_kg': float(self.peso_kg) if self.peso_kg else None,
            'precio_editado': bool(self.precio_editado),
        }
