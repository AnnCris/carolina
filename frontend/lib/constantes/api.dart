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
  static String precioCompra(int productoId, {int? proveedorId}) =>
    '$baseUrl/precios/producto/$productoId/compra'
    '${proveedorId != null ? '?proveedor_id=$proveedorId' : ''}';

  static const String ventasPedidosPendientes =
      '$baseUrl/ventas/pedidos-pendientes';
  static String ventaDesdePedido(int pedidoId) =>
      '$baseUrl/ventas/desde-pedido/$pedidoId';
  static String ventaRecibo(int ventaId) =>
      '$baseUrl/ventas/$ventaId/recibo';
  static String ventaDetalle(int ventaId) =>
      '$baseUrl/ventas/$ventaId';
  static const String ventasHoy = '$baseUrl/ventas/hoy';
  static String ventasPorFecha(String fecha) =>
      '$baseUrl/ventas/fecha/$fecha';
}