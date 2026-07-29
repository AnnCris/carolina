// carolina/frontend/lib/pantallas/compras/compras_pantalla.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../constantes/colores.dart';
import '../../constantes/api.dart';
import '../../servicios/auth_servicio.dart';
import '../../widgets/notificacion.dart';

// ─── Servicio ─────────────────────────────────────────────────────────────────
class ComprasServicio {
  final _auth = AuthServicio();
  Future<Map<String, String>> get _h => _auth.obtenerHeaders();

  Future<List<dynamic>> listar() async {
    final res = await http.get(
        Uri.parse(ApiConfig.compras), headers: await _h);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Error al cargar compras (${res.statusCode})');
  }

  Future<List<dynamic>> listarProveedores() async {
    final res = await http.get(
        Uri.parse(ApiConfig.proveedores), headers: await _h);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Error al cargar proveedores');
  }

  Future<List<dynamic>> listarProductos() async {
    final res = await http.get(
        Uri.parse(ApiConfig.productos), headers: await _h);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Error al cargar productos');
  }

  /// Carga el precio de compra registrado para un producto
  Future<double?> obtenerPrecioCompra(int productoId) async {
    try {
      final res = await http.get(
          Uri.parse(
              '${ApiConfig.baseUrl}/precios/producto/$productoId/compra'),
          headers: await _h);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final precio = data['precio'];
        if (precio != null) return (precio as num).toDouble();
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>> crear(
      Map<String, dynamic> datos) async {
    final res = await http.post(Uri.parse(ApiConfig.compras),
        headers: await _h, body: jsonEncode(datos));
    final data = jsonDecode(res.body);
    if (res.statusCode == 201) return data;
    if (data['errores'] != null) {
      throw Exception(
          (data['errores'] as Map).values.first.toString());
    }
    throw Exception(data['error'] ?? 'Error al registrar compra');
  }

  Future<Map<String, dynamic>> actualizar(
      int id, Map<String, dynamic> datos) async {
    final res = await http.put(
        Uri.parse('${ApiConfig.compras}/$id'),
        headers: await _h,
        body: jsonEncode(datos));
    final data = jsonDecode(res.body);
    if (res.statusCode == 200) return data;
    if (data['errores'] != null) {
      throw Exception(
          (data['errores'] as Map).values.first.toString());
    }
    throw Exception(data['error'] ?? 'Error al actualizar compra');
  }

  Future<void> eliminar(int id) async {
    final res = await http.delete(
        Uri.parse('${ApiConfig.compras}/$id'), headers: await _h);
    if (res.statusCode != 200) {
      final data = jsonDecode(res.body);
      throw Exception(data['error'] ?? 'Error al eliminar');
    }
  }
}

// ─── Pantalla ─────────────────────────────────────────────────────────────────
class ComprasPantalla extends StatefulWidget {
  const ComprasPantalla({super.key});
  @override
  State<ComprasPantalla> createState() => _ComprasPantallaState();
}

class _ComprasPantallaState extends State<ComprasPantalla> {
  final _servicio   = ComprasServicio();
  List<dynamic> _compras   = [];
  bool   _cargando         = true;
  String _busqueda         = '';
  String _filtroEstado     = 'todas';

  @override
  void initState() { super.initState(); _cargar(); }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final c = await _servicio.listar();
      setState(() => _compras = c);
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
    return _compras.where((c) {
      if (_filtroEstado != 'todas' && c['estado'] != _filtroEstado) {
        return false;
      }
      if (_busqueda.isEmpty) return true;
      final q = _busqueda.toLowerCase();
      return (c['proveedor'] ?? '').toLowerCase().contains(q) ||
             (c['estado']    ?? '').toLowerCase().contains(q) ||
             (c['id'].toString()).contains(q);
    }).toList();
  }

  Color _colorEstado(String? estado) {
    switch (estado) {
      case 'recibida':  return Colors.green;
      case 'pendiente': return Colors.orange;
      case 'cancelada': return ColoresCarolina.rojo;
      default:          return ColoresCarolina.grisMedio;
    }
  }

  IconData _iconoEstado(String? estado) {
    switch (estado) {
      case 'recibida':  return Icons.check_circle_rounded;
      case 'pendiente': return Icons.hourglass_empty_rounded;
      case 'cancelada': return Icons.cancel_rounded;
      default:          return Icons.help_outline;
    }
  }

  Future<bool> _confirmar(String titulo, String mensaje) async {
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
        content: Text(mensaje),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
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

  Future<void> _eliminar(Map<String, dynamic> c) async {
    final ok = await _confirmar('Eliminar compra',
        '⚠️ Se eliminará la compra #${c['id']} y se REVERTIRÁ '
        'el stock de los productos.\n\nEsta acción NO se puede deshacer.');
    if (ok && mounted) {
      try {
        await _servicio.eliminar(c['id']);
        if (mounted) {
          Notificacion.exito(context,
              'Compra eliminada y stock revertido');
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

  void _verDetalle(Map<String, dynamic> c) => showDialog(
      context: context,
      builder: (_) => _DetalleCompra(compra: c));

  void _abrirFormulario({Map<String, dynamic>? compra}) {
    showDialog(
      context: context, barrierDismissible: false,
      builder: (_) => _FormularioCompra(
        compra: compra, servicio: _servicio,
        onGuardado: () {
          Navigator.pop(context);
          Notificacion.exito(context, compra == null
              ? 'Compra registrada correctamente'
              : 'Compra actualizada correctamente');
          _cargar();
        },
      ),
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

  Widget _buildHeader() => Container(
    padding: const EdgeInsets.fromLTRB(28, 22, 28, 18),
    decoration: const BoxDecoration(color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0)))),
    child: Row(children: [
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Registro de Compras',
              style: TextStyle(fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: ColoresCarolina.celesteOscuro)),
          const SizedBox(height: 6),
          _chip('${_compras.length} compras registradas',
              ColoresCarolina.celeste),
        ],
      )),
      ElevatedButton.icon(
        onPressed: () => _abrirFormulario(),
        icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
        label: const Text('Nueva Compra'),
        style: ElevatedButton.styleFrom(
          backgroundColor: ColoresCarolina.celeste,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
              horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      ),
    ]),
  );

  Widget _buildBarra() => Container(
    padding: const EdgeInsets.symmetric(
        horizontal: 28, vertical: 12),
    color: Colors.white,
    child: Row(children: [
      Expanded(child: TextField(
        onChanged: (v) => setState(() => _busqueda = v),
        decoration: InputDecoration(
          hintText: 'Buscar por proveedor, estado o número...',
          prefixIcon: const Icon(Icons.search_rounded,
              color: ColoresCarolina.celeste),
          suffixIcon: _busqueda.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
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
      const SizedBox(width: 12),
      Container(
        decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _btnFiltro('Todas',      'todas',
              Icons.list_rounded),
          _btnFiltro('Recibidas',  'recibida',
              Icons.check_circle_rounded),
          _btnFiltro('Pendientes', 'pendiente',
              Icons.hourglass_empty_rounded),
          _btnFiltro('Canceladas', 'cancelada',
              Icons.cancel_rounded),
        ]),
      ),
      const SizedBox(width: 8),
      IconButton(onPressed: _cargar,
          icon: const Icon(Icons.refresh_rounded),
          color: ColoresCarolina.celeste,
          tooltip: 'Actualizar'),
    ]),
  );

  Widget _btnFiltro(String label, String valor, IconData icono) {
    final sel = _filtroEstado == valor;
    return GestureDetector(
      onTap: () => setState(() => _filtroEstado = valor),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
            color: sel
                ? ColoresCarolina.celeste
                : Colors.transparent,
            borderRadius: BorderRadius.circular(9)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icono, size: 14,
              color: sel
                  ? Colors.white
                  : ColoresCarolina.grisMedio),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11,
              fontWeight:
                  sel ? FontWeight.bold : FontWeight.normal,
              color: sel
                  ? Colors.white
                  : ColoresCarolina.grisMedio)),
        ]),
      ),
    );
  }

  Widget _buildCuerpo(List<dynamic> filtrados) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator(
          color: ColoresCarolina.celeste));
    }
    if (filtrados.isEmpty) {
      return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart_outlined, size: 72,
              color: ColoresCarolina.grisMedio
                  .withValues(alpha: 0.35)),
          const SizedBox(height: 14),
          Text(_busqueda.isNotEmpty
              ? 'No hay resultados para "$_busqueda"'
              : 'No hay compras registradas',
              style: const TextStyle(
                  color: ColoresCarolina.grisMedio,
                  fontSize: 15)),
        ],
      ));
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
                _th('#',          1),
                _th('FECHA',      2),
                _th('PROVEEDOR',  3),
                _th('PRODUCTOS',  2),
                _th('TOTAL',      2),
                _th('ESTADO',     2),
                _th('ACCIONES',   3),
              ]),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            ...filtrados.asMap().entries.map((e) {
              final c = e.value;
              return Column(children: [
                _FilaCompra(
                  compra:      c,
                  impar:       e.key.isOdd,
                  colorEstado: _colorEstado(c['estado']),
                  iconoEstado: _iconoEstado(c['estado']),
                  onVer:       () => _verDetalle(c),
                  onEditar:    () => _abrirFormulario(compra: c),
                  onEliminar:  () => _eliminar(c),
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
    child: Text(t, style: TextStyle(fontSize: 11, color: c,
        fontWeight: FontWeight.w600)),
  );
}

// ─── Fila ─────────────────────────────────────────────────────────────────────
class _FilaCompra extends StatelessWidget {
  final Map<String, dynamic> compra;
  final bool impar;
  final Color colorEstado;
  final IconData iconoEstado;
  final VoidCallback onVer, onEditar, onEliminar;

  const _FilaCompra({
    required this.compra,
    required this.impar,
    required this.colorEstado,
    required this.iconoEstado,
    required this.onVer,
    required this.onEditar,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    final detalles = compra['detalles'] as List? ?? [];
    final fecha    = DateTime.tryParse(compra['fecha'] ?? '');
    final fechaStr = fecha != null
        ? '${fecha.day.toString().padLeft(2, '0')}/'
          '${fecha.month.toString().padLeft(2, '0')}/'
          '${fecha.year}'
        : '-';

    return Container(
      color: impar ? const Color(0xFFFAFBFF) : Colors.white,
      padding: const EdgeInsets.symmetric(
          horizontal: 20, vertical: 12),
      child: Row(children: [
        Expanded(flex: 1, child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
              color: ColoresCarolina.celeste
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8)),
          child: Text('#${compra['id']}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: ColoresCarolina.celeste)),
        )),
        Expanded(flex: 2, child: Text(fechaStr,
            style: const TextStyle(
                fontSize: 13, color: Color(0xFF475569)))),
        Expanded(flex: 3, child: Text(
            compra['proveedor'] ?? '-',
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 13),
            overflow: TextOverflow.ellipsis)),
        Expanded(flex: 2, child: Text(
            '${detalles.length} producto(s)',
            style: const TextStyle(
                fontSize: 13, color: Color(0xFF475569)))),
        Expanded(flex: 2, child: Text(
            'Bs ${(compra['total'] ?? 0).toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold,
                fontSize: 13,
                color: ColoresCarolina.celesteOscuro))),
        Expanded(flex: 2, child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
              color: colorEstado.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(iconoEstado, size: 12, color: colorEstado),
            const SizedBox(width: 4),
            Text((compra['estado'] ?? '-')
                    .toString().toUpperCase(),
                style: TextStyle(fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: colorEstado)),
          ]),
        )),
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
        child: InkWell(onTap: fn,
            borderRadius: BorderRadius.circular(8),
          child: Container(padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(i, size: 16, color: c))));
}

