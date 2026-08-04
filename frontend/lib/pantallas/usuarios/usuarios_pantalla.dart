// carolina/frontend/lib/pantallas/usuarios/usuarios_pantalla.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../constantes/colores.dart';
import '../../constantes/api.dart';
import '../../constantes/breakpoints.dart';
import '../../servicios/usuarios_servicio.dart';
import '../../servicios/auth_servicio.dart';
import '../../widgets/notificacion.dart';

class UsuariosPantalla extends StatefulWidget {
  const UsuariosPantalla({super.key});
  @override
  State<UsuariosPantalla> createState() => _UsuariosPantallaState();
}

class _UsuariosPantallaState extends State<UsuariosPantalla> {
  final _servicio     = UsuariosServicio();
  List<dynamic> _todos  = [];
  List<dynamic> _roles  = [];
  bool   _cargando      = true;
  String _busqueda      = '';
  String _filtroEstado  = 'todos';

  @override
  void initState() { super.initState(); _cargar(); }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final u = await _servicio.listar();
      final r = await _servicio.listarRoles();
      setState(() { _todos = u; _roles = r; });
    } catch (e) {
      if (mounted) Notificacion.error(context, e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  List<dynamic> get _filtrados {
    return _todos.where((u) {
      final activo = u['activo'] as bool? ?? false;
      if (_filtroEstado == 'activos'   && !activo) return false;
      if (_filtroEstado == 'inactivos' &&  activo) return false;
      if (_busqueda.isEmpty) return true;
      final q = _busqueda.toLowerCase();
      return (u['nombre_completo'] ?? '').toLowerCase().contains(q) ||
             (u['email']          ?? '').toLowerCase().contains(q) ||
             (u['rol']            ?? '').toLowerCase().contains(q);
    }).toList();
  }

  int get _totalActivos   => _todos.where((u) => u['activo'] == true).length;
  int get _totalInactivos => _todos.where((u) => u['activo'] == false).length;

  static Color colorRol(String? rol) {
    switch (rol) {
      case 'admin':      return ColoresCarolina.rojo;
      case 'vendedor':   return Colors.green;
      case 'almacenero': return Colors.orange;
      default:           return ColoresCarolina.grisMedio;
    }
  }

  static String urlFoto(String foto) =>
      '${ApiConfig.baseUrl.replaceAll('/api', '')}$foto';

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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: colorBtn.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(icono, color: colorBtn, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(titulo, style: const TextStyle(fontSize: 16))),
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

  Future<void> _cambiarEstado(Map<String, dynamic> u) async {
    final activo = u['activo'] as bool? ?? false;
    final ok = await _confirmar(
      titulo:   activo ? 'Desactivar usuario' : 'Activar usuario',
      mensaje:  '¿Confirmas que deseas ${activo ? "desactivar" : "activar"} a "${u['nombre_completo']}"?',
      labelBtn: activo ? 'Sí, desactivar' : 'Sí, activar',
      colorBtn: activo ? Colors.amber.shade700 : Colors.green,
      icono:    activo ? Icons.person_off_rounded : Icons.person_rounded,
    );
    if (ok && mounted) {
      try {
        await _servicio.actualizar(u['id'], {'activo': !activo});
        if (mounted) { Notificacion.exito(context, 'Estado actualizado'); _cargar(); }
      } catch (e) {
        if (mounted) Notificacion.error(context, e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  Future<void> _eliminar(Map<String, dynamic> u) async {
    final ok = await _confirmar(
      titulo:   'Eliminar usuario',
      mensaje:  'Se eliminará permanentemente a "${u['nombre_completo']}".\n\nEsta acción NO se puede deshacer.',
      labelBtn: 'Sí, eliminar',
      colorBtn: ColoresCarolina.rojo,
      icono:    Icons.delete_forever_rounded,
    );
    if (ok && mounted) {
      try {
        await _servicio.eliminar(u['id']);
        if (mounted) { Notificacion.exito(context, 'Usuario eliminado'); _cargar(); }
      } catch (e) {
        if (mounted) Notificacion.error(context, e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  void _verDetalle(Map<String, dynamic> u) =>
      showDialog(context: context,
          builder: (_) => _DetalleUsuario(usuario: u));

  void _abrirFormulario({Map<String, dynamic>? usuario}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _FormularioUsuario(
        usuario: usuario,
        roles: _roles,
        onGuardado: () {
          Navigator.pop(context);
          Notificacion.exito(context,
              usuario == null ? 'Usuario creado' : 'Usuario actualizado');
          _cargar();
        },
      ),
    );
  }

@override
Widget build(BuildContext context) {
  final filtrados = _filtrados;
  return Column(  // <-- Ya NO es Scaffold, es Column directamente
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
          const Text('Gestión de Usuarios',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold,
                  color: ColoresCarolina.celesteOscuro)),
          const SizedBox(height: 4),
          const Text(
              'Administra las cuentas del sistema, sus roles y '
              'el acceso de cada empleado.',
              style: TextStyle(
                  fontSize: 13, color: ColoresCarolina.grisMedio)),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            _chip('${_todos.length} total',     ColoresCarolina.celeste),
            _chip('$_totalActivos activos',     Colors.green),
            _chip('$_totalInactivos inactivos', Colors.grey),
          ]),
        ],
      )),
      ElevatedButton.icon(
        onPressed: () => _abrirFormulario(),
        icon: const Icon(Icons.person_add_rounded, size: 18),
        label: const Text('Nuevo Usuario'),
        style: ElevatedButton.styleFrom(
          backgroundColor: ColoresCarolina.celeste,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
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
          hintText: 'Buscar por nombre, correo o rol...',
          prefixIcon: const Icon(Icons.search_rounded, color: ColoresCarolina.celeste),
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
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      )),
      const SizedBox(width: 12),
      Container(
        decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _btnFiltro('Todos',     'todos',     Icons.people_rounded),
          _btnFiltro('Activos',   'activos',   Icons.check_circle_rounded),
          _btnFiltro('Inactivos', 'inactivos', Icons.cancel_rounded),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
            color: sel ? ColoresCarolina.celeste : Colors.transparent,
            borderRadius: BorderRadius.circular(9)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icono, size: 14,
              color: sel ? Colors.white : ColoresCarolina.grisMedio),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                  color: sel ? Colors.white : ColoresCarolina.grisMedio)),
        ]),
      ),
    );
  }

  Widget _buildCuerpo(List<dynamic> filtrados) {
    if (_cargando) {
      return const Center(
          child: CircularProgressIndicator(color: ColoresCarolina.celeste));
    }
    if (filtrados.isEmpty) {
      return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline_rounded, size: 72,
              color: ColoresCarolina.grisMedio.withValues(alpha: 0.35)),
          const SizedBox(height: 14),
          Text(
            _busqueda.isNotEmpty
                ? 'No hay resultados para "$_busqueda"'
                : _filtroEstado == 'inactivos'
                    ? 'No hay usuarios inactivos'
                    : 'No hay usuarios registrados',
            style: const TextStyle(
                color: ColoresCarolina.grisMedio, fontSize: 15),
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
          final u = filtrados[i];
          return _TarjetaUsuarioMovil(
            usuario:    u,
            onVer:      () => _verDetalle(u),
            onEditar:   () => _abrirFormulario(usuario: u),
            onEstado:   () => _cambiarEstado(u),
            onEliminar: () => _eliminar(u),
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
            // Cabecera
            Container(
              color: const Color(0xFFF8FAFC),
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 14),
              child: Row(children: [
                _th('USUARIO',  4),
                _th('CORREO',   3),
                _th('ROL',      2),
                _th('ESTADO',   2),
                _th('ACCIONES', 3),
              ]),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            // Filas
            ...filtrados.asMap().entries.map((e) {
              final u = e.value;
              return Column(children: [
                _FilaUsuario(
                  usuario:    u,
                  impar:      e.key.isOdd,
                  onVer:      () => _verDetalle(u),
                  onEditar:   () => _abrirFormulario(usuario: u),
                  onEstado:   () => _cambiarEstado(u),
                  onEliminar: () => _eliminar(u),
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

  Widget _th(String t, int flex) => Expanded(
    flex: flex,
    child: Text(t,
        style: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.bold,
            color: ColoresCarolina.grisMedio, letterSpacing: 0.8)),
  );

  Widget _chip(String t, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20)),
    child: Text(t,
        style: TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.w600)),
  );
}

// ── Fila ──────────────────────────────────────────────────────────────────────
class _FilaUsuario extends StatelessWidget {
  final Map<String, dynamic> usuario;
  final bool         impar;
  final VoidCallback onVer, onEditar, onEstado, onEliminar;

  const _FilaUsuario({
    required this.usuario,
    required this.impar,
    required this.onVer,
    required this.onEditar,
    required this.onEstado,
    required this.onEliminar,
  });

  Color get _cRol => _UsuariosPantallaState.colorRol(usuario['rol'] as String?);

  ImageProvider? get _imgProvider {
    final foto = usuario['foto'] as String?;
    if (foto == null || foto.isEmpty) return null;
    return NetworkImage(_UsuariosPantallaState.urlFoto(foto));
  }

  @override
  Widget build(BuildContext context) {
    final activo = usuario['activo'] as bool? ?? false;
    final rol    = usuario['rol']    as String?;

    return Container(
      color: impar ? const Color(0xFFFAFBFF) : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(children: [
        // Usuario
        Expanded(flex: 4, child: Row(children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: _cRol.withValues(alpha: 0.15),
            backgroundImage: _imgProvider,
            child: _imgProvider == null
                ? Text(
                    (usuario['nombre'] as String? ?? 'U')[0].toUpperCase(),
                    style: TextStyle(color: _cRol,
                        fontWeight: FontWeight.bold, fontSize: 15))
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(usuario['nombre_completo'] ?? '',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13),
                  overflow: TextOverflow.ellipsis),
              if (!activo)
                const Text('Inactivo',
                    style: TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          )),
        ])),
        // Correo
        Expanded(flex: 3, child: Text(usuario['email'] ?? '',
            style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
            overflow: TextOverflow.ellipsis)),
        // Rol
        Expanded(flex: 2, child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
              color: _cRol.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20)),
          child: Text((rol ?? '-').toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11,
                  fontWeight: FontWeight.bold, color: _cRol)),
        )),
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
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: activo ? Colors.green : Colors.grey)),
          ],
        )),
        // Acciones
        Expanded(flex: 3, child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _accion(Icons.visibility_rounded,
                ColoresCarolina.celeste, 'Ver detalle', onVer),
            const SizedBox(width: 4),
            _accion(Icons.edit_rounded,
                Colors.orange, 'Editar', onEditar),
            const SizedBox(width: 4),
            _accion(
              activo ? Icons.person_off_rounded : Icons.person_rounded,
              activo ? Colors.amber.shade700    : Colors.green,
              activo ? 'Desactivar'             : 'Activar',
              onEstado,
            ),
            const SizedBox(width: 4),
            _accion(Icons.delete_rounded,
                ColoresCarolina.rojo, 'Eliminar', onEliminar),
          ],
        )),
      ]),
    );
  }

  Widget _accion(IconData i, Color c, String tip, VoidCallback fn) =>
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
}

