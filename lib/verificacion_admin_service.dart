
import 'package:cloud_firestore/cloud_firestore.dart';

/// Servicio para consultar y gestionar solicitudes de verificación.
class VerificacionAdminService {
  VerificacionAdminService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Consulta las solicitudes pendientes de verificación.
  Stream<QuerySnapshot<Map<String, dynamic>>> solicitudesPendientes() {
    return _firestore
        .collection('usuarios')
        .where('estadoVerificacionIdentidad', isEqualTo: 'pendiente')
        .snapshots();
  }

  /// Aprueba una solicitud de verificación.
  Future<void> aprobarSolicitud(String uid) async {
    final referencia = _firestore.collection('usuarios').doc(uid);

    await _firestore.runTransaction((transaccion) async {
      final documento = await transaccion.get(referencia);

      if (!documento.exists) {
        throw Exception('El usuario no existe.');
      }

      final datos = documento.data()!;
      if (datos['estadoVerificacionIdentidad'] != 'pendiente') {
        throw Exception('La solicitud ya no está pendiente.');
      }

      transaccion.update(referencia, {
        'estadoVerificacionIdentidad': 'aprobado',
        'identidadVerificada': true,
        'fechaRevisionIdentidad': FieldValue.serverTimestamp(),
        'motivoRechazoIdentidad': FieldValue.delete(),
      });
    });
  }

  /// Rechaza una solicitud indicando el motivo.
  Future<void> rechazarSolicitud(String uid, String motivo) async {
    final motivoLimpio = motivo.trim();

    if (motivoLimpio.isEmpty) {
      throw ArgumentError('Debes escribir el motivo del rechazo.');
    }

    final referencia = _firestore.collection('usuarios').doc(uid);

    await _firestore.runTransaction((transaccion) async {
      final documento = await transaccion.get(referencia);

      if (!documento.exists) {
        throw Exception('El usuario no existe.');
      }

      final datos = documento.data()!;
      if (datos['estadoVerificacionIdentidad'] != 'pendiente') {
        throw Exception('La solicitud ya no está pendiente.');
      }

      transaccion.update(referencia, {
        'estadoVerificacionIdentidad': 'rechazado',
        'identidadVerificada': false,
        'motivoRechazoIdentidad': motivoLimpio,
        'fechaRevisionIdentidad': FieldValue.serverTimestamp(),
      });
    });
  }
}
