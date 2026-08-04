// carolina/frontend/lib/pantallas/proveedores/proveedores_pantalla.dart
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
class ProveedoresServicio {
  final _auth = AuthServicio();
  Future<Map<String, String>> get _h => _auth.obtenerHeaders();

  Future<List<dynamic>> listar() async {
    final res = await http.get(
        Uri.parse(ApiConfig.proveedores), headers: await _h);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Error al cargar proveedores (${res.statusCode})');
  }

  Future<List<dynamic>> listarProductos() async {
    final res = await http.get(
        Uri.parse(ApiConfig.productos), headers: await _h);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Error al cargar productos');
  }

  Future<Map<String, dynamic>> crear(
      Map<String, dynamic> datos) async {
    final res = await http.post(Uri.parse(ApiConfig.proveedores),
        headers: await _h, body: jsonEncode(datos));
    final data = jsonDecode(res.body);
    if (res.statusCode == 201) return data;
    if (data['errores'] != null) {
      throw Exception(
          (data['errores'] as Map).values.first.toString());
    }
    throw Exception(data['error'] ?? 'Error al crear proveedor');
  }

  Future<Map<String, dynamic>> actualizar(
      int id, Map<String, dynamic> datos) async {
    final res = await http.put(
        Uri.parse('${ApiConfig.proveedores}/$id'),
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
        Uri.parse('${ApiConfig.proveedores}/$id'),
        headers: await _h);
    if (res.statusCode != 200) {
      final data = jsonDecode(res.body);
      throw Exception(data['error'] ?? 'Error al eliminar');
    }
  }
}

// ─── Pantalla ─────────────────────────────────────────────────────────────────
class ProveedoresPantalla extends StatefulWidget {
  const ProveedoresPantalla({super.key});
  @override
  State<ProveedoresPantalla> createState() => _ProveedoresPantallaState();
}

class _ProveedoresPantallaState extends State<ProveedoresPantalla> {
  final _servicio    = ProveedoresServicio();
  List<dynamic> _proveedores = [];
  List<dynamic> _productos   = [];
  bool   _cargando           = true;
  String _busqueda           = '';
  String _filtroEstado       = 'todos';

