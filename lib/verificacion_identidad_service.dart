
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VerificacionIdentidadService {
  VerificacionIdentidadService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<Map<String, dynamic>?> consultarEstado() async {
    final usuario = _auth.currentUser;

    if (usuario == null) {
      throw Exception('Debes iniciar sesión.');
    }

    final documento =
        await _firestore.collection('usuarios').doc(usuario.uid).get();

    return documento.data();
  }

  Future<void> enviarSolicitud({
    required String documentoIdentidadUrl,
    required String documentoIdentidadPublicId,
  }) async {
    final usuario = _auth.currentUser;

    if (usuario == null) {
      throw Exception('Debes iniciar sesión.');
    }

    final referencia =
        _firestore.collection('usuarios').doc(usuario.uid);

    await _firestore.runTransaction((transaccion) async {
      final documento = await transaccion.get(referencia);

      if (!documento.exists) {
        throw Exception('No se encontró el perfil del usuario.');
      }

      final datos = documento.data() ?? {};
      final estado = datos['estadoVerificacionIdentidad'];

      if (estado == 'pendiente') {
        throw Exception('Ya tienes una solicitud pendiente.');
      }

      if (datos['identidadVerificada'] == true) {
        throw Exception('Tu identidad ya está verificada.');
      }

      transaccion.update(referencia, {
        'estadoVerificacionIdentidad': 'pendiente',
        'identidadVerificada': false,
        'documentoIdentidadUrl': documentoIdentidadUrl,
        'documentoIdentidadPublicId': documentoIdentidadPublicId,
        'fechaSolicitudIdentidad': FieldValue.serverTimestamp(),
        'motivoRechazoIdentidad': FieldValue.delete(),
      });
    });
  }
}
