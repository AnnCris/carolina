// carolina/frontend/lib/pantallas/productos/productos_pantalla.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../../constantes/colores.dart';
import '../../constantes/api.dart';
import '../../servicios/auth_servicio.dart';
import '../../widgets/notificacion.dart';

class ProductosServicio {
  final _auth = AuthServicio();
  Future<Map<String, String>> get _h => _auth.obtenerHeaders();

  Future<List<dynamic>> listar() async {
    final res = await http.get(Uri.parse(ApiConfig.productos), headers: await _h);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Error al cargar productos');
  }

  Future<List<dynamic>> listarCategorias() async {
    final res = await http.get(Uri.parse(ApiConfig.categorias), headers: await _h);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Error al cargar categorías');
  }

  Future<List<dynamic>> listarMarcas() async {
    final res = await http.get(Uri.parse(ApiConfig.marcas), headers: await _h);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Error al cargar marcas');
  }

  Future<Map<String, dynamic>> crear(Map<String, dynamic> datos) async {
    final res = await http.post(Uri.parse(ApiConfig.productos),
        headers: await _h, body: jsonEncode(datos));
    final data = jsonDecode(res.body);
    if (res.statusCode == 201) return data;
    if (data['errores'] != null) throw Exception((data['errores'] as Map).values.first.toString());
    throw Exception(data['error'] ?? 'Error al crear');
  }

  Future<Map<String, dynamic>> actualizar(int id, Map<String, dynamic> datos) async {
    final res = await http.put(Uri.parse('${ApiConfig.productos}/$id'),
        headers: await _h, body: jsonEncode(datos));
    final data = jsonDecode(res.body);
    if (res.statusCode == 200) return data;
    if (data['errores'] != null) throw Exception((data['errores'] as Map).values.first.toString());
    throw Exception(data['error'] ?? 'Error al actualizar');
  }

  Future<void> eliminar(int id) async {
    final res = await http.delete(Uri.parse('${ApiConfig.productos}/$id'), headers: await _h);
    if (res.statusCode != 200) throw Exception('Error al eliminar');
  }

  Future<void> subirFoto(int id, XFile foto) async {
    final uri = Uri.parse('${ApiConfig.productos}/$id/foto');
    final request = http.MultipartRequest('POST', uri);
    final headers = await _h;
    headers.forEach((k, v) { if (k != 'Content-Type') request.headers[k] = v; });
    final bytes = await foto.readAsBytes();
    request.files.add(http.MultipartFile.fromBytes('foto', bytes,
        filename: foto.name.isNotEmpty ? foto.name : 'foto.jpg'));
    final res = await request.send();
    if (res.statusCode != 200) throw Exception('Error al subir foto');
  }

  Future<Map<String, dynamic>> crearCategoria(String nombre, String? desc) async {
    final res = await http.post(Uri.parse(ApiConfig.categorias),
        headers: await _h, body: jsonEncode({'nombre': nombre, 'descripcion': desc}));
    final data = jsonDecode(res.body);
    if (res.statusCode == 201) return data;
    throw Exception(data['error'] ?? 'Error al crear categoría');
  }

  Future<Map<String, dynamic>> crearMarca(String nombre, String? desc) async {
    final res = await http.post(Uri.parse(ApiConfig.marcas),
        headers: await _h, body: jsonEncode({'nombre': nombre, 'descripcion': desc}));
    final data = jsonDecode(res.body);
    if (res.statusCode == 201) return data;
    throw Exception(data['error'] ?? 'Error al crear marca');
  }
}

// ─── Pantalla principal ───────────────────────────────────────────────────────
class ProductosPantalla extends StatefulWidget {
  const ProductosPantalla({super.key});
  @override
  State<ProductosPantalla> createState() => _ProductosPantallaState();
}

class _ProductosPantallaState extends State<ProductosPantalla> {
  final _servicio   = ProductosServicio();
  List<dynamic> _productos  = [];
  List<dynamic> _categorias = [];
  List<dynamic> _marcas     = [];
  bool   _cargando          = true;
  String _busqueda          = '';
  String _filtroEstado      = 'todos';
  String _filtroCategoria   = 'todas';

