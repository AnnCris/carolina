// carolina/frontend/lib/pantallas/devoluciones/devoluciones_pantalla.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../constantes/breakpoints.dart';
import '../../constantes/colores.dart';
import '../../constantes/api.dart';
import '../../servicios/auth_servicio.dart';
import '../../widgets/notificacion.dart';

// ─── Motivos ────────────────────────────────────────────────────────────────
const Map<String, String> kMotivosDevolucion = {
  'vencido': 'Producto vencido',
  'danado': 'Producto dañado',
  'perdio_vacio': 'Perdió el vacío',
  'otro': 'Otro motivo',
};

// ─── Servicio ─────────────────────────────────────────────────────────────────
class DevolucionesServicio {
  final _auth = AuthServicio();
  Future<Map<String, String>> get _h => _auth.obtenerHeaders();

  Future<List<dynamic>> listar() async {
    final res = await http.get(Uri.parse(ApiConfig.devoluciones), headers: await _h);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Error al cargar devoluciones (${res.statusCode})');
  }

  Future<List<dynamic>> listarClientes() async {
    final res = await http.get(Uri.parse(ApiConfig.clientes), headers: await _h);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Error al cargar clientes');
  }

  Future<List<dynamic>> listarProductos() async {
    final res = await http.get(Uri.parse(ApiConfig.productos), headers: await _h);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Error al cargar productos');
  }

  Future<Map<String, dynamic>> crear(Map<String, dynamic> datos) async {
    final res = await http.post(Uri.parse(ApiConfig.devoluciones),
        headers: await _h, body: jsonEncode(datos));
    final data = jsonDecode(res.body);
    if (res.statusCode == 201) return data;
    if (data['errores'] != null) throw Exception((data['errores'] as Map).values.first.toString());
    throw Exception(data['error'] ?? 'Error al crear');
  }

  Future<Map<String, dynamic>> actualizar(int id, Map<String, dynamic> datos) async {
    final res = await http.put(Uri.parse('${ApiConfig.devoluciones}/$id'),
        headers: await _h, body: jsonEncode(datos));
    final data = jsonDecode(res.body);
    if (res.statusCode == 200) return data;
    if (data['errores'] != null) throw Exception((data['errores'] as Map).values.first.toString());
    throw Exception(data['error'] ?? 'Error al actualizar');
  }

  Future<void> eliminar(int id) async {
    final res = await http.delete(Uri.parse('${ApiConfig.devoluciones}/$id'), headers: await _h);
    if (res.statusCode != 200) throw Exception('Error al eliminar');
  }

  Future<Map<String, dynamic>> resolver(int id) async {
    final res = await http.post(Uri.parse('${ApiConfig.devoluciones}/$id/resolver'),
        headers: await _h, body: jsonEncode({}));
    final data = jsonDecode(res.body);
    if (res.statusCode == 200) return data;
    throw Exception(data['error'] ?? 'Error al marcar como resuelta');
  }
}

// ─── Pantalla ─────────────────────────────────────────────────────────────────
class DevolucionesPantalla extends StatefulWidget {
  const DevolucionesPantalla({super.key});
  @override
  State<DevolucionesPantalla> createState() => _DevolucionesPantallaState();
}

class _DevolucionesPantallaState extends State<DevolucionesPantalla> {
  final _servicio = DevolucionesServicio();
  List<dynamic> _devoluciones = [];
  List<dynamic> _clientes = [];
  List<dynamic> _productos = [];
  bool _cargando = true;
  String _busqueda = '';
  String _filtroEstado = 'todos';