// ─── Detalle ──────────────────────────────────────────────────────────────────
class _DetalleCompra extends StatelessWidget {
  final Map<String, dynamic> compra;
  const _DetalleCompra({required this.compra});

  @override
  Widget build(BuildContext context) {
    final detalles = compra['detalles'] as List? ?? [];
    final fecha    = DateTime.tryParse(compra['fecha'] ?? '');
    final fechaStr = fecha != null
        ? '${fecha.day.toString().padLeft(2, '0')}/'
          '${fecha.month.toString().padLeft(2, '0')}/'
          '${fecha.year} '
          '${fecha.hour.toString().padLeft(2, '0')}:'
          '${fecha.minute.toString().padLeft(2, '0')}'
        : '-';

    return Dialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
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
              const Icon(Icons.shopping_cart_rounded,
                  color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Text('Compra #${compra['id']}',
                  style: const TextStyle(color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close,
                      color: Colors.white)),
            ]),
          ),
          Flexible(child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: ColoresCarolina.grisClaro,
                      borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    Expanded(child: _info('Proveedor',
                        compra['proveedor'] ?? '-',
                        Icons.local_shipping_rounded)),
                    Expanded(child: _info('Fecha', fechaStr,
                        Icons.calendar_today_rounded)),
                    Expanded(child: _info('Registrado por',
                        compra['usuario'] ?? '-',
                        Icons.person_outline)),
                    Expanded(child: _info('Estado',
                        (compra['estado'] ?? '-')
                            .toString().toUpperCase(),
                        Icons.info_outline)),
                  ]),
                ),
                const SizedBox(height: 16),
                const Text('Productos recibidos',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: ColoresCarolina.celesteOscuro)),
                const SizedBox(height: 10),
                ...detalles.map((d) => _tarjetaDetalle(d)),
                if (compra['nota'] != null &&
                    compra['nota'].toString().isNotEmpty) ...[
                  const SizedBox(height: 12),
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
                        Expanded(child: Text(compra['nota'],
                            style: const TextStyle(
                                fontSize: 13))),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: ColoresCarolina.celeste
                          .withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: ColoresCarolina.celeste
                              .withValues(alpha: 0.3))),
                  child: Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('TOTAL COMPRA',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color:
                                  ColoresCarolina.celesteOscuro)),
                      Text(
                          'Bs ${(compra['total'] ?? 0).toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                              color: ColoresCarolina.celeste)),
                    ],
                  ),
                ),
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

  Widget _tarjetaDetalle(Map<String, dynamic> d) {
    final esPorKg =
        (d['tipo_precio'] as String? ?? '') == 'por_kg';
    final String infoProducto;
    if (esPorKg) {
      infoProducto =
          'Peso total: ${d['peso_total_kg'] ?? '-'} kg'
          '${d['num_cajas'] != null ? ' • ${d['num_cajas']} caja(s)' : ''}';
    } else {
      infoProducto =
          '${d['num_cajas']} caja(s) × ${d['unidades_x_caja']} unid. '
          '= ${d['cantidad']} unidades';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: ColoresCarolina.celeste
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(
              esPorKg
                  ? Icons.scale_rounded
                  : Icons.inventory_2_rounded,
              color: ColoresCarolina.celeste,
              size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(d['producto'] ?? '-',
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14)),
            const SizedBox(height: 2),
            Text(infoProducto,
                style: const TextStyle(
                    fontSize: 12,
                    color: ColoresCarolina.grisMedio)),
            Text(
              esPorKg
                  ? 'Bs ${d['precio_unitario']}/kg'
                  : 'Bs ${d['precio_unitario']} c/u',
              style: const TextStyle(fontSize: 12,
                  color: ColoresCarolina.celeste,
                  fontWeight: FontWeight.w500),
            ),
          ],
        )),
        Text(
            'Bs ${(d['subtotal'] ?? 0).toStringAsFixed(2)}',
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: ColoresCarolina.celesteOscuro)),
      ]),
    );
  }

  Widget _info(String label, String valor, IconData icono) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        Row(children: [
          Icon(icono, size: 14,
              color: ColoresCarolina.grisMedio),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11,
              color: ColoresCarolina.grisMedio)),
        ]),
        const SizedBox(height: 2),
        Text(valor, style: const TextStyle(
            fontWeight: FontWeight.w600, fontSize: 13),
            overflow: TextOverflow.ellipsis),
      ]);
}

