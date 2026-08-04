// carolina/frontend/lib/pantallas/clientes/clientes_pantalla.dart
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
class ClientesServicio {
  final _auth = AuthServicio();
  Future<Map<String, String>> get _h => _auth.obtenerHeaders();

  Future<List<dynamic>> listar() async {
    final res = await http.get(Uri.parse(ApiConfig.clientes), headers: await _h);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Error al cargar clientes (${res.statusCode})');
  }

  Future<Map<String, dynamic>> crear(Map<String, dynamic> datos) async {
    final res = await http.post(Uri.parse(ApiConfig.clientes),
        headers: await _h, body: jsonEncode(datos));
    final data = jsonDecode(res.body);
    if (res.statusCode == 201) return data;
    if (data['errores'] != null) {
      throw Exception((data['errores'] as Map).values.first.toString());
    }
    throw Exception(data['error'] ?? 'Error al crear cliente');
  }

  Future<Map<String, dynamic>> actualizar(
      int id, Map<String, dynamic> datos) async {
    final res = await http.put(Uri.parse('${ApiConfig.clientes}/$id'),
        headers: await _h, body: jsonEncode(datos));
    final data = jsonDecode(res.body);
    if (res.statusCode == 200) return data;
    if (data['errores'] != null) {
      throw Exception((data['errores'] as Map).values.first.toString());
    }
    throw Exception(data['error'] ?? 'Error al actualizar');
  }

  Future<void> eliminar(int id) async {
    final res = await http.delete(
        Uri.parse('${ApiConfig.clientes}/$id'), headers: await _h);
    if (res.statusCode != 200) {
      final data = jsonDecode(res.body);
      throw Exception(data['error'] ?? 'Error al eliminar');
    }
  }
}

// ─── Pantalla ─────────────────────────────────────────────────────────────────
class ClientesPantalla extends StatefulWidget {
  const ClientesPantalla({super.key});
  @override
  State<ClientesPantalla> createState() => _ClientesPantallaState();
}

class _ClientesPantallaState extends State<ClientesPantalla> {
  final _servicio = ClientesServicio();
  List<dynamic> _clientes    = [];
  bool   _cargando           = true;
  String _busqueda           = '';
  String _filtroEstado       = 'todos';

