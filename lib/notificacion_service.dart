
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificacionService {
  NotificacionService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _notificaciones =>
      _firestore.collection('notificaciones');

  // Guarda una notificación para un usuario.
  Future<void> crearNotificacion({
    required String usuarioId,
    required String titulo,
    required String mensaje,
    required String tipo,
  }) async {
    if (usuarioId.trim().isEmpty) {
      throw ArgumentError('El usuario destinatario es obligatorio.');
    }

    await _notificaciones.add({
      'usuarioId': usuarioId,
      'titulo': titulo,
      'mensaje': mensaje,
      'tipo': tipo,
      'leida': false,
      'fechaCreacion': FieldValue.serverTimestamp(),
    });
  }

  // Consulta las notificaciones de un usuario en tiempo real.
  Stream<QuerySnapshot<Map<String, dynamic>>> obtenerNotificaciones(
    String usuarioId,
  ) {
    return _notificaciones
        .where('usuarioId', isEqualTo: usuarioId)
        .snapshots();
  }

  // Marca una notificación como leída.
  Future<void> marcarComoLeida(String notificacionId) async {
    await _notificaciones.doc(notificacionId).update({
      'leida': true,
    });
  }

  // Marca todas las notificaciones de un usuario como leídas.
  Future<void> marcarTodasComoLeidas(String usuarioId) async {
    final resultado = await _notificaciones
        .where('usuarioId', isEqualTo: usuarioId)
        .where('leida', isEqualTo: false)
        .get();

    final lote = _firestore.batch();

    for (final documento in resultado.docs) {
      lote.update(documento.reference, {
        'leida': true,
      });
    }

    if (resultado.docs.isNotEmpty) {
      await lote.commit();
    }
  }
}
