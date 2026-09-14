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

  // Lista de pantallas integradas
  final List<Widget> _pantallas = [
    const InicioTab(),             // Movido a un widget separado para evitar el error de MediaQuery
    const BuscarLugaresScreen(),  
    const MapaExploracionScreen(), 
    const Center(child: Text('Perfil próximamente')), 
  ];

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
}

// Sub-widget para la pestaña de Inicio para evitar errores de contexto
class InicioTab extends StatelessWidget {
  const InicioTab({super.key});

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

              Padding(
                padding: const EdgeInsets.all(28.0),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    _tarjetaBienvenida(),
                    const SizedBox(height: 30),
                    const Text('Acciones rápidas', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 15),
                    _botonAccion(context, 'Explorar Mapa', Icons.map, Colors.blueGrey),
                    const SizedBox(height: 10),
                    _botonAccion(context, 'Buscar Categorías', Icons.category, AppTheme.azulPetroleo),
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
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 20)],
      ),
      child: const Column(
        children: [
          Icon(Icons.explore_rounded, size: 80, color: AppTheme.verdeAzulado),
          SizedBox(height: 16),
          Text('¡Todo listo, Anderson! 🌍', 
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.azulPetroleo)),
          SizedBox(height: 12),
          Text('Usa la barra de navegación de abajo para moverte entre tus categorías y el mapa del equipo.',
            textAlign: TextAlign.center, style: TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _botonAccion(BuildContext context, String texto, IconData icono, Color color) {
    return Container(
      width: double.infinity,
      height: 55,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icono, color: Colors.white),
            const SizedBox(width: 10),
            Text(texto, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