  @override
  void initState() { super.initState(); _cargar(); }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final p  = await _servicio.listar();
      final pr = await _servicio.listarProductos();
      setState(() { _proveedores = p; _productos = pr; });
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
    return _proveedores.where((p) {
      final activo = p['activo'] as bool? ?? false;
      if (_filtroEstado == 'activos'   && !activo) return false;
      if (_filtroEstado == 'inactivos' &&  activo) return false;
      if (_busqueda.isEmpty) return true;
      final q = _busqueda.toLowerCase();
      return (p['nombre_completo'] ?? '').toLowerCase().contains(q) ||
             (p['nit']             ?? '').toLowerCase().contains(q) ||
             (p['telefono']        ?? '').toLowerCase().contains(q) ||
             (p['email']           ?? '').toLowerCase().contains(q) ||
             (p['contacto']        ?? '').toLowerCase().contains(q);
    }).toList();
  }

  int get _totalActivos =>
      _proveedores.where((p) => p['activo'] == true).length;
  int get _totalInactivos =>
      _proveedores.where((p) => p['activo'] == false).length;

  Future<bool> _confirmar({
    required String   titulo,
    required String   mensaje,
    required String   labelBtn,
    required Color    colorBtn,
    required IconData icono,
  }) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: colorBtn.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(icono, color: colorBtn, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(titulo,
              style: const TextStyle(fontSize: 16))),
        ]),
        content: Text(mensaje),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: colorBtn,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
            child: Text(labelBtn),
          ),
        ],
      ),
    );
    return r ?? false;
  }

  Future<void> _cambiarEstado(Map<String, dynamic> p) async {
    final activo = p['activo'] as bool? ?? false;
    final ok = await _confirmar(
      titulo:   activo ? 'Desactivar proveedor' : 'Activar proveedor',
      mensaje:  '¿Confirmas ${activo ? "desactivar" : "activar"} a "${p['nombre_completo']}"?',
      labelBtn: activo ? 'Sí, desactivar' : 'Sí, activar',
      colorBtn: activo ? Colors.amber.shade700 : Colors.green,
      icono:    activo
          ? Icons.person_off_rounded
          : Icons.person_rounded,
    );
    if (ok && mounted) {
      try {
        await _servicio.actualizar(p['id'], {'activo': !activo});
        if (mounted) {
          Notificacion.exito(context, 'Estado actualizado');
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

  Future<void> _eliminar(Map<String, dynamic> p) async {
    final ok = await _confirmar(
      titulo:   'Eliminar proveedor',
      mensaje:  '⚠️ Se eliminará PERMANENTEMENTE a "${p['nombre_completo']}".\n\nEsta acción NO se puede deshacer.',
      labelBtn: 'Sí, eliminar',
      colorBtn: ColoresCarolina.rojo,
      icono:    Icons.delete_forever_rounded,
    );
    if (ok && mounted) {
      try {
        await _servicio.eliminar(p['id']);
        if (mounted) {
          Notificacion.exito(context, 'Proveedor eliminado');
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
          builder: (_) => _DetalleProveedor(proveedor: p));

  void _abrirFormulario({Map<String, dynamic>? proveedor}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _FormularioProveedor(
        proveedor: proveedor,
        productos: _productos,
        servicio:  _servicio,
        onGuardado: () {
          Navigator.pop(context);
          Notificacion.exito(context, proveedor == null
              ? 'Proveedor creado' : 'Proveedor actualizado');
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
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
    ),
    child: Row(children: [
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Gestión de Proveedores',
              style: TextStyle(fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: ColoresCarolina.celesteOscuro)),
          const SizedBox(height: 4),
          const Text(
              'Registra y administra los proveedores que abastecen '
              'a la distribuidora, sus datos de contacto y estado.',
              style: TextStyle(
                  fontSize: 13, color: ColoresCarolina.grisMedio)),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            _chip('${_proveedores.length} total',
                ColoresCarolina.celeste),
            _chip('$_totalActivos activos',  Colors.green),
            _chip('$_totalInactivos inactivos', Colors.grey),
          ]),
        ],
      )),
      ElevatedButton.icon(
        onPressed: () => _abrirFormulario(),
        icon: const Icon(Icons.add_rounded, size: 18),
        label: const Text('Nuevo Proveedor'),
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
          hintText:
              'Buscar por nombre, NIT, teléfono, correo o contacto...',
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
          _btnFiltro('Todos',     'todos',
              Icons.local_shipping_rounded),
          _btnFiltro('Activos',   'activos',
              Icons.check_circle_rounded),
          _btnFiltro('Inactivos', 'inactivos',
              Icons.cancel_rounded),
        ]),
      ),
      const SizedBox(width: 8),
      IconButton(
        onPressed: _cargar,
        icon: const Icon(Icons.refresh_rounded),
        color: ColoresCarolina.celeste,
        tooltip: 'Actualizar',
      ),
    ]),
  );

  Widget _btnFiltro(String label, String valor, IconData icono) {
    final sel = _filtroEstado == valor;
    return GestureDetector(
      onTap: () => setState(() => _filtroEstado = valor),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
            color: sel
                ? ColoresCarolina.celeste
                : Colors.transparent,
            borderRadius: BorderRadius.circular(9)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icono,
              size: 14,
              color: sel
                  ? Colors.white
                  : ColoresCarolina.grisMedio),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: sel
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: sel
                      ? Colors.white
                      : ColoresCarolina.grisMedio)),
        ]),
      ),
    );
  }

  Widget _buildCuerpo(List<dynamic> filtrados) {
    if (_cargando) {
      return const Center(
          child: CircularProgressIndicator(
              color: ColoresCarolina.celeste));
    }
    if (filtrados.isEmpty) {
      return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.local_shipping_outlined,
              size: 72,
              color: ColoresCarolina.grisMedio
                  .withValues(alpha: 0.35)),
          const SizedBox(height: 14),
          Text(
            _busqueda.isNotEmpty
                ? 'No hay resultados para "$_busqueda"'
                : _filtroEstado == 'inactivos'
                    ? 'No hay proveedores inactivos'
                    : 'No hay proveedores registrados',
            style: const TextStyle(
                color: ColoresCarolina.grisMedio,
                fontSize: 15),
          ),
        ],
      ));
    }

    // ── Vista móvil: tarjetas apiladas en vez de tabla ──────────────
    if (Breakpoints.esMovil(context)) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filtrados.length,
        itemBuilder: (_, i) {
          final p = filtrados[i];
          return _TarjetaProveedorMovil(
            proveedor:  p,
            onVer:      () => _verDetalle(p),
            onEditar:   () => _abrirFormulario(proveedor: p),
            onEstado:   () => _cambiarEstado(p),
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
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Column(children: [
            Container(
              color: const Color(0xFFF8FAFC),
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 14),
              child: Row(children: [
                _th('PROVEEDOR',  4),
                _th('NIT',        2),
                _th('TELÉFONO',   2),
                _th('CONTACTO',   2),
                _th('PRODUCTOS',  3),
                _th('ESTADO',     2),
                _th('ACCIONES',   3),
              ]),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            ...filtrados.asMap().entries.map((e) {
              final p = e.value;
              return Column(children: [
                _FilaProveedor(
                  proveedor:  p,
                  impar:      e.key.isOdd,
                  onVer:      () => _verDetalle(p),
                  onEditar:   () => _abrirFormulario(proveedor: p),
                  onEstado:   () => _cambiarEstado(p),
                  onEliminar: () => _eliminar(p),
                ),
                if (e.key < filtrados.length - 1)
                  const Divider(
                      height: 1, color: Color(0xFFE2E8F0)),
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

  Widget _chip(String t, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20)),
    child: Text(t,
        style: TextStyle(
            fontSize: 11, color: c, fontWeight: FontWeight.w600)),
  );
}

// ─── Fila ─────────────────────────────────────────────────────────────────────
class _FilaProveedor extends StatelessWidget {
  final Map<String, dynamic> proveedor;
  final bool impar;
  final VoidCallback onVer, onEditar, onEstado, onEliminar;

  const _FilaProveedor({
    required this.proveedor, required this.impar,
    required this.onVer,     required this.onEditar,
    required this.onEstado,  required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    final activo  = proveedor['activo'] as bool? ?? false;
    final nombre  = proveedor['nombre_completo'] as String? ?? '-';
    final inicial = nombre.isNotEmpty ? nombre[0].toUpperCase() : 'P';

    return Container(
      color: impar ? const Color(0xFFFAFBFF) : Colors.white,
      padding: const EdgeInsets.symmetric(
          horizontal: 20, vertical: 12),
      child: Row(children: [
        // Proveedor
        Expanded(flex: 4, child: Row(children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.orange.withValues(alpha: 0.15),
            child: Text(inicial,
                style: const TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(nombre,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13),
                  overflow: TextOverflow.ellipsis),
              if (!activo)
                const Text('Inactivo',
                    style: TextStyle(
                        fontSize: 10, color: Colors.grey)),
            ],
          )),
        ])),
        // NIT
        Expanded(flex: 2, child: Text(
            proveedor['nit'] ?? '-',
            style: const TextStyle(
                fontSize: 13, color: Color(0xFF475569)),
            overflow: TextOverflow.ellipsis)),
        // Teléfono
        Expanded(flex: 2, child: Text(
            proveedor['telefono'] ?? '-',
            style: const TextStyle(
                fontSize: 13, color: Color(0xFF475569)))),
        // Contacto
        Expanded(flex: 2, child: Text(
            proveedor['contacto'] ?? '-',
            style: const TextStyle(
                fontSize: 13, color: Color(0xFF475569)),
            overflow: TextOverflow.ellipsis)),
        // Productos que provee
        Expanded(flex: 3, child: _celdaProductos(proveedor)),
        // Estado
        Expanded(flex: 2, child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: activo ? Colors.green : Colors.grey)),
            const SizedBox(width: 6),
            Text(activo ? 'Activo' : 'Inactivo',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: activo ? Colors.green : Colors.grey)),
          ],
        )),
        // Acciones
        Expanded(flex: 3, child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _btn(Icons.visibility_rounded,
                ColoresCarolina.celeste, 'Ver', onVer),
            const SizedBox(width: 4),
            _btn(Icons.edit_rounded,
                Colors.orange, 'Editar', onEditar),
            const SizedBox(width: 4),
            _btn(
              activo
                  ? Icons.person_off_rounded
                  : Icons.person_rounded,
              activo
                  ? Colors.amber.shade700
                  : Colors.green,
              activo ? 'Desactivar' : 'Activar',
              onEstado,
            ),
            const SizedBox(width: 4),
            _btn(Icons.delete_rounded,
                ColoresCarolina.rojo, 'Eliminar', onEliminar),
          ],
        )),
      ]),
    );
  }

  Widget _btn(IconData i, Color c, String tip, VoidCallback fn) =>
      Tooltip(
        message: tip,
        child: InkWell(
          onTap: fn,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
                color: c.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(i, size: 16, color: c),
          ),
        ),
      );

  Widget _celdaProductos(Map<String, dynamic> proveedor) {
    final productos = (proveedor['productos'] as List?) ?? [];
    if (productos.isEmpty) {
      return const Text('—',
          style: TextStyle(fontSize: 13, color: ColoresCarolina.grisMedio));
    }
    final nombres = productos.map((p) => p['nombre'] as String? ?? '').join(', ');
    return Tooltip(
      message: nombres,
      child: Text(nombres,
          style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
          overflow: TextOverflow.ellipsis),
    );
  }
}

