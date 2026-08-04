// carolina/frontend/lib/pantallas/inventario/inventario_pantalla.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../constantes/colores.dart';
import '../../constantes/api.dart';
import '../../constantes/breakpoints.dart';
import '../../servicios/auth_servicio.dart';
import '../../widgets/notificacion.dart';

// ─── Servicio ─────────────────────────────────────────────────────────────────
class InventarioServicio {
  final _auth = AuthServicio();
  Future<Map<String, String>> get _h => _auth.obtenerHeaders();

  Future<List<dynamic>> listar() async {
    final res = await http.get(Uri.parse(ApiConfig.inventario), headers: await _h);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Error al cargar inventario (${res.statusCode})');
  }

  Future<List<dynamic>> movimientos(int productoId) async {
    final res = await http.get(
        Uri.parse('${ApiConfig.inventario}/$productoId/movimientos'),
        headers: await _h);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Error al cargar movimientos');
  }

  Future<Map<String, dynamic>> actualizarMinimos(
      int productoId, Map<String, dynamic> datos) async {
    final res = await http.put(
        Uri.parse('${ApiConfig.inventario}/$productoId'),
        headers: await _h, body: jsonEncode(datos));
    final data = jsonDecode(res.body);
    if (res.statusCode == 200) return data;
    if (data['errores'] != null) {
      throw Exception((data['errores'] as Map).values.first.toString());
    }
    throw Exception(data['error'] ?? 'Error al actualizar');
  }

  Future<Map<String, dynamic>> ajustar(
      int productoId, Map<String, dynamic> datos) async {
    final res = await http.post(
        Uri.parse('${ApiConfig.inventario}/$productoId/ajuste'),
        headers: await _h, body: jsonEncode(datos));
    final data = jsonDecode(res.body);
    if (res.statusCode == 200) return data;
    if (data['errores'] != null) {
      throw Exception((data['errores'] as Map).values.first.toString());
    }
    throw Exception(data['error'] ?? 'Error al ajustar');
  }

  Future<void> eliminar(int productoId) async {
    final res = await http.delete(
        Uri.parse('${ApiConfig.inventario}/$productoId'), headers: await _h);
    if (res.statusCode != 200) {
      final data = jsonDecode(res.body);
      throw Exception(data['error'] ?? 'Error al eliminar');
    }
  }
}

// ─── Pantalla ─────────────────────────────────────────────────────────────────
class InventarioPantalla extends StatefulWidget {
  const InventarioPantalla({super.key});
  @override
  State<InventarioPantalla> createState() => _InventarioPantallaState();
}

class _InventarioPantallaState extends State<InventarioPantalla> {
  final _servicio = InventarioServicio();
  List<dynamic> _items    = [];
  bool   _cargando        = true;
  String _busqueda        = '';
  String _filtroEstado    = 'todos';