  @override
  void initState() { super.initState(); _cargar(); }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final d = await _servicio.listar();
      final c = await _servicio.listarClientes();
      final p = await _servicio.listarProductos();
      setState(() { _devoluciones = d; _clientes = c; _productos = p; });
    } catch (e) {
      if (mounted) Notificacion.error(context, e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  List<dynamic> get _filtradas {
    return _devoluciones.where((d) {
      if (_filtroEstado != 'todos' && d['estado'] != _filtroEstado) return false;
      if (_busqueda.isEmpty) return true;
      final q = _busqueda.toLowerCase();
      final productos = (d['detalles'] as List? ?? [])
          .map((e) => (e['producto'] ?? '').toString().toLowerCase()).join(' ');
      return (d['cliente'] ?? '').toString().toLowerCase().contains(q) ||
             productos.contains(q);
    }).toList();
  }

  int get _totalPendientes => _devoluciones.where((d) => d['estado'] == 'pendiente').length;
  int get _totalResueltas => _devoluciones.where((d) => d['estado'] == 'resuelta').length;

  void _verDetalle(Map<String, dynamic> d) => showDialog(
      context: context, builder: (_) => _DetalleDevolucion(devolucion: d));

  void _abrirFormulario({Map<String, dynamic>? devolucion}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _FormularioDevolucion(
        devolucion: devolucion,
        clientes: _clientes,
        productos: _productos,
        servicio: _servicio,
        onGuardado: () {
          Navigator.pop(context);
          Notificacion.exito(context,
              devolucion == null ? 'Devolución registrada' : 'Devolución actualizada');
          _cargar();
        },
      ),
    );
  }

  Future<void> _resolver(Map<String, dynamic> d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.check_circle_rounded, color: ColoresCarolina.exito),
          SizedBox(width: 10),
          Text('Marcar como resuelta'),
        ]),
        content: Text(
            '¿Ya se le entregó el producto de cambio a "${d['cliente']}"?\n\n'
            'Se marcará esta devolución como resuelta.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: ColoresCarolina.exito,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('Sí, resuelta'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await _servicio.resolver(d['id']);
        if (mounted) { Notificacion.exito(context, 'Devolución marcada como resuelta'); _cargar(); }
      } catch (e) {
        if (mounted) Notificacion.error(context, e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  Future<void> _eliminar(Map<String, dynamic> d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Container(padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: ColoresCarolina.rojo.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.delete_forever_rounded,
                  color: ColoresCarolina.rojo, size: 22)),
          const SizedBox(width: 12),
          const Expanded(child: Text('Eliminar devolución')),
        ]),
        content: Text('¿Seguro que deseas eliminar la devolución de "${d['cliente']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: ColoresCarolina.rojo,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('Sí, eliminar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await _servicio.eliminar(d['id']);
        if (mounted) { Notificacion.exito(context, 'Devolución eliminada'); _cargar(); }
      } catch (e) {
        if (mounted) Notificacion.error(context, e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _buildHeader(), _buildBarra(), Expanded(child: _buildCuerpo(_filtradas)),
    ]);
  }

  Widget _buildHeader() {
    final movil = Breakpoints.esMovil(context);
    final titulo = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Devoluciones y Cambios', style: TextStyle(fontSize: 24,
          fontWeight: FontWeight.bold, color: ColoresCarolina.celesteOscuro)),
      const SizedBox(height: 4),
      const Text('Registra productos vencidos, dañados o sin vacío que el cliente devuelve.',
          style: TextStyle(fontSize: 12.5, color: ColoresCarolina.grisMedio)),
      const SizedBox(height: 8),
      Wrap(spacing: 6, runSpacing: 6, children: [
        _chip('$_totalPendientes pendiente(s)', Colors.orange),
        _chip('$_totalResueltas resuelta(s)', ColoresCarolina.exito),
      ]),
    ]);
    final boton = ElevatedButton.icon(
      onPressed: () => _abrirFormulario(),
      icon: const Icon(Icons.add_rounded, size: 18),
      label: const Text('Nueva Devolución'),
      style: ElevatedButton.styleFrom(
        backgroundColor: ColoresCarolina.celeste, foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    return Container(
      padding: EdgeInsets.fromLTRB(movil ? 16 : 28, 22, movil ? 16 : 28, 18),
      decoration: const BoxDecoration(color: Colors.white,
          border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0)))),
      child: movil
          ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              titulo, const SizedBox(height: 14), boton,
            ])
          : Row(children: [Expanded(child: titulo), boton]),
    );
  }

  Widget _buildBarra() {
    final movil = Breakpoints.esMovil(context);
    final buscador = TextField(
      onChanged: (v) => setState(() => _busqueda = v),
      decoration: InputDecoration(
        hintText: 'Buscar por cliente o producto...',
        prefixIcon: const Icon(Icons.search_rounded, color: ColoresCarolina.celeste),
        suffixIcon: _busqueda.isNotEmpty
            ? IconButton(icon: const Icon(Icons.clear_rounded, size: 18),
                tooltip: 'Limpiar búsqueda',
                onPressed: () => setState(() => _busqueda = ''))
            : null,
        filled: true, fillColor: const Color(0xFFF1F5F9),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: ColoresCarolina.celeste, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
    final filtros = Container(
      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _btnFiltro('Todas', 'todos', Icons.list_alt_rounded),
        _btnFiltro('Pendientes', 'pendiente', Icons.pending_actions_rounded),
        _btnFiltro('Resueltas', 'resuelta', Icons.check_circle_rounded),
      ]),
    );
    final refrescar = IconButton(onPressed: _cargar, icon: const Icon(Icons.refresh_rounded),
        color: ColoresCarolina.celeste, tooltip: 'Actualizar');

    return Container(
      padding: EdgeInsets.symmetric(horizontal: movil ? 16 : 28, vertical: 12),
      color: Colors.white,
      child: movil
          ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              buscador,
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [filtros, const SizedBox(width: 8), refrescar]),
              ),
            ])
          : Row(children: [
              Expanded(child: buscador),
              const SizedBox(width: 12),
              filtros,
              const SizedBox(width: 8),
              refrescar,
            ]),
    );
  }

  Widget _btnFiltro(String label, String valor, IconData icono) {
    final sel = _filtroEstado == valor;
    return InkWell(
      onTap: () => setState(() => _filtroEstado = valor),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
            color: sel ? ColoresCarolina.celeste : Colors.transparent,
            borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icono, size: 15, color: sel ? Colors.white : ColoresCarolina.grisMedio),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 12.5,
              color: sel ? Colors.white : ColoresCarolina.grisMedio,
              fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
        ]),
      ),
    );
  }

  Widget _buildCuerpo(List<dynamic> filtradas) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator(color: ColoresCarolina.celeste));
    }
    if (filtradas.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.assignment_return_outlined, size: 72,
            color: ColoresCarolina.grisMedio.withValues(alpha: 0.35)),
        const SizedBox(height: 14),
        Text(_busqueda.isNotEmpty
            ? 'No hay resultados para "$_busqueda"'
            : 'No hay devoluciones registradas',
            style: const TextStyle(color: ColoresCarolina.grisMedio, fontSize: 15)),
      ]));
    }

    if (Breakpoints.esMovil(context)) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filtradas.length,
        itemBuilder: (_, i) {
          final d = filtradas[i];
          return _TarjetaDevolucionMovil(
            devolucion: d,
            onVer: () => _verDetalle(d),
            onEditar: d['estado'] == 'pendiente' ? () => _abrirFormulario(devolucion: d) : null,
            onResolver: d['estado'] == 'pendiente' ? () => _resolver(d) : null,
            onEliminar: () => _eliminar(d),
          );
        },
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFFE2E8F0))),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Column(children: [
            Container(
              color: const Color(0xFFF8FAFC),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(children: [
                _th('CLIENTE', 3),
                _th('PRODUCTOS', 4),
                _th('FECHA', 2),
                _th('ESTADO', 2),
                _th('ACCIONES', 3),
              ]),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            ...filtradas.asMap().entries.map((e) {
              final d = e.value;
              return Column(children: [
                _FilaDevolucion(
                  devolucion: d,
                  impar: e.key.isOdd,
                  onVer: () => _verDetalle(d),
                  onEditar: d['estado'] == 'pendiente' ? () => _abrirFormulario(devolucion: d) : null,
                  onResolver: d['estado'] == 'pendiente' ? () => _resolver(d) : null,
                  onEliminar: () => _eliminar(d),
                ),
                if (e.key < filtradas.length - 1)
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
              ]);
            }),
          ]),
        ),
      ),
    );
  }

  Widget _th(String t, int flex) => Expanded(flex: flex,
      child: Text(t, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
          color: ColoresCarolina.grisMedio, letterSpacing: 0.8)));

  Widget _chip(String t, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
    child: Text(t, style: TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.w600)),
  );
}