  @override
  void initState() { super.initState(); _cargar(); }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final c = await _servicio.listar();
      setState(() => _clientes = c);
    } catch (e) {
      if (mounted) {
        Notificacion.error(context, e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  List<dynamic> get _filtrados {
    return _clientes.where((c) {
      final activo = c['activo'] as bool? ?? false;
      if (_filtroEstado == 'activos'   && !activo) return false;
      if (_filtroEstado == 'inactivos' &&  activo) return false;
      if (_busqueda.isEmpty) return true;
      final q = _busqueda.toLowerCase();
      return (c['nombre_completo'] ?? '').toLowerCase().contains(q) ||
             (c['ci_nit']          ?? '').toLowerCase().contains(q) ||
             (c['telefono']        ?? '').toLowerCase().contains(q) ||
             (c['email']           ?? '').toLowerCase().contains(q);
    }).toList();
  }

  int get _totalActivos   => _clientes.where((c) => c['activo'] == true).length;
  int get _totalInactivos => _clientes.where((c) => c['activo'] == false).length;

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
          Container(padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: colorBtn.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(icono, color: colorBtn, size: 22)),
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

  Future<void> _cambiarEstado(Map<String, dynamic> c) async {
    final activo = c['activo'] as bool? ?? false;
    final ok = await _confirmar(
      titulo:   activo ? 'Desactivar cliente' : 'Activar cliente',
      mensaje:  '¿Confirmas ${activo ? "desactivar" : "activar"} a "${c['nombre_completo']}"?',
      labelBtn: activo ? 'Sí, desactivar' : 'Sí, activar',
      colorBtn: activo ? Colors.amber.shade700 : Colors.green,
      icono:    activo ? Icons.person_off_rounded : Icons.person_rounded,
    );
    if (ok && mounted) {
      try {
        await _servicio.actualizar(c['id'], {'activo': !activo});
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

  Future<void> _eliminar(Map<String, dynamic> c) async {
    final ok = await _confirmar(
      titulo:   'Eliminar cliente',
      mensaje:  '⚠️ Se eliminará PERMANENTEMENTE a "${c['nombre_completo']}".\n\nEsta acción NO se puede deshacer.',
      labelBtn: 'Sí, eliminar',
      colorBtn: ColoresCarolina.rojo,
      icono:    Icons.delete_forever_rounded,
    );
    if (ok && mounted) {
      try {
        await _servicio.eliminar(c['id']);
        if (mounted) {
          Notificacion.exito(context, 'Cliente eliminado');
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

  void _verDetalle(Map<String, dynamic> c) =>
      showDialog(context: context,
          builder: (_) => _DetalleCliente(cliente: c));

  void _abrirFormulario({Map<String, dynamic>? cliente}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _FormularioCliente(
        cliente: cliente,
        servicio: _servicio,
        onGuardado: () {
          Navigator.pop(context);
          Notificacion.exito(context,
              cliente == null ? 'Cliente creado' : 'Cliente actualizado');
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

  Widget _buildHeader() {
    final movil = Breakpoints.esMovil(context);
    final titulo = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Gestión de Clientes',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold,
                color: ColoresCarolina.celesteOscuro)),
        const SizedBox(height: 4),
        const Text('Registra y administra la información de tus clientes.',
            style: TextStyle(fontSize: 13, color: ColoresCarolina.grisMedio)),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          _chip('${_clientes.length} total',  ColoresCarolina.celeste),
          _chip('$_totalActivos activos',     Colors.green),
          _chip('$_totalInactivos inactivos', Colors.grey),
        ]),
      ],
    );
    final boton = ElevatedButton.icon(
      onPressed: () => _abrirFormulario(),
      icon: const Icon(Icons.person_add_rounded, size: 18),
      label: const Text('Nuevo Cliente'),
      style: ElevatedButton.styleFrom(
        backgroundColor: ColoresCarolina.celeste,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
      ),
    );

    return Container(
      padding: EdgeInsets.fromLTRB(movil ? 16 : 28, 22, movil ? 16 : 28, 18),
      decoration: const BoxDecoration(color: Colors.white,
          border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0)))),
      child: movil
          ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              titulo,
              const SizedBox(height: 14),
              boton,
            ])
          : Row(children: [
              Expanded(child: titulo),
              boton,
            ]),
    );
  }

  Widget _buildBarra() {
    final movil = Breakpoints.esMovil(context);
    final buscador = TextField(
      onChanged: (v) => setState(() => _busqueda = v),
      decoration: InputDecoration(
        hintText: movil
            ? 'Buscar cliente...'
            : 'Buscar por nombre, CI/NIT, teléfono o correo...',
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
    );
    final filtros = Container(
      decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _btnFiltro('Todos',     'todos',     Icons.people_rounded),
        _btnFiltro('Activos',   'activos',   Icons.check_circle_rounded),
        _btnFiltro('Inactivos', 'inactivos', Icons.cancel_rounded),
      ]),
    );
    final refrescar = IconButton(
      onPressed: _cargar,
      icon: const Icon(Icons.refresh_rounded),
      color: ColoresCarolina.celeste,
      tooltip: 'Actualizar',
    );

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: movil ? 16 : 28, vertical: 12),
      color: Colors.white,
      child: movil
          ? Column(crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                buscador,
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    filtros,
                    const SizedBox(width: 8),
                    refrescar,
                  ]),
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
    return GestureDetector(
      onTap: () => setState(() => _filtroEstado = valor),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
            color: sel ? ColoresCarolina.celeste : Colors.transparent,
            borderRadius: BorderRadius.circular(9)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icono, size: 14,
              color: sel ? Colors.white : ColoresCarolina.grisMedio),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 12,
              fontWeight: sel ? FontWeight.bold : FontWeight.normal,
              color: sel ? Colors.white : ColoresCarolina.grisMedio)),
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
          Icon(Icons.people_outline_rounded, size: 72,
              color: ColoresCarolina.grisMedio.withValues(alpha: 0.35)),
          const SizedBox(height: 14),
          Text(_busqueda.isNotEmpty
              ? 'No hay resultados para "$_busqueda"'
              : _filtroEstado == 'inactivos'
                  ? 'No hay clientes inactivos'
                  : 'No hay clientes registrados',
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
          final c = filtrados[i];
          return _TarjetaCliente(
            cliente:    c,
            onVer:      () => _verDetalle(c),
            onEditar:   () => _abrirFormulario(cliente: c),
            onEstado:   () => _cambiarEstado(c),
            onEliminar: () => _eliminar(c),
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
                _th('CLIENTE',   4),
                _th('CI/NIT',    2),
                _th('TELÉFONO',  2),
                _th('CORREO',    3),
                _th('ESTADO',    2),
                _th('ACCIONES',  3),
              ]),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            ...filtrados.asMap().entries.map((e) {
              final c = e.value;
              return Column(children: [
                _FilaCliente(
                  cliente:    c,
                  impar:      e.key.isOdd,
                  onVer:      () => _verDetalle(c),
                  onEditar:   () => _abrirFormulario(cliente: c),
                  onEstado:   () => _cambiarEstado(c),
                  onEliminar: () => _eliminar(c),
                ),
                if (e.key < filtrados.length - 1)
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
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
          color: ColoresCarolina.grisMedio, letterSpacing: 0.8)));

  Widget _chip(String t, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20)),
    child: Text(t, style: TextStyle(fontSize: 11, color: c,
        fontWeight: FontWeight.w600)),
  );
}