  @override
  void initState() { super.initState(); _cargar(); }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final i = await _servicio.listar();
      setState(() => _items = i);
    } catch (e) {
      if (mounted) {
        Notificacion.error(context, e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  List<dynamic> get _filtrados {
    return _items.where((i) {
      final estado = i['estado_stock'] as String? ?? 'normal';
      if (_filtroEstado == 'criticos' &&
          estado != 'critico' && estado != 'sin_stock') {
            return false;
      }
      if (_filtroEstado == 'normales'   && estado != 'normal')     return false;
      if (_filtroEstado == 'sobrestock' && estado != 'sobrestock') return false;
      if (_busqueda.isEmpty) return true;
      final q = _busqueda.toLowerCase();
      return (i['producto']  ?? '').toLowerCase().contains(q) ||
             (i['categoria'] ?? '').toLowerCase().contains(q);
    }).toList();
  }

  int get _totalCriticos => _items
      .where((i) => i['estado_stock'] == 'critico' ||
                    i['estado_stock'] == 'sin_stock')
      .length;

  Color _colorEstado(String? e) {
    switch (e) {
      case 'sin_stock':  return ColoresCarolina.rojo;
      case 'critico':    return Colors.orange;
      case 'sobrestock': return Colors.purple;
      default:           return Colors.green;
    }
  }

  IconData _iconoEstado(String? e) {
    switch (e) {
      case 'sin_stock':  return Icons.remove_circle_rounded;
      case 'critico':    return Icons.warning_amber_rounded;
      case 'sobrestock': return Icons.arrow_upward_rounded;
      default:           return Icons.check_circle_rounded;
    }
  }

  String _labelEstado(String? e) {
    switch (e) {
      case 'sin_stock':  return 'Sin stock';
      case 'critico':    return 'Crítico';
      case 'sobrestock': return 'Sobrestock';
      default:           return 'Normal';
    }
  }

  // Stock siempre en unidades
  String _fmt(double val) {
    if (val % 1 == 0) return '${val.toStringAsFixed(0)} unid.';
    return '${val.toStringAsFixed(2)} unid.';
  }

  Future<bool> _confirmar(String titulo, String msg) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: ColoresCarolina.rojo,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8))),
              child: const Text('Sí, eliminar')),
        ],
      ),
    );
    return r ?? false;
  }

  Future<void> _eliminar(Map<String, dynamic> item) async {
    final ok = await _confirmar('Eliminar registro',
        '⚠️ Se eliminará el registro de inventario de "${item['producto']}".\n\n'
        'El producto seguirá existiendo pero perderá su historial de stock.');
    if (ok && mounted) {
      try {
        await _servicio.eliminar(item['producto_id'] as int);
        if (mounted) {
          Notificacion.exito(context, 'Registro eliminado');
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

  void _abrirMovimientos(Map<String, dynamic> item) =>
      showDialog(context: context,
          builder: (_) => _MovimientosDialog(
              item: item, servicio: _servicio));

  void _abrirAjuste(Map<String, dynamic> item) =>
      showDialog(context: context, barrierDismissible: false,
          builder: (_) => _AjusteDialog(
            item: item, servicio: _servicio,
            onGuardado: () {
              Navigator.pop(context);
              Notificacion.exito(context, 'Stock ajustado');
              _cargar();
            },
          ));

  void _abrirMinimos(Map<String, dynamic> item) =>
      showDialog(context: context, barrierDismissible: false,
          builder: (_) => _MinimosDialog(
            item: item, servicio: _servicio,
            onGuardado: () {
              Navigator.pop(context);
              Notificacion.exito(context, 'Alertas actualizadas');
              _cargar();
            },
          ));

  @override
  Widget build(BuildContext context) {
    final filtrados = _filtrados;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _buildHeader(),
      _buildBarra(),
      Expanded(child: _buildCuerpo(filtrados)),
    ]);
  }

  Widget _buildHeader() {
    final movil = Breakpoints.esMovil(context);
    return Container(
      padding: EdgeInsets.fromLTRB(movil ? 16 : 28, 22, movil ? 16 : 28, 18),
      decoration: const BoxDecoration(color: Colors.white,
          border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0)))),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Gestión de Inventario',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold,
                    color: ColoresCarolina.celesteOscuro)),
            const SizedBox(height: 4),
            const Text(
                'Controla el stock disponible y recibe alertas de niveles bajos o excedentes.',
                style: TextStyle(fontSize: 13, color: ColoresCarolina.grisMedio)),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              _chip('${_items.length} productos', ColoresCarolina.celeste),
              if (_totalCriticos > 0)
                _chip('$_totalCriticos crítico(s)', Colors.orange),
              _chip('Método PEPS (FIFO)', Colors.purple),
            ]),
          ],
        )),
        IconButton(onPressed: _cargar, icon: const Icon(Icons.refresh_rounded),
            color: ColoresCarolina.celeste, tooltip: 'Actualizar'),
      ]),
    );
  }

  Widget _buildBarra() {
    final movil = Breakpoints.esMovil(context);
    final buscador = TextField(
      onChanged: (v) => setState(() => _busqueda = v),
      decoration: InputDecoration(
        hintText: 'Buscar por producto o categoría...',
        prefixIcon: const Icon(Icons.search_rounded,
            color: ColoresCarolina.celeste),
        suffixIcon: _busqueda.isNotEmpty
            ? IconButton(icon: const Icon(Icons.clear_rounded, size: 18),
                tooltip: 'Limpiar búsqueda',
                onPressed: () => setState(() => _busqueda = ''))
            : null,
        filled: true, fillColor: const Color(0xFFF1F5F9),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
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
    );
    final filtros = Container(
      decoration: BoxDecoration(color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _btnFiltro('Todos',      'todos',      Icons.inventory_2_rounded),
        _btnFiltro('Críticos',   'criticos',   Icons.warning_amber_rounded),
        _btnFiltro('Normales',   'normales',   Icons.check_circle_rounded),
        _btnFiltro('Sobrestock', 'sobrestock', Icons.arrow_upward_rounded),
      ]),
    );

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: movil ? 16 : 28, vertical: 12),
      color: Colors.white,
      child: movil
          ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              buscador,
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: filtros,
              ),
            ])
          : Row(children: [
              Expanded(child: buscador),
              const SizedBox(width: 12),
              filtros,
            ]),
    );
  }

  Widget _btnFiltro(String label, String valor, IconData icono) {
    final sel = _filtroEstado == valor;
    return GestureDetector(
      onTap: () => setState(() => _filtroEstado = valor),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
            color: sel ? ColoresCarolina.celeste : Colors.transparent,
            borderRadius: BorderRadius.circular(9)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icono, size: 14,
              color: sel ? Colors.white : ColoresCarolina.grisMedio),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11,
              fontWeight: sel ? FontWeight.bold : FontWeight.normal,
              color: sel ? Colors.white : ColoresCarolina.grisMedio)),
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
          Icon(Icons.inventory_2_outlined, size: 72,
              color: ColoresCarolina.grisMedio.withValues(alpha: 0.35)),
          const SizedBox(height: 14),
          Text(_busqueda.isNotEmpty
              ? 'No hay resultados para "$_busqueda"'
              : 'No hay productos en inventario',
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
          final item = filtrados[i];
          return _TarjetaInventario(
            item:          item,
            colorEstado:   _colorEstado(item['estado_stock']),
            iconoEstado:   _iconoEstado(item['estado_stock']),
            labelEstado:   _labelEstado(item['estado_stock']),
            fmtStock:      _fmt,
            onMovimientos: () => _abrirMovimientos(item),
            onAjuste:      () => _abrirAjuste(item),
            onMinimos:     () => _abrirMinimos(item),
            onEliminar:    () => _eliminar(item),
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(children: [
                _th('PRODUCTO',      4),
                _th('CATEGORÍA',     2),
                _th('STOCK (unid.)', 2),
                _th('MÍNIMO',        2),
                _th('MÁXIMO',        2),
                _th('ESTADO',        2),
                _th('ACCIONES',      3),
              ]),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            ...filtrados.asMap().entries.map((e) {
              final item = e.value;
              return Column(children: [
                _FilaInventario(
                  item:          item,
                  impar:         e.key.isOdd,
                  colorEstado:   _colorEstado(item['estado_stock']),
                  iconoEstado:   _iconoEstado(item['estado_stock']),
                  labelEstado:   _labelEstado(item['estado_stock']),
                  fmtStock:      _fmt,
                  onMovimientos: () => _abrirMovimientos(item),
                  onAjuste:      () => _abrirAjuste(item),
                  onMinimos:     () => _abrirMinimos(item),
                  onEliminar:    () => _eliminar(item),
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
          fontWeight: FontWeight.bold, color: ColoresCarolina.grisMedio,
          letterSpacing: 0.8)));

  Widget _chip(String t, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20)),
    child: Text(t, style: TextStyle(fontSize: 11, color: c,
        fontWeight: FontWeight.w600)),
  );
}

// ─── Fila ─────────────────────────────────────────────────────────────────────
class _FilaInventario extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool impar;
  final Color colorEstado;
  final IconData iconoEstado;
  final String labelEstado;
  final String Function(double) fmtStock;
  final VoidCallback onMovimientos, onAjuste, onMinimos, onEliminar;

  const _FilaInventario({
    required this.item,        required this.impar,
    required this.colorEstado, required this.iconoEstado,
    required this.labelEstado, required this.fmtStock,
    required this.onMovimientos, required this.onAjuste,
    required this.onMinimos,     required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    final stock  = (item['stock_actual'] as num).toDouble();
    final minimo = (item['stock_minimo'] as num).toDouble();
    final maximo = item['stock_maximo'] != null
        ? (item['stock_maximo'] as num).toDouble() : null;

    return Container(
      color: impar ? const Color(0xFFFAFBFF) : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(children: [
        // Producto
        Expanded(flex: 4, child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item['producto'] ?? '-',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                overflow: TextOverflow.ellipsis),
            const Text('PEPS · unidades',
                style: TextStyle(fontSize: 10, color: ColoresCarolina.grisMedio)),
          ],
        )),
        // Categoría
        Expanded(flex: 2, child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
              color: ColoresCarolina.celeste.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20)),
          child: Text(item['categoria'] ?? '-',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11,
                  color: ColoresCarolina.celeste, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis),
        )),
        // Stock
        Expanded(flex: 2, child: Text(fmtStock(stock),
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14,
                color: colorEstado))),
        // Mínimo
        Expanded(flex: 2, child: Text(fmtStock(minimo),
            style: const TextStyle(fontSize: 13, color: Color(0xFF475569)))),
        // Máximo
        Expanded(flex: 2, child: Text(
            maximo != null ? fmtStock(maximo) : '—',
            style: const TextStyle(fontSize: 13, color: Color(0xFF475569)))),
        // Estado
        Expanded(flex: 2, child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
              color: colorEstado.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(iconoEstado, size: 12, color: colorEstado),
            const SizedBox(width: 4),
            Text(labelEstado, style: TextStyle(fontSize: 10,
                fontWeight: FontWeight.bold, color: colorEstado)),
          ]),
        )),
        // Acciones
        Expanded(flex: 3, child: Row(mainAxisSize: MainAxisSize.min, children: [
          _btn(Icons.history_rounded,  ColoresCarolina.celeste,
              'Movimientos', onMovimientos),
          const SizedBox(width: 4),
          _btn(Icons.tune_rounded, Colors.orange,
              'Ajustar stock', onAjuste),
          const SizedBox(width: 4),
          _btn(Icons.settings_rounded, Colors.purple,
              'Configurar alertas', onMinimos),
          const SizedBox(width: 4),
          _btn(Icons.delete_rounded, ColoresCarolina.rojo,
              'Eliminar registro', onEliminar),
        ])),
      ]),
    );
  }

  Widget _btn(IconData i, Color c, String tip, VoidCallback fn) =>
      Tooltip(message: tip,
        child: InkWell(onTap: fn, borderRadius: BorderRadius.circular(8),
          child: Container(padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(color: c.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(i, size: 16, color: c))));
}

