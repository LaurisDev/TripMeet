import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_theme.dart';

/// Estilos compartidos por las pantallas de registro (Pantallas 1, 2 y 3)
/// para mantener colores, tipografía, radios y espaciado consistentes.
class FormStyles {
  FormStyles._();

  // --- ESPACIADO ---
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s28 = 28;

  // --- RADIOS ---
  static const double radio = 12;
  static const double radioTarjeta = 24;
  static const double radioPill = 30;

  static const Color colorError = Color(0xFFB3261E);
  static const Color colorBorde = Color(0xFFE6E6E6);

  // --- TIPOGRAFÍA (una sola familia: Work Sans, variando el peso) ---
  static TextStyle titulo({bool pequena = false}) => GoogleFonts.workSans(
        fontSize: pequena ? 22 : 24,
        fontWeight: FontWeight.w600,
        color: AppTheme.azulPetroleo,
        height: 1.2,
        letterSpacing: -0.2,
      );

  static TextStyle subtitulo({bool pequena = false}) => GoogleFonts.workSans(
        fontSize: pequena ? 14 : 16,
        color: AppTheme.textoSuave,
        height: 1.4,
      );

  static TextStyle etiqueta() => GoogleFonts.workSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppTheme.azulPetroleo,
      );

  static TextStyle ayuda() => GoogleFonts.workSans(
        fontSize: 12,
        color: AppTheme.textoSuave.withValues(alpha: 0.7),
        fontStyle: FontStyle.italic,
      );

  static TextStyle error() => GoogleFonts.workSans(
        fontSize: 12,
        color: colorError,
      );

  static TextStyle cuerpo({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color? color,
  }) =>
      GoogleFonts.workSans(
        fontSize: size,
        fontWeight: weight,
        color: color ?? AppTheme.textoSuave,
      );

  // --- INPUTS (mismo alto, padding y borde que la Pantalla 1) ---
  static InputDecoration input({
    required String label,
    String? hint,
    IconData? icon,
    Widget? suffixIcon,
    String? errorText,
    String? helperText,
  }) {
    OutlineInputBorder borde(Color color, double width) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(radio),
          borderSide: BorderSide(color: color, width: width),
        );

    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helperText,
      errorText: errorText,
      prefixIcon: icon == null
          ? null
          : Icon(icon, size: 20, color: AppTheme.azulPetroleo),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: borde(colorBorde, 1),
      enabledBorder: borde(colorBorde, 1),
      focusedBorder: borde(AppTheme.verdeAzulado, 2),
      errorBorder: borde(colorError, 1),
      focusedErrorBorder: borde(colorError, 2),
      labelStyle: GoogleFonts.workSans(color: AppTheme.textoSuave),
      helperStyle: ayuda().copyWith(fontStyle: FontStyle.normal),
      errorStyle: error(),
    );
  }

  // --- BOTÓN PRIMARIO ---
  static ButtonStyle botonPrimario({Color? color}) => FilledButton.styleFrom(
        backgroundColor: color ?? AppTheme.azulPetroleo,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radio),
        ),
        elevation: 1,
        textStyle: GoogleFonts.workSans(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      );

  static ButtonStyle botonSecundario() => OutlinedButton.styleFrom(
        foregroundColor: AppTheme.azulPetroleo,
        minimumSize: const Size.fromHeight(48),
        side: const BorderSide(color: colorBorde),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radio),
        ),
        textStyle: GoogleFonts.workSans(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      );
}
