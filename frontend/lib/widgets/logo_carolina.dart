// carolina/frontend/lib/widgets/logo_carolina.dart
import 'package:flutter/material.dart';
import '../constantes/colores.dart';

/// Logo de la Distribuidora de Quesos Carolina.
///
/// Muestra assets/images/logo_carolina.png si existe. Si el archivo
/// todavía no fue agregado al proyecto, cae automáticamente en un
/// monograma "C" de respaldo (no rompe la app mientras tanto).
/// Al estar centralizado acá, el logo se actualiza en toda la app
/// (login, sidebar) con un solo archivo.
class LogoCarolina extends StatelessWidget {
  static const String ruta = 'assets/images/logo_carolina.png';

  final double tamano;
  /// true: para usar sobre fondos celeste/azul (círculo translúcido de respaldo).
  /// false: para usar sobre fondos claros (círculo con degradado de respaldo).
  final bool sobreFondoOscuro;

  const LogoCarolina({
    super.key,
    this.tamano = 56,
    this.sobreFondoOscuro = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tamano,
      height: tamano,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: sobreFondoOscuro
            ? null
            : [
                BoxShadow(
                  color: ColoresCarolina.celeste.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: ClipOval(
        child: Image.asset(
          ruta,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _respaldo(),
        ),
      ),
    );
  }

  Widget _respaldo() {
    return Container(
      decoration: BoxDecoration(
        gradient: sobreFondoOscuro ? null : ColoresCarolina.gradienteMarca,
        color: sobreFondoOscuro ? Colors.white.withValues(alpha: 0.16) : null,
        border: sobreFondoOscuro
            ? Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.4)
            : null,
      ),
      alignment: Alignment.center,
      child: Text(
        'C',
        style: TextStyle(
          color: Colors.white,
          fontSize: tamano * 0.5,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }
}