// ─── Tarjeta (vista móvil) ──────────────────────────────────────────────────────
class _TarjetaInventario extends StatelessWidget {
  final Map<String, dynamic> item;
  final Color colorEstado;
  final IconData iconoEstado;
  final String labelEstado;
  final String Function(double) fmtStock;
  final VoidCallback onMovimientos, onAjuste, onMinimos, onEliminar;

  const _TarjetaInventario({
    required this.item,        required this.colorEstado,
    required this.iconoEstado, required this.labelEstado,
    required this.fmtStock,    required this.onMovimientos,
    required this.onAjuste,    required this.onMinimos,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    final stock  = (item['stock_actual'] as num).toDouble();
    final minimo = (item['stock_minimo'] as num).toDouble();
    final maximo = item['stock_maximo'] != null
        ? (item['stock_maximo'] as num).toDouble() : null;

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
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item['producto'] ?? '-',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              const Text('PEPS · unidades',
                  style: TextStyle(fontSize: 10, color: ColoresCarolina.grisMedio)),
            ],
          )),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: colorEstado.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(iconoEstado, size: 12, color: colorEstado),
              const SizedBox(width: 4),
              Text(labelEstado, style: TextStyle(fontSize: 10,
                  fontWeight: FontWeight.bold, color: colorEstado)),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 16, runSpacing: 8, children: [
          _dato('Categoría', item['categoria'] ?? '-'),
          _dato('Stock', fmtStock(stock), color: colorEstado, negrita: true),
          _dato('Mínimo', fmtStock(minimo)),
          _dato('Máximo', maximo != null ? fmtStock(maximo) : '—'),
        ]),
        const SizedBox(height: 12),
        const Divider(height: 1, color: ColoresCarolina.borde),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          _btn(Icons.history_rounded, ColoresCarolina.celeste,
              'Movimientos', onMovimientos),
          const SizedBox(width: 6),
          _btn(Icons.tune_rounded, Colors.orange, 'Ajustar stock', onAjuste),
          const SizedBox(width: 6),
          _btn(Icons.settings_rounded, Colors.purple,
              'Configurar alertas', onMinimos),
          const SizedBox(width: 6),
          _btn(Icons.delete_rounded, ColoresCarolina.rojo,
              'Eliminar registro', onEliminar),
        ]),
      ]),
    );
  }

  Widget _dato(String label, String valor, {Color? color, bool negrita = false}) =>
      SizedBox(
        width: 120,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10,
                color: ColoresCarolina.grisMedio)),
            Text(valor, style: TextStyle(
                fontSize: 13,
                fontWeight: negrita ? FontWeight.bold : FontWeight.w600,
                color: color ?? const Color(0xFF475569)),
                overflow: TextOverflow.ellipsis),
          ],
        ),
      );

  Widget _btn(IconData i, Color c, String tip, VoidCallback fn) =>
      Tooltip(message: tip,
        child: InkWell(onTap: fn, borderRadius: BorderRadius.circular(8),
          child: Container(padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(color: c.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(i, size: 16, color: c))));
}