  @override
  void initState() { super.initState(); _cargar(); }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final p = await _servicio.listar();
      final c = await _servicio.listarCategorias();
      final m = await _servicio.listarMarcas();
      setState(() { _productos = p; _categorias = c; _marcas = m; });
    } catch (e) {
      if (mounted) Notificacion.error(context, e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  List<dynamic> get _filtrados {
    return _productos.where((p) {
      final activo = p['activo'] as bool? ?? false;
      if (_filtroEstado == 'activos'   && !activo) return false;
      if (_filtroEstado == 'inactivos' &&  activo) return false;
      if (_filtroCategoria != 'todas' && (p['categoria'] ?? '') != _filtroCategoria) {
        return false;
      }
      if (_busqueda.isEmpty) return true;
      final q = _busqueda.toLowerCase();
      return (p['nombre'] ?? '').toLowerCase().contains(q) ||
             (p['categoria'] ?? '').toLowerCase().contains(q) ||
             (p['marca'] ?? '').toLowerCase().contains(q) ||
             (p['codigo_barras'] ?? '').toLowerCase().contains(q);
    }).toList();
  }

  int get _totalActivos   => _productos.where((p) => p['activo'] == true).length;
  int get _totalInactivos => _productos.where((p) => p['activo'] == false).length;

  static String urlFoto(String foto) => '${ApiConfig.baseUrl.replaceAll('/api', '')}$foto';

  Future<bool> _confirmar({required String titulo, required String mensaje,
      required String labelBtn, required Color colorBtn, required IconData icono}) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Container(padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: colorBtn.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(icono, color: colorBtn, size: 22)),
          const SizedBox(width: 12),
          Expanded(child: Text(titulo, style: const TextStyle(fontSize: 16))),
        ]),
        content: Text(mensaje),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: colorBtn,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              child: Text(labelBtn)),
        ],
      ),
    );
    return r ?? false;
  }

  Future<void> _cambiarEstado(Map<String, dynamic> p) async {
    final activo = p['activo'] as bool? ?? false;
    final ok = await _confirmar(
      titulo: activo ? 'Desactivar producto' : 'Activar producto',
      mensaje: '¿Confirmas ${activo ? "desactivar" : "activar"} "${p['nombre']}"?',
      labelBtn: activo ? 'Sí, desactivar' : 'Sí, activar',
      colorBtn: activo ? Colors.amber.shade700 : Colors.green,
      icono: activo ? Icons.inventory_2_rounded : Icons.check_circle_rounded,
    );
    if (ok && mounted) {
      try {
        await _servicio.actualizar(p['id'], {'activo': !activo});
        if (mounted) { Notificacion.exito(context, 'Estado actualizado'); _cargar(); }
      } catch (e) {
        if (mounted) Notificacion.error(context, e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  Future<void> _eliminar(Map<String, dynamic> p) async {
    final ok = await _confirmar(
      titulo: 'Eliminar producto',
      mensaje: '⚠️ Se eliminará PERMANENTEMENTE "${p['nombre']}".\n\nEsta acción NO se puede deshacer.',
      labelBtn: 'Sí, eliminar',
      colorBtn: ColoresCarolina.rojo,
      icono: Icons.delete_forever_rounded,
    );
    if (ok && mounted) {
      try {
        await _servicio.eliminar(p['id']);
        if (mounted) { Notificacion.exito(context, 'Producto eliminado'); _cargar(); }
      } catch (e) {
        if (mounted) Notificacion.error(context, e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  void _verDetalle(Map<String, dynamic> p) =>
      showDialog(context: context, builder: (_) => _DetalleProducto(producto: p));

  void _abrirFormulario({Map<String, dynamic>? producto}) {
  showDialog(
    context: context, barrierDismissible: false,
    builder: (_) => _FormularioProducto(
      producto: producto, categorias: _categorias, marcas: _marcas,
      servicio: _servicio,
      onGuardado: () {
        Navigator.pop(context);
        Notificacion.exito(context, producto == null ? 'Producto creado' : 'Producto actualizado');
        _cargar();
      },
      onNuevaCategoria: () async { await _cargar(); },  // ✅ Ahora retorna Future
      onNuevaMarca: () async { await _cargar(); },      // ✅ Ahora retorna Future
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _buildHeader(), _buildBarra(), Expanded(child: _buildCuerpo(_filtrados)),
    ]);
  }

  Widget _buildHeader() => Container(
    padding: const EdgeInsets.fromLTRB(28, 22, 28, 18),
    decoration: const BoxDecoration(color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0)))),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Gestión de Productos', style: TextStyle(fontSize: 24,
            fontWeight: FontWeight.bold, color: ColoresCarolina.celesteOscuro)),
        const SizedBox(height: 6),
        Row(children: [
          _chip('${_productos.length} total', ColoresCarolina.celeste),
          const SizedBox(width: 6),
          _chip('$_totalActivos activos', Colors.green),
          const SizedBox(width: 6),
          _chip('$_totalInactivos inactivos', Colors.grey),
        ]),
      ])),
      ElevatedButton.icon(
        onPressed: () => _abrirFormulario(),
        icon: const Icon(Icons.add_rounded, size: 18),
        label: const Text('Nuevo Producto'),
        style: ElevatedButton.styleFrom(backgroundColor: ColoresCarolina.celeste,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
      ),
    ]),
  );

  Widget _buildBarra() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
    color: Colors.white,
    child: Row(children: [
      Expanded(child: TextField(
        onChanged: (v) => setState(() => _busqueda = v),
        decoration: InputDecoration(
          hintText: 'Buscar por nombre, categoría, marca o código...',
          prefixIcon: const Icon(Icons.search_rounded, color: ColoresCarolina.celeste),
          suffixIcon: _busqueda.isNotEmpty
              ? IconButton(icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: () => setState(() => _busqueda = '')) : null,
          filled: true, fillColor: const Color(0xFFF1F5F9),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: ColoresCarolina.celeste, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      )),
      const SizedBox(width: 12),
      if (_categorias.isNotEmpty)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10)),
          child: DropdownButtonHideUnderline(child: DropdownButton<String>(
            value: _filtroCategoria,
            items: [
              const DropdownMenuItem(value: 'todas', child: Text('Todas las categorías')),
              ..._categorias.map<DropdownMenuItem<String>>((c) =>
                  DropdownMenuItem(value: c['nombre'] as String, child: Text(c['nombre'] as String))),
            ],
            onChanged: (v) => setState(() => _filtroCategoria = v ?? 'todas'),
          )),
        ),
      const SizedBox(width: 8),
      Container(
        decoration: BoxDecoration(color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _btnFiltro('Todos', 'todos', Icons.category_rounded),
          _btnFiltro('Activos', 'activos', Icons.check_circle_rounded),
          _btnFiltro('Inactivos', 'inactivos', Icons.cancel_rounded),
        ]),
      ),
      const SizedBox(width: 8),
      IconButton(onPressed: _cargar, icon: const Icon(Icons.refresh_rounded),
          color: ColoresCarolina.celeste, tooltip: 'Actualizar'),
    ]),
  );

  Widget _btnFiltro(String label, String valor, IconData icono) {
    final sel = _filtroEstado == valor;
    return GestureDetector(
      onTap: () => setState(() => _filtroEstado = valor),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
            color: sel ? ColoresCarolina.celeste : Colors.transparent,
            borderRadius: BorderRadius.circular(9)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icono, size: 14, color: sel ? Colors.white : ColoresCarolina.grisMedio),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 12,
              fontWeight: sel ? FontWeight.bold : FontWeight.normal,
              color: sel ? Colors.white : ColoresCarolina.grisMedio)),
        ]),
      ),
    );
  }

  Widget _buildCuerpo(List<dynamic> filtrados) {
    if (_cargando) return const Center(child: CircularProgressIndicator(color: ColoresCarolina.celeste));
    if (filtrados.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.inventory_2_outlined, size: 72,
            color: ColoresCarolina.grisMedio.withValues(alpha: 0.35)),
        const SizedBox(height: 14),
        Text(_busqueda.isNotEmpty ? 'No hay resultados para "$_busqueda"'
            : _filtroEstado == 'inactivos' ? 'No hay productos inactivos'
            : 'No hay productos registrados',
            style: const TextStyle(color: ColoresCarolina.grisMedio, fontSize: 15)),
      ]));
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
                _th('PRODUCTO', 5), _th('CATEGORÍA', 2), _th('PESO/UNIDAD', 2),
                _th('STOCK', 2), _th('ESTADO', 2), _th('ACCIONES', 3),
              ]),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            ...filtrados.asMap().entries.map((e) {
              final p = e.value;
              return Column(children: [
                _FilaProducto(producto: p, impar: e.key.isOdd,
                    onVer: () => _verDetalle(p), onEditar: () => _abrirFormulario(producto: p),
                    onEstado: () => _cambiarEstado(p), onEliminar: () => _eliminar(p)),
                if (e.key < filtrados.length - 1) const Divider(height: 1, color: Color(0xFFE2E8F0)),
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

// ─── Fila ─────────────────────────────────────────────────────────────────────
class _FilaProducto extends StatelessWidget {
  final Map<String, dynamic> producto;
  final bool impar;
  final VoidCallback onVer, onEditar, onEstado, onEliminar;

  const _FilaProducto({required this.producto, required this.impar,
      required this.onVer, required this.onEditar,
      required this.onEstado, required this.onEliminar});

  ImageProvider? get _img {
    final f = producto['foto'] as String?;
    if (f == null || f.isEmpty) return null;
    return NetworkImage(_ProductosPantallaState.urlFoto(f));
  }

  String get _pesoLabel {
    final tipo   = producto['tipo_peso'] as String? ?? 'fijo';
    final peso   = producto['peso_gramos'];
    final unidad = producto['unidad']    as String? ?? 'gr';
    if (tipo == 'variable') return 'Variable (kg)';
    if (peso == null) return unidad;
    final g = double.tryParse(peso.toString()) ?? 0;
    if (unidad == 'kg') return '${g.toStringAsFixed(2)} kg';
    if (g >= 1000) return '${(g / 1000).toStringAsFixed(2)} kg';
    return '${g.toStringAsFixed(0)} gr';
  }

  @override
  Widget build(BuildContext context) {
    final activo  = producto['activo'] as bool? ?? false;
    final stock   = double.tryParse((producto['stock'] ?? 0).toString()) ?? 0;
    final imgProv = _img;
    return Container(
      color: impar ? const Color(0xFFFAFBFF) : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(children: [
        Expanded(flex: 5, child: Row(children: [
          Container(width: 44, height: 44,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8),
                color: ColoresCarolina.grisClaro),
            child: ClipRRect(borderRadius: BorderRadius.circular(8),
              child: imgProv != null
                  ? Image(image: imgProv, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.inventory_2_outlined,
                          color: ColoresCarolina.celeste, size: 22))
                  : const Icon(Icons.inventory_2_outlined, color: ColoresCarolina.celeste, size: 22),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(producto['nombre'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                overflow: TextOverflow.ellipsis),
            if (producto['marca'] != null)
              Text(producto['marca'], style: const TextStyle(fontSize: 11, color: ColoresCarolina.grisMedio)),
            if (producto['codigo_barras'] != null)
              Text('Cód: ${producto['codigo_barras']}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ])),
        ])),
        Expanded(flex: 2, child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: ColoresCarolina.celeste.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20)),
          child: Text(producto['categoria'] ?? '-', textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: ColoresCarolina.celeste,
                  fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
        )),
        Expanded(flex: 2, child: Text(_pesoLabel,
            style: const TextStyle(fontSize: 13, color: Color(0xFF475569)))),
        Expanded(flex: 2, child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (stock <= 5) const Padding(padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.warning_amber_rounded, size: 14, color: Colors.orange)),
          Text(stock % 1 == 0 ? stock.toStringAsFixed(0) : stock.toStringAsFixed(2),
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                  color: stock <= 5 ? Colors.orange : const Color(0xFF475569))),
        ])),
        Expanded(flex: 2, child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle,
              color: activo ? Colors.green : Colors.grey)),
          const SizedBox(width: 6),
          Text(activo ? 'Activo' : 'Inactivo', style: TextStyle(fontSize: 13,
              fontWeight: FontWeight.w600, color: activo ? Colors.green : Colors.grey)),
        ])),
        Expanded(flex: 3, child: Row(mainAxisSize: MainAxisSize.min, children: [
          _btn(Icons.visibility_rounded, ColoresCarolina.celeste, 'Ver', onVer),
          const SizedBox(width: 4),
          _btn(Icons.edit_rounded, Colors.orange, 'Editar', onEditar),
          const SizedBox(width: 4),
          _btn(activo ? Icons.inventory_2_rounded : Icons.check_circle_rounded,
              activo ? Colors.amber.shade700 : Colors.green,
              activo ? 'Desactivar' : 'Activar', onEstado),
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
          child: Icon(i, size: 16, color: c))),
  );
}

