// carolina/frontend/lib/constantes/breakpoints.dart
import 'package:flutter/material.dart';

/// Puntos de quiebre únicos para que todas las pantallas respondan igual
/// en celular, tablet y escritorio.
class Breakpoints {
  static const double movil = 700;
  static const double tablet = 1050;

  static bool esMovil(BuildContext context) =>
      MediaQuery.of(context).size.width < movil;

  static bool esTablet(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return w >= movil && w < tablet;
  }

  static bool esEscritorio(BuildContext context) =>
      MediaQuery.of(context).size.width >= tablet;
}
