// carolina/frontend/lib/pantallas/marcas/marcas_pantalla.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../constantes/colores.dart';
import '../../constantes/api.dart';
import '../../constantes/breakpoints.dart';
import '../../servicios/auth_servicio.dart';
import '../../widgets/notificacion.dart';

class MarcasServicio {
  final _auth = AuthServicio();
  Future<Map<String, String>> get _h => _auth.obtenerHeaders();

  Future<List<dynamic>> listar() async {
    final res = await http.get(Uri.parse(ApiConfig.marcas), headers: await _h);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Error al cargar marcas (${res.statusCode})');
  }

  Future<Map<String, dynamic>> crear(String nombre, String? desc) async {
    final res = await http.post(Uri.parse(ApiConfig.marcas),
        headers: await _h,
        body: jsonEncode({'nombre': nombre, 'descripcion': desc}));
    final data = jsonDecode(res.body);
    if (res.statusCode == 201) return data;
    if (data['errores'] != null) throw Exception((data['errores'] as Map).values.first.toString());
    throw Exception(data['error'] ?? 'Error al crear');
  }

  Future<Map<String, dynamic>> actualizar(int id, String nombre, String? desc) async {
    final res = await http.put(Uri.parse('${ApiConfig.marcas}/$id'),
        headers: await _h,
        body: jsonEncode({'nombre': nombre, 'descripcion': desc}));
    final data = jsonDecode(res.body);
    if (res.statusCode == 200) return data;
    if (data['errores'] != null) throw Exception((data['errores'] as Map).values.first.toString());
    throw Exception(data['error'] ?? 'Error al actualizar');
  }

  Future<void> eliminar(int id) async {
    final res = await http.delete(Uri.parse('${ApiConfig.marcas}/$id'),
        headers: await _h);
    if (res.statusCode != 200) {
      final data = jsonDecode(res.body);
      throw Exception(data['error'] ?? 'Error al eliminar');
    }
  }
}

class MarcasPantalla extends StatefulWidget {
  const MarcasPantalla({super.key});
  @override
  State<MarcasPantalla> createState() => _MarcasPantallaState();
}

class _MarcasPantallaState extends State<MarcasPantalla> {
  final _servicio  = MarcasServicio();
  List<dynamic> _marcas   = [];
  bool   _cargando = true;
  String _busqueda = '';

  // Colores para las marcas (ciclo)
  static const _colores = [
    Color(0xFF0EA5E9), Color(0xFF8B5CF6), Color(0xFFEC4899),
    Color(0xFFF59E0B), Color(0xFF10B981), Color(0xFFEF4444),
    Color(0xFF6366F1), Color(0xFF14B8A6),
  ];

  Color _colorMarca(int index) => _colores[index % _colores.length];

