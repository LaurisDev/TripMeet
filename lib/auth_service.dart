import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Servicio encargado del registro y la persistencia de usuarios.
class AuthService {
  /// Permite inyectar las dependencias para facilitar pruebas y reutilización.
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  /// Inicia sesión con una cuenta existente de Firebase Authentication.
  Future<UserCredential> iniciarSesion(String correo, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: correo.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw AuthServiceException(
        _mensajeParaErrorDeLogin(error.code),
        code: error.code,
      );
    } catch (_) {
      throw const AuthServiceException(
        'Ocurrió un error inesperado al iniciar sesión. Inténtalo de nuevo.',
        code: 'unknown-error',
      );
    }
  }

  /// Consulta el rol del usuario autenticado en su perfil de Firestore.
  Future<String> obtenerRolUsuarioActual() async {
    final User? usuario = _auth.currentUser;
    if (usuario == null) {
      throw const AuthServiceException(
        'No hay un usuario autenticado para consultar su rol.',
        code: 'user-not-authenticated',
      );
    }

    try {
      final DocumentSnapshot<Map<String, dynamic>> perfil =
          await _firestore.collection('usuarios').doc(usuario.uid).get();

      if (!perfil.exists) {
        throw const AuthServiceException(
          'No se encontró el perfil del usuario.',
          code: 'user-profile-not-found',
        );
      }

      final dynamic rol = perfil.data()?['rol'];
      if (rol is! String || rol.trim().isEmpty) {
        throw const AuthServiceException(
          'El perfil del usuario no tiene un rol asignado.',
          code: 'user-role-missing',
        );
      }

      return rol.trim();
    } on AuthServiceException {
      rethrow;
    } on FirebaseException catch (error) {
      throw AuthServiceException(
        error.code == 'unavailable' || error.code == 'network-request-failed'
            ? 'No se pudo consultar el rol por un problema de conexión.'
            : 'No se pudo consultar el rol del usuario. Inténtalo de nuevo.',
        code: error.code,
      );
    } catch (_) {
      throw const AuthServiceException(
        'No se pudo consultar el rol del usuario. Inténtalo de nuevo.',
        code: 'user-role-lookup-failed',
      );
    }
  }

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
      final UserCredential credenciales = await _auth
          .createUserWithEmailAndPassword(
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

      // El UID se usa como ID para mantener una relación directa con Auth.
      await _firestore.collection('usuarios').doc(usuario.uid).set({
        'uid': usuario.uid,
        'correo': correo.trim(),
        'rol': rol,
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

  String _mensajeParaErrorDeLogin(String codigo) {
    switch (codigo) {
      case 'invalid-email':
        return 'El correo electrónico no tiene un formato válido.';
      case 'user-not-found':
        return 'No existe una cuenta con este correo electrónico.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'El correo electrónico o la contraseña son incorrectos.';
      case 'network-request-failed':
        return 'No hay conexión a Internet. Inténtalo de nuevo.';
      case 'user-disabled':
        return 'Esta cuenta está deshabilitada.';
      case 'too-many-requests':
        return 'Demasiados intentos. Inténtalo de nuevo más tarde.';
      case 'operation-not-allowed':
        return 'El inicio de sesión con correo y contraseña no está habilitado.';
      default:
        return 'No se pudo iniciar sesión. Inténtalo de nuevo.';
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
