// carolina/frontend/lib/pantallas/pedidos/pedidos_pantalla.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../constantes/breakpoints.dart';
import '../../constantes/colores.dart';
import '../../constantes/api.dart';
import '../../servicios/auth_servicio.dart';
import '../../widgets/notificacion.dart';
import '../devoluciones/devoluciones_pantalla.dart' show kMotivosDevolucion;

// ─── Servicio ─────────────────────────────────────────────────────────────────
class PedidosServicio {
  final _auth = AuthServicio();
  Future<Map<String, String>> get _h => _auth.obtenerHeaders();

  Future<List<dynamic>> listar() async {
    final res = await http.get(
        Uri.parse(ApiConfig.pedidos), headers: await _h);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Error al cargar pedidos');
  }

  Future<List<dynamic>> pedidosPorFecha(String fecha) async {
    final res = await http.get(
        Uri.parse('${ApiConfig.pedidos}/fecha/$fecha'),
        headers: await _h);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Error al cargar pedidos de esa fecha');
  }

  Future<List<dynamic>> listarClientes() async {
    final res = await http.get(
        Uri.parse(ApiConfig.clientes), headers: await _h);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Error al cargar clientes');
  }

  Future<List<dynamic>> listarProductos() async {
    final res = await http.get(
        Uri.parse(ApiConfig.productos), headers: await _h);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Error al cargar productos');
  }

  Future<List<dynamic>> listarDevolucionesPendientes(int clienteId) async {
    final res = await http.get(
        Uri.parse('${ApiConfig.devoluciones}/pendientes/$clienteId'),
        headers: await _h);
    if (res.statusCode == 200) return jsonDecode(res.body);
    return [];
  }

  Future<Map<String, dynamic>> crear(Map<String, dynamic> datos) async {
    final res = await http.post(Uri.parse(ApiConfig.pedidos),
        headers: await _h, body: jsonEncode(datos));
    final data = jsonDecode(res.body);
    if (res.statusCode == 201) return data;
    if (data['errores'] != null) {
      throw Exception(
          (data['errores'] as Map).values.first.toString());
    }
    throw Exception(data['error'] ?? 'Error al crear pedido');
  }

  Future<Map<String, dynamic>> actualizar(
      int id, Map<String, dynamic> datos) async {
    final res = await http.put(
        Uri.parse('${ApiConfig.pedidos}/$id'),
        headers: await _h,
        body: jsonEncode(datos));
    final data = jsonDecode(res.body);
    if (res.statusCode == 200) return data;
    if (data['errores'] != null) {
      throw Exception(
          (data['errores'] as Map).values.first.toString());
    }
    throw Exception(data['error'] ?? 'Error al actualizar');
  }

  Future<void> eliminar(int id) async {
    final res = await http.delete(
        Uri.parse('${ApiConfig.pedidos}/$id'), headers: await _h);
    if (res.statusCode != 200) {
      throw Exception('Error al eliminar');
    }
  }
}

// ─── Pantalla ─────────────────────────────────────────────────────────────────
class PedidosPantalla extends StatefulWidget {
  const PedidosPantalla({super.key});
  @override
  State<PedidosPantalla> createState() => _PedidosPantallaState();
}

class _PedidosPantallaState extends State<PedidosPantalla> {
  final _servicio = PedidosServicio();
  List<dynamic> _pedidos = [];
  bool   _cargando       = true;
  String _busqueda       = '';

