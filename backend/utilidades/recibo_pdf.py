# carolina/backend/utilidades/recibo_pdf.py
from reportlab.lib.pagesizes import A5
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Table, TableStyle, Paragraph, Spacer
from reportlab.lib.styles import getSampleStyleSheet
import io

CELESTE = colors.HexColor('#0EA5E9')
ROJO = colors.HexColor('#DC2626')

def generar_recibo(venta):
    buffer = io.BytesIO()
    doc = SimpleDocTemplate(buffer, pagesize=(226, 400),  # 80mm de ancho (impresora térmica)
                            leftMargin=10, rightMargin=10, topMargin=10, bottomMargin=10)
    estilos = getSampleStyleSheet()
    elementos = []

    # Encabezado
    titulo = Paragraph('<b>DISTRIBUIDORA DE QUESOS CAROLINA</b>', estilos['Title'])
    elementos.append(titulo)
    elementos.append(Paragraph('La Paz, Bolivia', estilos['Normal']))
    elementos.append(Spacer(1, 8))
    elementos.append(Paragraph(f'<b>Recibo N°:</b> {venta.numero_recibo}', estilos['Normal']))
    elementos.append(Paragraph(f'<b>Fecha:</b> {venta.fecha.strftime("%d/%m/%Y %H:%M")}', estilos['Normal']))
    if venta.cliente:
        elementos.append(Paragraph(f'<b>Cliente:</b> {venta.cliente.nombre}', estilos['Normal']))
    elementos.append(Spacer(1, 8))

    # Detalle
    datos_tabla = [['Producto', 'Cant.', 'P.Unit', 'Total']]
    for d in venta.detalles:
        datos_tabla.append([
            d.producto.nombre[:20],
            f'{float(d.cantidad):.2f}',
            f'Bs {float(d.precio_unitario):.2f}',
            f'Bs {float(d.subtotal):.2f}'
        ])

    tabla = Table(datos_tabla, colWidths=[90, 35, 50, 50])
    tabla.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), CELESTE),
        ('TEXTCOLOR', (0,0), (-1,0), colors.white),
        ('FONTSIZE', (0,0), (-1,-1), 8),
        ('GRID', (0,0), (-1,-1), 0.5, colors.grey),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, colors.HexColor('#F0F9FF')]),
    ]))
    elementos.append(tabla)
    elementos.append(Spacer(1, 8))

    if venta.descuento:
        elementos.append(Paragraph(f'<b>Descuento:</b> Bs {float(venta.descuento):.2f}', estilos['Normal']))
    elementos.append(Paragraph(f'<b>TOTAL: Bs {float(venta.total):.2f}</b>', estilos['Heading2']))
    elementos.append(Spacer(1, 8))
    elementos.append(Paragraph('¡Gracias por su compra!', estilos['Normal']))

    doc.build(elementos)
    buffer.seek(0)
    return buffer