// ─── Formulario ───────────────────────────────────────────────────────────────
class _FormularioCompra extends StatefulWidget {
  final Map<String, dynamic>? compra;
  final ComprasServicio        servicio;
  final VoidCallback           onGuardado;

  const _FormularioCompra({
    this.compra,
    required this.servicio,
    required this.onGuardado,
  });

  @override
  State<_FormularioCompra> createState() =>
      _FormularioCompraState();
}

class _FormularioCompraState extends State<_FormularioCompra> {
  final _formKey  = GlobalKey<FormState>();
  final _notaCtrl = TextEditingController();

  List<dynamic> _proveedores   = [];
  List<dynamic> _productos     = [];
  int?          _proveedorId;
  DateTime      _fecha         = DateTime.now();
  String        _estado        = 'recibida';
  bool          _cargando      = false;
  bool          _cargandoDatos = true;

  final List<Map<String, dynamic>> _items = [];

  bool get _esEdicion => widget.compra != null;

  @override
  void initState() { super.initState(); _cargarDatos(); }

  @override
  void dispose() {
    _notaCtrl.dispose();
    for (final item in _items) { _disposeItem(item); }
    super.dispose();
  }

  void _disposeItem(Map<String, dynamic> item) {
    (item['num_cajas']       as TextEditingController).dispose();
    (item['unidades_x_caja'] as TextEditingController).dispose();
    (item['precio_unitario'] as TextEditingController).dispose();
    (item['peso_total_kg']   as TextEditingController).dispose();
    (item['precio_kg']       as TextEditingController).dispose();
  }

