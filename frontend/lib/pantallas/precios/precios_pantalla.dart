// carolina/frontend/lib/pantallas/precios/precios_pantalla.dart
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
class PreciosServicio {
  final _auth = AuthServicio();
  Future<Map<String, String>> get _h => _auth.obtenerHeaders();

  Future<List<dynamic>> listar() async {
    final res = await http.get(
        Uri.parse(ApiConfig.precios), headers: await _h);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Error al cargar precios');
  }

  Future<void> guardar(Map<String, dynamic> datos) async {
    final res = await http.post(
        Uri.parse('${ApiConfig.precios}/guardar'),
        headers: await _h, body: jsonEncode(datos));
    final data = jsonDecode(res.body);
    if (res.statusCode == 200) return;
    if (data['errores'] != null) {
      throw Exception(
          (data['errores'] as Map).values.first.toString());
    }
    throw Exception(data['error'] ?? 'Error al guardar precios');
  }

  Future<void> eliminarPrecio(int id) async {
    final res = await http.delete(
        Uri.parse('${ApiConfig.precios}/$id'), headers: await _h);
    if (res.statusCode != 200) {
      final data = jsonDecode(res.body);
      throw Exception(data['error'] ?? 'Error al eliminar');
    }
  }

  Future<List<dynamic>> listarProductos() async {
    final res = await http.get(
        Uri.parse(ApiConfig.productos), headers: await _h);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Error al cargar productos');
  }
}

// ─── Pantalla ─────────────────────────────────────────────────────────────────
class PreciosPantalla extends StatefulWidget {
  const PreciosPantalla({super.key});
  @override
  State<PreciosPantalla> createState() => _PreciosPantallaState();
}

class _PreciosPantallaState extends State<PreciosPantalla> {
  final _servicio = PreciosServicio();
  List<dynamic> _precios  = [];
  bool   _cargando        = true;
  String _busqueda        = '';
  String _filtro          = 'todos';