// ─── Detalle ──────────────────────────────────────────────────────────────────
class _DetalleProducto extends StatelessWidget {
  final Map<String, dynamic> producto;
  const _DetalleProducto({required this.producto});

  ImageProvider? get _img {
    final f = producto['foto'] as String?;
    if (f == null || f.isEmpty) return null;
    return NetworkImage(_ProductosPantallaState.urlFoto(f));
  }

  String get _pesoLabel {
    final tipo   = producto['tipo_peso'] as String? ?? 'fijo';
    final peso   = producto['peso_gramos'];
    final unidad = producto['unidad']    as String? ?? 'gr';
    if (tipo == 'variable') return 'Peso variable (se pesa al vender)';
    if (peso == null) return unidad;
    final g = double.tryParse(peso.toString()) ?? 0;
    if (unidad == 'kg') return '${g.toStringAsFixed(3)} kg';
    if (g >= 1000) return '${(g / 1000).toStringAsFixed(3)} kg (${g.toStringAsFixed(0)} gr)';
    return '${g.toStringAsFixed(0)} gramos';
  }

  @override
  Widget build(BuildContext context) {
    final activo  = producto['activo'] as bool? ?? false;
    final stock   = double.tryParse((producto['stock'] ?? 0).toString()) ?? 0;
    final imgProv = _img;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [ColoresCarolina.celeste, ColoresCarolina.celesteOscuro],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            child: Column(children: [
              const SizedBox(height: 20),
              Container(width: 90, height: 90,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(16),
                    color: Colors.white.withValues(alpha: 0.2),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 10)]),
                child: ClipRRect(borderRadius: BorderRadius.circular(16),
                  child: imgProv != null
                      ? Image(image: imgProv, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.inventory_2_rounded, color: Colors.white, size: 48))
                      : const Icon(Icons.inventory_2_rounded, color: Colors.white, size: 48),
                ),
              ),
              const SizedBox(height: 14),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(producto['nombre'] ?? '', textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))),
              const SizedBox(height: 6),
              if (producto['marca'] != null)
                Text(producto['marca'], style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
              const SizedBox(height: 16),
            ]),
          ),
          Flexible(child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              Row(children: [
                Expanded(child: _stat('Stock actual',
                    '${stock % 1 == 0 ? stock.toStringAsFixed(0) : stock.toStringAsFixed(2)} ${producto['unidad'] ?? ''}',
                    Icons.inventory_rounded, Colors.green)),
                const SizedBox(width: 12),
                Expanded(child: _stat('Estado', activo ? 'Activo' : 'Inactivo',
                    activo ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    activo ? Colors.green : Colors.grey)),
              ]),
              const SizedBox(height: 16),
              _fila(Icons.category_outlined,    'Categoría',   producto['categoria']     ?? '-'),
              _fila(Icons.branding_watermark,   'Marca',       producto['marca']         ?? '-'),
              _fila(Icons.scale_rounded,        'Peso/Unidad', _pesoLabel),
              _fila(Icons.qr_code_rounded,      'Cód. barras', producto['codigo_barras'] ?? '-'),
              if ((producto['descripcion'] ?? '').toString().isNotEmpty)
                _fila(Icons.description_outlined, 'Descripción', producto['descripcion']),
            ]),
          )),
          Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: SizedBox(width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: ColoresCarolina.celeste,
                    foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                child: const Text('Cerrar', style: TextStyle(fontWeight: FontWeight.bold))))),
        ]),
      ),
    );
  }

  Widget _stat(String label, String valor, IconData icono, Color color) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.2))),
    child: Row(children: [
      Icon(icono, color: color, size: 22), const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, color: ColoresCarolina.grisMedio)),
        Text(valor, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
      ])),
    ]),
  );

  Widget _fila(IconData i, String l, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(children: [
      Icon(i, size: 18, color: ColoresCarolina.celeste), const SizedBox(width: 12),
      SizedBox(width: 110, child: Text(l, style: const TextStyle(color: ColoresCarolina.grisMedio, fontSize: 13))),
      Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          overflow: TextOverflow.ellipsis)),
    ]),
  );
}

