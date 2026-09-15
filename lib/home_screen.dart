import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_theme.dart';
import 'buscar_lugares_screen.dart';
import 'mapa_exploracion_screen.dart';
import 'recomendaciones_service.dart';
import 'lugares_service.dart';
import 'detalle_lugar_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.rol, this.avisoRevision});

  final String? rol;
  final String? avisoRevision;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _indiceActual = 0;
  final RecomendacionesService _recomendacionesService = RecomendacionesService();
  List<Lugar> _recomendados = [];
  bool _cargandoRecomendados = true;

  @override
  void initState() {
    super.initState();
    _cargarRecomendaciones();
  }

  Future<void> _cargarRecomendaciones() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final lugares = await _recomendacionesService.obtenerRecomendacionesPersonalizadas(user.uid);
      if (mounted) {
        setState(() {
          _recomendados = lugares;
          _cargandoRecomendados = false;
        });
      }
    } else {
      setState(() => _cargandoRecomendados = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Definimos las pantallas para el BottomNavBar
    final List<Widget> pantallas = [
      _buildInicio(),
      const BuscarLugaresScreen(),
      const MapaExploracionScreen(),
      const Center(child: Text('Perfil próximamente')),
    ];

    return Scaffold(
      body: pantallas[_indiceActual],
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
    final double ancho = MediaQuery.of(context).size.width;
    final bool esChica = ancho < 360;

    return Scaffold(
      backgroundColor: AppTheme.crema,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // ENCABEZADO ANDERSON
              _buildHeader(esChica),
              
              if (widget.avisoRevision != null) _buildAviso(widget.avisoRevision!),

              // --- SECCIÓN DE RECOMENDACIONES (HU-09) ---
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 30, 24, 15),
                child: Text('Recomendados para ti ✨', 
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.azulPetroleo)),
              ),
              
              _buildCarouselRecomendados(),

              // ACCIONES RÁPIDAS
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('¿Qué quieres hacer?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 15),
                    _botonAccion('Ver Mapa de Lugares', Icons.map_rounded, () => setState(() => _indiceActual = 2)),
                    const SizedBox(height: 12),
                    _botonAccion('Filtrar por Categoría', Icons.category_rounded, () => setState(() => _indiceActual = 1)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCarouselRecomendados() {
    if (_cargandoRecomendados) {
      return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
    }
    if (_recomendados.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 24),
        child: Text('Explora más lugares para recibir recomendaciones.'),
      );
    }

    return SizedBox(
      height: 250,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _recomendados.length,
        itemBuilder: (context, index) {
          final lugar = _recomendados[index];
          return GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetalleLugarScreen(lugar: lugar))),
            child: Container(
              width: 200,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, 5))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
                    child: Image.network(
                      lugar.fotos.isNotEmpty ? lugar.fotos[0] : 'https://images.unsplash.com/photo-1506744038136-46273834b3fb',
                      height: 140, width: 200, fit: BoxFit.cover,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(lugar.nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 14),
                            const SizedBox(width: 4),
                            Text(lugar.categoria, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(bool esChica) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [AppTheme.azulPetroleo, AppTheme.verdeAzulado]),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(40), bottomRight: Radius.circular(40)),
      ),
      child: Row(
        children: [
          const Icon(Icons.travel_explore, size: 48, color: AppTheme.crema),
          const SizedBox(width: 12),
          Text('TripMeet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: esChica ? 24 : 28)),
        ],
      ),
    );
  }

  Widget _buildAviso(String texto) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(12)),
      child: Text(texto, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  Widget _botonAccion(String t, IconData i, VoidCallback a) {
    return ElevatedButton.icon(
      onPressed: a, icon: Icon(i), label: Text(t),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 55),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.azulPetroleo,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: AppTheme.azulPetroleo.withOpacity(0.1))),
      ),
    );
  }
}
