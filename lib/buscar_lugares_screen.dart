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

  Future<void> _buscar() async {
    setState(() {
      _cargando = true;
      _busquedaRealizada = true;
    });

    try {
      final resultados = await _lugaresService.buscarLugares(
        _buscadorController.text,
        categoria: _categoriaSeleccionada,
      );

      if (!mounted) return;

      setState(() {
        _resultados = resultados;
        _cargando = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _resultados = [];
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), 
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Descubre', 
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 26)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5)),
                ],
              ),
              child: TextField(
                controller: _buscadorController,
                onSubmitted: (_) => _buscar(),
                decoration: InputDecoration(
                  hintText: '¿A dónde quieres ir?',
                  prefixIcon: Icon(Icons.search_rounded, color: AppTheme.verdeAzulado),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 18),
                ),
              ),
            ),
          ),

          // CATEGORÍAS ESTILO CÁPSULA (HU-07)
          const SizedBox(height: 15),
          SizedBox(
            height: 110,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 15),
              children: _categoriasMap.entries.map((entry) {
                bool estaSeleccionado = _categoriaSeleccionada == entry.key;
                return GestureDetector(
                  onTap: () {
                    setState(() => _categoriaSeleccionada = entry.key);
                    _buscar();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 80,
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: estaSeleccionado 
                        ? LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [AppTheme.azulPetroleo.withOpacity(0.8), AppTheme.azulPetroleo])
                        : null,
                      color: estaSeleccionado ? null : Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        if (estaSeleccionado) 
                          BoxShadow(color: AppTheme.azulPetroleo.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))
                        else
                          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(entry.value, 
                          color: estaSeleccionado ? Colors.white : AppTheme.azulPetroleo, size: 28),
                        const SizedBox(height: 8),
                        Text(entry.key, 
                          style: TextStyle(
                            color: estaSeleccionado ? Colors.white : AppTheme.azulPetroleo,
                            fontWeight: estaSeleccionado ? FontWeight.bold : FontWeight.w500,
                            fontSize: 11,
                          )),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // LISTA DE RESULTADOS ESTILO TARJETA MODERNA
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : !_busquedaRealizada
                    ? Center(child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.explore_rounded, size: 100, color: Colors.grey.shade200),
                          const SizedBox(height: 10),
                          const Text('Explora categorías para empezar', style: TextStyle(color: Colors.grey)),
                        ],
                      ))
                    : ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: _resultados.length,
                        itemBuilder: (context, index) {
                          final lugar = _resultados[index];
                          return GestureDetector(
                            onTap: () => Navigator.push(context, MaterialPageRoute(
                              builder: (context) => DetalleLugarScreen(lugar: lugar),
                            )),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 25),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(35),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10)),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(35),
                                        child: Image.network(
                                          lugar.fotos.isNotEmpty ? lugar.fotos[0] : 'https://images.unsplash.com/photo-1506744038136-46273834b3fb',
                                          height: 220,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      // Gradiente sobre la imagen para que el texto resalte
                                      Positioned.fill(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(35),
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [Colors.transparent, Colors.black.withOpacity(0.6)],
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Info flotante sobre la imagen
                                      Positioned(
                                        bottom: 20,
                                        left: 20,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(lugar.nombre, 
                                              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                                            Row(
                                              children: [
                                                const Icon(Icons.location_on, color: Colors.white70, size: 16),
                                                const SizedBox(width: 5),
                                                Text(lugar.ubicacion, style: const TextStyle(color: Colors.white70)),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Badge de categoría
                                      Positioned(
                                        top: 20,
                                        right: 20,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.3),
                                            borderRadius: BorderRadius.circular(15),
                                            border: Border.all(color: Colors.white.withOpacity(0.5)),
                                          ),
                                          child: Text(lugar.categoria, 
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
