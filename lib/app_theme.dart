import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Define la identidad visual compartida de TripMeet.
class AppTheme {
  AppTheme._();

  static const Color azulPetroleo = Color(0xFF274C56);
  static const Color verdeAzulado = Color(0xFF3E8E7E);
  static const Color naranjaQuemado = Color(0xFFD96C2C);
  static const Color ambar = Color(0xFFE7A84E);
  static const Color crema = Color(0xFFF6E2B3);
  static const Color superficieClara = Color(0xFFFFFBF2);
  static const Color textoSuave = Color(0xFF4A4A4A);

  static ThemeData get lightTheme {
    final ColorScheme colorScheme = ColorScheme.light(
      primary: naranjaQuemado,
      onPrimary: Colors.white,
      secondary: verdeAzulado,
      onSecondary: Colors.white,
      tertiary: ambar,
      onTertiary: azulPetroleo,
      surface: superficieClara,
      onSurface: textoSuave,
      error: const Color(0xFFB3261E),
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: crema,
      appBarTheme: const AppBarTheme(
        backgroundColor: azulPetroleo,
        foregroundColor: crema,
        elevation: 0,
        centerTitle: false,
      ),
      // Fraunces aporta el carácter editorial de los títulos y Work Sans mantiene
      // la lectura clara en campos, mensajes y acciones.
      textTheme: TextTheme(
        displayLarge: GoogleFonts.fraunces(
          color: azulPetroleo,
          fontWeight: FontWeight.w700,
        ),
        displayMedium: GoogleFonts.fraunces(
          color: azulPetroleo,
          fontWeight: FontWeight.w700,
        ),
        displaySmall: GoogleFonts.fraunces(
          color: azulPetroleo,
          fontWeight: FontWeight.w600,
        ),
        headlineLarge: GoogleFonts.fraunces(
          color: azulPetroleo,
          fontWeight: FontWeight.w700,
        ),
        headlineMedium: GoogleFonts.fraunces(
          color: azulPetroleo,
          fontWeight: FontWeight.w600,
        ),
        headlineSmall: GoogleFonts.fraunces(
          color: azulPetroleo,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: GoogleFonts.fraunces(
          color: azulPetroleo,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: GoogleFonts.workSans(
          color: azulPetroleo,
          fontWeight: FontWeight.w500,
        ),
        titleSmall: GoogleFonts.workSans(
          color: azulPetroleo,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: GoogleFonts.workSans(color: textoSuave),
        bodyMedium: GoogleFonts.workSans(color: textoSuave),
        bodySmall: GoogleFonts.workSans(color: textoSuave),
        labelLarge: GoogleFonts.workSans(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
        labelMedium: GoogleFonts.workSans(
          color: textoSuave,
          fontWeight: FontWeight.w500,
        ),
        labelSmall: GoogleFonts.workSans(color: textoSuave),
      ),
      cardTheme: CardThemeData(
        color: superficieClara,
        elevation: 3,
        shadowColor: azulPetroleo.withValues(alpha: 0.18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: naranjaQuemado,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: naranjaQuemado,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: superficieClara,
        labelStyle: const TextStyle(color: azulPetroleo),
        prefixIconColor: verdeAzulado,
        suffixIconColor: verdeAzulado,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: verdeAzulado),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: verdeAzulado.withValues(alpha: 0.45)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: verdeAzulado, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFB3261E)),
        ),
      ),
    );
  }
}
