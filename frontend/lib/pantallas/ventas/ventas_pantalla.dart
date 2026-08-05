// carolina/frontend/lib/pantallas/ventas/ventas_pantalla.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';
import '../../constantes/colores.dart';
import '../../constantes/breakpoints.dart';
import '../../constantes/api.dart';
import '../../servicios/auth_servicio.dart';
import '../../widgets/notificacion.dart';
import '../devoluciones/devoluciones_pantalla.dart' show kMotivosDevolucion;
import '../cobranzas/cobranzas_pantalla.dart' show kMetodosPago;

// ─── Servicio ─────────────────────────────────────────────────────────────────
class VentasServicio {
  final _auth = AuthServicio();
  Future<Map<String, String>> get _h => _auth.obtenerHeaders();

  Future<List<dynamic>> listar() async {
    final res =
        await http.get(Uri.parse(ApiConfig.ventas), headers: await _h);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Error al cargar ventas');
  }

  Future<List<dynamic>> hoy() async {
    final res =
        await http.get(Uri.parse(ApiConfig.ventasHoy), headers: await _h);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Error al cargar las ventas de hoy');
  }

  Future<List<dynamic>> porFecha(String fecha) async {
    final res = await http.get(Uri.parse(ApiConfig.ventasPorFecha(fecha)),
        headers: await _h);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Error al cargar las ventas de esa fecha');
  }

  Future<Map<String, dynamic>> obtener(int id) async {
    final res = await http.get(Uri.parse(ApiConfig.ventaDetalle(id)),
        headers: await _h);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Error al cargar la venta');
  }

  Future<List<dynamic>> pedidosPendientes() async {
    final res = await http.get(
        Uri.parse(ApiConfig.ventasPedidosPendientes), headers: await _h);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Error al cargar los pedidos del día');
  }

  Future<Map<String, dynamic>> prepararDesdePedido(int pedidoId) async {
    final res = await http.get(
        Uri.parse(ApiConfig.ventaDesdePedido(pedidoId)), headers: await _h);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Error al preparar la venta desde el pedido');
  }

  Future<List<dynamic>> listarClientes() async {
    final res =
        await http.get(Uri.parse(ApiConfig.clientes), headers: await _h);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Error al cargar clientes');
  }

  Future<List<dynamic>> listarProductos() async {
    final res =
        await http.get(Uri.parse(ApiConfig.productos), headers: await _h);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Error al cargar productos');
  }

  Future<List<dynamic>> listarPrecios() async {
    final res =
        await http.get(Uri.parse(ApiConfig.precios), headers: await _h);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Error al cargar precios');
  }

  Future<Map<String, dynamic>> crear(Map<String, dynamic> datos) async {
    final res = await http.post(Uri.parse(ApiConfig.ventas),
        headers: await _h, body: jsonEncode(datos));
    final data = jsonDecode(res.body);
    if (res.statusCode == 201) return data;
    if (data['errores'] != null) {
      throw Exception((data['errores'] as Map).values.first.toString());
    }
    throw Exception(data['error'] ?? 'Error al registrar la venta');
  }

  Future<List<dynamic>> listarDevolucionesPendientes(int clienteId) async {
    final res = await http.get(
        Uri.parse('${ApiConfig.devoluciones}/pendientes/$clienteId'),
        headers: await _h);
    if (res.statusCode == 200) return jsonDecode(res.body);
    return [];
  }

  Future<List<dynamic>> listarSaldosPendientes(int clienteId) async {
    final res = await http.get(
        Uri.parse(ApiConfig.cobranzasPendientesPorCliente(clienteId)),
        headers: await _h);
    if (res.statusCode == 200) return jsonDecode(res.body);
    return [];
  }

  Future<Uint8List> obtenerReciboBytes(int ventaId) async {
    final res = await http.get(Uri.parse(ApiConfig.ventaRecibo(ventaId)),
        headers: await _h);
    if (res.statusCode == 200) return res.bodyBytes;
    throw Exception('Error al generar el recibo');
  }

  Future<Map<String, dynamic>> actualizarVenta(
      int id, Map<String, dynamic> datos) async {
    final res = await http.put(Uri.parse(ApiConfig.ventaDetalle(id)),
        headers: await _h, body: jsonEncode(datos));
    final data = jsonDecode(res.body);
    if (res.statusCode == 200) return data;
    if (data['errores'] != null) {
      throw Exception((data['errores'] as Map).values.first.toString());
    }
    throw Exception(data['error'] ?? 'Error al actualizar la venta');
  }

  Future<void> anular(int id) async {
    final res = await http.delete(Uri.parse(ApiConfig.ventaDetalle(id)),
        headers: await _h);
    if (res.statusCode == 200) return;
    final data = jsonDecode(res.body);
    throw Exception(data['error'] ?? 'Error al anular la venta');
  }
}

// ─── Pantalla ─────────────────────────────────────────────────────────────────
class VentasPantalla extends StatefulWidget {
  const VentasPantalla({super.key});
  @override
  State<VentasPantalla> createState() => _VentasPantallaState();
}

class _VentasPantallaState extends State<VentasPantalla> {
  final _servicio = VentasServicio();
  List<dynamic> _ventas = [];
  bool _cargando = true;
  String _busqueda = '';
  DateTime _fecha = DateTime.now();

  bool get _esHoy {
    final hoy = DateTime.now();
    return _fecha.year == hoy.year &&
        _fecha.month == hoy.month &&
        _fecha.day == hoy.day;
  }

