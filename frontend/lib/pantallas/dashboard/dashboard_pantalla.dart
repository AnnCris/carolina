// carolina/frontend/lib/pantallas/dashboard/dashboard_pantalla.dart
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../constantes/api.dart';
import '../../constantes/breakpoints.dart';
import '../../constantes/colores.dart';
import '../../constantes/rutas.dart';
import '../../servicios/auth_servicio.dart';

// ─── Servicio ───────────────────────────────────────────────────────────────
class DashboardServicio {
  final _auth = AuthServicio();
  Future<Map<String, String>> get _h => _auth.obtenerHeaders();

  Future<Map<String, dynamic>> resumen() async {
    final res = await http.get(Uri.parse(ApiConfig.dashboardResumen), headers: await _h);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Error al cargar el resumen');
  }

  Future<List<dynamic>> ventasSemana({bool propias = false}) async {
    final res = await http.get(
        Uri.parse(ApiConfig.dashboardVentasSemana(dias: 7, propias: propias)),
        headers: await _h);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Error al cargar las ventas de la semana');
  }

  Future<List<dynamic>> topProductos() async {
    final res = await http.get(
        Uri.parse(ApiConfig.dashboardTopProductos(dias: 30, limite: 5)),
        headers: await _h);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Error al cargar el top de productos');
  }

  Future<List<dynamic>> metodosPago() async {
    final res = await http.get(
        Uri.parse(ApiConfig.dashboardMetodosPago(dias: 30)), headers: await _h);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Error al cargar los métodos de pago');
  }

  Future<List<dynamic>> topDeudores() async {
    final res = await http.get(
        Uri.parse(ApiConfig.dashboardTopDeudores(limite: 5)), headers: await _h);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Error al cargar las cuentas por cobrar');
  }
}

// ─── Pantalla ───────────────────────────────────────────────────────────────
class DashboardPantalla extends StatefulWidget {
  const DashboardPantalla({super.key});
  @override
  State<DashboardPantalla> createState() => _DashboardPantallaState();
}

class _DashboardPantallaState extends State<DashboardPantalla> {
  final _servicio = DashboardServicio();

  Map<String, dynamic>? _usuario;
  Map<String, dynamic> _resumen = {};
  List<dynamic> _ventasSemana = [];
  List<dynamic> _topProductos = [];
  List<dynamic> _metodosPago = [];
  List<dynamic> _topDeudores = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  Future<void> _iniciar() async {
    final u = await AuthServicio().obtenerUsuario();
    if (mounted) setState(() => _usuario = u);
    await _cargarDatos();
  }

  bool get _esAdmin => _usuario?['permisos']?['todo'] == true;
  String get _rol => (_usuario?['rol'] ?? '').toString();
  bool get _soloPropias => !_esAdmin && _rol == 'vendedor';

