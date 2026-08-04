// carolina/frontend/lib/pantallas/auth/registro_pantalla.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../constantes/breakpoints.dart';
import '../../constantes/colores.dart';
import '../../constantes/rutas.dart';
import '../../servicios/auth_servicio.dart';
import '../../widgets/notificacion.dart';

class RegistroPantalla extends StatefulWidget {
  const RegistroPantalla({super.key});
  @override
  State<RegistroPantalla> createState() => _RegistroPantallaState();
}

class _RegistroPantallaState extends State<RegistroPantalla> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _apPaternoCtrl = TextEditingController();
  final _apMaternoCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _verPass = false;
  bool _verConfirm = false;
  bool _cargando = false;
  XFile? _foto;

  // Indicadores de fortaleza
  bool _tieneMinimo = false;
  bool _tieneMayuscula = false;
  bool _tieneNumero = false;
  bool _tieneEspecial = false;

  void _evaluarPassword(String valor) {
    setState(() {
      _tieneMinimo = valor.length >= 8;
      _tieneMayuscula = valor.contains(RegExp(r'[A-Z]'));
      _tieneNumero = valor.contains(RegExp(r'[0-9]'));
      _tieneEspecial = valor.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-]'));
    });
  }

  int get _nivelSeguridad {
    return [_tieneMinimo, _tieneMayuscula, _tieneNumero, _tieneEspecial]
        .where((e) => e).length;
  }

  Future<void> _seleccionarFoto() async {
    final imagen = await ImagePicker().pickImage(
        source: ImageSource.gallery, imageQuality: 80);
    if (imagen != null) setState(() => _foto = imagen);
  }

  Future<void> _registrar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_nivelSeguridad < 3) {
      Notificacion.advertencia(context,
          'Tu contraseña es débil. Agrega mayúsculas, números y símbolos.');
      return;
    }
    setState(() => _cargando = true);
    try {
      await AuthServicio().registro(
        nombre: _nombreCtrl.text.trim(),
        apellidoPaterno: _apPaternoCtrl.text.trim(),
        apellidoMaterno: _apMaternoCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
        foto: _foto,
      );
      if (mounted) {
        Notificacion.exito(context, '¡Cuenta creada! Bienvenido a Carolina');
        Navigator.pushReplacementNamed(context, RutasApp.dashboard);
      }
    } catch (e) {
      if (mounted) Notificacion.error(context, e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final movil = Breakpoints.esMovil(context);
    return Scaffold(
      backgroundColor: ColoresCarolina.fondo,
      appBar: AppBar(
        title: const Text('Crear cuenta'),
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(gradient: ColoresCarolina.gradienteMarca),
        ),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(movil ? 16 : 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: ColoresCarolina.borde),
                boxShadow: ColoresCarolina.sombraTarjeta(),
              ),
              child: Padding(
                padding: EdgeInsets.all(movil ? 22 : 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Completa tus datos',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: ColoresCarolina.celesteOscuro)),
                      const SizedBox(height: 4),
                      const Text(
                          'Solo toma un minuto crear tu cuenta',
                          style: TextStyle(
                              color: ColoresCarolina.grisMedio, fontSize: 13)),
                      const SizedBox(height: 20),
                      Center(
                        child: Column(
                          children: [
                            Tooltip(
                              message: 'Toca para elegir una foto de perfil',
                              child: GestureDetector(
                                onTap: _seleccionarFoto,
                                child: Stack(
                                  children: [
                                    CircleAvatar(
                                      radius: 50,
                                      backgroundColor: ColoresCarolina.celesteSuave,
                                      backgroundImage: _foto != null
                                          ? FileImage(File(_foto!.path)) : null,
                                      child: _foto == null
                                          ? const Icon(Icons.person, size: 50,
                                              color: ColoresCarolina.celeste) : null,
                                    ),
                                    Positioned(
                                      bottom: 0, right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: ColoresCarolina.celeste,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 2),
                                        ),
                                        child: const Icon(Icons.camera_alt,
                                            color: Colors.white, size: 16),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text('Foto de perfil (opcional)',
                                style: TextStyle(color: ColoresCarolina.grisMedio,
                                    fontSize: 12)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      _campo(_nombreCtrl, 'Nombre(s)', Icons.person_outline,
                          validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'El nombre es requerido';
                        if (v.trim().length < 2) return 'Mínimo 2 caracteres';
                        return null;
                      }),
                      const SizedBox(height: 14),

                      _campo(_apPaternoCtrl, 'Apellido Paterno', Icons.badge_outlined,
                          validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'El apellido paterno es requerido';
                        if (v.trim().length < 2) return 'Mínimo 2 caracteres';
                        return null;
                      }),
                      const SizedBox(height: 14),

                      _campo(_apMaternoCtrl, 'Apellido Materno (opcional)',
                          Icons.badge_outlined),
                      const SizedBox(height: 14),

                      _campo(_emailCtrl, 'Correo electrónico', Icons.email_outlined,
                          tipo: TextInputType.emailAddress,
                          validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'El correo es requerido';
                        if (!v.contains('@') || !v.contains('.')) {
                          return 'Correo inválido';
                        }
                        return null;
                      }),
                      const SizedBox(height: 14),

                      // Contraseña con medidor
                      TextFormField(
                        controller: _passCtrl,
                        obscureText: !_verPass,
                        onChanged: _evaluarPassword,
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_verPass ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setState(() => _verPass = !_verPass),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'La contraseña es requerida';
                          if (v.length < 8) return 'Mínimo 8 caracteres';
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      _buildMedidorPassword(),
                      const SizedBox(height: 14),

                      TextFormField(
                        controller: _confirmPassCtrl,
                        obscureText: !_verConfirm,
                        decoration: InputDecoration(
                          labelText: 'Confirmar contraseña',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_verConfirm ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setState(() => _verConfirm = !_verConfirm),
                          ),
                        ),
                        validator: (v) {
                          if (v != _passCtrl.text) return 'Las contraseñas no coinciden';
                          return null;
                        },
                      ),
                      const SizedBox(height: 28),

                      SizedBox(
                        width: double.infinity, height: 50,
                        child: ElevatedButton(
                          onPressed: _cargando ? null : _registrar,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ColoresCarolina.celeste,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _cargando
                              ? const SizedBox(height: 22, width: 22,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2.5))
                              : const Text('CREAR CUENTA',
                                  style: TextStyle(fontWeight: FontWeight.bold,
                                      fontSize: 15, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _campo(TextEditingController ctrl, String label, IconData icono,
      {String? Function(String?)? validator, TextInputType? tipo}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: tipo,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icono),
      ),
      validator: validator,
    );
  }

  Widget _buildMedidorPassword() {
    final nivel = _nivelSeguridad;
    final colores = [Colors.transparent, ColoresCarolina.rojo,
        Colors.orange, Colors.amber, Colors.green];
    final etiquetas = ['', 'Muy débil', 'Débil', 'Buena', 'Fuerte'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(4, (i) => Expanded(
            child: Container(
              margin: const EdgeInsets.only(right: 4),
              height: 5,
              decoration: BoxDecoration(
                color: i < nivel ? colores[nivel] : ColoresCarolina.grisClaro,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          )),
        ),
        const SizedBox(height: 6),
        if (_passCtrl.text.isNotEmpty)
          Text(etiquetas[nivel],
              style: TextStyle(color: colores[nivel], fontSize: 12,
                  fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8, runSpacing: 4,
          children: [
            _indicador('8+ caracteres', _tieneMinimo),
            _indicador('Mayúscula', _tieneMayuscula),
            _indicador('Número', _tieneNumero),
            _indicador('Símbolo (!@#...)', _tieneEspecial),
          ],
        ),
      ],
    );
  }

  Widget _indicador(String texto, bool cumple) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(cumple ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 14,
            color: cumple ? Colors.green : ColoresCarolina.grisMedio),
        const SizedBox(width: 4),
        Text(texto,
            style: TextStyle(
                fontSize: 11,
                color: cumple ? Colors.green : ColoresCarolina.grisMedio)),
      ],
    );
  }
}