// ── Tarjeta móvil ─────────────────────────────────────────────────────────────
class _TarjetaUsuarioMovil extends StatelessWidget {
  final Map<String, dynamic> usuario;
  final VoidCallback onVer, onEditar, onEstado, onEliminar;

  const _TarjetaUsuarioMovil({
    required this.usuario, required this.onVer,
    required this.onEditar,  required this.onEstado,
    required this.onEliminar,
  });

  Color get _cRol => _UsuariosPantallaState.colorRol(usuario['rol'] as String?);

  ImageProvider? get _imgProvider {
    final foto = usuario['foto'] as String?;
    if (foto == null || foto.isEmpty) return null;
    return NetworkImage(_UsuariosPantallaState.urlFoto(foto));
  }

  @override
  Widget build(BuildContext context) {
    final activo = usuario['activo'] as bool? ?? false;
    final rol    = usuario['rol']    as String?;

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
              backgroundColor: _cRol.withValues(alpha: 0.15),
              backgroundImage: _imgProvider,
              child: _imgProvider == null
                  ? Text(
                      (usuario['nombre'] as String? ?? 'U')[0].toUpperCase(),
                      style: TextStyle(color: _cRol,
                          fontWeight: FontWeight.bold, fontSize: 15))
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(usuario['nombre_completo'] ?? '',
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
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: _cRol.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20)),
              child: Text((rol ?? '-').toUpperCase(),
                  style: TextStyle(fontSize: 11,
                      fontWeight: FontWeight.bold, color: _cRol)),
            ),
            if ((usuario['email'] as String?)?.isNotEmpty == true)
              _dato(Icons.email_outlined, usuario['email']),
          ]),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _accion(Icons.visibility_rounded,
                  ColoresCarolina.celeste, 'Ver detalle', onVer),
              const SizedBox(width: 6),
              _accion(Icons.edit_rounded, Colors.orange, 'Editar', onEditar),
              const SizedBox(width: 6),
              _accion(
                activo
                    ? Icons.person_off_rounded
                    : Icons.person_rounded,
                activo ? Colors.amber.shade700 : Colors.green,
                activo ? 'Desactivar' : 'Activar',
                onEstado,
              ),
              const SizedBox(width: 6),
              _accion(Icons.delete_rounded,
                  ColoresCarolina.rojo, 'Eliminar', onEliminar),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dato(IconData icono, String? valor) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icono, size: 14, color: ColoresCarolina.grisMedio),
      const SizedBox(width: 5),
      Text(valor ?? '-',
          style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
    ]),
  );

  Widget _accion(IconData i, Color c, String tip, VoidCallback fn) =>
      Tooltip(
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

// ── Detalle ───────────────────────────────────────────────────────────────────
class _DetalleUsuario extends StatelessWidget {
  final Map<String, dynamic> usuario;
  const _DetalleUsuario({required this.usuario});

  Color get _cRol =>
      _UsuariosPantallaState.colorRol(usuario['rol'] as String?);

  ImageProvider get _avatarProvider {
    final foto = usuario['foto'] as String?;
    if (foto != null && foto.isNotEmpty) {
      return NetworkImage(_UsuariosPantallaState.urlFoto(foto));
    }
    return const AssetImage('');
  }

  bool get _tieneFoto {
    final foto = usuario['foto'] as String?;
    return foto != null && foto.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final rol    = usuario['rol']    as String?;
    final activo = usuario['activo'] as bool? ?? false;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [_cRol, _cRol.withValues(alpha: 0.75)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.white.withValues(alpha: 0.25),
                backgroundImage: _tieneFoto ? _avatarProvider : null,
                child: !_tieneFoto
                    ? Text(
                        (usuario['nombre'] as String? ?? 'U')[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white,
                            fontWeight: FontWeight.bold, fontSize: 30))
                    : null,
              ),
              const SizedBox(height: 10),
              Text(usuario['nombre_completo'] ?? '',
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
                child: Text((rol ?? '').toUpperCase(),
                    style: const TextStyle(color: Colors.white,
                        fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ]),
          ),
          // Datos
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Column(children: [
              _f(Icons.person_outline,  'Nombre',
                  usuario['nombre']           ?? '-'),
              _f(Icons.badge_outlined,  'Ap. Paterno',
                  usuario['apellido_paterno'] ?? '-'),
              _f(Icons.badge_outlined,  'Ap. Materno',
                  usuario['apellido_materno'] ?? '-'),
              _f(Icons.email_outlined,  'Correo',
                  usuario['email']            ?? '-'),
              _f(Icons.shield_outlined, 'Rol',
                  (rol ?? '-').toUpperCase()),
              // Estado
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
                    child: Text(activo ? 'Activo' : 'Inactivo',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: activo ? Colors.green : Colors.grey)),
                  ),
                ]),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
            child: SizedBox(
              width: double.infinity,
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

  Widget _f(IconData i, String l, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(children: [
      Icon(i, size: 18, color: ColoresCarolina.celeste),
      const SizedBox(width: 12),
      SizedBox(
          width: 110,
          child: Text(l,
              style: const TextStyle(
                  color: ColoresCarolina.grisMedio, fontSize: 13))),
      Expanded(
          child: Text(v,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13),
              overflow: TextOverflow.ellipsis)),
    ]),
  );
}