  String get _fechaStr =>
      '${_fecha.year}-${_fecha.month.toString().padLeft(2, '0')}-'
      '${_fecha.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final v = _esHoy
          ? await _servicio.hoy()
          : await _servicio.porFecha(_fechaStr);
      setState(() => _ventas = v);
    } catch (e) {
      if (mounted) {
        Notificacion.error(context, e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _elegirFecha() async {
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      helpText: 'Ver ventas de una fecha',
    );
    if (elegida != null) {
      setState(() => _fecha = elegida);
      _cargar();
    }
  }

  void _irAHoy() {
    if (_esHoy) return;
    setState(() => _fecha = DateTime.now());
    _cargar();
  }

  List<dynamic> get _filtrados {
    if (_busqueda.isEmpty) return _ventas;
    final q = _busqueda.toLowerCase();
    return _ventas.where((v) =>
        (v['cliente'] ?? '').toLowerCase().contains(q) ||
        (v['numero_recibo'] ?? '').toLowerCase().contains(q) ||
        v['id'].toString().contains(q)).toList();
  }

  Future<void> _imprimirRecibo(int ventaId, String numeroRecibo) async {
    try {
      final bytes = await _servicio.obtenerReciboBytes(ventaId);
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: 'recibo_$numeroRecibo.pdf',
      );
    } catch (e) {
      if (mounted) {
        Notificacion.error(context, e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  Future<void> _ventaCreada(Map<String, dynamic> resultado) async {
    Navigator.pop(context); // cierra el formulario
    final venta = resultado['venta'] as Map<String, dynamic>;
    Notificacion.exito(context,
        'Venta registrada — recibo ${resultado['numero_recibo']}');
    _cargar();
    await _imprimirRecibo(venta['id'] as int, resultado['numero_recibo']);
  }

  void _abrirPedidosPendientes() {
    showDialog(
      context: context,
      builder: (_) => _PedidosPendientesDialog(
        servicio: _servicio,
        onSeleccionarPedido: (preparado) {
          Navigator.pop(context); // cierra el diálogo de pedidos
          _abrirFormularioVenta(pedidoOrigen: preparado);
        },
      ),
    );
  }

  void _abrirFormularioVenta({Map<String, dynamic>? pedidoOrigen}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _FormularioVenta(
        servicio: _servicio,
        pedidoOrigen: pedidoOrigen,
        onGuardado: _ventaCreada,
      ),
    );
  }

  void _verDetalle(Map<String, dynamic> ventaResumen) async {
    try {
      final venta = await _servicio.obtener(ventaResumen['id'] as int);
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => _DetalleVentaDialog(
            venta: venta,
            onImprimir: () =>
                _imprimirRecibo(venta['id'] as int, venta['numero_recibo']),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Notificacion.error(context, e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  Future<void> _ventaEditada(Map<String, dynamic> resultado) async {
    Navigator.pop(context); // cierra el formulario
    Notificacion.exito(context, 'Venta actualizada');
    _cargar();
  }

  void _editarVenta(Map<String, dynamic> ventaResumen) async {
    try {
      final venta = await _servicio.obtener(ventaResumen['id'] as int);
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => _FormularioVenta(
            servicio: _servicio,
            ventaOrigen: venta,
            onGuardado: _ventaEditada,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Notificacion.error(context, e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  Future<bool> _confirmar(String titulo, String msg) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: ColoresCarolina.rojo.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.warning_amber_rounded,
                  color: ColoresCarolina.rojo, size: 22)),
          const SizedBox(width: 12),
          Expanded(child: Text(titulo, style: const TextStyle(fontSize: 16))),
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
            child: const Text('Sí, anular'),
          ),
        ],
      ),
    );
    return r ?? false;
  }

  Future<void> _anularVenta(Map<String, dynamic> venta) async {
    final ok = await _confirmar('Anular venta',
        '⚠️ Se anulará el recibo ${venta['numero_recibo']} y se devolverá '
        'el stock vendido al inventario. Esta acción no se puede deshacer.');
    if (!ok) return;
    try {
      await _servicio.anular(venta['id'] as int);
      if (mounted) {
        Notificacion.exito(context, 'Venta anulada — stock revertido');
        _cargar();
      }
    } catch (e) {
      if (mounted) {
        Notificacion.error(context, e.toString().replaceAll('Exception: ', ''));
      }
    }
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

  Widget _buildHeader() => Container(
        padding: const EdgeInsets.fromLTRB(28, 22, 28, 18),
        decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0)))),
        child: Row(children: [
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Gestión de Ventas',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: ColoresCarolina.celesteOscuro)),
              const SizedBox(height: 6),
              _chip(
                  _esHoy
                      ? '${_ventas.length} ventas de hoy'
                      : '${_ventas.length} ventas el '
                          '${_fecha.day.toString().padLeft(2, '0')}/'
                          '${_fecha.month.toString().padLeft(2, '0')}/'
                          '${_fecha.year}',
                  ColoresCarolina.celeste),
            ],
          )),
          OutlinedButton.icon(
            onPressed: _elegirFecha,
            icon: const Icon(Icons.calendar_month_rounded, size: 18),
            label: Text(_esHoy
                ? 'Ver otra fecha'
                : '${_fecha.day.toString().padLeft(2, '0')}/'
                    '${_fecha.month.toString().padLeft(2, '0')}/'
                    '${_fecha.year}'),
            style: OutlinedButton.styleFrom(
              foregroundColor: ColoresCarolina.grisMedio,
              side: BorderSide(color: Colors.grey.shade400),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
          if (!_esHoy) ...[
            const SizedBox(width: 8),
            IconButton(
              onPressed: _irAHoy,
              icon: const Icon(Icons.today_rounded),
              color: ColoresCarolina.celeste,
              tooltip: 'Volver a hoy',
            ),
          ],
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: _abrirPedidosPendientes,
            icon: const Icon(Icons.receipt_long_rounded, size: 18),
            label: const Text('Pedidos del día'),
            style: OutlinedButton.styleFrom(
              foregroundColor: ColoresCarolina.celesteOscuro,
              side: const BorderSide(color: ColoresCarolina.celeste),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            onPressed: () => _abrirFormularioVenta(),
            icon: const Icon(Icons.point_of_sale_rounded, size: 18),
            label: const Text('Venta directa'),
            style: ElevatedButton.styleFrom(
              backgroundColor: ColoresCarolina.celeste,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ]),
      );

  Widget _buildBarra() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
        color: Colors.white,
        child: Row(children: [
          Expanded(
              child: TextField(
            onChanged: (v) => setState(() => _busqueda = v),
            decoration: InputDecoration(
              hintText: 'Buscar por cliente o número de recibo...',
              prefixIcon: const Icon(Icons.search_rounded,
                  color: ColoresCarolina.celeste),
              suffixIcon: _busqueda.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      tooltip: 'Limpiar búsqueda',
                      onPressed: () => setState(() => _busqueda = ''))
                  : null,
              filled: true,
              fillColor: const Color(0xFFF1F5F9),
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
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
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
      return const Center(
          child: CircularProgressIndicator(color: ColoresCarolina.celeste));
    }
    if (filtrados.isEmpty) {
      return Center(
          child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.point_of_sale_outlined,
              size: 72,
              color: ColoresCarolina.grisMedio.withValues(alpha: 0.35)),
          const SizedBox(height: 14),
          Text(
              _busqueda.isNotEmpty
                  ? 'No hay resultados para "$_busqueda"'
                  : 'No hay ventas registradas',
              style: const TextStyle(
                  color: ColoresCarolina.grisMedio, fontSize: 15)),
        ],
      ));
    }

    if (Breakpoints.esMovil(context)) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filtrados.length,
        itemBuilder: (_, i) {
          final v = filtrados[i];
          return _TarjetaVentaMovil(
            venta: v,
            onVer: () => _verDetalle(v),
            onImprimir: () =>
                _imprimirRecibo(v['id'] as int, v['numero_recibo'] ?? ''),
            onEditar: () => _editarVenta(v),
            onAnular: () => _anularVenta(v),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(children: [
                _th('RECIBO', 2),
                _th('CLIENTE', 3),
                _th('FECHA', 2),
                _th('TOTAL', 2),
                _th('PAGO', 2),
                _th('ACCIONES', 3),
              ]),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            ...filtrados.asMap().entries.map((e) {
              final v = e.value;
              return Column(children: [
                _FilaVenta(
                  venta: v,
                  impar: e.key.isOdd,
                  onVer: () => _verDetalle(v),
                  onImprimir: () => _imprimirRecibo(
                      v['id'] as int, v['numero_recibo'] ?? ''),
                  onEditar: () => _editarVenta(v),
                  onAnular: () => _anularVenta(v),
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

  Widget _th(String t, int flex) => Expanded(
      flex: flex,
      child: Text(t,
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: ColoresCarolina.grisMedio,
              letterSpacing: 0.8)));

  Widget _chip(String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: c.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20)),
        child: Text(t,
            style:
                TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.w600)),
      );
}

// ─── Chip de estado de pago (compartido tabla/tarjeta/detalle) ─────────────────
Widget chipEstadoPago(Map<String, dynamic> venta) {
  final estado = venta['estado_pago'] as String? ?? 'pagado';
  final saldo = (venta['saldo_pendiente'] as num?)?.toDouble() ?? 0;
  Color color;
  String texto;
  switch (estado) {
    case 'pendiente':
      color = ColoresCarolina.rojo;
      texto = 'Debe Bs ${saldo.toStringAsFixed(2)}';
      break;
    case 'parcial':
      color = Colors.orange;
      texto = 'Falta Bs ${saldo.toStringAsFixed(2)}';
      break;
    default:
      color = ColoresCarolina.exito;
      texto = 'Pagado';
  }
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
    child: Text(texto,
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: color),
        overflow: TextOverflow.ellipsis),
  );
}

// ─── Fila del historial ────────────────────────────────────────────────────────
class _FilaVenta extends StatelessWidget {
  final Map<String, dynamic> venta;
  final bool impar;
  final VoidCallback onVer, onImprimir, onEditar, onAnular;

  const _FilaVenta({
    required this.venta,
    required this.impar,
    required this.onVer,
    required this.onImprimir,
    required this.onEditar,
    required this.onAnular,
  });

  @override
  Widget build(BuildContext context) {
    final total = (venta['total'] as num?)?.toDouble() ?? 0;
    final fecha = venta['fecha']?.toString() ?? '';
    final fechaStr = fecha.length >= 16 ? fecha.substring(0, 16) : fecha;
    final anulada = venta['estado'] == 'anulada';

    return Container(
      color: anulada
          ? ColoresCarolina.rojoClaro.withValues(alpha: 0.35)
          : (impar ? const Color(0xFFFAFBFF) : Colors.white),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(children: [
        Expanded(
            flex: 2,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                  color: ColoresCarolina.celeste.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: Text(venta['numero_recibo'] ?? '-',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: ColoresCarolina.celeste)),
            )),
        Expanded(
            flex: 3,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Flexible(
                  child: Text(venta['cliente'] ?? '-',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          decoration: anulada
                              ? TextDecoration.lineThrough
                              : null,
                          color: anulada
                              ? ColoresCarolina.grisMedio
                              : Colors.black87),
                      overflow: TextOverflow.ellipsis)),
              if (anulada) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: ColoresCarolina.rojo,
                      borderRadius: BorderRadius.circular(6)),
                  child: const Text('ANULADA',
                      style: TextStyle(
                          fontSize: 9,
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ])),
        Expanded(
            flex: 2,
            child: Text(fechaStr,
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF475569)))),
        Expanded(
            flex: 2,
            child: Text('Bs ${total.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: ColoresCarolina.celesteOscuro))),
        Expanded(flex: 2, child: chipEstadoPago(venta)),
        Expanded(
            flex: 3,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _btn(Icons.visibility_rounded, ColoresCarolina.celeste,
                  'Ver detalle', onVer),
              const SizedBox(width: 4),
              _btn(Icons.print_rounded, Colors.green.shade700,
                  'Reimprimir recibo', onImprimir),
              if (!anulada) ...[
                const SizedBox(width: 4),
                _btn(Icons.edit_rounded, Colors.orange, 'Editar venta',
                    onEditar),
                const SizedBox(width: 4),
                _btn(Icons.cancel_outlined, ColoresCarolina.rojo,
                    'Anular venta', onAnular),
              ],
            ])),
      ]),
    );
  }

  Widget _btn(IconData i, Color c, String tip, VoidCallback fn) => Tooltip(
      message: tip,
      child: InkWell(
          onTap: fn,
          borderRadius: BorderRadius.circular(8),
          child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(i, size: 16, color: c))));
}

