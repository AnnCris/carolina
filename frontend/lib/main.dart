// carolina/frontend/lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'constantes/colores.dart';
import 'constantes/rutas.dart';

void main() {
  runApp(const AppCarolina());
}

class AppCarolina extends StatelessWidget {
  const AppCarolina({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Distribuidora Carolina',
      debugShowCheckedModeBanner: false,

      // ── Localización (DEBE ir antes de routes) ──────────────
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'BO'),
        Locale('es'),
        Locale('en'),
      ],
      locale: const Locale('es', 'BO'),

      // ── Tema ────────────────────────────────────────────────
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: ColoresCarolina.fondo,
        colorScheme: ColorScheme.fromSeed(
          seedColor: ColoresCarolina.celeste,
          brightness: Brightness.light,
          primary: ColoresCarolina.celeste,
          secondary: ColoresCarolina.celesteOscuro,
          error: ColoresCarolina.rojo,
          surface: ColoresCarolina.blanco,
        ),
        primarySwatch: ColoresCarolina.celestePrimario,
        fontFamily: 'Roboto',
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: ColoresCarolina.textoFuerte),
        ).apply(
          bodyColor: ColoresCarolina.textoFuerte,
          displayColor: ColoresCarolina.textoFuerte,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: ColoresCarolina.celeste,
          foregroundColor: ColoresCarolina.blanco,
          elevation: 0,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: ColoresCarolina.blanco,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: ColoresCarolina.borde),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: ColoresCarolina.celeste,
            foregroundColor: ColoresCarolina.blanco,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: ColoresCarolina.celesteOscuro,
            side: const BorderSide(color: ColoresCarolina.celeste),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: ColoresCarolina.celesteSuave,
          labelStyle: const TextStyle(color: ColoresCarolina.celesteOscuro),
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: ColoresCarolina.blanco,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: ColoresCarolina.borde),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: ColoresCarolina.borde),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(
                color: ColoresCarolina.celeste, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: ColoresCarolina.borde,
          thickness: 1,
        ),
      ),

      // ── Rutas ────────────────────────────────────────────────
      initialRoute: RutasApp.login,
      routes: RutasApp.rutas,
    );
  }
}