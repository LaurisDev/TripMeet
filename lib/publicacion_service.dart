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

/// Máximo de fotos en una publicación (carrusel).
const int maximoFotosPublicacion = 10;

/// Una foto de una publicación, ya subida a Cloudinary.
class ImagenPublicacion {
  const ImagenPublicacion({required this.url, required this.publicId});

  final String url;
  final String publicId;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'url': url,
    'publicId': publicId,
  };

  /// Lee una foto de la lista `imagenes`; `null` si el dato no es válido.
  static ImagenPublicacion? desdeMapa(dynamic datos) {
    if (datos is! Map) return null;
    final dynamic url = datos['url'];
    if (url is! String || url.isEmpty) return null;
    final dynamic publicId = datos['publicId'];
    return ImagenPublicacion(
      url: url,
      publicId: publicId is String ? publicId : '',
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ImagenPublicacion &&
      other.url == url &&
      other.publicId == publicId;

  @override
  int get hashCode => Object.hash(url, publicId);
}

/// Una foto en el formulario de una publicación: una que ya estaba publicada
/// ([FotoPublicada]) o una recién elegida del dispositivo ([FotoNueva]).
sealed class FotoEdicion {
  const FotoEdicion();
}

class FotoPublicada extends FotoEdicion {
  const FotoPublicada(this.imagen);

  final ImagenPublicacion imagen;
}

class FotoNueva extends FotoEdicion {
  const FotoNueva(this.archivo);

  final ArchivoLocal archivo;
}

/// Publicación de un turista: una o varias fotos (carrusel) con descripción
/// y ubicación opcionales.
///
/// [imagenUrl] e [imagenPublicId] son la primera foto (la portada, que se
/// muestra en la grilla del perfil); [masImagenes], las demás.
class Publicacion {
  const Publicacion({
    required this.id,
    required this.uid,
    required this.imagenUrl,
    required this.imagenPublicId,
    required this.fechaCreacion,
    this.masImagenes = const <ImagenPublicacion>[],
    this.descripcion,
    this.ubicacion,
    this.editado = false,
    this.fechaEdicion,
  });

  final String id;
  final String uid;
  final String imagenUrl;
  final String imagenPublicId;

  /// Fotos del carrusel después de la portada.
  final List<ImagenPublicacion> masImagenes;

  /// Todas las fotos, empezando por la portada.
  List<ImagenPublicacion> get imagenes => <ImagenPublicacion>[
    ImagenPublicacion(url: imagenUrl, publicId: imagenPublicId),
    ...masImagenes,
  ];

  final String? descripcion;

  /// Dónde se tomaron las fotos o dónde estuvo el autor (por ejemplo,
  /// "Guatapé, Antioquia"); `null` si no la indicó.
  final String? ubicacion;
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
    // Las publicaciones de antes del carrusel solo tienen `imagenUrl`.
    final dynamic lista = datos['imagenes'];
    final List<ImagenPublicacion> imagenes = <ImagenPublicacion>[
      if (lista is List)
        for (final dynamic item in lista)
          if (ImagenPublicacion.desdeMapa(item) case final ImagenPublicacion i)
            i,
    ];

    return Publicacion(
      id: documento.id,
      uid: datos['uid'] as String? ?? '',
      imagenUrl: imagenes.isNotEmpty
          ? imagenes.first.url
          : datos['imagenUrl'] as String? ?? '',
      imagenPublicId: imagenes.isNotEmpty
          ? imagenes.first.publicId
          : datos['imagenPublicId'] as String? ?? '',
      masImagenes: imagenes.skip(1).toList(),
      descripcion: (descripcion == null || descripcion.trim().isEmpty)
          ? null
          : descripcion,
      ubicacion: PublicacionService.normalizarUbicacion(
        datos['ubicacion'] as String?,
      ),
      fechaCreacion:
          (datos['fechaCreacion'] as Timestamp?)?.toDate() ?? DateTime.now(),
      // Las publicaciones creadas antes de existir estos campos no los
      // tienen: se leen como "no editada".
      editado: datos['editado'] as bool? ?? false,
      fechaEdicion: (datos['fechaEdicion'] as Timestamp?)?.toDate(),
    );
  }

  /// Copia con los campos editables reemplazados. [descripcion] y
  /// [ubicacion] son funciones para poder distinguir "no cambiar" de "dejar
  /// en `null`".
  /// [imagenes], si se pasa, no puede estar vacía.
  Publicacion copyWith({
    List<ImagenPublicacion>? imagenes,
    String? Function()? descripcion,
    String? Function()? ubicacion,
    bool? editado,
    DateTime? fechaEdicion,
  }) {
    return Publicacion(
      id: id,
      uid: uid,
      imagenUrl: imagenes?.first.url ?? imagenUrl,
      imagenPublicId: imagenes?.first.publicId ?? imagenPublicId,
      masImagenes: imagenes?.skip(1).toList() ?? masImagenes,
      descripcion: descripcion != null ? descripcion() : this.descripcion,
      ubicacion: ubicacion != null ? ubicacion() : this.ubicacion,
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
    this.cambiaUbicacion = false,
    this.ubicacion,
    this.cambiaImagenes = false,
    this.imagenes,
  });

  final Publicacion actual;
  final bool cambiaDescripcion;

  /// Descripción normalizada (sin espacios sobrantes; `null` si quedó vacía).
  final String? descripcion;
  final bool cambiaUbicacion;

  /// Ubicación normalizada (sin espacios sobrantes; `null` si quedó vacía).
  final String? ubicacion;

  /// `true` si se agregaron, quitaron o reordenaron fotos.
  final bool cambiaImagenes;

  /// Fotos finales del carrusel, en orden; `null` si no cambian.
  final List<FotoEdicion>? imagenes;

  bool get hayCambios => cambiaDescripcion || cambiaUbicacion || cambiaImagenes;
}

