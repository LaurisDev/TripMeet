import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Define la identidad visual compartida de TripMeet.
/// Estilo Minimalista y Atractivo (v2.0)
class AppTheme {
  AppTheme._();

  static const Color azulPetroleo = Color(0xFF274C56);
  static const Color verdeAzulado = Color(0xFF3E8E7E);
  static const Color verdeSuave = Color(0xFF789286);
  static const Color arena = Color(0xFFB99A78);
  static const Color naranjaQuemado = Color(0xFFD96C2C);
  static const Color crema = Color(0xFFFBF8EE); // Un poco más claro y moderno
  static const Color superficieClara = Color(0xFFFFFFFF);
  static const Color textoSuave = Color(0xFF5A5A5A);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: crema,
      colorScheme: ColorScheme.fromSeed(
        seedColor: azulPetroleo,
        primary: azulPetroleo,
        secondary: verdeAzulado,
        surface: superficieClara,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.fraunces(
          color: azulPetroleo,
          fontSize: 26,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: const IconThemeData(color: azulPetroleo),
      ),
      textTheme: TextTheme(
        headlineLarge: GoogleFonts.fraunces(
          color: azulPetroleo,
          fontWeight: FontWeight.bold,
          fontSize: 32,
        ),
        headlineMedium: GoogleFonts.fraunces(
          color: azulPetroleo,
          fontWeight: FontWeight.bold,
          fontSize: 28,
        ),
        titleLarge: GoogleFonts.fraunces(
          color: azulPetroleo,
          fontWeight: FontWeight.w600,
          fontSize: 22,
        ),
        bodyLarge: GoogleFonts.workSans(
          color: textoSuave,
          fontSize: 16,
          height: 1.5,
        ),
        bodyMedium: GoogleFonts.workSans(
          color: textoSuave,
          fontSize: 14,
        ),
        labelLarge: GoogleFonts.workSans(
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        color: superficieClara,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: azulPetroleo,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}
