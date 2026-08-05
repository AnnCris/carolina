// carolina/frontend/lib/pantallas/cobranzas/cobranzas_pantalla.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../constantes/breakpoints.dart';
import '../../constantes/colores.dart';
import '../../constantes/api.dart';
import '../../servicios/auth_servicio.dart';
import '../../widgets/notificacion.dart';

const Map<String, String> kMetodosPago = {
  'efectivo': 'Efectivo',
  'qr': 'QR',
  'transferencia': 'Transferencia',
};

const Map<String, IconData> kIconosMetodoPago = {
  'efectivo': Icons.payments_outlined,
  'qr': Icons.qr_code_rounded,
  'transferencia': Icons.account_balance_outlined,
};

// ─── Servicio ─────────────────────────────────────────────────────────────────
class CobranzasServicio {
  final _auth = AuthServicio();
  Future<Map<String, String>> get _h => _auth.obtenerHeaders();

  Future<List<dynamic>> resumen() async {
    final res = await http.get(Uri.parse(ApiConfig.cobranzasResumen), headers: await _h);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Error al cargar cobranzas');
  }

  Future<List<dynamic>> porCliente(int clienteId) async {
    final res = await http.get(Uri.parse(ApiConfig.cobranzasPorCliente(clienteId)),
        headers: await _h);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Error al cargar las cuentas del cliente');
  }

  Future<List<dynamic>> historialCliente(int clienteId) async {
    final res = await http.get(Uri.parse(ApiConfig.cobranzasHistorialPorCliente(clienteId)),
        headers: await _h);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Error al cargar el historial de cobros');
  }

  Future<Map<String, dynamic>> crearCobranza({
    required int clienteId,
    required String metodoPago,
    String? nota,
    required List<Map<String, dynamic>> detalles,
  }) async {
    final res = await http.post(Uri.parse(ApiConfig.cobranzas),
        headers: await _h,
        body: jsonEncode({
          'cliente_id': clienteId,
          'metodo_pago': metodoPago,
          'nota': nota,
          'detalles': detalles,
        }));
    final data = jsonDecode(res.body);
    if (res.statusCode == 201) return data;
    if (data['errores'] != null) throw Exception((data['errores'] as Map).values.first.toString());
    throw Exception(data['error'] ?? 'Error al registrar el cobro');
  }

  Future<void> eliminarCobranza(int cobranzaId) async {
    final res = await http.delete(Uri.parse(ApiConfig.cobranzaDetalle(cobranzaId)),
        headers: await _h);
    if (res.statusCode != 200) throw Exception('Error al eliminar el cobro');
  }
}

// ─── Pantalla ─────────────────────────────────────────────────────────────────
class CobranzasPantalla extends StatefulWidget {
  const CobranzasPantalla({super.key});
  @override
  State<CobranzasPantalla> createState() => _CobranzasPantallaState();
}

class _CobranzasPantallaState extends State<CobranzasPantalla> {
  final _servicio = CobranzasServicio();
  List<dynamic> _resumen = [];
  bool _cargando = true;
  String _busqueda = '';

