import 'package:flutter/material.dart';

/// Placeholder temporal del feed principal de TripMeet.
///
/// Más adelante aquí se mostrarán las publicaciones y planes de otros usuarios.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final double anchoPantalla = MediaQuery.of(context).size.width;
    final bool esPantallaPequena = anchoPantalla < 360;
    final double paddingHorizontal = esPantallaPequena ? 16 : 24;
    final double tamanoTitulo = esPantallaPequena ? 22 : 26;

    return Scaffold(
      appBar: AppBar(
        title: const Text('TripMeet'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: paddingHorizontal),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.explore_outlined,
                  size: tamanoTitulo + 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Bienvenido a TripMeet 🎉',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontSize: tamanoTitulo,
                        fontWeight: FontWeight.bold,
                      ),
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
      ),
    );
  }
}
