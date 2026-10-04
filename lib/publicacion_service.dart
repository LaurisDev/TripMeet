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

/// Tamaño máximo permitido para la foto de una publicación (5 MB).
const int tamanoMaximoImagenBytes = 5 * 1024 * 1024;

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
    this.editado = false,
    this.fechaEdicion,
  });

  final String id;
  final String uid;
  final String imagenUrl;
  final String imagenPublicId;
  final String? descripcion;
  final DateTime fechaCreacion;

  /// `true` si el autor modificó la publicación después de crearla.
  final bool editado;

  /// Fecha de la última edición; `null` si nunca se editó.
  final DateTime? fechaEdicion;

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
      // Las publicaciones creadas antes de existir estos campos no los
      // tienen: se leen como "no editada".
      editado: datos['editado'] as bool? ?? false,
      fechaEdicion: (datos['fechaEdicion'] as Timestamp?)?.toDate(),
    );
  }

  /// Copia con los campos editables reemplazados. [descripcion] es una
  /// función para poder distinguir "no cambiar" de "dejar en `null`".
  Publicacion copyWith({
    String? imagenUrl,
    String? imagenPublicId,
    String? Function()? descripcion,
    bool? editado,
    DateTime? fechaEdicion,
  }) {
    return Publicacion(
      id: id,
      uid: uid,
      imagenUrl: imagenUrl ?? this.imagenUrl,
      imagenPublicId: imagenPublicId ?? this.imagenPublicId,
      descripcion: descripcion != null ? descripcion() : this.descripcion,
      fechaCreacion: fechaCreacion,
      editado: editado ?? this.editado,
      fechaEdicion: fechaEdicion ?? this.fechaEdicion,
    );
  }
}

/// Cambios reales que una edición aplica sobre una publicación, ya
/// validados por [PublicacionService.validarEdicion].
class EdicionPublicacion {
  const EdicionPublicacion({
    required this.actual,
    required this.cambiaDescripcion,
    this.descripcion,
    this.nuevaImagen,
  });

  final Publicacion actual;
  final bool cambiaDescripcion;

  /// Descripción normalizada (sin espacios sobrantes; `null` si quedó vacía).
  final String? descripcion;
  final ArchivoLocal? nuevaImagen;

  bool get hayCambios => cambiaDescripcion || nuevaImagen != null;
}

/// Excepción de dominio con un mensaje seguro para mostrar en la interfaz.
class PublicacionServiceException implements Exception {
  const PublicacionServiceException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

/// Gestiona la creación, consulta, edición y eliminación de publicaciones del
/// turista: sube la foto
/// a Cloudinary (mismo preset `TripMeet` que los certificados de guías, pero
/// en la carpeta `tripmeet/publicaciones` en vez de `tripmeet/certificados`)
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
  bool esImagenValida(ArchivoLocal archivo) => validarImagen(archivo) == null;

  /// Devuelve el mensaje de error de [archivo] si no cumple las reglas de
  /// imagen (formato y tamaño máximo), o `null` si es válida.
  static String? validarImagen(ArchivoLocal archivo) {
    if (!_formatoImagenValido(archivo.bytes, archivo.extension)) {
      return 'Formato de imagen no válido. Formatos permitidos: '
          '${extensionesImagenPermitidas.map((String e) => e.toUpperCase()).join(', ')}.';
    }
    if (archivo.tamano > tamanoMaximoImagenBytes) {
      return 'La imagen supera el tamaño máximo de '
          '${tamanoMaximoImagenBytes ~/ (1024 * 1024)} MB.';
    }
    return null;
  }

  /// Quita espacios sobrantes y convierte una descripción vacía en `null`,
  /// igual que al crear la publicación.
  static String? normalizarDescripcion(String? descripcion) {
    final String? limpia = descripcion?.trim();
    return (limpia == null || limpia.isEmpty) ? null : limpia;
  }

  /// Comprueba que [uidUsuario] pueda [accion] (por ejemplo, "editar" o
  /// "eliminar") la publicación [actual], sin tocar Firestore:
  ///
  /// - [uidUsuario] `null` → `user-not-authenticated`.
  /// - [actual] `null` → la publicación no existe (`not-found`, el "404").
  /// - [uidUsuario] distinto del autor → `permission-denied` (el "403").
  ///
  /// Devuelve la publicación ya verificada.
  static Publicacion validarAutoria({
    required Publicacion? actual,
    required String? uidUsuario,
    required String accion,
  }) {
    if (uidUsuario == null) {
      throw PublicacionServiceException(
        'No hay un usuario autenticado para $accion la publicación.',
        code: 'user-not-authenticated',
      );
    }
    if (actual == null) {
      throw const PublicacionServiceException(
        'La publicación ya no existe.',
        code: 'not-found',
      );
    }
    if (actual.uid != uidUsuario) {
      throw PublicacionServiceException(
        'Solo el autor puede $accion esta publicación.',
        code: 'permission-denied',
      );
    }
    return actual;
  }

