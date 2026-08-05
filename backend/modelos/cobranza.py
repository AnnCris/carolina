# carolina/backend/modelos/cobranza.py
"""
Una Cobranza es un cobro que se le hace a un cliente: puede saldar
una sola cuenta pendiente (una venta) o varias de una sola vez —
por eso tiene su propio detalle, igual que Compras, Ventas, Pedidos
y Devoluciones.
"""
from extensions import db
from utilidades.tiempo import ahora_bolivia

METODOS_PAGO_VALIDOS = ['efectivo', 'qr', 'transferencia']


class Cobranza(db.Model):
    __tablename__ = 'cobranzas'
    id = db.Column(db.Integer, primary_key=True)
    cliente_id = db.Column(db.Integer, db.ForeignKey('clientes.id'), nullable=False)
    usuario_id = db.Column(db.Integer, db.ForeignKey('usuarios.id'))
    fecha = db.Column(db.DateTime, default=ahora_bolivia)
    metodo_pago = db.Column(db.String(20), nullable=False)  # efectivo | qr | transferencia
    monto_total = db.Column(db.Numeric(12, 2), nullable=False)
    nota = db.Column(db.Text)

    cliente = db.relationship('Cliente', backref='cobranzas')
    usuario = db.relationship('Usuario')
    detalles = db.relationship('DetalleCobranza', backref='cobranza',
                                lazy='dynamic', cascade='all, delete-orphan')

    def to_dict(self):
        return {
            'id': self.id,
            'cliente_id': self.cliente_id,
            'cliente': self.cliente.nombre_completo if self.cliente else None,
            'usuario': self.usuario.nombre if self.usuario else None,
            'fecha': str(self.fecha),
            'metodo_pago': self.metodo_pago,
            'monto_total': float(self.monto_total) if self.monto_total else 0,
            'nota': self.nota,
            'detalles': [d.to_dict() for d in self.detalles],
        }


class DetalleCobranza(db.Model):
    """Cuánto de una Cobranza se aplicó a cada cuenta (venta) pendiente."""
    __tablename__ = 'detalle_cobranzas'
    id = db.Column(db.Integer, primary_key=True)
    cobranza_id = db.Column(db.Integer, db.ForeignKey('cobranzas.id'))
    venta_id = db.Column(db.Integer, db.ForeignKey('ventas.id'), nullable=False)
    monto = db.Column(db.Numeric(12, 2), nullable=False)

    venta = db.relationship('Venta', backref='detalles_cobranza')

    def to_dict(self):
        return {
            'id': self.id,
            'cobranza_id': self.cobranza_id,
            'venta_id': self.venta_id,
            'venta_numero_recibo': self.venta.numero_recibo if self.venta else None,
            'monto': float(self.monto) if self.monto else 0,
        }