  @override
  void initState() { super.initState(); _cargar(); }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final p = await _servicio.listar();
      setState(() => _pedidos = p);
    } catch (e) {
      if (mounted) {
        Notificacion.error(context,
            e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  List<dynamic> get _filtrados {
    if (_busqueda.isEmpty) return _pedidos;
    final q = _busqueda.toLowerCase();
    return _pedidos.where((p) =>
        (p['cliente'] ?? '').toLowerCase().contains(q) ||
        p['id'].toString().contains(q)).toList();
  }

  Future<bool> _confirmar(String titulo, String msg) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Container(padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: ColoresCarolina.rojo.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.delete_forever_rounded,
                  color: ColoresCarolina.rojo, size: 22)),
          const SizedBox(width: 12),
          Expanded(child: Text(titulo,
              style: const TextStyle(fontSize: 16))),
        ]),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: ColoresCarolina.rojo,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
            child: const Text('Sí, eliminar'),
          ),
        ],
      ),
    );
    return r ?? false;
  }

  Future<void> _eliminar(Map<String, dynamic> p) async {
    final ok = await _confirmar('Eliminar pedido',
        '⚠️ Se eliminará el pedido #${p['id']} de "${p['cliente']}".\n\nEsta acción no se puede deshacer.');
    if (ok && mounted) {
      try {
        await _servicio.eliminar(p['id']);
        if (mounted) {
          Notificacion.exito(context, 'Pedido eliminado');
          _cargar();
        }
      } catch (e) {
        if (mounted) {
          Notificacion.error(context,
              e.toString().replaceAll('Exception: ', ''));
        }
      }
    }
  }

  void _verDetalle(Map<String, dynamic> p) =>
      showDialog(context: context,
          builder: (_) => _DetallePedido(pedido: p));

  void _abrirFormulario({Map<String, dynamic>? pedido}) {
    showDialog(
      context: context, barrierDismissible: false,
      builder: (_) => _FormularioPedido(
        pedido: pedido, servicio: _servicio,
        onGuardado: (resultado) {
          Navigator.pop(context);
          Notificacion.exito(context,
              pedido == null ? 'Pedido creado' : 'Pedido actualizado');
          if (pedido != null && resultado['venta_generada'] == true) {
            final recibo = resultado['venta_numero_recibo'];
            Notificacion.advertencia(context,
                'Este pedido ya tenía la venta'
                '${recibo != null ? " #$recibo" : ""} generada — se '
                'actualizaron los productos y el inventario de esa venta '
                'automáticamente.');
          }
          _cargar();
        },
      ),
    );
  }

  Future<void> _imprimirListaDiaria() async {
    try {
      final fecha = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(2024),
        lastDate: DateTime.now().add(const Duration(days: 30)),
        helpText: 'Selecciona la fecha de la lista',
      );
      if (fecha == null || !mounted) return;

      final fechaStr =
          '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}';
      final pedidos = await _servicio.pedidosPorFecha(fechaStr);

      if (pedidos.isEmpty) {
        if (mounted) {
          Notificacion.advertencia(
              context, 'No hay pedidos para esa fecha');
        }
        return;
      }

      await _generarPdf(pedidos, fecha);
    } catch (e) {
      if (mounted) {
        Notificacion.error(context,
            e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  Future<void> _generarPdf(
      List<dynamic> pedidos, DateTime fecha) async {
    final doc      = pw.Document();
    final fechaStr =
        '${fecha.day.toString().padLeft(2, '0')}/'
        '${fecha.month.toString().padLeft(2, '0')}/'
        '${fecha.year}';

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      header: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Distribuidora Carolina',
                  style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold)),
              pw.Text('Pedidos del $fechaStr',
                  style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold)),
            ],
          ),
          pw.Divider(thickness: 1.5),
          pw.SizedBox(height: 6),
        ],
      ),
      build: (_) => pedidos.map((p) {
        final cliente  = p['cliente'] as String? ?? '-';
        final detalles = p['detalles'] as List? ?? [];
        // "5 Holandesa, 4 Cristy, 10 Chiquitano"
        final productos = detalles.map((d) {
          final cant = (d['cantidad'] as num).toDouble();
          final cantStr = cant % 1 == 0
              ? cant.toStringAsFixed(0)
              : cant.toStringAsFixed(1);
          return '$cantStr ${d['producto'] ?? '-'}';
        }).join(', ');

        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('$cliente: ',
                  style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold)),
              pw.Expanded(child: pw.Text(
                productos.isNotEmpty ? productos : '(sin productos)',
                style: const pw.TextStyle(fontSize: 12),
              )),
            ],
          ),
        );
      }).toList(),
    ));

    await Printing.layoutPdf(
      onLayout: (_) async => doc.save(),
      name: 'pedidos_$fechaStr.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtrados = _filtrados;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(),
        _buildBarra(),
        Expanded(child: _buildCuerpo(filtrados)),
      ],
    );
  }

  Widget _buildHeader() {
    final esMovil = Breakpoints.esMovil(context);
    final titulo = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Gestión de Pedidos',
            style: TextStyle(fontSize: 24,
                fontWeight: FontWeight.bold,
                color: ColoresCarolina.celesteOscuro)),
        const SizedBox(height: 4),
        const Text(
            'Registra, edita e imprime los pedidos de tus clientes.',
            style: TextStyle(fontSize: 12.5,
                color: ColoresCarolina.grisMedio)),
        const SizedBox(height: 8),
        _chip('${_pedidos.length} pedidos registrados',
            ColoresCarolina.celeste),
      ],
    );
    final botones = [
      ElevatedButton.icon(
        onPressed: _imprimirListaDiaria,
        icon: const Icon(Icons.print_rounded, size: 18),
        label: const Text('Imprimir lista'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      ),
      ElevatedButton.icon(
        onPressed: () => _abrirFormulario(),
        icon: const Icon(Icons.add_rounded, size: 18),
        label: const Text('Nuevo Pedido'),
        style: ElevatedButton.styleFrom(
          backgroundColor: ColoresCarolina.celeste,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
              horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      ),
    ];

    return Container(
      padding: EdgeInsets.fromLTRB(
          esMovil ? 16 : 28, 22, esMovil ? 16 : 28, 18),
      decoration: const BoxDecoration(color: Colors.white,
          border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0)))),
      child: esMovil
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titulo,
                const SizedBox(height: 14),
                Wrap(spacing: 10, runSpacing: 10, children: botones),
              ],
            )
          : Row(children: [
              Expanded(child: titulo),
              botones[0],
              const SizedBox(width: 10),
              botones[1],
            ]),
    );
  }

  Widget _buildBarra() => Container(
    padding: const EdgeInsets.symmetric(
        horizontal: 28, vertical: 12),
    color: Colors.white,
    child: Row(children: [
      Expanded(child: TextField(
        onChanged: (v) => setState(() => _busqueda = v),
        decoration: InputDecoration(
          hintText: 'Buscar por cliente o número...',
          prefixIcon: const Icon(Icons.search_rounded,
              color: ColoresCarolina.celeste),
          suffixIcon: _busqueda.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  tooltip: 'Limpiar búsqueda',
                  onPressed: () => setState(() => _busqueda = ''))
              : null,
          filled: true, fillColor: const Color(0xFFF1F5F9),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                  color: ColoresCarolina.celeste, width: 1.5)),
          contentPadding:
              const EdgeInsets.symmetric(vertical: 12),
        ),
      )),
      const SizedBox(width: 8),
      IconButton(
        onPressed: _cargar,
        icon: const Icon(Icons.refresh_rounded),
        color: ColoresCarolina.celeste,
        tooltip: 'Actualizar',
      ),
    ]),
  );

  Widget _buildCuerpo(List<dynamic> filtrados) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator(
          color: ColoresCarolina.celeste));
    }
    if (filtrados.isEmpty) {
      return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_bag_outlined, size: 72,
              color: ColoresCarolina.grisMedio
                  .withValues(alpha: 0.35)),
          const SizedBox(height: 14),
          Text(_busqueda.isNotEmpty
              ? 'No hay resultados para "$_busqueda"'
              : 'No hay pedidos registrados',
              style: const TextStyle(
                  color: ColoresCarolina.grisMedio,
                  fontSize: 15)),
        ],
      ));
    }

    if (Breakpoints.esMovil(context)) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filtrados.length,
        itemBuilder: (_, i) {
          final p = filtrados[i];
          return _TarjetaPedidoMovil(
            pedido:     p,
            onVer:      () => _verDetalle(p),
            onEditar:   () => _abrirFormulario(pedido: p),
            onEliminar: () => _eliminar(p),
          );
        },
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFFE2E8F0))),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Column(children: [
            Container(
              color: const Color(0xFFF8FAFC),
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 14),
              child: Row(children: [
                _th('#',         1),
                _th('CLIENTE',   3),
                _th('PRODUCTOS', 6),
                _th('ENTREGA',   2),
                _th('ACCIONES',  3),
              ]),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            ...filtrados.asMap().entries.map((e) {
              final p = e.value;
              return Column(children: [
                _FilaPedido(
                  pedido:     p,
                  impar:      e.key.isOdd,
                  onVer:      () => _verDetalle(p),
                  onEditar:   () => _abrirFormulario(pedido: p),
                  onEliminar: () => _eliminar(p),
                ),
                if (e.key < filtrados.length - 1)
                  const Divider(height: 1, color: Color(0xFFE2E8F0))
                else
                  const SizedBox.shrink(),
              ]);
            }),
          ]),
        ),
      ),
    );
  }

  Widget _th(String t, int flex) => Expanded(flex: flex,
      child: Text(t, style: const TextStyle(fontSize: 11,
          fontWeight: FontWeight.bold,
          color: ColoresCarolina.grisMedio,
          letterSpacing: 0.8)));

  Widget _chip(String t, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20)),
    child: Text(t, style: TextStyle(
        fontSize: 11, color: c, fontWeight: FontWeight.w600)),
  );
}