// ─── Tarjeta del historial (vista móvil) ───────────────────────────────────────
class _TarjetaVentaMovil extends StatelessWidget {
  final Map<String, dynamic> venta;
  final VoidCallback onVer, onImprimir, onEditar, onAnular;

  const _TarjetaVentaMovil({
    required this.venta,
    required this.onVer,
    required this.onImprimir,
    required this.onEditar,
    required this.onAnular,
  });

  @override
  Widget build(BuildContext context) {
    final total = (venta['total'] as num?)?.toDouble() ?? 0;
    final fecha = venta['fecha']?.toString() ?? '';
    final fechaStr = fecha.length >= 16 ? fecha.substring(0, 16) : fecha;
    final anulada = venta['estado'] == 'anulada';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: anulada
            ? ColoresCarolina.rojoClaro.withValues(alpha: 0.35)
            : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColoresCarolina.borde),
        boxShadow: ColoresCarolina.sombraTarjeta(),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: ColoresCarolina.celeste.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8)),
            child: Text(venta['numero_recibo'] ?? '-',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: ColoresCarolina.celeste)),
          ),
          const Spacer(),
          if (anulada)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: ColoresCarolina.rojo,
                  borderRadius: BorderRadius.circular(6)),
              child: const Text('ANULADA',
                  style: TextStyle(
                      fontSize: 9,
                      color: Colors.white,
                      fontWeight: FontWeight.bold)),
            ),
        ]),
        const SizedBox(height: 8),
        Text(venta['cliente'] ?? '-',
            style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                decoration: anulada ? TextDecoration.lineThrough : null,
                color: anulada
                    ? ColoresCarolina.grisMedio
                    : ColoresCarolina.textoFuerte)),
        const SizedBox(height: 4),
        Text(fechaStr,
            style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
        const SizedBox(height: 8),
        if (!anulada) chipEstadoPago(venta),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Bs ${total.toStringAsFixed(2)}',
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: ColoresCarolina.celesteOscuro)),
          Row(mainAxisSize: MainAxisSize.min, children: [
            _btn(Icons.visibility_rounded, ColoresCarolina.celeste,
                'Ver detalle', onVer),
            const SizedBox(width: 6),
            _btn(Icons.print_rounded, Colors.green.shade700,
                'Reimprimir recibo', onImprimir),
            if (!anulada) ...[
              const SizedBox(width: 6),
              _btn(Icons.edit_rounded, Colors.orange, 'Editar venta',
                  onEditar),
              const SizedBox(width: 6),
              _btn(Icons.cancel_outlined, ColoresCarolina.rojo,
                  'Anular venta', onAnular),
            ],
          ]),
        ]),
      ]),
    );
  }

  Widget _btn(IconData i, Color c, String tip, VoidCallback fn) => Tooltip(
      message: tip,
      child: InkWell(
          onTap: fn,
          borderRadius: BorderRadius.circular(8),
          child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(i, size: 16, color: c))));
}

// ─── Diálogo: pedidos pendientes del día ───────────────────────────────────────
class _PedidosPendientesDialog extends StatefulWidget {
  final VentasServicio servicio;
  final void Function(Map<String, dynamic> preparado) onSeleccionarPedido;

