// carolina/frontend/lib/constantes/api.dart
class ApiConfig {
  static const String baseUrl = 'http://127.0.0.1:5000/api';

  static const String login      = '$baseUrl/login';
  static const String registro   = '$baseUrl/registro';
  static const String logout     = '$baseUrl/logout';
  static const String perfil     = '$baseUrl/perfil';

  static const String productos  = '$baseUrl/productos';
  static const String categorias = '$baseUrl/categorias';
  static const String marcas     = '$baseUrl/marcas';
  static const String proveedores= '$baseUrl/proveedores';
  static const String clientes   = '$baseUrl/clientes';
  static const String ventas     = '$baseUrl/ventas';
  static const String compras    = '$baseUrl/compras';
  static const String inventario = '$baseUrl/inventario';
  static const String pedidos    = '$baseUrl/pedidos';
  static const String devoluciones='$baseUrl/devoluciones';
  static const String usuarios   = '$baseUrl/usuarios';
  static const String precios = '$baseUrl/precios';
  static String precioCompra(int productoId) =>
    '$baseUrl/precios/producto/$productoId/compra';
  
}