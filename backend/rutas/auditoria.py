# carolina/backend/rutas/auditoria.py
from flask import Blueprint, request, jsonify
from sqlalchemy import func, or_
from datetime import datetime, timedelta
from extensions import db
from modelos.auditoria import RegistroAuditoria
from utilidades.permisos import requiere_permiso

bp_auditoria = Blueprint('auditoria', __name__)


@bp_auditoria.route('/auditoria', methods=['GET'])
@requiere_permiso('todo')
def listar():
    """Historial de acciones, con filtros opcionales por querystring:
    usuario_id, modulo, accion, exitoso (true/false), desde/hasta
    (YYYY-MM-DD), q (busca en descripción y nombre de usuario), y
    paginación con pagina/por_pagina."""
    query = RegistroAuditoria.query

    usuario_id = request.args.get('usuario_id', type=int)
    if usuario_id:
        query = query.filter(RegistroAuditoria.usuario_id == usuario_id)

    modulo = request.args.get('modulo')
    if modulo:
        query = query.filter(RegistroAuditoria.modulo == modulo)

    accion = request.args.get('accion')
    if accion:
        query = query.filter(RegistroAuditoria.accion == accion)

    exitoso = request.args.get('exitoso')
    if exitoso is not None and exitoso != '':
        query = query.filter(RegistroAuditoria.exitoso == (exitoso.lower() == 'true'))

    desde = request.args.get('desde')
    if desde:
        try:
            query = query.filter(RegistroAuditoria.fecha >= datetime.strptime(desde, '%Y-%m-%d'))
        except ValueError:
            return jsonify({'error': 'Formato de fecha "desde" inválido. Usa YYYY-MM-DD'}), 422

    hasta = request.args.get('hasta')
    if hasta:
        try:
            fecha_hasta = datetime.strptime(hasta, '%Y-%m-%d') + timedelta(days=1)
            query = query.filter(RegistroAuditoria.fecha < fecha_hasta)
        except ValueError:
            return jsonify({'error': 'Formato de fecha "hasta" inválido. Usa YYYY-MM-DD'}), 422

    q = request.args.get('q')
    if q:
        patron = f'%{q}%'
        query = query.filter(or_(
            RegistroAuditoria.descripcion.ilike(patron),
            RegistroAuditoria.usuario_nombre.ilike(patron),
        ))

    pagina = request.args.get('pagina', 1, type=int)
    por_pagina = min(request.args.get('por_pagina', 50, type=int), 200)

    query = query.order_by(RegistroAuditoria.fecha.desc())
    total = query.count()
    registros = query.offset((pagina - 1) * por_pagina).limit(por_pagina).all()

    return jsonify({
        'total': total,
        'pagina': pagina,
        'por_pagina': por_pagina,
        'registros': [r.to_dict() for r in registros],
    })


@bp_auditoria.route('/auditoria/modulos', methods=['GET'])
@requiere_permiso('todo')
def modulos_disponibles():
    """Módulos que ya tienen algún registro — para armar el filtro."""
    filas = db.session.query(RegistroAuditoria.modulo).distinct().all()
    return jsonify(sorted(f[0] for f in filas if f[0]))


@bp_auditoria.route('/auditoria/resumen', methods=['GET'])
@requiere_permiso('todo')
def resumen():
    """Cuántas acciones hizo cada usuario — vistazo rápido de actividad."""
    filas = (db.session.query(
                RegistroAuditoria.usuario_id,
                RegistroAuditoria.usuario_nombre,
                func.count(RegistroAuditoria.id),
             )
             .group_by(RegistroAuditoria.usuario_id, RegistroAuditoria.usuario_nombre)
             .order_by(func.count(RegistroAuditoria.id).desc())
             .all())
    return jsonify([
        {'usuario_id': f[0], 'usuario': f[1], 'total_acciones': f[2]}
        for f in filas
    ])
