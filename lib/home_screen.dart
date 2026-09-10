import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'buscar_lugares_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.rol});

  final String? rol;

  @override
  Widget build(BuildContext context) {
    final double anchoPantalla = MediaQuery.of(context).size.width;
    final bool esPantallaPequena = anchoPantalla < 360;
    final double paddingHorizontal = esPantallaPequena ? 20 : 28;

    return Scaffold(
      backgroundColor: AppTheme.crema,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              // ENCABEZADO MEJORADO
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(
                  paddingHorizontal,
                  32,
                  paddingHorizontal,
                  40,
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
                    bottomLeft: Radius.circular(40),
                    bottomRight: Radius.circular(40),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    // Logo y Título
                    Row(
                      children: [
                        const Icon(
                          Icons.travel_explore,
                          size: 48,
                          color: AppTheme.crema,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'TripMeet',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: esPantallaPequena ? 24 : 28,
                                letterSpacing: 1.2,
                              ),
                        ),
                      ],
                    ),
                    // Botón de Búsqueda Estilizado
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.search,
                          color: Colors.white,
                          size: 30,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const BuscarLugaresScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // CONTENIDO PRINCIPAL
              Padding(
                padding: const EdgeInsets.all(28.0),
                child: Column(
                  children: <Widget>[
                    const SizedBox(height: 40),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.explore_rounded,
                            size: 80,
                            color: AppTheme.verdeAzulado,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            '¡Hola, viajero! 🌍',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.azulPetroleo,
                                ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Estamos preparando las mejores aventuras para ti. Muy pronto verás aquí los planes de la comunidad.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black54,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Un botón de acceso rápido a tu función de búsqueda
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const BuscarLugaresScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.map_rounded),
                      label: const Text('Explorar Categorías'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.verdeAzulado,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        elevation: 5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
