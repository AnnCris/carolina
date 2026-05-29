from extensions import db
 
class Proveedor(db.Model):
    __tablename__ = 'proveedores'
    id               = db.Column(db.Integer, primary_key=True)
    nombre           = db.Column(db.String(150), nullable=False)
    apellido_paterno = db.Column(db.String(100))
    apellido_materno = db.Column(db.String(100))
    nit              = db.Column(db.String(50))
    telefono         = db.Column(db.String(20))
    email            = db.Column(db.String(150))
    direccion        = db.Column(db.Text)
    contacto         = db.Column(db.String(100))
    activo           = db.Column(db.Boolean, default=True)
 
    @property
    def nombre_completo(self):
        partes = [self.nombre]
        if self.apellido_paterno:
            partes.append(self.apellido_paterno)
        if self.apellido_materno:
            partes.append(self.apellido_materno)
        return ' '.join(partes)
 
    def to_dict(self):
        return {
            'id':               self.id,
            'nombre':           self.nombre,
            'apellido_paterno': self.apellido_paterno,
            'apellido_materno': self.apellido_materno,
            'nombre_completo':  self.nombre_completo,
            'nit':              self.nit,
            'telefono':         self.telefono,
            'email':            self.email,
            'direccion':        self.direccion,
            'contacto':         self.contacto,
            'activo':           self.activo,
        }
 