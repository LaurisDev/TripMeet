
import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'buscar_lugares_screen.dart';
import 'eventos_screen.dart';
import 'feed_publicaciones_screen.dart';
import 'mapa_exploracion_screen.dart';
import 'notificaciones_screen.dart';
import 'perfil_usuario_screen.dart';
import 'test_recommendations_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.rol,
    this.avisoRevision,
    this.forzarIndiceMapa = false,
  });

  final String? rol;
  final String? avisoRevision;
  final bool forzarIndiceMapa;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _indiceActual;

  @override
  void initState() {
    super.initState();
    _indiceActual = 0;
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pantallas = [
      const MapaExploracionScreen(),
      const BuscarLugaresScreen(),
      const EventosScreen(),
      const FeedPublicacionesScreen(),
      const NotificacionesScreen(),
      const PerfilUsuarioScreen(),
    ];

    return Scaffold(
      floatingActionButtonLocation: _indiceActual == 2
          ? const _FabMasArriba(
              FloatingActionButtonLocation.endFloat,
              72,
            )
          : FloatingActionButtonLocation.endFloat,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'probar-ia',
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const TestRecommendationsScreen(),
            ),
          );
        },
        icon: const Icon(Icons.smart_toy_outlined),
        label: const Text('Asistente IA'),
      ),
      body: pantallas[_indiceActual],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 20,
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _indiceActual,
          onTap: (index) => setState(() => _indiceActual = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: AppTheme.azulPetroleo,
          unselectedItemColor: Colors.grey.shade400,
          showSelectedLabels: true,
          showUnselectedLabels: false,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.map_rounded),
              label: 'Inicio',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.search_rounded),
              label: 'Explorar',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.event_rounded),
              label: 'Eventos',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.dynamic_feed_rounded),
              label: 'Publicaciones',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.notifications_outlined),
              label: 'Notificaciones',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded),
              label: 'Perfil',
            ),
          ],
        ),
      ),
    );
  }
}

/// Ubica el botón flotante unos píxeles más arriba.
class _FabMasArriba extends FloatingActionButtonLocation {
  const _FabMasArriba(this.base, this.subir);

  final FloatingActionButtonLocation base;
  final double subir;

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    final Offset offset = base.getOffset(scaffoldGeometry);
    return Offset(offset.dx, offset.dy - subir);
  }
}