/// Autor de una publicación tal como se muestra en el feed, calculado desde
/// su perfil `usuarios/{uid}` (el proyecto no guarda nombre de usuario).
class AutorPublicacion {
  const AutorPublicacion({required this.uid, required this.alias, this.rol});

  final String uid;

  /// Parte del correo antes de la "@" (por ejemplo, `julia` para
  /// `julia@gmail.com`); "Usuario" si el perfil no tiene correo.
  final String alias;

  /// "Turista" o "Guía turístico"; `null` si el perfil no tiene un rol
  /// conocido.
  final String? rol;

  /// Construye el autor a partir del perfil; [perfil] es `null` si no existe
  /// o no se pudo leer.
  factory AutorPublicacion.desdePerfil(
    String uid,
    Map<String, dynamic>? perfil,
  ) {
    final dynamic rol = perfil?['rol'];
    final String? rolLimpio = rol is String ? rol.trim() : null;
    return AutorPublicacion(
      uid: uid,
      alias: aliasDesdeCorreo(perfil?['correo']),
      rol: rolesConocidos.contains(rolLimpio) ? rolLimpio : null,
    );
  }

  /// Roles que se muestran junto al autor (ver `registro_screen.dart`).
  static const List<String> rolesConocidos = <String>[
    'Turista',
    'Guía turístico',
  ];

  /// Devuelve la parte de [correo] antes de la "@", o "Usuario" si no hay un
  /// correo válido.
  static String aliasDesdeCorreo(dynamic correo) {
    if (correo is! String) return 'Usuario';
    final String local = correo.trim().split('@').first.trim();
    return local.isEmpty ? 'Usuario' : local;
  }
}

/// Una publicación del feed con los datos que se muestran junto a ella: su
/// autor, cuántos "me gusta" tiene y si el usuario actual le dio "me gusta".
class PublicacionEnFeed {
  const PublicacionEnFeed({
    required this.publicacion,
    required this.autor,
    required this.totalMeGusta,
    required this.meGusta,
  });

  final Publicacion publicacion;
  final AutorPublicacion autor;
  final int totalMeGusta;

  /// `true` si el usuario autenticado le dio "me gusta".
  final bool meGusta;

  PublicacionEnFeed copyWith({
    Publicacion? publicacion,
    int? totalMeGusta,
    bool? meGusta,
  }) {
    return PublicacionEnFeed(
      publicacion: publicacion ?? this.publicacion,
      autor: autor,
      totalMeGusta: totalMeGusta ?? this.totalMeGusta,
      meGusta: meGusta ?? this.meGusta,
    );
  }
}