  const _PedidosPendientesDialog({
    required this.servicio,
    required this.onSeleccionarPedido,
  });

  @override
  State<_PedidosPendientesDialog> createState() =>
      _PedidosPendientesDialogState();
}

class _PedidosPendientesDialogState extends State<_PedidosPendientesDialog> {
  List<dynamic> _pedidos = [];
  bool _cargando = true;
  int? _procesando;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final p = await widget.servicio.pedidosPendientes();
      setState(() => _pedidos = p);
    } catch (e) {
      if (mounted) {
        Notificacion.error(context, e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _vender(Map<String, dynamic> pedido) async {
    setState(() => _procesando = pedido['id'] as int);
    try {
      final preparado =
          await widget.servicio.prepararDesdePedido(pedido['id'] as int);
      widget.onSeleccionarPedido(preparado);
    } catch (e) {
      if (mounted) {
        Notificacion.error(context, e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _procesando = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
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
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(children: [
              const Icon(Icons.receipt_long_rounded,
                  color: Colors.white, size: 22),
              const SizedBox(width: 10),
              const Expanded(
                  child: Text('Pedidos del día pendientes de venta',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold))),
              IconButton(
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Cerrar',
                  icon: const Icon(Icons.close, color: Colors.white)),
            ]),
          ),
          Flexible(
            child: _cargando
                ? const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                        child: CircularProgressIndicator(
                            color: ColoresCarolina.celeste)))
                : _pedidos.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(children: [
                          Icon(Icons.check_circle_outline_rounded,
                              size: 56,
                              color: ColoresCarolina.grisMedio
                                  .withValues(alpha: 0.4)),
                          const SizedBox(height: 12),
                          const Text(
                              'No hay pedidos pendientes de facturar hoy',
                              style: TextStyle(
                                  color: ColoresCarolina.grisMedio)),
                        ]),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.all(16),
                        itemCount: _pedidos.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final p = _pedidos[i];
                          final detalles = p['detalles'] as List? ?? [];
                          final resumen = detalles.take(4).map((d) {
                            final cant = (d['cantidad'] as num).toDouble();
                            final cantStr = cant % 1 == 0
                                ? cant.toStringAsFixed(0)
                                : cant.toStringAsFixed(1);
                            return '$cantStr ${d['producto']}';
                          }).join(', ');
                          final procesandoEste = _procesando == p['id'];
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: const Color(0xFFE2E8F0))),
                            child: Row(children: [
                              Expanded(
                                  child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(p['cliente'] ?? '-',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: ColoresCarolina
                                              .celesteOscuro)),
                                  const SizedBox(height: 4),
                                  Text(resumen,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF475569))),
                                ],
                              )),
                              const SizedBox(width: 10),
                              ElevatedButton.icon(
                                onPressed: procesandoEste
                                    ? null
                                    : () => _vender(p),
                                icon: procesandoEste
                                    ? const SizedBox(
                                        height: 14,
                                        width: 14,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white))
                                    : const Icon(
                                        Icons.point_of_sale_rounded,
                                        size: 16),
                                label: const Text('Vender'),
                                style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        ColoresCarolina.celeste,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(8))),
                              ),
                            ]),
                          );
                        },
                      ),
          ),
        ]),
      ),
    );
  }
}

// ─── Formulario de venta ────────────────────────────────────────────────────────
class _FormularioVenta extends StatefulWidget {
  final VentasServicio servicio;
  final Map<String, dynamic>? pedidoOrigen;
  final Map<String, dynamic>? ventaOrigen;
  final void Function(Map<String, dynamic> resultado) onGuardado;

  const _FormularioVenta({
    required this.servicio,
    this.pedidoOrigen,
    this.ventaOrigen,
    required this.onGuardado,
  });

  @override
  State<_FormularioVenta> createState() => _FormularioVentaState();
}

class _FormularioVentaState extends State<_FormularioVenta> {
  final _formKey = GlobalKey<FormState>();
  final _notaCtrl = TextEditingController();
  final _descuentoCtrl = TextEditingController(text: '0');
  final _montoPagadoCtrl = TextEditingController(text: '0');

  bool _cargandoDatos = true;
  bool _guardando = false;
  bool _pagoCompleto = true;
  String _metodoPago = 'efectivo';

  List<dynamic> _clientes = [];
  List<dynamic> _productos = [];
  Map<int, double> _preciosVenta = {}; // producto_id -> precio catálogo

  int? _clienteId;
  String? _clienteNombreFijo;
  final List<Map<String, dynamic>> _items = [];

  List<dynamic> _devolucionesPendientes = [];
  final Set<int> _devolucionesAResolver = {};
  List<dynamic> _saldosPendientes = [];

  bool get _esDesdePedido => widget.pedidoOrigen != null;
  bool get _esEdicion => widget.ventaOrigen != null;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void dispose() {
    _notaCtrl.dispose();
    _descuentoCtrl.dispose();
    _montoPagadoCtrl.dispose();
    for (final item in _items) {
      (item['cantidadCtrl'] as TextEditingController).dispose();
      (item['precioCtrl'] as TextEditingController).dispose();
    }
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    try {
      if (_esDesdePedido) {
        final p = widget.pedidoOrigen!;
        _clienteId = p['cliente_id'] as int?;
        _clienteNombreFijo = p['cliente'] as String?;
        final detalles = p['detalles'] as List? ?? [];
        for (final d in detalles) {
          final devolucionId = d['devolucion_id'] as int?;
          final nombre = d['producto'] as String? ?? '-';
          _items.add(_crearItem(
            productoId: d['producto_id'] as int,
            productoNombre: devolucionId != null ? '$nombre (Reemplazo)' : nombre,
            cantidad: (d['cantidad'] as num).toDouble(),
            precio: devolucionId != null ? 0.0 : (d['precio_unitario'] as num).toDouble(),
            stockDisponible: (d['stock_disponible'] as num).toDouble(),
            devolucionId: devolucionId,
          ));
          if (devolucionId != null) _devolucionesAResolver.add(devolucionId);
        }
      } else {
        // Venta directa o edición: ambas necesitan clientes/productos/precios
        final cl = await widget.servicio.listarClientes();
        final pr = await widget.servicio.listarProductos();
        final precios = await widget.servicio.listarPrecios();
        _clientes = cl.where((c) => c['activo'] == true).toList();
        _productos = pr.where((p) => p['activo'] == true).toList();
        _preciosVenta = {
          for (final row in precios)
            if (row['precio_venta'] != null)
              row['producto_id'] as int: (row['precio_venta'] as num).toDouble()
        };

        if (_esEdicion) {
          final v = widget.ventaOrigen!;
          _clienteId = v['cliente_id'] as int?;
          _notaCtrl.text = v['nota']?.toString() ?? '';
          final descuento = (v['descuento'] as num?)?.toDouble() ?? 0;
          _descuentoCtrl.text = descuento % 1 == 0
              ? descuento.toStringAsFixed(0)
              : descuento.toStringAsFixed(2);
          final detalles = v['detalles'] as List? ?? [];
          for (final d in detalles) {
            final productoId = d['producto_id'] as int;
            final cantidad = (d['cantidad'] as num).toDouble();
            final devolucionId = d['devolucion_id'] as int?;
            final prod = _productos.firstWhere((p) => p['id'] == productoId,
                orElse: () => null);
            final stockCatalogo =
                prod != null ? ((prod['stock'] as num?)?.toDouble() ?? 0) : 0.0;
            final nombre = d['producto'] as String? ?? '-';
            _items.add(_crearItem(
              productoId: productoId,
              productoNombre: devolucionId != null ? '$nombre (Reemplazo)' : nombre,
              cantidad: cantidad,
              precio: devolucionId != null
                  ? 0.0
                  : (d['precio_unitario'] as num).toDouble(),
              stockDisponible: stockCatalogo + cantidad,
              precioEspecial: d['precio_editado'] == true,
              productoOriginalId: productoId,
              cantidadOriginal: cantidad,
              devolucionId: devolucionId,
            ));
          }
        }
      }
      if (_clienteId != null && !_esEdicion) {
        await _cargarDevolucionesPendientes(_clienteId!);
        await _cargarSaldosPendientes(_clienteId!);
      }
      setState(() => _cargandoDatos = false);
    } catch (e) {
      if (mounted) {
        Notificacion.error(context, e.toString().replaceAll('Exception: ', ''));
        setState(() => _cargandoDatos = false);
      }
    }
  }

