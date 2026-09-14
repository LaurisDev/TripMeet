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

  final LugarService _servicio = LugarService();
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
      final lugares = await _servicio.obtenerLugares();
      final marcadores = <Marker>{};
      for (var i = 0; i < lugares.length; i++) {
        final lugar = lugares[i];
        if (!_coordenadasValidas(lugar.latitud, lugar.longitud)) {
          continue;
        }
        marcadores.add(
          Marker(
            markerId: MarkerId('lugar_$i'),
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
      _informarUbicacion(
        'Permiso denegado. El mapa seguirá centrado en Colombia.',
      );
      return;
    }
    if (permiso == LocationPermission.deniedForever) {
      _informarUbicacion(
        'La ubicación está bloqueada. Habilítala desde Ajustes.',
        ajustes: true,
      );
      return;
    }
    // Mientras se espera el fix preciso, usamos la última posición
    // conocida (si existe) para centrar el mapa de inmediato.
    try {
      final ultima = await Geolocator.getLastKnownPosition();
      if (ultima != null && mounted && _posicion == null) {
        setState(() => _posicion = ultima);
        await _moverCamara(
          LatLng(ultima.latitude, ultima.longitude),
          zoom: 15,
        );
      }
    } catch (_) {
      // Sin última posición conocida; seguimos con el fix en vivo.
    }
    try {
      final posicion = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      if (!mounted) return;
      setState(() {
        _posicion = posicion;
        _ubicacionCargando = false;
      });
      await _moverCamara(
        LatLng(posicion.latitude, posicion.longitude),
        zoom: 15,
      );
    } on TimeoutException {
      _informarUbicacion(
        'No se pudo obtener un GPS preciso a tiempo. Toca para reintentar.',
      );
    } catch (_) {
      _informarUbicacion(
        'No se pudo obtener tu ubicación. El mapa seguirá disponible.',
      );
    }
  }

  void _informarUbicacion(String mensaje, {bool ajustes = false}) {
    if (!mounted) return;
    setState(() {
      _ubicacionCargando = false;
      _mensajeUbicacion = mensaje;
    });
    if (ajustes) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensaje),
          action: SnackBarAction(
            label: 'Ajustes',
            onPressed: Geolocator.openAppSettings,
          ),
        ),
      );
    }
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
      final resultados = await _servicio.buscarLugares(consulta);
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo conectar con los lugares guardados.'),
        ),
      );
    }
  }

  Future<void> _seleccionar(Lugar lugar) async {
    FocusManager.instance.primaryFocus?.unfocus();
    _buscador.text = lugar.nombre;
    setState(() {
      _mostrarResultados = false;
    });
    if (!_coordenadasValidas(lugar.latitud, lugar.longitud)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Este lugar no tiene coordenadas válidas para el mapa.',
          ),
        ),
      );
      return;
    }
    await _moverCamara(LatLng(lugar.latitud, lugar.longitud), zoom: 16);
    if (mounted) _mostrarMarcador(lugar);
  }

  /// Resalta el marcador del [lugar] seleccionado mostrando su InfoWindow,
  /// para que el usuario lo toque y entre a la descripción cuando quiera.
  void _mostrarMarcador(Lugar lugar) {
    final destino = LatLng(lugar.latitud, lugar.longitud);
    for (final marcador in _marcadores) {
      if (marcador.position == destino) {
        _mapa?.showMarkerInfoWindow(marcador.markerId);
        break;
      }
    }
  }

  Future<void> _moverCamara(LatLng destino, {double zoom = 14}) async {
    final mapa = _mapa;
    if (mapa == null) return;
    await mapa.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: destino, zoom: zoom),
      ),
    );
  }

  Future<void> _centrarUsuario() async {
    if (_posicion == null) {
      await _cargarUbicacion();
      return;
    }
    await _moverCamara(
      LatLng(_posicion!.latitude, _posicion!.longitude),
      zoom: 15,
    );
  }

  bool _coordenadasValidas(double latitud, double longitud) =>
      latitud.isFinite &&
      longitud.isFinite &&
      latitud >= -90 &&
      latitud <= 90 &&
      longitud >= -180 &&
      longitud <= 180 &&
      (latitud != 0 || longitud != 0);

  void _abrirDetalle(Lugar lugar) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => DetalleLugarScreen(lugar: lugar)),
    );
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
            compassEnabled: false,
            mapToolbarEnabled: false,
            onMapCreated: (controller) {
              _mapa = controller;
              final posicion = _posicion;
              if (posicion != null) {
                _moverCamara(
                  LatLng(posicion.latitude, posicion.longitude),
                  zoom: 15,
                );
              }
            },
          ),
          SafeArea(
            child: Column(
              children: [
                _barraBusqueda(),
                const SizedBox(height: 10),
                _filtros(),
                if (_mensajeUbicacion != null) _avisoUbicacion(),
                if (_mostrarResultados) _listaResultados(),
                const Spacer(),
                _botonUbicacion(),
                _panelInferior(),
              ],
            ),
          ),
          if (_cargando) _carga(),
          if (_error != null) _avisoError(),
          if (!_cargando && _error == null && _marcadores.isEmpty)
            _sinLugares(),
        ],
      ),
    );
  }

  Widget _barraBusqueda() => Padding(
    padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
    child: Material(
      color: AppTheme.superficieClara,
      elevation: 5,
      borderRadius: BorderRadius.circular(28),
      child: TextField(
        controller: _buscador,
        onChanged: _buscar,
        onSubmitted: _buscar,
        textInputAction: TextInputAction.search,
        decoration: const InputDecoration(
          hintText: '¿Qué quieres explorar?',
          prefixIcon: Icon(Icons.search),
          suffixIcon: Icon(Icons.person_outline),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    ),
  );

  Widget _filtros() => SizedBox(
    height: 36,
    child: ListView(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      scrollDirection: Axis.horizontal,
      children: const [
        _FiltroMapa('Medellín y alrededores', true),
        _FiltroMapa('Restaurantes'),
        _FiltroMapa('Guías'),
      ],
    ),
  );

  Widget _listaResultados() => Container(
    margin: const EdgeInsets.fromLTRB(18, 8, 18, 0),
    constraints: const BoxConstraints(maxHeight: 220),
    decoration: BoxDecoration(
      color: AppTheme.superficieClara,
      borderRadius: BorderRadius.circular(16),
      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
    ),
    child: _buscando
        ? const Padding(
            padding: EdgeInsets.all(18),
            child: Center(child: CircularProgressIndicator()),
          )
        : _resultados.isEmpty
        ? const Padding(
            padding: EdgeInsets.all(18),
            child: Text('No se encontraron lugares guardados.'),
          )
        : ListView.builder(
            shrinkWrap: true,
            itemCount: _resultados.length,
            itemBuilder: (_, i) {
              final lugar = _resultados[i];
              return ListTile(
                dense: true,
                leading: const Icon(Icons.place, color: AppTheme.verdeAzulado),
                title: Text(lugar.nombre),
                subtitle: Text(lugar.ubicacion),
                onTap: () => _seleccionar(lugar),
                trailing: PopupMenuButton<String>(
                  tooltip: 'Más opciones',
                  onSelected: (opcion) {
                    if (opcion == 'descripcion') _abrirDetalle(lugar);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem<String>(
                      value: 'descripcion',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.description_outlined),
                        title: Text('Ver descripción'),
                      ),
                    ),
                  ],
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
        heroTag: 'centrar-ubicacion',
        mini: true,
        backgroundColor: AppTheme.superficieClara,
        foregroundColor: AppTheme.naranjaQuemado,
        onPressed: _ubicacionCargando ? null : _centrarUsuario,
        tooltip: 'Centrar en mi ubicación',
        child: const Icon(Icons.my_location),
      ),
    ),
  );

  Widget _panelInferior() => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
    decoration: const BoxDecoration(
      color: AppTheme.superficieClara,
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(child: Container(width: 36, height: 4, color: AppTheme.crema)),
        const SizedBox(height: 10),
        Text('Cerca de ti', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        const Row(
          children: [
            Expanded(
              child: _LugarCercano(
                'Explora lugares turísticos',
                Color(0xFF789286),
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: _LugarCercano('Descubre Medellín', Color(0xFFB99A78)),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _carga() => const Center(
    child: Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: CircularProgressIndicator(),
      ),
    ),
  );

  Widget _avisoError() => Center(
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _cargarLugares,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _sinLugares() => Positioned(
    left: 18,
    right: 18,
    bottom: 210,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          'No hay lugares turísticos con coordenadas válidas.',
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );

  Widget _avisoUbicacion() => Padding(
    padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
    child: Material(
      color: AppTheme.superficieClara,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            const Icon(Icons.location_off, color: AppTheme.naranjaQuemado),
            const SizedBox(width: 8),
            Expanded(child: Text(_mensajeUbicacion!)),
          ],
        ),
      ),
    ),
  );
}

class _FiltroMapa extends StatelessWidget {
  const _FiltroMapa(this.texto, [this.destacado = false]);
  final String texto;
  final bool destacado;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(right: 8),
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
    decoration: BoxDecoration(
      color: AppTheme.superficieClara,
      borderRadius: BorderRadius.circular(18),
      boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 4)],
    ),
    child: Text(
      texto,
      style: TextStyle(
        color: destacado ? AppTheme.azulPetroleo : AppTheme.textoSuave,
        fontSize: 12,
        fontWeight: destacado ? FontWeight.w600 : FontWeight.w500,
      ),
    ),
  );
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
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(9),
    ),
    child: Text(
      nombre,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
    ),
  );
}
