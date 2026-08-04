
// carolina/frontend/lib/pantallas/categorias/categorias_pantalla.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../constantes/colores.dart';
import '../../constantes/api.dart';
import '../../constantes/breakpoints.dart';
import '../../servicios/auth_servicio.dart';
import '../../widgets/notificacion.dart';

class CategoriasServicio {
  final _auth = AuthServicio();
  Future<Map<String, String>> get _h => _auth.obtenerHeaders();

  Future<List<dynamic>> listar() async {
    final res = await http.get(Uri.parse(ApiConfig.categorias), headers: await _h);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Error al cargar categorías (${res.statusCode})');
  }

  Future<Map<String, dynamic>> crear(String nombre, String? desc) async {
    final res = await http.post(Uri.parse(ApiConfig.categorias),
        headers: await _h,
        body: jsonEncode({'nombre': nombre, 'descripcion': desc}));
    final data = jsonDecode(res.body);
    if (res.statusCode == 201) return data;
    if (data['errores'] != null) throw Exception((data['errores'] as Map).values.first.toString());
    throw Exception(data['error'] ?? 'Error al crear');
  }

  Future<Map<String, dynamic>> actualizar(int id, String nombre, String? desc) async {
    final res = await http.put(Uri.parse('${ApiConfig.categorias}/$id'),
        headers: await _h,
        body: jsonEncode({'nombre': nombre, 'descripcion': desc}));
    final data = jsonDecode(res.body);
    if (res.statusCode == 200) return data;
    if (data['errores'] != null) throw Exception((data['errores'] as Map).values.first.toString());
    throw Exception(data['error'] ?? 'Error al actualizar');
  }

  Future<void> eliminar(int id) async {
    final res = await http.delete(Uri.parse('${ApiConfig.categorias}/$id'),
        headers: await _h);
    if (res.statusCode != 200) {
      final data = jsonDecode(res.body);
      throw Exception(data['error'] ?? 'Error al eliminar');
    }
  }
}

class CategoriasPantalla extends StatefulWidget {
  const CategoriasPantalla({super.key});
  @override
  State<CategoriasPantalla> createState() => _CategoriasPantallaState();
}

class _CategoriasPantallaState extends State<CategoriasPantalla> {
  final _servicio   = CategoriasServicio();
  List<dynamic> _categorias = [];
  bool   _cargando  = true;
  String _busqueda  = '';