  Future<void> _cargarDatos() async {
    try {
      final p  = await widget.servicio.listarProveedores();
      final pr = await widget.servicio.listarProductos();
      setState(() {
        _proveedores   =
            p.where((x) => x['activo'] == true).toList();
        _productos     =
            pr.where((x) => x['activo'] == true).toList();
        _cargandoDatos = false;
      });

      if (_esEdicion) {
        final c = widget.compra!;
        _proveedorId   = c['proveedor_id'] as int?;
        _notaCtrl.text = c['nota'] ?? '';
        _estado        = c['estado'] ?? 'recibida';
        final f = DateTime.tryParse(c['fecha'] ?? '');
        if (f != null) _fecha = f;

        final detalles = c['detalles'] as List? ?? [];
        for (final d in detalles) {
          final tipoPrecio =
              d['tipo_precio'] as String? ?? 'por_unidad';
          final item = <String, dynamic>{
            'producto_id':     d['producto_id'],
            'tipo_precio':     tipoPrecio,
            'num_cajas':       TextEditingController(
                text: (d['num_cajas'] ?? 1).toString()),
            'unidades_x_caja': TextEditingController(
                text: (d['unidades_x_caja'] ?? 1).toString()),
            'precio_unitario': TextEditingController(
                text: tipoPrecio == 'por_unidad'
                    ? (d['precio_unitario'] ?? '').toString()
                    : ''),
            'peso_total_kg':   TextEditingController(
                text: tipoPrecio == 'por_kg'
                    ? (d['peso_total_kg'] ?? '').toString()
                    : ''),
            'precio_kg':       TextEditingController(
                text: tipoPrecio == 'por_kg'
                    ? (d['precio_unitario'] ?? '').toString()
                    : ''),
            'cargando_precio': false,
          };
          _items.add(item);
        }
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        Notificacion.error(context,
            e.toString().replaceAll('Exception: ', ''));
        setState(() => _cargandoDatos = false);
      }
    }
  }

