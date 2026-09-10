import 'package:flutter/material.dart';
import 'lugares_service.dart';

class DetalleLugarScreen extends StatefulWidget {
  final Lugar lugar;

  const DetalleLugarScreen({
    super.key,
    required this.lugar,
  });

  @override
  State<DetalleLugarScreen> createState() => _DetalleLugarScreenState();
}

class _DetalleLugarScreenState extends State<DetalleLugarScreen> {
  final LugaresService _lugaresService = LugaresService();
  List<Resena> _resenas = [];
  bool _cargandoResenas = true;

  @override
  void initState() {
    super.initState();
    _cargarResenas();
  }

  Future<void> _cargarResenas() async {
    try {
      final resenas = await _lugaresService.obtenerResenas(widget.lugar.id);
      setState(() {
        _resenas = resenas;
        _cargandoResenas = false;
      });
    } catch (e) {
      setState(() {
        _cargandoResenas = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool tieneDescripcion = widget.lugar.descripcion.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.lugar.nombre),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Categoría (HU-07)
            Chip(
              label: Text(widget.lugar.categoria),
              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
            ),
            const SizedBox(height: 10),
            Text(
              widget.lugar.nombre,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.lugar.ubicacion,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            Text(
              'Descripción',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),

            Text(
              tieneDescripcion
                  ? widget.lugar.descripcion
                  : 'La información de este lugar aún no está disponible.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),

            const SizedBox(height: 24),

            Text(
              'Fotos',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),

            if (widget.lugar.fotos.isEmpty)
              const Text('No hay fotos disponibles.')
            else
              SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.lugar.fotos.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Image.network(
                        widget.lugar.fotos[index],
                        width: 280,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 280,
                            color: Colors.grey.shade300,
                            alignment: Alignment.center,
                            child: const Text(
                              'No se pudo cargar la foto.',
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 32),

            // SECCIÓN DE RESEÑAS (HU-08)
            Text(
              'Reseñas de viajeros',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),

            if (_cargandoResenas)
              const Center(child: CircularProgressIndicator())
            else if (_resenas.isEmpty)
              const Text('Aún no hay reseñas. ¡Sé el primero en compartir tu experiencia!')
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _resenas.length,
                itemBuilder: (context, index) {
                  final r = _resenas[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(r.usuario, style: const TextStyle(fontWeight: FontWeight.bold)),
                              Row(
                                children: List.generate(5, (i) {
                                  return Icon(
                                    Icons.star,
                                    size: 16,
                                    color: i < r.calificacion ? Colors.amber : Colors.grey,
                                  );
                                }),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(r.comentario),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
