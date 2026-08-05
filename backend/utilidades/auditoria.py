# carolina/backend/utilidades/auditoria.py
"""
Registro automático de auditoría. Se engancha una sola vez en app.py
(@app.after_request) y a partir de ahí registra solo, sin necesidad de
tocar cada ruta: toda petición POST/PUT/DELETE exitosa o fallida bajo
/api/ que pueda identificar a un usuario queda guardada en la tabla
'auditoria'.

Deliberadamente NO registra peticiones GET (solo consultan, no cambian
nada) — eso evitaría inundar la tabla con cada vez que alguien abre una
pantalla a mirar una lista.
"""
from extensions import db
from utilidades.tiempo import ahora_bolivia

MODULOS_LEGIBLES = {
    'auth':          'sesión',
    'usuarios':      'un usuario',
    'productos':     'un producto',
    'categorias':    'una categoría',
    'marcas':        'una marca',
    'proveedores':   'un proveedor',
    'clientes':      'un cliente',
    'compras':       'una compra',
    'ventas':        'una venta',
    'inventario':    'el inventario',
    'pedidos':       'un pedido',
    'devoluciones':  'una devolución',
    'precios':       'un precio',
    'cobranzas':     'una cobranza',
}

ACCIONES_LEGIBLES = {
    'crear':              'Creó',
    'actualizar':         'Actualizó',
    'eliminar':           'Eliminó',
    'login':              'Inició sesión',
    'login_fallido':      'Intento de inicio de sesión fallido',
    'registro':           'Se registró',
    'logout':             'Cerró sesión',
    'ajuste_inventario':  'Hizo un ajuste de inventario en',
    'resolver':           'Resolvió',
    'subir_foto':         'Subió una foto para',
    'subir_factura':      'Subió una factura para',
    'guardar_precio':     'Guardó el precio de venta de',
}

# Rutas bajo /api/ que no representan una acción de negocio (servir
# archivos subidos) — nunca se auditan aunque sean GET/POST.
_MODULOS_IGNORADOS = {'subidas'}


def _modulo_y_accion(metodo, partes):
    if not partes:
        return None, None

    primero = partes[0]

    if primero == 'login':
        return 'auth', 'login'
    if primero == 'registro':
        return 'auth', 'registro'
    if primero == 'logout':
        return 'auth', 'logout'
    if primero in _MODULOS_IGNORADOS:
        return None, None

    modulo = primero
    accion = {'POST': 'crear', 'PUT': 'actualizar', 'DELETE': 'eliminar'}.get(metodo)

    if len(partes) >= 2:
        ultimo = partes[-1]
        if ultimo == 'ajuste':
            accion = 'ajuste_inventario'
        elif ultimo == 'resolver':
            accion = 'resolver'
        elif ultimo == 'foto':
            accion = 'subir_foto'
        elif ultimo == 'factura':
            accion = 'subir_factura'
        elif ultimo == 'guardar' and modulo == 'precios':
            accion = 'guardar_precio'

    return modulo, accion


def _extraer_entidad_id(partes, datos_respuesta):
    for parte in partes:
        if parte.isdigit():
            return int(parte)
    if isinstance(datos_respuesta, dict):
        if isinstance(datos_respuesta.get('id'), int):
            return datos_respuesta['id']
        for contenedor in ('venta', 'usuario', 'cliente', 'producto'):
            sub = datos_respuesta.get(contenedor)
            if isinstance(sub, dict) and isinstance(sub.get('id'), int):
                return sub['id']
    return None


def registrar_desde_request(request, response):
    from modelos.auditoria import RegistroAuditoria
    from utilidades.permisos import obtener_usuario_actual

    if not request.path.startswith('/api/'):
        return
    if request.method not in ('POST', 'PUT', 'DELETE'):
        return

    partes = [p for p in request.path[len('/api/'):].split('/') if p]
    modulo, accion = _modulo_y_accion(request.method, partes)
    if not modulo or not accion:
        return

    exitoso = response.status_code < 400
    datos_respuesta = response.get_json(silent=True)

    usuario = obtener_usuario_actual()
    usuario_id = usuario.id if usuario else None
    usuario_nombre = usuario.nombre_completo if usuario else None

    # En login/registro todavía no hay token en la petición: el usuario
    # sale de la propia respuesta (o del body enviado, si el login falló).
    if modulo == 'auth':
        if accion == 'login':
            if exitoso and isinstance(datos_respuesta, dict):
                u = datos_respuesta.get('usuario') or {}
                usuario_id = u.get('id')
                usuario_nombre = u.get('nombre_completo')
            else:
                accion = 'login_fallido'
                datos_enviados = request.get_json(silent=True) or {}
                usuario_nombre = datos_enviados.get('nombre_usuario') or 'Desconocido'
        elif accion == 'registro' and exitoso and isinstance(datos_respuesta, dict):
            u = datos_respuesta.get('usuario') or {}
            usuario_id = u.get('id')
            usuario_nombre = u.get('nombre_completo')

    # Si no pudimos identificar quién hizo la petición (token ausente o
    # inválido) y no es un intento de login fallido, no vale la pena
    # guardarlo — sería un registro anónimo sin utilidad para auditar.
    if usuario_id is None and accion != 'login_fallido':
        return

    entidad_id = _extraer_entidad_id(partes, datos_respuesta)
    descripcion = ACCIONES_LEGIBLES.get(accion, accion)
    if modulo != 'auth':
        descripcion += f' {MODULOS_LEGIBLES.get(modulo, modulo)}'
        if entidad_id:
            descripcion += f' (#{entidad_id})'
    if not exitoso and accion != 'login_fallido':
        descripcion += ' — falló'

    registro = RegistroAuditoria(
        usuario_id=usuario_id,
        usuario_nombre=usuario_nombre or 'Desconocido',
        modulo=modulo,
        accion=accion,
        metodo_http=request.method,
        ruta=request.path,
        entidad_id=entidad_id,
        descripcion=descripcion,
        ip=request.remote_addr,
        exitoso=exitoso,
        codigo_estado=response.status_code,
        fecha=ahora_bolivia(),
    )
    db.session.add(registro)
    db.session.commit()
