# carolina/backend/utilidades/permisos.py
from functools import wraps
from flask import jsonify, request

# Permisos por rol — fuente de verdad centralizada
PERMISOS_ROL = {
    'admin': {
        'todo': True  # acceso completo a todo
    },
    'vendedor': {
        'ventas':        True,
        'pedidos':       True,
        'clientes':      True,
        'devoluciones':  True,
        'cobranzas':     True,
        'productos_ver': True,  # solo ver productos, no editar
    },
    'almacenero': {
        'inventario':    True,
        'compras':       True,
        'productos':     True,  # puede editar productos
        'productos_ver': True,
        'proveedores':   True,
        'devoluciones':  True,
    },
}

def obtener_usuario_actual():
    from modelos.usuario import Usuario
    # Token Bearer (ID del usuario)
    auth = request.headers.get('Authorization', '')
    if auth.startswith('Bearer '):
        token = auth.replace('Bearer ', '').strip()
        if token.isdigit():
            return Usuario.query.get(int(token))
    # Fallback: header X-Usuario-Id
    uid_header = request.headers.get('X-Usuario-Id', '')
    if uid_header.isdigit():
        return Usuario.query.get(int(uid_header))
    return None

def _tiene_permiso(usuario, permiso):
    """
    Verifica si un usuario tiene el permiso dado.
    Primero consulta los permisos guardados en BD,
    luego complementa con PERMISOS_ROL como respaldo.
    Admin siempre tiene acceso total.
    """
    rol_nombre = usuario.rol.nombre if usuario.rol else ''

    # Admin siempre pasa
    if rol_nombre == 'admin':
        return True

    # Permisos guardados en BD (tienen prioridad)
    permisos_bd = usuario.rol.permisos or {}
    if permisos_bd.get('todo'):
        return True
    if permisos_bd.get(permiso):
        return True

    # Respaldo: tabla PERMISOS_ROL definida arriba
    permisos_base = PERMISOS_ROL.get(rol_nombre, {})
    if permisos_base.get('todo'):
        return True
    if permisos_base.get(permiso):
        return True

    return False

def requiere_permiso(permiso):
    def decorador(fn):
        @wraps(fn)
        def wrapper(*args, **kwargs):
            usuario = obtener_usuario_actual()
            if not usuario:
                return jsonify({'error': 'No autenticado'}), 401
            if not usuario.activo:
                return jsonify({'error': 'Usuario desactivado'}), 403
            if not _tiene_permiso(usuario, permiso):
                return jsonify({
                    'error': f'Permiso denegado. Se requiere: {permiso}'
                }), 403
            return fn(*args, **kwargs)
        return wrapper
    return decorador