  String _notaParaGuardar() {
    final base = _notaCtrl.text.trim();
    if (_devolucionesAResolver.isEmpty) return base;
    final partes = _devolucionesPendientes
        .where((d) => _devolucionesAResolver.contains(d['id']))
        .map((d) {
      final detalles = (d['detalles'] as List?) ?? [];
      final resumen = detalles.map((det) {
        final cant = (det['cantidad'] as num?)?.toDouble() ?? 0;
        final cantStr = cant % 1 == 0 ? cant.toStringAsFixed(0) : cant.toStringAsFixed(2);
        return '$cantStr ${det['producto']}';
      }).join(', ');
      return 'Cambio por devolución: $resumen';
    }).join(' | ');
    return base.isEmpty ? partes : '$base\n$partes';
  }

  Future<void> _cargarDevolucionesPendientes(int clienteId) async {
    try {
      final lista = await widget.servicio.listarDevolucionesPendientes(clienteId);
      if (mounted) setState(() => _devolucionesPendientes = lista);
    } catch (_) {
      // Aviso informativo: si falla, simplemente no se muestra el banner.
    }
  }

  Future<void> _cargarSaldosPendientes(int clienteId) async {
    try {
      final lista = await widget.servicio.listarSaldosPendientes(clienteId);
      if (mounted) setState(() => _saldosPendientes = lista);
    } catch (_) {
      // Aviso informativo: si falla, simplemente no se muestra el banner.
    }
  }

  Map<String, dynamic> _crearItem({
    required int productoId,
    required String productoNombre,
    required double cantidad,
    required double precio,
    double? stockDisponible,
    bool precioEspecial = false,
    int? productoOriginalId,
    double? cantidadOriginal,
    int? devolucionId,
  }) {
    return {
      'producto_id': productoId,
      'producto_nombre': productoNombre,
      'cantidadCtrl': TextEditingController(
          text: cantidad % 1 == 0
              ? cantidad.toStringAsFixed(0)
              : cantidad.toStringAsFixed(2)),
      'precioCtrl':
          TextEditingController(text: precio.toStringAsFixed(2)),
      'precio_sugerido': precio,
      'stock_disponible': stockDisponible,
      'precio_especial': precioEspecial,
      // Si el producto de esta línea no cambia, al editar se le vuelve a
      // sumar cantidad_original al stock del catálogo (el backend revierte
      // el descuento anterior antes de validar el nuevo).
      'producto_original_id': productoOriginalId,
      'cantidad_original': cantidadOriginal,
      // Producto de reemplazo entregado por una devolución (sin costo).
      'devolucion_id': devolucionId,
      'es_reemplazo': devolucionId != null,
    };
  }

  double _calcularStockDisponible(
      Map<String, dynamic> item, int productoId, double stockCatalogo) {
    if (item['producto_original_id'] == productoId) {
      return stockCatalogo + (item['cantidad_original'] as double? ?? 0);
    }
    return stockCatalogo;
  }

  void _agregarProductoManual() {
    setState(() {
      _items.add({
        'producto_id': null,
        'producto_nombre': null,
        'cantidadCtrl': TextEditingController(),
        'precioCtrl': TextEditingController(),
        'precio_sugerido': 0.0,
        'stock_disponible': null,
        'precio_especial': false,
      });
    });
  }

  void _eliminarItem(int index) {
    (_items[index]['cantidadCtrl'] as TextEditingController).dispose();
    (_items[index]['precioCtrl'] as TextEditingController).dispose();
    setState(() => _items.removeAt(index));
  }

  void _productoSeleccionado(int index, int productoId, String nombre) {
    final sugerido = _preciosVenta[productoId] ?? 0.0;
    final inventarioProd =
        _productos.firstWhere((p) => p['id'] == productoId, orElse: () => null);
    final stockCatalogo = inventarioProd != null
        ? ((inventarioProd['stock'] as num?)?.toDouble() ?? 0)
        : 0.0;
    setState(() {
      _items[index]['producto_id'] = productoId;
      _items[index]['producto_nombre'] = nombre;
      _items[index]['precio_sugerido'] = sugerido;
      _items[index]['stock_disponible'] =
          _calcularStockDisponible(_items[index], productoId, stockCatalogo);
      if (_items[index]['precio_especial'] != true) {
        (_items[index]['precioCtrl'] as TextEditingController).text =
            sugerido.toStringAsFixed(2);
      }
    });
  }

  void _alternarPrecioEspecial(int index, bool valor) {
    setState(() {
      _items[index]['precio_especial'] = valor;
      if (!valor) {
        final sugerido = _items[index]['precio_sugerido'] as double;
        (_items[index]['precioCtrl'] as TextEditingController).text =
            sugerido.toStringAsFixed(2);
      }
    });
  }

  double get _total {
    double t = 0;
    for (final item in _items) {
      final cant =
          double.tryParse((item['cantidadCtrl'] as TextEditingController).text) ??
              0;
      final precio =
          double.tryParse((item['precioCtrl'] as TextEditingController).text) ??
              0;
      t += cant * precio;
    }
    final descuento = double.tryParse(_descuentoCtrl.text) ?? 0;
    return t - descuento;
  }

