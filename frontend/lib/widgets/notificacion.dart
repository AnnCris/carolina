// carolina/frontend/lib/widgets/notificacion.dart
import 'package:flutter/material.dart';
import '../constantes/colores.dart';

class Notificacion {
  static void _mostrar(BuildContext context, String mensaje,
      Color color, IconData icono) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icono, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(mensaje,
                style: const TextStyle(color: Colors.white, fontSize: 14))),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  static void exito(BuildContext context, String mensaje) =>
      _mostrar(context, mensaje, Colors.green.shade600, Icons.check_circle_outline);

  static void error(BuildContext context, String mensaje) =>
      _mostrar(context, mensaje, ColoresCarolina.rojo, Icons.error_outline);

  static void advertencia(BuildContext context, String mensaje) =>
      _mostrar(context, mensaje, Colors.orange.shade700, Icons.warning_amber_outlined);

  static void info(BuildContext context, String mensaje) =>
      _mostrar(context, mensaje, ColoresCarolina.celeste, Icons.info_outline);
}