// ─── Fila ─────────────────────────────────────────────────────────────────────
class _FilaCliente extends StatelessWidget {
  final Map<String, dynamic> cliente;
  final bool impar;
  final VoidCallback onVer, onEditar, onEstado, onEliminar;

  const _FilaCliente({
    required this.cliente, required this.impar,
    required this.onVer,   required this.onEditar,
    required this.onEstado, required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    final activo = cliente['activo'] as bool? ?? false;
    final nombre = cliente['nombre_completo'] as String? ?? '-';
    final inicial = nombre.isNotEmpty ? nombre[0].toUpperCase() : 'C';

    return Container(
      color: impar ? const Color(0xFFFAFBFF) : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(children: [
        // Cliente
        Expanded(flex: 4, child: Row(children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: ColoresCarolina.celeste.withValues(alpha: 0.15),
            child: Text(inicial,
                style: const TextStyle(color: ColoresCarolina.celeste,
                    fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(nombre, style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13),
                  overflow: TextOverflow.ellipsis),
              if (!activo)
                const Text('Inactivo', style: TextStyle(
                    fontSize: 10, color: Colors.grey)),
            ],
          )),
        ])),
        // CI/NIT
        Expanded(flex: 2, child: Text(
            cliente['ci_nit'] ?? '-',
            style: const TextStyle(fontSize: 13,
                color: Color(0xFF475569)),
            overflow: TextOverflow.ellipsis)),
        // Teléfono
        Expanded(flex: 2, child: Text(
            cliente['telefono'] ?? '-',
            style: const TextStyle(fontSize: 13,
                color: Color(0xFF475569)))),
        // Correo
        Expanded(flex: 3, child: Text(
            cliente['email'] ?? '-',
            style: const TextStyle(fontSize: 13,
                color: Color(0xFF475569)),
            overflow: TextOverflow.ellipsis)),
        // Estado
        Expanded(flex: 2, child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 8, height: 8,
                decoration: BoxDecoration(shape: BoxShape.circle,
                    color: activo ? Colors.green : Colors.grey)),
            const SizedBox(width: 6),
            Text(activo ? 'Activo' : 'Inactivo',
                style: TextStyle(fontSize: 13,
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
            _btn(Icons.edit_rounded, Colors.orange, 'Editar', onEditar),
            const SizedBox(width: 4),
            _btn(
              activo ? Icons.person_off_rounded : Icons.person_rounded,
              activo ? Colors.amber.shade700    : Colors.green,
              activo ? 'Desactivar'             : 'Activar',
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
      Tooltip(message: tip,
        child: InkWell(onTap: fn, borderRadius: BorderRadius.circular(8),
          child: Container(padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(i, size: 16, color: c))));
}

// ─── Tarjeta (vista móvil) ──────────────────────────────────────────────────────
class _TarjetaCliente extends StatelessWidget {
  final Map<String, dynamic> cliente;
  final VoidCallback onVer, onEditar, onEstado, onEliminar;

  const _TarjetaCliente({
    required this.cliente, required this.onVer,
    required this.onEditar, required this.onEstado,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    final activo = cliente['activo'] as bool? ?? false;
    final nombre = cliente['nombre_completo'] as String? ?? '-';
    final inicial = nombre.isNotEmpty ? nombre[0].toUpperCase() : 'C';

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
          CircleAvatar(
            radius: 20,
            backgroundColor: ColoresCarolina.celeste.withValues(alpha: 0.15),
            child: Text(inicial,
                style: const TextStyle(color: ColoresCarolina.celeste,
                    fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(nombre,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              overflow: TextOverflow.ellipsis)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: (activo ? Colors.green : Colors.grey)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20)),
            child: Text(activo ? 'Activo' : 'Inactivo',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                    color: activo ? Colors.green : Colors.grey)),
          ),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 16, runSpacing: 8, children: [
          _dato(Icons.badge_rounded, 'CI/NIT', cliente['ci_nit'] ?? '-'),
          _dato(Icons.phone_outlined, 'Teléfono', cliente['telefono'] ?? '-'),
          _dato(Icons.email_outlined, 'Correo', cliente['email'] ?? '-'),
        ]),
        const SizedBox(height: 12),
        const Divider(height: 1, color: ColoresCarolina.borde),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          _btn(Icons.visibility_rounded, ColoresCarolina.celeste, 'Ver', onVer),
          const SizedBox(width: 6),
          _btn(Icons.edit_rounded, Colors.orange, 'Editar', onEditar),
          const SizedBox(width: 6),
          _btn(
            activo ? Icons.person_off_rounded : Icons.person_rounded,
            activo ? Colors.amber.shade700    : Colors.green,
            activo ? 'Desactivar'             : 'Activar',
            onEstado,
          ),
          const SizedBox(width: 6),
          _btn(Icons.delete_rounded, ColoresCarolina.rojo, 'Eliminar', onEliminar),
        ]),
      ]),
    );
  }

  Widget _dato(IconData i, String label, String valor) => SizedBox(
    width: 150,
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(i, size: 14, color: ColoresCarolina.grisMedio),
      const SizedBox(width: 6),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10,
              color: ColoresCarolina.grisMedio)),
          Text(valor, style: const TextStyle(fontSize: 12,
              fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis),
        ],
      )),
    ]),
  );

  Widget _btn(IconData i, Color c, String tip, VoidCallback fn) =>
      Tooltip(message: tip,
        child: InkWell(onTap: fn, borderRadius: BorderRadius.circular(8),
          child: Container(padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(i, size: 16, color: c))));
}