// ─── Tarjeta móvil ────────────────────────────────────────────────────────────
class _TarjetaProveedorMovil extends StatelessWidget {
  final Map<String, dynamic> proveedor;
  final VoidCallback onVer, onEditar, onEstado, onEliminar;

  const _TarjetaProveedorMovil({
    required this.proveedor, required this.onVer,
    required this.onEditar,  required this.onEstado,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    final activo  = proveedor['activo'] as bool? ?? false;
    final nombre  = proveedor['nombre_completo'] as String? ?? '-';
    final inicial = nombre.isNotEmpty ? nombre[0].toUpperCase() : 'P';

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
              radius: 20,
              backgroundColor: Colors.orange.withValues(alpha: 0.15),
              child: Text(inicial,
                  style: const TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold, fontSize: 15)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nombre,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: activo ? Colors.green : Colors.grey)),
                  const SizedBox(width: 6),
                  Text(activo ? 'Activo' : 'Inactivo',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600,
                          color: activo ? Colors.green : Colors.grey)),
                ]),
              ],
            )),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if ((proveedor['nit'] as String?)?.isNotEmpty == true)
              _dato(Icons.receipt_rounded, 'NIT', proveedor['nit']),
            if ((proveedor['telefono'] as String?)?.isNotEmpty == true)
              _dato(Icons.phone_outlined, 'Tel.', proveedor['telefono']),
            if ((proveedor['contacto'] as String?)?.isNotEmpty == true)
              _dato(Icons.contact_phone_outlined, 'Contacto',
                  proveedor['contacto']),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            const Icon(Icons.inventory_2_outlined, size: 14,
                color: ColoresCarolina.grisMedio),
            const SizedBox(width: 6),
            Expanded(child: Text(
                (() {
                  final productos = (proveedor['productos'] as List?) ?? [];
                  if (productos.isEmpty) return 'Sin productos vinculados';
                  return productos.map((p) => p['nombre'] as String? ?? '')
                      .join(', ');
                })(),
                style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                overflow: TextOverflow.ellipsis)),
          ]),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _btn(Icons.visibility_rounded,
                  ColoresCarolina.celeste, 'Ver', onVer),
              const SizedBox(width: 6),
              _btn(Icons.edit_rounded, Colors.orange, 'Editar', onEditar),
              const SizedBox(width: 6),
              _btn(
                activo
                    ? Icons.person_off_rounded
                    : Icons.person_rounded,
                activo ? Colors.amber.shade700 : Colors.green,
                activo ? 'Desactivar' : 'Activar',
                onEstado,
              ),
              const SizedBox(width: 6),
              _btn(Icons.delete_rounded,
                  ColoresCarolina.rojo, 'Eliminar', onEliminar),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dato(IconData icono, String label, String? valor) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icono, size: 14, color: ColoresCarolina.grisMedio),
      const SizedBox(width: 5),
      Text('$label: ${valor ?? "-"}',
          style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
    ]),
  );

  Widget _btn(IconData i, Color c, String tip, VoidCallback fn) => Tooltip(
    message: tip,
    child: InkWell(
      onTap: fn,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: c.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8)),
        child: Icon(i, size: 17, color: c),
      ),
    ),
  );
}

