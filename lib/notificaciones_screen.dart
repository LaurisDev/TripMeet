
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'notificacion_service.dart';

class NotificacionesScreen extends StatelessWidget {
  const NotificacionesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final usuario = FirebaseAuth.instance.currentUser;

    if (usuario == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notificaciones')),
        body: const Center(
          child: Text('Debes iniciar sesión para ver tus notificaciones.'),
        ),
      );
    }

    final servicio = NotificacionService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        actions: [
          TextButton(
            onPressed: () async {
              try {
                await servicio.marcarTodasComoLeidas(usuario.uid);

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Notificaciones marcadas como leídas.'),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No se pudieron actualizar los avisos.'),
                    ),
                  );
                }
              }
            },
            child: const Text('Leer todas'),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: servicio.obtenerNotificaciones(usuario.uid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('No se pudieron cargar las notificaciones.'),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final notificaciones = snapshot.data?.docs.toList() ?? [];

          notificaciones.sort((a, b) {
            final fechaA = a.data()['fechaCreacion'];
            final fechaB = b.data()['fechaCreacion'];

            final tiempoA = fechaA is Timestamp
                ? fechaA.millisecondsSinceEpoch
                : 0;
            final tiempoB = fechaB is Timestamp
                ? fechaB.millisecondsSinceEpoch
                : 0;

            return tiempoB.compareTo(tiempoA);
          });

          if (notificaciones.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.notifications_none, size: 64),
                    SizedBox(height: 12),
                    Text(
                      'No tienes notificaciones todavía.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: notificaciones.length,
            itemBuilder: (context, index) {
              final documento = notificaciones[index];
              final datos = documento.data();

              final titulo =
                  datos['titulo'] as String? ?? 'Notificación';
              final mensaje = datos['mensaje'] as String? ?? '';
              final tipo = datos['tipo'] as String? ?? '';
              final leida = datos['leida'] == true;

              IconData icono;
              switch (tipo) {
                case 'aprobacion':
                  icono = Icons.check_circle_outline;
                  break;
                case 'rechazo':
                  icono = Icons.cancel_outlined;
                  break;
                case 'correcciones':
                  icono = Icons.edit_document;
                  break;
                case 'reversion':
                  icono = Icons.history;
                  break;
                default:
                  icono = Icons.notifications_outlined;
              }

              final fecha = datos['fechaCreacion'];
              final fechaTexto = fecha is Timestamp
                  ? _formatearFecha(fecha.toDate())
                  : 'Fecha pendiente';

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                color: leida
                    ? null
                    : Theme.of(context).colorScheme.primaryContainer,
                child: ListTile(
                  leading: Icon(icono, size: 30),
                  title: Text(
                    titulo,
                    style: TextStyle(
                      fontWeight:
                          leida ? FontWeight.normal : FontWeight.bold,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(mensaje),
                        const SizedBox(height: 8),
                        Text(
                          fechaTexto,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  trailing: leida
                      ? const Icon(Icons.done, size: 20)
                      : IconButton(
                          tooltip: 'Marcar como leída',
                          icon: const Icon(Icons.mark_email_read_outlined),
                          onPressed: () async {
                            try {
                              await servicio.marcarComoLeida(documento.id);
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'No se pudo marcar como leída.',
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                        ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  static String _formatearFecha(DateTime fecha) {
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    final hora = fecha.hour.toString().padLeft(2, '0');
    final minuto = fecha.minute.toString().padLeft(2, '0');

    return '$dia/$mes/${fecha.year} - $hora:$minuto';
  }
}
