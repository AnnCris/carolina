// carolina/frontend/lib/pantallas/dashboard/dashboard_pantalla.dart
import 'package:flutter/material.dart';
import '../../constantes/colores.dart';
import '../../constantes/rutas.dart';
import '../../servicios/auth_servicio.dart';


class DashboardPantalla extends StatefulWidget {
  const DashboardPantalla({super.key});
  @override
  State<DashboardPantalla> createState() => _DashboardPantallaState();
}

class _DashboardPantallaState extends State<DashboardPantalla> {
  Map<String, dynamic>? _usuario;
  int _paginaActual = 0;
  bool _menuExpandido = true;

  @override
  void initState() {
    super.initState();
    _cargarUsuario();
  }

  Future<void> _cargarUsuario() async {
    final u = await AuthServicio().obtenerUsuario();
    setState(() => _usuario = u);
  }

  Future<void> _cerrarSesion() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Estás seguro que deseas salir?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: ColoresCarolina.rojo),
            child: const Text('Salir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmar == true) {
      await AuthServicio().cerrarSesion();
      if (mounted) Navigator.pushReplacementNamed(context, RutasApp.login);
    }
  }

  List<Map<String, dynamic>> get _menuItems {
    final permisos = _usuario?['permisos'] as Map? ?? {};
    final esAdmin = _usuario?['permisos']?['todo'] == true;

    final todos = [
      {'icono': Icons.dashboard_rounded, 'titulo': 'Dashboard', 'ruta': '', 'permiso': 'todo'},
      {'icono': Icons.point_of_sale_rounded, 'titulo': 'Ventas', 'ruta': RutasApp.ventas, 'permiso': 'ventas'},
      {'icono': Icons.shopping_cart_rounded, 'titulo': 'Compras', 'ruta': '/compras', 'permiso': 'compras'},
      {'icono': Icons.inventory_2_rounded, 'titulo': 'Inventario', 'ruta': RutasApp.inventario, 'permiso': 'inventario'},
      {'icono': Icons.category_rounded, 'titulo': 'Productos', 'ruta': RutasApp.productos, 'permiso': 'productos'},
      {'icono': Icons.category_rounded, 'titulo': 'Productos', 'ruta': RutasApp.productos, 'permiso': 'productos'},
      {'icono': Icons.people_rounded, 'titulo': 'Clientes', 'ruta': RutasApp.clientes, 'permiso': 'clientes'},
      {'icono': Icons.local_shipping_rounded, 'titulo': 'Proveedores', 'ruta': '/proveedores', 'permiso': 'proveedores'},
      {'icono': Icons.receipt_long_rounded, 'titulo': 'Pedidos', 'ruta': '/pedidos', 'permiso': 'pedidos'},
      {'icono': Icons.assignment_return_rounded, 'titulo': 'Devoluciones', 'ruta': '/devoluciones', 'permiso': 'devoluciones'},
      {'icono': Icons.people_alt_rounded, 'titulo': 'Usuarios', 'ruta': RutasApp.usuarios, 'permiso': 'todo'},
    ];

    if (esAdmin) return todos;
    return todos.where((m) => permisos[m['permiso']] == true || m['permiso'] == 'todo' && esAdmin).toList();
  }

  @override
  Widget build(BuildContext context) {
    final esMovil = MediaQuery.of(context).size.width < 800;

    if (esMovil) return _buildMovil();
    return _buildEscritorio();
  }

  Widget _buildEscritorio() {
    return Scaffold(
      body: Row(
        children: [
          _buildSidebar(),
          Expanded(child: _buildContenido()),
        ],
      ),
    );
  }

  Widget _buildMovil() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Distribuidora Carolina'),
        backgroundColor: ColoresCarolina.celeste,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _cerrarSesion),
        ],
      ),
      drawer: Drawer(child: _buildContenidoSidebar()),
      body: _buildContenido(),
    );
  }

  Widget _buildSidebar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: _menuExpandido ? 240 : 70,
      color: ColoresCarolina.celesteOscuro,
      child: _buildContenidoSidebar(),
    );
  }

  Widget _buildContenidoSidebar() {
    return Column(
      children: [
        // Encabezado
        Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          color: ColoresCarolina.celeste,
          child: Row(
            children: [
              const Icon(Icons.storefront_rounded, color: Colors.white, size: 28),
              if (_menuExpandido) ...[
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Carolina',
                      style: TextStyle(color: Colors.white,
                          fontWeight: FontWeight.bold, fontSize: 18)),
                ),
                IconButton(
                  icon: const Icon(Icons.menu_open, color: Colors.white),
                  onPressed: () => setState(() => _menuExpandido = !_menuExpandido),
                ),
              ] else
                IconButton(
                  icon: const Icon(Icons.menu, color: Colors.white),
                  onPressed: () => setState(() => _menuExpandido = !_menuExpandido),
                ),
            ],
          ),
        ),

        // Info usuario
        if (_menuExpandido && _usuario != null)
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: ColoresCarolina.celeste,
                  child: Text(
                    (_usuario!['nombre'] as String? ?? 'U')[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_usuario!['nombre'] ?? '',
                          style: const TextStyle(color: Colors.white,
                              fontWeight: FontWeight.w600, fontSize: 13),
                          overflow: TextOverflow.ellipsis),
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: ColoresCarolina.celeste,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text((_usuario!['rol'] ?? '').toString().toUpperCase(),
                            style: const TextStyle(color: Colors.white,
                                fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        const Divider(color: Colors.white24, height: 1),

        // Menú
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: _menuItems.length,
            itemBuilder: (_, i) {
              final item = _menuItems[i];
              final seleccionado = _paginaActual == i;
              return Tooltip(
                message: _menuExpandido ? '' : item['titulo'],
                child: InkWell(
                  onTap: () {
                    if (item['ruta'] != '' && item['ruta'] != null) {
                      Navigator.pushReplacementNamed(context, item['ruta']);
                    } else {
                      setState(() => _paginaActual = i);
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    padding: EdgeInsets.symmetric(
                        horizontal: _menuExpandido ? 16 : 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: seleccionado
                          ? ColoresCarolina.celeste.withValues(alpha: 0.3)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: _menuExpandido
                          ? MainAxisAlignment.start : MainAxisAlignment.center,
                      children: [
                        Icon(item['icono'] as IconData,
                            color: seleccionado ? Colors.white : Colors.white70,
                            size: 22),
                        if (_menuExpandido) ...[
                          const SizedBox(width: 12),
                          Text(item['titulo'],
                              style: TextStyle(
                                  color: seleccionado ? Colors.white : Colors.white70,
                                  fontWeight: seleccionado
                                      ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 14)),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Cerrar sesión
        const Divider(color: Colors.white24, height: 1),
        InkWell(
          onTap: _cerrarSesion,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: _menuExpandido
                  ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: [
                const Icon(Icons.logout_rounded, color: Colors.white70),
                if (_menuExpandido) ...[
                  const SizedBox(width: 12),
                  const Text('Cerrar sesión',
                      style: TextStyle(color: Colors.white70, fontSize: 14)),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContenido() {
    return Container(
      color: ColoresCarolina.fondo,
      child: Column(
        children: [
          // Barra superior
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            color: Colors.white,
            child: Row(
              children: [
                Text(_menuItems.isNotEmpty ? _menuItems[_paginaActual]['titulo'] : 'Dashboard',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                        color: ColoresCarolina.celesteOscuro)),
                const Spacer(),
                if (_usuario != null)
                  Text('Hola, ${_usuario!['nombre']}',
                      style: const TextStyle(color: ColoresCarolina.grisMedio)),
              ],
            ),
          ),
          const Divider(height: 1),
          // Contenido principal
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: _buildTarjetasDashboard(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTarjetasDashboard() {
    final rol = _usuario?['rol'] ?? '';
    final esAdmin = _usuario?['permisos']?['todo'] == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Resumen del sistema',
            style: TextStyle(fontSize: 16, color: ColoresCarolina.grisMedio)),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16, runSpacing: 16,
          children: [
            if (esAdmin) ...[
              _tarjeta('Ventas hoy', 'Bs 0.00', Icons.point_of_sale_rounded,
                  ColoresCarolina.celeste),
              _tarjeta('Productos', '0', Icons.inventory_rounded,
                  Colors.green),
              _tarjeta('Clientes', '0', Icons.people_rounded,
                  Colors.orange),
              _tarjeta('Stock bajo', '0', Icons.warning_rounded,
                  ColoresCarolina.rojo),
            ],
            if (!esAdmin && rol == 'vendedor') ...[
              _tarjeta('Mis ventas hoy', 'Bs 0.00',
                  Icons.point_of_sale_rounded, ColoresCarolina.celeste),
              _tarjeta('Pedidos pendientes', '0',
                  Icons.pending_actions_rounded, Colors.orange),
            ],
          ],
        ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ColoresCarolina.grisClaro),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Accesos rápidos',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12, runSpacing: 12,
                children: _menuItems
                    .where((m) => m['ruta'] != '')
                    .take(6)
                    .map((m) => ActionChip(
                          avatar: Icon(m['icono'] as IconData,
                              size: 18, color: ColoresCarolina.celeste),
                          label: Text(m['titulo']),
                          onPressed: () {
                            if (m['ruta'] != null && m['ruta'] != '') {
                              Navigator.pushNamed(context, m['ruta']);
                            }
                          },
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tarjeta(String titulo, String valor, IconData icono, Color color) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColoresCarolina.grisClaro),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.08),
              blurRadius: 8, offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icono, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo,
                    style: const TextStyle(color: ColoresCarolina.grisMedio,
                        fontSize: 12),
                    overflow: TextOverflow.ellipsis),
                Text(valor,
                    style: const TextStyle(fontWeight: FontWeight.bold,
                        fontSize: 18)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}