// ─── Fila ─────────────────────────────────────────────────────────────────────
class _FilaPedido extends StatelessWidget {
  final Map<String, dynamic> pedido;
  final bool impar;
  final VoidCallback onVer, onEditar, onEliminar;

  const _FilaPedido({
    required this.pedido,
    required this.impar,
    required this.onVer,
    required this.onEditar,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    final detalles = pedido['detalles'] as List? ?? [];
    final resumen  = detalles.take(3).map((d) {
      final cant = (d['cantidad'] as num).toDouble();
      final cantStr = cant % 1 == 0
          ? cant.toStringAsFixed(0) : cant.toStringAsFixed(1);
      return '$cantStr ${d['producto']}';
    }).join(', ');
    final extra =
        detalles.length > 3 ? ' +${detalles.length - 3} más' : '';
    final entrega    = pedido['fecha_entrega'];
    final entregaStr = entrega != null
        ? entrega.toString().substring(0, 10) : '—';

    return Container(
      color: impar ? const Color(0xFFFAFBFF) : Colors.white,
      padding: const EdgeInsets.symmetric(
          horizontal: 20, vertical: 12),
      child: Row(children: [
        Expanded(flex: 1, child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
              color: ColoresCarolina.celeste
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8)),
          child: Text('#${pedido['id']}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: ColoresCarolina.celeste)),
        )),
        Expanded(flex: 3, child: Text(
            pedido['cliente'] ?? '-',
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 13),
            overflow: TextOverflow.ellipsis)),
        Expanded(flex: 6, child: Text(
            '$resumen$extra',
            style: const TextStyle(
                fontSize: 12, color: Color(0xFF475569)),
            overflow: TextOverflow.ellipsis)),
        Expanded(flex: 2, child: Text(entregaStr,
            style: const TextStyle(
                fontSize: 12, color: Color(0xFF475569)))),
        Expanded(flex: 3, child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _btn(Icons.visibility_rounded,
                ColoresCarolina.celeste, 'Ver detalle', onVer),
            const SizedBox(width: 4),
            _btn(Icons.edit_rounded,
                Colors.orange, 'Editar', onEditar),
            const SizedBox(width: 4),
            _btn(Icons.delete_rounded,
                ColoresCarolina.rojo, 'Eliminar', onEliminar),
          ],
        )),
      ]),
    );
  }

  Widget _btn(IconData i, Color c, String tip, VoidCallback fn) =>
      Tooltip(message: tip,
        child: InkWell(onTap: fn, borderRadius: BorderRadius.circular(8),
          child: Container(padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(i, size: 16, color: c))));
}

