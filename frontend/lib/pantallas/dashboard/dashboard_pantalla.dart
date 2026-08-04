// carolina/frontend/lib/pantallas/dashboard/dashboard_pantalla.dart
import 'package:flutter/material.dart';
import '../../constantes/breakpoints.dart';
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

  @override
  void initState() {
    super.initState();
    _cargarUsuario();
  }

  Future<void> _cargarUsuario() async {
    final u = await AuthServicio().obtenerUsuario();
    if (mounted) setState(() => _usuario = u);
  }

  bool get _esAdmin => _usuario?['permisos']?['todo'] == true;
  String get _rol => (_usuario?['rol'] ?? '').toString();

  List<Map<String, dynamic>> get _accesosRapidos {
    final permisos = (_usuario?['permisos'] as Map?) ?? {};
    final todos = [
      {'icono': Icons.point_of_sale_rounded, 'titulo': 'Ventas', 'ruta': RutasApp.ventas, 'permiso': 'ventas'},
      {'icono': Icons.receipt_long_rounded, 'titulo': 'Pedidos', 'ruta': RutasApp.pedidos, 'permiso': 'pedidos'},
      {'icono': Icons.shopping_cart_rounded, 'titulo': 'Compras', 'ruta': RutasApp.compras, 'permiso': 'compras'},
      {'icono': Icons.inventory_2_rounded, 'titulo': 'Inventario', 'ruta': RutasApp.inventario, 'permiso': 'inventario'},
      {'icono': Icons.category_rounded, 'titulo': 'Productos', 'ruta': RutasApp.productos, 'permiso': 'productos'},
      {'icono': Icons.price_change_rounded, 'titulo': 'Precios', 'ruta': RutasApp.precios, 'permiso': 'productos'},
      {'icono': Icons.people_rounded, 'titulo': 'Clientes', 'ruta': RutasApp.clientes, 'permiso': 'clientes'},
      {'icono': Icons.local_shipping_rounded, 'titulo': 'Proveedores', 'ruta': RutasApp.proveedores, 'permiso': 'proveedores'},
    ];
    if (_esAdmin) return todos;
    return todos.where((m) => permisos[m['permiso']] == true).toList();
  }

  @override
  Widget build(BuildContext context) {
    final movil = Breakpoints.esMovil(context);
    return SingleChildScrollView(
      padding: EdgeInsets.all(movil ? 16 : 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSaludo(),
          const SizedBox(height: 24),
          _buildTarjetasResumen(),
          const SizedBox(height: 28),
          _buildAccesosRapidos(),
        ],
      ),
    );
  }

  Widget _buildSaludo() {
    final nombre = _usuario?['nombre'] ?? '';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: ColoresCarolina.gradienteMarca,
        borderRadius: BorderRadius.circular(20),
        boxShadow: ColoresCarolina.sombraTarjeta(tinte: ColoresCarolina.celeste),
      ),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nombre.isNotEmpty ? 'Hola, $nombre 👋' : 'Bienvenido',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Esto es lo que está pasando hoy en Distribuidora Carolina',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9), fontSize: 13),
              ),
            ],
          ),
        ),
        if (!Breakpoints.esMovil(context))
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.storefront_rounded,
                color: Colors.white, size: 36),
          ),
      ]),
    );
  }

  Widget _buildTarjetasResumen() {
    final tarjetas = <Widget>[];
    if (_esAdmin) {
      tarjetas.addAll([
        _tarjeta('Ventas de hoy', 'Bs 0.00', Icons.point_of_sale_rounded,
            ColoresCarolina.celeste),
        _tarjeta('Pedidos del día', '0', Icons.receipt_long_rounded,
            ColoresCarolina.exito),
        _tarjeta('Clientes', '0', Icons.people_rounded, Colors.orange),
        _tarjeta('Stock bajo', '0', Icons.warning_amber_rounded,
            ColoresCarolina.rojo),
      ]);
    } else if (_rol == 'vendedor') {
      tarjetas.addAll([
        _tarjeta('Mis ventas de hoy', 'Bs 0.00',
            Icons.point_of_sale_rounded, ColoresCarolina.celeste),
        _tarjeta('Pedidos pendientes', '0',
            Icons.pending_actions_rounded, Colors.orange),
      ]);
    } else if (_rol == 'almacenero') {
      tarjetas.addAll([
        _tarjeta('Stock bajo', '0', Icons.warning_amber_rounded,
            ColoresCarolina.rojo),
        _tarjeta('Compras del mes', '0', Icons.shopping_cart_rounded,
            ColoresCarolina.celeste),
      ]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Resumen',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: ColoresCarolina.textoFuerte)),
        const SizedBox(height: 14),
        Wrap(spacing: 16, runSpacing: 16, children: tarjetas),
      ],
    );
  }

  Widget _tarjeta(String titulo, String valor, IconData icono, Color color) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ColoresCarolina.borde),
        boxShadow: ColoresCarolina.sombraTarjeta(),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icono, color: color, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo,
                  style: const TextStyle(
                      color: ColoresCarolina.grisMedio, fontSize: 12),
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(valor,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 19)),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _buildAccesosRapidos() {
    final items = _accesosRapidos;
    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ColoresCarolina.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Accesos rápidos',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: items.map((m) => _accesoRapido(m)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _accesoRapido(Map<String, dynamic> m) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.pushReplacementNamed(context, m['ruta'] as String),
      child: Container(
        width: 130,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: ColoresCarolina.celesteSuave,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: [
          Icon(m['icono'] as IconData,
              color: ColoresCarolina.celesteOscuro, size: 26),
          const SizedBox(height: 8),
          Text(m['titulo'] as String,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: ColoresCarolina.celesteOscuro)),
        ]),
      ),
    );
  }
}