// ─── Detalle ──────────────────────────────────────────────────────────────────
class _DetalleProveedor extends StatelessWidget {
  final Map<String, dynamic> proveedor;
  const _DetalleProveedor({required this.proveedor});

  @override
  Widget build(BuildContext context) {
    final activo = proveedor['activo'] as bool? ?? false;
    return Dialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [
                    Colors.orange.shade600,
                    Colors.orange.shade800
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20)),
            ),
            child: Column(children: [
              CircleAvatar(
                radius: 38,
                backgroundColor: Colors.white.withValues(alpha: 0.25),
                child: Text(
                  (proveedor['nombre'] as String? ?? 'P')[0]
                      .toUpperCase(),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 30),
                ),
              ),
              const SizedBox(height: 10),
              Text(proveedor['nombre_completo'] ?? '',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 17)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(activo ? 'ACTIVO' : 'INACTIVO',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
            ]),
          ),
          // Datos
          Flexible(child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Column(children: [
              _fila(Icons.person_outline,
                  'Nombre',      proveedor['nombre']           ?? '-'),
              _fila(Icons.badge_outlined,
                  'Ap. Paterno', proveedor['apellido_paterno'] ?? '-'),
              _fila(Icons.badge_outlined,
                  'Ap. Materno', proveedor['apellido_materno'] ?? '-'),
              _fila(Icons.receipt_rounded,
                  'NIT',         proveedor['nit']              ?? '-'),
              _fila(Icons.phone_outlined,
                  'Teléfono',    proveedor['telefono']         ?? '-'),
              _fila(Icons.email_outlined,
                  'Correo',      proveedor['email']            ?? '-'),
              _fila(Icons.location_on_outlined,
                  'Dirección',   proveedor['direccion']        ?? '-'),
              _fila(Icons.contact_phone_outlined,
                  'Contacto',    proveedor['contacto']         ?? '-'),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.inventory_2_outlined, size: 18,
                          color: ColoresCarolina.celeste),
                      const SizedBox(width: 12),
                      const SizedBox(
                          width: 110,
                          child: Text('Productos',
                              style: TextStyle(
                                  color: ColoresCarolina.grisMedio,
                                  fontSize: 13))),
                    ]),
                    const SizedBox(height: 8),
                    if (((proveedor['productos'] as List?) ?? []).isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(left: 30),
                        child: Text('Sin productos vinculados',
                            style: TextStyle(
                                color: ColoresCarolina.grisMedio,
                                fontSize: 12)),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(left: 30),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: (proveedor['productos'] as List)
                              .map((p) => Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                        color: ColoresCarolina.celeste
                                            .withValues(alpha: 0.1),
                                        borderRadius:
                                            BorderRadius.circular(20)),
                                    child: Text(p['nombre'] ?? '',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: ColoresCarolina
                                                .celesteOscuro,
                                            fontWeight: FontWeight.w600)),
                                  ))
                              .toList(),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(children: [
                  Icon(
                      activo
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded,
                      size: 18,
                      color: activo ? Colors.green : Colors.grey),
                  const SizedBox(width: 12),
                  const SizedBox(
                      width: 110,
                      child: Text('Estado',
                          style: TextStyle(
                              color: ColoresCarolina.grisMedio,
                              fontSize: 13))),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                        color: (activo ? Colors.green : Colors.grey)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(
                        activo ? 'Activo' : 'Inactivo',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: activo
                                ? Colors.green
                                : Colors.grey)),
                  ),
                ]),
              ),
            ]),
          )),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                    backgroundColor: ColoresCarolina.celeste,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(10))),
                child: const Text('Cerrar',
                    style: TextStyle(
                        fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _fila(IconData i, String l, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(children: [
      Icon(i, size: 18, color: ColoresCarolina.celeste),
      const SizedBox(width: 12),
      SizedBox(
          width: 110,
          child: Text(l,
              style: const TextStyle(
                  color: ColoresCarolina.grisMedio,
                  fontSize: 13))),
      Expanded(
          child: Text(v,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13),
              overflow: TextOverflow.ellipsis)),
    ]),
  );
}

