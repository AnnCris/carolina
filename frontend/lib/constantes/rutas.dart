// carolina/frontend/lib/constantes/rutas.dart
import 'package:flutter/material.dart';
import '../pantallas/auth/login_pantalla.dart';
import '../pantallas/auth/registro_pantalla.dart';
import '../pantallas/dashboard/dashboard_pantalla.dart';
import '../pantallas/ventas/ventas_pantalla.dart';
import '../pantallas/productos/productos_pantalla.dart';
import '../pantallas/clientes/clientes_pantalla.dart';
import '../pantallas/inventario/inventario_pantalla.dart';
import '../pantallas/usuarios/usuarios_pantalla.dart';
import '../widgets/layout_principal.dart';
import '../pantallas/categorias/categorias_pantalla.dart';
import '../pantallas/marcas/marcas_pantalla.dart';
import '../pantallas/proveedores/proveedores_pantalla.dart';
import '../pantallas/compras/compras_pantalla.dart';


class RutasApp {
  static const String login        = '/';
  static const String registro     = '/registro';
  static const String dashboard    = '/dashboard';
  static const String ventas       = '/ventas';
  static const String compras      = '/compras';
  static const String inventario   = '/inventario';
  static const String productos    = '/productos';
  static const String clientes     = '/clientes';
  static const String proveedores  = '/proveedores';
  static const String pedidos      = '/pedidos';
  static const String devoluciones = '/devoluciones';
  static const String usuarios     = '/usuarios';
  static const String categorias = '/categorias';
  static const String marcas     = '/marcas';

  static Map<String, WidgetBuilder> get rutas => {
    login:    (_) => const LoginPantalla(),
    registro: (_) => const RegistroPantalla(),

    dashboard: (_) => const DashboardPantalla(),

    ventas: (_) => const LayoutPrincipal(
        titulo: 'Ventas', hijo: VentasPantalla()),
    compras: (_) => const LayoutPrincipal(
      titulo: 'Compras', hijo: ComprasPantalla()),
    inventario: (_) => const LayoutPrincipal(
        titulo: 'Inventario', hijo: InventarioPantalla()),
    productos: (_) => const LayoutPrincipal(
        titulo: 'Productos', hijo: ProductosPantalla()),
    clientes: (_) => const LayoutPrincipal(
        titulo: 'Clientes', hijo: ClientesPantalla()),
    proveedores: (_) => const LayoutPrincipal(
      titulo: 'Proveedores', hijo: ProveedoresPantalla()),  
    pedidos: (_) => LayoutPrincipal(
        titulo: 'Pedidos', hijo: _placeholder('Pedidos')),
    devoluciones: (_) => LayoutPrincipal(
        titulo: 'Devoluciones', hijo: _placeholder('Devoluciones')),
    usuarios: (_) => const LayoutPrincipal(
        titulo: 'Usuarios', hijo: UsuariosPantalla()),
    categorias: (_) => const LayoutPrincipal(
        titulo: 'Categorías', hijo: CategoriasPantalla()),
    marcas: (_) => const LayoutPrincipal(
        titulo: 'Marcas', hijo: MarcasPantalla()),
  };

  static Widget _placeholder(String nombre) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.construction_rounded, size: 64,
            color: Colors.grey.shade300),
        const SizedBox(height: 16),
        Text('Módulo $nombre',
            style: const TextStyle(fontSize: 20,
                fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 8),
        const Text('En desarrollo...',
            style: TextStyle(color: Colors.grey)),
      ],
    ),
  );
}