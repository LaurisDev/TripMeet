import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_theme.dart';
import 'buscar_lugares_screen.dart';
import 'mapa_exploracion_screen.dart';
import 'recomendaciones_service.dart';
import 'lugares_service.dart';
import 'detalle_lugar_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.rol, this.avisoRevision, this.forzarIndiceMapa = false});

  final String? rol;
  final String? avisoRevision;
  final bool forzarIndiceMapa; // Nuevo parámetro para el cambio de Juliana

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _indiceActual;
  final RecomendacionesService _recomendacionesService = RecomendacionesService();
  List<Lugar> _recomendados = [];
  bool _cargandoRecomendados = true;

  @override
  void initState() {
    super.initState();
    // Si forzarIndiceMapa es true, empezamos en el índice 2 (Mapa)
    _indiceActual = widget.forzarIndiceMapa ? 2 : 0;
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
    final List<Widget> pantallas = [
      _buildInicioTab(),
      const BuscarLugaresScreen(),
      const MapaExploracionScreen(),
      const Center(child: Text('Perfil próximamente')),
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
            BottomNavigationBarItem(icon: Icon(Icons.explore_rounded), label: 'Inicio'),
            BottomNavigationBarItem(icon: Icon(Icons.search_rounded), label: 'Explorar'),
            BottomNavigationBarItem(icon: Icon(Icons.map_rounded), label: 'Mapa'),
            BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Perfil'),
          ],
        ),
      ),
    );
  }

  Widget _buildInicioTab() {
    return Scaffold(
      backgroundColor: AppTheme.crema,
      appBar: AppBar(
        title: const Text('TripMeet'),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.azulPetroleo,
              child: Icon(Icons.person_outline, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: GestureDetector(
                onTap: () => setState(() => _indiceActual = 1),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded, color: Colors.grey.shade400),
                      const SizedBox(width: 12),
                      Text('¿A dónde quieres ir?', style: TextStyle(color: Colors.grey.shade400, fontSize: 16)),
                    ],
                  ),
                ),
              ),
            ),
            if (widget.avisoRevision != null) _buildAvisoAlerta(widget.avisoRevision!),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 30, 24, 15),
              child: Text('Recomendados para ti ✨', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.azulPetroleo)),
            ),
            _buildCarouselRecomendados(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildCarouselRecomendados() {
    if (_cargandoRecomendados) return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
    return SizedBox(
      height: 260,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _recomendados.length,
        itemBuilder: (context, index) {
          final lugar = _recomendados[index];
          return GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetalleLugarScreen(lugar: lugar))),
            child: Container(
              width: 220,
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 8))]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(30), child: Image.network(lugar.fotos.isNotEmpty ? lugar.fotos[0] : 'https://images.unsplash.com/photo-1506744038136-46273834b3fb', width: double.infinity, fit: BoxFit.cover))),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(lugar.nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1), const SizedBox(height: 4), Row(children: [const Icon(Icons.star_rounded, color: Colors.amber, size: 16), const SizedBox(width: 4), Text(lugar.categoria, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500))])]),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAvisoAlerta(String texto) => Container(margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.amber.shade100)), child: Row(children: [const Icon(Icons.info_outline_rounded, color: Colors.amber), const SizedBox(width: 10), Expanded(child: Text(texto, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)))]));
}