  Future<void> _guardar() async {
    if (_items.isEmpty) {
      Notificacion.error(context, 'Agrega al menos un producto');
      return;
    }
    for (final item in _items) {
      if (item['producto_id'] == null) {
        Notificacion.error(context, 'Selecciona el producto en todos los ítems');
        return;
      }
      final cant =
          double.tryParse((item['cantidadCtrl'] as TextEditingController).text);
      if (cant == null || cant <= 0) {
        Notificacion.error(context, 'Cantidad inválida en algún producto');
        return;
      }
      final stock = item['stock_disponible'] as double?;
      if (stock != null && cant > stock) {
        Notificacion.error(context,
            'Stock insuficiente de "${item['producto_nombre']}" (disponible: $stock)');
        return;
      }
      final precio =
          double.tryParse((item['precioCtrl'] as TextEditingController).text);
      final esReemplazo = item['es_reemplazo'] == true;
      if (precio == null || (precio <= 0 && !esReemplazo)) {
        Notificacion.error(context, 'Precio inválido en algún producto');
        return;
      }
    }
    if (!_esDesdePedido && _clienteId == null) {
      Notificacion.error(context, 'Selecciona un cliente');
      return;
    }
    if (!_esEdicion && !_pagoCompleto) {
      final n = double.tryParse(_montoPagadoCtrl.text.trim());
      if (n == null || n < 0) {
        Notificacion.error(context, 'Ingresa un monto pagado válido');
        return;
      }
      if (n > _total + 0.01) {
        Notificacion.error(context,
            'El monto pagado no puede superar el total (Bs ${_total.toStringAsFixed(2)})');
        return;
      }
    }

    setState(() => _guardando = true);

    final detalles = _items.map((item) {
      return {
        'producto_id': item['producto_id'],
        'cantidad': double.parse(
            (item['cantidadCtrl'] as TextEditingController).text),
        'precio_unitario': double.parse(
            (item['precioCtrl'] as TextEditingController).text),
        'precio_editado': item['precio_especial'] == true,
        if (item['devolucion_id'] != null) 'devolucion_id': item['devolucion_id'],
      };
    }).toList();

    final datos = {
      'cliente_id': _clienteId,
      if (_esDesdePedido) 'pedido_id': widget.pedidoOrigen!['pedido_id'],
      'descuento': double.tryParse(_descuentoCtrl.text) ?? 0,
      'nota': _notaParaGuardar(),
      'detalles': detalles,
      if (!_esEdicion) 'monto_pagado': _montoPagadoFinal,
      if (!_esEdicion && _montoPagadoFinal > 0) 'metodo_pago': _metodoPago,
    };

    try {
      final resultado = _esEdicion
          ? await widget.servicio
              .actualizarVenta(widget.ventaOrigen!['id'] as int, datos)
          : await widget.servicio.crear(datos);
      // La devolución se marca como resuelta automáticamente en el backend
      // al guardar la venta (viene indicado en cada detalle con devolucion_id).
      widget.onGuardado(resultado);
    } catch (e) {
      if (mounted) {
        Notificacion.error(context, e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxWidth: 620, maxHeight: MediaQuery.of(context).size.height * 0.9),
        child: Column(children: [
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
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(children: [
              Icon(
                  _esEdicion
                      ? Icons.edit_rounded
                      : Icons.point_of_sale_rounded,
                  color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(
                      _esEdicion
                          ? 'Editar venta — recibo ${widget.ventaOrigen!['numero_recibo']}'
                          : _esDesdePedido
                              ? 'Registrar venta (Pedido #${widget.pedidoOrigen!['pedido_id']})'
                              : 'Venta directa',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold))),
              IconButton(
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Cerrar',
                  icon: const Icon(Icons.close, color: Colors.white)),
            ]),
          ),
          Flexible(
            child: _cargandoDatos
                ? const Center(
                    child:
                        CircularProgressIndicator(color: ColoresCarolina.celeste))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_esDesdePedido)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                  color: ColoresCarolina.grisClaro,
                                  borderRadius: BorderRadius.circular(10)),
                              child: Row(children: [
                                const Icon(Icons.person_outline,
                                    size: 18, color: ColoresCarolina.celeste),
                                const SizedBox(width: 8),
                                Text(_clienteNombreFijo ?? '-',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14)),
                              ]),
                            )
                          else
                            DropdownButtonFormField<int>(
                              initialValue: _clienteId,
                              decoration: _deco(
                                  'Cliente *', Icons.person_rounded),
                              items: _clientes
                                  .map<DropdownMenuItem<int>>((c) =>
                                      DropdownMenuItem(
                                          value: c['id'] as int,
                                          child: Text(
                                              c['nombre_completo'] as String,
                                              overflow:
                                                  TextOverflow.ellipsis)))
                                  .toList(),
                              onChanged: (v) {
                                setState(() {
                                  _clienteId = v;
                                  _devolucionesPendientes = [];
                                  _devolucionesAResolver.clear();
                                  _saldosPendientes = [];
                                });
                                if (v != null) {
                                  _cargarDevolucionesPendientes(v);
                                  _cargarSaldosPendientes(v);
                                }
                              },
                              validator: (v) =>
                                  v == null ? 'Selecciona un cliente' : null,
                            ),
                          if (_devolucionesPendientes.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _buildAvisoDevoluciones(),
                          ],
                          if (_saldosPendientes.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _buildAvisoSaldo(),
                          ],
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Productos',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: ColoresCarolina.celesteOscuro)),
                              if (!_esDesdePedido)
                                ElevatedButton.icon(
                                  onPressed: _agregarProductoManual,
                                  icon: const Icon(Icons.add_rounded, size: 16),
                                  label: const Text('Agregar'),
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          ColoresCarolina.celeste,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 10),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8))),
                                ),
                            ],
                          ),
                          if (!_esDesdePedido) ...[
                            const SizedBox(height: 2),
                            const Text(
                                'Agrega los productos vendidos y ajusta cantidad o precio si corresponde',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: ColoresCarolina.grisMedio)),
                          ],
                          const SizedBox(height: 10),
                          if (_items.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: const Color(0xFFE2E8F0))),
                              child: const Center(
                                  child: Text(
                                      'Toca "Agregar" para añadir productos',
                                      style: TextStyle(
                                          color: ColoresCarolina.grisMedio))),
                            ),
                          ..._items.asMap().entries.map((e) => _ItemVenta(
                                index: e.key,
                                item: e.value,
                                productos: _productos,
                                soloLectura: _esDesdePedido,
                                onProductoSeleccionado: (id, nombre) =>
                                    _productoSeleccionado(e.key, id, nombre),
                                onPrecioEspecialCambiado: (v) =>
                                    _alternarPrecioEspecial(e.key, v),
                                onEliminar: () => _eliminarItem(e.key),
                                onChanged: () => setState(() {}),
                              )),
                          const SizedBox(height: 14),
                          Row(children: [
                            Expanded(
                              child: TextFormField(
                                controller: _descuentoCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                      RegExp(r'^\d*\.?\d*')),
                                ],
                                onChanged: (_) => setState(() {}),
                                decoration: _deco('Descuento (Bs)',
                                    Icons.discount_outlined),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 16),
                                decoration: BoxDecoration(
                                    color: ColoresCarolina.grisClaro,
                                    borderRadius: BorderRadius.circular(10)),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('TOTAL',
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: ColoresCarolina.grisMedio)),
                                    Text('Bs ${_total.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color:
                                                ColoresCarolina.celesteOscuro)),
                                  ],
                                ),
                              ),
                            ),
                          ]),
                          if (!_esEdicion) ...[
                            const SizedBox(height: 14),
                            _buildSeccionPago(),
                          ],
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _notaCtrl,
                            maxLines: 2,
                            maxLength: 300,
                            decoration:
                                _deco('Nota (opcional)', Icons.note_outlined),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Row(children: [
              Expanded(
                  child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                    foregroundColor: ColoresCarolina.grisMedio,
                    side: BorderSide(color: Colors.grey.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
                child: const Text('Cancelar'),
              )),
              const SizedBox(width: 12),
              Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _guardando || _cargandoDatos ? null : _guardar,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: ColoresCarolina.celeste,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10))),
                    child: _guardando
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Text(
                            _esEdicion
                                ? 'Guardar cambios'
                                : 'Registrar venta e imprimir recibo',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.bold)),
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: ColoresCarolina.celeste, width: 2)),
      );

  void _toggleReemplazo(Map<String, dynamic> devolucion, bool marcar) {
    final id = devolucion['id'] as int;
    setState(() {
      if (marcar) {
        _devolucionesAResolver.add(id);
        final detalles = (devolucion['detalles'] as List?) ?? [];
        for (final det in detalles) {
          _items.add(_crearItem(
            productoId: det['producto_id'] as int,
            productoNombre: '${det['producto']} (Reemplazo)',
            cantidad: (det['cantidad'] as num).toDouble(),
            precio: 0.0,
            devolucionId: id,
          ));
        }
      } else {
        _devolucionesAResolver.remove(id);
        _items.removeWhere((item) {
          if (item['devolucion_id'] == id) {
            (item['cantidadCtrl'] as TextEditingController).dispose();
            (item['precioCtrl'] as TextEditingController).dispose();
            return true;
          }
          return false;
        });
      }
    });
  }

  double get _montoPagadoFinal =>
      _pagoCompleto ? _total : (double.tryParse(_montoPagadoCtrl.text.trim()) ?? 0);

  Widget _buildSeccionPago() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ColoresCarolina.celesteSuave,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.payments_outlined, size: 18, color: ColoresCarolina.celesteOscuro),
          SizedBox(width: 8),
          Text('Pago', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14,
              color: ColoresCarolina.celesteOscuro)),
        ]),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _pagoCompleto,
          activeTrackColor: ColoresCarolina.celeste,
          title: const Text('El cliente paga todo ahora', style: TextStyle(fontSize: 13)),
          subtitle: Text(
              _pagoCompleto
                  ? 'Paga Bs ${_total.toStringAsFixed(2)}'
                  : 'Paga una parte ahora; el resto queda a cuenta',
              style: const TextStyle(fontSize: 11.5)),
          onChanged: (v) => setState(() => _pagoCompleto = v),
        ),
        if (!_pagoCompleto) ...[
          const SizedBox(height: 6),
          TextFormField(
            controller: _montoPagadoCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: _deco('Monto que paga ahora (Bs)', Icons.attach_money_rounded),
            validator: (v) {
              if (_pagoCompleto) return null;
              final n = double.tryParse((v ?? '').trim());
              if (n == null || n < 0) return 'Ingresa un monto válido';
              if (n > _total + 0.01) {
                return 'No puede pagar más del total (Bs ${_total.toStringAsFixed(2)})';
              }
              return null;
            },
          ),
        ],
        if (_montoPagadoFinal > 0) ...[
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _metodoPago,
            decoration: _deco('Método de pago', Icons.account_balance_wallet_outlined),
            items: kMetodosPago.entries
                .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
            onChanged: (v) => setState(() => _metodoPago = v ?? 'efectivo'),
          ),
        ] else
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text('Toda la venta queda a cuenta del cliente (fiado).',
                style: TextStyle(fontSize: 11.5, color: ColoresCarolina.grisMedio,
                    fontStyle: FontStyle.italic)),
          ),
      ]),
    );
  }

  Widget _buildAvisoSaldo() {
    final total = _saldosPendientes.fold<double>(
        0.0, (acc, v) => acc + ((v['saldo_pendiente'] as num?)?.toDouble() ?? 0));
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ColoresCarolina.rojo.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ColoresCarolina.rojo.withValues(alpha: 0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.account_balance_wallet_outlined,
              color: ColoresCarolina.rojo, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(
              'Este cliente debe Bs ${total.toStringAsFixed(2)} de compras anteriores',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13,
                  color: ColoresCarolina.rojo))),
        ]),
        const SizedBox(height: 6),
        ..._saldosPendientes.map((v) {
          final fecha = (v['fecha'] ?? '').toString();
          final fechaStr = fecha.length >= 10 ? fecha.substring(0, 10) : fecha;
          final saldo = (v['saldo_pendiente'] as num?)?.toDouble() ?? 0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
                '• Nota ${v['numero_recibo'] ?? '-'} ($fechaStr): Bs ${saldo.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF7F1D1D))),
          );
        }),
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Text('Para cobrar estos saldos, ve a Cobranzas.',
              style: TextStyle(fontSize: 11, color: ColoresCarolina.rojo,
                  fontStyle: FontStyle.italic)),
        ),
      ]),
    );
  }

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
        const SizedBox(height: 8),
        ..._devolucionesPendientes.map((d) {
          final detalles = (d['detalles'] as List?) ?? [];
          final resumen = detalles.map((det) {
            final cant = (det['cantidad'] as num?)?.toDouble() ?? 0;
            final cantStr = cant % 1 == 0 ? cant.toStringAsFixed(0) : cant.toStringAsFixed(2);
            final motivo = kMotivosDevolucion[det['motivo']] ?? det['motivo'] ?? '';
            return '$cantStr ${det['producto']} ($motivo)';
          }).join(', ');
          final incluida = _devolucionesAResolver.contains(d['id']);
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Checkbox(
                value: incluida,
                activeColor: ColoresCarolina.celeste,
                onChanged: (v) => _toggleReemplazo(d, v == true),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Text(resumen,
                      style: const TextStyle(fontSize: 12.5, color: Color(0xFF7C4A03))),
                ),
              ),
            ]),
          );
        }),
        const Padding(
          padding: EdgeInsets.only(left: 4),
          child: Text(
              'Marca las que le estás entregando el cambio en esta venta — '
              'quedará anotado en la nota y en el recibo.',
              style: TextStyle(fontSize: 11, color: Colors.orange, fontStyle: FontStyle.italic)),
        ),
      ]),
    );
  }
}