// ─── Fila (escritorio) ────────────────────────────────────────────────────────
class _FilaDevolucion extends StatelessWidget {
  final Map<String, dynamic> devolucion;
  final bool impar;
  final VoidCallback onVer, onEliminar;
  final VoidCallback? onEditar, onResolver;

  const _FilaDevolucion({
    required this.devolucion, required this.impar,
    required this.onVer, required this.onEliminar,
    this.onEditar, this.onResolver,
  });

  @override
  Widget build(BuildContext context) {
    final pendiente = devolucion['estado'] == 'pendiente';
    final detalles = (devolucion['detalles'] as List?) ?? [];
    final resumen = detalles.map((d) => '${_fmtCantidad(d['cantidad'])} ${d['producto']}').join(', ');
    final fecha = (devolucion['fecha'] ?? '').toString();
    final fechaStr = fecha.length >= 10 ? fecha.substring(0, 10) : fecha;

    return Container(
      color: impar ? const Color(0xFFFAFBFF) : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(children: [
        Expanded(flex: 3, child: Text(devolucion['cliente'] ?? '-',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            overflow: TextOverflow.ellipsis)),
        Expanded(flex: 4, child: Text(resumen.isEmpty ? '—' : resumen,
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569)),
            overflow: TextOverflow.ellipsis)),
        Expanded(flex: 2, child: Text(fechaStr,
            style: const TextStyle(fontSize: 13, color: Color(0xFF475569)))),
        Expanded(flex: 2, child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
              color: (pendiente ? Colors.orange : ColoresCarolina.exito).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20)),
          child: Text(pendiente ? 'Pendiente' : 'Resuelta', textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                  color: pendiente ? Colors.orange : ColoresCarolina.exito)),
        )),
        Expanded(flex: 3, child: Row(mainAxisSize: MainAxisSize.min, children: [
          _btn(Icons.visibility_rounded, ColoresCarolina.celeste, 'Ver detalle', onVer),
          if (onEditar != null) ...[
            const SizedBox(width: 4),
            _btn(Icons.edit_rounded, Colors.orange, 'Editar', onEditar!),
          ],
          if (onResolver != null) ...[
            const SizedBox(width: 4),
            _btn(Icons.check_circle_outline_rounded, ColoresCarolina.exito, 'Marcar resuelta', onResolver!),
          ],
          const SizedBox(width: 4),
          _btn(Icons.delete_rounded, ColoresCarolina.rojo, 'Eliminar', onEliminar),
        ])),
      ]),
    );
  }

  Widget _btn(IconData i, Color c, String tip, VoidCallback fn) => Tooltip(
    message: tip,
    child: InkWell(onTap: fn, borderRadius: BorderRadius.circular(8),
      child: Container(padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(i, size: 16, color: c)),
    ),
  );
}