  @override
  void initState() { super.initState(); _cargar(); }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final p = await _servicio.listar();
      setState(() => _precios = p);
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
    return _precios.where((p) {
      if (_filtro == 'con_precios' &&
          (p['precio_venta'] == null || p['precio_compra'] == null)) {
        return false;
      }
      if (_filtro == 'sin_precio' &&
          p['precio_venta'] != null && p['precio_compra'] != null) {
        return false;
      }
      if (_busqueda.isEmpty) return true;
      final q = _busqueda.toLowerCase();
      return (p['producto']  ?? '').toLowerCase().contains(q) ||
             (p['categoria'] ?? '').toLowerCase().contains(q);
    }).toList();
  }

  int get _conAmbosPrecio => _precios.where((p) =>
      p['precio_venta'] != null && p['precio_compra'] != null).length;
  int get _sinPrecio => _precios.where((p) =>
      p['precio_venta'] == null || p['precio_compra'] == null).length;

  void _abrirFormulario({required Map<String, dynamic> item}) {
    showDialog(
      context: context, barrierDismissible: false,
      builder: (_) => _FormularioPrecio(
        item: item, servicio: _servicio,
        onGuardado: () {
          Navigator.pop(context);
          Notificacion.exito(context, 'Precios guardados');
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
          const Text('Gestión de Precios',
              style: TextStyle(fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: ColoresCarolina.celesteOscuro)),
          const SizedBox(height: 4),
          const Text('Define precios de compra y venta, y controla tu margen de ganancia',
              style: TextStyle(fontSize: 13, color: ColoresCarolina.grisMedio)),
          const SizedBox(height: 6),
          Row(children: [
            _chip('$_conAmbosPrecio con precios', Colors.green),
            const SizedBox(width: 6),
            if (_sinPrecio > 0)
              _chip('$_sinPrecio sin precio completo', Colors.orange),
          ]),
        ],
      )),
      IconButton(onPressed: _cargar,
          icon: const Icon(Icons.refresh_rounded),
          color: ColoresCarolina.celeste, tooltip: 'Actualizar'),
    ]),
  );

  Widget _buildBarra() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
    color: Colors.white,
    child: Row(children: [
      Expanded(child: TextField(
        onChanged: (v) => setState(() => _busqueda = v),
        decoration: InputDecoration(
          hintText: 'Buscar por producto o categoría...',
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
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      )),
      const SizedBox(width: 12),
      Container(
        decoration: BoxDecoration(color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _btnFiltro('Todos',       'todos',       Icons.list_rounded),
          _btnFiltro('Completos',   'con_precios', Icons.check_circle_rounded),
          _btnFiltro('Incompletos', 'sin_precio',  Icons.warning_amber_rounded),
        ]),
      ),
    ]),
  );

  Widget _btnFiltro(String label, String valor, IconData icono) {
    final sel = _filtro == valor;
    return GestureDetector(
      onTap: () => setState(() => _filtro = valor),
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
          Icon(Icons.price_change_outlined, size: 72,
              color: ColoresCarolina.grisMedio.withValues(alpha: 0.35)),
          const SizedBox(height: 14),
          Text(_busqueda.isNotEmpty
              ? 'No hay resultados para "$_busqueda"'
              : 'No hay productos registrados',
              style: const TextStyle(
                  color: ColoresCarolina.grisMedio, fontSize: 15)),
        ],
      ));
    }

    if (Breakpoints.esMovil(context)) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filtrados.length,
        itemBuilder: (_, i) => _TarjetaPrecioMovil(
          item: filtrados[i],
          onEditar: () => _abrirFormulario(item: filtrados[i]),
        ),
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
                _th('PRODUCTO',       4),
                _th('CATEGORÍA',      2),
                _th('P. COMPRA',      2),
                _th('P. VENTA',       2),
                _th('GANANCIA',       3),
                _th('ACCIONES',       2),
              ]),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            ...filtrados.asMap().entries.map((e) {
              final item = e.value;
              return Column(children: [
                _FilaPrecio(
                  item:    item,
                  impar:   e.key.isOdd,
                  onEditar: () => _abrirFormulario(item: item),
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
    decoration: BoxDecoration(color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20)),
    child: Text(t, style: TextStyle(fontSize: 11, color: c,
        fontWeight: FontWeight.w600)),
  );
}

// ─── Fila ─────────────────────────────────────────────────────────────────────
class _FilaPrecio extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool impar;
  final VoidCallback onEditar;

  const _FilaPrecio({
    required this.item,
    required this.impar,
    required this.onEditar,
  });

  @override
  Widget build(BuildContext context) {
    final pv = item['precio_venta']  as double?;
    final pc = item['precio_compra'] as double?;
    final ganancia    = item['ganancia']     as double?;
    final gananciaPct = item['ganancia_pct'] as double?;

    final tieneAmbos = pv != null && pc != null;
    final colorGanancia = ganancia != null && ganancia > 0
        ? Colors.green : Colors.red;

    return Container(
      color: impar ? const Color(0xFFFAFBFF) : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(children: [
        // Producto
        Expanded(flex: 4, child: Text(item['producto'] ?? '-',
            style: const TextStyle(fontWeight: FontWeight.w600,
                fontSize: 13),
            overflow: TextOverflow.ellipsis)),
        // Categoría
        Expanded(flex: 2, child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
              color: ColoresCarolina.celeste.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20)),
          child: Text(item['categoria'] ?? '-',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11,
                  color: ColoresCarolina.celeste,
                  fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis),
        )),
        // Precio compra
        Expanded(flex: 2, child: pc != null
            ? Text('Bs ${pc.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 13,
                    color: Colors.orange,
                    fontWeight: FontWeight.w600))
            : _sinPrecio()),
        // Precio venta
        Expanded(flex: 2, child: pv != null
            ? Text('Bs ${pv.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 13,
                    color: Colors.green,
                    fontWeight: FontWeight.w600))
            : _sinPrecio()),
        // Ganancia
        Expanded(flex: 3, child: tieneAmbos && ganancia != null
            ? Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Bs ${ganancia.toStringAsFixed(2)}',
                      style: TextStyle(fontWeight: FontWeight.bold,
                          fontSize: 13, color: colorGanancia)),
                  if (gananciaPct != null)
                    Text('${gananciaPct.toStringAsFixed(1)}% margen',
                        style: TextStyle(fontSize: 10,
                            color: colorGanancia)),
                ])
            : const Text('—', style: TextStyle(
                color: ColoresCarolina.grisMedio))),
        // Acciones
        Expanded(flex: 2, child: Tooltip(
          message: 'Editar precios',
          child: InkWell(
            onTap: onEditar,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                  color: ColoresCarolina.celeste.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.edit_rounded,
                  size: 16, color: ColoresCarolina.celeste)),
          ),
        )),
      ]),
    );
  }

  Widget _sinPrecio() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20)),
    child: const Text('Sin precio',
        style: TextStyle(fontSize: 10, color: Colors.orange,
            fontWeight: FontWeight.w600)),
  );
}

