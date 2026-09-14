import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Servicio encargado del registro y la persistencia de usuarios.
class AuthService {
  /// Permite inyectar las dependencias para facilitar pruebas y reutilización.
  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  /// Registra un usuario en Firebase Authentication y crea su perfil en Firestore.
  ///
  /// Devuelve las credenciales creadas o lanza [AuthServiceException] cuando
  /// ocurre un error que puede mostrarse directamente en la interfaz.
  Future<UserCredential> registrarUsuario(
    String correo,
    String password,
    String rol,
  ) async {
    try {
      // Primero se crea la cuenta para obtener el UID que identifica al usuario.
      final UserCredential credenciales =
          await _auth.createUserWithEmailAndPassword(
        email: correo.trim(),
        password: password,
      );

      final User? usuario = credenciales.user;
      if (usuario == null) {
        throw const AuthServiceException(
          'No se pudo obtener la información del usuario registrado.',
          code: 'user-not-found-after-registration',
        );
      }

      // Los guías turísticos quedan pendientes hasta subir sus certificados y
      // completar el perfil laboral (Pantallas 2 y 3).
      final bool esGuia = rol == 'Guía turístico';

      // El UID se usa como ID para mantener una relación directa con Auth.
      await _firestore.collection('usuarios').doc(usuario.uid).set({
        'uid': usuario.uid,
        'correo': correo.trim(),
        'rol': rol,
        'estado': esGuia ? 'pendiente_aprobacion' : 'activo',
        if (esGuia) 'perfilCompleto': false,
        if (esGuia) 'estadoCertificados': 'pendiente',
        'fechaCreacion': Timestamp.now(),
      });

      return credenciales;
    } on FirebaseAuthException catch (error) {
      // Se traducen los códigos de Firebase a mensajes claros para la UI.
      throw AuthServiceException(
        _mensajeParaErrorDeAuth(error.code),
        code: error.code,
      );
    } on FirebaseException catch (error) {
      // También se ocultan detalles técnicos de Firestore al usuario final.
      throw AuthServiceException(
        'No se pudo guardar el perfil del usuario. Inténtalo de nuevo.',
        code: error.code,
      );
    } on AuthServiceException {
      rethrow;
    } catch (_) {
      throw const AuthServiceException(
        'Ocurrió un error inesperado al registrar el usuario.',
        code: 'unknown-error',
      );
    }
  }

  /// Devuelve un mensaje en español para los errores habituales de Auth.
  String _mensajeParaErrorDeAuth(String codigo) {
    switch (codigo) {
      case 'email-already-in-use':
        return 'Este correo electrónico ya está registrado.';
      case 'invalid-email':
        return 'El correo electrónico no tiene un formato válido.';
      case 'weak-password':
        return 'La contraseña es demasiado débil. Usa al menos 6 caracteres.';
      case 'operation-not-allowed':
        return 'El registro con correo y contraseña no está habilitado.';
      case 'network-request-failed':
        return 'No hay conexión a Internet. Inténtalo de nuevo.';
      default:
        return 'No se pudo registrar el usuario. Inténtalo de nuevo.';
    }
  }
}

/// Excepción de dominio con un mensaje seguro para mostrar en la interfaz.
class AuthServiceException implements Exception {
  const AuthServiceException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}
