import 'package:flutter/material.dart';
import 'lugares_service.dart';
import 'detalle_lugar_screen.dart';
import 'app_theme.dart';

class BuscarLugaresScreen extends StatefulWidget {
  const BuscarLugaresScreen({super.key});

  @override
  State<BuscarLugaresScreen> createState() => _BuscarLugaresScreenState();
}

class _BuscarLugaresScreenState extends State<BuscarLugaresScreen> {
  final TextEditingController _buscadorController = TextEditingController();
  final LugaresService _lugaresService = LugaresService();
  List<Lugar> _resultados = [];
  bool _cargando = false;
  bool _busquedaRealizada = false;
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
    _buscar(); // Carga inicial
  }

  Future<void> _buscar() async {
    setState(() { _cargando = true; _busquedaRealizada = true; });
    try {
      final resultados = await _lugaresService.buscarLugares(_buscadorController.text, categoria: _categoriaSeleccionada);
      if (mounted) setState(() { _resultados = resultados; _cargando = false; });
    } catch (_) {
      if (mounted) setState(() { _resultados = []; _cargando = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.crema,
      appBar: AppBar(
        title: const Text('Descubre'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          _barraBusqueda(),
          _selectorCategorias(),
          Expanded(
            child: _cargando 
              ? const Center(child: CircularProgressIndicator()) 
              : _buildListaResultados(),
          ),
        ],
      ),
    );
  }

  Widget _barraBusqueda() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 15),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 15)],
        ),
        child: TextField(
          controller: _buscadorController,
          onSubmitted: (_) => _buscar(),
          decoration: InputDecoration(
            hintText: '¿A dónde quieres ir?',
            prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.azulPetroleo),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ),
    );
  }

  Widget _selectorCategorias() {
    return SizedBox(
      height: 110,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        children: _categoriasMap.entries.map((entry) {
          bool seleccionado = _categoriaSeleccionada == entry.key;
          return GestureDetector(
            onTap: () {
              setState(() => _categoriaSeleccionada = entry.key);
              _buscar();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 85,
              margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              decoration: BoxDecoration(
                color: seleccionado ? AppTheme.azulPetroleo : Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: seleccionado ? AppTheme.azulPetroleo.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10, offset: const Offset(0, 5)
                  )
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(entry.value, color: seleccionado ? Colors.white : AppTheme.azulPetroleo, size: 28),
                  const SizedBox(height: 8),
                  Text(entry.key, style: TextStyle(
                    color: seleccionado ? Colors.white : AppTheme.azulPetroleo,
                    fontWeight: seleccionado ? FontWeight.bold : FontWeight.w500,
                    fontSize: 11,
                  )),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildListaResultados() {
    if (_resultados.isEmpty && _busquedaRealizada) {
      return const Center(child: Text('No encontramos lugares para ti.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      physics: const BouncingScrollPhysics(),
      itemCount: _resultados.length,
      itemBuilder: (context, index) {
        final lugar = _resultados[index];
        return GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetalleLugarScreen(lugar: lugar))),
          child: Container(
            margin: const EdgeInsets.only(bottom: 25),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(35),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 10))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(35),
              child: Stack(
                alignment: Alignment.bottomLeft,
                children: [
                  Image.network(
                    lugar.fotos.isNotEmpty ? lugar.fotos[0] : 'https://images.unsplash.com/photo-1506744038136-46273834b3fb',
                    height: 220, width: double.infinity, fit: BoxFit.cover,
                  ),
                  Container(
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(lugar.nombre, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                        Row(
                          children: [
                            const Icon(Icons.location_on_rounded, color: Colors.white70, size: 16),
                            const SizedBox(width: 4),
                            Text(lugar.ubicacion, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 20, right: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(20)),
                      child: Text(lugar.categoria, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.azulPetroleo)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