// ─── Tarjeta (móvil) ──────────────────────────────────────────────────────────
class _TarjetaDevolucionMovil extends StatelessWidget {
  final Map<String, dynamic> devolucion;
  final VoidCallback onVer, onEliminar;
  final VoidCallback? onEditar, onResolver;

  const _TarjetaDevolucionMovil({
    required this.devolucion, required this.onVer, required this.onEliminar,
    this.onEditar, this.onResolver,
  });

  @override
  Widget build(BuildContext context) {
    final pendiente = devolucion['estado'] == 'pendiente';
    final detalles = (devolucion['detalles'] as List?) ?? [];
    final resumen = detalles.map((d) => '${_fmtCantidad(d['cantidad'])} ${d['producto']}').join(', ');
    final fecha = (devolucion['fecha'] ?? '').toString();
    final fechaStr = fecha.length >= 10 ? fecha.substring(0, 10) : fecha;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColoresCarolina.borde),
        boxShadow: ColoresCarolina.sombraTarjeta(),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(devolucion['cliente'] ?? '-',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              overflow: TextOverflow.ellipsis)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: (pendiente ? Colors.orange : ColoresCarolina.exito).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20)),
            child: Text(pendiente ? 'PENDIENTE' : 'RESUELTA',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
                    color: pendiente ? Colors.orange : ColoresCarolina.exito)),
          ),
        ]),
        const SizedBox(height: 8),
        Text(resumen.isEmpty ? 'Sin productos' : resumen,
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569))),
        const SizedBox(height: 4),
        Text('Reportado: $fechaStr',
            style: const TextStyle(fontSize: 11.5, color: ColoresCarolina.grisMedio)),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          _btn(Icons.visibility_rounded, ColoresCarolina.celeste, 'Ver', onVer),
          if (onEditar != null) ...[
            const SizedBox(width: 6),
            _btn(Icons.edit_rounded, Colors.orange, 'Editar', onEditar!),
          ],
          if (onResolver != null) ...[
            const SizedBox(width: 6),
            _btn(Icons.check_circle_outline_rounded, ColoresCarolina.exito, 'Resolver', onResolver!),
          ],
          const SizedBox(width: 6),
          _btn(Icons.delete_rounded, ColoresCarolina.rojo, 'Eliminar', onEliminar),
        ]),
      ]),
    );
  }

  Widget _btn(IconData i, Color c, String tip, VoidCallback fn) => Tooltip(
    message: tip,
    child: InkWell(onTap: fn, borderRadius: BorderRadius.circular(8),
      child: Container(padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(i, size: 16, color: c)),
    ),
  );
}

