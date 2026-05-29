# carolina/backend/modelos/rol.py
from extensions import db

class Rol(db.Model):
    __tablename__ = 'roles'
    id = db.Column(db.Integer, primary_key=True)
    nombre = db.Column(db.String(50), unique=True, nullable=False)
    permisos = db.Column(db.JSON, default={})

    usuarios = db.relationship('Usuario', backref='rol', lazy='dynamic')

    def to_dict(self):
        return {
            'id': self.id,
            'nombre': self.nombre,
            'permisos': self.permisos
        }