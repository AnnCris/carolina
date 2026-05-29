# carolina/backend/rutas/productos.py
from flask import Blueprint, request, jsonify, current_app
from extensions import db
from modelos.producto import Producto
from modelos.inventario import Inventario
from utilidades.permisos import requiere_permiso
import uuid, os

bp_productos = Blueprint('productos', __name__)

@bp_productos.route('/productos', methods=['GET'])
@requiere_permiso('productos_ver')
def listar():
    # Devuelve TODOS: activos e inactivos
    productos = Producto.query.order_by(Producto.id.asc()).all()
    return jsonify([p.to_dict() for p in productos])

@bp_productos.route('/productos', methods=['POST'])
@requiere_permiso('productos')
def crear():
    datos = request.get_json() or {}
    errores = {}

    nombre       = (datos.get('nombre') or '').strip()
    categoria_id = datos.get('categoria_id')

    if len(nombre) < 2:
        errores['nombre'] = 'El nombre es requerido'
    if not categoria_id:
        errores['categoria_id'] = 'La categoría es requerida'
    if errores:
        return jsonify({'errores': errores}), 422

    producto = Producto(
        nombre       = nombre,
        descripcion  = (datos.get('descripcion') or '').strip() or None,
        categoria_id = categoria_id,
        marca_id     = datos.get('marca_id'),
        tipo_peso    = datos.get('tipo_peso', 'fijo'),
        peso_gramos  = datos.get('peso_gramos'),
        unidad       = datos.get('unidad', 'unidad'),
        codigo_barras= (datos.get('codigo_barras') or '').strip() or None,
        activo       = True,
    )
    db.session.add(producto)
    db.session.flush()

    stock_minimo = datos.get('stock_minimo', 0) or 0
    inv = Inventario(
        producto_id  = producto.id,
        stock_actual = 0,
        stock_minimo = stock_minimo,
    )
    db.session.add(inv)
    db.session.commit()
    return jsonify(producto.to_dict()), 201


@bp_productos.route('/productos/<int:id>', methods=['PUT'])
@requiere_permiso('productos')
def actualizar(id):
    p    = Producto.query.get_or_404(id)
    datos = request.get_json() or {}

    nombre = (datos.get('nombre') or '').strip()
    if nombre and len(nombre) < 2:
        return jsonify({'errores': {'nombre': 'Mínimo 2 caracteres'}}), 422

    if nombre:
        p.nombre = nombre
    if 'descripcion'   in datos: p.descripcion   = (datos['descripcion']   or '').strip() or None
    if 'categoria_id'  in datos: p.categoria_id  = datos['categoria_id']
    if 'marca_id'      in datos: p.marca_id       = datos['marca_id']
    if 'tipo_peso'     in datos: p.tipo_peso      = datos['tipo_peso']
    if 'peso_gramos'   in datos: p.peso_gramos    = datos['peso_gramos']
    if 'unidad'        in datos: p.unidad         = datos['unidad']
    if 'codigo_barras' in datos: p.codigo_barras  = (datos['codigo_barras'] or '').strip() or None
    if 'activo'        in datos: p.activo         = datos['activo']

    db.session.commit()
    return jsonify(p.to_dict())


@bp_productos.route('/productos/<int:id>', methods=['DELETE'])
@requiere_permiso('productos')
def eliminar(id):
    p = Producto.query.get_or_404(id)
    from modelos.inventario import Inventario
    inv = Inventario.query.filter_by(producto_id=id).first()
    if inv:
        db.session.delete(inv)
    db.session.delete(p)
    db.session.commit()
    return jsonify({'mensaje': 'Producto eliminado permanentemente'})


@bp_productos.route('/productos/<int:id>/foto', methods=['POST'])
@requiere_permiso('productos')
def subir_foto_producto(id):
    p = Producto.query.get_or_404(id)
    if 'foto' not in request.files:
        return jsonify({'error': 'No se envió imagen'}), 422
    archivo = request.files['foto']
    ext = archivo.filename.rsplit('.', 1)[-1].lower()
    if ext not in current_app.config['ALLOWED_EXTENSIONS']:
        return jsonify({'error': 'Formato no permitido. Usa JPG, PNG o WEBP'}), 422
    nombre_archivo = f"prod_{uuid.uuid4().hex}.{ext}"
    archivo.save(os.path.join(current_app.config['UPLOAD_FOLDER'], nombre_archivo))
    p.foto = nombre_archivo
    db.session.commit()
    return jsonify({'foto': f'/api/subidas/{nombre_archivo}'}), 200