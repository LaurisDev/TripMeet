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
    final bool tieneFotos = widget.lugar.fotos.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle del lugar'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _imagenPrincipal(tieneFotos),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Categoría (HU-07)
                  if (widget.lugar.categoria.trim().isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        widget.lugar.categoria,
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSecondaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    widget.lugar.nombre,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on_outlined),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.lugar.ubicacion.isEmpty
                              ? 'Ubicación no disponible'
                              : widget.lugar.ubicacion,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _seccionDescripcion(context, tieneDescripcion),
                  const SizedBox(height: 24),
                  _seccionFotos(context, tieneFotos),
                  
                  const SizedBox(height: 32),

                  // SECCIÓN DE RESEÑAS (HU-08 - Anderson)
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
          ],
        ),
      ),
    );
  }

  Widget _imagenPrincipal(bool tieneFotos) {
    if (!tieneFotos) {
      return Container(
        height: 220,
        width: double.infinity,
        color: Colors.grey.shade300,
        alignment: Alignment.center,
        child: const Icon(Icons.landscape_outlined, size: 64),
      );
    }

    return SizedBox(
      height: 260,
      width: double.infinity,
      child: Image.network(
        widget.lugar.fotos.first,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          color: Colors.grey.shade300,
          alignment: Alignment.center,
          child: const Icon(Icons.broken_image_outlined, size: 52),
        ),
      ),
    );
  }

  Widget _seccionDescripcion(BuildContext context, bool tieneDescripcion) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Descripción', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black12),
          ),
          child: Text(
            tieneDescripcion
                ? widget.lugar.descripcion
                : 'La información de este lugar aún no está disponible.',
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(height: 1.45),
          ),
        ),
      ],
    );
  }

  Widget _seccionFotos(BuildContext context, bool tieneFotos) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Fotos', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        if (!tieneFotos)
          const Text('No hay fotos disponibles.')
        else
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: widget.lugar.fotos.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) => ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  widget.lugar.fotos[index],
                  width: 170,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    width: 170,
                    color: Colors.grey.shade300,
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image_outlined),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
