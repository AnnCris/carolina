# carolina/backend/rutas/ventas.py
from flask import Blueprint, request, jsonify, send_file
from flask_jwt_extended import jwt_required, get_jwt_identity
from extensions import db
from modelos.venta import Venta, DetalleVenta
from modelos.inventario import Inventario
from utilidades.permisos import requiere_permiso
from utilidades.recibo_pdf import generar_recibo
import datetime, random, string

bp_ventas = Blueprint('ventas', __name__)

def generar_numero_recibo():
    fecha = datetime.datetime.now().strftime('%Y%m%d')
    aleatorio = ''.join(random.choices(string.digits, k=4))
    return f'RC-{fecha}-{aleatorio}'

@bp_ventas.route('/ventas', methods=['GET'])
@jwt_required()
@requiere_permiso('ventas')
def listar_ventas():
    ventas = Venta.query.order_by(Venta.fecha.desc()).all()
    return jsonify([v.to_dict() for v in ventas])

@bp_ventas.route('/ventas', methods=['POST'])
@jwt_required()
@requiere_permiso('ventas')
def crear_venta():
    datos = request.get_json()
    usuario_id = get_jwt_identity()

    if not datos.get('detalles') or len(datos['detalles']) == 0:
        return jsonify({'error': 'La venta debe tener al menos un producto'}), 422

    # Crear venta
    venta = Venta(
        cliente_id=datos.get('cliente_id'),
        usuario_id=usuario_id,
        descuento=datos.get('descuento', 0),
        nota=datos.get('nota'),
        numero_recibo=generar_numero_recibo()
    )
    db.session.add(venta)

    total = 0
    for item in datos['detalles']:
        subtotal = float(item['cantidad']) * float(item['precio_unitario'])
        detalle = DetalleVenta(
            venta=venta,
            producto_id=item['producto_id'],
            cantidad=item['cantidad'],
            precio_unitario=item['precio_unitario'],  # precio editable
            subtotal=subtotal,
            peso_kg=item.get('peso_kg')
        )
        db.session.add(detalle)
        total += subtotal

        # Actualizar inventario
        inv = Inventario.query.filter_by(producto_id=item['producto_id']).first()
        if inv:
            inv.stock_actual -= float(item['cantidad'])

    venta.total = total - float(datos.get('descuento', 0))
    db.session.commit()

    return jsonify({'venta': venta.to_dict(), 'numero_recibo': venta.numero_recibo}), 201

@bp_ventas.route('/ventas/<int:id>/recibo', methods=['GET'])
@jwt_required()
@requiere_permiso('ventas')
def obtener_recibo(id):
    venta = Venta.query.get_or_404(id)
    pdf_buffer = generar_recibo(venta)
    return send_file(pdf_buffer, mimetype='application/pdf',
                     download_name=f'recibo_{venta.numero_recibo}.pdf')
