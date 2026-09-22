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
  bool _ubicacionCargando = true;
  String? _mensajeUbicacion;

  String _categoriaSeleccionada = 'Todos';
  final List<String> _categorias = ['Todos', 'Playa', 'Montaña', 'Ciudad', 'Aventura', 'Cultura'];

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
    setState(() => _cargando = true);
    try {
      // Ahora incluimos el texto del buscador para que Felipe pueda buscar nombres
      final lugares = await _servicio.buscarLugares(_buscador.text, categoria: _categoriaSeleccionada);
      final marcadores = <Marker>{};
      for (var lugar in lugares) {
        marcadores.add(
          Marker(
            markerId: MarkerId(lugar.id),
            position: LatLng(lugar.latitud, lugar.longitud),
            infoWindow: InfoWindow(title: lugar.nombre, snippet: lugar.ubicacion, onTap: () => _abrirDetalle(lugar)),
            onTap: () => _abrirDetalle(lugar),
          ),
        );
      }
      if (mounted) setState(() { _marcadores = marcadores; _cargando = false; });
    } catch (_) { if (mounted) setState(() => _cargando = false); }
  }

  Future<void> _cargarUbicacion() async {
    try {
      final posicion = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() { _posicion = posicion; _ubicacionCargando = false; });
        _moverCamara(LatLng(posicion.latitude, posicion.longitude));
      }
    } catch (_) { if (mounted) setState(() => _ubicacionCargando = false); }
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
      backgroundColor: AppTheme.crema,
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
                const SizedBox(height: 10),
                _filtros(),
                if (_mostrarResultados) _listaResultados(),
                const Spacer(),
                _botonUbicacion(),
                _panelInferior(),
              ],
            ),
          ),
          if (_cargando) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }

  Widget _barraBusqueda() => Padding(
    padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
    child: Material(
      color: Colors.white,
      elevation: 5,
      borderRadius: BorderRadius.circular(28),
      child: TextField(
        controller: _buscador,
        onSubmitted: (_) => _cargarLugares(), // Acción al presionar Enter
        onChanged: (value) {
           // Si borra todo, recargamos automáticamente
           if (value.isEmpty) _cargarLugares();
        },
        decoration: InputDecoration(
          hintText: '¿Qué quieres explorar?',
          prefixIcon: IconButton(
            icon: const Icon(Icons.search),
            onPressed: _cargarLugares, // Botón de lupa funcional
          ),
          suffixIcon: const Icon(Icons.person_outline),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    ),
  );

  Widget _filtros() => SizedBox(
    height: 36,
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      itemCount: _categorias.length,
      itemBuilder: (context, index) {
        final cat = _categorias[index];
        final bool destacado = _categoriaSeleccionada == cat;
        return GestureDetector(
          onTap: () {
            setState(() => _categoriaSeleccionada = cat);
            _cargarLugares();
          },
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 4)],
              border: destacado ? Border.all(color: AppTheme.azulPetroleo, width: 1) : null,
            ),
            child: Text(cat, style: TextStyle(
              color: destacado ? AppTheme.azulPetroleo : Colors.grey,
              fontSize: 12,
              fontWeight: destacado ? FontWeight.w600 : FontWeight.w500,
            )),
          ),
        );
      },
    ),
  );

  Widget _botonUbicacion() => Padding(
    padding: const EdgeInsets.only(right: 18, bottom: 12),
    child: Align(
      alignment: Alignment.centerRight,
      child: FloatingActionButton(
        mini: true,
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.naranjaQuemado,
        onPressed: _cargarUbicacion,
        child: const Icon(Icons.my_location),
      ),
    ),
  );

  Widget _panelInferior() => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
    decoration: const BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(child: Container(width: 36, height: 4, color: AppTheme.crema)),
        const SizedBox(height: 10),
        const Text('Cerca de ti', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _LugarCercano('Explora lugares turísticos', AppTheme.verdeSuave)),
            const SizedBox(width: 10),
            Expanded(child: _LugarCercano('Descubre Medellín', AppTheme.arena)),
          ],
        ),
      ],
    ),
  );

  Widget _listaResultados() => const SizedBox.shrink();
}

class _LugarCercano extends StatelessWidget {
  const _LugarCercano(this.nombre, this.color);
  final String nombre;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    height: 62,
    padding: const EdgeInsets.all(10),
    alignment: Alignment.bottomLeft,
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(9)),
    child: Text(nombre, maxLines: 2, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
  );
}
