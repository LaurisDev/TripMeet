import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'cloudinary_service.dart';
import 'guia_service.dart' show ArchivoLocal;

/// Extensiones de imagen aceptadas para una publicación.
const List<String> extensionesImagenPermitidas = <String>[
  'jpg',
  'jpeg',
  'png',
  'webp',
];

/// Publicación de un turista: una foto con descripción opcional, visible en
/// su propio perfil.
class Publicacion {
  const Publicacion({
    required this.id,
    required this.uid,
    required this.imagenUrl,
    required this.imagenPublicId,
    required this.fechaCreacion,
    this.descripcion,
  });

  final String id;
  final String uid;
  final String imagenUrl;
  final String imagenPublicId;
  final String? descripcion;
  final DateTime fechaCreacion;

  factory Publicacion.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> documento,
  ) {
    final Map<String, dynamic> datos = documento.data() ?? <String, dynamic>{};
    final String? descripcion = datos['descripcion'] as String?;

    return Publicacion(
      id: documento.id,
      uid: datos['uid'] as String? ?? '',
      imagenUrl: datos['imagenUrl'] as String? ?? '',
      imagenPublicId: datos['imagenPublicId'] as String? ?? '',
      descripcion: (descripcion == null || descripcion.trim().isEmpty)
          ? null
          : descripcion,
      fechaCreacion:
          (datos['fechaCreacion'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

/// Excepción de dominio con un mensaje seguro para mostrar en la interfaz.
class PublicacionServiceException implements Exception {
  const PublicacionServiceException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

/// Gestiona la creación y consulta de publicaciones del turista: sube la foto
/// a Cloudinary (reutilizando el mismo patrón que los certificados de guías)
/// y guarda el documento en la colección `publicaciones` de Firestore.
class PublicacionService {
  PublicacionService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    CloudinaryService? cloudinary,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _cloudinary = cloudinary ?? CloudinaryService();

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final CloudinaryService _cloudinary;

  /// Valida que [archivo] sea una imagen soportada, revisando tanto su
  /// extensión como la firma binaria real del archivo (no solo el nombre).
  bool esImagenValida(ArchivoLocal archivo) =>
      _formatoImagenValido(archivo.bytes, archivo.extension);

  /// Sube la foto de una publicación a Cloudinary.
  ///
  /// Lanza [PublicacionServiceException] si el archivo no es una imagen
  /// válida o si falla la subida.
  Future<CloudinarySubida> subirImagen(ArchivoLocal imagen) async {
    if (!esImagenValida(imagen)) {
      throw PublicacionServiceException(
        'Formato de imagen no válido. Formatos permitidos: '
        '${extensionesImagenPermitidas.map((String e) => e.toUpperCase()).join(', ')}.',
        code: 'formato-invalido',
      );
    }

    try {
      return await _cloudinary.subirImagen(
        bytes: imagen.bytes,
        nombreArchivo: imagen.nombre,
      );
    } on CloudinaryException catch (error) {
      throw PublicacionServiceException(error.message, code: error.code);
    }
  }

  /// Crea el documento de la publicación en Firestore, ya con la imagen
  /// subida a Cloudinary.
  Future<void> crearPublicacion({
    required String imagenUrl,
    required String imagenPublicId,
    String? descripcion,
  }) async {
    final User? usuario = _auth.currentUser;
    if (usuario == null) {
      throw const PublicacionServiceException(
        'No hay un usuario autenticado para crear la publicación.',
        code: 'user-not-authenticated',
      );
    }

    try {
      final DocumentReference<Map<String, dynamic>> documento =
          _firestore.collection('publicaciones').doc();

      await documento.set(<String, dynamic>{
        'id': documento.id,
        'uid': usuario.uid,
        'imagenUrl': imagenUrl,
        'imagenPublicId': imagenPublicId,
        'descripcion':
            (descripcion == null || descripcion.trim().isEmpty)
                ? null
                : descripcion.trim(),
        'fechaCreacion': Timestamp.now(),
      });
    } on FirebaseException catch (error) {
      throw PublicacionServiceException(
        _mensajeParaErrorDeFirestore(error.code),
        code: error.code,
      );
    } catch (_) {
      throw const PublicacionServiceException(
        'No se pudo publicar tu experiencia. Inténtalo de nuevo.',
        code: 'publicacion-fallida',
      );
    }
  }

  /// Consulta las publicaciones de [uid], de la más reciente a la más
  /// antigua.
  Future<List<Publicacion>> obtenerPublicacionesDeUsuario(String uid) async {
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('publicaciones')
          .where('uid', isEqualTo: uid)
          .orderBy('fechaCreacion', descending: true)
          .get();

      return snapshot.docs.map(Publicacion.fromFirestore).toList();
    } on FirebaseException catch (error) {
      throw PublicacionServiceException(
        _mensajeParaErrorDeFirestore(error.code),
        code: error.code,
      );
    }
  }

  String _mensajeParaErrorDeFirestore(String codigo) {
    switch (codigo) {
      case 'unavailable':
      case 'network-request-failed':
        return 'No se pudo completar la operación por un problema de conexión.';
      case 'permission-denied':
        return 'No tienes permiso para realizar esta acción.';
      case 'failed-precondition':
        return 'No se pudieron cargar las publicaciones. Inténtalo de nuevo en unos minutos.';
      default:
        return 'Ocurrió un error inesperado. Inténtalo de nuevo.';
    }
  }

  bool _formatoImagenValido(Uint8List bytes, String extension) {
    if (!extensionesImagenPermitidas.contains(extension.toLowerCase())) {
      return false;
    }
    if (bytes.length < 12) {
      return false;
    }

    final bool esJpeg = bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF;
    final bool esPng = bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47;
    final bool esWebp = bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50;

    return esJpeg || esPng || esWebp;
  }
}