// ─── Tarjeta para pantallas angostas (celular) ─────────────────────────────────
class _TarjetaPrecioMovil extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onEditar;

  const _TarjetaPrecioMovil({
    required this.item,
    required this.onEditar,
  });

  @override
  Widget build(BuildContext context) {
    final pv = item['precio_venta']  as double?;
    final pc = item['precio_compra'] as double?;
    final ganancia    = item['ganancia']     as double?;
    final gananciaPct = item['ganancia_pct'] as double?;

    final tieneAmbos = pv != null && pc != null;
    final colorGanancia = ganancia != null && ganancia > 0
        ? Colors.green : Colors.red;

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
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: ColoresCarolina.celeste.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.price_change_rounded,
                  color: ColoresCarolina.celeste, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(item['producto'] ?? '-',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 15),
                  overflow: TextOverflow.ellipsis),
            ),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: ColoresCarolina.celeste.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20)),
              child: Text(item['categoria'] ?? '-',
                  style: const TextStyle(fontSize: 11,
                      color: ColoresCarolina.celeste,
                      fontWeight: FontWeight.w600)),
            ),
            if (pc != null)
              _etiquetaValor('Compra', 'Bs ${pc.toStringAsFixed(2)}', Colors.orange)
            else
              _sinPrecio(),
            if (pv != null)
              _etiquetaValor('Venta', 'Bs ${pv.toStringAsFixed(2)}', Colors.green)
            else
              _sinPrecio(),
          ]),
          const SizedBox(height: 10),
          if (tieneAmbos && ganancia != null)
            Row(children: [
              Icon(ganancia > 0
                  ? Icons.trending_up_rounded
                  : Icons.trending_down_rounded,
                  size: 16, color: colorGanancia),
              const SizedBox(width: 6),
              Text('Ganancia: Bs ${ganancia.toStringAsFixed(2)}',
                  style: TextStyle(fontWeight: FontWeight.bold,
                      fontSize: 13, color: colorGanancia)),
              if (gananciaPct != null) ...[
                const SizedBox(width: 6),
                Text('(${gananciaPct.toStringAsFixed(1)}% margen)',
                    style: TextStyle(fontSize: 11, color: colorGanancia)),
              ],
            ])
          else
            const Text('— Sin datos de ganancia',
                style: TextStyle(color: ColoresCarolina.grisMedio, fontSize: 12)),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            Tooltip(
              message: 'Editar precios',
              child: InkWell(
                onTap: onEditar,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: ColoresCarolina.celeste.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.edit_rounded,
                      size: 18, color: ColoresCarolina.celeste),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _etiquetaValor(String etiqueta, String valor, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20)),
    child: Text('$etiqueta: $valor',
        style: TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.w600)),
  );

  Widget _sinPrecio() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20)),
    child: const Text('Sin precio',
        style: TextStyle(fontSize: 10, color: Colors.orange,
            fontWeight: FontWeight.w600)),
  );
}

// ─── Formulario ───────────────────────────────────────────────────────────────
class _FormularioPrecio extends StatefulWidget {
  final Map<String, dynamic> item;
  final PreciosServicio       servicio;
  final VoidCallback          onGuardado;
  const _FormularioPrecio({
    required this.item,
    required this.servicio,
    required this.onGuardado,
  });
  @override
  State<_FormularioPrecio> createState() => _FormularioPrecioState();
}

class _FormularioPrecioState extends State<_FormularioPrecio> {
  final _formKey     = GlobalKey<FormState>();
  final _ventaCtrl   = TextEditingController();
  bool  _cargando    = false;

  double? get _precioCompraRef => widget.item['precio_compra'] as double?;
  String? get _proveedorRef =>
      widget.item['precio_compra_proveedor'] as String?;

  @override
  void initState() {
    super.initState();
    final pv = widget.item['precio_venta'] as double?;
    if (pv != null) _ventaCtrl.text = pv.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _ventaCtrl.dispose();
    super.dispose();
  }

  // Calcula ganancia en tiempo real contra el último precio de compra
  // real (registrado desde Compras) — no se edita aquí.
  double? get _ganancia {
    final pv = double.tryParse(_ventaCtrl.text);
    final pc = _precioCompraRef;
    if (pv == null || pc == null) return null;
    return pv - pc;
  }

  double? get _gananciaPct {
    final g  = _ganancia;
    final pc = _precioCompraRef;
    if (g == null || pc == null || pc == 0) return null;
    return (g / pc) * 100;
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _cargando = true);

    final datos = <String, dynamic>{
      'producto_id': widget.item['producto_id'],
      'precio_venta': double.tryParse(_ventaCtrl.text),
    };

    try {
      await widget.servicio.guardar(datos);
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
    final ganancia    = _ganancia;
    final gananciaPct = _gananciaPct;
    final colorG = ganancia != null && ganancia > 0
        ? Colors.green : Colors.red;

    return Dialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
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
              const Icon(Icons.price_change_rounded,
                  color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Expanded(child: Text(
                  'Precios — ${widget.item['producto']}',
                  style: const TextStyle(color: Colors.white,
                      fontSize: 16, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis)),
              IconButton(
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Cerrar',
                  icon: const Icon(Icons.close, color: Colors.white)),
            ]),
          ),