// ─── Ítem de venta (con toggle de precio especial) ─────────────────────────────
class _ItemVenta extends StatelessWidget {
  final int index;
  final Map<String, dynamic> item;
  final List<dynamic> productos;
  final bool soloLectura; // true cuando viene de un pedido: producto/cant. fijos
  final void Function(int productoId, String nombre) onProductoSeleccionado;
  final void Function(bool valor) onPrecioEspecialCambiado;
  final VoidCallback onEliminar, onChanged;

  const _ItemVenta({
    required this.index,
    required this.item,
    required this.productos,
    required this.soloLectura,
    required this.onProductoSeleccionado,
    required this.onPrecioEspecialCambiado,
    required this.onEliminar,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final precioEspecial = item['precio_especial'] == true;
    final stock = item['stock_disponible'] as double?;
    final esReemplazo = item['es_reemplazo'] == true;
    final efectivoSoloLectura = soloLectura || esReemplazo;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: esReemplazo ? Colors.orange.withValues(alpha: 0.06) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: esReemplazo
              ? Colors.orange.withValues(alpha: 0.35)
              : const Color(0xFFE2E8F0))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
                color: ColoresCarolina.celeste.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6)),
            child: Center(
                child: Text('${index + 1}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: ColoresCarolina.celeste,
                        fontSize: 11))),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: efectivoSoloLectura
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      Flexible(
                        child: Text(item['producto_nombre'] as String? ?? '-',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13),
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (esReemplazo) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20)),
                          child: const Text('SIN COSTO',
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold,
                                  color: Colors.orange)),
                        ),
                      ],
                    ]))
                : DropdownButtonFormField<int>(
                    initialValue: item['producto_id'] as int?,
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
                    items: productos
                        .map<DropdownMenuItem<int>>((p) => DropdownMenuItem(
                            value: p['id'] as int,
                            child: Text(p['nombre'] as String,
                                overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      final prod =
                          productos.firstWhere((p) => p['id'] == v);
                      onProductoSeleccionado(v, prod['nombre'] as String);
                    },
                    validator: (v) => v == null ? 'Selecciona un producto' : null,
                  ),
          ),
          if (!efectivoSoloLectura) ...[
            const SizedBox(width: 6),
            IconButton(
              onPressed: onEliminar,
              icon: const Icon(Icons.delete_rounded, size: 18),
              color: ColoresCarolina.rojo,
              tooltip: 'Eliminar producto',
              padding: const EdgeInsets.all(6),
              style: IconButton.styleFrom(
                  backgroundColor: ColoresCarolina.rojo.withValues(alpha: 0.1)),
            ),
          ],
        ]),
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: item['cantidadCtrl'] as TextEditingController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
              onChanged: (_) => onChanged(),
              decoration: InputDecoration(
                labelText: 'Cantidad',
                suffixText: 'u.',
                helperText: stock != null ? 'Stock: $stock' : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: ColoresCarolina.celeste, width: 2)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: item['precioCtrl'] as TextEditingController,
              enabled: !esReemplazo && (precioEspecial || item['producto_id'] == null),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
              onChanged: (_) => onChanged(),
              decoration: InputDecoration(
                labelText: 'P. Unitario (Bs)',
                filled: !precioEspecial,
                fillColor: const Color(0xFFF1F5F9),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: ColoresCarolina.celeste, width: 2)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              ),
            ),
          ),
        ]),
        if (esReemplazo)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
                'Producto de reemplazo por devolución — no se cobra.',
                style: TextStyle(fontSize: 11.5, color: Colors.orange,
                    fontStyle: FontStyle.italic)),
          )
        else ...[
          const SizedBox(height: 4),
          InkWell(
            onTap: () => onPrecioEspecialCambiado(!precioEspecial),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Switch(
                  value: precioEspecial,
                  onChanged: onPrecioEspecialCambiado,
                  activeTrackColor: ColoresCarolina.celeste,
                ),
                Expanded(
                  child: Text(
                    precioEspecial
                        ? 'Precio especial activado (venta por mayor u otra condición)'
                        : 'Usar precio de catálogo',
                    style: TextStyle(
                        fontSize: 12,
                        color: precioEspecial
                            ? Colors.orange.shade800
                            : ColoresCarolina.grisMedio,
                        fontWeight:
                            precioEspecial ? FontWeight.w600 : FontWeight.normal),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ]),
    );
  }
}