  @override
  void initState() { super.initState(); _cargar(); }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final r = await _servicio.resumen();
      setState(() => _resumen = r);
    } catch (e) {
      if (mounted) Notificacion.error(context, e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  List<dynamic> get _filtrados {
    if (_busqueda.isEmpty) return _resumen;
    final q = _busqueda.toLowerCase();
    return _resumen.where((r) => (r['cliente'] ?? '').toString().toLowerCase().contains(q)).toList();
  }

  double get _saldoTotalGeneral =>
      _resumen.fold(0.0, (acc, r) => acc + ((r['saldo_total'] as num?)?.toDouble() ?? 0));

  void _abrirCuentasCliente(Map<String, dynamic> fila) {
    showDialog(
      context: context,
      builder: (_) => _DialogoCuentasCliente(
        clienteId: fila['cliente_id'] as int,
        clienteNombre: fila['cliente'] as String? ?? '-',
        servicio: _servicio,
        onCambio: _cargar,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _buildHeader(), _buildBarra(), Expanded(child: _buildCuerpo(_filtrados)),
    ]);
  }

  Widget _buildHeader() {
    final movil = Breakpoints.esMovil(context);
    return Container(
      padding: EdgeInsets.fromLTRB(movil ? 16 : 28, 22, movil ? 16 : 28, 18),
      decoration: const BoxDecoration(color: Colors.white,
          border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0)))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Cobranzas', style: TextStyle(fontSize: 24,
            fontWeight: FontWeight.bold, color: ColoresCarolina.celesteOscuro)),
        const SizedBox(height: 4),
        const Text('Clientes con saldos pendientes por ventas al crédito o pagos parciales.',
            style: TextStyle(fontSize: 12.5, color: ColoresCarolina.grisMedio)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _chip('${_resumen.length} cliente(s) con saldo', ColoresCarolina.celeste),
          _chip('Total por cobrar: Bs ${_saldoTotalGeneral.toStringAsFixed(2)}', ColoresCarolina.rojo),
        ]),
      ]),
    );
  }

  Widget _buildBarra() {
    final movil = Breakpoints.esMovil(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: movil ? 16 : 28, vertical: 12),
      color: Colors.white,
      child: Row(children: [
        Expanded(child: TextField(
          onChanged: (v) => setState(() => _busqueda = v),
          decoration: InputDecoration(
            hintText: 'Buscar cliente...',
            prefixIcon: const Icon(Icons.search_rounded, color: ColoresCarolina.celeste),
            suffixIcon: _busqueda.isNotEmpty
                ? IconButton(icon: const Icon(Icons.clear_rounded, size: 18),
                    tooltip: 'Limpiar búsqueda',
                    onPressed: () => setState(() => _busqueda = ''))
                : null,
            filled: true, fillColor: const Color(0xFFF1F5F9),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: ColoresCarolina.celeste, width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        )),
        const SizedBox(width: 8),
        IconButton(onPressed: _cargar, icon: const Icon(Icons.refresh_rounded),
            color: ColoresCarolina.celeste, tooltip: 'Actualizar'),
      ]),
    );
  }

  Widget _buildCuerpo(List<dynamic> filtrados) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator(color: ColoresCarolina.celeste));
    }
    if (filtrados.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.check_circle_outline_rounded, size: 72,
            color: ColoresCarolina.exito.withValues(alpha: 0.35)),
        const SizedBox(height: 14),
        Text(_busqueda.isNotEmpty
            ? 'No hay resultados para "$_busqueda"'
            : '¡Ningún cliente tiene saldos pendientes!',
            style: const TextStyle(color: ColoresCarolina.grisMedio, fontSize: 15)),
      ]));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filtrados.length,
      itemBuilder: (_, i) {
        final r = filtrados[i];
        final saldo = (r['saldo_total'] as num?)?.toDouble() ?? 0;
        final cuentas = r['cantidad_cuentas'] ?? 0;
        final fechaAntigua = (r['cuenta_mas_antigua'] ?? '').toString();
        final fechaStr = fechaAntigua.length >= 10 ? fechaAntigua.substring(0, 10) : fechaAntigua;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ColoresCarolina.borde),
            boxShadow: ColoresCarolina.sombraTarjeta(),
          ),
          child: Row(children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: ColoresCarolina.rojo.withValues(alpha: 0.12),
              child: Text((r['cliente'] as String? ?? 'C')[0].toUpperCase(),
                  style: const TextStyle(color: ColoresCarolina.rojo, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r['cliente'] ?? '-',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Wrap(spacing: 10, runSpacing: 4, children: [
                  Text(cuentas == 1 ? '1 cuenta pendiente' : '$cuentas cuentas pendientes',
                      style: const TextStyle(fontSize: 12, color: ColoresCarolina.grisMedio)),
                  Text('Desde: $fechaStr',
                      style: const TextStyle(fontSize: 12, color: ColoresCarolina.grisMedio)),
                ]),
              ]),
            ),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('Bs ${saldo.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16,
                      color: ColoresCarolina.rojo)),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: () => _abrirCuentasCliente(r),
                icon: const Icon(Icons.receipt_long_rounded, size: 16),
                label: const Text('Ver cuentas'),
                style: OutlinedButton.styleFrom(
                    foregroundColor: ColoresCarolina.celeste,
                    side: const BorderSide(color: ColoresCarolina.celeste),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              ),
            ]),
          ]),
        );
      },
    );
  }

  Widget _chip(String t, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
    child: Text(t, style: TextStyle(fontSize: 12, color: c, fontWeight: FontWeight.w600)),
  );
}

// ─── Diálogo: cuentas de un cliente ────────────────────────────────────────────
class _DialogoCuentasCliente extends StatefulWidget {
  final int clienteId;
  final String clienteNombre;
  final CobranzasServicio servicio;
  final VoidCallback onCambio;

  const _DialogoCuentasCliente({
    required this.clienteId, required this.clienteNombre,
    required this.servicio, required this.onCambio,
  });

  @override
  State<_DialogoCuentasCliente> createState() => _DialogoCuentasClienteState();
}

