# carolina/backend/modelos/devolucion.py
from extensions import db
from utilidades.tiempo import ahora_bolivia

# Motivos estándar — 'otro' permite detalle libre en motivo_detalle
MOTIVOS_VALIDOS = ['vencido', 'danado', 'perdio_vacio', 'otro']


class Devolucion(db.Model):
    __tablename__ = 'devoluciones'
    id = db.Column(db.Integer, primary_key=True)
    cliente_id = db.Column(db.Integer, db.ForeignKey('clientes.id'), nullable=False)
    venta_id = db.Column(db.Integer, db.ForeignKey('ventas.id'), nullable=True)
    usuario_id = db.Column(db.Integer, db.ForeignKey('usuarios.id'))
    fecha = db.Column(db.DateTime, default=ahora_bolivia)
    estado = db.Column(db.String(20), default='pendiente')  # pendiente | resuelta
    nota = db.Column(db.Text)

    fecha_resolucion = db.Column(db.DateTime, nullable=True)
    venta_resolucion_id = db.Column(db.Integer, db.ForeignKey('ventas.id'), nullable=True)

    cliente = db.relationship('Cliente', backref='devoluciones')
    usuario = db.relationship('Usuario', backref='devoluciones')
    venta = db.relationship('Venta', foreign_keys=[venta_id])
    venta_resolucion = db.relationship('Venta', foreign_keys=[venta_resolucion_id])
    detalles = db.relationship('DetalleDevolucion', backref='devolucion',
                                lazy='dynamic', cascade='all, delete-orphan')

    def to_dict(self):
        return {
            'id': self.id,
            'cliente_id': self.cliente_id,
            'cliente': self.cliente.nombre_completo if self.cliente else None,
            'venta_id': self.venta_id,
            'venta_numero_recibo': self.venta.numero_recibo if self.venta else None,
            'usuario': self.usuario.nombre if self.usuario else None,
            'fecha': str(self.fecha),
            'estado': self.estado,
            'nota': self.nota,
            'fecha_resolucion': str(self.fecha_resolucion) if self.fecha_resolucion else None,
            'venta_resolucion_id': self.venta_resolucion_id,
            'venta_resolucion_numero_recibo':
                self.venta_resolucion.numero_recibo if self.venta_resolucion else None,
            'detalles': [d.to_dict() for d in self.detalles],
        }


class DetalleDevolucion(db.Model):
    __tablename__ = 'detalle_devoluciones'
    id = db.Column(db.Integer, primary_key=True)
    devolucion_id = db.Column(db.Integer, db.ForeignKey('devoluciones.id'))
    producto_id = db.Column(db.Integer, db.ForeignKey('productos.id'))
    cantidad = db.Column(db.Numeric(10, 3))
    motivo = db.Column(db.String(30))          # vencido | danado | perdio_vacio | otro
    motivo_detalle = db.Column(db.Text)         # detalle libre (obligatorio si motivo='otro')

    producto = db.relationship('Producto')

    def to_dict(self):
        return {
            'id': self.id,
            'producto_id': self.producto_id,
            'producto': self.producto.nombre if self.producto else None,
            'cantidad': float(self.cantidad) if self.cantidad else 0,
            'motivo': self.motivo,
            'motivo_detalle': self.motivo_detalle,
        }
