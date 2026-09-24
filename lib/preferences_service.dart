import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Categorías de interés disponibles para personalizar recomendaciones.
///
/// Se usan tanto en la selección de chips de [PreferencesService] como
/// respaldo "amplio" cuando el turista no ha configurado preferencias.
const List<String> categoriasDeInteres = <String>[
  'Naturaleza',
  'Aventura',
  'Fotografía',
  'Gastronomía',
  'Cultura',
  'Playa',
  'Vida nocturna',
  'Historia',
];

/// Gestiona las preferencias de recomendación del turista, guardadas en
/// `usuarios/{uid}` junto al resto de su perfil (uid, correo, rol, ...).
///
/// Se mantiene separado de [AuthService] siguiendo el mismo criterio que
/// `GuiaService`: ambos escriben sobre el mismo documento de usuario, pero
/// cada uno resuelve una responsabilidad distinta.
class PreferencesService {
  PreferencesService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _documentoUsuarioActual() {
    final User? usuario = _auth.currentUser;
    if (usuario == null) {
      throw const PreferencesServiceException(
        'No hay un usuario autenticado para consultar sus preferencias.',
        code: 'user-not-authenticated',
      );
    }
    return _firestore.collection('usuarios').doc(usuario.uid);
  }

  /// Lee las categorías de interés guardadas por el turista.
  ///
  /// Devuelve una lista vacía si el campo no existe o está vacío, lo que se
  /// interpreta como "sin preferencias personalizadas" (modo general).
  Future<List<String>> obtenerPreferenciasUsuario() async {
    final DocumentReference<Map<String, dynamic>> documento =
        _documentoUsuarioActual();

    try {
      final DocumentSnapshot<Map<String, dynamic>> perfil =
          await documento.get();

      final dynamic categorias = perfil.data()?['preferenciasIntereses'];
      if (categorias is! List) {
        return <String>[];
      }

      return categorias.map((dynamic categoria) => categoria.toString()).toList();
    } on PreferencesServiceException {
      rethrow;
    } on FirebaseException catch (error) {
      throw PreferencesServiceException(
        _mensajeParaErrorDeFirestore(error.code),
        code: error.code,
      );
    } catch (_) {
      throw const PreferencesServiceException(
        'No se pudieron consultar tus preferencias. Inténtalo de nuevo.',
        code: 'preferences-lookup-failed',
      );
    }
  }

  /// Si el turista configuró categorías, las devuelve tal cual. Si no,
  /// devuelve [categoriasDeInteres] completo como respaldo "amplio" para
  /// mantener recomendaciones generales sin fricción.
  Future<List<String>> obtenerPreferenciasParaRecomendaciones() async {
    final List<String> guardadas = await obtenerPreferenciasUsuario();
    return guardadas.isEmpty ? categoriasDeInteres : guardadas;
  }

  /// Guarda las categorías seleccionadas por el turista.
  ///
  /// Usa `.update()` (no `.set()`) para no pisar el resto del perfil
  /// (uid, correo, rol, fechaCreacion).
  Future<void> guardarPreferenciasUsuario(List<String> categorias) async {
    await _actualizarPreferencias(categorias);
  }

  /// Borra las preferencias personalizadas del turista, volviendo al modo de
  /// recomendaciones generales.
  Future<void> borrarPreferenciasUsuario() async {
    await _actualizarPreferencias(const <String>[]);
  }

  Future<void> _actualizarPreferencias(List<String> categorias) async {
    final DocumentReference<Map<String, dynamic>> documento =
        _documentoUsuarioActual();

    try {
      await documento.update(<String, dynamic>{
        'preferenciasIntereses': categorias,
        'preferenciasActualizadasEn': Timestamp.now(),
      });
    } on PreferencesServiceException {
      rethrow;
    } on FirebaseException catch (error) {
      throw PreferencesServiceException(
        _mensajeParaErrorDeFirestore(error.code),
        code: error.code,
      );
    } catch (_) {
      throw const PreferencesServiceException(
        'No se pudieron guardar tus preferencias. Inténtalo de nuevo.',
        code: 'preferences-save-failed',
      );
    }
  }

  /// Devuelve un mensaje en español para los errores habituales de Firestore.
  String _mensajeParaErrorDeFirestore(String codigo) {
    switch (codigo) {
      case 'unavailable':
      case 'network-request-failed':
        return 'No se pudieron guardar tus preferencias por un problema de conexión.';
      case 'not-found':
        return 'No se encontró tu perfil de usuario.';
      case 'permission-denied':
        return 'No tienes permiso para actualizar tus preferencias.';
      default:
        return 'No se pudieron guardar tus preferencias. Inténtalo de nuevo.';
    }
  }
}

/// Excepción de dominio con un mensaje seguro para mostrar en la interfaz.
class PreferencesServiceException implements Exception {
  const PreferencesServiceException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}