class _DialogoCuentasClienteState extends State<_DialogoCuentasCliente> {
  List<dynamic> _ventas = [];
  List<dynamic> _historial = [];
  bool _cargando = true;

  @override
  void initState() { super.initState(); _cargar(); }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final v = await widget.servicio.porCliente(widget.clienteId);
      final h = await widget.servicio.historialCliente(widget.clienteId);
      setState(() { _ventas = v; _historial = h; });
    } catch (e) {
      if (mounted) Notificacion.error(context, e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _abrirFormularioCobranza() async {
    final pendientes = _ventas.where((v) => (v['saldo_pendiente'] as num? ?? 0) > 0).toList();
    if (pendientes.isEmpty) {
      Notificacion.error(context, 'Este cliente no tiene cuentas pendientes');
      return;
    }
    final resultado = await showDialog<bool>(
      context: context,
      builder: (_) => _FormularioCobranza(
        clienteId: widget.clienteId,
        clienteNombre: widget.clienteNombre,
        ventasPendientes: pendientes,
        servicio: widget.servicio,
      ),
    );
    if (resultado == true) {
      await _cargar();
      widget.onCambio();
    }
  }

  Future<void> _eliminarCobranza(Map<String, dynamic> cobranza) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar cobro'),
        content: Text(
            '¿Seguro que deseas eliminar este cobro de Bs '
            '${(cobranza['monto_total'] as num).toStringAsFixed(2)}?\n\n'
            'Las cuentas que saldaba volverán a quedar pendientes.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: ColoresCarolina.rojo,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('Sí, eliminar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await widget.servicio.eliminarCobranza(cobranza['id'] as int);
        if (mounted) Notificacion.exito(context, 'Cobro eliminado');
        await _cargar();
        widget.onCambio();
      } catch (e) {
        if (mounted) Notificacion.error(context, e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendientes = _ventas.where((v) => (v['saldo_pendiente'] as num? ?? 0) > 0).toList();
    final saldadas = _ventas.where((v) => (v['saldo_pendiente'] as num? ?? 0) <= 0).toList();
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 640, maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              gradient: ColoresCarolina.gradienteMarca,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(children: [
              const Icon(Icons.account_balance_wallet_outlined, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Expanded(child: Text('Cuentas de ${widget.clienteNombre}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  overflow: TextOverflow.ellipsis)),
              IconButton(onPressed: () => Navigator.pop(context), tooltip: 'Cerrar',
                  icon: const Icon(Icons.close, color: Colors.white)),
            ]),
          ),
          Flexible(
            child: _cargando
                ? const Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(color: ColoresCarolina.celeste))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if (pendientes.isNotEmpty)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _abrirFormularioCobranza,
                            icon: const Icon(Icons.payments_outlined, size: 18),
                            label: const Text('Registrar cobro'),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: ColoresCarolina.exito, foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                          ),
                        ),
                      const SizedBox(height: 18),
                      if (pendientes.isEmpty && saldadas.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(20),
                          child: Text('Este cliente no tiene ventas registradas.'),
                        ),
                      if (pendientes.isNotEmpty) ...[
                        const Text('Cuentas pendientes',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13,
                                color: ColoresCarolina.rojo)),
                        const SizedBox(height: 8),
                        ...pendientes.map((v) => _tarjetaVenta(v, pendiente: true)),
                        const SizedBox(height: 16),
                      ],
                      if (saldadas.isNotEmpty) ...[
                        const Text('Ya pagadas',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13,
                                color: ColoresCarolina.grisMedio)),
                        const SizedBox(height: 8),
                        ...saldadas.map((v) => _tarjetaVenta(v, pendiente: false)),
                        const SizedBox(height: 16),
                      ],
                      if (_historial.isNotEmpty) ...[
                        const Text('Historial de cobros',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13,
                                color: ColoresCarolina.celesteOscuro)),
                        const SizedBox(height: 8),
                        ..._historial.map((c) => _tarjetaCobranza(c)),
                      ],
                    ]),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: SizedBox(width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: ColoresCarolina.celeste,
                    foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                child: const Text('Cerrar', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _tarjetaVenta(Map<String, dynamic> v, {required bool pendiente}) {
    final fecha = (v['fecha'] ?? '').toString();
    final fechaStr = fecha.length >= 10 ? fecha.substring(0, 10) : fecha;
    final total = (v['total'] as num?)?.toDouble() ?? 0;
    final pagado = (v['monto_pagado'] as num?)?.toDouble() ?? 0;
    final saldo = (v['saldo_pendiente'] as num?)?.toDouble() ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: pendiente ? Colors.red.withValues(alpha: 0.03) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColoresCarolina.borde),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: ColoresCarolina.celeste.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8)),
            child: Text('Nota ${v['numero_recibo'] ?? '-'}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                    color: ColoresCarolina.celeste)),
          ),
          const SizedBox(width: 8),
          Text(fechaStr, style: const TextStyle(fontSize: 12, color: ColoresCarolina.grisMedio)),
          const Spacer(),
          if (!pendiente)
            const Icon(Icons.check_circle_rounded, color: ColoresCarolina.exito, size: 20),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 16, runSpacing: 4, children: [
          Text('Total: Bs ${total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13)),
          Text('Pagado: Bs ${pagado.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 13, color: ColoresCarolina.exito)),
          if (saldo > 0)
            Text('Saldo: Bs ${saldo.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                    color: ColoresCarolina.rojo)),
        ]),
      ]),
    );
  }

  Widget _tarjetaCobranza(Map<String, dynamic> c) {
    final fecha = (c['fecha'] ?? '').toString();
    final fechaStr = fecha.length >= 16 ? fecha.substring(0, 16) : fecha;
    final metodo = kMetodosPago[c['metodo_pago']] ?? c['metodo_pago'] ?? '-';
    final icono = kIconosMetodoPago[c['metodo_pago']] ?? Icons.payments_outlined;
    final detalles = (c['detalles'] as List?) ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColoresCarolina.borde),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icono, size: 16, color: ColoresCarolina.celesteOscuro),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Bs ${(c['monto_total'] as num).toStringAsFixed(2)} · $metodo',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          Text(fechaStr, style: const TextStyle(fontSize: 11.5, color: ColoresCarolina.grisMedio)),
          const SizedBox(width: 6),
          Tooltip(
            message: 'Eliminar cobro',
            child: InkWell(
              onTap: () => _eliminarCobranza(c),
              borderRadius: BorderRadius.circular(6),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.delete_outline_rounded, size: 16, color: ColoresCarolina.rojo),
              ),
            ),
          ),
        ]),
        if (detalles.isNotEmpty) ...[
          const SizedBox(height: 6),
          ...detalles.map((d) => Padding(
                padding: const EdgeInsets.only(left: 24, top: 2),
                child: Text(
                    '• Nota ${d['venta_numero_recibo'] ?? '-'}: Bs ${(d['monto'] as num).toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
              )),
        ],
        if ((c['nota'] ?? '').toString().isNotEmpty) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 24),
            child: Text(c['nota'],
                style: const TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic,
                    color: ColoresCarolina.grisMedio)),
          ),
        ],
      ]),
    );
  }
}