/// Una página del feed. [cursor] se pasa a
/// [PublicacionService.obtenerFeed] para pedir la siguiente; [hayMas] es
/// `false` cuando ya no quedan publicaciones más antiguas.
class PaginaFeed {
  const PaginaFeed({
    required this.publicaciones,
    required this.cursor,
    required this.hayMas,
  });

  final List<PublicacionEnFeed> publicaciones;
  final DocumentSnapshot<Map<String, dynamic>>? cursor;
  final bool hayMas;
}

/// Excepción de dominio con un mensaje seguro para mostrar en la interfaz.
class PublicacionServiceException implements Exception {
  const PublicacionServiceException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

/// Gestiona la creación, consulta (propias y feed), edición, eliminación y
/// "me gusta" de las publicaciones del
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

  /// Largo máximo de la ubicación de una publicación.
  static const int largoMaximoUbicacion = 100;

  /// Quita espacios sobrantes (también los repetidos entre palabras) y
  /// convierte una ubicación vacía en `null`.
  static String? normalizarUbicacion(String? ubicacion) {
    final String? limpia = ubicacion?.trim().replaceAll(RegExp(r'\s+'), ' ');
    return (limpia == null || limpia.isEmpty) ? null : limpia;
  }

  static const Map<String, String> _sinTilde = <String, String>{
    'á': 'a',
    'à': 'a',
    'ä': 'a',
    'â': 'a',
    'ã': 'a',
    'é': 'e',
    'è': 'e',
    'ë': 'e',
    'ê': 'e',
    'í': 'i',
    'ì': 'i',
    'ï': 'i',
    'î': 'i',
    'ó': 'o',
    'ò': 'o',
    'ö': 'o',
    'ô': 'o',
    'õ': 'o',
    'ú': 'u',
    'ù': 'u',
    'ü': 'u',
    'û': 'u',
    'ñ': 'n',
    'ç': 'c',
  };

  /// Palabras de [texto] para buscar: en minúsculas, sin tildes y sin
  /// signos de puntuación. "Guatapé, Antioquia" → `[guatape, antioquia]`.
  static List<String> palabrasDeBusqueda(String? texto) {
    if (texto == null) return const <String>[];
    final String sinTildes = texto
        .toLowerCase()
        .split('')
        .map((String c) => _sinTilde[c] ?? c)
        .join();
    return sinTildes
        .split(RegExp(r'[^a-z0-9]+'))
        .where((String palabra) => palabra.isNotEmpty)
        .toList();
  }

  /// Términos que se guardan en `ubicacionTerminos` para poder buscar por
  /// ubicación con `array-contains`: todos los prefijos de cada palabra, para
  /// que "mede" encuentre "Medellín".
  static List<String> terminosDeUbicacion(String? ubicacion) {
    final Set<String> terminos = <String>{};
    for (final String palabra in palabrasDeBusqueda(ubicacion)) {
      for (int largo = 1; largo <= palabra.length; largo++) {
        terminos.add(palabra.substring(0, largo));
      }
    }
    return terminos.toList();
  }

  /// `true` si [ubicacion] coincide con la búsqueda [filtro]: cada palabra
  /// del filtro debe ser el inicio de alguna palabra de la ubicación, sin
  /// importar tildes ni mayúsculas.
  static bool coincideUbicacion(String? ubicacion, String filtro) {
    final List<String> palabras = palabrasDeBusqueda(ubicacion);
    return palabrasDeBusqueda(filtro).every(
      (String buscada) =>
          palabras.any((String palabra) => palabra.startsWith(buscada)),
    );
  }

