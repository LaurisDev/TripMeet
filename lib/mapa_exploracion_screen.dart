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
  static const _colombia = CameraPosition(
    target: LatLng(4.5709, -74.2973),
    zoom: 5.5,
  );

  final LugaresService _servicio = LugaresService();
  final TextEditingController _buscador = TextEditingController();
  GoogleMapController? _mapa;
  Set<Marker> _marcadores = {};
  List<Lugar> _resultados = [];
  Position? _posicion;
  bool _cargando = true;
  bool _buscando = false;
  bool _mostrarResultados = false;
  bool _ubicacionCargando = true;
  String? _error;
  String? _mensajeUbicacion;

  // Anderson: Integración de categorías innovadoras en el mapa
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

  @override
  void dispose() {
    _buscador.dispose();
    _mapa?.dispose();
    super.dispose();
  }

  Future<void> _cargarLugares() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      // Filtrar marcadores por la categoría seleccionada
      final lugares = await _servicio.buscarLugares("", categoria: _categoriaSeleccionada);
      final marcadores = <Marker>{};
      for (var i = 0; i < lugares.length; i++) {
        final lugar = lugares[i];
        if (!_coordenadasValidas(lugar.latitud, lugar.longitud)) {
          continue;
        }
        marcadores.add(
          Marker(
            markerId: MarkerId('lugar_${lugar.id}'),
            position: LatLng(lugar.latitud, lugar.longitud),
            infoWindow: InfoWindow(
              title: lugar.nombre,
              snippet: lugar.ubicacion,
              onTap: () => _abrirDetalle(lugar),
            ),
            onTap: () => _abrirDetalle(lugar),
          ),
        );
      }
      if (!mounted) return;
      setState(() {
        _marcadores = marcadores;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = 'No se pudieron cargar los lugares.';
      });
    }
  }

  Future<void> _cargarUbicacion() async {
    setState(() {
      _ubicacionCargando = true;
      _mensajeUbicacion = null;
    });
    if (!await Geolocator.isLocationServiceEnabled()) {
      _informarUbicacion('Activa el GPS para centrar el mapa en tu ubicación.');
      return;
    }
    var permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
    }
    if (permiso == LocationPermission.denied) {
      _informarUbicacion('Permiso denegado.');
      return;
    }
    try {
      final posicion = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;
      setState(() {
        _posicion = posicion;
        _ubicacionCargando = false;
      });
      await _moverCamara(LatLng(posicion.latitude, posicion.longitude), zoom: 15);
    } catch (_) {
      _informarUbicacion('No se pudo obtener tu ubicación.');
    }
  }

  void _informarUbicacion(String mensaje) {
    if (!mounted) return;
    setState(() {
      _ubicacionCargando = false;
      _mensajeUbicacion = mensaje;
    });
  }

  Future<void> _buscar(String texto) async {
    final consulta = texto.trim();
    if (consulta.isEmpty) {
      setState(() {
        _resultados = [];
        _mostrarResultados = false;
      });
      return;
    }
    setState(() {
      _buscando = true;
      _mostrarResultados = true;
    });
    try {
      // Búsqueda inteligente combinando texto y categoría actual
      final resultados = await _servicio.buscarLugares(consulta, categoria: _categoriaSeleccionada);
      if (!mounted) return;
      setState(() {
        _resultados = resultados;
        _buscando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _resultados = [];
        _buscando = false;
      });
    }
  }

  Future<void> _seleccionar(Lugar lugar) async {
    FocusManager.instance.primaryFocus?.unfocus();
    _buscador.text = lugar.nombre;
    setState(() => _mostrarResultados = false);
    await _moverCamara(LatLng(lugar.latitud, lugar.longitud), zoom: 16);
    _mapa?.showMarkerInfoWindow(MarkerId('lugar_${lugar.id}'));
  }

  Future<void> _moverCamara(LatLng destino, {double zoom = 14}) async {
    final mapa = _mapa;
    if (mapa == null) return;
    await mapa.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: destino, zoom: zoom)));
  }

  bool _coordenadasValidas(double latitud, double longitud) =>
      latitud != 0 || longitud != 0;

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
            myLocationEnabled: _posicion != null,
            myLocationButtonEnabled: false,
            onMapCreated: (controller) => _mapa = controller,
          ),
          SafeArea(
            child: Column(
              children: [
                _barraBusqueda(),
                const SizedBox(height: 12),
                _filtrosCategorias(),
                if (_mostrarResultados) _listaResultados(),
              ],
            ),
          ),
          if (_cargando) const Center(child: CircularProgressIndicator()),
          Positioned(bottom: 30, right: 20, child: _botonCentrar()),
        ],
      ),
    );
  }

  Widget _barraBusqueda() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: TextField(
        controller: _buscador,
        onChanged: _buscar,
        decoration: InputDecoration(
          hintText: '¿Qué quieres explorar?',
          prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.verdeAzulado),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    ),
  );

  Widget _filtrosCategorias() => SizedBox(
    height: 50,
    child: ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      scrollDirection: Axis.horizontal,
      children: _categoriasMap.entries.map((entry) {
        final bool seleccionado = _categoriaSeleccionada == entry.key;
        return GestureDetector(
          onTap: () {
            setState(() => _categoriaSeleccionada = entry.key);
            _cargarLugares(); // Filtra marcadores en tiempo real
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.only(right: 10),
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              color: seleccionado ? AppTheme.azulPetroleo : Colors.white,
              borderRadius: BorderRadius.circular(25),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5)],
            ),
            child: Row(
              children: [
                Icon(entry.value, size: 20, color: seleccionado ? Colors.white : AppTheme.azulPetroleo),
                const SizedBox(width: 8),
                Text(entry.key, style: TextStyle(color: seleccionado ? Colors.white : AppTheme.azulPetroleo, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        );
      }).toList(),
    ),
  );

  Widget _listaResultados() => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    constraints: const BoxConstraints(maxHeight: 250),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)]),
    child: ListView.builder(
      shrinkWrap: true,
      itemCount: _resultados.length,
      itemBuilder: (_, i) => ListTile(
        leading: const Icon(Icons.place, color: AppTheme.verdeAzulado),
        title: Text(_resultados[i].nombre),
        onTap: () => _seleccionar(_resultados[i]),
      ),
    ),
  );

  Widget _botonCentrar() => FloatingActionButton(
    backgroundColor: Colors.white,
    foregroundColor: AppTheme.azulPetroleo,
    onPressed: _cargarUbicacion,
    child: const Icon(Icons.my_location),
  );
}
