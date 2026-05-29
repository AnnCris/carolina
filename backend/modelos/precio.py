# carolina/backend/modelos/precio.py
from extensions import db
from datetime import date

class Precio(db.Model):
    __tablename__ = 'precios'
    id = db.Column(db.Integer, primary_key=True)
    producto_id = db.Column(db.Integer, db.ForeignKey('productos.id'))
    tipo = db.Column(db.String(20), nullable=False)  # compra | venta
    proveedor_id = db.Column(db.Integer, db.ForeignKey('proveedores.id'), nullable=True)
    precio = db.Column(db.Numeric(12, 2), nullable=False)
    moneda = db.Column(db.String(5), default='BOB')
    vigente_desde = db.Column(db.Date, default=date.today)
    activo = db.Column(db.Boolean, default=True)

    proveedor = db.relationship('Proveedor', backref='precios')

    def to_dict(self):
        return {
            'id': self.id, 'producto_id': self.producto_id,
            'tipo': self.tipo, 'proveedor_id': self.proveedor_id,
            'proveedor': self.proveedor.nombre if self.proveedor else None,
            'precio': float(self.precio), 'moneda': self.moneda,
            'vigente_desde': str(self.vigente_desde), 'activo': self.activo
        }
