// carolina/frontend/lib/pantallas/auth/login_pantalla.dart
import 'package:flutter/material.dart';
import '../../constantes/colores.dart';
import '../../constantes/rutas.dart';
import '../../servicios/auth_servicio.dart';
import '../../widgets/notificacion.dart';

class LoginPantalla extends StatefulWidget {
  const LoginPantalla({super.key});
  @override
  State<LoginPantalla> createState() => _LoginPantallaState();
}

class _LoginPantallaState extends State<LoginPantalla> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _cargando = false;
  bool _verPassword = false;

  @override
  void initState() {
    super.initState();
    _verificarSesion();
  }

  Future<void> _verificarSesion() async {
    final logueado = await AuthServicio().estaLogueado();
    if (logueado && mounted) {
      Navigator.pushReplacementNamed(context, RutasApp.dashboard);
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _cargando = true);
    try {
      await AuthServicio().login(_emailCtrl.text.trim(), _passCtrl.text);
      if (mounted) {
        Notificacion.exito(context, '¡Bienvenido a Distribuidora Carolina!');
        Navigator.pushReplacementNamed(context, RutasApp.dashboard);
      }
    } catch (e) {
      if (mounted) Notificacion.error(context, 'Correo o contraseña incorrectos');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.of(context).size.width;
    final esMovil = ancho < 700;

    return Scaffold(
      body: Row(
        children: [
          // Panel izquierdo decorativo — solo en pantallas grandes
          if (!esMovil)
            Expanded(
              flex: 5,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [ColoresCarolina.celesteOscuro, ColoresCarolina.celeste],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.storefront_rounded,
                          color: Colors.white, size: 80),
                    ),
                    const SizedBox(height: 32),
                    const Text('Distribuidora de\nQuesos Carolina',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white,
                            fontSize: 32, fontWeight: FontWeight.bold,
                            height: 1.3)),
                    const SizedBox(height: 16),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 48),
                      height: 2,
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 16),
                    Text('Sistema de Gestión Integral',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 16)),
                    const SizedBox(height: 8),
                    Text('La Paz, Bolivia',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 14)),
                  ],
                ),
              ),
            ),

          // Panel derecho — formulario
          Expanded(
            flex: esMovil ? 1 : 4,
            child: Container(
              color: ColoresCarolina.fondo,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(40),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (esMovil) ...[
                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: ColoresCarolina.celeste,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(Icons.storefront_rounded,
                                  color: Colors.white, size: 40),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                        const Text('Bienvenido',
                            style: TextStyle(fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: ColoresCarolina.celesteOscuro)),
                        const SizedBox(height: 6),
                        const Text('Inicia sesión para continuar',
                            style: TextStyle(color: ColoresCarolina.grisMedio,
                                fontSize: 15)),
                        const SizedBox(height: 36),

                        Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              // Email
                              TextFormField(
                                controller: _emailCtrl,
                                keyboardType: TextInputType.emailAddress,
                                decoration: InputDecoration(
                                  labelText: 'Correo electrónico',
                                  hintText: 'ejemplo@carolina.bo',
                                  prefixIcon: const Icon(Icons.email_outlined,
                                      color: ColoresCarolina.celeste),
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                        color: Colors.grey.shade300),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                        color: Colors.grey.shade300),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                        color: ColoresCarolina.celeste,
                                        width: 2),
                                  ),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Ingresa tu correo';
                                  }
                                  if (!v.contains('@') || !v.contains('.')) {
                                    return 'Correo inválido';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Password
                              TextFormField(
                                controller: _passCtrl,
                                obscureText: !_verPassword,
                                decoration: InputDecoration(
                                  labelText: 'Contraseña',
                                  prefixIcon: const Icon(Icons.lock_outline,
                                      color: ColoresCarolina.celeste),
                                  suffixIcon: IconButton(
                                    icon: Icon(_verPassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                        color: ColoresCarolina.grisMedio),
                                    onPressed: () => setState(
                                        () => _verPassword = !_verPassword),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                        color: Colors.grey.shade300),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                        color: Colors.grey.shade300),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                        color: ColoresCarolina.celeste,
                                        width: 2),
                                  ),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return 'Ingresa tu contraseña';
                                  }
                                  if (v.length < 6) return 'Mínimo 6 caracteres';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 28),

                              // Botón
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: ElevatedButton(
                                  onPressed: _cargando ? null : _login,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: ColoresCarolina.celeste,
                                    foregroundColor: Colors.white,
                                    elevation: 3,
                                    shadowColor: ColoresCarolina.celeste
                                        .withValues(alpha: 0.4),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                  ),
                                  child: _cargando
                                      ? const SizedBox(
                                          height: 22, width: 22,
                                          child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2.5))
                                      : const Text('INICIAR SESIÓN',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                              letterSpacing: 1.2)),
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Divider
                              Row(children: [
                                Expanded(child: Divider(color: Colors.grey.shade300)),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12),
                                  child: Text('o',
                                      style: TextStyle(
                                          color: ColoresCarolina.grisMedio)),
                                ),
                                Expanded(child: Divider(color: Colors.grey.shade300)),
                              ]),
                              const SizedBox(height: 16),

                              // Registro
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: OutlinedButton(
                                  onPressed: () => Navigator.pushNamed(
                                      context, RutasApp.registro),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: ColoresCarolina.celeste,
                                    side: const BorderSide(
                                        color: ColoresCarolina.celeste,
                                        width: 1.5),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                  ),
                                  child: const Text('CREAR CUENTA',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          letterSpacing: 1.2)),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),
                        const Center(
                          child: Text(
                            '© 2025 Distribuidora de Quesos Carolina\nLa Paz, Bolivia',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: ColoresCarolina.grisMedio,
                                fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}