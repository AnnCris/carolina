// carolina/frontend/lib/widgets/layout_principal.dart
import 'package:flutter/material.dart';
import '../constantes/colores.dart';
import '../constantes/rutas.dart';
import '../servicios/auth_servicio.dart';

class LayoutPrincipal extends StatefulWidget {
  final Widget hijo;
  final String titulo;

  const LayoutPrincipal({
    super.key,
    required this.hijo,
    required this.titulo,
  });

  @override
  State<LayoutPrincipal> createState() => _LayoutPrincipalState();
}

class _LayoutPrincipalState extends State<LayoutPrincipal> {
  Map<String, dynamic>? _usuario;
  bool _menuExpandido = true;

  @override
  void initState() {
    super.initState();
    _cargarUsuario();
  }

  Future<void> _cargarUsuario() async {
    final u = await AuthServicio().obtenerUsuario();
    if (mounted) setState(() => _usuario = u);
  }

  List<Map<String, dynamic>> get _menuItems {
    final permisos = (_usuario?['permisos'] as Map?) ?? {};
    final esAdmin  = permisos['todo'] == true;

    final todos = [
      {'icono': Icons.dashboard_rounded,         'titulo': 'Dashboard',    'ruta': RutasApp.dashboard,    'permiso': 'todo'},
      {'icono': Icons.point_of_sale_rounded,     'titulo': 'Ventas',       'ruta': RutasApp.ventas,       'permiso': 'ventas'},
      {'icono': Icons.price_change_rounded,      'titulo': 'Precios',      'ruta': RutasApp.precios,      'permiso': 'productos'},
      {'icono': Icons.shopping_cart_rounded,     'titulo': 'Compras',      'ruta': RutasApp.compras,      'permiso': 'compras'},
      {'icono': Icons.inventory_2_rounded,       'titulo': 'Inventario',   'ruta': RutasApp.inventario,   'permiso': 'inventario'},
      {'icono': Icons.category_rounded,          'titulo': 'Productos',    'ruta': RutasApp.productos,    'permiso': 'productos'},
      {'icono': Icons.label_rounded,             'titulo': 'Categorías', 'ruta': RutasApp.categorias, 'permiso': 'productos'},
      {'icono': Icons.branding_watermark_rounded, 'titulo': 'Marcas', 'ruta': RutasApp.marcas, 'permiso': 'productos'   },
      {'icono': Icons.people_rounded,            'titulo': 'Clientes',     'ruta': RutasApp.clientes,     'permiso': 'clientes'},
      {'icono': Icons.local_shipping_rounded,    'titulo': 'Proveedores',  'ruta': RutasApp.proveedores,  'permiso': 'proveedores'},
      {'icono': Icons.receipt_long_rounded,      'titulo': 'Pedidos',      'ruta': RutasApp.pedidos,      'permiso': 'pedidos'},
      {'icono': Icons.assignment_return_rounded, 'titulo': 'Devoluciones', 'ruta': RutasApp.devoluciones, 'permiso': 'devoluciones'},
      {'icono': Icons.manage_accounts_rounded,   'titulo': 'Usuarios',     'ruta': RutasApp.usuarios,     'permiso': 'todo'},
    ];

    if (esAdmin) return todos;
    return todos.where((m) {
      if (m['permiso'] == 'todo') return esAdmin;
      return permisos[m['permiso']] == true;
    }).toList();
  }

