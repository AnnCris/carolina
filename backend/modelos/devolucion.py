# carolina/backend/modelos/devolucion.py
from app import db
from datetime import datetime

class Devolucion(db.Model):
    __tablename__ = 'devoluciones'
    id = db.Column(db.Integer, primary_key=True)
    venta_id = db.Column(db.Integer, db.ForeignKey('ventas.id'), nullable=True)
    compra_id = db.Column(db.Integer, db.ForeignKey('compras.id'), nullable=True)
    tipo = db.Column(db.String(20), nullable=False)
    usuario_id = db.Column(db.Integer, db.ForeignKey('usuarios.id'))
    fecha = db.Column(db.DateTime, default=datetime.utcnow)
    motivo = db.Column(db.Text)
    total = db.Column(db.Numeric(12, 2))
    estado = db.Column(db.String(30), default='pendiente')
    imagen = db.Column(db.String(255))

    usuario = db.relationship('Usuario', backref='devoluciones')
    detalles = db.relationship('DetalleDevolucion', backref='devolucion', lazy='dynamic')

    def to_dict(self):
        return {
            'id': self.id, 'tipo': self.tipo,
            'venta_id': self.venta_id, 'compra_id': self.compra_id,
            'usuario': self.usuario.nombre if self.usuario else None,
            'fecha': str(self.fecha), 'motivo': self.motivo,
            'total': float(self.total) if self.total else 0,
            'estado': self.estado,
            'imagen': f'/api/subidas/{self.imagen}' if self.imagen else None,
            'detalles': [d.to_dict() for d in self.detalles]
        }

class DetalleDevolucion(db.Model):
    __tablename__ = 'detalle_devoluciones'
    id = db.Column(db.Integer, primary_key=True)
    devolucion_id = db.Column(db.Integer, db.ForeignKey('devoluciones.id'))
    producto_id = db.Column(db.Integer, db.ForeignKey('productos.id'))
    cantidad = db.Column(db.Numeric(10, 3))
    precio_unitario = db.Column(db.Numeric(12, 2))

    producto = db.relationship('Producto', backref='detalles_devolucion')

    def to_dict(self):
        return {
            'id': self.id, 'producto_id': self.producto_id,
            'producto': self.producto.nombre if self.producto else None,
            'cantidad': float(self.cantidad),
            'precio_unitario': float(self.precio_unitario)
        }