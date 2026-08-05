# carolina/backend/utilidades/recibo_pdf.py
from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_RIGHT
from reportlab.platypus import SimpleDocTemplate, Table, TableStyle, Paragraph, Spacer
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
import io

CELESTE = colors.HexColor('#0EA5E9')
GRIS = colors.HexColor('#475569')


def generar_recibo(venta):
    buffer = io.BytesIO()
    # 80mm de ancho (impresora térmica). Alto variable según cantidad de
    # productos, para no desperdiciar papel en ventas cortas.
    n_items = venta.detalles.count() if hasattr(venta.detalles, 'count') \
        else len(venta.detalles)
    alto = 300 + 20 * n_items
    doc = SimpleDocTemplate(buffer, pagesize=(226, alto),
                            leftMargin=10, rightMargin=10, topMargin=10, bottomMargin=10)
    estilos = getSampleStyleSheet()
    centrado = ParagraphStyle('Centrado', parent=estilos['Normal'],
                               alignment=TA_CENTER)
    tagline = ParagraphStyle('Tagline', parent=estilos['Normal'],
                              alignment=TA_CENTER, fontSize=7.5,
                              textColor=GRIS)
    negrita_dcha = ParagraphStyle('NegritaDcha', parent=estilos['Normal'],
                                  alignment=TA_RIGHT, fontName='Helvetica-Bold')
    elementos = []

    # ── Encabezado del negocio ──────────────────────────────────────
    elementos.append(Paragraph('<b>DISTRIBUIDORA DE QUESOS CAROLINA</b>',
                                ParagraphStyle('Titulo', parent=estilos['Normal'],
                                               alignment=TA_CENTER, fontSize=13,
                                               leading=15)))
    elementos.append(Paragraph(
        'Chiquitano, San Javier, La Ribera, Cristy: Laminado y Barras',
        tagline))
    elementos.append(Paragraph('Pedidos Cel: 77529102 - 76218335', tagline))
    elementos.append(Spacer(1, 6))

    # ── Nº de recibo y tipo de comprobante ──────────────────────────
    encabezado = Table(
        [[Paragraph('<b>NOTA DE ENTREGA</b>', estilos['Normal']),
          Paragraph(f'<b>N° {venta.numero_recibo}</b>', negrita_dcha)]],
        colWidths=[110, 96])
    encabezado.setStyle(TableStyle([
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('TOPPADDING', (0, 0), (-1, -1), 0),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 4),
    ]))
    elementos.append(encabezado)
    elementos.append(Paragraph(
        f'Fecha: {venta.fecha.strftime("%d/%m/%Y %H:%M")}', estilos['Normal']))
    elementos.append(Paragraph(
        f'Señor(es): {venta.cliente.nombre_completo if venta.cliente else "-"}',
        estilos['Normal']))
    if venta.nota:
        elementos.append(Paragraph(f'<i>Nota: {venta.nota}</i>',
                                    ParagraphStyle('Nota', parent=estilos['Normal'],
                                                   fontSize=8)))
    elementos.append(Spacer(1, 8))

    # ── Detalle ──────────────────────────────────────────────────────
    datos_tabla = [['Cant.', 'Detalle', 'P.Unit', 'Total']]
    hay_precio_especial = False
    for d in venta.detalles:
        nombre = d.producto.nombre[:18] if d.producto else '-'
        if d.precio_editado:
            nombre += ' *'
            hay_precio_especial = True
        datos_tabla.append([
            f'{float(d.cantidad):.2f}',
            nombre,
            f'{float(d.precio_unitario):.2f}',
            f'{float(d.subtotal):.2f}'
        ])

    tabla = Table(datos_tabla, colWidths=[30, 88, 40, 48])
    tabla.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), CELESTE),
        ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
        ('FONTSIZE', (0, 0), (-1, -1), 8),
        ('ALIGN', (0, 0), (0, -1), 'CENTER'),
        ('ALIGN', (2, 0), (-1, -1), 'RIGHT'),
        ('GRID', (0, 0), (-1, -1), 0.5, colors.grey),
        ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, colors.HexColor('#F0F9FF')]),
    ]))
    elementos.append(tabla)
    elementos.append(Spacer(1, 8))

    # ── Totales ──────────────────────────────────────────────────────
    if venta.descuento:
        elementos.append(Paragraph(
            f'Descuento: Bs {float(venta.descuento):.2f}', negrita_dcha))
    elementos.append(Paragraph(
        f'TOTAL: Bs {float(venta.total):.2f}',
        ParagraphStyle('Total', parent=estilos['Normal'], alignment=TA_RIGHT,
                        fontName='Helvetica-Bold', fontSize=13)))
    elementos.append(Spacer(1, 6))

    # ── Pago de esta venta ──────────────────────────────────────────
    metodos_legibles = {'efectivo': 'Efectivo', 'qr': 'QR', 'transferencia': 'Transferencia'}
    pagado = venta.monto_pagado
    saldo_esta_venta = venta.saldo_pendiente
    if pagado > 0:
        metodos_usados = ', '.join(sorted({
            metodos_legibles.get(d.cobranza.metodo_pago, d.cobranza.metodo_pago)
            for d in venta.detalles_cobranza if d.cobranza
        }))
        elementos.append(Paragraph(
            f'Pagado: Bs {pagado:.2f}' + (f' ({metodos_usados})' if metodos_usados else ''),
            negrita_dcha))
    if saldo_esta_venta > 0:
        elementos.append(Paragraph(
            f'SALDO DE ESTA COMPRA: Bs {saldo_esta_venta:.2f}',
            ParagraphStyle('SaldoVenta', parent=estilos['Normal'], alignment=TA_RIGHT,
                            fontName='Helvetica-Bold', fontSize=10,
                            textColor=colors.HexColor('#DC2626'))))
    elementos.append(Spacer(1, 6))

    # ── Otras cuentas pendientes del cliente ────────────────────────
    if venta.cliente:
        otras_pendientes = [
            v for v in venta.cliente.ventas
            if v.id != venta.id and v.estado != 'anulada' and v.saldo_pendiente > 0
        ]
        if otras_pendientes or saldo_esta_venta > 0:
            elementos.append(Paragraph(
                '<b>Cuentas pendientes del cliente</b>',
                ParagraphStyle('TituloCuentas', parent=estilos['Normal'], fontSize=9)))
            if saldo_esta_venta > 0:
                elementos.append(Paragraph(
                    f'• Nota {venta.numero_recibo} ({venta.fecha.strftime("%d/%m/%Y")}): '
                    f'Bs {saldo_esta_venta:.2f}',
                    ParagraphStyle('LineaCuenta', parent=estilos['Normal'], fontSize=8)))
            total_otras = 0.0
            for v in sorted(otras_pendientes, key=lambda v: v.fecha):
                elementos.append(Paragraph(
                    f'• Nota {v.numero_recibo} ({v.fecha.strftime("%d/%m/%Y")}): '
                    f'Bs {v.saldo_pendiente:.2f}',
                    ParagraphStyle('LineaCuenta', parent=estilos['Normal'], fontSize=8)))
                total_otras += v.saldo_pendiente
            elementos.append(Paragraph(
                f'TOTAL QUE DEBE EL CLIENTE: Bs {(saldo_esta_venta + total_otras):.2f}',
                ParagraphStyle('TotalDeuda', parent=estilos['Normal'], alignment=TA_RIGHT,
                                fontName='Helvetica-Bold', fontSize=10,
                                textColor=colors.HexColor('#DC2626'))))
            elementos.append(Spacer(1, 8))

    if hay_precio_especial:
        elementos.append(Paragraph(
            '<font size=7>* Precio especial acordado para esta venta</font>',
            estilos['Normal']))
        elementos.append(Spacer(1, 4))

    elementos.append(Paragraph(
        '<font size=7>Una vez retirada la mercadería, no se aceptan '
        'cambios ni devoluciones.</font>', centrado))
    elementos.append(Spacer(1, 6))
    elementos.append(Paragraph('¡Gracias por su compra!', centrado))

    doc.build(elementos)
    buffer.seek(0)
    return buffer