  Future<void> _cerrarSesion() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.logout_rounded, color: ColoresCarolina.rojo),
          SizedBox(width: 10),
          Text('Cerrar sesión'),
        ]),
        content: const Text('¿Estás seguro que deseas salir del sistema?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: ColoresCarolina.rojo,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
            child: const Text('Sí, salir'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await AuthServicio().cerrarSesion();
      if (mounted) Navigator.pushReplacementNamed(context, RutasApp.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final esMovil = MediaQuery.of(context).size.width < 800;
    if (esMovil) return _buildMovil();
    return _buildEscritorio();
  }

  // ── Escritorio ──────────────────────────────────────────────────────────────
  Widget _buildEscritorio() {
    return Scaffold(
      body: Row(children: [
        _buildSidebar(),
        Expanded(child: _buildAreaContenido()),
      ]),
    );
  }

  // ── Móvil ───────────────────────────────────────────────────────────────────
  Widget _buildMovil() {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.titulo),
        backgroundColor: ColoresCarolina.celeste,
        foregroundColor: Colors.white,
      ),
      drawer: Drawer(
        child: _buildContenidoSidebar(forzarExpandido: true),
      ),
      body: widget.hijo,
    );
  }

  // ── Sidebar ─────────────────────────────────────────────────────────────────
  Widget _buildSidebar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      width: _menuExpandido ? 240 : 68,
      child: _buildContenidoSidebar(),
    );
  }

  Widget _buildContenidoSidebar({bool forzarExpandido = false}) {
    final expandido = forzarExpandido || _menuExpandido;
    final rutaActual = ModalRoute.of(context)?.settings.name ?? '';

    return Container(
      color: ColoresCarolina.celesteOscuro,
      child: Column(children: [
        // ── Logo / Nombre ──────────────────────────────────────────────
        Container(
          padding: EdgeInsets.symmetric(
              horizontal: expandido ? 16 : 10, vertical: 18),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [ColoresCarolina.celeste, ColoresCarolina.celesteOscuro],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.storefront_rounded,
                  color: Colors.white, size: 22),
            ),
            if (expandido) ...[
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Carolina',
                    style: TextStyle(color: Colors.white,
                        fontWeight: FontWeight.bold, fontSize: 18)),
              ),
              IconButton(
                onPressed: () =>
                    setState(() => _menuExpandido = !_menuExpandido),
                icon: const Icon(Icons.menu_open_rounded,
                    color: Colors.white, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ] else
              IconButton(
                onPressed: () =>
                    setState(() => _menuExpandido = !_menuExpandido),
                icon: const Icon(Icons.menu_rounded,
                    color: Colors.white, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ]),
        ),

        // ── Info usuario ───────────────────────────────────────────────
        if (expandido && _usuario != null)
          Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: ColoresCarolina.celeste,
                child: Text(
                  (_usuario!['nombre'] as String? ?? 'U')[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white,
                      fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_usuario!['nombre'] ?? '',
                      style: const TextStyle(color: Colors.white,
                          fontWeight: FontWeight.w600, fontSize: 13),
                      overflow: TextOverflow.ellipsis),
                  Container(
                    margin: const EdgeInsets.only(top: 3),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                        color: ColoresCarolina.celeste,
                        borderRadius: BorderRadius.circular(10)),
                    child: Text(
                      ((_usuario!['rol'] ?? '') as String).toUpperCase(),
                      style: const TextStyle(color: Colors.white,
                          fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              )),
            ]),
          )
        else if (!expandido && _usuario != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: ColoresCarolina.celeste,
              child: Text(
                (_usuario!['nombre'] as String? ?? 'U')[0].toUpperCase(),
                style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ),

        const Divider(color: Colors.white24, height: 1),

        // ── Menú ───────────────────────────────────────────────────────
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: _menuItems.map((item) {
              final ruta = item['ruta'] as String;
              final seleccionado = rutaActual == ruta ||
                  (ruta == RutasApp.dashboard && rutaActual.isEmpty);

              return Tooltip(
                message: expandido ? '' : item['titulo'] as String,
                preferBelow: false,
                child: InkWell(
                  onTap: () {
                    if (ruta != rutaActual) {
                      Navigator.pushReplacementNamed(context, ruta);
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    padding: EdgeInsets.symmetric(
                        horizontal: expandido ? 14 : 10,
                        vertical: 11),
                    decoration: BoxDecoration(
                      color: seleccionado
                          ? Colors.white.withValues(alpha: 0.18)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: seleccionado
                          ? Border.all(
                              color: Colors.white.withValues(alpha: 0.25),
                              width: 1)
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: expandido
                          ? MainAxisAlignment.start
                          : MainAxisAlignment.center,
                      children: [
                        Icon(
                          item['icono'] as IconData,
                          color: seleccionado
                              ? Colors.white
                              : Colors.white60,
                          size: 20,
                        ),
                        if (expandido) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              item['titulo'] as String,
                              style: TextStyle(
                                  color: seleccionado
                                      ? Colors.white
                                      : Colors.white70,
                                  fontWeight: seleccionado
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  fontSize: 14),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // ── Cerrar sesión ──────────────────────────────────────────────
        const Divider(color: Colors.white24, height: 1),
        InkWell(
          onTap: _cerrarSesion,
          child: Container(
            padding: EdgeInsets.symmetric(
                horizontal: expandido ? 22 : 14, vertical: 16),
            child: Row(
              mainAxisAlignment: expandido
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                const Icon(Icons.logout_rounded,
                    color: Colors.white70, size: 20),
                if (expandido) ...[
                  const SizedBox(width: 12),
                  const Text('Cerrar sesión',
                      style: TextStyle(
                          color: Colors.white70, fontSize: 14)),
                ],
              ],
            ),
          ),
        ),
      ]),
    );
  }

  // ── Área de contenido ───────────────────────────────────────────────────────
  Widget _buildAreaContenido() {
    return Column(children: [
      // Barra superior
      Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 24, vertical: 14),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
              bottom: BorderSide(color: Color(0xFFE2E8F0))),
        ),
        child: Row(children: [
          Text(widget.titulo,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: ColoresCarolina.celesteOscuro)),
          const Spacer(),
          if (_usuario != null)
            Row(children: [
              const Icon(Icons.person_outline,
                  size: 16, color: ColoresCarolina.grisMedio),
              const SizedBox(width: 6),
              Text('Hola, ${_usuario!['nombre']}',
                  style: const TextStyle(
                      color: ColoresCarolina.grisMedio,
                      fontSize: 14)),
            ]),
        ]),
      ),
      // Contenido del módulo
      Expanded(child: widget.hijo),
    ]);
  }
}