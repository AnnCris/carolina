// carolina/frontend/lib/servicios/auth_servicio.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import '../constantes/api.dart';

class AuthServicio {
  static const String _tokenKey    = 'auth_token';
  static const String _usuarioKey  = 'usuario_data';

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final res = await http.post(
        Uri.parse(ApiConfig.login),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email.trim().toLowerCase(),
          'password': password,
        }),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_tokenKey,   data['token'].toString());
        await prefs.setString(_usuarioKey, jsonEncode(data['usuario']));
        return data;
      }
      throw Exception(data['error'] ?? 'Error de conexión');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('No se pudo conectar al servidor');
    }
  }

  Future<Map<String, dynamic>> registro({
    required String nombre,
    required String apellidoPaterno,
    String? apellidoMaterno,
    required String email,
    required String password,
    XFile? foto,
  }) async {
    try {
      final res = await http.post(
        Uri.parse(ApiConfig.registro),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nombre': nombre.trim(),
          'apellido_paterno': apellidoPaterno.trim(),
          'apellido_materno': (apellidoMaterno ?? '').trim(),
          'email': email.trim().toLowerCase(),
          'password': password,
        }),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode == 201) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_tokenKey,   data['token'].toString());
        await prefs.setString(_usuarioKey, jsonEncode(data['usuario']));
        return data;
      }
      if (data['errores'] != null) {
        throw Exception((data['errores'] as Map).values.first.toString());
      }
      throw Exception(data['error'] ?? 'Error al registrar');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('No se pudo conectar al servidor');
    }
  }

  Future<String?> obtenerToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<Map<String, dynamic>?> obtenerUsuario() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_usuarioKey);
    return data != null ? jsonDecode(data) : null;
  }

  Future<void> cerrarSesion() async {
    try {
      final headers = await obtenerHeaders();
      await http.post(Uri.parse(ApiConfig.logout), headers: headers);
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_usuarioKey);
  }

  Future<bool> estaLogueado() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_tokenKey);
  }

  // Headers con Bearer token — se usa en TODOS los servicios
  Future<Map<String, String>> obtenerHeaders() async {
    final token = await obtenerToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }
}