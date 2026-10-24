
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'verificacion_admin_service.dart';

class VerificacionAdminScreen extends StatelessWidget {
  VerificacionAdminScreen({
    super.key,
    VerificacionAdminService? servicio,
  }) : servicio = servicio ?? VerificacionAdminService();

  final VerificacionAdminService servicio;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verificación de identidad'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: servicio.solicitudesPendientes(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Error al cargar las solicitudes.'),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final solicitudes = snapshot.data?.docs ?? [];

          if (solicitudes.isEmpty) {
            return const Center(
              child: Text('No hay solicitudes pendientes.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: solicitudes.length,
            itemBuilder: (context, index) {
              final documento = solicitudes[index];
              final datos = documento.data();

              final nombre = datos['nombre']?.toString() ??
                  datos['correo']?.toString() ??
                  documento.id;

              final correo = datos['correo']?.toString() ?? '';
              final enlace =
                  datos['documentoIdentidadUrl']?.toString() ?? '';

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombre,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      if (correo.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(correo),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        'UID: ${documento.id}',
                        style: const TextStyle(
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Documento de identidad:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (enlace.isNotEmpty) ...[
                        SelectableText(enlace),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () {
                            _mostrarDocumento(
                              context,
                              enlace,
                            );
                          },
                          icon: const Icon(Icons.visibility),
                          label: const Text('Ver documento'),
                        ),
                      ] else
                        const Text(
                          'No hay enlace del documento registrado.',
                        ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () async {
                              final confirmar =
                                  await _confirmarAccion(
                                context,
                                '¿Aprobar la identidad de este usuario?',
                              );

                              if (confirmar != true) return;

                              try {
                                await servicio.aprobarSolicitud(
                                  documento.id,
                                );

                                if (!context.mounted) return;

                                ScaffoldMessenger.of(context)
                                    .showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Identidad aprobada correctamente.',
                                    ),
                                  ),
                                );
                              } catch (e) {
                                if (!context.mounted) return;

                                ScaffoldMessenger.of(context)
                                    .showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'No se pudo aprobar: $e',
                                    ),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.check_circle_outline),
                            label: const Text('Aprobar'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final motivo =
                                  await _pedirMotivoRechazo(context);

                              if (motivo == null ||
                                  motivo.trim().isEmpty) {
                                return;
                              }

                              try {
                                await servicio.rechazarSolicitud(
                                  documento.id,
                                  motivo.trim(),
                                );

                                if (!context.mounted) return;

                                ScaffoldMessenger.of(context)
                                    .showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Solicitud rechazada.',
                                    ),
                                  ),
                                );
                              } catch (e) {
                                if (!context.mounted) return;

                                ScaffoldMessenger.of(context)
                                    .showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'No se pudo rechazar: $e',
                                    ),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.cancel_outlined),
                            label: const Text('Rechazar'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _mostrarDocumento(
    BuildContext context,
    String enlace,
  ) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Documento de identidad'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Image.network(
                enlace,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progreso) {
                  if (progreso == null) return child;

                  return const SizedBox(
                    height: 200,
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'No se pudo cargar la imagen. '
                      'Verifica que el enlace sea válido '
                      'y que permita visualizar el archivo.',
                    ),
                  );
                },
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  Future<bool?> _confirmarAccion(
    BuildContext context,
    String mensaje,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          content: Text(mensaje),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );
  }

  Future<String?> _pedirMotivoRechazo(
    BuildContext context,
  ) async {
    final controlador = TextEditingController();

    final motivo = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Rechazar solicitud'),
          content: TextField(
            controller: controlador,
            autofocus: true,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Motivo del rechazo',
              hintText: 'Escribe el motivo...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final texto = controlador.text.trim();

                if (texto.isEmpty) return;

                Navigator.pop(dialogContext, texto);
              },
              child: const Text('Rechazar'),
            ),
          ],
        );
      },
    );

    controlador.dispose();
    return motivo;
  }
}
