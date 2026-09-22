import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'buscar_lugares_screen.dart';
import 'mapa_exploracion_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.rol, this.avisoRevision, this.forzarIndiceMapa = false});

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
    // Solo Inicio (Mapa), Lupa (Explorar) y Perfil
    final List<Widget> pantallas = [
      const MapaExploracionScreen(), // Índice 0
      const BuscarLugaresScreen(),    // Índice 1
      const Center(child: Text('Perfil próximamente')),    // Índice 2
    ];

    return Scaffold(
      body: pantallas[_indiceActual],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20)],
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
            BottomNavigationBarItem(icon: Icon(Icons.map_rounded), label: 'Inicio'),
            BottomNavigationBarItem(icon: Icon(Icons.search_rounded), label: 'Explorar'),
            BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Perfil'),
          ],
        ),
      ),
    );
  }
}