// ─── Dialog Movimientos ───────────────────────────────────────────────────────
class _MovimientosDialog extends StatefulWidget {
  final Map<String, dynamic> item;
  final InventarioServicio   servicio;
  const _MovimientosDialog({required this.item, required this.servicio});
  @override
  State<_MovimientosDialog> createState() => _MovimientosDialogState();
}

class _MovimientosDialogState extends State<_MovimientosDialog> {
  List<dynamic> _movs    = [];
  bool          _cargando = true;

  @override
  void initState() { super.initState(); _cargar(); }

  Future<void> _cargar() async {
    try {
      final m = await widget.servicio
          .movimientos(widget.item['producto_id'] as int);
      setState(() { _movs = m; _cargando = false; });
    } catch (_) {
      setState(() => _cargando = false);
    }
  }

  Color _colorTipo(String? t) {
    switch (t) {
      case 'entrada': return Colors.green;
      case 'salida':  return ColoresCarolina.rojo;
      default:        return Colors.orange;
    }
  }

  IconData _iconoTipo(String? t) {
    switch (t) {
      case 'entrada': return Icons.add_circle_rounded;
      case 'salida':  return Icons.remove_circle_rounded;
      default:        return Icons.tune_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.fromLTRB(22, 16, 12, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                  colors: [ColoresCarolina.celeste, ColoresCarolina.celesteOscuro],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            child: Row(children: [
              const Icon(Icons.history_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Expanded(child: Text(
                  'Movimientos — ${widget.item['producto']}',
                  style: const TextStyle(color: Colors.white, fontSize: 16,
                      fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis)),
              IconButton(onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white)),
            ]),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.purple.withValues(alpha: 0.2))),
            child: const Row(children: [
              Icon(Icons.info_outline_rounded, size: 15, color: Colors.purple),
              SizedBox(width: 8),
              Expanded(child: Text(
                'PEPS: primer lote en entrar = primer lote en salir. '
                'El stock siempre se muestra en unidades.',
                style: TextStyle(fontSize: 11, color: Colors.purple))),
            ]),
          ),
          Flexible(child: _cargando
              ? const Center(child: Padding(padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: ColoresCarolina.celeste)))
              : _movs.isEmpty
                  ? const Padding(padding: EdgeInsets.all(32),
                      child: Center(child: Text('Sin movimientos registrados',
                          style: TextStyle(color: ColoresCarolina.grisMedio))))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _movs.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final m    = _movs[i];
                        final tipo = m['tipo'] as String? ?? '';
                        final cant = (m['cantidad'] as num).toDouble();
                        final fecha = DateTime.tryParse(m['fecha'] ?? '');
                        final fechaStr = fecha != null
                            ? '${fecha.day.toString().padLeft(2,'0')}/'
                              '${fecha.month.toString().padLeft(2,'0')}/'
                              '${fecha.year} '
                              '${fecha.hour.toString().padLeft(2,'0')}:'
                              '${fecha.minute.toString().padLeft(2,'0')}'
                            : '-';
                        final color = _colorTipo(tipo);
                        final cantStr = cant % 1 == 0
                            ? cant.toStringAsFixed(0)
                            : cant.toStringAsFixed(2);
                        return ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8)),
                            child: Icon(_iconoTipo(tipo), color: color, size: 18),
                          ),
                          title: Text(
                            '${tipo.toUpperCase()} — $cantStr unid.',
                            style: TextStyle(fontWeight: FontWeight.w600,
                                color: color, fontSize: 13),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(m['referencia_tipo'] ?? '',
                                  style: const TextStyle(fontSize: 11)),
                              if (m['nota'] != null)
                                Text(m['nota'],
                                    style: const TextStyle(fontSize: 11,
                                        color: ColoresCarolina.grisMedio)),
                            ],
                          ),
                          trailing: Text(fechaStr,
                              style: const TextStyle(fontSize: 10,
                                  color: ColoresCarolina.grisMedio)),
                        );
                      },
                    )),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                    foregroundColor: ColoresCarolina.grisMedio,
                    side: BorderSide(color: Colors.grey.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
                child: const Text('Cerrar'))),
          ),
        ]),
      ),
    );
  }
}

