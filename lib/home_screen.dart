import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_theme.dart';

/// Placeholder temporal del feed principal de TripMeet.
///
/// Más adelante aquí se mostrarán las publicaciones y planes de otros usuarios.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.avisoRevision});

  /// Mensaje mostrado en un banner superior cuando el usuario llega desde el
  /// registro de guía y su perfil quedó en revisión.
  final String? avisoRevision;

  @override
  Widget build(BuildContext context) {
    final double anchoPantalla = MediaQuery.of(context).size.width;
    final bool esPantallaPequena = anchoPantalla < 360;
    final double paddingHorizontal = esPantallaPequena ? 16 : 24;
    final double tamanoTitulo = esPantallaPequena ? 22 : 26;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              if (avisoRevision != null)
                _BannerRevision(mensaje: avisoRevision!),
              // El mismo encabezado graduado conecta el placeholder con registro.
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(
                  paddingHorizontal,
                  28,
                  paddingHorizontal,
                  42,
                ),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      AppTheme.azulPetroleo,
                      AppTheme.verdeAzulado,
                    ],
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(32),
                    bottomRight: Radius.circular(32),
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(
                      Icons.travel_explore,
                      size: 64,
                      color: AppTheme.crema,
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Text(
                        'TripMeet',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: Colors.white,
                              fontSize: esPantallaPequena ? 26 : 32,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: paddingHorizontal),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const SizedBox(height: 48),
                      Icon(
                        Icons.explore_outlined,
                        size: tamanoTitulo + 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Bienvenido a TripMeet 🎉',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontSize: tamanoTitulo),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'El feed principal se implementará próximamente.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Banner informativo para el estado "perfil en revisión".
class _BannerRevision extends StatelessWidget {
  const _BannerRevision({required this.mensaje});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppTheme.crema,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.hourglass_top_rounded,
              size: 20, color: AppTheme.azulPetroleo),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              mensaje,
              style: GoogleFonts.workSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.azulPetroleo,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