  /// Reglas de negocio de la edición, sin tocar Firestore ni Cloudinary:
  ///
  /// - El usuario debe ser el autor (ver [validarAutoria]).
  /// - [nuevaImagen] debe cumplir las mismas reglas que al crear.
  ///
  /// Devuelve qué cambia realmente respecto al contenido original; si nada
  /// cambia, [EdicionPublicacion.hayCambios] es `false` y la publicación no
  /// debe marcarse como editada.
  static EdicionPublicacion validarEdicion({
    required Publicacion? actual,
    required String? uidUsuario,
    required String? descripcion,
    ArchivoLocal? nuevaImagen,
  }) {
    final Publicacion verificada = validarAutoria(
      actual: actual,
      uidUsuario: uidUsuario,
      accion: 'editar',
    );
    if (nuevaImagen != null) {
      final String? errorImagen = validarImagen(nuevaImagen);
      if (errorImagen != null) {
        throw PublicacionServiceException(errorImagen, code: 'imagen-invalida');
      }
    }

    final String? nuevaDescripcion = normalizarDescripcion(descripcion);
    return EdicionPublicacion(
      actual: verificada,
      cambiaDescripcion: nuevaDescripcion != verificada.descripcion,
      descripcion: nuevaDescripcion,
      nuevaImagen: nuevaImagen,
    );
  }

  /// Sube la foto de una publicación a Cloudinary.
  ///
  /// Lanza [PublicacionServiceException] si el archivo no es una imagen
  /// válida o si falla la subida.
  Future<CloudinarySubida> subirImagen(ArchivoLocal imagen) async {
    final String? errorImagen = validarImagen(imagen);
    if (errorImagen != null) {
      throw PublicacionServiceException(errorImagen, code: 'imagen-invalida');
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
        'editado': false,
        'fechaEdicion': null,
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

  /// Edita la publicación [publicacionId] del usuario autenticado: cambia la
  /// descripción y/o reemplaza la foto por [nuevaImagen].
  ///
  /// Lee el documento actual del servidor para validar que exista y que el
  /// usuario sea su autor (ver [validarEdicion]); las reglas de Firestore
  /// repiten esa validación del lado del servidor. Si no hay cambios reales
  /// no escribe nada y devuelve la publicación tal cual; si los hay, marca
  /// `editado = true` y registra `fechaEdicion`.
  ///
  /// La foto anterior no se borra de Cloudinary (borrar exige la API secret,
  /// que no puede vivir en la app): solo deja de referenciarse.
  Future<Publicacion> editarPublicacion({
    required String publicacionId,
    String? descripcion,
    ArchivoLocal? nuevaImagen,
  }) async {
    final DocumentReference<Map<String, dynamic>> documento =
        _firestore.collection('publicaciones').doc(publicacionId);

    final EdicionPublicacion edicion;
    try {
      final DocumentSnapshot<Map<String, dynamic>> snapshot =
          await documento.get();
      edicion = validarEdicion(
        actual: snapshot.exists ? Publicacion.fromFirestore(snapshot) : null,
        uidUsuario: _auth.currentUser?.uid,
        descripcion: descripcion,
        nuevaImagen: nuevaImagen,
      );
    } on FirebaseException catch (error) {
      throw PublicacionServiceException(
        _mensajeParaErrorDeFirestore(error.code),
        code: error.code,
      );
    }

    if (!edicion.hayCambios) {
      return edicion.actual;
    }

    final CloudinarySubida? subida =
        nuevaImagen == null ? null : await subirImagen(nuevaImagen);
    final Timestamp fechaEdicion = Timestamp.now();

    try {
      await documento.update(<String, dynamic>{
        if (edicion.cambiaDescripcion) 'descripcion': edicion.descripcion,
        if (subida != null) 'imagenUrl': subida.secureUrl,
        if (subida != null) 'imagenPublicId': subida.publicId,
        'editado': true,
        'fechaEdicion': fechaEdicion,
      });
    } on FirebaseException catch (error) {
      throw PublicacionServiceException(
        _mensajeParaErrorDeFirestore(error.code),
        code: error.code,
      );
    }

    return edicion.actual.copyWith(
      imagenUrl: subida?.secureUrl,
      imagenPublicId: subida?.publicId,
      descripcion: () => edicion.descripcion,
      editado: true,
      fechaEdicion: fechaEdicion.toDate(),
    );
  }

  /// Elimina permanentemente la publicación [publicacionId] del usuario
  /// autenticado.
  ///
  /// Lee el documento actual del servidor para validar que exista y que el
  /// usuario sea su autor (ver [validarAutoria]); las reglas de Firestore
  /// repiten esa validación del lado del servidor. Si algo falla lanza
  /// [PublicacionServiceException] y el documento queda intacto.
  ///
  /// Igual que al editar, la foto no se borra de Cloudinary (borrar exige la
  /// API secret, que no puede vivir en la app): solo deja de referenciarse.
  Future<void> eliminarPublicacion(String publicacionId) async {
    final DocumentReference<Map<String, dynamic>> documento =
        _firestore.collection('publicaciones').doc(publicacionId);

    try {
      final DocumentSnapshot<Map<String, dynamic>> snapshot =
          await documento.get();
      validarAutoria(
        actual: snapshot.exists ? Publicacion.fromFirestore(snapshot) : null,
        uidUsuario: _auth.currentUser?.uid,
        accion: 'eliminar',
      );
      await documento.delete();
    } on FirebaseException catch (error) {
      throw PublicacionServiceException(
        _mensajeParaErrorDeFirestore(error.code),
        code: error.code,
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
      case 'not-found':
        return 'La publicación ya no existe.';
      case 'failed-precondition':
        return 'No se pudieron cargar las publicaciones. Inténtalo de nuevo en unos minutos.';
      default:
        return 'Ocurrió un error inesperado. Inténtalo de nuevo.';
    }
  }

  static bool _formatoImagenValido(Uint8List bytes, String extension) {
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