// ─── Dialog Ajuste ────────────────────────────────────────────────────────────
class _AjusteDialog extends StatefulWidget {
  final Map<String, dynamic> item;
  final InventarioServicio   servicio;
  final VoidCallback         onGuardado;
  const _AjusteDialog({required this.item, required this.servicio,
      required this.onGuardado});
  @override
  State<_AjusteDialog> createState() => _AjusteDialogState();
}

class _AjusteDialogState extends State<_AjusteDialog> {
  final _formKey      = GlobalKey<FormState>();
  final _cantidadCtrl = TextEditingController();
  final _notaCtrl     = TextEditingController();
  String _tipo        = 'entrada';
  bool   _cargando    = false;

  @override
  void dispose() {
    _cantidadCtrl.dispose();
    _notaCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _cargando = true);
    try {
      await widget.servicio.ajustar(widget.item['producto_id'] as int, {
        'tipo':     _tipo,
        'cantidad': double.tryParse(_cantidadCtrl.text) ?? 0,
        'nota':     _notaCtrl.text.trim(),
      });
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
    final stockActual = (widget.item['stock_actual'] as num).toDouble();
    final stockStr    = stockActual % 1 == 0
        ? stockActual.toStringAsFixed(0)
        : stockActual.toStringAsFixed(2);

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
                  colors: [Colors.orange, Color(0xFFe65100)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            child: Row(children: [
              const Icon(Icons.tune_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Expanded(child: Text(
                  'Ajustar Stock — ${widget.item['producto']}',
                  style: const TextStyle(color: Colors.white, fontSize: 16,
                      fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis)),
              IconButton(onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Form(key: _formKey, child: Column(children: [
              // Stock actual
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0))),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Stock actual:',
                        style: TextStyle(color: ColoresCarolina.grisMedio,
                            fontSize: 13)),
                    Text('$stockStr unidades',
                        style: const TextStyle(fontWeight: FontWeight.bold,
                            fontSize: 16, color: ColoresCarolina.celesteOscuro)),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Tipo
              const Text('Tipo de movimiento',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13,
                      color: ColoresCarolina.grisMedio)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _radioTipo('entrada', 'Entrada',
                    'Suma unidades', Icons.add_circle_rounded, Colors.green)),
                const SizedBox(width: 8),
                Expanded(child: _radioTipo('salida', 'Salida',
                    'Resta unidades', Icons.remove_circle_rounded,
                    ColoresCarolina.rojo)),
                const SizedBox(width: 8),
                Expanded(child: _radioTipo('ajuste', 'Fijar',
                    'Valor exacto', Icons.tune_rounded, Colors.orange)),
              ]),
              const SizedBox(height: 16),

              // Cantidad
              TextFormField(
                controller: _cantidadCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                decoration: InputDecoration(
                  labelText: _tipo == 'ajuste'
                      ? 'Nuevo stock total (unidades)'
                      : 'Cantidad (unidades)',
                  hintText: 'Ej: 50',
                  prefixIcon: const Icon(Icons.format_list_numbered_rounded,
                      color: ColoresCarolina.celeste),
                  suffixText: 'unid.',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                          color: ColoresCarolina.celeste, width: 2)),
                ),
                validator: (v) {
                  final n = double.tryParse(v ?? '');
                  if (n == null || n <= 0) return 'Ingresa un valor mayor a 0';
                  if (_tipo == 'salida' && n > stockActual) {
                    return 'No puede superar el stock actual ($stockStr)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Nota
              TextFormField(
                controller: _notaCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Motivo / Nota (opcional)',
                  prefixIcon: const Icon(Icons.note_outlined,
                      color: ColoresCarolina.celeste),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                          color: ColoresCarolina.celeste, width: 2)),
                ),
              ),
            ])),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Row(children: [
              Expanded(child: OutlinedButton(
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
              Expanded(flex: 2, child: ElevatedButton(
                onPressed: _cargando ? null : _guardar,
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
                child: _cargando
                    ? const SizedBox(height: 20, width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Confirmar Ajuste',
                        style: TextStyle(fontWeight: FontWeight.bold,
                            fontSize: 15)),
              )),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _radioTipo(String valor, String titulo, String sub,
      IconData icono, Color color) {
    final sel = _tipo == valor;
    return GestureDetector(
      onTap: () => setState(() => _tipo = valor),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: sel ? color.withValues(alpha: 0.1) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: sel ? color : Colors.grey.shade300,
                width: sel ? 2 : 1)),
        child: Column(children: [
          Icon(icono, color: sel ? color : ColoresCarolina.grisMedio, size: 20),
          const SizedBox(height: 4),
          Text(titulo, style: TextStyle(fontWeight: FontWeight.bold,
              fontSize: 12, color: sel ? color : Colors.black87)),
          Text(sub, style: const TextStyle(fontSize: 9,
              color: ColoresCarolina.grisMedio), textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

// ─── Dialog Mínimos ───────────────────────────────────────────────────────────
class _MinimosDialog extends StatefulWidget {
  final Map<String, dynamic> item;
  final InventarioServicio   servicio;
  final VoidCallback         onGuardado;
  const _MinimosDialog({required this.item, required this.servicio,
      required this.onGuardado});
  @override
  State<_MinimosDialog> createState() => _MinimosDialogState();
}

class _MinimosDialogState extends State<_MinimosDialog> {
  final _formKey    = GlobalKey<FormState>();
  final _minimoCtrl = TextEditingController();
  final _maximoCtrl = TextEditingController();
  bool  _cargando   = false;

  @override
  void initState() {
    super.initState();
    final m = (widget.item['stock_minimo'] as num).toDouble();
    _minimoCtrl.text = m % 1 == 0
        ? m.toStringAsFixed(0) : m.toStringAsFixed(2);
    final x = widget.item['stock_maximo'];
    if (x != null) {
      final xd = (x as num).toDouble();
      _maximoCtrl.text = xd % 1 == 0
          ? xd.toStringAsFixed(0) : xd.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _minimoCtrl.dispose();
    _maximoCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _cargando = true);
    try {
      final datos = <String, dynamic>{
        'stock_minimo': double.tryParse(_minimoCtrl.text) ?? 0,
        'stock_maximo': _maximoCtrl.text.trim().isNotEmpty
            ? double.tryParse(_maximoCtrl.text) : null,
      };
      await widget.servicio.actualizarMinimos(
          widget.item['producto_id'] as int, datos);
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.fromLTRB(22, 16, 12, 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [Colors.purple, Colors.purple.shade800],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20))),
            child: Row(children: [
              const Icon(Icons.settings_rounded,
                  color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Expanded(child: Text(
                  'Alertas — ${widget.item['producto']}',
                  style: const TextStyle(color: Colors.white, fontSize: 16,
                      fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis)),
              IconButton(onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Form(key: _formKey, child: Column(children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: Colors.purple.withValues(alpha: 0.2))),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.warning_amber_rounded,
                          size: 14, color: Colors.orange),
                      SizedBox(width: 6),
                      Expanded(child: Text(
                          'Stock mínimo: alerta naranja/roja al llegar a este nivel',
                          style: TextStyle(fontSize: 12))),
                    ]),
                    SizedBox(height: 4),
                    Row(children: [
                      Icon(Icons.arrow_upward_rounded,
                          size: 14, color: Colors.purple),
                      SizedBox(width: 6),
                      Expanded(child: Text(
                          'Stock máximo: alerta morada si hay demasiado (opcional)',
                          style: TextStyle(fontSize: 12))),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Mínimo
              TextFormField(
                controller: _minimoCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                decoration: InputDecoration(
                  labelText: 'Stock mínimo (unidades) *',
                  hintText: 'Ej: 10',
                  prefixIcon: const Icon(Icons.warning_amber_rounded,
                      color: Colors.orange),
                  suffixText: 'unid.',
                  helperText: 'Alerta cuando el stock baje a este nivel',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                          color: Colors.orange, width: 2)),
                ),
                validator: (v) {
                  final n = double.tryParse(v ?? '');
                  if (n == null || n < 0) {
                    return 'Ingresa 0 o más';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Máximo
              TextFormField(
                controller: _maximoCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                decoration: InputDecoration(
                  labelText: 'Stock máximo (unidades) — opcional',
                  hintText: 'Ej: 500',
                  prefixIcon: const Icon(Icons.arrow_upward_rounded,
                      color: Colors.purple),
                  suffixText: 'unid.',
                  helperText: 'Dejar vacío para no tener límite superior',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                          color: Colors.purple, width: 2)),
                ),
                validator: (v) {
                  final s = (v ?? '').trim();
                  if (s.isEmpty) return null;
                  final n = double.tryParse(s);
                  if (n == null || n < 0) return 'Valor inválido';
                  final min = double.tryParse(_minimoCtrl.text) ?? 0;
                  if (n < min) {
                    return 'Debe ser mayor al mínimo ($min)';
                  }
                  return null;
                },
              ),
            ])),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Row(children: [
              Expanded(child: OutlinedButton(
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
              Expanded(flex: 2, child: ElevatedButton(
                onPressed: _cargando ? null : _guardar,
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
                child: _cargando
                    ? const SizedBox(height: 20, width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Guardar Alertas',
                        style: TextStyle(fontWeight: FontWeight.bold,
                            fontSize: 15)),
              )),
            ]),
          ),
        ]),
      ),
    );
  }
}