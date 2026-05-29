from flask import Blueprint, request, jsonify
from extensions import db
from modelos.inventario import Inventario, MovimientoInventario
from utilidades.permisos import requiere_permiso, obtener_usuario_actual
from datetime import datetime
 
bp_inventario = Blueprint('inventario', __name__)
 
 
@bp_inventario.route('/inventario', methods=['GET'])
@requiere_permiso('inventario')
def listar():
    from modelos.producto import Producto
    items = (Inventario.query
             .join(Producto, Inventario.producto_id == Producto.id)
             .order_by(Producto.nombre.asc())
             .all())
    return jsonify([i.to_dict() for i in items])
 
 
@bp_inventario.route('/inventario/<int:producto_id>', methods=['GET'])
@requiere_permiso('inventario')
def obtener(producto_id):
    inv = Inventario.query.filter_by(
        producto_id=producto_id).first_or_404()
    return jsonify(inv.to_dict())
 
 
@bp_inventario.route('/inventario/<int:producto_id>/movimientos', methods=['GET'])
@requiere_permiso('inventario')
def movimientos(producto_id):
    movs = (MovimientoInventario.query
            .filter_by(producto_id=producto_id)
            .order_by(MovimientoInventario.fecha.desc())
            .limit(100)
            .all())
    return jsonify([m.to_dict() for m in movs])
 
 
@bp_inventario.route('/inventario/<int:producto_id>', methods=['PUT'])
@requiere_permiso('inventario')
def actualizar(producto_id):
    inv   = Inventario.query.filter_by(
        producto_id=producto_id).first_or_404()
    datos = request.get_json() or {}
    errores = {}
 
    if 'stock_minimo' in datos:
        try:
            val = float(datos['stock_minimo'])
            if val < 0:
                errores['stock_minimo'] = 'No puede ser negativo'
            else:
                inv.stock_minimo = val
        except (ValueError, TypeError):
            errores['stock_minimo'] = 'Valor inválido'
 
    if 'stock_maximo' in datos:
        val_max = datos['stock_maximo']
        if val_max is None or val_max == '':
            inv.stock_maximo = None
        else:
            try:
                val = float(val_max)
                if val < 0:
                    errores['stock_maximo'] = 'No puede ser negativo'
                else:
                    inv.stock_maximo = val
            except (ValueError, TypeError):
                errores['stock_maximo'] = 'Valor inválido'
 
    if errores:
        return jsonify({'errores': errores}), 422
 
    db.session.commit()
    return jsonify(inv.to_dict())
 
 
@bp_inventario.route('/inventario/<int:producto_id>/ajuste', methods=['POST'])
@requiere_permiso('inventario')
def ajustar(producto_id):
    inv     = Inventario.query.filter_by(
        producto_id=producto_id).first_or_404()
    datos   = request.get_json() or {}
    usuario = obtener_usuario_actual()
    errores = {}
 
    tipo = datos.get('tipo', '')
    nota = (datos.get('nota') or '').strip()
 
    if tipo not in ('entrada', 'salida', 'ajuste'):
        errores['tipo'] = 'Tipo inválido'
 
    try:
        cantidad = float(datos.get('cantidad', 0))
        if cantidad <= 0:
            errores['cantidad'] = 'Debe ser mayor a 0'
    except (ValueError, TypeError):
        errores['cantidad'] = 'Valor inválido'
        cantidad = 0
 
    if errores:
        return jsonify({'errores': errores}), 422
 
    stock_anterior = float(inv.stock_actual or 0)
 
    if tipo == 'entrada':
        inv.stock_actual   = stock_anterior + cantidad
        inv.ultima_entrada = datetime.utcnow()
        delta              = cantidad
    elif tipo == 'salida':
        if cantidad > stock_anterior:
            return jsonify({
                'error': f'Stock insuficiente. Disponible: {stock_anterior} unidades'
            }), 422
        inv.stock_actual  = stock_anterior - cantidad
        inv.ultima_salida = datetime.utcnow()
        delta             = -cantidad
    else:  # ajuste directo
        delta            = cantidad - stock_anterior
        inv.stock_actual = cantidad
 
    mov = MovimientoInventario(
        inventario_id   = inv.id,
        producto_id     = producto_id,
        tipo            = tipo,
        cantidad        = abs(delta),
        referencia_tipo = 'ajuste_manual',
        referencia_id   = None,
        nota            = nota or f'Ajuste manual: {tipo}',
        usuario_id      = usuario.id if usuario else None,
    )
    db.session.add(mov)
    db.session.commit()
    return jsonify(inv.to_dict()), 200
 
 
@bp_inventario.route('/inventario/<int:producto_id>', methods=['DELETE'])
@requiere_permiso('todo')
def eliminar(producto_id):
    inv = Inventario.query.filter_by(
        producto_id=producto_id).first_or_404()
    # Eliminar movimientos primero
    MovimientoInventario.query.filter_by(
        producto_id=producto_id).delete()
    db.session.delete(inv)
    db.session.commit()
    return jsonify({'mensaje': 'Registro de inventario eliminado'})
 
 
@bp_inventario.route('/inventario/alertas', methods=['GET'])
@requiere_permiso('inventario')
def alertas():
    items  = Inventario.query.all()
    result = [i.to_dict() for i in items
              if i.estado_stock in ('critico', 'sin_stock')]
    return jsonify(result)