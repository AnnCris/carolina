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
    # 'detalles_cobranza' llega por el backref definido en DetalleCobranza.venta
    # (modelos/cobranza.py) — cada fila es cuánto de una Cobranza se aplicó
    # a esta venta.

    @property
    def monto_pagado(self):
        return sum(float(d.monto) for d in self.detalles_cobranza)

    @property
    def saldo_pendiente(self):
        if self.estado == 'anulada':
            return 0.0
        saldo = float(self.total or 0) - self.monto_pagado
        return round(saldo, 2) if saldo > 0.005 else 0.0

    @property
    def estado_pago(self):
        pagado = self.monto_pagado
        total = float(self.total or 0)
        if pagado <= 0.005:
            return 'pendiente'
        if pagado + 0.005 >= total:
            return 'pagado'
        return 'parcial'

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
            'detalles': [d.to_dict() for d in self.detalles],
            'monto_pagado': self.monto_pagado,
            'saldo_pendiente': self.saldo_pendiente,
            'estado_pago': self.estado_pago,
            'pagos': [
                {
                    'monto': float(d.monto) if d.monto else 0,
                    'metodo_pago': d.cobranza.metodo_pago if d.cobranza else None,
                    'fecha': str(d.cobranza.fecha) if d.cobranza else None,
                    'cobranza_id': d.cobranza_id,
                }
                for d in self.detalles_cobranza
            ],
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
    # Si no es None, esta línea es el producto de reemplazo entregado por
    # esa devolución (precio/subtotal siempre 0, no es una venta nueva).
    devolucion_id = db.Column(db.Integer, db.ForeignKey('devoluciones.id'), nullable=True)

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
            'devolucion_id': self.devolucion_id,
        }
