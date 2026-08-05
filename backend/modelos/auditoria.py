# carolina/backend/modelos/auditoria.py
from extensions import db
from datetime import datetime

class RegistroAuditoria(db.Model):
    """
    Un renglón por cada acción que modifica algo en el sistema (crear,
    actualizar, eliminar, iniciar/cerrar sesión, ajustes de inventario,
    etc.). Se llena automáticamente desde utilidades/auditoria.py, no
    hay que tocar cada ruta a mano.

    'usuario_nombre' queda guardado tal cual (no solo el id) para que el
    historial siga siendo legible aunque ese usuario se elimine después.
    """
    __tablename__ = 'auditoria'
    id = db.Column(db.Integer, primary_key=True)
    usuario_id = db.Column(db.Integer, db.ForeignKey('usuarios.id'), nullable=True)
    usuario_nombre = db.Column(db.String(200))
    modulo = db.Column(db.String(50), nullable=False)
    accion = db.Column(db.String(50), nullable=False)
    metodo_http = db.Column(db.String(10))
    ruta = db.Column(db.String(255))
    entidad_id = db.Column(db.Integer, nullable=True)
    descripcion = db.Column(db.String(500))
    ip = db.Column(db.String(64))
    exitoso = db.Column(db.Boolean, default=True)
    codigo_estado = db.Column(db.Integer)
    fecha = db.Column(db.DateTime, default=datetime.utcnow)

    usuario = db.relationship('Usuario')

    def to_dict(self):
        return {
            'id': self.id,
            'usuario_id': self.usuario_id,
            'usuario': self.usuario_nombre,
            'modulo': self.modulo,
            'accion': self.accion,
            'metodo_http': self.metodo_http,
            'ruta': self.ruta,
            'entidad_id': self.entidad_id,
            'descripcion': self.descripcion,
            'ip': self.ip,
            'exitoso': self.exitoso,
            'codigo_estado': self.codigo_estado,
            'fecha': str(self.fecha),
        }