// ─── Detalle ──────────────────────────────────────────────────────────────────
class _DetalleCliente extends StatelessWidget {
  final Map<String, dynamic> cliente;
  const _DetalleCliente({required this.cliente});

  @override
  Widget build(BuildContext context) {
    final activo = cliente['activo'] as bool? ?? false;
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
            child: Column(children: [
              CircleAvatar(
                radius: 38,
                backgroundColor: Colors.white.withValues(alpha: 0.25),
                child: Text(
                  (cliente['nombre'] as String? ?? 'C')[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white,
                      fontWeight: FontWeight.bold, fontSize: 30),
                ),
              ),
              const SizedBox(height: 10),
              Text(cliente['nombre_completo'] ?? '',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white,
                      fontWeight: FontWeight.bold, fontSize: 17)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(activo ? 'ACTIVO' : 'INACTIVO',
                    style: const TextStyle(color: Colors.white,
                        fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ]),
          ),
          // Datos
          Flexible(child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Column(children: [
              _fila(Icons.person_outline,     'Nombre',      cliente['nombre']           ?? '-'),
              _fila(Icons.badge_outlined,     'Ap. Paterno', cliente['apellido_paterno'] ?? '-'),
              _fila(Icons.badge_outlined,     'Ap. Materno', cliente['apellido_materno'] ?? '-'),
              _fila(Icons.badge_rounded,      'CI/NIT',      cliente['ci_nit']           ?? '-'),
              _fila(Icons.phone_outlined,     'Teléfono',    cliente['telefono']         ?? '-'),
              _fila(Icons.email_outlined,     'Correo',      cliente['email']            ?? '-'),
              _fila(Icons.location_on_outlined,'Dirección',  cliente['direccion']        ?? '-'),
              // Estado
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(children: [
                  Icon(activo
                      ? Icons.check_circle_rounded
                      : Icons.cancel_rounded,
                      size: 18,
                      color: activo ? Colors.green : Colors.grey),
                  const SizedBox(width: 12),
                  const SizedBox(width: 110,
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
                    child: Text(activo ? 'Activo' : 'Inactivo',
                        style: TextStyle(fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: activo ? Colors.green : Colors.grey)),
                  ),
                ]),
              ),
            ]),
          )),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
            child: SizedBox(width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                    backgroundColor: ColoresCarolina.celeste,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
                child: const Text('Cerrar',
                    style: TextStyle(fontWeight: FontWeight.bold)),
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
      SizedBox(width: 110, child: Text(l,
          style: const TextStyle(color: ColoresCarolina.grisMedio,
              fontSize: 13))),
      Expanded(child: Text(v,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          overflow: TextOverflow.ellipsis)),
    ]),
  );
}