// ─── Formulario ───────────────────────────────────────────────────────────────
class _FormularioProducto extends StatefulWidget {
  final Map<String, dynamic>? producto;
  final List<dynamic> categorias, marcas;
  final ProductosServicio servicio;
  final VoidCallback onGuardado;
  final Future<void> Function() onNuevaCategoria;  
  final Future<void> Function() onNuevaMarca;

  const _FormularioProducto({this.producto, required this.categorias, required this.marcas,
      required this.servicio, required this.onGuardado,
      required this.onNuevaCategoria, required this.onNuevaMarca});

  @override
  State<_FormularioProducto> createState() => _FormularioProductoState();
}

class _FormularioProductoState extends State<_FormularioProducto> {
  final _formKey      = GlobalKey<FormState>();
  final _nombreCtrl   = TextEditingController();
  final _descCtrl     = TextEditingController();
  final _codigoCtrl   = TextEditingController();
  final _pesoCtrl     = TextEditingController();
  final _stockMinCtrl = TextEditingController();

  int?             _categoriaId;
  int?             _marcaId;
  late List<dynamic> _categoriasLocal;
  late List<dynamic> _marcasLocal;
  String     _tipoPeso = 'fijo';
  String     _unidad   = 'gr';
  bool       _activo   = true;
  bool       _cargando = false;
  Uint8List? _fotoBytes;
  XFile?     _fotoFile;

