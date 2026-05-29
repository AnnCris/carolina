// carolina/frontend/lib/servicios/usuarios_servicio.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../constantes/api.dart';
import 'auth_servicio.dart';
import 'package:image_picker/image_picker.dart';

class UsuariosServicio {
  final _auth = AuthServicio();

  Future<List<dynamic>> listar() async {
    final headers = await _auth.obtenerHeaders();
    final res = await http.get(Uri.parse(ApiConfig.usuarios), headers: headers);
    if (res.statusCode == 200) return jsonDecode(res.body);
    if (res.statusCode == 401) throw Exception('Sesión expirada. Vuelve a iniciar sesión');
    throw Exception('Error al cargar usuarios (${res.statusCode})');
  }

  Future<List<dynamic>> listarRoles() async {
    final headers = await _auth.obtenerHeaders();
    final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/roles'), headers: headers);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Error al cargar roles');
  }

  Future<Map<String, dynamic>> crear(Map<String, dynamic> datos) async {
    final headers = await _auth.obtenerHeaders();
    final res = await http.post(Uri.parse(ApiConfig.usuarios),
        headers: headers, body: jsonEncode(datos));
    final data = jsonDecode(res.body);
    if (res.statusCode == 201) return data;
    if (data['errores'] != null) {
      throw Exception((data['errores'] as Map).values.first.toString());
    }
    throw Exception(data['error'] ?? 'Error al crear usuario');
  }

  Future<Map<String, dynamic>> actualizar(
      int id, Map<String, dynamic> datos) async {
    final headers = await _auth.obtenerHeaders();
    final res = await http.put(Uri.parse('${ApiConfig.usuarios}/$id'),
        headers: headers, body: jsonEncode(datos));
    final data = jsonDecode(res.body);
    if (res.statusCode == 200) return data;
    if (data['errores'] != null) {
      throw Exception((data['errores'] as Map).values.first.toString());
    }
    throw Exception(data['error'] ?? 'Error al actualizar');
  }

  Future<void> eliminar(int id) async {
    final headers = await _auth.obtenerHeaders();
    final res = await http.delete(Uri.parse('${ApiConfig.usuarios}/$id'),
        headers: headers);
    if (res.statusCode != 200) throw Exception('Error al eliminar usuario');
  }


   Future<void> subirFoto(int id, XFile foto, Map<String, String> headers) async {
    final uri = Uri.parse('${ApiConfig.usuarios}/$id/foto');
    final request = http.MultipartRequest('POST', uri);

    // Copiar headers sin Content-Type (multipart lo establece solo)
    headers.forEach((k, v) {
      if (k != 'Content-Type') request.headers[k] = v;
    });

    // Leer como bytes — funciona en web Y móvil
    final Uint8List bytes = await foto.readAsBytes();
    final nombreArchivo = foto.name.isNotEmpty ? foto.name : 'foto.jpg';

    request.files.add(http.MultipartFile.fromBytes(
      'foto',
      bytes,
      filename: nombreArchivo,
    ));

    final response = await request.send();
    if (response.statusCode != 200) {
      throw Exception('Error al subir la foto');
    }
  }
}