// ─── Tarjeta móvil ────────────────────────────────────────────────────────────
class _TarjetaPedidoMovil extends StatelessWidget {
  final Map<String, dynamic> pedido;
  final VoidCallback onVer, onEditar, onEliminar;

  const _TarjetaPedidoMovil({
    required this.pedido,
    required this.onVer,
    required this.onEditar,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    final detalles = pedido['detalles'] as List? ?? [];
    final resumen  = detalles.take(3).map((d) {
      final cant = (d['cantidad'] as num).toDouble();
      final cantStr = cant % 1 == 0
          ? cant.toStringAsFixed(0) : cant.toStringAsFixed(1);
      return '$cantStr ${d['producto']}';
    }).join(', ');
    final extra =
        detalles.length > 3 ? ' +${detalles.length - 3} más' : '';
    final entrega    = pedido['fecha_entrega'];
    final entregaStr = entrega != null
        ? entrega.toString().substring(0, 10) : '—';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColoresCarolina.borde),
        boxShadow: ColoresCarolina.sombraTarjeta(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: ColoresCarolina.celeste.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: Text('#${pedido['id']}',
                  style: const TextStyle(fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: ColoresCarolina.celeste)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(
                pedido['cliente'] ?? '-',
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 15),
                overflow: TextOverflow.ellipsis)),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 14, runSpacing: 6, children: [
            _dato(Icons.shopping_bag_outlined,
                resumen.isNotEmpty ? '$resumen$extra' : '(sin productos)'),
            _dato(Icons.local_shipping_outlined, 'Entrega: $entregaStr'),
          ]),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _btn(Icons.visibility_rounded,
                  ColoresCarolina.celeste, 'Ver detalle', onVer),
              const SizedBox(width: 4),
              _btn(Icons.edit_rounded,
                  Colors.orange, 'Editar', onEditar),
              const SizedBox(width: 4),
              _btn(Icons.delete_rounded,
                  ColoresCarolina.rojo, 'Eliminar', onEliminar),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dato(IconData i, String t) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(i, size: 14, color: ColoresCarolina.grisMedio),
      const SizedBox(width: 5),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 220),
        child: Text(t,
            style: const TextStyle(
                fontSize: 12.5, color: Color(0xFF475569)),
            overflow: TextOverflow.ellipsis),
      ),
    ],
  );

  Widget _btn(IconData i, Color c, String tip, VoidCallback fn) =>
      Tooltip(message: tip,
        child: InkWell(onTap: fn, borderRadius: BorderRadius.circular(8),
          child: Container(padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(i, size: 16, color: c))));
}

