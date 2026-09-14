import 'package:flutter/material.dart';

import 'app_theme.dart';
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
    final bool tieneFotos = lugar.fotos.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle del lugar'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _imagenPrincipal(context, tieneFotos),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lugar.nombre,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),

                  const SizedBox(height: 12),

                  // Ubicación
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.superficieClara,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.verdeAzulado.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.verdeAzulado.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.location_on,
                            color: AppTheme.verdeAzulado,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ubicación',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(
                                      color: AppTheme.azulPetroleo,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                lugar.ubicacion.isEmpty
                                    ? 'Ubicación no disponible'
                                    : lugar.ubicacion,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  _seccionDescripcion(context, tieneDescripcion),

                  const SizedBox(height: 24),

                  _seccionFotos(context, tieneFotos),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagenPrincipal(
    BuildContext context,
    bool tieneFotos,
  ) {
    if (!tieneFotos) {
      return Container(
        height: 260,
        width: double.infinity,
        decoration: const BoxDecoration(
          color: AppTheme.azulPetroleo,
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(28),
            bottomRight: Radius.circular(28),
          ),
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.landscape_outlined,
          color: AppTheme.crema,
          size: 64,
        ),
      );
    }

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(28),
        bottomRight: Radius.circular(28),
      ),
      child: SizedBox(
        height: 280,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              lugar.fotos.first,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                color: AppTheme.azulPetroleo,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.broken_image_outlined,
                  color: AppTheme.crema,
                  size: 52,
                ),
              ),
            ),

            // Degradado para mejorar la lectura de la categoría.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.55),
                  ],
                ),
              ),
            ),

            if (lugar.categoria.trim().isNotEmpty)
              Positioned(
                left: 20,
                bottom: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.naranjaQuemado,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.explore_outlined,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        lugar.categoria,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _seccionDescripcion(
    BuildContext context,
    bool tieneDescripcion,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Descripción',
          style: Theme.of(context).textTheme.titleLarge,
        ),
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
                ? lugar.descripcion
                : 'La información de este lugar aún no está disponible.',
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(height: 1.45),
          ),
        ),
      ],
    );
  }

  Widget _seccionFotos(
    BuildContext context,
    bool tieneFotos,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Fotos',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 10),
        if (!tieneFotos)
          const Text('No hay fotos disponibles.')
        else
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: lugar.fotos.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) => ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  lugar.fotos[index],
                  width: 170,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    width: 170,
                    color: Colors.grey.shade300,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.broken_image_outlined,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}