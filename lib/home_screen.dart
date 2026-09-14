import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'buscar_lugares_screen.dart';
import 'mapa_exploracion_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.rol, this.avisoRevision});

  final String? rol;
  final String? avisoRevision;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _indiceActual = 0;

  // Lista de pantallas integradas de todos los compañeros
  late final List<Widget> _pantallas;

  @override
  void initState() {
    super.initState();
    _pantallas = [
      _buildInicio(),               // Tu diseño innovador
      const BuscarLugaresScreen(),  // Tu HU-07 (Categorías)
      const MapaExploracionScreen(), // Lo de July (Mapa)
      const Center(child: Text('Perfil próximamente')), // Espacio para Lau/Felipe
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pantallas[_indiceActual],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _indiceActual,
        onTap: (index) => setState(() => _indiceActual = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.verdeAzulado,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Inicio'),
          BottomNavigationBarItem(icon: Icon(Icons.search_rounded), label: 'Explorar'),
          BottomNavigationBarItem(icon: Icon(Icons.map_rounded), label: 'Mapa'),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Perfil'),
        ],
      ),
    );
  }

  Widget _buildInicio() {
    final double anchoPantalla = MediaQuery.of(context).size.width;
    final bool esPantallaPequena = anchoPantalla < 360;
    final double paddingHorizontal = esPantallaPequena ? 20 : 28;

    return Scaffold(
      backgroundColor: AppTheme.crema,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              // ENCABEZADO ANDERSON
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(paddingHorizontal, 32, paddingHorizontal, 40),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.azulPetroleo, AppTheme.verdeAzulado],
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(40),
                    bottomRight: Radius.circular(40),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.travel_explore, size: 48, color: AppTheme.crema),
                    const SizedBox(width: 12),
                    Text('TripMeet',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: esPantallaPequena ? 24 : 28,
                      )),
                  ],
                ),
              ),
              
              if (widget.avisoRevision != null)
                _avisoAlerta(widget.avisoRevision!),

              Padding(
                padding: const EdgeInsets.all(28.0),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    _tarjetaBienvenida(),
                    const SizedBox(height: 30),
                    Text('Acciones rápidas', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 15),
                    _botonAccion('Ir al Mapa', Icons.map, () => setState(() => _indiceActual = 2)),
                    const SizedBox(height: 10),
                    _botonAccion('Buscar por Categoría', Icons.category, () => setState(() => _indiceActual = 1)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tarjetaBienvenida() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)],
      ),
      child: const Column(
        children: [
          Icon(Icons.explore_rounded, size: 80, color: AppTheme.verdeAzulado),
          SizedBox(height: 16),
          Text('¡Todo integrado Anderson! 🌍', 
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.azulPetroleo)),
          SizedBox(height: 12),
          Text('Ahora puedes ver el mapa de tus compañeros y tus propias categorías en la barra de abajo.',
            textAlign: TextAlign.center, style: TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _botonAccion(String texto, IconData icono, VoidCallback accion) {
    return ElevatedButton.icon(
      onPressed: accion,
      icon: Icon(icono),
      label: Text(texto),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 55),
        backgroundColor: AppTheme.azulPetroleo,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }

  Widget _avisoAlerta(String texto) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(12)),
      child: Text(texto, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}