// ─── Formulario: registrar un cobro (una o varias cuentas a la vez) ────────────
class _FilaCobro {
  final Map<String, dynamic> venta;
  bool seleccionada = false;
  late final TextEditingController montoCtrl;

  _FilaCobro(this.venta) {
    final saldo = (venta['saldo_pendiente'] as num?)?.toDouble() ?? 0;
    montoCtrl = TextEditingController(text: saldo.toStringAsFixed(2));
  }

  double get saldo => (venta['saldo_pendiente'] as num?)?.toDouble() ?? 0;

  void dispose() => montoCtrl.dispose();
}

class _FormularioCobranza extends StatefulWidget {
  final int clienteId;
  final String clienteNombre;
  final List<dynamic> ventasPendientes;
  final CobranzasServicio servicio;

  const _FormularioCobranza({
    required this.clienteId, required this.clienteNombre,
    required this.ventasPendientes, required this.servicio,
  });

  @override
  State<_FormularioCobranza> createState() => _FormularioCobranzaState();
}

class _FormularioCobranzaState extends State<_FormularioCobranza> {
  late final List<_FilaCobro> _filas;
  final _notaCtrl = TextEditingController();
  String _metodoPago = 'efectivo';
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    _filas = widget.ventasPendientes.map((v) => _FilaCobro(v)).toList();
  }

  @override
  void dispose() {
    for (final f in _filas) f.dispose();
    _notaCtrl.dispose();
    super.dispose();
  }

  double get _totalSeleccionado => _filas.where((f) => f.seleccionada).fold(0.0,
      (acc, f) => acc + (double.tryParse(f.montoCtrl.text.trim()) ?? 0));

  Future<void> _guardar() async {
    final seleccionadas = _filas.where((f) => f.seleccionada).toList();
    if (seleccionadas.isEmpty) {
      Notificacion.error(context, 'Selecciona al menos una cuenta a pagar');
      return;
    }
    for (final f in seleccionadas) {
      final monto = double.tryParse(f.montoCtrl.text.trim());
      if (monto == null || monto <= 0) {
        Notificacion.error(context, 'Monto inválido en alguna cuenta seleccionada');
        return;
      }
      if (monto > f.saldo + 0.01) {
        Notificacion.error(context,
            'El monto de la nota ${f.venta['numero_recibo']} supera su saldo '
            '(Bs ${f.saldo.toStringAsFixed(2)})');
        return;
      }
    }

    setState(() => _cargando = true);
    try {
      await widget.servicio.crearCobranza(
        clienteId: widget.clienteId,
        metodoPago: _metodoPago,
        nota: _notaCtrl.text.trim().isEmpty ? null : _notaCtrl.text.trim(),
        detalles: seleccionadas.map((f) => {
          'venta_id': f.venta['id'],
          'monto': double.parse(f.montoCtrl.text.trim()),
        }).toList(),
      );
      if (mounted) {
        Notificacion.exito(context, 'Cobro registrado');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) Notificacion.error(context, e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 480, maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              gradient: ColoresCarolina.gradienteMarca,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(children: [
              const Icon(Icons.payments_outlined, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Expanded(child: Text('Registrar cobro a ${widget.clienteNombre}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  overflow: TextOverflow.ellipsis)),
              IconButton(onPressed: () => Navigator.pop(context), tooltip: 'Cerrar',
                  icon: const Icon(Icons.close, color: Colors.white)),
            ]),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Marca las cuentas que el cliente está pagando ahora. '
                    'Puedes pagar una sola, varias, o solo una parte de cada una.',
                    style: TextStyle(fontSize: 12.5, color: ColoresCarolina.grisMedio)),
                const SizedBox(height: 12),
                ..._filas.map((f) => _filaCuenta(f)),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                      color: ColoresCarolina.celesteSuave, borderRadius: BorderRadius.circular(10)),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('TOTAL A COBRAR', style: TextStyle(fontSize: 12,
                        fontWeight: FontWeight.bold, color: ColoresCarolina.celesteOscuro)),
                    Text('Bs ${_totalSeleccionado.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                            color: ColoresCarolina.celesteOscuro)),
                  ]),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _metodoPago,
                  decoration: InputDecoration(
                    labelText: 'Método de pago *',
                    prefixIcon: const Icon(Icons.account_balance_wallet_outlined,
                        color: ColoresCarolina.celeste),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: ColoresCarolina.celeste, width: 2)),
                  ),
                  items: kMetodosPago.entries
                      .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                      .toList(),
                  onChanged: (v) => setState(() => _metodoPago = v ?? 'efectivo'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notaCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Nota (opcional)',
                    prefixIcon: const Icon(Icons.notes_rounded, color: ColoresCarolina.celeste),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: ColoresCarolina.celeste, width: 2)),
                  ),
                ),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                    foregroundColor: ColoresCarolina.grisMedio,
                    side: BorderSide(color: Colors.grey.shade300),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                child: const Text('Cancelar'),
              )),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: ElevatedButton(
                onPressed: _cargando ? null : _guardar,
                style: ElevatedButton.styleFrom(
                    backgroundColor: ColoresCarolina.celeste, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                child: _cargando
                    ? const SizedBox(height: 20, width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Registrar cobro', style: TextStyle(fontWeight: FontWeight.bold)),
              )),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _filaCuenta(_FilaCobro f) {
    final fecha = (f.venta['fecha'] ?? '').toString();
    final fechaStr = fecha.length >= 10 ? fecha.substring(0, 10) : fecha;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: f.seleccionada ? ColoresCarolina.celeste.withValues(alpha: 0.06) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ColoresCarolina.borde),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Checkbox(
            value: f.seleccionada,
            activeColor: ColoresCarolina.celeste,
            onChanged: (v) => setState(() => f.seleccionada = v == true),
          ),
          Expanded(
            child: Text('Nota ${f.venta['numero_recibo'] ?? '-'} ($fechaStr)',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                overflow: TextOverflow.ellipsis),
          ),
          Text('Saldo: Bs ${f.saldo.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 12, color: ColoresCarolina.rojo,
                  fontWeight: FontWeight.bold)),
        ]),
        if (f.seleccionada)
          Padding(
            padding: const EdgeInsets.fromLTRB(40, 0, 8, 8),
            child: TextField(
              controller: f.montoCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Monto a pagar de esta cuenta (Bs)',
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
      ]),
    );
  }
}