  bool _tiene(String permiso) {
    final permisos = (_usuario?['permisos'] as Map?) ?? {};
    return _esAdmin || permisos[permiso] == true;
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    try {
      final resultados = await Future.wait([
        _servicio.resumen(),
        _servicio.ventasSemana(propias: _soloPropias),
        _servicio.topProductos(),
        _servicio.metodosPago(),
        _servicio.topDeudores(),
      ]);
      if (!mounted) return;
      setState(() {
        _resumen = resultados[0] as Map<String, dynamic>;
        _ventasSemana = resultados[1] as List<dynamic>;
        _topProductos = resultados[2] as List<dynamic>;
        _metodosPago = resultados[3] as List<dynamic>;
        _topDeudores = resultados[4] as List<dynamic>;
      });
    } catch (_) {
      // El dashboard no debe bloquear la pantalla con un error — si algo
      // falla se queda con valores en 0 / listas vacías.
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  double _num(dynamic v) => (v as num?)?.toDouble() ?? 0.0;
  int _entero(dynamic v) => (v as num?)?.toInt() ?? 0;
  String _bs(dynamic v) => 'Bs ${_num(v).toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final movil = Breakpoints.esMovil(context);
    return RefreshIndicator(
      onRefresh: _cargarDatos,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(movil ? 16 : 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSaludo(),
            const SizedBox(height: 24),
            _buildTarjetasResumen(),
            const SizedBox(height: 28),
            _buildGraficos(movil),
            const SizedBox(height: 28),
            _buildAccesosRapidos(),
          ],
        ),
      ),
    );
  }

  // ── Saludo ────────────────────────────────────────────────────────────
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
                    color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Esto es lo que está pasando hoy en Distribuidora Carolina',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: _cargando ? null : _cargarDatos,
          tooltip: 'Actualizar',
          icon: _cargando
              ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.refresh_rounded, color: Colors.white),
        ),
        if (!Breakpoints.esMovil(context))
          Container(
            margin: const EdgeInsets.only(left: 4),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 36),
          ),
      ]),
    );
  }

  // ── Tarjetas de resumen (datos reales) ──────────────────────────────────
  Widget _buildTarjetasResumen() {
    final tarjetas = <Widget>[];

    if (_tiene('ventas')) {
      final monto = _soloPropias ? _resumen['mis_ventas_hoy_monto'] : _resumen['ventas_hoy_monto'];
      final cantidad = _soloPropias
          ? _resumen['mis_ventas_hoy_cantidad'] : _resumen['ventas_hoy_cantidad'];
      tarjetas.add(_tarjeta(
        _soloPropias ? 'Mis ventas de hoy' : 'Ventas de hoy',
        _bs(monto), Icons.point_of_sale_rounded, ColoresCarolina.celeste,
        subtitulo: '${_entero(cantidad)} venta(s)',
      ));
    }

    if (_tiene('ventas') || _tiene('pedidos')) {
      final cantidad = _soloPropias
          ? _resumen['mis_pedidos_pendientes_cantidad'] : _resumen['pedidos_pendientes_cantidad'];
      tarjetas.add(_tarjeta('Pedidos pendientes', '${_entero(cantidad)}',
          Icons.pending_actions_rounded, Colors.orange));
    }

    if (_esAdmin) {
      tarjetas.add(_tarjeta('Clientes activos', '${_entero(_resumen['clientes_activos'])}',
          Icons.people_rounded, Colors.purple));
    }

    if (_tiene('inventario')) {
      tarjetas.add(_tarjeta('Stock crítico', '${_entero(_resumen['stock_critico_cantidad'])}',
          Icons.warning_amber_rounded, ColoresCarolina.rojo));
    }

    if (_tiene('cobranzas')) {
      tarjetas.add(_tarjeta('Cuentas por cobrar', _bs(_resumen['cuentas_por_cobrar_total']),
          Icons.account_balance_wallet_rounded, Colors.deepOrange,
          subtitulo: '${_entero(_resumen['cuentas_por_cobrar_cantidad'])} cuenta(s)'));
    }

    if (_tiene('compras')) {
      tarjetas.add(_tarjeta('Compras del mes', _bs(_resumen['compras_mes_total']),
          Icons.shopping_cart_rounded, Colors.brown));
    }

    if (_tiene('devoluciones')) {
      tarjetas.add(_tarjeta(
          'Devoluciones pendientes', '${_entero(_resumen['devoluciones_pendientes_cantidad'])}',
          Icons.assignment_return_rounded, Colors.teal));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Resumen',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: ColoresCarolina.textoFuerte)),
        const SizedBox(height: 14),
        Wrap(spacing: 16, runSpacing: 16, children: tarjetas),
      ],
    );
  }

  Widget _tarjeta(String titulo, String valor, IconData icono, Color color, {String? subtitulo}) {
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
                  style: const TextStyle(color: ColoresCarolina.grisMedio, fontSize: 12),
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(valor,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
                  overflow: TextOverflow.ellipsis),
              if (subtitulo != null) ...[
                const SizedBox(height: 2),
                Text(subtitulo,
                    style: const TextStyle(color: ColoresCarolina.grisMedio, fontSize: 11)),
              ],
            ],
          ),
        ),
      ]),
    );
  }

  // ── Gráficos ─────────────────────────────────────────────────────────────
  Widget _buildGraficos(bool movil) {
    final verVentas = _tiene('ventas');
    final verCobranzas = _tiene('cobranzas');
    if (!verVentas && !verCobranzas) return const SizedBox.shrink();

    final bloqueVentas = verVentas
        ? _tarjetaSeccion(
            _soloPropias ? 'Mis ventas de los últimos 7 días' : 'Ventas de los últimos 7 días',
            Icons.show_chart_rounded,
            _buildBarrasVentas(),
          )
        : null;
    final bloqueMetodos = verCobranzas
        ? _tarjetaSeccion(
            'Métodos de pago (últimos 30 días)',
            Icons.pie_chart_rounded,
            _buildMetodosPago(),
          )
        : null;
    final bloqueTopProductos = verVentas
        ? _tarjetaSeccion(
            'Productos más vendidos (30 días)',
            Icons.local_fire_department_rounded,
            _buildTopProductos(),
          )
        : null;
    final bloqueDeudores = verCobranzas
        ? _tarjetaSeccion(
            'Clientes con más saldo pendiente',
            Icons.priority_high_rounded,
            _buildTopDeudores(),
          )
        : null;

    final filaSuperior = [bloqueVentas, bloqueMetodos].whereType<Widget>().toList();
    final filaInferior = [bloqueTopProductos, bloqueDeudores].whereType<Widget>().toList();

    Widget filaOColumna(List<Widget> bloques) {
      if (bloques.isEmpty) return const SizedBox.shrink();
      if (movil || bloques.length == 1) {
        return Column(children: [
          for (int i = 0; i < bloques.length; i++) ...[
            if (i > 0) const SizedBox(height: 16),
            bloques[i],
          ],
        ]);
      }
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (int i = 0; i < bloques.length; i++) ...[
              if (i > 0) const SizedBox(width: 16),
              Expanded(child: bloques[i]),
            ],
          ],
        ),
      );
    }

    return Column(children: [
      filaOColumna(filaSuperior),
      if (filaInferior.isNotEmpty) const SizedBox(height: 16),
      filaOColumna(filaInferior),
    ]);
  }

  Widget _tarjetaSeccion(String titulo, IconData icono, Widget contenido) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ColoresCarolina.borde),
        boxShadow: ColoresCarolina.sombraTarjeta(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icono, size: 18, color: ColoresCarolina.celeste),
            const SizedBox(width: 8),
            Expanded(
              child: Text(titulo,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  overflow: TextOverflow.ellipsis),
            ),
          ]),
          const SizedBox(height: 18),
          contenido,
        ],
      ),
    );
  }

  Widget _mensajeVacio(String texto) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(texto,
              textAlign: TextAlign.center,
              style: const TextStyle(color: ColoresCarolina.grisMedio, fontSize: 13)),
        ),
      );

  static const _diasCorto = ['', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

  Widget _buildBarrasVentas() {
    if (_cargando && _ventasSemana.isEmpty) {
      return const SizedBox(height: 160, child: Center(child: CircularProgressIndicator()));
    }
    if (_ventasSemana.isEmpty) {
      return _mensajeVacio('Todavía no hay ventas registradas esta semana.');
    }

    final maxTotal = _ventasSemana.fold<double>(
        0, (m, f) => math.max(m, _num((f as Map)['total'])));
    final tope = maxTotal <= 0 ? 1.0 : maxTotal;
    const alturaMax = 120.0;

    return SizedBox(
      height: 170,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: _ventasSemana.asMap().entries.map((entry) {
          final esHoy = entry.key == _ventasSemana.length - 1;
          final fila = entry.value as Map;
          final total = _num(fila['total']);
          final cantidad = _entero(fila['cantidad']);
          final altura = total <= 0 ? 4.0 : 8.0 + (total / tope) * alturaMax;
          final fecha = DateTime.tryParse(fila['fecha'] as String? ?? '');

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(total > 0 ? total.toStringAsFixed(0) : '',
                      style: const TextStyle(fontSize: 10, color: ColoresCarolina.grisMedio)),
                  const SizedBox(height: 4),
                  Tooltip(
                    message: '${_bs(total)} · $cantidad venta(s)',
                    child: Container(
                      height: altura,
                      decoration: BoxDecoration(
                        color: esHoy ? ColoresCarolina.celesteOscuro : ColoresCarolina.celeste,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    fecha != null ? _diasCorto[fecha.weekday] : '-',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: esHoy ? FontWeight.bold : FontWeight.normal,
                        color: esHoy ? ColoresCarolina.celesteOscuro : ColoresCarolina.grisMedio),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  static const Map<String, Color> _coloresMetodo = {
    'efectivo': Color(0xFF16A34A),
    'qr': ColoresCarolina.celeste,
    'transferencia': Color(0xFFF59E0B),
  };
  static const Map<String, String> _etiquetasMetodo = {
    'efectivo': 'Efectivo',
    'qr': 'QR',
    'transferencia': 'Transferencia',
  };

  Widget _buildMetodosPago() {
    if (_cargando && _metodosPago.isEmpty) {
      return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
    }
    if (_metodosPago.isEmpty) {
      return _mensajeVacio('No se registraron cobros en los últimos 30 días.');
    }

    final valores = _metodosPago.map((m) => _num((m as Map)['monto'])).toList();
    final colores = _metodosPago
        .map((m) => _coloresMetodo[(m as Map)['metodo']] ?? Colors.grey)
        .toList();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CustomPaint(size: const Size(110, 110), painter: _DonutPainter(valores, colores)),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: _metodosPago.map((m) {
              final fila = m as Map;
              final metodo = fila['metodo'] as String? ?? '';
              final color = _coloresMetodo[metodo] ?? Colors.grey;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(children: [
                  Container(
                      width: 10, height: 10,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_etiquetasMetodo[metodo] ?? metodo,
                        style: const TextStyle(fontSize: 13)),
                  ),
                  Text('${fila['porcentaje']}%',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildTopProductos() {
    if (_cargando && _topProductos.isEmpty) {
      return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));
    }
    if (_topProductos.isEmpty) {
      return _mensajeVacio('Aún no hay ventas registradas en los últimos 30 días.');
    }

    final maxCantidad = _topProductos.fold<double>(
        0, (m, p) => math.max(m, _num((p as Map)['cantidad'])));
    final tope = maxCantidad <= 0 ? 1.0 : maxCantidad;

    return Column(
      children: _topProductos.map((p) {
        final fila = p as Map;
        final cantidad = _num(fila['cantidad']);
        final ratio = (cantidad / tope).clamp(0.04, 1.0);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(fila['producto'] as String? ?? '-',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 8),
                Text('${cantidad.toStringAsFixed(0)} u. · ${_bs(fila['total'])}',
                    style: const TextStyle(fontSize: 11, color: ColoresCarolina.grisMedio)),
              ]),
              const SizedBox(height: 6),
              LayoutBuilder(builder: (context, restricciones) {
                return Container(
                  height: 8,
                  width: restricciones.maxWidth,
                  decoration: BoxDecoration(
                      color: ColoresCarolina.grisClaro, borderRadius: BorderRadius.circular(4)),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      height: 8,
                      width: restricciones.maxWidth * ratio,
                      decoration: BoxDecoration(
                          color: ColoresCarolina.celeste, borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTopDeudores() {
    if (_cargando && _topDeudores.isEmpty) {
      return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));
    }
    if (_topDeudores.isEmpty) {
      return _mensajeVacio('No hay cuentas pendientes por cobrar. 🎉');
    }

    return Column(
      children: _topDeudores.map((d) {
        final fila = d as Map;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: ColoresCarolina.rojo.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(fila['cliente'] as String? ?? '-',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text('${_entero(fila['cantidad_cuentas'])} cuenta(s) pendiente(s)',
                      style: const TextStyle(fontSize: 11, color: ColoresCarolina.grisMedio)),
                ],
              ),
            ),
            Text(_bs(fila['saldo_total']),
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: ColoresCarolina.rojo, fontSize: 14)),
          ]),
        );
      }).toList(),
    );
  }

  // ── Accesos rápidos ──────────────────────────────────────────────────────
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
          Icon(m['icono'] as IconData, color: ColoresCarolina.celesteOscuro, size: 26),
          const SizedBox(height: 8),
          Text(m['titulo'] as String,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: ColoresCarolina.celesteOscuro)),
        ]),
      ),
    );
  }
}

// ─── Gráfico de dona (sin dependencias externas) ───────────────────────────
class _DonutPainter extends CustomPainter {
  final List<double> valores;
  final List<Color> colores;
  _DonutPainter(this.valores, this.colores);

  @override
  void paint(Canvas canvas, Size size) {
    final total = valores.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return;

    final grosor = size.width * 0.24;
    final rect = Rect.fromLTWH(0, 0, size.width, size.height).deflate(grosor / 2);
    double anguloInicio = -math.pi / 2;

    for (var i = 0; i < valores.length; i++) {
      if (valores[i] <= 0) continue;
      final barrido = (valores[i] / total) * 2 * math.pi;
      final pincel = Paint()
        ..color = colores[i % colores.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = grosor
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, anguloInicio, barrido, false, pincel);
      anguloInicio += barrido;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.valores != valores || oldDelegate.colores != colores;
}