          // Body
          Padding(
            padding: const EdgeInsets.all(24),
            child: Form(key: _formKey, child: Column(children: [
              // Precio de compra: solo lectura, viene de Compras reales
              _PanelPreciosCompra(
                precioReferencia: _precioCompraRef,
                proveedorReferencia: _proveedorRef,
                preciosCompra:
                    widget.item['precios_compra'] as List? ?? const [],
              ),
              const SizedBox(height: 16),

              // Precio de venta
              TextFormField(
                controller: _ventaCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d*')),
                ],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Precio de venta (Bs)',
                  hintText: 'Ej: 8.50',
                  prefixIcon: const Icon(Icons.sell_rounded,
                      color: Colors.green),
                  prefixText: 'Bs ',
                  helperText:
                      'Precio para todos los clientes. '
                      'Se puede ajustar en la venta si es necesario.',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                          color: Colors.green, width: 2)),
                ),
                validator: (v) {
                  final s = (v ?? '').trim();
                  if (s.isEmpty) return 'El precio de venta es requerido';
                  final n = double.tryParse(s);
                  if (n == null || n <= 0) {
                    return 'Debe ser mayor a 0';
                  }
                  final pc = _precioCompraRef;
                  if (pc != null && n < pc) {
                    return 'El precio de venta no puede ser menor al de compra';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Calculadora de ganancia en tiempo real
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: ganancia != null
                        ? colorG.withValues(alpha: 0.07)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: ganancia != null
                            ? colorG.withValues(alpha: 0.3)
                            : const Color(0xFFE2E8F0))),
                child: ganancia != null
                    ? Row(children: [
                        Icon(ganancia > 0
                            ? Icons.trending_up_rounded
                            : Icons.trending_down_rounded,
                            color: colorG, size: 28),
                        const SizedBox(width: 14),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Ganancia por unidad',
                                style: TextStyle(fontSize: 11,
                                    color: ColoresCarolina.grisMedio)),
                            Row(children: [
                              Text(
                                'Bs ${ganancia.toStringAsFixed(2)}',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 22, color: colorG),
                              ),
                              if (gananciaPct != null) ...[
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(
                                      color: colorG.withValues(alpha: 0.1),
                                      borderRadius:
                                          BorderRadius.circular(20)),
                                  child: Text(
                                    '${gananciaPct.toStringAsFixed(1)}% margen',
                                    style: TextStyle(fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: colorG),
                                  ),
                                ),
                              ],
                            ]),
                          ],
                        )),
                      ])
                    : const Row(children: [
                        Icon(Icons.calculate_outlined,
                            color: ColoresCarolina.grisMedio, size: 22),
                        SizedBox(width: 10),
                        Text('Ingresa ambos precios para ver la ganancia',
                            style: TextStyle(fontSize: 12,
                                color: ColoresCarolina.grisMedio)),
                      ]),
              ),
            ])),
          ),

          // Footer
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
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
                    backgroundColor: ColoresCarolina.celeste,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
                child: _cargando
                    ? const SizedBox(height: 20, width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Guardar Precios',
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

// ─── Panel de precios de compra (solo lectura, viene de Compras) ──────────────
class _PanelPreciosCompra extends StatelessWidget {
  final double? precioReferencia;
  final String? proveedorReferencia;
  final List preciosCompra;

  const _PanelPreciosCompra({
    required this.precioReferencia,
    required this.proveedorReferencia,
    required this.preciosCompra,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.shopping_cart_rounded,
              color: Colors.orange, size: 18),
          const SizedBox(width: 8),
          const Text('Precio de compra',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.orange)),
          const Spacer(),
          Text(
              precioReferencia != null
                  ? 'Bs ${precioReferencia!.toStringAsFixed(2)}'
                  : 'Sin compras aún',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: precioReferencia != null
                      ? Colors.orange.shade800
                      : ColoresCarolina.grisMedio)),
        ]),
        const SizedBox(height: 4),
        Text(
            precioReferencia != null
                ? 'Último precio pagado'
                    '${proveedorReferencia != null ? " a $proveedorReferencia" : ""}. '
                    'Se registra solo al hacer una Compra, no se edita aquí.'
                : 'Este precio se completa automáticamente cuando registres '
                    'una Compra de este producto.',
            style: const TextStyle(
                fontSize: 11, color: ColoresCarolina.grisMedio)),
        if (preciosCompra.length > 1) ...[
          const Divider(height: 16),
          const Text('Por proveedor:',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          ...preciosCompra.map((p) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(children: [
                  Expanded(
                      child: Text(p['proveedor'] ?? 'Sin proveedor',
                          style: const TextStyle(fontSize: 12))),
                  Text('Bs ${(p['precio'] as num).toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              )),
        ],
      ]),
    );
  }
}