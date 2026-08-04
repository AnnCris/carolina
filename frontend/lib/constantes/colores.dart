// carolina/frontend/lib/constantes/colores.dart
import 'package:flutter/material.dart';

class ColoresCarolina {
  // ── Identidad de marca: celeste, azul, rojo, blanco ─────────────────────
  static const Color celeste = Color(0xFF0EA5E9);
  static const Color celesteOscuro = Color(0xFF0369A1);
  static const Color rojo = Color(0xFFDC2626);
  static const Color rojoClaro = Color(0xFFFEE2E2);
  static const Color blanco = Color(0xFFFFFFFF);
  static const Color grisClaro = Color(0xFFF0F9FF);
  static const Color grisMedio = Color(0xFF64748B);
  static const Color fondo = Color(0xFFF8FAFC);

  // ── Añadidos para el rediseño (no reemplazan nada existente) ────────────
  static const Color celesteSuave = Color(0xFFE0F2FE);
  static const Color azulNoche = Color(0xFF0C4A6E);
  static const Color borde = Color(0xFFE2E8F0);
  static const Color textoFuerte = Color(0xFF1E293B);
  static const Color exito = Color(0xFF16A34A);
  static const Color advertencia = Color(0xFFEA580C);

  static const LinearGradient gradienteMarca = LinearGradient(
    colors: [celeste, celesteOscuro],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static List<BoxShadow> sombraTarjeta({Color? tinte}) => [
        BoxShadow(
          color: (tinte ?? Colors.black).withValues(alpha: 0.05),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];

  static const MaterialColor celestePrimario = MaterialColor(0xFF0EA5E9, {
    50: Color(0xFFF0F9FF),
    100: Color(0xFFE0F2FE),
    200: Color(0xFFBAE6FD),
    300: Color(0xFF7DD3FC),
    400: Color(0xFF38BDF8),
    500: Color(0xFF0EA5E9),
    600: Color(0xFF0284C7),
    700: Color(0xFF0369A1),
    800: Color(0xFF075985),
    900: Color(0xFF0C4A6E),
  });
}