  Future<void> _seleccionarFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('es'),
    );
    if (picked != null) setState(() => _fecha = picked);
  }

  void _agregarProducto() {
    setState(() {
      _items.add({
        'producto_id':     null,
        'tipo_precio':     'por_unidad',
        'num_cajas':       TextEditingController(text: '1'),
        'unidades_x_caja': TextEditingController(text: '1'),
        'precio_unitario': TextEditingController(),
        'peso_total_kg':   TextEditingController(),
        'precio_kg':       TextEditingController(),
        'cargando_precio': false,
      });
    });
  }

  void _eliminarProducto(int index) {
    _disposeItem(_items[index]);
    setState(() => _items.removeAt(index));
  }

  double _calcularSubtotal(Map<String, dynamic> item) {
    try {
      if (item['tipo_precio'] == 'por_kg') {
        final peso   = double.tryParse((item['peso_total_kg']
                as TextEditingController).text) ?? 0;
        final precio = double.tryParse(
                (item['precio_kg'] as TextEditingController)
                    .text) ?? 0;
        return peso * precio;
      } else {
        final cajas   = int.tryParse(
                (item['num_cajas'] as TextEditingController)
                    .text) ?? 0;
        final unidades = int.tryParse(
                (item['unidades_x_caja'] as TextEditingController)
                    .text) ?? 0;
        final precio   = double.tryParse(
                (item['precio_unitario'] as TextEditingController)
                    .text) ?? 0;
        return cajas * unidades * precio;
      }
    } catch (_) { return 0; }
  }

  double get _totalCompra =>
      _items.fold(0, (s, item) => s + _calcularSubtotal(item));

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_proveedorId == null) {
      Notificacion.error(context, 'Selecciona un proveedor');
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

    final detalles = _items.map((item) {
      final tipo = item['tipo_precio'] as String;
      if (tipo == 'por_kg') {
        return {
          'producto_id':     item['producto_id'],
          'tipo_precio':     'por_kg',
          'peso_total_kg':   double.tryParse(
                  (item['peso_total_kg'] as TextEditingController)
                      .text) ?? 0,
          'precio_unitario': double.tryParse(
                  (item['precio_kg'] as TextEditingController)
                      .text) ?? 0,
          'num_cajas':       int.tryParse(
                  (item['num_cajas'] as TextEditingController)
                      .text) ?? 1,
          'unidades_x_caja': int.tryParse(
                  (item['unidades_x_caja'] as TextEditingController)
                      .text) ?? 1,
          'cantidad':        1,
        };
      } else {
        final cajas   = int.tryParse(
                (item['num_cajas'] as TextEditingController)
                    .text) ?? 1;
        final unidades = int.tryParse(
                (item['unidades_x_caja'] as TextEditingController)
                    .text) ?? 1;
        return {
          'producto_id':     item['producto_id'],
          'tipo_precio':     'por_unidad',
          'cantidad':        cajas * unidades,
          'precio_unitario': double.tryParse(
                  (item['precio_unitario'] as TextEditingController)
                      .text) ?? 0,
          'num_cajas':       cajas,
          'unidades_x_caja': unidades,
        };
      }
    }).toList();

    final datos = {
      'proveedor_id': _proveedorId,
      'fecha':
          '${_fecha.year}-${_fecha.month.toString().padLeft(2, '0')}-${_fecha.day.toString().padLeft(2, '0')}',
      'nota':     _notaCtrl.text.trim(),
      'estado':   _estado,
      'detalles': detalles,
    };

    try {
      if (_esEdicion) {
        await widget.servicio
            .actualizar(widget.compra!['id'], datos);
      } else {
        await widget.servicio.crear(datos);
      }
      widget.onGuardado();
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
            maxWidth: 700,
            maxHeight:
                MediaQuery.of(context).size.height * 0.92),
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
              Icon(_esEdicion
                  ? Icons.edit_rounded
                  : Icons.add_shopping_cart_rounded,
                  color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Text(_esEdicion
                  ? 'Editar Compra #${widget.compra!['id']}'
                  : 'Nueva Compra',
                  style: const TextStyle(color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                  onPressed: () => Navigator.pop(context),
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
                        // Proveedor + Fecha
                        Row(children: [
                          Expanded(
                              child: DropdownButtonFormField<int>(
                            initialValue: _proveedorId,
                            decoration: _deco('Proveedor *',
                                Icons.local_shipping_rounded),
                            items: _proveedores
                                .map<DropdownMenuItem<int>>((p) =>
                                    DropdownMenuItem(
                                        value: p['id'] as int,
                                        child: Text(
                                            p['nombre_completo']
                                                as String,
                                            overflow:
                                                TextOverflow
                                                    .ellipsis)))
                                .toList(),
                            onChanged: (v) => setState(
                                () => _proveedorId = v),
                            validator: (v) => v == null
                                ? 'Selecciona un proveedor'
                                : null,
                          )),
                          const SizedBox(width: 12),
                          Expanded(child: GestureDetector(
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
                                    const Text('Fecha de compra',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: ColoresCarolina
                                                .grisMedio)),
                                    Text(
                                      '${_fecha.day.toString().padLeft(2, '0')}/'
                                      '${_fecha.month.toString().padLeft(2, '0')}/'
                                      '${_fecha.year}',
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
                          )),
                        ]),
                        const SizedBox(height: 14),

                        // Estado
                        DropdownButtonFormField<String>(
                          initialValue: _estado,
                          decoration: _deco(
                              'Estado de la compra',
                              Icons.info_outline_rounded),
                          items: const [
                            DropdownMenuItem(
                                value: 'recibida',
                                child: Text(
                                    '✅ Recibida — stock ingresa al inventario')),
                            DropdownMenuItem(
                                value: 'pendiente',
                                child: Text(
                                    '⏳ Pendiente — en camino, sin stock aún')),
                            DropdownMenuItem(
                                value: 'cancelada',
                                child: Text(
                                    '❌ Cancelada — no afecta inventario')),
                          ],
                          onChanged: (v) => setState(
                              () => _estado = v ?? 'recibida'),
                        ),
                        const SizedBox(height: 14),

                        // Productos
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Productos recibidos',
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
                            padding: const EdgeInsets.all(20),
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
                            _ItemCompra(
                              index:      e.key,
                              item:       e.value,
                              productos:  _productos,
                              servicio:   widget.servicio,
                              onEliminar: () =>
                                  _eliminarProducto(e.key),
                              onChanged:  () => setState(() {}),
                            )),

                        if (_items.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                                color: ColoresCarolina.celeste
                                    .withValues(alpha: 0.08),
                                borderRadius:
                                    BorderRadius.circular(10),
                                border: Border.all(
                                    color: ColoresCarolina.celeste
                                        .withValues(alpha: 0.3))),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('TOTAL ESTIMADO',
                                    style: TextStyle(
                                        fontWeight:
                                            FontWeight.bold,
                                        color: ColoresCarolina
                                            .celesteOscuro)),
                                Text(
                                    'Bs ${_totalCompra.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                        fontWeight:
                                            FontWeight.bold,
                                        fontSize: 20,
                                        color: ColoresCarolina
                                            .celeste)),
                              ],
                            ),
                          ),
                        ],

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
                onPressed: _cargando || _cargandoDatos
                    ? null : _guardar,
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
                            color: Colors.white,
                            strokeWidth: 2))
                    : Text(
                        _esEdicion
                            ? 'Guardar Cambios'
                            : 'Registrar Compra',
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

  InputDecoration _deco(String l, IconData i) =>
      InputDecoration(
    labelText: l,
    prefixIcon: Icon(i, color: ColoresCarolina.celeste),
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10)),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(
            color: ColoresCarolina.celeste, width: 2)),
  );
}