// ── Formulario ────────────────────────────────────────────────────────────────
class _FormularioUsuario extends StatefulWidget {
  final Map<String, dynamic>? usuario;
  final List<dynamic>         roles;
  final VoidCallback          onGuardado;

  const _FormularioUsuario({
    this.usuario,
    required this.roles,
    required this.onGuardado,
  });

  @override
  State<_FormularioUsuario> createState() => _FormularioUsuarioState();
}

class _FormularioUsuarioState extends State<_FormularioUsuario> {
  final _formKey       = GlobalKey<FormState>();
  final _nombreCtrl    = TextEditingController();
  final _apPaternoCtrl = TextEditingController();
  final _apMaternoCtrl = TextEditingController();
  final _emailCtrl     = TextEditingController();
  final _passCtrl      = TextEditingController();
  final _servicio      = UsuariosServicio();
  final _auth          = AuthServicio();

  int?       _rolId;
  bool       _activo          = true;
  bool       _verPass         = false;
  bool       _cargando        = false;
  bool       _cambiarPassword = false;
  Uint8List? _fotoBytes;
  XFile?     _fotoFile;

  bool get _tieneMinimo    => _passCtrl.text.length >= 8;
  bool get _tieneMayuscula =>
      _passCtrl.text.contains(RegExp(r'[A-Z]'));
  bool get _tieneNumero    =>
      _passCtrl.text.contains(RegExp(r'[0-9]'));
  bool get _tieneEspecial  =>
      _passCtrl.text.contains(RegExp(r'[!@#\$%^&*(),.?:{}|<>_\-]'));
  bool get _esEdicion      => widget.usuario != null;

