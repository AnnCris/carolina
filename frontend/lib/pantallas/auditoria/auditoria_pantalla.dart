// carolina/frontend/lib/pantallas/auditoria/auditoria_pantalla.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../constantes/api.dart';
import '../../constantes/breakpoints.dart';
import '../../constantes/colores.dart';
import '../../servicios/auth_servicio.dart';
import '../../widgets/notificacion.dart';

// ─── Servicio ───────────────────────────────────────────────────────────────
class AuditoriaServicio {
  final _auth = AuthServicio();
  Future<Map<String, String>> get _h => _auth.obtenerHeaders();

  Future<Map<String, dynamic>> listar(Map<String, String> filtros) async {
    final uri = Uri.parse(ApiConfig.auditoria)
        .replace(queryParameters: filtros.isEmpty ? null : filtros);
    final res = await http.get(uri, headers: await _h);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Error al cargar la auditoría');
  }

  Future<List<dynamic>> modulos() async {
    final res = await http.get(Uri.parse(ApiConfig.auditoriaModulos), headers: await _h);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Error al cargar los módulos');
  }

  Future<List<dynamic>> resumen() async {
    final res = await http.get(Uri.parse(ApiConfig.auditoriaResumen), headers: await _h);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Error al cargar el resumen de actividad');
  }
}

const Map<String, String> kAccionesLegibles = {
  'crear': 'Creó',
  'actualizar': 'Actualizó',
  'eliminar': 'Eliminó',
  'login': 'Inició sesión',
  'login_fallido': 'Login fallido',
  'registro': 'Se registró',
  'logout': 'Cerró sesión',
  'ajuste_inventario': 'Ajuste de inventario',
  'resolver': 'Resolvió',
  'subir_foto': 'Subió foto',
  'subir_factura': 'Subió factura',
  'guardar_precio': 'Guardó precio',
};

const Map<String, IconData> kIconosAccion = {
  'crear': Icons.add_circle_outline_rounded,
  'actualizar': Icons.edit_outlined,
  'eliminar': Icons.delete_outline_rounded,
  'login': Icons.login_rounded,
  'login_fallido': Icons.block_rounded,
  'registro': Icons.person_add_alt_1_rounded,
  'logout': Icons.logout_rounded,
  'ajuste_inventario': Icons.tune_rounded,
  'resolver': Icons.check_circle_outline_rounded,
  'subir_foto': Icons.image_outlined,
  'subir_factura': Icons.receipt_outlined,
  'guardar_precio': Icons.price_change_outlined,
};

const Map<String, String> kModulosLegibles = {
  'auth': 'Sesión',
  'usuarios': 'Usuarios',
  'productos': 'Productos',
  'categorias': 'Categorías',
  'marcas': 'Marcas',
  'proveedores': 'Proveedores',
  'clientes': 'Clientes',
  'compras': 'Compras',
  'ventas': 'Ventas',
  'inventario': 'Inventario',
  'pedidos': 'Pedidos',
  'devoluciones': 'Devoluciones',
  'precios': 'Precios',
  'cobranzas': 'Cobranzas',
};

// ─── Pantalla ───────────────────────────────────────────────────────────────
class AuditoriaPantalla extends StatefulWidget {
  const AuditoriaPantalla({super.key});
  @override
  State<AuditoriaPantalla> createState() => _AuditoriaPantallaState();
}

class _AuditoriaPantallaState extends State<AuditoriaPantalla> {
  final _servicio = AuditoriaServicio();
  final _busquedaCtrl = TextEditingController();

  List<dynamic> _registros = [];
  List<dynamic> _modulos = [];
  List<dynamic> _resumenUsuarios = [];
  int _total = 0;
  int _pagina = 1;
  static const _porPagina = 30;
  bool _cargando = true;
  bool _mostrarResumen = false;

  String? _moduloSeleccionado;
  String? _estadoSeleccionado; // null=todos, 'true'=exitosos, 'false'=fallidos
  DateTime? _desde;
  DateTime? _hasta;

