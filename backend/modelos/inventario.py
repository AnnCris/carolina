from extensions import db
from datetime import datetime
 
 
class Inventario(db.Model):
    __tablename__ = 'inventario'
    id               = db.Column(db.Integer, primary_key=True)
    producto_id      = db.Column(db.Integer,
                           db.ForeignKey('productos.id'), unique=True)
    stock_actual     = db.Column(db.Numeric(12, 2), default=0)
    stock_minimo     = db.Column(db.Numeric(12, 2), default=0)
    stock_maximo     = db.Column(db.Numeric(12, 2), nullable=True)
    metodo_valuacion = db.Column(db.String(10), default='PEPS')
    ultima_entrada   = db.Column(db.DateTime, nullable=True)
    ultima_salida    = db.Column(db.DateTime, nullable=True)
    updated_at       = db.Column(db.DateTime, default=datetime.utcnow,
                                 onupdate=datetime.utcnow)
 
    @property
    def estado_stock(self):
        actual = float(self.stock_actual or 0)
        minimo = float(self.stock_minimo or 0)
        maximo = float(self.stock_maximo) if self.stock_maximo else None
        if actual <= 0:
            return 'sin_stock'
        if minimo > 0 and actual <= minimo:
            return 'critico'
        if maximo and actual >= maximo:
            return 'sobrestock'
        return 'normal'
 
    def to_dict(self):
        from modelos.producto import Producto as P
        prod = P.query.get(self.producto_id)
        return {
            'id':               self.id,
            'producto_id':      self.producto_id,
            'producto':         prod.nombre if prod else None,
            'categoria':        prod.categoria.nombre
                                if prod and prod.categoria else None,
            'stock_actual':     float(self.stock_actual or 0),
            'stock_minimo':     float(self.stock_minimo or 0),
            'stock_maximo':     float(self.stock_maximo)
                                if self.stock_maximo else None,
            'metodo_valuacion': self.metodo_valuacion,
            'estado_stock':     self.estado_stock,
            'ultima_entrada':   str(self.ultima_entrada)
                                if self.ultima_entrada else None,
            'ultima_salida':    str(self.ultima_salida)
                                if self.ultima_salida else None,
            'updated_at':       str(self.updated_at)
                                if self.updated_at else None,
        }
 
 
class MovimientoInventario(db.Model):
    __tablename__ = 'movimientos_inventario'
    id              = db.Column(db.Integer, primary_key=True)
    inventario_id   = db.Column(db.Integer, db.ForeignKey('inventario.id'))
    producto_id     = db.Column(db.Integer, db.ForeignKey('productos.id'))
    tipo            = db.Column(db.String(20))  # entrada | salida | ajuste
    cantidad        = db.Column(db.Numeric(12, 2))
    referencia_tipo = db.Column(db.String(30))  # compra | venta | ajuste_manual
    referencia_id   = db.Column(db.Integer, nullable=True)
    nota            = db.Column(db.Text)
    fecha           = db.Column(db.DateTime, default=datetime.utcnow)
    usuario_id      = db.Column(db.Integer,
                          db.ForeignKey('usuarios.id'), nullable=True)
 
    def to_dict(self):
        from modelos.producto import Producto as P
        prod = P.query.get(self.producto_id)
        return {
            'id':              self.id,
            'producto_id':     self.producto_id,
            'producto':        prod.nombre if prod else None,
            'tipo':            self.tipo,
            'cantidad':        float(self.cantidad or 0),
            'referencia_tipo': self.referencia_tipo,
            'referencia_id':   self.referencia_id,
            'nota':            self.nota,
            'fecha':           str(self.fecha),
        }
 
 