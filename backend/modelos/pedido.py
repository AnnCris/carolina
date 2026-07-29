from extensions import db
from datetime import datetime
 
class Pedido(db.Model):
    __tablename__ = 'pedidos'
    id             = db.Column(db.Integer, primary_key=True)
    cliente_id     = db.Column(db.Integer, db.ForeignKey('clientes.id'))
    usuario_id     = db.Column(db.Integer, db.ForeignKey('usuarios.id'))
    fecha          = db.Column(db.DateTime, default=datetime.utcnow)
    fecha_entrega  = db.Column(db.Date)
    estado         = db.Column(db.String(30), default='pendiente')
    total_estimado = db.Column(db.Numeric(12, 2), default=0)
    nota           = db.Column(db.Text)
 
    cliente  = db.relationship('Cliente', backref='pedidos')
    usuario  = db.relationship('Usuario', backref='pedidos_usuario')
    detalles = db.relationship('DetallePedido', backref='pedido',
                               lazy='dynamic', cascade='all, delete-orphan')
 
    @property
    def cliente_nombre(self):
        if not self.cliente:
            return None
        partes = [self.cliente.nombre]
        if self.cliente.apellido_paterno:
            partes.append(self.cliente.apellido_paterno)
        return ' '.join(partes)
 
    def to_dict(self):
        return {
            'id':             self.id,
            'cliente_id':     self.cliente_id,
            'cliente':        self.cliente_nombre,
            'usuario':        self.usuario.nombre if self.usuario else None,
            'fecha':          str(self.fecha),
            'fecha_entrega':  str(self.fecha_entrega)
                              if self.fecha_entrega else None,
            'estado':         self.estado,
            'nota':           self.nota,
            'detalles':       [d.to_dict() for d in self.detalles],
        }
 
 
class DetallePedido(db.Model):
    __tablename__ = 'detalle_pedidos'
    id              = db.Column(db.Integer, primary_key=True)
    pedido_id       = db.Column(db.Integer, db.ForeignKey('pedidos.id'))
    producto_id     = db.Column(db.Integer, db.ForeignKey('productos.id'))
    cantidad        = db.Column(db.Numeric(10, 2))
 
    producto = db.relationship('Producto')
 
    def to_dict(self):
        return {
            'id':              self.id,
            'producto_id':     self.producto_id,
            'producto':        self.producto.nombre if self.producto else None,
            'cantidad':        float(self.cantidad or 0),
        }
 
 