  @override
  void initState() { super.initState(); _cargar(); }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final c = await _servicio.listar();
      setState(() => _categorias = c);
    } catch (e) {
      if (mounted) Notificacion.error(context, e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  List<dynamic> get _filtradas {
    if (_busqueda.isEmpty) return _categorias;
    final q = _busqueda.toLowerCase();
    return _categorias.where((c) =>
        (c['nombre'] ?? '').toLowerCase().contains(q) ||
        (c['descripcion'] ?? '').toLowerCase().contains(q)).toList();
  }

  Future<bool> _confirmar(String titulo, String mensaje) async {
    final r = await showDialog<bool>(
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
          Expanded(child: Text(titulo, style: const TextStyle(fontSize: 16))),
        ]),
        content: Text(mensaje),
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
    return r ?? false;
  }

  Future<void> _eliminar(Map<String, dynamic> c) async {
    final ok = await _confirmar('Eliminar categoría',
        '¿Seguro que deseas eliminar "${c['nombre']}"?\n\nNo podrás eliminarla si tiene productos asociados.');
    if (ok && mounted) {
      try {
        await _servicio.eliminar(c['id']);
        if (mounted) { Notificacion.exito(context, 'Categoría eliminada'); _cargar(); }
      } catch (e) {
        if (mounted) Notificacion.error(context, e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  void _abrirFormulario({Map<String, dynamic>? categoria}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _FormularioCategoria(
        categoria: categoria,
        servicio: _servicio,
        onGuardado: () {
          Navigator.pop(context);
          Notificacion.exito(context,
              categoria == null ? 'Categoría creada' : 'Categoría actualizada');
          _cargar();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtradas = _filtradas;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Encabezado ──────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(28, 22, 28, 18),
          decoration: const BoxDecoration(color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0)))),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Gestión de Categorías',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold,
                      color: ColoresCarolina.celesteOscuro)),
              const SizedBox(height: 4),
              const Text('Organiza tus productos por categoría',
                  style: TextStyle(fontSize: 13, color: ColoresCarolina.grisMedio)),
              const SizedBox(height: 6),
              _chip('${_categorias.length} categorías', ColoresCarolina.celeste),
            ])),
            ElevatedButton.icon(
              onPressed: () => _abrirFormulario(),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Nueva Categoría'),
              style: ElevatedButton.styleFrom(
                backgroundColor: ColoresCarolina.celeste, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ]),
        ),

        // ── Buscador ────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
          color: Colors.white,
          child: Row(children: [
            Expanded(child: TextField(
              onChanged: (v) => setState(() => _busqueda = v),
              decoration: InputDecoration(
                hintText: 'Buscar categoría...',
                prefixIcon: const Icon(Icons.search_rounded, color: ColoresCarolina.celeste),
                suffixIcon: _busqueda.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear_rounded, size: 18),
                        tooltip: 'Limpiar búsqueda',
                        onPressed: () => setState(() => _busqueda = ''))
                    : null,
                filled: true, fillColor: const Color(0xFFF1F5F9),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: ColoresCarolina.celeste, width: 1.5)),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            )),
            const SizedBox(width: 8),
            IconButton(onPressed: _cargar, icon: const Icon(Icons.refresh_rounded),
                color: ColoresCarolina.celeste, tooltip: 'Actualizar'),
          ]),
        ),

        // ── Cuerpo ──────────────────────────────────────────────────────
        Expanded(child: _buildCuerpo(filtradas)),
      ],
    );
  }

  Widget _buildCuerpo(List<dynamic> filtradas) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator(color: ColoresCarolina.celeste));
    }
    if (filtradas.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.category_outlined, size: 72,
            color: ColoresCarolina.grisMedio.withValues(alpha: 0.35)),
        const SizedBox(height: 14),
        Text(_busqueda.isNotEmpty
            ? 'No hay resultados para "$_busqueda"'
            : 'No hay categorías registradas',
            style: const TextStyle(color: ColoresCarolina.grisMedio, fontSize: 15)),
      ]));
    }

    if (Breakpoints.esMovil(context)) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filtradas.length,
        itemBuilder: (_, i) => _TarjetaCategoriaMovil(
          categoria: filtradas[i],
          onEditar: () => _abrirFormulario(categoria: filtradas[i]),
          onEliminar: () => _eliminar(filtradas[i]),
        ),
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
            // Cabecera
            Container(
              color: const Color(0xFFF8FAFC),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(children: [
                _th('#',           1),
                _th('NOMBRE',      4),
                _th('DESCRIPCIÓN', 5),
                _th('PRODUCTOS',   2),
                _th('ACCIONES',    2),
              ]),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            ...filtradas.asMap().entries.map((e) {
              final c = e.value;
              return Column(children: [
                _FilaCategoria(
                  categoria: c,
                  numero:    e.key + 1,
                  impar:     e.key.isOdd,
                  onEditar:  () => _abrirFormulario(categoria: c),
                  onEliminar: () => _eliminar(c),
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
    decoration: BoxDecoration(color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20)),
    child: Text(t, style: TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.w600)),
  );
}

class _FilaCategoria extends StatelessWidget {
  final Map<String, dynamic> categoria;
  final int numero;
  final bool impar;
  final VoidCallback onEditar, onEliminar;

  const _FilaCategoria({
    required this.categoria, required this.numero, required this.impar,
    required this.onEditar, required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: impar ? const Color(0xFFFAFBFF) : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(children: [
        Expanded(flex: 1, child: Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
              color: ColoresCarolina.celeste.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8)),
          child: Center(child: Text('$numero',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                  color: ColoresCarolina.celeste))),
        )),
        Expanded(flex: 4, child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: ColoresCarolina.celeste.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.category_rounded,
                color: ColoresCarolina.celeste, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(categoria['nombre'] ?? '',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              overflow: TextOverflow.ellipsis)),
        ])),
        Expanded(flex: 5, child: Text(
            categoria['descripcion'] ?? '—',
            style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
            overflow: TextOverflow.ellipsis)),
        Expanded(flex: 2, child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20)),
          child: Text('${categoria['total_productos'] ?? 0} productos',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Colors.green,
                  fontWeight: FontWeight.w600)),
        )),
        Expanded(flex: 2, child: Row(mainAxisSize: MainAxisSize.min, children: [
          _btn(Icons.edit_rounded, Colors.orange, 'Editar', onEditar),
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
          decoration: BoxDecoration(color: c.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(i, size: 16, color: c)),
    ),
  );
}

// ─── Tarjeta para pantallas angostas (celular) ─────────────────────────────────
class _TarjetaCategoriaMovil extends StatelessWidget {
  final Map<String, dynamic> categoria;
  final VoidCallback onEditar, onEliminar;