// ─── Item de compra ───────────────────────────────────────────────────────────
class _ItemCompra extends StatefulWidget {
  final int index;
  final Map<String, dynamic> item;
  final List<dynamic>        productos;
  final ComprasServicio      servicio;
  final VoidCallback         onEliminar, onChanged;

  const _ItemCompra({
    required this.index,
    required this.item,
    required this.productos,
    required this.servicio,
    required this.onEliminar,
    required this.onChanged,
  });

  @override
  State<_ItemCompra> createState() => _ItemCompraState();
}

class _ItemCompraState extends State<_ItemCompra> {

  /// Cuando se selecciona un producto, carga su precio de compra
  /// desde el módulo de precios y lo coloca en el campo
  Future<void> _cargarPrecioCompra(int productoId) async {
    setState(() => widget.item['cargando_precio'] = true);
    try {
      final precio =
          await widget.servicio.obtenerPrecioCompra(productoId);
      if (precio != null && mounted) {
        final tipo = widget.item['tipo_precio'] as String;
        if (tipo == 'por_kg') {
          (widget.item['precio_kg'] as TextEditingController)
              .text = precio.toStringAsFixed(2);
        } else {
          (widget.item['precio_unitario']
                  as TextEditingController)
              .text = precio.toStringAsFixed(2);
        }
        widget.onChanged();
      }
    } finally {
      if (mounted) {
        setState(() => widget.item['cargando_precio'] = false);
      }
    }
  }

