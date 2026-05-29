# carolina/backend/modelos/producto.py
from extensions import db
from datetime import datetime

class Producto(db.Model):
    __tablename__ = 'productos'
    id = db.Column(db.Integer, primary_key=True)
    nombre = db.Column(db.String(150), nullable=False)
    descripcion = db.Column(db.Text)
    categoria_id = db.Column(db.Integer, db.ForeignKey('categorias.id'))
    marca_id = db.Column(db.Integer, db.ForeignKey('marcas.id'))
    foto = db.Column(db.String(255))
    tipo_peso = db.Column(db.String(20), default='fijo')  # fijo | variable
    peso_gramos = db.Column(db.Numeric(10, 3))
    unidad = db.Column(db.String(20), default='unidad')
    codigo_barras = db.Column(db.String(100))
    activo = db.Column(db.Boolean, default=True)

    categoria = db.relationship('Categoria', backref='productos')
    marca = db.relationship('Marca', backref='productos')
    precios = db.relationship('Precio', backref='producto', lazy='dynamic')
    inventario = db.relationship('Inventario', uselist=False)

    def to_dict(self):
        return {
            'id': self.id,
            'nombre': self.nombre,
            'descripcion': self.descripcion,
            'categoria_id': self.categoria_id,
            'categoria': self.categoria.nombre if self.categoria else None,
            'marca_id': self.marca_id,
            'marca': self.marca.nombre if self.marca else None,
            'foto': f'/api/subidas/{self.foto}' if self.foto else None,
            'tipo_peso': self.tipo_peso,
            'peso_gramos': float(self.peso_gramos) if self.peso_gramos else None,
            'unidad': self.unidad,
            'codigo_barras': self.codigo_barras,
            'activo': self.activo,
            'stock': float(self.inventario.stock_actual) if self.inventario else 0
        }