// ─── Diálogo: detalle de una venta ─────────────────────────────────────────────
class _DetalleVentaDialog extends StatelessWidget {
  final Map<String, dynamic> venta;
  final VoidCallback onImprimir;

  const _DetalleVentaDialog({required this.venta, required this.onImprimir});

  @override
  Widget build(BuildContext context) {
    final detalles = venta['detalles'] as List? ?? [];
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(children: [
              const Icon(Icons.receipt_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Expanded(
                  child: Text('Recibo ${venta['numero_recibo'] ?? ''}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold))),
              if (venta['estado'] == 'anulada')
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(8)),
                  child: const Text('ANULADA',
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                ),
              IconButton(
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Cerrar',
                  icon: const Icon(Icons.close, color: Colors.white)),
            ]),
          ),
          Flexible(
              child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cliente: ${venta['cliente'] ?? '-'}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('Fecha: ${venta['fecha']?.toString().substring(0, 16) ?? '-'}',
                    style: const TextStyle(
                        fontSize: 12, color: ColoresCarolina.grisMedio)),
                if (venta['nota'] != null &&
                    venta['nota'].toString().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('Nota: ${venta['nota']}',
                      style: const TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: ColoresCarolina.grisMedio)),
                ],
                if (venta['estado'] != 'anulada') ...[
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                    chipEstadoPago(venta),
                    Text(
                        'Pagado: Bs ${((venta['monto_pagado'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 12, color: ColoresCarolina.grisMedio)),
                  ]),
                  if (((venta['pagos'] as List?) ?? []).isNotEmpty) ...[
                    const SizedBox(height: 6),
                    ...((venta['pagos'] as List).map((p) {
                      final metodo = kMetodosPago[p['metodo_pago']] ?? p['metodo_pago'] ?? '-';
                      final f = (p['fecha'] ?? '').toString();
                      final fStr = f.length >= 10 ? f.substring(0, 10) : f;
                      return Text(
                          '• Bs ${(p['monto'] as num).toStringAsFixed(2)} · $metodo · $fStr',
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569)));
                    })),
                  ],
                  if ((venta['saldo_pendiente'] as num? ?? 0) > 0) ...[
                    const SizedBox(height: 4),
                    const Text('Para registrar un pago de este saldo, ve a Cobranzas.',
                        style: TextStyle(fontSize: 11, color: ColoresCarolina.grisMedio,
                            fontStyle: FontStyle.italic)),
                  ],
                ],
                const SizedBox(height: 14),
                ...detalles.map((d) {
                  final especial = d['precio_editado'] == true;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      Expanded(
                          child: Text(
                              '${d['producto']}${especial ? ' *' : ''}',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: especial
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: especial
                                      ? Colors.orange.shade800
                                      : Colors.black87))),
                      Text('${d['cantidad']} x Bs ${d['precio_unitario']}',
                          style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 8),
                      Text('Bs ${d['subtotal']}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ]),
                  );
                }),
                const Divider(height: 20),
                if ((venta['descuento'] as num?) != null &&
                    (venta['descuento'] as num) > 0)
                  Text('Descuento: Bs ${venta['descuento']}',
                      style: const TextStyle(fontSize: 13)),
                Text('TOTAL: Bs ${venta['total']}',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: ColoresCarolina.celesteOscuro)),
              ],
            ),
          )),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Row(children: [
              Expanded(
                  child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
                child: const Text('Cerrar'),
              )),
              const SizedBox(width: 12),
              Expanded(
                  child: ElevatedButton.icon(
                onPressed: onImprimir,
                icon: const Icon(Icons.print_rounded, size: 18),
                label: const Text('Reimprimir'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: ColoresCarolina.celeste,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
              )),
            ]),
          ),
        ]),
      ),
    );
  }
}
