import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'app_theme.dart';
import 'detalle_lugar_screen.dart';
import 'lugares_service.dart';

class MapaExploracionScreen extends StatefulWidget {
  const MapaExploracionScreen({super.key});

  @override
  State<MapaExploracionScreen> createState() => _MapaExploracionScreenState();
}

class _MapaExploracionScreenState extends State<MapaExploracionScreen> {
  static const _colombia = CameraPosition(target: LatLng(4.5709, -74.2973), zoom: 5.5);
  final LugaresService _servicio = LugaresService();
  final TextEditingController _buscador = TextEditingController();
  GoogleMapController? _mapa;
  Set<Marker> _marcadores = {};
  List<Lugar> _resultados = [];
  Position? _posicion;
  bool _cargando = true;
  bool _buscando = false;
  bool _mostrarResultados = false;
  
  String _categoriaSeleccionada = 'Todos';
  final Map<String, IconData> _categoriasMap = {
    'Todos': Icons.grid_view_rounded,
    'Playa': Icons.beach_access_rounded,
    'Montaña': Icons.terrain_rounded,
    'Ciudad': Icons.location_city_rounded,
    'Aventura': Icons.explore_rounded,
    'Cultura': Icons.museum_rounded,
  };

  @override
  void initState() {
    super.initState();
    _cargarLugares();
    _cargarUbicacion();
  }

  Future<void> _cargarLugares() async {
    try {
      final lugares = await _servicio.buscarLugares("", categoria: _categoriaSeleccionada);
      final marcadores = <Marker>{};
      for (var lugar in lugares) {
        marcadores.add(
          Marker(
            markerId: MarkerId(lugar.id),
            position: LatLng(lugar.latitud, lugar.longitud),
            infoWindow: InfoWindow(title: lugar.nombre, snippet: lugar.ubicacion),
            onTap: () => _abrirDetalle(lugar),
          ),
        );
      }
      if (mounted) setState(() { _marcadores = marcadores; _cargando = false; });
    } catch (_) {}
  }

  Future<void> _cargarUbicacion() async {
    try {
      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) permiso = await Geolocator.requestPermission();
      final posicion = await Geolocator.getCurrentPosition();
      if (mounted) setState(() => _posicion = posicion);
      _moverCamara(LatLng(posicion.latitude, posicion.longitude));
    } catch (_) {}
  }

  void _moverCamara(LatLng destino) {
    _mapa?.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: destino, zoom: 15)));
  }

  void _abrirDetalle(Lugar lugar) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => DetalleLugarScreen(lugar: lugar)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _colombia,
            markers: _marcadores,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            onMapCreated: (controller) => _mapa = controller,
            style: _mapStyle, // Estilo de mapa más limpio
          ),
          
          SafeArea(
            child: Column(
              children: [
                _barraBusquedaMinimalista(),
                const SizedBox(height: 12),
                _filtrosCapsulas(),
              ],
            ),
          ),
          
          Positioned(
            bottom: 30,
            right: 20,
            child: FloatingActionButton(
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.azulPetroleo,
              elevation: 4,
              onPressed: _cargarUbicacion,
              child: const Icon(Icons.my_location_rounded),
            ),
          ),
        ],
      ),
    );
  }

  Widget _barraBusquedaMinimalista() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 15, offset: const Offset(0, 5))],
        ),
        child: TextField(
          controller: _buscador,
          decoration: InputDecoration(
            hintText: '¿Qué quieres explorar?',
            hintStyle: TextStyle(color: Colors.grey.shade400),
            prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.azulPetroleo),
            suffixIcon: const Icon(Icons.person_outline, color: AppTheme.azulPetroleo),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 15),
          ),
        ),
      ),
    );
  }

  Widget _filtrosCapsulas() {
    return SizedBox(
      height: 45,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        children: _categoriasMap.entries.map((entry) {
          final bool seleccionado = _categoriaSeleccionada == entry.key;
          return GestureDetector(
            onTap: () {
              setState(() => _categoriaSeleccionada = entry.key);
              _cargarLugares();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: seleccionado ? AppTheme.azulPetroleo : Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(25),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
              ),
              child: Row(
                children: [
                  Icon(entry.value, size: 18, color: seleccionado ? Colors.white : AppTheme.azulPetroleo),
                  const SizedBox(width: 8),
                  Text(entry.key, style: TextStyle(
                    color: seleccionado ? Colors.white : AppTheme.azulPetroleo, 
                    fontWeight: seleccionado ? FontWeight.bold : FontWeight.w500,
                    fontSize: 13,
                  )),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  final String _mapStyle = '''
[
  {
    "featureType": "poi",
    "elementType": "labels",
    "stylers": [ { "visibility": "off" } ]
  }
]
''';
}