  @override
  void initState() {
    super.initState();
    _cargarModulos();
    _cargarResumen();
    _cargar();
  }

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarModulos() async {
    try {
      final m = await _servicio.modulos();
      if (mounted) setState(() => _modulos = m);
    } catch (_) {}
  }

  Future<void> _cargarResumen() async {
    try {
      final r = await _servicio.resumen();
      if (mounted) setState(() => _resumenUsuarios = r);
    } catch (_) {}
  }

  Map<String, String> get _filtrosActuales {
    final filtros = <String, String>{
      'pagina': '$_pagina',
      'por_pagina': '$_porPagina',
    };
    if (_busquedaCtrl.text.trim().isNotEmpty) filtros['q'] = _busquedaCtrl.text.trim();
    if (_moduloSeleccionado != null) filtros['modulo'] = _moduloSeleccionado!;
    if (_estadoSeleccionado != null) filtros['exitoso'] = _estadoSeleccionado!;
    if (_desde != null) filtros['desde'] = _fmtFecha(_desde!);
    if (_hasta != null) filtros['hasta'] = _fmtFecha(_hasta!);
    return filtros;
  }

  String _fmtFecha(DateTime f) =>
      '${f.year.toString().padLeft(4, '0')}-${f.month.toString().padLeft(2, '0')}-${f.day.toString().padLeft(2, '0')}';

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final data = await _servicio.listar(_filtrosActuales);
      if (mounted) {
        setState(() {
          _registros = data['registros'] as List<dynamic>;
          _total = data['total'] as int;
        });
      }
    } catch (e) {
      if (mounted) Notificacion.error(context, e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _aplicarFiltros() {
    _pagina = 1;
    _cargar();
  }

  void _limpiarFiltros() {
    setState(() {
      _busquedaCtrl.clear();
      _moduloSeleccionado = null;
      _estadoSeleccionado = null;
      _desde = null;
      _hasta = null;
      _pagina = 1;
    });
    _cargar();
  }

  Future<void> _elegirRangoFechas() async {
    final rango = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _desde != null && _hasta != null
          ? DateTimeRange(start: _desde!, end: _hasta!)
          : null,
    );
    if (rango != null) {
      setState(() {
        _desde = rango.start;
        _hasta = rango.end;
      });
      _aplicarFiltros();
    }
  }

  int get _totalPaginas => (_total / _porPagina).ceil().clamp(1, 999999);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(),
        if (_mostrarResumen) _buildResumenUsuarios(),
        _buildFiltros(),
        Expanded(child: _buildCuerpo()),
        _buildPaginacion(),
      ],
    );
  }

  Widget _buildHeader() => Container(
        padding: const EdgeInsets.fromLTRB(28, 22, 28, 14),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
        ),
        child: Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Auditoría del sistema',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: ColoresCarolina.celesteOscuro)),
                const SizedBox(height: 4),
                Text('$_total movimiento(s) registrado(s)',
                    style: const TextStyle(fontSize: 13, color: ColoresCarolina.grisMedio)),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () => setState(() => _mostrarResumen = !_mostrarResumen),
            icon: Icon(_mostrarResumen ? Icons.expand_less_rounded : Icons.bar_chart_rounded),
            label: const Text('Actividad por usuario'),
          ),
          IconButton(
            onPressed: _cargando ? null : _cargar,
            icon: const Icon(Icons.refresh_rounded),
            color: ColoresCarolina.celeste,
            tooltip: 'Actualizar',
          ),
        ]),
      );

  Widget _buildResumenUsuarios() {
    if (_resumenUsuarios.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 28, vertical: 12),
        child: Text('Aún no hay actividad registrada.',
            style: TextStyle(color: ColoresCarolina.grisMedio, fontSize: 13)),
      );
    }
    final maxTotal = _resumenUsuarios.fold<int>(
        0, (m, r) => ((r['total_acciones'] as int?) ?? 0) > m ? (r['total_acciones'] as int) : m);
    final tope = maxTotal <= 0 ? 1 : maxTotal;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(28, 4, 28, 18),
      child: Wrap(
        spacing: 24,
        runSpacing: 12,
        children: _resumenUsuarios.map((r) {
          final total = (r['total_acciones'] as int?) ?? 0;
          final ratio = (total / tope).clamp(0.05, 1.0);
          return SizedBox(
            width: 220,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(r['usuario'] as String? ?? 'Desconocido',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis),
                  ),
                  Text('$total', style: const TextStyle(fontSize: 12, color: ColoresCarolina.grisMedio)),
                ]),
                const SizedBox(height: 4),
                LayoutBuilder(builder: (context, c) {
                  return Container(
                    height: 6,
                    width: c.maxWidth,
                    decoration: BoxDecoration(
                        color: ColoresCarolina.grisClaro, borderRadius: BorderRadius.circular(3)),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        height: 6,
                        width: c.maxWidth * ratio,
                        decoration: BoxDecoration(
                            color: ColoresCarolina.celeste, borderRadius: BorderRadius.circular(3)),
                      ),
                    ),
                  );
                }),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFiltros() {
    final movil = Breakpoints.esMovil(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
      color: Colors.white,
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: movil ? double.infinity : 260,
            child: TextField(
              controller: _busquedaCtrl,
              onSubmitted: (_) => _aplicarFiltros(),
              decoration: InputDecoration(
                hintText: 'Buscar por usuario o descripción...',
                isDense: true,
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          SizedBox(
            width: movil ? double.infinity : 180,
            child: DropdownButtonFormField<String?>(
              initialValue: _moduloSeleccionado,
              isDense: true,
              decoration: InputDecoration(
                labelText: 'Módulo',
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('Todos')),
                ..._modulos.map((m) => DropdownMenuItem(
                    value: m as String, child: Text(kModulosLegibles[m] ?? m))),
              ],
              onChanged: (v) {
                setState(() => _moduloSeleccionado = v);
                _aplicarFiltros();
              },
            ),
          ),
          SizedBox(
            width: movil ? double.infinity : 160,
            child: DropdownButtonFormField<String?>(
              initialValue: _estadoSeleccionado,
              isDense: true,
              decoration: InputDecoration(
                labelText: 'Estado',
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
              items: const [
                DropdownMenuItem(value: null, child: Text('Todos')),
                DropdownMenuItem(value: 'true', child: Text('Exitosos')),
                DropdownMenuItem(value: 'false', child: Text('Fallidos')),
              ],
              onChanged: (v) {
                setState(() => _estadoSeleccionado = v);
                _aplicarFiltros();
              },
            ),
          ),
          OutlinedButton.icon(
            onPressed: _elegirRangoFechas,
            icon: const Icon(Icons.date_range_rounded, size: 18),
            label: Text(_desde == null
                ? 'Rango de fechas'
                : '${_fmtFecha(_desde!)} → ${_fmtFecha(_hasta!)}'),
          ),
          if (_busquedaCtrl.text.isNotEmpty ||
              _moduloSeleccionado != null ||
              _estadoSeleccionado != null ||
              _desde != null)
            TextButton.icon(
              onPressed: _limpiarFiltros,
              icon: const Icon(Icons.clear_rounded, size: 18),
              label: const Text('Limpiar'),
            ),
        ],
      ),
    );
  }

  Widget _buildCuerpo() {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator(color: ColoresCarolina.celeste));
    }
    if (_registros.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_toggle_off_rounded,
                size: 72, color: ColoresCarolina.grisMedio.withValues(alpha: 0.35)),
            const SizedBox(height: 14),
            const Text('No hay movimientos con estos filtros',
                style: TextStyle(color: ColoresCarolina.grisMedio, fontSize: 15)),
          ],
        ),
      );
    }

    if (Breakpoints.esMovil(context)) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _registros.length,
        itemBuilder: (_, i) => _tarjetaMovil(_registros[i] as Map),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Column(children: [
            Container(
              color: const Color(0xFFF8FAFC),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(children: [
                _th('FECHA', 2),
                _th('USUARIO', 2),
                _th('MÓDULO', 2),
                _th('DESCRIPCIÓN', 4),
                _th('ESTADO', 1),
              ]),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            ..._registros.asMap().entries.map((e) {
              return Column(children: [
                _filaTabla(e.value as Map, e.key.isOdd),
                if (e.key < _registros.length - 1)
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
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
                letterSpacing: 0.8)),
      );

  String _fechaLegible(String? iso) {
    if (iso == null) return '-';
    final f = DateTime.tryParse(iso);
    if (f == null) return iso;
    String d2(int n) => n.toString().padLeft(2, '0');
    return '${d2(f.day)}/${d2(f.month)}/${f.year} ${d2(f.hour)}:${d2(f.minute)}';
  }

  Widget _filaTabla(Map r, bool impar) {
    final exitoso = r['exitoso'] as bool? ?? true;
    final accion = r['accion'] as String? ?? '';
    final modulo = r['modulo'] as String? ?? '';
    return Container(
      color: impar ? const Color(0xFFFAFBFF) : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(children: [
        Expanded(
            flex: 2,
            child: Text(_fechaLegible(r['fecha'] as String?),
                style: const TextStyle(fontSize: 12, color: Color(0xFF475569)))),
        Expanded(
          flex: 2,
          child: Text(r['usuario'] as String? ?? '-',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis),
        ),
        Expanded(
          flex: 2,
          child: Row(children: [
            Icon(kIconosAccion[accion] ?? Icons.circle_outlined,
                size: 14, color: ColoresCarolina.celeste),
            const SizedBox(width: 6),
            Expanded(
              child: Text(kModulosLegibles[modulo] ?? modulo,
                  style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
            ),
          ]),
        ),
        Expanded(
          flex: 4,
          child: Text(r['descripcion'] as String? ?? '',
              style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
        ),
        Expanded(
          flex: 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (exitoso ? Colors.green : ColoresCarolina.rojo).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(exitoso ? 'OK' : 'Falló',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: exitoso ? Colors.green : ColoresCarolina.rojo)),
          ),
        ),
      ]),
    );
  }

  Widget _tarjetaMovil(Map r) {
    final exitoso = r['exitoso'] as bool? ?? true;
    final accion = r['accion'] as String? ?? '';
    final modulo = r['modulo'] as String? ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
            Icon(kIconosAccion[accion] ?? Icons.circle_outlined,
                size: 18, color: ColoresCarolina.celeste),
            const SizedBox(width: 8),
            Expanded(
              child: Text(r['descripcion'] as String? ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: (exitoso ? Colors.green : ColoresCarolina.rojo).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(exitoso ? 'OK' : 'Falló',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: exitoso ? Colors.green : ColoresCarolina.rojo)),
            ),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 4, children: [
            _dato(Icons.person_outline, r['usuario'] as String? ?? '-'),
            _dato(Icons.folder_outlined, kModulosLegibles[modulo] ?? modulo),
            _dato(Icons.schedule_rounded, _fechaLegible(r['fecha'] as String?)),
          ]),
        ],
      ),
    );
  }

  Widget _dato(IconData icono, String valor) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration:
            BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icono, size: 13, color: ColoresCarolina.grisMedio),
          const SizedBox(width: 5),
          Text(valor, style: const TextStyle(fontSize: 11, color: Color(0xFF475569))),
        ]),
      );

  Widget _buildPaginacion() {
    if (_total <= _porPagina) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: _pagina > 1
                ? () {
                    setState(() => _pagina--);
                    _cargar();
                  }
                : null,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Text('Página $_pagina de $_totalPaginas',
              style: const TextStyle(fontSize: 13, color: ColoresCarolina.grisMedio)),
          IconButton(
            onPressed: _pagina < _totalPaginas
                ? () {
                    setState(() => _pagina++);
                    _cargar();
                  }
                : null,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}
