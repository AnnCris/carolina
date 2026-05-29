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
        colorScheme: ColorScheme.fromSeed(
            seedColor: ColoresCarolina.celeste),
        primarySwatch: ColoresCarolina.celestePrimario,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: ColoresCarolina.celeste,
          foregroundColor: ColoresCarolina.blanco,
          elevation: 2,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: ColoresCarolina.celeste,
            foregroundColor: ColoresCarolina.blanco,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8)),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(
                color: ColoresCarolina.celeste, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),

      // ── Rutas ────────────────────────────────────────────────
      initialRoute: RutasApp.login,
      routes: RutasApp.rutas,
    );
  }
}