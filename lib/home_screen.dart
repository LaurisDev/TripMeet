import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'buscar_lugares_screen.dart';  

/// Placeholder temporal del feed principal de TripMeet.
///
/// Más adelante aquí se mostrarán las publicaciones y planes de otros usuarios.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.rol});

  final String? rol;

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
                    IconButton(
  icon: const Icon(Icons.search),
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const BuscarLugaresScreen(),
      ),
    );
  },
),
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