  const _TarjetaCategoriaMovil({
    required this.categoria,
    required this.onEditar,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
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
              child: const Icon(Icons.category_rounded,
                  color: ColoresCarolina.celeste, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(categoria['nombre'] ?? '',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 15),
                  overflow: TextOverflow.ellipsis),
            ),
          ]),
          const SizedBox(height: 10),
          Text(
            categoria['descripcion'] ?? '—',
            style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20)),
              child: Text('${categoria['total_productos'] ?? 0} productos',
                  style: const TextStyle(fontSize: 11, color: Colors.green,
                      fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            _btn(Icons.edit_rounded, Colors.orange, 'Editar categoría', onEditar),
            const SizedBox(width: 8),
            _btn(Icons.delete_rounded, ColoresCarolina.rojo, 'Eliminar categoría',
                onEliminar),
          ]),
        ],
      ),
    );
  }

  Widget _btn(IconData i, Color c, String tip, VoidCallback fn) => Tooltip(
    message: tip,
    child: InkWell(onTap: fn, borderRadius: BorderRadius.circular(8),
      child: Container(padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: c.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(i, size: 18, color: c)),
    ),
  );
}

class _FormularioCategoria extends StatefulWidget {
  final Map<String, dynamic>? categoria;
  final CategoriasServicio servicio;
  final VoidCallback onGuardado;

  const _FormularioCategoria({
    this.categoria,
    required this.servicio,
    required this.onGuardado,
  });

  @override
  State<_FormularioCategoria> createState() => _FormularioCategoriaState();
}

class _FormularioCategoriaState extends State<_FormularioCategoria> {
  final _formKey    = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _descCtrl   = TextEditingController();
  bool _cargando    = false;

  bool get _esEdicion => widget.categoria != null;

  // Solo letras, números, espacios y guión
  final _regexNombre = RegExp(r'^[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ0-9\s\-]+$');

  @override
  void initState() {
    super.initState();
    if (_esEdicion) {
      _nombreCtrl.text = widget.categoria!['nombre'] ?? '';
      _descCtrl.text   = widget.categoria!['descripcion'] ?? '';
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _cargando = true);
    try {
      if (_esEdicion) {
        await widget.servicio.actualizar(
          widget.categoria!['id'],
          _nombreCtrl.text.trim(),
          _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        );
      } else {
        await widget.servicio.crear(
          _nombreCtrl.text.trim(),
          _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        );
      }
      widget.onGuardado();
    } catch (e) {
      if (mounted) {
        Notificacion.error(
            context, e.toString().replaceAll('Exception: ', ''));
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
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(children: [
                Icon(
                    _esEdicion ? Icons.edit_rounded : Icons.add_rounded,
                    color: Colors.white,
                    size: 22),
                const SizedBox(width: 10),
                Text(
                    _esEdicion ? 'Editar Categoría' : 'Nueva Categoría',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Cerrar',
                    icon: const Icon(Icons.close, color: Colors.white)),
              ]),
            ),

            // Formulario
            Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(children: [
                  // ── Nombre ──────────────────────────────────────────
                  TextFormField(
                    controller: _nombreCtrl,
                    maxLength: 100,
                    decoration: InputDecoration(
                      labelText: 'Nombre de la categoría *',
                      hintText: 'Ej: Quesos frescos',
                      prefixIcon: const Icon(Icons.category_outlined,
                          color: ColoresCarolina.celeste),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: ColoresCarolina.celeste, width: 2)),
                      counterText: '${_nombreCtrl.text.length}/100',
                    ),
                    onChanged: (_) => setState(() {}),
                    validator: (v) {
                      final s = (v ?? '').trim();
                      if (s.isEmpty) return 'El nombre es requerido';
                      if (s.length < 2) return 'Mínimo 2 caracteres';
                      if (s.length > 100) return 'Máximo 100 caracteres';
                      if (!_regexNombre.hasMatch(s)) {
                        return 'Solo letras, números y guiones';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // ── Descripción ──────────────────────────────────────
                  TextFormField(
                    controller: _descCtrl,
                    maxLines: 3,
                    maxLength: 300,
                    decoration: InputDecoration(
                      labelText: 'Descripción (opcional)',
                      hintText: 'Describe brevemente esta categoría...',
                      prefixIcon: const Icon(Icons.description_outlined,
                          color: ColoresCarolina.celeste),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: ColoresCarolina.celeste, width: 2)),
                    ),
                    validator: (v) {
                      final s = (v ?? '').trim();
                      if (s.isNotEmpty && s.length > 300) {
                        return 'Máximo 300 caracteres';
                      }
                      return null;
                    },
                  ),
                ]),
              ),
            ),

            // Footer
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: ColoresCarolina.grisMedio,
                        side: BorderSide(color: Colors.grey.shade300),
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10))),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _cargando ? null : _guardar,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: ColoresCarolina.celeste,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10))),
                    child: _cargando
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Text(
                            _esEdicion
                                ? 'Guardar Cambios'
                                : 'Crear Categoría',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15)),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}