// ─── Detalle ──────────────────────────────────────────────────────────────────
class _DetallePedido extends StatelessWidget {
  final Map<String, dynamic> pedido;
  const _DetallePedido({required this.pedido});

  @override
  Widget build(BuildContext context) {
    final detalles = pedido['detalles'] as List? ?? [];
    return Dialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.fromLTRB(22, 16, 12, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                  colors: [
                    ColoresCarolina.celeste,
                    ColoresCarolina.celesteOscuro
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.vertical(
                  top: Radius.circular(20))),
            child: Row(children: [
              const Icon(Icons.shopping_bag_rounded,
                  color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Expanded(child: Text(
                  'Pedido #${pedido['id']}',
                  style: const TextStyle(color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold))),
              IconButton(
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Cerrar',
                  icon: const Icon(Icons.close,
                      color: Colors.white)),
            ]),
          ),
          Flexible(child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info del cliente
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: ColoresCarolina.grisClaro,
                      borderRadius: BorderRadius.circular(12)),
                  child: Column(children: [
                    _fila(Icons.person_outline, 'Cliente',
                        pedido['cliente'] ?? '-'),
                    _fila(Icons.calendar_today_rounded,
                        'Fecha pedido',
                        pedido['fecha']?.toString()
                                .substring(0, 10) ?? '-'),
                    if (pedido['fecha_entrega'] != null)
                      _fila(Icons.local_shipping_rounded,
                          'Entrega',
                          pedido['fecha_entrega']),
                  ]),
                ),
                const SizedBox(height: 16),

                // Formato lista: "Ana: 5 Holandesa, 4 Cristy"
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0xFFE2E8F0))),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Row(children: [
                          Icon(Icons.list_alt_rounded,
                            color: ColoresCarolina.celeste,
                            size: 18),
                          SizedBox(width: 8),
                         Text('Lista del pedido',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: ColoresCarolina
                                    .celesteOscuro)),
                      ]),
                      const SizedBox(height: 10),
                      RichText(text: TextSpan(
                        style: const TextStyle(
                            fontSize: 14, color: Colors.black87),
                        children: [
                          TextSpan(
                            text: '${pedido['cliente']}: ',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color:
                                    ColoresCarolina.celesteOscuro),
                          ),
                          TextSpan(
                            text: detalles.map((d) {
                              final cant =
                                  (d['cantidad'] as num).toDouble();
                              final cantStr = cant % 1 == 0
                                  ? cant.toStringAsFixed(0)
                                  : cant.toStringAsFixed(1);
                              return '$cantStr ${d['producto']}';
                            }).join(', '),
                          ),
                        ],
                      )),
                    ],
                  ),
                ),

                if (pedido['nota'] != null &&
                    pedido['nota'].toString().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        border: Border.all(
                            color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.note_outlined,
                            size: 18,
                            color: ColoresCarolina.celeste),
                        const SizedBox(width: 8),
                        Expanded(child: Text(pedido['nota'],
                            style: const TextStyle(
                                fontSize: 13))),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          )),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: SizedBox(width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                    backgroundColor: ColoresCarolina.celeste,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(10))),
                child: const Text('Cerrar',
                    style: TextStyle(
                        fontWeight: FontWeight.bold)))),
          ),
        ]),
      ),
    );
  }

  Widget _fila(IconData i, String l, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      Icon(i, size: 16, color: ColoresCarolina.celeste),
      const SizedBox(width: 10),
      SizedBox(width: 100, child: Text(l,
          style: const TextStyle(
              color: ColoresCarolina.grisMedio,
              fontSize: 12))),
      Expanded(child: Text(v,
          style: const TextStyle(
              fontWeight: FontWeight.w600, fontSize: 13),
          overflow: TextOverflow.ellipsis)),
    ]),
  );
}

// ─── Formulario ───────────────────────────────────────────────────────────────
class _FormularioPedido extends StatefulWidget {
  final Map<String, dynamic>? pedido;
  final PedidosServicio        servicio;
  final void Function(Map<String, dynamic> resultado) onGuardado;
  const _FormularioPedido({
    this.pedido,
    required this.servicio,
    required this.onGuardado,
  });
  @override
  State<_FormularioPedido> createState() => _FormularioPedidoState();
}