  final _regexLetras =
      RegExp(r"^[a-zA-ZáéíóúÁÉÍÓÚñÑüÜ\s'\-]+$");

  @override
  void initState() {
    super.initState();
    if (_esEdicion) {
      final u = widget.usuario!;
      _nombreCtrl.text    = u['nombre']           ?? '';
      _apPaternoCtrl.text = u['apellido_paterno'] ?? '';
      _apMaternoCtrl.text = u['apellido_materno'] ?? '';
      _emailCtrl.text     = u['email']            ?? '';
      _rolId              = u['rol_id'] as int?;
      _activo             = u['activo'] as bool? ?? true;
    } else {
      if (widget.roles.isNotEmpty) {
        _rolId = widget.roles.first['id'] as int;
      }
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _apPaternoCtrl.dispose();
    _apMaternoCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _seleccionarFoto() async {
    final img = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (img != null) {
      final bytes = await img.readAsBytes();
      setState(() { _fotoFile = img; _fotoBytes = bytes; });
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _cargando = true);

    final datos = <String, dynamic>{
      'nombre':           _nombreCtrl.text.trim(),
      'apellido_paterno': _apPaternoCtrl.text.trim(),
      'apellido_materno': _apMaternoCtrl.text.trim(),
      'email':            _emailCtrl.text.trim().toLowerCase(),
      'rol_id':           _rolId,
      'activo':           _activo,
    };
    if (!_esEdicion || _cambiarPassword) {
      datos['password'] = _passCtrl.text;
    }

    try {
      Map<String, dynamic> result;
      if (_esEdicion) {
        result = await _servicio.actualizar(
            widget.usuario!['id'], datos);
      } else {
        result = await _servicio.crear(datos);
      }
      if (_fotoFile != null) {
        final id = (result['id'] ?? widget.usuario?['id']) as int?;
        if (id != null) {
          final headers = await _auth.obtenerHeaders();
          await _servicio.subirFoto(id, _fotoFile!, headers);
        }
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

  ImageProvider? _fotoPreview(String? fotoActual) {
    if (_fotoBytes != null) return MemoryImage(_fotoBytes!);
    if (fotoActual != null && fotoActual.isNotEmpty) {
      return NetworkImage(
          _UsuariosPantallaState.urlFoto(fotoActual));
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final fotoActual =
        _esEdicion ? (widget.usuario!['foto'] as String?) : null;
    final preview = _fotoPreview(fotoActual);

    return Dialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
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
                borderRadius: BorderRadius.vertical(
                    top: Radius.circular(20)),
              ),
              child: Row(children: [
                Icon(
                    _esEdicion
                        ? Icons.edit_rounded
                        : Icons.person_add_rounded,
                    color: Colors.white,
                    size: 22),
                const SizedBox(width: 10),
                Text(
                    _esEdicion ? 'Editar Usuario' : 'Nuevo Usuario',
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

            // Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Selector foto
                      Center(child: Column(children: [
                        GestureDetector(
                          onTap: _seleccionarFoto,
                          child: Stack(children: [
                            CircleAvatar(
                              radius: 48,
                              backgroundColor: ColoresCarolina.grisClaro,
                              backgroundImage: preview,
                              child: preview == null
                                  ? const Icon(Icons.person,
                                      size: 48,
                                      color: ColoresCarolina.celeste)
                                  : null,
                            ),
                            Positioned(
                              bottom: 0, right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                    color: ColoresCarolina.celeste,
                                    shape: BoxShape.circle),
                                child: const Icon(Icons.camera_alt,
                                    color: Colors.white, size: 16),
                              ),
                            ),
                          ]),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _fotoBytes != null
                              ? 'Foto seleccionada ✓'
                              : 'Toca para agregar foto',
                          style: TextStyle(
                              fontSize: 12,
                              color: _fotoBytes != null
                                  ? Colors.green
                                  : ColoresCarolina.grisMedio),
                        ),
                      ])),
                      const SizedBox(height: 20),

                      // Nombre + Ap. Paterno
                      Row(children: [
                        Expanded(child: _campo(
                          _nombreCtrl, 'Nombre(s)',
                          Icons.person_outline,
                          validator: (v) {
                            final s = (v ?? '').trim();
                            if (s.length < 2) return 'Mínimo 2 caracteres';
                            if (!_regexLetras.hasMatch(s)) return 'Solo letras';
                            return null;
                          },
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: _campo(
                          _apPaternoCtrl, 'Ap. Paterno',
                          Icons.badge_outlined,
                          validator: (v) {
                            final s = (v ?? '').trim();
                            if (s.length < 2) return 'Requerido';
                            if (!_regexLetras.hasMatch(s)) return 'Solo letras';
                            return null;
                          },
                        )),
                      ]),
                      const SizedBox(height: 14),

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

                      _campo(
                        _emailCtrl, 'Correo electrónico',
                        Icons.email_outlined,
                        tipo: TextInputType.emailAddress,
                        validator: (v) {
                          final s = (v ?? '').trim();
                          if (s.isEmpty) return 'Requerido';
                          if (!s.contains('@') || !s.contains('.')) {
                            return 'Correo inválido';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      DropdownButtonFormField<int>(
                        initialValue: _rolId,
                        decoration: _deco(
                            'Rol', Icons.admin_panel_settings_outlined),
                        items: widget.roles
                            .map<DropdownMenuItem<int>>((r) =>
                                DropdownMenuItem(
                                  value: r['id'] as int,
                                  child: Text(
                                      (r['nombre'] as String)
                                          .toUpperCase()),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _rolId = v),
                        validator: (v) =>
                            v == null ? 'Selecciona un rol' : null,
                      ),
                      const SizedBox(height: 14),

                      // Estado activo — solo edición
                      if (_esEdicion) ...[
                        Container(
                          decoration: BoxDecoration(
                              border: Border.all(
                                  color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(10)),
                          child: SwitchListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14),
                            title: const Text('Usuario activo',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text(
                              _activo
                                  ? 'Puede acceder al sistema'
                                  : 'Sin acceso',
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
                        const SizedBox(height: 12),
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Cambiar contraseña',
                              style: TextStyle(fontSize: 14)),
                          value: _cambiarPassword,
                          fillColor: WidgetStateProperty.resolveWith(
                              (s) => s.contains(WidgetState.selected)
                                  ? ColoresCarolina.celeste
                                  : null),
                          controlAffinity:
                              ListTileControlAffinity.leading,
                          onChanged: (v) => setState(
                              () => _cambiarPassword = v ?? false),
                        ),
                      ],

                      // Contraseña
                      if (!_esEdicion || _cambiarPassword) ...[
                        const SizedBox(height: 4),
                        TextFormField(
                          controller: _passCtrl,
                          obscureText: !_verPass,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: _esEdicion
                                ? 'Nueva contraseña'
                                : 'Contraseña',
                            prefixIcon: const Icon(Icons.lock_outline,
                                color: ColoresCarolina.celeste),
                            suffixIcon: IconButton(
                              icon: Icon(_verPass
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined),
                              tooltip: _verPass
                                  ? 'Ocultar contraseña'
                                  : 'Mostrar contraseña',
                              onPressed: () => setState(
                                  () => _verPass = !_verPass),
                            ),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                    color: ColoresCarolina.celeste,
                                    width: 2)),
                          ),
                          validator: (v) {
                            if (!_esEdicion || _cambiarPassword) {
                              if ((v ?? '').length < 8) {
                                return 'Mínimo 8 caracteres';
                              }
                              if (!_tieneMayuscula) {
                                return 'Necesita una mayúscula';
                              }
                              if (!_tieneNumero) {
                                return 'Necesita un número';
                              }
                            }
                            return null;
                          },
                        ),
                        if (_passCtrl.text.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _medidor(),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
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
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Text(
                          _esEdicion
                              ? 'Guardar Cambios'
                              : 'Crear Usuario',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                )),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _medidor() {
    final n = [
      _tieneMinimo, _tieneMayuscula, _tieneNumero, _tieneEspecial
    ].where((e) => e).length;
    final cols = [
      Colors.transparent, ColoresCarolina.rojo,
      Colors.orange, Colors.amber, Colors.green
    ];
    final labs = ['', 'Muy débil', 'Débil', 'Buena', 'Fuerte'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: List.generate(4, (i) => Expanded(child: Container(
          margin: const EdgeInsets.only(right: 4), height: 4,
          decoration: BoxDecoration(
              color: i < n ? cols[n] : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(2)),
        )))),
        const SizedBox(height: 5),
        Text(labs[n],
            style: TextStyle(
                color: cols[n], fontSize: 11,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Wrap(spacing: 8, runSpacing: 4, children: [
          _ind('8+ caracteres', _tieneMinimo),
          _ind('Mayúscula',     _tieneMayuscula),
          _ind('Número',        _tieneNumero),
          _ind('Símbolo',       _tieneEspecial),
        ]),
      ],
    );
  }

  Widget _ind(String t, bool ok) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
          ok
              ? Icons.check_circle_rounded
              : Icons.radio_button_unchecked,
          size: 13,
          color: ok ? Colors.green : Colors.grey),
      const SizedBox(width: 3),
      Text(t,
          style: TextStyle(
              fontSize: 11,
              color: ok ? Colors.green : ColoresCarolina.grisMedio)),
    ],
  );

  InputDecoration _deco(String l, IconData i) => InputDecoration(
    labelText: l,
    prefixIcon: Icon(i, color: ColoresCarolina.celeste),
    border:
        OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(
            color: ColoresCarolina.celeste, width: 2)),
  );

  Widget _campo(
    TextEditingController c,
    String l,
    IconData i, {
    String? Function(String?)? validator,
    TextInputType? tipo,
  }) =>
      TextFormField(
        controller: c,
        keyboardType: tipo,
        decoration: _deco(l, i),
        validator: validator,
      );
}