// ─── Formulario ───────────────────────────────────────────────────────────────
class _FormularioProveedor extends StatefulWidget {
  final Map<String, dynamic>? proveedor;
  final List<dynamic>          productos;
  final ProveedoresServicio    servicio;
  final VoidCallback           onGuardado;

  const _FormularioProveedor({
    this.proveedor,
    required this.productos,
    required this.servicio,
    required this.onGuardado,
  });

  @override
  State<_FormularioProveedor> createState() =>
      _FormularioProveedorState();
}

class _FormularioProveedorState
    extends State<_FormularioProveedor> {
  final _formKey       = GlobalKey<FormState>();
  final _nombreCtrl    = TextEditingController();
  final _apPaternoCtrl = TextEditingController();
  final _apMaternoCtrl = TextEditingController();
  final _nitCtrl       = TextEditingController();
  final _telefonoCtrl  = TextEditingController();
  final _emailCtrl     = TextEditingController();
  final _direccionCtrl = TextEditingController();
  final _contactoCtrl  = TextEditingController();

  Set<int> _productoIds = {};
  bool _activo   = true;
  bool _cargando = false;

  bool get _esEdicion => widget.proveedor != null;

  final _regexLetras =
      RegExp(r"^[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ\s'\-]+$");

  @override
  void initState() {
    super.initState();
    if (_esEdicion) {
      final p = widget.proveedor!;
      _nombreCtrl.text    = p['nombre']           ?? '';
      _apPaternoCtrl.text = p['apellido_paterno'] ?? '';
      _apMaternoCtrl.text = p['apellido_materno'] ?? '';
      _nitCtrl.text       = p['nit']              ?? '';
      _telefonoCtrl.text  = p['telefono']         ?? '';
      _emailCtrl.text     = p['email']            ?? '';
      _direccionCtrl.text = p['direccion']        ?? '';
      _contactoCtrl.text  = p['contacto']         ?? '';
      _activo             = p['activo']            ?? true;
      _productoIds        = ((p['producto_ids'] as List?) ?? [])
          .map((e) => e as int).toSet();
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();    _apPaternoCtrl.dispose();
    _apMaternoCtrl.dispose(); _nitCtrl.dispose();
    _telefonoCtrl.dispose();  _emailCtrl.dispose();
    _direccionCtrl.dispose(); _contactoCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _cargando = true);

    final datos = <String, dynamic>{
      'nombre':           _nombreCtrl.text.trim(),
      'apellido_paterno': _apPaternoCtrl.text.trim(),
      'apellido_materno': _apMaternoCtrl.text.trim(),
      'nit':              _nitCtrl.text.trim(),
      'telefono':         _telefonoCtrl.text.trim(),
      'email':            _emailCtrl.text.trim().toLowerCase(),
      'direccion':        _direccionCtrl.text.trim(),
      'contacto':         _contactoCtrl.text.trim(),
      'activo':           _activo,
      'producto_ids':     _productoIds.toList(),
    };

    try {
      if (_esEdicion) {
        await widget.servicio
            .actualizar(widget.proveedor!['id'], datos);
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
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
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
                  top: Radius.circular(20)),
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
                  _esEdicion
                      ? 'Editar Proveedor'
                      : 'Nuevo Proveedor',
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
          Flexible(child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // Nombre + Apellido Paterno
                  Row(children: [
                    Expanded(child: _campo(
                      _nombreCtrl, 'Nombre(s) *',
                      Icons.person_outline,
                      validator: (v) {
                        final s = (v ?? '').trim();
                        if (s.length < 2) {
                          return 'Mínimo 2 caracteres';
                        }
                        if (!_regexLetras.hasMatch(s)) {
                          return 'Solo letras';
                        }
                        return null;
                      },
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _campo(
                      _apPaternoCtrl, 'Ap. Paterno *',
                      Icons.badge_outlined,
                      validator: (v) {
                        final s = (v ?? '').trim();
                        if (s.length < 2) return 'Requerido';
                        if (!_regexLetras.hasMatch(s)) {
                          return 'Solo letras';
                        }
                        return null;
                      },
                    )),
                  ]),
                  const SizedBox(height: 14),

                  // Apellido Materno
                  _campo(
                    _apMaternoCtrl,
                    'Apellido Materno (opcional)',
                    Icons.badge_outlined,
                    validator: (v) {
                      final s = (v ?? '').trim();
                      if (s.isNotEmpty &&
                          !_regexLetras.hasMatch(s)) {
                        return 'Solo letras';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // NIT + Teléfono
                  Row(children: [
                    Expanded(child: TextFormField(
                      controller: _nitCtrl,
                      maxLength: 20,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9\-]')),
                      ],
                      decoration: _deco('NIT (opcional)',
                          Icons.receipt_rounded),
                      validator: (v) {
                        final s = (v ?? '').trim();
                        if (s.isNotEmpty && s.length < 5) {
                          return 'Mínimo 5 dígitos';
                        }
                        return null;
                      },
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: TextFormField(
                      controller: _telefonoCtrl,
                      maxLength: 15,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9\+\-\s]')),
                      ],
                      decoration: _deco(
                          'Teléfono (opcional)',
                          Icons.phone_outlined),
                      validator: (v) {
                        final s = (v ?? '').trim();
                        if (s.isNotEmpty && s.length < 7) {
                          return 'Mínimo 7 dígitos';
                        }
                        return null;
                      },
                    )),
                  ]),
                  const SizedBox(height: 14),

                  // Correo
                  _campo(
                    _emailCtrl,
                    'Correo electrónico (opcional)',
                    Icons.email_outlined,
                    tipo: TextInputType.emailAddress,
                    validator: (v) {
                      final s = (v ?? '').trim();
                      if (s.isNotEmpty &&
                          (!s.contains('@') ||
                              !s.contains('.'))) {
                        return 'Correo inválido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Contacto
                  _campo(
                    _contactoCtrl,
                    'Persona de contacto (opcional)',
                    Icons.contact_phone_outlined,
                    validator: (v) {
                      final s = (v ?? '').trim();
                      if (s.isNotEmpty && s.length < 2) {
                        return 'Mínimo 2 caracteres';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Dirección
                  TextFormField(
                    controller: _direccionCtrl,
                    maxLines: 2,
                    maxLength: 300,
                    decoration: _deco(
                        'Dirección (opcional)',
                        Icons.location_on_outlined),
                    validator: (v) {
                      if ((v ?? '').trim().length > 300) {
                        return 'Máximo 300 caracteres';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Productos que provee
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Productos que provee (opcional)',
                        style: TextStyle(fontSize: 12.5,
                            color: Colors.grey.shade700)),
                  ),
                  const SizedBox(height: 6),
                  if (widget.productos.isEmpty)
                    Text('No hay productos registrados todavía.',
                        style: TextStyle(fontSize: 12.5,
                            color: Colors.grey.shade600))
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.productos.map((prod) {
                        final id = prod['id'] as int;
                        final seleccionado = _productoIds.contains(id);
                        return FilterChip(
                          label: Text(prod['nombre'] ?? ''),
                          selected: seleccionado,
                          selectedColor: ColoresCarolina.celeste.withValues(alpha: 0.15),
                          checkmarkColor: ColoresCarolina.celeste,
                          labelStyle: TextStyle(
                              fontSize: 12.5,
                              color: seleccionado
                                  ? ColoresCarolina.celesteOscuro
                                  : Colors.grey.shade800,
                              fontWeight: seleccionado
                                  ? FontWeight.w600 : FontWeight.normal),
                          onSelected: (v) => setState(() {
                            if (v) {
                              _productoIds.add(id);
                            } else {
                              _productoIds.remove(id);
                            }
                          }),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 14),

                  // Estado activo
                  Container(
                    decoration: BoxDecoration(
                        border: Border.all(
                            color: Colors.grey.shade300),
                        borderRadius:
                            BorderRadius.circular(10)),
                    child: SwitchListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(
                              horizontal: 14),
                      title: const Text('Proveedor activo',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        _activo
                            ? 'Puede recibir órdenes de compra'
                            : 'Sin actividad',
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

          // Footer
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
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
                onPressed: _cargando ? null : _guardar,
                style: ElevatedButton.styleFrom(
                    backgroundColor: ColoresCarolina.celeste,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(10))),
                child: _cargando
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2))
                    : Text(
                        _esEdicion
                            ? 'Guardar Cambios'
                            : 'Crear Proveedor',
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

  Widget _campo(
    TextEditingController ctrl,
    String label,
    IconData icono, {
    String? Function(String?)? validator,
    TextInputType? tipo,
  }) =>
      TextFormField(
        controller: ctrl,
        keyboardType: tipo,
        decoration: _deco(label, icono),
        validator: validator,
      );
}