import 'package:flutter/material.dart';

import 'lugares_service.dart';

class DetalleLugarScreen extends StatelessWidget {
  final Lugar lugar;

  const DetalleLugarScreen({
    super.key,
    required this.lugar,
  });

  @override
  Widget build(BuildContext context) {
    final bool tieneDescripcion = lugar.descripcion.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(lugar.nombre),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lugar.nombre,
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
                    lugar.ubicacion,
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
                  ? lugar.descripcion
                  : 'La información de este lugar aún no está disponible.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),

            const SizedBox(height: 24),

            Text(
              'Fotos',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),

            if (lugar.fotos.isEmpty)
              const Text('No hay fotos disponibles.')
            else
              SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: lugar.fotos.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Image.network(
                        lugar.fotos[index],
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
          ],
        ),
      ),
    );
  }
}