  static String? _validarUbicacion(String? ubicacion) {
    if (ubicacion != null && ubicacion.length > largoMaximoUbicacion) {
      return 'La ubicación no puede tener más de '
          '$largoMaximoUbicacion caracteres.';
    }
    return null;
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

  /// Mensaje de error si [cantidad] fotos no es válido para una publicación
  /// (al menos una y como máximo [maximoFotosPublicacion]); `null` si sí.
  static String? validarCantidadFotos(int cantidad) {
    if (cantidad < 1) return 'Agrega al menos una foto.';
    if (cantidad > maximoFotosPublicacion) {
      return 'Puedes subir hasta $maximoFotosPublicacion fotos por '
          'publicación.';
    }
    return null;
  }

  /// Reglas de negocio de la edición, sin tocar Firestore ni Cloudinary:
  ///
  /// - El usuario debe ser el autor (ver [validarAutoria]).
  /// - [imagenes] (`null` = no tocar las fotos) debe tener entre 1 y
  ///   [maximoFotosPublicacion] fotos, y las nuevas deben cumplir las mismas
  ///   reglas que al crear.
  ///
  /// Devuelve qué cambia realmente respecto al contenido original; si nada
  /// cambia, [EdicionPublicacion.hayCambios] es `false` y la publicación no
  /// debe marcarse como editada.
  static EdicionPublicacion validarEdicion({
    required Publicacion? actual,
    required String? uidUsuario,
    required String? descripcion,
    String? ubicacion,
    List<FotoEdicion>? imagenes,
  }) {
    final Publicacion verificada = validarAutoria(
      actual: actual,
      uidUsuario: uidUsuario,
      accion: 'editar',
    );

    bool cambiaImagenes = false;
    if (imagenes != null) {
      final String? errorCantidad = validarCantidadFotos(imagenes.length);
      if (errorCantidad != null) {
        throw PublicacionServiceException(
          errorCantidad,
          code: 'cantidad-fotos-invalida',
        );
      }
      for (final FotoEdicion foto in imagenes) {
        if (foto is FotoNueva) {
          final String? errorImagen = validarImagen(foto.archivo);
          if (errorImagen != null) {
            throw PublicacionServiceException(
              errorImagen,
              code: 'imagen-invalida',
            );
          }
        }
      }
      final List<ImagenPublicacion> originales = verificada.imagenes;
      cambiaImagenes =
          imagenes.length != originales.length ||
          <int>[for (int i = 0; i < imagenes.length; i++) i].any((int i) {
            final FotoEdicion foto = imagenes[i];
            return foto is! FotoPublicada || foto.imagen != originales[i];
          });
    }

    final String? nuevaDescripcion = normalizarDescripcion(descripcion);
    // `null` = no tocar la ubicación; texto vacío = quitarla.
    final String? nuevaUbicacion = ubicacion == null
        ? verificada.ubicacion
        : normalizarUbicacion(ubicacion);
    final String? errorUbicacion = _validarUbicacion(nuevaUbicacion);
    if (errorUbicacion != null) {
      throw PublicacionServiceException(
        errorUbicacion,
        code: 'ubicacion-invalida',
      );
    }
    return EdicionPublicacion(
      actual: verificada,
      cambiaDescripcion: nuevaDescripcion != verificada.descripcion,
      descripcion: nuevaDescripcion,
      cambiaUbicacion: nuevaUbicacion != verificada.ubicacion,
      ubicacion: nuevaUbicacion,
      cambiaImagenes: cambiaImagenes,
      imagenes: cambiaImagenes ? imagenes : null,
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

  /// Sube a Cloudinary las fotos nuevas de [fotos], una por una y en orden,
  /// y devuelve todas las fotos ya publicadas. [onProgreso] recibe cuántas
  /// fotos nuevas van subidas y cuántas son en total.
  ///
  /// Valida todas antes de subir la primera, para no dejar fotos sueltas en
  /// Cloudinary si una no sirve.
  Future<List<ImagenPublicacion>> subirImagenes(
    List<FotoEdicion> fotos, {
    void Function(int subidas, int total)? onProgreso,
  }) async {
    final List<ArchivoLocal> nuevas = <ArchivoLocal>[
      for (final FotoEdicion foto in fotos)
        if (foto is FotoNueva) foto.archivo,
    ];
    for (final ArchivoLocal archivo in nuevas) {
      final String? errorImagen = validarImagen(archivo);
      if (errorImagen != null) {
        throw PublicacionServiceException(errorImagen, code: 'imagen-invalida');
      }
    }

    int subidas = 0;
    onProgreso?.call(subidas, nuevas.length);
    final List<ImagenPublicacion> resultado = <ImagenPublicacion>[];
    for (final FotoEdicion foto in fotos) {
      switch (foto) {
        case FotoPublicada(:final ImagenPublicacion imagen):
          resultado.add(imagen);
        case FotoNueva(:final ArchivoLocal archivo):
          final CloudinarySubida subida = await subirImagen(archivo);
          resultado.add(
            ImagenPublicacion(url: subida.secureUrl, publicId: subida.publicId),
          );
          onProgreso?.call(++subidas, nuevas.length);
      }
    }
    return resultado;
  }

  /// Campos de Firestore con las fotos: la lista completa en `imagenes` y la
  /// portada también en `imagenUrl`/`imagenPublicId`, para las pantallas y
  /// publicaciones de antes del carrusel.
  static Map<String, dynamic> _camposImagenes(
    List<ImagenPublicacion> imagenes,
  ) => <String, dynamic>{
    'imagenUrl': imagenes.first.url,
    'imagenPublicId': imagenes.first.publicId,
    'imagenes': <Map<String, dynamic>>[
      for (final ImagenPublicacion imagen in imagenes) imagen.toMap(),
    ],
  };

  /// Crea el documento de la publicación en Firestore, ya con las fotos
  /// subidas a Cloudinary (ver [subirImagenes]); la primera es la portada.
  Future<void> crearPublicacion({
    required List<ImagenPublicacion> imagenes,
    String? descripcion,
    String? ubicacion,
  }) async {
    final User? usuario = _auth.currentUser;
    if (usuario == null) {
      throw const PublicacionServiceException(
        'No hay un usuario autenticado para crear la publicación.',
        code: 'user-not-authenticated',
      );
    }
    final String? errorCantidad = validarCantidadFotos(imagenes.length);
    if (errorCantidad != null) {
      throw PublicacionServiceException(
        errorCantidad,
        code: 'cantidad-fotos-invalida',
      );
    }
    final String? ubicacionLimpia = normalizarUbicacion(ubicacion);
    final String? errorUbicacion = _validarUbicacion(ubicacionLimpia);
    if (errorUbicacion != null) {
      throw PublicacionServiceException(
        errorUbicacion,
        code: 'ubicacion-invalida',
      );
    }

    try {
      final DocumentReference<Map<String, dynamic>> documento = _firestore
          .collection('publicaciones')
          .doc();

      await documento.set(<String, dynamic>{
        'id': documento.id,
        'uid': usuario.uid,
        ..._camposImagenes(imagenes),
        'descripcion': (descripcion == null || descripcion.trim().isEmpty)
            ? null
            : descripcion.trim(),
        'ubicacion': ubicacionLimpia,
        'ubicacionTerminos': terminosDeUbicacion(ubicacionLimpia),
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
  /// descripción, la ubicación ([ubicacion] `null` la deja igual; vacía la
  /// quita) y/o las fotos del carrusel ([imagenes] `null` las deja igual;
  /// si no, es la lista final en orden, con fotos ya publicadas y nuevas).
  ///
  /// Lee el documento actual del servidor para validar que exista y que el
  /// usuario sea su autor (ver [validarEdicion]); las reglas de Firestore
  /// repiten esa validación del lado del servidor. Si no hay cambios reales
  /// no escribe nada y devuelve la publicación tal cual; si los hay, marca
  /// `editado = true` y registra `fechaEdicion`.
  ///
  /// Las fotos quitadas no se borran de Cloudinary (borrar exige la API
  /// secret, que no puede vivir en la app): solo dejan de referenciarse.
  Future<Publicacion> editarPublicacion({
    required String publicacionId,
    String? descripcion,
    String? ubicacion,
    List<FotoEdicion>? imagenes,
    void Function(int subidas, int total)? onProgreso,
  }) async {
    final DocumentReference<Map<String, dynamic>> documento = _firestore
        .collection('publicaciones')
        .doc(publicacionId);

    final EdicionPublicacion edicion;
    try {
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await documento
          .get();
      edicion = validarEdicion(
        actual: snapshot.exists ? Publicacion.fromFirestore(snapshot) : null,
        uidUsuario: _auth.currentUser?.uid,
        descripcion: descripcion,
        ubicacion: ubicacion,
        imagenes: imagenes,
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

    final List<FotoEdicion>? fotos = edicion.imagenes;
    final List<ImagenPublicacion>? subidas = fotos == null
        ? null
        : await subirImagenes(fotos, onProgreso: onProgreso);
    final Timestamp fechaEdicion = Timestamp.now();

    try {
      await documento.update(<String, dynamic>{
        if (edicion.cambiaDescripcion) 'descripcion': edicion.descripcion,
        if (edicion.cambiaUbicacion) 'ubicacion': edicion.ubicacion,
        if (edicion.cambiaUbicacion)
          'ubicacionTerminos': terminosDeUbicacion(edicion.ubicacion),
        if (subidas != null) ..._camposImagenes(subidas),
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
      imagenes: subidas,
      descripcion: () => edicion.descripcion,
      ubicacion: () => edicion.ubicacion,
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
    final DocumentReference<Map<String, dynamic>> documento = _firestore
        .collection('publicaciones')
        .doc(publicacionId);

    try {
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await documento
          .get();
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

  /// Cantidad de publicaciones por página del feed.
  static const int tamanoPaginaFeed = 10;

  /// Máximo de publicaciones que trae una búsqueda por ubicación.
  static const int limiteBusquedaUbicacion = 100;

  /// Consulta el feed: publicaciones de todos los usuarios (incluidas las
  /// propias), de la más reciente a la más antigua, de [limite] en [limite].
  /// Para la página siguiente se pasa el [PaginaFeed.cursor] de la anterior.
  ///
  /// Cada publicación trae su autor (alias del correo y rol, leídos una sola
  /// vez por autor), el total de "me gusta" y si el usuario actual le dio
  /// "me gusta". Si el perfil de un autor no se puede leer, se muestra como
  /// "Usuario" sin rol; si no se pueden contar los "me gusta", se muestran
  /// en 0. Solo falla si no se pueden leer las publicaciones.
  ///
  /// Con [ubicacion] solo trae las publicaciones de esa ubicación (ver
  /// [coincideUbicacion]), hasta [limiteBusquedaUbicacion], en una sola
  /// página.
  Future<PaginaFeed> obtenerFeed({
    DocumentSnapshot<Map<String, dynamic>>? despuesDe,
    int limite = tamanoPaginaFeed,
    String? ubicacion,
  }) async {
    final List<String> palabrasFiltro = palabrasDeBusqueda(ubicacion);
    if (palabrasFiltro.isNotEmpty) {
      return _buscarPorUbicacion(ubicacion!, palabrasFiltro);
    }

    final QuerySnapshot<Map<String, dynamic>> snapshot;
    try {
      Query<Map<String, dynamic>> consulta = _firestore
          .collection('publicaciones')
          .orderBy('fechaCreacion', descending: true);
      // Primero el cursor y después el límite: es el orden lógico y el que
      // respetan tanto Firestore como su versión simulada de las pruebas.
      if (despuesDe != null) {
        consulta = consulta.startAfterDocument(despuesDe);
      }
      snapshot = await consulta.limit(limite).get();
    } on FirebaseException catch (error) {
      throw PublicacionServiceException(
        _mensajeParaErrorDeFirestore(error.code),
        code: error.code,
      );
    }

    return PaginaFeed(
      publicaciones: await _enFeed(
        snapshot.docs.map(Publicacion.fromFirestore).toList(),
      ),
      cursor: snapshot.docs.isEmpty ? despuesDe : snapshot.docs.last,
      hayMas: snapshot.docs.length == limite,
    );
  }

  /// Busca con `array-contains` la palabra más larga del filtro en
  /// `ubicacionTerminos` y revisa el resto en la app. Se ordena por fecha en
  /// la app para no necesitar un índice compuesto en Firestore.
  Future<PaginaFeed> _buscarPorUbicacion(
    String filtro,
    List<String> palabrasFiltro,
  ) async {
    final String termino = palabrasFiltro.reduce(
      (String a, String b) => b.length > a.length ? b : a,
    );
    final QuerySnapshot<Map<String, dynamic>> snapshot;
    try {
      snapshot = await _firestore
          .collection('publicaciones')
          .where('ubicacionTerminos', arrayContains: termino)
          .limit(limiteBusquedaUbicacion)
          .get();
    } on FirebaseException catch (error) {
      throw PublicacionServiceException(
        _mensajeParaErrorDeFirestore(error.code),
        code: error.code,
      );
    }

    final List<Publicacion> publicaciones =
        snapshot.docs
            .map(Publicacion.fromFirestore)
            .where((Publicacion p) => coincideUbicacion(p.ubicacion, filtro))
            .toList()
          ..sort(
            (Publicacion a, Publicacion b) =>
                b.fechaCreacion.compareTo(a.fechaCreacion),
          );

    return PaginaFeed(
      publicaciones: await _enFeed(publicaciones),
      cursor: null,
      hayMas: false,
    );
  }

  /// Agrega a cada publicación su autor y sus "me gusta".
  Future<List<PublicacionEnFeed>> _enFeed(
    List<Publicacion> publicaciones,
  ) async {
    final String? uidActual = _auth.currentUser?.uid;

    final Map<String, AutorPublicacion> autores = await _autores(
      publicaciones.map((Publicacion p) => p.uid).toSet(),
    );
    return Future.wait(
      publicaciones.map((Publicacion publicacion) async {
        final (int total, bool meGusta) = await _meGustaDe(
          publicacion.id,
          uidActual,
        );
        return PublicacionEnFeed(
          publicacion: publicacion,
          autor:
              autores[publicacion.uid] ??
              AutorPublicacion.desdePerfil(publicacion.uid, null),
          totalMeGusta: total,
          meGusta: meGusta,
        );
      }),
    );
  }

  /// Da o quita el "me gusta" del usuario autenticado en [publicacionId].
  ///
  /// Cada "me gusta" es el documento `publicaciones/{id}/likes/{uid}`: al usar
  /// el uid como id, un usuario no puede dar dos "me gusta" a la misma
  /// publicación, y darlo o quitarlo varias veces no cambia el resultado.
  /// Devuelve el nuevo total de "me gusta".
  Future<int> cambiarMeGusta({
    required String publicacionId,
    required bool meGusta,
  }) async {
    final User? usuario = _auth.currentUser;
    if (usuario == null) {
      throw const PublicacionServiceException(
        'Inicia sesión para dar "me gusta".',
        code: 'user-not-authenticated',
      );
    }

    final DocumentReference<Map<String, dynamic>> publicacion = _firestore
        .collection('publicaciones')
        .doc(publicacionId);
    final DocumentReference<Map<String, dynamic>> like = publicacion
        .collection('likes')
        .doc(usuario.uid);

    try {
      if (meGusta) {
        if (!(await publicacion.get()).exists) {
          throw const PublicacionServiceException(
            'La publicación ya no existe.',
            code: 'not-found',
          );
        }
        await like.set(<String, dynamic>{
          'uid': usuario.uid,
          'fecha': Timestamp.now(),
        });
      } else {
        await like.delete();
      }
      final AggregateQuerySnapshot conteo = await publicacion
          .collection('likes')
          .count()
          .get();
      return conteo.count ?? 0;
    } on FirebaseException catch (error) {
      throw PublicacionServiceException(
        _mensajeParaErrorDeFirestore(error.code),
        code: error.code,
      );
    }
  }

  /// Total de "me gusta" de [publicacionId] y si [uid] le dio "me gusta".
  /// Si no se pueden leer, `(0, false)`: el feed se muestra igual.
  Future<(int, bool)> _meGustaDe(String publicacionId, String? uid) async {
    final CollectionReference<Map<String, dynamic>> likes = _firestore
        .collection('publicaciones')
        .doc(publicacionId)
        .collection('likes');
    try {
      final List<Object?> resultados = await Future.wait(<Future<Object?>>[
        likes.count().get(),
        if (uid != null) likes.doc(uid).get(),
      ]);
      final int total =
          (resultados.first! as AggregateQuerySnapshot).count ?? 0;
      final bool meGusta =
          uid != null &&
          (resultados.last! as DocumentSnapshot<Map<String, dynamic>>).exists;
      return (total, meGusta);
    } on FirebaseException {
      return (0, false);
    }
  }

  /// Lee una sola vez el perfil de cada autor de [uids].
  Future<Map<String, AutorPublicacion>> _autores(Set<String> uids) async {
    final List<AutorPublicacion> autores = await Future.wait(
      uids.map((String uid) async {
        Map<String, dynamic>? perfil;
        if (uid.isNotEmpty) {
          try {
            perfil = (await _firestore.collection('usuarios').doc(uid).get())
                .data();
          } on FirebaseException {
            perfil = null;
          }
        }
        return AutorPublicacion.desdePerfil(uid, perfil);
      }),
    );
    return <String, AutorPublicacion>{
      for (final AutorPublicacion autor in autores) autor.uid: autor,
    };
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

    final bool esJpeg =
        bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF;
    final bool esPng =
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47;
    final bool esWebp =
        bytes[0] == 0x52 &&
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