String _fmtCantidad(dynamic v) {
  final n = (v as num?)?.toDouble() ?? 0;
  return n % 1 == 0 ? n.toStringAsFixed(0) : n.toStringAsFixed(2);
}

// ─── Detalle ──────────────────────────────────────────────────────────────────
class _DetalleDevolucion extends StatelessWidget {
  final Map<String, dynamic> devolucion;
  const _DetalleDevolucion({required this.devolucion});

  @override
  Widget build(BuildContext context) {
    final pendiente = devolucion['estado'] == 'pendiente';
    final detalles = (devolucion['detalles'] as List?) ?? [];
    final fecha = (devolucion['fecha'] ?? '').toString();
    final fechaStr = fecha.length >= 16 ? fecha.substring(0, 16) : fecha;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              gradient: ColoresCarolina.gradienteMarca,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(children: [
              Row(children: [
                const Icon(Icons.assignment_return_rounded, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Expanded(child: Text('Devolución de ${devolucion['cliente'] ?? '-'}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    overflow: TextOverflow.ellipsis)),
                IconButton(onPressed: () => Navigator.pop(context), tooltip: 'Cerrar',
                    icon: const Icon(Icons.close, color: Colors.white)),
              ]),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(pendiente ? 'PENDIENTE' : 'RESUELTA',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ]),
          ),
          Flexible(child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _fila(Icons.event_outlined, 'Reportado', fechaStr),
              if (devolucion['venta_numero_recibo'] != null)
                _fila(Icons.receipt_long_outlined, 'Venta original', devolucion['venta_numero_recibo']),
              if (!pendiente) ...[
                _fila(Icons.event_available_outlined, 'Resuelto',
                    (devolucion['fecha_resolucion'] ?? '-').toString()),
                if (devolucion['venta_resolucion_numero_recibo'] != null)
                  _fila(Icons.receipt_rounded, 'Cambio registrado en',
                      devolucion['venta_resolucion_numero_recibo']),
              ],
              const SizedBox(height: 8),
              const Text('Productos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              ...detalles.map((d) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${_fmtCantidad(d['cantidad'])} × ${d['producto']}',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text(kMotivosDevolucion[d['motivo']] ?? d['motivo'] ?? '-',
                          style: const TextStyle(fontSize: 12, color: ColoresCarolina.celesteOscuro)),
                      if ((d['motivo_detalle'] ?? '').toString().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(d['motivo_detalle'],
                            style: const TextStyle(fontSize: 12, color: ColoresCarolina.grisMedio)),
                      ],
                    ]),
                  )),
              if ((devolucion['nota'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 4),
                const Text('Nota', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                Text(devolucion['nota'], style: const TextStyle(fontSize: 13)),
              ],
            ]),
          )),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: SizedBox(width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: ColoresCarolina.celeste,
                    foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                child: const Text('Cerrar', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _fila(IconData i, String l, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(i, size: 17, color: ColoresCarolina.celeste),
      const SizedBox(width: 10),
      SizedBox(width: 110, child: Text(l,
          style: const TextStyle(color: ColoresCarolina.grisMedio, fontSize: 12.5))),
      Expanded(child: Text(v, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
    ]),
  );
}

// ─── Formulario (crear / editar) ──────────────────────────────────────────────
class _FormularioDevolucion extends StatefulWidget {
  final Map<String, dynamic>? devolucion;
  final List<dynamic> clientes, productos;
  final DevolucionesServicio servicio;
  final VoidCallback onGuardado;

  const _FormularioDevolucion({
    this.devolucion, required this.clientes, required this.productos,
    required this.servicio, required this.onGuardado,
  });

  @override
  State<_FormularioDevolucion> createState() => _FormularioDevolucionState();
}

class _FilaProductoDevolucion {
  int? productoId;
  final TextEditingController cantidadCtrl = TextEditingController(text: '1');
  String motivo = 'vencido';
  final TextEditingController detalleCtrl = TextEditingController();

  void dispose() {
    cantidadCtrl.dispose();
    detalleCtrl.dispose();
  }
}

class _FormularioDevolucionState extends State<_FormularioDevolucion> {
  final _formKey = GlobalKey<FormState>();
  final _notaCtrl = TextEditingController();
  int? _clienteId;
  bool _cargando = false;
  final List<_FilaProductoDevolucion> _filas = [];

  bool get _esEdicion => widget.devolucion != null;

  @override
  void initState() {
    super.initState();
    if (_esEdicion) {
      final d = widget.devolucion!;
      _clienteId = d['cliente_id'] as int?;
      _notaCtrl.text = d['nota']?.toString() ?? '';
      final detalles = d['detalles'] as List? ?? [];
      for (final det in detalles) {
        final fila = _FilaProductoDevolucion()
          ..productoId = det['producto_id'] as int?
          ..motivo = det['motivo'] as String? ?? 'vencido';
        fila.cantidadCtrl.text = _fmtCantidad(det['cantidad']);
        fila.detalleCtrl.text = det['motivo_detalle']?.toString() ?? '';
        _filas.add(fila);
      }
    }
    if (_filas.isEmpty) _filas.add(_FilaProductoDevolucion());
  }

  @override
  void dispose() {
    _notaCtrl.dispose();
    for (final f in _filas) f.dispose();
    super.dispose();
  }

  void _agregarFila() => setState(() => _filas.add(_FilaProductoDevolucion()));

  void _quitarFila(int i) {
    if (_filas.length <= 1) return;
    setState(() { _filas[i].dispose(); _filas.removeAt(i); });
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_clienteId == null) {
      Notificacion.error(context, 'Selecciona un cliente');
      return;
    }
    for (final f in _filas) {
      if (f.productoId == null) {
        Notificacion.error(context, 'Selecciona el producto en cada fila');
        return;
      }
      if (f.motivo == 'otro' && f.detalleCtrl.text.trim().isEmpty) {
        Notificacion.error(context, 'Describe el motivo cuando eliges "Otro motivo"');
        return;
      }
    }

    setState(() => _cargando = true);
    final datos = <String, dynamic>{
      'cliente_id': _clienteId,
      'nota': _notaCtrl.text.trim(),
      'detalles': _filas.map((f) => {
        'producto_id': f.productoId,
        'cantidad': double.tryParse(f.cantidadCtrl.text.trim()) ?? 0,
        'motivo': f.motivo,
        'motivo_detalle': f.detalleCtrl.text.trim(),
      }).toList(),
    };

    try {
      if (_esEdicion) {
        await widget.servicio.actualizar(widget.devolucion!['id'], datos);
      } else {
        await widget.servicio.crear(datos);
      }
      widget.onGuardado();
    } catch (e) {
      if (mounted) Notificacion.error(context, e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final movil = Breakpoints.esMovil(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: EdgeInsets.all(movil ? 12 : 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.fromLTRB(22, 16, 12, 16),
            decoration: const BoxDecoration(
              gradient: ColoresCarolina.gradienteMarca,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(children: [
              Icon(_esEdicion ? Icons.edit_rounded : Icons.add_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Text(_esEdicion ? 'Editar Devolución' : 'Nueva Devolución',
                  style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(onPressed: () => Navigator.pop(context), tooltip: 'Cerrar',
                  icon: const Icon(Icons.close, color: Colors.white)),
            ]),
          ),
          Flexible(child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: Form(key: _formKey, child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: _clienteId,
                  decoration: InputDecoration(
                    labelText: 'Cliente *',
                    prefixIcon: const Icon(Icons.person_outline, color: ColoresCarolina.celeste),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: ColoresCarolina.celeste, width: 2)),
                  ),
                  items: widget.clientes.map<DropdownMenuItem<int>>((c) => DropdownMenuItem(
                      value: c['id'] as int,
                      child: Text(c['nombre_completo'] as String, overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: (v) => setState(() => _clienteId = v),
                  validator: (v) => v == null ? 'Selecciona un cliente' : null,
                ),
                const SizedBox(height: 18),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Productos a devolver', style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14, color: ColoresCarolina.celesteOscuro)),
                  TextButton.icon(
                    onPressed: _agregarFila,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Agregar producto'),
                  ),
                ]),
                const SizedBox(height: 8),
                ..._filas.asMap().entries.map((entry) =>
                    _buildFilaProducto(entry.key, entry.value, movil)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _notaCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Nota general (opcional)',
                    hintText: 'Ej: cliente llamó el 01/08 avisando de los productos',
                    prefixIcon: const Icon(Icons.notes_rounded, color: ColoresCarolina.celeste),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: ColoresCarolina.celeste, width: 2)),
                  ),
                ),
              ],
            )),
          )),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
            child: Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                    foregroundColor: ColoresCarolina.grisMedio,
                    side: BorderSide(color: Colors.grey.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                child: const Text('Cancelar'),
              )),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: ElevatedButton(
                onPressed: _cargando ? null : _guardar,
                style: ElevatedButton.styleFrom(
                    backgroundColor: ColoresCarolina.celeste, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                child: _cargando
                    ? const SizedBox(height: 20, width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(_esEdicion ? 'Guardar Cambios' : 'Registrar Devolución',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              )),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildFilaProducto(int i, _FilaProductoDevolucion fila, bool movil) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColoresCarolina.borde),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<int>(
              initialValue: fila.productoId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Producto *',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              items: widget.productos.map<DropdownMenuItem<int>>((p) => DropdownMenuItem(
                  value: p['id'] as int,
                  child: Text(p['nombre'] as String, overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (v) => setState(() => fila.productoId = v),
            ),
          ),
          if (_filas.length > 1) ...[
            const SizedBox(width: 6),
            IconButton(
              onPressed: () => _quitarFila(i),
              tooltip: 'Quitar producto',
              icon: const Icon(Icons.delete_outline_rounded, color: ColoresCarolina.rojo),
            ),
          ],
        ]),
        const SizedBox(height: 10),
        Row(children: [
          SizedBox(
            width: 100,
            child: TextFormField(
              controller: fila.cantidadCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Cantidad *', isDense: true,
                  border: OutlineInputBorder()),
              validator: (v) {
                final n = double.tryParse((v ?? '').trim());
                if (n == null || n <= 0) return 'Inválida';
                return null;
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: fila.motivo,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Motivo *', isDense: true,
                  border: OutlineInputBorder()),
              items: kMotivosDevolucion.entries
                  .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) => setState(() => fila.motivo = v ?? 'vencido'),
            ),
          ),
        ]),
        if (fila.motivo == 'otro') ...[
          const SizedBox(height: 10),
          TextFormField(
            controller: fila.detalleCtrl,
            decoration: const InputDecoration(
              labelText: 'Describe el motivo *',
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ]),
    );
  }
}