class _FormularioPedidoState extends State<_FormularioPedido> {
  final _formKey  = GlobalKey<FormState>();
  final _notaCtrl = TextEditingController();

  List<dynamic> _clientes      = [];
  List<dynamic> _productos     = [];
  List<dynamic> _devolucionesPendientes = [];
  int?          _clienteId;
  DateTime      _fechaEntrega  = DateTime.now();
  bool          _cargando      = false;
  bool          _cargandoDatos = true;

  final List<Map<String, dynamic>> _items = [];

  bool get _esEdicion => widget.pedido != null;

  @override
  void initState() { super.initState(); _cargarDatos(); }

  @override
  void dispose() {
    _notaCtrl.dispose();
    for (final item in _items) {
      (item['cantidad'] as TextEditingController).dispose();
    }
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    try {
      final cl = await widget.servicio.listarClientes();
      final pr = await widget.servicio.listarProductos();
      setState(() {
        _clientes      =
            cl.where((c) => c['activo'] == true).toList();
        _productos     =
            pr.where((p) => p['activo'] == true).toList();
        _cargandoDatos = false;
      });

      if (_esEdicion) {
        final p = widget.pedido!;
        _clienteId      = p['cliente_id'] as int?;
        _notaCtrl.text  = p['nota'] ?? '';
        if (p['fecha_entrega'] != null) {
          final f = DateTime.tryParse(p['fecha_entrega']);
          if (f != null) _fechaEntrega = f;
        }
        final detalles = p['detalles'] as List? ?? [];
        for (final d in detalles) {
          final cant = (d['cantidad'] as num).toDouble();
          _items.add({
            'producto_id': d['producto_id'],
            'cantidad':    TextEditingController(
                text: cant % 1 == 0
                    ? cant.toStringAsFixed(0)
                    : cant.toStringAsFixed(2)),
          });
        }
        setState(() {});
      }
      if (_clienteId != null) {
        await _cargarDevolucionesPendientes(_clienteId!);
      }
    } catch (e) {
      if (mounted) {
        Notificacion.error(context,
            e.toString().replaceAll('Exception: ', ''));
        setState(() => _cargandoDatos = false);
      }
    }
  }

  Future<void> _cargarDevolucionesPendientes(int clienteId) async {
    try {
      final lista = await widget.servicio.listarDevolucionesPendientes(clienteId);
      if (mounted) setState(() => _devolucionesPendientes = lista);
    } catch (_) {
      // Aviso informativo: si falla, simplemente no se muestra el banner.
    }
  }