// ─── Formulario ───────────────────────────────────────────────────────────────
class _FormularioCliente extends StatefulWidget {
  final Map<String, dynamic>? cliente;
  final ClientesServicio       servicio;
  final VoidCallback           onGuardado;

  const _FormularioCliente({
    this.cliente,
    required this.servicio,
    required this.onGuardado,
  });

  @override
  State<_FormularioCliente> createState() => _FormularioClienteState();
}

class _FormularioClienteState extends State<_FormularioCliente> {
  final _formKey       = GlobalKey<FormState>();
  final _nombreCtrl    = TextEditingController();
  final _apPaternoCtrl = TextEditingController();
  final _apMaternoCtrl = TextEditingController();
  final _ciNitCtrl     = TextEditingController();
  final _telefonoCtrl  = TextEditingController();
  final _emailCtrl     = TextEditingController();
  final _direccionCtrl = TextEditingController();

  bool _activo   = true;
  bool _cargando = false;

  bool get _esEdicion => widget.cliente != null;

  // Solo letras y espacios para nombres
  final _regexLetras = RegExp(r"^[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ\s'\-]+$");

  @override
  void initState() {
    super.initState();
    if (_esEdicion) {
      final c = widget.cliente!;
      _nombreCtrl.text    = c['nombre']           ?? '';
      _apPaternoCtrl.text = c['apellido_paterno'] ?? '';
      _apMaternoCtrl.text = c['apellido_materno'] ?? '';
      _ciNitCtrl.text     = c['ci_nit']           ?? '';
      _telefonoCtrl.text  = c['telefono']         ?? '';
      _emailCtrl.text     = c['email']            ?? '';
      _direccionCtrl.text = c['direccion']        ?? '';
      _activo             = c['activo']            ?? true;
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();    _apPaternoCtrl.dispose();
    _apMaternoCtrl.dispose(); _ciNitCtrl.dispose();
    _telefonoCtrl.dispose();  _emailCtrl.dispose();
    _direccionCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _cargando = true);

    final datos = <String, dynamic>{
      'nombre':           _nombreCtrl.text.trim(),
      'apellido_paterno': _apPaternoCtrl.text.trim(),
      'apellido_materno': _apMaternoCtrl.text.trim(),
      'ci_nit':           _ciNitCtrl.text.trim(),
      'telefono':         _telefonoCtrl.text.trim(),
      'email':            _emailCtrl.text.trim().toLowerCase(),
      'direccion':        _direccionCtrl.text.trim(),
      'activo':           _activo,
    };

    try {
      if (_esEdicion) {
        await widget.servicio.actualizar(widget.cliente!['id'], datos);
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
        constraints: const BoxConstraints(maxWidth: 560),
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
              Icon(_esEdicion
                  ? Icons.edit_rounded
                  : Icons.person_add_rounded,
                  color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Text(_esEdicion ? 'Editar Cliente' : 'Nuevo Cliente',
                  style: const TextStyle(color: Colors.white,
                      fontSize: 17, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white)),
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
                  _filaOColumna([
                    _campo(
                      _nombreCtrl, 'Nombre(s) *',
                      Icons.person_outline,
                      validator: (v) {
                        final s = (v ?? '').trim();
                        if (s.length < 2) return 'Mínimo 2 caracteres';
                        if (!_regexLetras.hasMatch(s)) return 'Solo letras';
                        return null;
                      },
                    ),
                    _campo(
                      _apPaternoCtrl, 'Ap. Paterno *',
                      Icons.badge_outlined,
                      validator: (v) {
                        final s = (v ?? '').trim();
                        if (s.length < 2) return 'Requerido';
                        if (!_regexLetras.hasMatch(s)) return 'Solo letras';
                        return null;
                      },
                    ),
                  ]),
                  const SizedBox(height: 14),

                  // Apellido Materno
                  _campo(
                    _apMaternoCtrl,
                    'Apellido Materno (opcional)',
                    Icons.badge_outlined,
                    validator: (v) {
                      final s = (v ?? '').trim();
                      if (s.isNotEmpty && !_regexLetras.hasMatch(s)) {
                        return 'Solo letras';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // CI/NIT + Teléfono
                  _filaOColumna([
                    TextFormField(
                      controller: _ciNitCtrl,
                      maxLength: 20,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9\-A-Za-z]')),
                      ],
                      decoration: _deco(
                          'CI / NIT (opcional)',
                          Icons.badge_rounded),
                      validator: (v) {
                        final s = (v ?? '').trim();
                        if (s.isNotEmpty && s.length < 5) {
                          return 'Mínimo 5 caracteres';
                        }
                        return null;
                      },
                    ),
                    TextFormField(
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
                    ),
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
                          (!s.contains('@') || !s.contains('.'))) {
                        return 'Correo inválido';
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

                  // Estado activo
                  Container(
                    decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(10)),
                    child: SwitchListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 14),
                      title: const Text('Cliente activo',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        _activo
                            ? 'Puede realizar compras'
                            : 'Sin acceso al sistema',
                        style: TextStyle(
                            fontSize: 12,
                            color: _activo
                                ? Colors.green
                                : ColoresCarolina.rojo),
                      ),
                      value: _activo,
                      activeTrackColor: ColoresCarolina.celeste,
                      onChanged: (v) => setState(() => _activo = v),
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
                    : Text(_esEdicion ? 'Guardar Cambios' : 'Crear Cliente',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
              )),
            ]),
          ),
        ]),
      ),
    );
  }

  // En móvil apila los campos en columna; en tablet/escritorio los pone en fila.
  Widget _filaOColumna(List<Widget> campos) {
    if (Breakpoints.esMovil(context)) {
      return Column(children: [
        for (final c in campos) ...[
          c,
          if (c != campos.last) const SizedBox(height: 14),
        ],
      ]);
    }
    return Row(children: [
      for (final c in campos) ...[
        Expanded(child: c),
        if (c != campos.last) const SizedBox(width: 12),
      ],
    ]);
  }

  InputDecoration _deco(String l, IconData i) => InputDecoration(
    labelText: l,
    prefixIcon: Icon(i, color: ColoresCarolina.celeste),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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