  @override
  void initState() { super.initState(); _cargar(); }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final m = await _servicio.listar();
      setState(() => _marcas = m);
    } catch (e) {
      if (mounted) Notificacion.error(context, e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  List<dynamic> get _filtradas {
    if (_busqueda.isEmpty) return _marcas;
    final q = _busqueda.toLowerCase();
    return _marcas.where((m) =>
        (m['nombre'] ?? '').toLowerCase().contains(q) ||
        (m['descripcion'] ?? '').toLowerCase().contains(q)).toList();
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

  Future<void> _eliminar(Map<String, dynamic> m) async {
    final ok = await _confirmar('Eliminar marca',
        '¿Seguro que deseas eliminar la marca "${m['nombre']}"?');
    if (ok && mounted) {
      try {
        await _servicio.eliminar(m['id']);
        if (mounted) { Notificacion.exito(context, 'Marca eliminada'); _cargar(); }
      } catch (e) {
        if (mounted) Notificacion.error(context, e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  void _abrirFormulario({Map<String, dynamic>? marca}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _FormularioMarca(
        marca: marca,
        servicio: _servicio,
        onGuardado: () {
          Navigator.pop(context);
          Notificacion.exito(context,
              marca == null ? 'Marca creada' : 'Marca actualizada');
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
              const Text('Gestión de Marcas',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold,
                      color: ColoresCarolina.celesteOscuro)),
              const SizedBox(height: 4),
              const Text('Administra las marcas de tus productos',
                  style: TextStyle(fontSize: 13, color: ColoresCarolina.grisMedio)),
              const SizedBox(height: 6),
              _chip('${_marcas.length} marcas', ColoresCarolina.celeste),
            ])),
            ElevatedButton.icon(
              onPressed: () => _abrirFormulario(),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Nueva Marca'),
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
                hintText: 'Buscar marca...',
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
        Icon(Icons.branding_watermark_outlined, size: 72,
            color: ColoresCarolina.grisMedio.withValues(alpha: 0.35)),
        const SizedBox(height: 14),
        Text(_busqueda.isNotEmpty
            ? 'No hay resultados para "$_busqueda"'
            : 'No hay marcas registradas',
            style: const TextStyle(color: ColoresCarolina.grisMedio, fontSize: 15)),
      ]));
    }

    if (Breakpoints.esMovil(context)) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filtradas.length,
        itemBuilder: (_, i) => _TarjetaMarcaMovil(
          marca: filtradas[i],
          color: _colorMarca(i),
          onEditar: () => _abrirFormulario(marca: filtradas[i]),
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
            Container(
              color: const Color(0xFFF8FAFC),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(children: [
                _th('#',           1),
                _th('MARCA',       4),
                _th('DESCRIPCIÓN', 5),
                _th('ACCIONES',    2),
              ]),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            ...filtradas.asMap().entries.map((e) {
              final m = e.value;
              return Column(children: [
                _FilaMarca(
                  marca:      m,
                  numero:     e.key + 1,
                  impar:      e.key.isOdd,
                  color:      _colorMarca(e.key),
                  onEditar:   () => _abrirFormulario(marca: m),
                  onEliminar: () => _eliminar(m),
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

class _FilaMarca extends StatelessWidget {
  final Map<String, dynamic> marca;
  final int numero;
  final bool impar;
  final Color color;
  final VoidCallback onEditar, onEliminar;

  const _FilaMarca({
    required this.marca, required this.numero, required this.impar,
    required this.color, required this.onEditar, required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    final inicial = (marca['nombre'] as String? ?? 'M')[0].toUpperCase();
    return Container(
      color: impar ? const Color(0xFFFAFBFF) : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(children: [
        Expanded(flex: 1, child: Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8)),
          child: Center(child: Text('$numero',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color))),
        )),
        Expanded(flex: 4, child: Row(children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withValues(alpha: 0.15),
            child: Text(inicial, style: TextStyle(color: color,
                fontWeight: FontWeight.bold, fontSize: 14)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(marca['nombre'] ?? '',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              overflow: TextOverflow.ellipsis)),
        ])),
        Expanded(flex: 5, child: Text(
            marca['descripcion'] ?? '—',
            style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
            overflow: TextOverflow.ellipsis)),
        Expanded(flex: 2, child: Row(mainAxisSize: MainAxisSize.min, children: [
          _btn(Icons.edit_rounded,   Colors.orange,          'Editar',    onEditar),
          const SizedBox(width: 4),
          _btn(Icons.delete_rounded, ColoresCarolina.rojo,   'Eliminar',  onEliminar),
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
class _TarjetaMarcaMovil extends StatelessWidget {
  final Map<String, dynamic> marca;
  final Color color;
  final VoidCallback onEditar, onEliminar;

  const _TarjetaMarcaMovil({
    required this.marca,
    required this.color,
    required this.onEditar,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    final inicial = (marca['nombre'] as String? ?? 'M')[0].toUpperCase();
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
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withValues(alpha: 0.15),
              child: Text(inicial, style: TextStyle(color: color,
                  fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(marca['nombre'] ?? '',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 15),
                  overflow: TextOverflow.ellipsis),
            ),
          ]),
          const SizedBox(height: 10),
          Text(
            marca['descripcion'] ?? '—',
            style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
          ),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            _btn(Icons.edit_rounded, Colors.orange, 'Editar marca', onEditar),
            const SizedBox(width: 8),
            _btn(Icons.delete_rounded, ColoresCarolina.rojo, 'Eliminar marca',
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

class _FormularioMarca extends StatefulWidget {
  final Map<String, dynamic>? marca;
  final MarcasServicio servicio;
  final VoidCallback onGuardado;

  const _FormularioMarca({
    this.marca,
    required this.servicio,
    required this.onGuardado,
  });

  @override
  State<_FormularioMarca> createState() => _FormularioMarcaState();
}

class _FormularioMarcaState extends State<_FormularioMarca> {
  final _formKey    = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _descCtrl   = TextEditingController();
  bool _cargando    = false;

  bool get _esEdicion => widget.marca != null;

  // Letras, números, espacios, guión y punto
  final _regexNombre =
      RegExp(r'^[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ0-9\s\-\.]+$');

  @override
  void initState() {
    super.initState();
    if (_esEdicion) {
      _nombreCtrl.text = widget.marca!['nombre'] ?? '';
      _descCtrl.text   = widget.marca!['descripcion'] ?? '';
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
          widget.marca!['id'],
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
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20)),
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
                    _esEdicion
                        ? Icons.edit_rounded
                        : Icons.add_rounded,
                    color: Colors.white,
                    size: 22),
                const SizedBox(width: 10),
                Text(
                    _esEdicion ? 'Editar Marca' : 'Nueva Marca',
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
                      labelText: 'Nombre de la marca *',
                      hintText: 'Ej: Quesos Don Pedro',
                      prefixIcon: const Icon(
                          Icons.branding_watermark_outlined,
                          color: ColoresCarolina.celeste),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: ColoresCarolina.celeste,
                              width: 2)),
                      counterText:
                          '${_nombreCtrl.text.length}/100',
                    ),
                    onChanged: (_) => setState(() {}),
                    validator: (v) {
                      final s = (v ?? '').trim();
                      if (s.isEmpty) {
                        return 'El nombre es requerido';
                      }
                      if (s.length < 2) {
                        return 'Mínimo 2 caracteres';
                      }
                      if (s.length > 100) {
                        return 'Máximo 100 caracteres';
                      }
                      if (!_regexNombre.hasMatch(s)) {
                        return 'Solo letras, números, guiones y puntos';
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
                      hintText:
                          'Describe brevemente esta marca...',
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
                        side:
                            BorderSide(color: Colors.grey.shade300),
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(10))),
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
                            borderRadius:
                                BorderRadius.circular(10))),
                    child: _cargando
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2))
                        : Text(
                            _esEdicion
                                ? 'Guardar Cambios'
                                : 'Crear Marca',
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