  double get _subtotal {
    try {
      if (widget.item['tipo_precio'] == 'por_kg') {
        final peso   = double.tryParse((widget.item['peso_total_kg']
                as TextEditingController).text) ?? 0;
        final precio = double.tryParse(
                (widget.item['precio_kg'] as TextEditingController)
                    .text) ?? 0;
        return peso * precio;
      } else {
        final cajas   = int.tryParse(
                (widget.item['num_cajas'] as TextEditingController)
                    .text) ?? 0;
        final unid    = int.tryParse(
                (widget.item['unidades_x_caja']
                        as TextEditingController)
                    .text) ?? 0;
        final precio  = double.tryParse(
                (widget.item['precio_unitario']
                        as TextEditingController)
                    .text) ?? 0;
        return cajas * unid * precio;
      }
    } catch (_) { return 0; }
  }

  @override
  Widget build(BuildContext context) {
    final esPorKg  = widget.item['tipo_precio'] == 'por_kg';
    final cargandoPrecio =
        widget.item['cargando_precio'] as bool? ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera: número + toggle tipo + eliminar
          Row(children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                  color: ColoresCarolina.celeste
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: Center(child: Text(
                  '${widget.index + 1}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: ColoresCarolina.celeste,
                      fontSize: 13))),
            ),
            const SizedBox(width: 10),
            const Text('Producto', style: TextStyle(
                fontWeight: FontWeight.w600, fontSize: 14)),
            const Spacer(),
            // Toggle por_unidad / por_kg
            Container(
              decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8)),
              child: Row(mainAxisSize: MainAxisSize.min,
                  children: [
                _toggleTipo('Por unidad', 'por_unidad'),
                _toggleTipo('Por kg',     'por_kg'),
              ]),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: widget.onEliminar,
              icon: const Icon(Icons.delete_rounded, size: 18),
              color: ColoresCarolina.rojo,
              tooltip: 'Eliminar',
              style: IconButton.styleFrom(
                  backgroundColor:
                      ColoresCarolina.rojo.withValues(alpha: 0.1)),
            ),
          ]),
          const SizedBox(height: 12),

          // Selector de producto — al seleccionar carga el precio
          Stack(children: [
            DropdownButtonFormField<int>(
              initialValue: widget.item['producto_id'],
              decoration: InputDecoration(
                labelText: 'Selecciona el producto *',
                prefixIcon: const Icon(
                    Icons.inventory_2_outlined,
                    color: ColoresCarolina.celeste),
                // Muestra indicador si está cargando el precio
                suffixIcon: cargandoPrecio
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: ColoresCarolina.celeste)))
                    : widget.item['producto_id'] != null
                        ? const Icon(Icons.check_circle_rounded,
                            color: Colors.green, size: 18)
                        : null,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                        color: ColoresCarolina.celeste,
                        width: 2)),
              ),
              items: widget.productos
                  .map<DropdownMenuItem<int>>((p) =>
                      DropdownMenuItem(
                          value: p['id'] as int,
                          child: Text(p['nombre'] as String,
                              overflow:
                                  TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (v) {
                setState(() => widget.item['producto_id'] = v);
                // ← Carga automáticamente el precio de compra
                if (v != null) _cargarPrecioCompra(v);
                widget.onChanged();
              },
              validator: (v) =>
                  v == null ? 'Selecciona un producto' : null,
            ),
          ]),
          const SizedBox(height: 12),

          // Campos: cajas y unidades por caja
          Row(children: [
            Expanded(child: _campo(
              ctrl: widget.item['num_cajas']
                  as TextEditingController,
              label: 'Nº de cajas',
              icono: Icons.inventory_2_rounded,
              soloEnteros: true,
              hint: 'Ej: 5',
              validator: (v) =>
                  (int.tryParse(v ?? '') ?? 0) <= 0
                      ? 'Mínimo 1' : null,
            )),
            const SizedBox(width: 10),
            Expanded(child: _campo(
              ctrl: widget.item['unidades_x_caja']
                  as TextEditingController,
              label: 'Unidades por caja',
              icono: Icons.format_list_numbered_rounded,
              soloEnteros: true,
              hint: 'Ej: 90',
              validator: (v) =>
                  (int.tryParse(v ?? '') ?? 0) <= 0
                      ? 'Mínimo 1' : null,
            )),
          ]),
          const SizedBox(height: 10),

          // Campos según tipo (por_unidad o por_kg)
          if (!esPorKg)
            _campo(
              ctrl: widget.item['precio_unitario']
                  as TextEditingController,
              label: 'Precio por unidad (Bs)',
              icono: Icons.payments_rounded,
              decimal: true,
              hint: 'Ej: 8.50',
              helperText: cargandoPrecio
                  ? 'Cargando precio del módulo de precios...'
                  : 'Cargado automáticamente desde módulo de precios. Editable.',
              validator: (v) =>
                  (double.tryParse(v ?? '') ?? 0) <= 0
                      ? 'Requerido' : null,
            )
          else
            Row(children: [
              Expanded(child: _campo(
                ctrl: widget.item['peso_total_kg']
                    as TextEditingController,
                label: 'Peso total (kg)',
                icono: Icons.scale_rounded,
                decimal: true,
                hint: 'Ej: 33.58',
                validator: (v) =>
                    (double.tryParse(v ?? '') ?? 0) <= 0
                        ? 'Requerido' : null,
              )),
              const SizedBox(width: 10),
              Expanded(child: _campo(
                ctrl: widget.item['precio_kg']
                    as TextEditingController,
                label: 'Precio por kg (Bs)',
                icono: Icons.payments_rounded,
                decimal: true,
                hint: 'Ej: 54.00',
                helperText: cargandoPrecio
                    ? 'Cargando precio...'
                    : 'Desde módulo de precios. Editable.',
                validator: (v) =>
                    (double.tryParse(v ?? '') ?? 0) <= 0
                        ? 'Requerido' : null,
              )),
            ]),

          // Info calculada
          const SizedBox(height: 8),
          if (!esPorKg)
            _infoCalculo(
              '${(int.tryParse((widget.item['num_cajas'] as TextEditingController).text) ?? 0)} cajas × '
              '${(int.tryParse((widget.item['unidades_x_caja'] as TextEditingController).text) ?? 0)} unid. = '
              '${(int.tryParse((widget.item['num_cajas'] as TextEditingController).text) ?? 0) * (int.tryParse((widget.item['unidades_x_caja'] as TextEditingController).text) ?? 0)} unidades totales',
            )
          else
            _infoCalculo(
              '${(widget.item['num_cajas'] as TextEditingController).text} cajas • '
              '${(widget.item['peso_total_kg'] as TextEditingController).text} kg total recibido',
            ),

          // Subtotal
          const SizedBox(height: 8),
          Align(alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                  color: ColoresCarolina.celeste
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20)),
              child: Text(
                  'Subtotal: Bs ${_subtotal.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: ColoresCarolina.celeste)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCalculo(String texto) => Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: Colors.green.withValues(alpha: 0.2))),
    child: Row(children: [
      const Icon(Icons.info_outline_rounded,
          size: 14, color: Colors.green),
      const SizedBox(width: 6),
      Expanded(child: Text(texto,
          style: const TextStyle(fontSize: 11,
              color: Colors.green,
              fontWeight: FontWeight.w500))),
    ]),
  );

  Widget _toggleTipo(String label, String valor) {
    final sel = widget.item['tipo_precio'] == valor;
    return GestureDetector(
      onTap: () {
        setState(() => widget.item['tipo_precio'] = valor);
        // Al cambiar tipo, recargar precio si hay producto
        final pid = widget.item['producto_id'] as int?;
        if (pid != null) _cargarPrecioCompra(pid);
        widget.onChanged();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
            horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
            color: sel
                ? ColoresCarolina.celeste
                : Colors.transparent,
            borderRadius: BorderRadius.circular(7)),
        child: Text(label, style: TextStyle(fontSize: 11,
            fontWeight:
                sel ? FontWeight.bold : FontWeight.normal,
            color: sel
                ? Colors.white
                : ColoresCarolina.grisMedio)),
      ),
    );
  }

  Widget _campo({
    required TextEditingController ctrl,
    required String label,
    required IconData icono,
    String hint        = '',
    String? helperText,
    bool soloEnteros   = false,
    bool decimal       = false,
    String? Function(String?)? validator,
  }) =>
      TextFormField(
        controller: ctrl,
        keyboardType: soloEnteros
            ? TextInputType.number
            : decimal
                ? const TextInputType.numberWithOptions(
                    decimal: true)
                : TextInputType.text,
        inputFormatters: soloEnteros
            ? [FilteringTextInputFormatter.digitsOnly]
            : decimal
                ? [FilteringTextInputFormatter.allow(
                    RegExp(r'^\d*\.?\d*'))]
                : null,
        onChanged: (_) {
          setState(() {});
          widget.onChanged();
        },
        decoration: InputDecoration(
          labelText: label,
          hintText:  hint,
          helperText: helperText,
          helperMaxLines: 2,
          prefixIcon: Icon(icono,
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
        validator: validator,
      );
}