  Future<void> _seleccionarFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaEntrega,
      firstDate: DateTime.now(),
      lastDate:
          DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _fechaEntrega = picked);
    }
  }

  void _agregarProducto() {
    setState(() {
      _items.add({
        'producto_id': null,
        'cantidad':    TextEditingController(),
      });
    });
  }

  void _eliminarProducto(int index) {
    (_items[index]['cantidad'] as TextEditingController)
        .dispose();
    setState(() => _items.removeAt(index));
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_clienteId == null) {
      Notificacion.error(context, 'Selecciona un cliente');
      return;
    }
    if (_items.isEmpty) {
      Notificacion.error(
          context, 'Agrega al menos un producto');
      return;
    }
    for (final item in _items) {
      if (item['producto_id'] == null) {
        Notificacion.error(context,
            'Selecciona el producto en todos los ítems');
        return;
      }
    }

    setState(() => _cargando = true);
    final fechaStr =
        '${_fechaEntrega.year}-'
        '${_fechaEntrega.month.toString().padLeft(2, '0')}-'
        '${_fechaEntrega.day.toString().padLeft(2, '0')}';

    final detalles = _items.map((item) => {
      'producto_id': item['producto_id'],
      'cantidad':    double.tryParse(
              (item['cantidad'] as TextEditingController)
                  .text) ??
          0,
    }).toList();

    final datos = {
      'cliente_id':    _clienteId,
      'fecha_entrega': fechaStr,
      'nota':          _notaCtrl.text.trim(),
      'detalles':      detalles,
    };

    try {
      final resultado = _esEdicion
          ? await widget.servicio
              .actualizar(widget.pedido!['id'], datos)
          : await widget.servicio.crear(datos);
      widget.onGuardado(resultado);
    } catch (e) {
      if (mounted) {
        Notificacion.error(context,
            e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxWidth: 580,
            maxHeight:
                MediaQuery.of(context).size.height * 0.9),
        child: Column(children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(22, 16, 12, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                  colors: [
                    ColoresCarolina.celeste,
                    ColoresCarolina.celesteOscuro
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.vertical(
                  top: Radius.circular(20))),
            child: Row(children: [
              Icon(
                  _esEdicion
                      ? Icons.edit_rounded
                      : Icons.shopping_bag_rounded,
                  color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Text(
                  _esEdicion
                      ? 'Editar Pedido #${widget.pedido!['id']}'
                      : 'Nuevo Pedido',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Cerrar',
                  icon: const Icon(Icons.close,
                      color: Colors.white)),
            ]),
          ),

          // Body
          Flexible(child: _cargandoDatos
              ? const Center(child: CircularProgressIndicator(
                  color: ColoresCarolina.celeste))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        // Cliente
                        DropdownButtonFormField<int>(
                          initialValue: _clienteId,
                          decoration: _deco('Cliente *',
                              Icons.person_rounded),
                          items: _clientes
                              .map<DropdownMenuItem<int>>((c) =>
                                  DropdownMenuItem(
                                      value: c['id'] as int,
                                      child: Text(
                                          c['nombre_completo']
                                              as String,
                                          overflow: TextOverflow
                                              .ellipsis)))
                              .toList(),
                          onChanged: (v) {
                            setState(() {
                              _clienteId = v;
                              _devolucionesPendientes = [];
                            });
                            if (v != null) _cargarDevolucionesPendientes(v);
                          },
                          validator: (v) => v == null
                              ? 'Selecciona un cliente'
                              : null,
                        ),
                        if (_devolucionesPendientes.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _buildAvisoDevoluciones(),
                        ],
                        const SizedBox(height: 14),

                        // Fecha entrega
                        GestureDetector(
                          onTap: _seleccionarFecha,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 16),
                            decoration: BoxDecoration(
                                border: Border.all(
                                    color: Colors.grey.shade400),
                                borderRadius:
                                    BorderRadius.circular(10)),
                            child: Row(children: [
                              const Icon(
                                  Icons.calendar_today_rounded,
                                  color: ColoresCarolina.celeste,
                                  size: 20),
                              const SizedBox(width: 10),
                              Expanded(child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  const Text('Fecha de entrega',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: ColoresCarolina
                                              .grisMedio)),
                                  Text(
                                    '${_fechaEntrega.day.toString().padLeft(2, '0')}/'
                                    '${_fechaEntrega.month.toString().padLeft(2, '0')}/'
                                    '${_fechaEntrega.year}',
                                    style: const TextStyle(
                                        fontWeight:
                                            FontWeight.w600,
                                        fontSize: 14),
                                  ),
                                ],
                              )),
                              const Icon(
                                  Icons.edit_calendar_rounded,
                                  size: 16,
                                  color:
                                      ColoresCarolina.celeste),
                            ]),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Productos
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Productos',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: ColoresCarolina
                                        .celesteOscuro)),
                            ElevatedButton.icon(
                              onPressed: _agregarProducto,
                              icon: const Icon(Icons.add_rounded,
                                  size: 16),
                              label: const Text('Agregar'),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      ColoresCarolina.celeste,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 10),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(
                                              8))),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        if (_items.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius:
                                    BorderRadius.circular(12),
                                border: Border.all(
                                    color: const Color(
                                        0xFFE2E8F0))),
                            child: const Center(child: Text(
                                'Toca "Agregar" para añadir productos',
                                style: TextStyle(
                                    color: ColoresCarolina
                                        .grisMedio))),
                          ),

                        ..._items.asMap().entries.map((e) =>
                            _ItemPedido(
                              index:      e.key,
                              item:       e.value,
                              productos:  _productos,
                              onEliminar: () =>
                                  _eliminarProducto(e.key),
                              onChanged:
                                  () => setState(() {}),
                            )),

                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _notaCtrl,
                          maxLines: 2,
                          maxLength: 300,
                          decoration: _deco('Nota (opcional)',
                              Icons.note_outlined),
                        ),
                      ],
                    ),
                  ),
                )),

          // Footer
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                    foregroundColor: ColoresCarolina.grisMedio,
                    side: BorderSide(
                        color: Colors.grey.shade300),
                    padding: const EdgeInsets.symmetric(
                        vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(10))),
                child: const Text('Cancelar'),
              )),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: ElevatedButton(
                onPressed:
                    _cargando || _cargandoDatos ? null : _guardar,
                style: ElevatedButton.styleFrom(
                    backgroundColor: ColoresCarolina.celeste,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(10))),
                child: _cargando
                    ? const SizedBox(height: 20, width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text(
                        _esEdicion
                            ? 'Guardar Cambios'
                            : 'Crear Pedido',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
              )),
            ]),
          ),
        ]),
      ),
    );
  }

  InputDecoration _deco(String l, IconData i) => InputDecoration(
    labelText: l,
    prefixIcon: Icon(i, color: ColoresCarolina.celeste),
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10)),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(
            color: ColoresCarolina.celeste, width: 2)),
  );

  Widget _buildAvisoDevoluciones() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
          SizedBox(width: 8),
          Expanded(child: Text('Este cliente tiene devolución(es) pendiente(s)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.orange))),
        ]),
        const SizedBox(height: 6),
        ..._devolucionesPendientes.map((d) {
          final detalles = (d['detalles'] as List?) ?? [];
          final resumen = detalles.map((det) {
            final cant = (det['cantidad'] as num?)?.toDouble() ?? 0;
            final cantStr = cant % 1 == 0 ? cant.toStringAsFixed(0) : cant.toStringAsFixed(2);
            final motivo = kMotivosDevolucion[det['motivo']] ?? det['motivo'] ?? '';
            return '$cantStr ${det['producto']} ($motivo)';
          }).join(', ');
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('• $resumen',
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF7C4A03))),
          );
        }),
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Text(
              'Recuerda llevar el producto de cambio y registrarlo como resuelto '
              'cuando factures la venta.',
              style: TextStyle(fontSize: 11, color: Colors.orange, fontStyle: FontStyle.italic)),
        ),
      ]),
    );
  }
}

