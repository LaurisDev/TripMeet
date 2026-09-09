import 'package:flutter/material.dart';

import 'lugares_service.dart';

import 'detalle_lugar_screen.dart';

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

  Future<void> _buscar() async {
    setState(() {
      _cargando = true;
      _busquedaRealizada = true;
    });

    try {
      final resultados =
          await _lugaresService.buscarLugares(_buscadorController.text);

      if (!mounted) return;

      setState(() {
        _resultados = resultados;
        _cargando = false;
      });
    } catch (error) {
      print('ERROR AL BUSCAR: $error');
      if (!mounted) return;

      setState(() {
        _resultados = [];
        _cargando = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudieron buscar los lugares.'),
        ),
      );
    }
  }

  @override
  void dispose() {
    _buscadorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscar lugares'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _buscadorController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _buscar(),
              decoration: InputDecoration(
                hintText: 'Escribe un lugar',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _buscar,
                ),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _cargando
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : !_busquedaRealizada
                      ? const Center(
                          child: Text(
                            'Busca un lugar para ver los resultados.',
                            textAlign: TextAlign.center,
                          ),
                        )
                      : _resultados.isEmpty
                          ? const Center(
                              child: Text(
                                'No se encontraron lugares.',
                                textAlign: TextAlign.center,
                              ),
                            )
                          : ListView.builder(
                              itemCount: _resultados.length,
                              itemBuilder: (context, index) {
                                final lugar = _resultados[index];

                                return Card(
                                  child: ListTile(
                                    leading: const Icon(
                                      Icons.place,
                                      size: 32,
                                    ),
                                    title: Text(lugar.nombre),
                                    subtitle: Text(lugar.ubicacion),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => DetalleLugarScreen(lugar: lugar),
                                        ),
  );
},
                                      // Aquí conectaremos HU-06.
                                    
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}