  bool get _esEdicion => widget.producto != null;

  final List<Map<String, String>> _unidades = [
    {'valor': 'gr', 'label': 'Gramos (gr)'},
    {'valor': 'kg', 'label': 'Kilogramos (kg)'},
  ];

  final List<Map<String, String>> _pesosPredefinidos = [
    {'valor': '160',  'label': '160 gr'},
    {'valor': '400',  'label': '400 gr'},
    {'valor': '420',  'label': '420 gr'},
    {'valor': '500',  'label': '500 gr'},
    {'valor': '1000', 'label': '1 kg'},
    {'valor': '3500', 'label': '3.5 kg'},
  ];

  @override
  void initState() {
    super.initState();
    // Copiar listas localmente para poder agregar sin afectar el padre
    _categoriasLocal = List.from(widget.categorias);
    _marcasLocal     = List.from(widget.marcas);

    if (_esEdicion) {
      final p = widget.producto!;
      _nombreCtrl.text  = p['nombre']        ?? '';
      _descCtrl.text    = p['descripcion']   ?? '';
      _codigoCtrl.text  = p['codigo_barras'] ?? '';
      _tipoPeso         = p['tipo_peso']     ?? 'fijo';
      _unidad           = p['unidad']        ?? 'gr';
      _activo           = p['activo']        ?? true;
      _categoriaId      = p['categoria_id']  as int?;
      _marcaId          = p['marca_id']      as int?;
      if (p['peso_gramos'] != null) {
        _pesoCtrl.text = p['peso_gramos'].toString();
      }
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descCtrl.dispose();
    _codigoCtrl.dispose();
    _pesoCtrl.dispose();
    _stockMinCtrl.dispose();
    super.dispose();
  }

  Future<void> _seleccionarFoto() async {
    final img = await ImagePicker().pickImage(
        source: ImageSource.gallery, imageQuality: 80);
    if (img != null) {
      final bytes = await img.readAsBytes();
      setState(() { _fotoFile = img; _fotoBytes = bytes; });
    }
  }

  Future<void> _nuevaCategoria() async {
    final nc = TextEditingController();
    final dc = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Nueva Categoría'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: nc,
            maxLength: 100,
            decoration: const InputDecoration(
                labelText: 'Nombre *',
                border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: dc,
            decoration: const InputDecoration(
                labelText: 'Descripción (opcional)',
                border: OutlineInputBorder()),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: ColoresCarolina.celeste,
                foregroundColor: Colors.white),
            child: const Text('Crear'),
          ),
        ],
      ),
    );
    if (ok == true && nc.text.trim().isNotEmpty && mounted) {
      try {
        final nueva = await widget.servicio.crearCategoria(
            nc.text.trim(), dc.text.trim());
        final id = nueva['id'] as int;
        // Primero agrega a la lista local, luego asigna el ID
        setState(() {
          _categoriasLocal.add(nueva);
          _categoriaId = id;
        });
        widget.onNuevaCategoria();
        if (mounted) Notificacion.exito(context, 'Categoría creada');
      } catch (e) {
        if (mounted) {
          Notificacion.error(context,
              e.toString().replaceAll('Exception: ', ''));
        }
      }
    }
  }

  Future<void> _nuevaMarca() async {
    final nc = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Nueva Marca'),
        content: TextField(
          controller: nc,
          maxLength: 100,
          decoration: const InputDecoration(
              labelText: 'Nombre *',
              border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: ColoresCarolina.celeste,
                foregroundColor: Colors.white),
            child: const Text('Crear'),
          ),
        ],
      ),
    );
    if (ok == true && nc.text.trim().isNotEmpty && mounted) {
      try {
        final nueva = await widget.servicio.crearMarca(
            nc.text.trim(), null);
        final id = nueva['id'] as int;
        // Primero agrega a la lista local, luego asigna el ID
        setState(() {
          _marcasLocal.add(nueva);
          _marcaId = id;
        });
        widget.onNuevaMarca();
        if (mounted) Notificacion.exito(context, 'Marca creada');
      } catch (e) {
        if (mounted) {
          Notificacion.error(context,
              e.toString().replaceAll('Exception: ', ''));
        }
      }
    }
  }

  String? _validarPeso(String? v) {
    if (_tipoPeso == 'variable') return null;
    final s = (v ?? '').trim();
    if (!_esEdicion && s.isEmpty) {
      return _unidad == 'kg'
          ? 'El peso en kg es requerido'
          : 'El peso en gramos es requerido';
    }
    if (s.isEmpty) return null;
    final n = double.tryParse(s);
    if (n == null) {
      return 'Ingresa un número válido'
          ' (ej: ${_unidad == "kg" ? "0.5, 1, 3.5" : "160, 500"})';
    }
    if (n <= 0) return 'El valor debe ser mayor a 0';
    if (_unidad == 'kg' && n > 999) return 'Máximo 999 kg';
    if (_unidad == 'gr' && n > 99999) return 'Máximo 99999 gramos';
    return null;
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _cargando = true);

    final datos = <String, dynamic>{
      'nombre':        _nombreCtrl.text.trim(),
      'descripcion':   _descCtrl.text.trim().isEmpty
          ? null : _descCtrl.text.trim(),
      'codigo_barras': _codigoCtrl.text.trim().isEmpty
          ? null : _codigoCtrl.text.trim(),
      'categoria_id':  _categoriaId,
      'marca_id':      _marcaId,
      'tipo_peso':     _tipoPeso,
      'unidad':        _unidad,
      'activo':        _activo,
    };

    if (_tipoPeso == 'fijo' && _pesoCtrl.text.isNotEmpty) {
      datos['peso_gramos'] = double.tryParse(_pesoCtrl.text);
    }
    if (!_esEdicion && _stockMinCtrl.text.isNotEmpty) {
      datos['stock_minimo'] = double.tryParse(_stockMinCtrl.text);
    }

    try {
      Map<String, dynamic> result;
      if (_esEdicion) {
        result = await widget.servicio
            .actualizar(widget.producto!['id'], datos);
      } else {
        result = await widget.servicio.crear(datos);
      }
      if (_fotoFile != null) {
        final id = (result['id'] ?? widget.producto?['id']) as int?;
        if (id != null) {
          await widget.servicio.subirFoto(id, _fotoFile!);
        }
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

  ImageProvider? get _preview {
    if (_fotoBytes != null) return MemoryImage(_fotoBytes!);
    final f = _esEdicion
        ? (widget.producto!['foto'] as String?) : null;
    if (f != null && f.isNotEmpty) {
      return NetworkImage(_ProductosPantallaState.urlFoto(f));
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    return Dialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // ── Header ──────────────────────────────────────────
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
                  top: Radius.circular(20)),
            ),
            child: Row(children: [
              Icon(_esEdicion
                  ? Icons.edit_rounded
                  : Icons.add_box_rounded,
                  color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Text(_esEdicion ? 'Editar Producto' : 'Nuevo Producto',
                  style: const TextStyle(color: Colors.white,
                      fontSize: 17, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white)),
            ]),
          ),

          // ── Body ────────────────────────────────────────────
          Flexible(child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Foto ────────────────────────────────────
                  Center(child: Column(children: [
                    GestureDetector(
                      onTap: _seleccionarFoto,
                      child: Stack(children: [
                        Container(
                          width: 100, height: 100,
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              color: ColoresCarolina.grisClaro,
                              border: Border.all(
                                  color: ColoresCarolina.celeste
                                      .withValues(alpha: 0.3))),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(13),
                            child: preview != null
                                ? Image(image: preview,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        const Icon(
                                            Icons.add_photo_alternate_rounded,
                                            color: ColoresCarolina.celeste,
                                            size: 40))
                                : const Icon(
                                    Icons.add_photo_alternate_rounded,
                                    color: ColoresCarolina.celeste,
                                    size: 40),
                          ),
                        ),
                        Positioned(bottom: 4, right: 4,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: const BoxDecoration(
                                color: ColoresCarolina.celeste,
                                shape: BoxShape.circle),
                            child: const Icon(Icons.camera_alt,
                                color: Colors.white, size: 14),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _fotoBytes != null
                          ? 'Foto seleccionada ✓'
                          : 'Toca para agregar foto',
                      style: TextStyle(fontSize: 12,
                          color: _fotoBytes != null
                              ? Colors.green
                              : ColoresCarolina.grisMedio),
                    ),
                  ])),
                  const SizedBox(height: 20),

                  // ── Nombre ──────────────────────────────────
                  TextFormField(
                    controller: _nombreCtrl,
                    maxLength: 150,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Nombre del producto *',
                      hintText: 'Ej: Queso fresco 500gr',
                      prefixIcon: const Icon(
                          Icons.inventory_2_outlined,
                          color: ColoresCarolina.celeste),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: ColoresCarolina.celeste,
                              width: 2)),
                      counterText: '${_nombreCtrl.text.length}/150',
                    ),
                    validator: (v) {
                      final s = (v ?? '').trim();
                      if (s.isEmpty) return 'El nombre es requerido';
                      if (s.length < 2) return 'Mínimo 2 caracteres';
                      if (s.length > 150) return 'Máximo 150 caracteres';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // ── Descripción ──────────────────────────────
                  TextFormField(
                    controller: _descCtrl,
                    maxLines: 2,
                    maxLength: 500,
                    decoration: InputDecoration(
                      labelText: 'Descripción (opcional)',
                      hintText: 'Describe el producto...',
                      prefixIcon: const Icon(
                          Icons.description_outlined,
                          color: ColoresCarolina.celeste),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: ColoresCarolina.celeste,
                              width: 2)),
                    ),
                    validator: (v) {
                      if ((v ?? '').trim().length > 500) {
                        return 'Máximo 500 caracteres';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // ── Código barras ────────────────────────────
                  TextFormField(
                    controller: _codigoCtrl,
                    maxLength: 100,
                    onChanged: (_) => setState(() {}),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'[a-zA-Z0-9\-]')),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Código de barras (opcional)',
                      hintText: 'Ej: 7890001234567',
                      prefixIcon: const Icon(
                          Icons.qr_code_rounded,
                          color: ColoresCarolina.celeste),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: ColoresCarolina.celeste,
                              width: 2)),
                      counterText: _codigoCtrl.text.isNotEmpty
                          ? '${_codigoCtrl.text.length}/100' : '',
                    ),
                    validator: (v) {
                      if ((v ?? '').trim().length > 100) {
                        return 'Máximo 100 caracteres';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // ── Categoría ────────────────────────────────
                  Row(children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: _categoriaId,
                        decoration: _deco('Categoría *',
                            Icons.category_outlined),
                        // USA _categoriasLocal en lugar de widget.categorias
                        items: _categoriasLocal
                            .map<DropdownMenuItem<int>>((c) =>
                                DropdownMenuItem(
                                    value: c['id'] as int,
                                    child: Text(c['nombre'] as String)))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _categoriaId = v),
                        validator: (v) => v == null
                            ? 'Selecciona una categoría' : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Tooltip(
                      message: 'Nueva categoría',
                      child: IconButton(
                        onPressed: _nuevaCategoria,
                        icon: const Icon(Icons.add_circle_rounded),
                        color: ColoresCarolina.celeste,
                        style: IconButton.styleFrom(
                            backgroundColor: ColoresCarolina.celeste
                                .withValues(alpha: 0.1)),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 14),

                  // ── Marca ────────────────────────────────────
                  Row(children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: _marcaId,
                        decoration: _deco('Marca (opcional)',
                            Icons.branding_watermark_outlined),
                        // USA _marcasLocal en lugar de widget.marcas
                        items: [
                          const DropdownMenuItem<int>(
                              value: null,
                              child: Text('Sin marca')),
                          ..._marcasLocal
                              .map<DropdownMenuItem<int>>((m) =>
                                  DropdownMenuItem(
                                      value: m['id'] as int,
                                      child: Text(
                                          m['nombre'] as String))),
                        ],
                        onChanged: (v) =>
                            setState(() => _marcaId = v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Tooltip(
                      message: 'Nueva marca',
                      child: IconButton(
                        onPressed: _nuevaMarca,
                        icon: const Icon(Icons.add_circle_rounded),
                        color: ColoresCarolina.celeste,
                        style: IconButton.styleFrom(
                            backgroundColor: ColoresCarolina.celeste
                                .withValues(alpha: 0.1)),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 14),

                  // ── Tipo de producto ─────────────────────────
                  const Text('Tipo de producto',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: ColoresCarolina.grisMedio)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: _radioTipoPeso(
                        'fijo', 'Peso fijo',
                        'Ej: 160gr, 500gr, 3.5kg',
                        Icons.scale_rounded)),
                    const SizedBox(width: 12),
                    Expanded(child: _radioTipoPeso(
                        'variable', 'Peso variable',
                        'Se pesa en balanza al vender',
                        Icons.balance_rounded)),
                  ]),
                  const SizedBox(height: 14),

                  // ── Unidad + Peso (solo fijo) ─────────────────
                  if (_tipoPeso == 'fijo') ...[
                    DropdownButtonFormField<String>(
                      initialValue: _unidad,
                      decoration: _deco('Unidad de medida *',
                          Icons.straighten_rounded),
                      items: _unidades
                          .map<DropdownMenuItem<String>>((u) =>
                              DropdownMenuItem(
                                  value: u['valor'],
                                  child: Text(u['label']!)))
                          .toList(),
                      onChanged: (v) {
                        setState(() {
                          _unidad = v ?? 'gr';
                          _pesoCtrl.clear();
                        });
                      },
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: _pesoCtrl,
                      keyboardType: const TextInputType
                          .numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d*')),
                      ],
                      decoration: InputDecoration(
                        labelText: _unidad == 'kg'
                            ? 'Peso en kilogramos *'
                            : 'Peso en gramos *',
                        hintText: _unidad == 'kg'
                            ? 'Ej: 0.5, 1, 3.5'
                            : 'Ej: 160, 400, 500',
                        prefixIcon: const Icon(
                            Icons.scale_rounded,
                            color: ColoresCarolina.celeste),
                        suffixText: _unidad,
                        helperText: _unidad == 'kg'
                            ? 'Escribe en kg (ej: 3.5 = 3.5 kg)'
                            : 'Escribe en gramos (ej: 500)',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: ColoresCarolina.celeste,
                                width: 2)),
                      ),
                      validator: _validarPeso,
                    ),
                    const SizedBox(height: 10),

                    // Chips pesos comunes
                    const Text(
                      'Pesos más usados en quesos Carolina:',
                      style: TextStyle(
                          fontSize: 11,
                          color: ColoresCarolina.grisMedio,
                          fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6, runSpacing: 6,
                      children: _pesosPredefinidos.map((p) {
                        final valGr = double.parse(p['valor']!);
                        final chipVal = _unidad == 'kg'
                            ? (valGr / 1000).toStringAsFixed(
                                valGr % 1000 == 0 ? 1 : 3)
                            : p['valor']!;
                        final sel = _pesoCtrl.text == chipVal;
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _pesoCtrl.text = chipVal),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: sel
                                  ? ColoresCarolina.celeste
                                  : ColoresCarolina.grisClaro,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: sel
                                      ? ColoresCarolina.celeste
                                      : Colors.grey.shade300),
                            ),
                            child: Text(p['label']!,
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: sel
                                        ? Colors.white
                                        : ColoresCarolina.grisMedio)),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: Colors.orange
                                  .withValues(alpha: 0.2))),
                      child: const Row(children: [
                        Icon(Icons.info_outline_rounded,
                            color: Colors.orange, size: 18),
                        SizedBox(width: 10),
                        Expanded(child: Text(
                          'El precio se calculará por kg '
                          'según el peso en balanza al vender.',
                          style: TextStyle(
                              fontSize: 12, color: Colors.orange),
                        )),
                      ]),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // ── Stock mínimo (solo creación) ──────────────
                  if (!_esEdicion) ...[
                    TextFormField(
                      controller: _stockMinCtrl,
                      keyboardType: const TextInputType
                          .numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d*')),
                      ],
                      decoration: _deco(
                          'Stock mínimo para alerta (opcional)',
                          Icons.warning_amber_rounded),
                      validator: (v) {
                        final s = (v ?? '').trim();
                        if (s.isNotEmpty) {
                          final n = double.tryParse(s);
                          if (n == null) {
                            return 'Ingresa un número válido';
                          }
                          if (n < 0) {
                            return 'No puede ser negativo';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                  ],

                  // ── Estado activo ────────────────────────────
                  Container(
                    decoration: BoxDecoration(
                        border: Border.all(
                            color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(10)),
                    child: SwitchListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14),
                      title: const Text('Producto activo',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        _activo
                            ? 'Disponible para venta'
                            : 'No disponible para venta',
                        style: TextStyle(
                            fontSize: 12,
                            color: _activo
                                ? Colors.green
                                : ColoresCarolina.rojo),
                      ),
                      value: _activo,
                      activeTrackColor: ColoresCarolina.celeste,
                      onChanged: (v) =>
                          setState(() => _activo = v),
                    ),
                  ),
                ],
              ),
            ),
          )),

          // ── Footer ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            child: Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                    foregroundColor: ColoresCarolina.grisMedio,
                    side: BorderSide(color: Colors.grey.shade300),
                    padding:
                        const EdgeInsets.symmetric(vertical: 14),
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
                    padding:
                        const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
                child: _cargando
                    ? const SizedBox(height: 20, width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text(
                        _esEdicion
                            ? 'Guardar Cambios'
                            : 'Crear Producto',
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

  Widget _radioTipoPeso(String valor, String titulo,
      String subtitulo, IconData icono) {
    final sel = _tipoPeso == valor;
    return GestureDetector(
      onTap: () => setState(() {
        _tipoPeso = valor;
        _pesoCtrl.clear();
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: sel
                ? ColoresCarolina.celeste.withValues(alpha: 0.08)
                : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: sel
                    ? ColoresCarolina.celeste
                    : Colors.grey.shade300,
                width: sel ? 2 : 1)),
        child: Row(children: [
          Icon(icono,
              color: sel ? ColoresCarolina.celeste : Colors.grey,
              size: 22),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: sel
                          ? ColoresCarolina.celeste
                          : Colors.black87)),
              Text(subtitulo,
                  style: const TextStyle(
                      fontSize: 10,
                      color: ColoresCarolina.grisMedio)),
            ],
          )),
          if (sel)
            const Icon(Icons.check_circle_rounded,
                color: ColoresCarolina.celeste, size: 18),
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
}