// ─── Item de pedido ───────────────────────────────────────────────────────────
class _ItemPedido extends StatefulWidget {
  final int index;
  final Map<String, dynamic> item;
  final List<dynamic> productos;
  final VoidCallback onEliminar, onChanged;

  const _ItemPedido({
    required this.index,
    required this.item,
    required this.productos,
    required this.onEliminar,
    required this.onChanged,
  });

  @override
  State<_ItemPedido> createState() => _ItemPedidoState();
}

class _ItemPedidoState extends State<_ItemPedido> {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(
          horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Row(children: [
        Container(
          width: 24, height: 24,
          decoration: BoxDecoration(
              color: ColoresCarolina.celeste
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6)),
          child: Center(child: Text('${widget.index + 1}',
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: ColoresCarolina.celeste,
                  fontSize: 11))),
        ),
        const SizedBox(width: 10),
        // Producto
        Expanded(flex: 5, child: DropdownButtonFormField<int>(
          initialValue: widget.item['producto_id'],
          decoration: InputDecoration(
            labelText: 'Producto *',
            prefixIcon: const Icon(Icons.inventory_2_outlined,
                color: ColoresCarolina.celeste, size: 18),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                    color: ColoresCarolina.celeste, width: 2)),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 12),
          ),
          items: widget.productos
              .map<DropdownMenuItem<int>>((p) =>
                  DropdownMenuItem(
                      value: p['id'] as int,
                      child: Text(p['nombre'] as String,
                          overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: (v) {
            setState(() => widget.item['producto_id'] = v);
            widget.onChanged();
          },
          validator: (v) =>
              v == null ? 'Selecciona un producto' : null,
        )),
        const SizedBox(width: 10),
        // Cantidad
        Expanded(flex: 2, child: TextFormField(
          controller:
              widget.item['cantidad'] as TextEditingController,
          keyboardType: const TextInputType.numberWithOptions(
              decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(
                RegExp(r'^\d*\.?\d*')),
          ],
          onChanged: (_) {
            setState(() {});
            widget.onChanged();
          },
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            labelText: 'Cant.',
            hintText: '0',
            suffixText: 'u.',
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                    color: ColoresCarolina.celeste, width: 2)),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 12),
          ),
          validator: (v) {
            final n = double.tryParse(v ?? '');
            if (n == null || n <= 0) return 'Min. 1';
            return null;
          },
        )),
        const SizedBox(width: 6),
        IconButton(
          onPressed: widget.onEliminar,
          icon: const Icon(Icons.delete_rounded, size: 18),
          tooltip: 'Quitar producto',
          color: ColoresCarolina.rojo,
          padding: const EdgeInsets.all(6),
          style: IconButton.styleFrom(
              backgroundColor:
                  ColoresCarolina.rojo.withValues(alpha: 0.1)),
        ),
      ]),
    );
  }
}