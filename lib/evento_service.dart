import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'cloudinary_service.dart';
import 'guia_service.dart' show ArchivoLocal;
import 'publicacion_service.dart' show PublicacionService;

/// Roles con los que se registra un usuario (ver `registro_screen.dart`).
const String rolTurista = 'Turista';
const String rolGuiaTuristico = 'GuÃa turÃstico';

/// Valor de `estadoCertificados` de un guÃa cuyos certificados ya fueron
/// aprobados. `GuiaService` solo escribe `pendiente` y `en_revision`; la
/// aprobaciÃ³n se registra fuera de la app.
const String estadoCertificadosAprobado = 'aprobado';

/// Longitudes mÃ¡ximas de los textos de un evento.
const int longitudMaximaNombreEvento = 100;
const int longitudMaximaLugarEvento = 150;
const int longitudMaximaDescripcionEvento = 1000;

/// Longitud mÃnima del nombre y el lugar (sin espacios sobrantes).
const int longitudMinimaTextoEvento = 3;

/// Carpeta de Cloudinary para las fotos de eventos.
const String carpetaImagenesEventos = 'tripmeet/eventos';

/// Rango permitido para el cupo mÃ¡ximo de personas (opcional).
const int cupoMinimoEvento = 1;
const int cupoMaximoEvento = 1000;

/// Precio mÃ¡ximo de un evento, en pesos colombianos (opcional; 0 = gratis).
const int precioMaximoEvento = 50000000;

/// Certificado aprobado del guÃa que creÃ³ un evento, tal como lo guarda
/// `GuiaService` en `usuarios/{uid}.certificados.carneGuia` (PDF en
/// Cloudinary). Solo se expone el carnÃ© de guÃa turÃstico: los antecedentes
/// judiciales y los certificados adicionales son datos personales que no se
/// muestran a los turistas.
class CertificadoGuia {
  const CertificadoGuia({required this.nombre, required this.url});

  /// Nombre del archivo subido (por ejemplo, `carne.pdf`).
  final String nombre;

  /// `secure_url` del PDF en Cloudinary.
  final String url;

  /// Devuelve el carnÃ© de guÃa de [perfil] solo si el usuario es guÃa
  /// turÃstico, sus certificados estÃ¡n aprobados (`estadoCertificados`) y el
  /// carnÃ© tiene un enlace https vÃ¡lido. En cualquier otro caso, `null`: no
  /// se muestra ninguna certificaciÃ³n.
  static CertificadoGuia? desdePerfil(Map<String, dynamic>? perfil) {
    if (!EventoService.esGuiaAprobado(perfil)) return null;

    final dynamic certificados = perfil!['certificados'];
    if (certificados is! Map) return null;
    final dynamic carne = certificados['carneGuia'];
    if (carne is! Map) return null;

    final dynamic url = carne['url'];
    final Uri? enlace = url is String ? Uri.tryParse(url.trim()) : null;
    if (enlace == null || enlace.scheme != 'https' || enlace.host.isEmpty) {
      return null;
    }

    final dynamic nombre = carne['nombre'];
    return CertificadoGuia(
      nombre: nombre is String && nombre.trim().isNotEmpty
          ? nombre.trim()
          : 'CarnÃ© de guÃa turÃstico',
      url: enlace.toString(),
    );
  }
}

/// Evento turÃstico publicado por un turista o un guÃa, visible para todos
/// en la secciÃ³n "Eventos". Se guarda en la colecciÃ³n `eventos`, separada de las
/// publicaciones y de los lugares.
class Evento {
  const Evento({
    required this.id,
    required this.creadorUid,
    required this.nombre,
    required this.lugar,
    required this.fechaHora,
    required this.fechaCreacion,
    this.descripcion,
    this.imagenUrl,
    this.imagenPublicId,
    this.creadoPorGuia = false,
    this.certificadoGuia,
    this.cupoMaximo,
    this.precio,
  });

  final String id;

  /// UID del usuario que creÃ³ el evento.
  final String creadorUid;
  final String nombre;
  final String lugar;

  /// Fecha y hora en que se realiza el evento.
  final DateTime fechaHora;
  final DateTime fechaCreacion;
  final String? descripcion;

  /// Foto del evento en Cloudinary; `null` si no tiene.
  final String? imagenUrl;
  final String? imagenPublicId;

  /// `true` si el creador tiene el rol de guÃa turÃstico en su perfil
  /// (`usuarios/{creadorUid}`). No se lee del documento del evento: lo
  /// calcula [EventoService] a partir del rol real del creador, para que
  /// nadie pueda darle el diseÃ±o premium escribiendo un campo.
  final bool creadoPorGuia;

  /// CarnÃ© aprobado del guÃa creador; `null` si el creador no es guÃa, si
  /// sus certificados no estÃ¡n aprobados o si no hay un carnÃ© registrado.
  /// Igual que [creadoPorGuia], sale del perfil real del creador.
  final CertificadoGuia? certificadoGuia;

  /// NÃºmero mÃ¡ximo de personas; `null` si el creador no lo indicÃ³.
  final int? cupoMaximo;

  /// Precio por persona en pesos colombianos (0 = gratis); `null` si el
  /// creador no lo indicÃ³.
  final int? precio;

  /// Copia con los datos del creador calculados desde su [perfil]
  /// (`usuarios/{creadorUid}`; `null` si no existe o no se pudo leer).
  Evento conPerfilDelCreador(Map<String, dynamic>? perfil) => Evento(
    id: id,
    creadorUid: creadorUid,
    nombre: nombre,
    lugar: lugar,
    fechaHora: fechaHora,
    fechaCreacion: fechaCreacion,
    descripcion: descripcion,
    imagenUrl: imagenUrl,
    imagenPublicId: imagenPublicId,
    cupoMaximo: cupoMaximo,
    precio: precio,
    creadoPorGuia: EventoService.esGuia(perfil),
    certificadoGuia: CertificadoGuia.desdePerfil(perfil),
  );

  factory Evento.fromFirestore(DocumentSnapshot<Map<String, dynamic>> documento) {
    final Map<String, dynamic> datos = documento.data() ?? <String, dynamic>{};

    return Evento(
      id: documento.id,
      creadorUid: datos['creadorUid'] as String? ?? '',
      nombre: datos['nombre'] as String? ?? '',
      lugar: datos['lugar'] as String? ?? '',
      fechaHora:
          (datos['fechaHora'] as Timestamp?)?.toDate() ?? DateTime.now(),
      fechaCreacion:
          (datos['fechaCreacion'] as Timestamp?)?.toDate() ?? DateTime.now(),
      descripcion: _textoOpcional(datos['descripcion']),
      imagenUrl: _textoOpcional(datos['imagenUrl']),
      imagenPublicId: _textoOpcional(datos['imagenPublicId']),
      cupoMaximo: _enteroEnRango(
        datos['cupoMaximo'],
        minimo: cupoMinimoEvento,
        maximo: cupoMaximoEvento,
      ),
      precio: _enteroEnRango(
        datos['precio'],
        minimo: 0,
        maximo: precioMaximoEvento,
      ),
    );
  }

  /// Lee un entero guardado; si falta o estÃ¡ fuera de rango, `null` (no se
  /// muestra un cupo o precio invÃ¡lido).
  static int? _enteroEnRango(
    dynamic valor, {
    required int minimo,
    required int maximo,
  }) {
    if (valor is! num || valor != valor.roundToDouble()) return null;
    final int entero = valor.toInt();
    return (entero < minimo || entero > maximo) ? null : entero;
  }

  static String? _textoOpcional(dynamic valor) {
    if (valor is! String || valor.trim().isEmpty) return null;
    return valor;
  }
}

/// ExcepciÃ³n de dominio con un mensaje seguro para mostrar en la interfaz.
class EventoServiceException implements Exception {
  const EventoServiceException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

/// Crea y consulta los eventos turÃsticos: sube la foto a Cloudinary (mismo
/// preset que publicaciones y certificados, carpeta `tripmeet/eventos`) y
/// guarda el documento en la colecciÃ³n `eventos` de Firestore.
class EventoService {
  EventoService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    CloudinaryService? cloudinary,
    DateTime Function()? reloj,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _cloudinary = cloudinary ?? CloudinaryService(),
       _reloj = reloj ?? DateTime.now;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final CloudinaryService _cloudinary;

  /// Hora actual (inyectable en pruebas).
  final DateTime Function() _reloj;

  /// Valida el nombre del evento: obligatorio, entre
  /// [longitudMinimaTextoEvento] y [longitudMaximaNombreEvento] caracteres.
  /// Devuelve el mensaje de error o `null` si es vÃ¡lido.
  static String? validarNombre(String? nombre) => _validarTextoObligatorio(
    nombre,
    campo: 'el nombre del evento',
    maximo: longitudMaximaNombreEvento,
  );

  /// Valida el lugar del evento, con las mismas reglas que el nombre pero
  /// hasta [longitudMaximaLugarEvento] caracteres.
  static String? validarLugar(String? lugar) => _validarTextoObligatorio(
    lugar,
    campo: 'el lugar del evento',
    maximo: longitudMaximaLugarEvento,
  );

  /// Valida la fecha y hora: obligatoria y posterior a [ahora].
  static String? validarFechaHora(
    DateTime? fechaHora, {
    required DateTime ahora,
  }) {
    if (fechaHora == null) {
      return 'Selecciona la fecha y la hora del evento.';
    }
    if (!fechaHora.isAfter(ahora)) {
      return 'La fecha y hora del evento deben ser posteriores a la actual.';
    }
    return null;
  }

  /// Convierte el texto de un campo numÃ©rico opcional en entero: `null` si
  /// estÃ¡ vacÃo. Lanza [FormatException] si no es un entero (por ejemplo,
  /// "abc" o "2,5"). Acepta puntos y espacios como separadores de miles.
  static int? leerEnteroOpcional(String? texto) {
    final String limpio = (texto ?? '').replaceAll(RegExp(r'[\s.]'), '');
    if (limpio.isEmpty) return null;
    final int? valor = int.tryParse(limpio);
    if (valor == null) throw FormatException('No es un entero', texto);
    return valor;
  }

  /// Valida el cupo mÃ¡ximo: opcional, entero entre [cupoMinimoEvento] y
  /// [cupoMaximoEvento].
  static String? validarCupoMaximo(int? cupo) {
    if (cupo == null) return null;
    if (cupo < cupoMinimoEvento || cupo > cupoMaximoEvento) {
      return 'El cupo debe estar entre $cupoMinimoEvento y $cupoMaximoEvento '
          'personas.';
    }
    return null;
  }

  /// Valida el precio: opcional, entero entre 0 (gratis) y
  /// [precioMaximoEvento] pesos.
  static String? validarPrecio(int? precio) {
    if (precio == null) return null;
    if (precio < 0) return 'El precio no puede ser negativo.';
    if (precio > precioMaximoEvento) {
      return 'El precio no puede superar \$50.000.000 COP.';
    }
    return null;
  }

  /// Validador de formulario para un campo numÃ©rico opcional: revisa que el
  /// texto sea un entero y luego aplica [reglas].
  static String? validarCampoEntero(
    String? texto,
    String? Function(int?) reglas,
  ) {
    try {
      return reglas(leerEnteroOpcional(texto));
    } on FormatException {
      return 'Ingresa solo nÃºmeros enteros.';
    }
  }

  /// Valida la descripciÃ³n: opcional, hasta
  /// [longitudMaximaDescripcionEvento] caracteres.
  static String? validarDescripcion(String? descripcion) {
    if ((descripcion?.trim().length ?? 0) > longitudMaximaDescripcionEvento) {
      return 'La descripciÃ³n no puede superar '
          '$longitudMaximaDescripcionEvento caracteres.';
    }
    return null;
  }

  static String? _validarTextoObligatorio(
    String? valor, {
    required String campo,
    required int maximo,
  }) {
    final String limpio = valor?.trim() ?? '';
    if (limpio.isEmpty) {
      return 'Ingresa $campo.';
    }
    if (limpio.length < longitudMinimaTextoEvento) {
      return 'Escribe al menos $longitudMinimaTextoEvento caracteres para '
          '$campo.';
    }
    if (limpio.length > maximo) {
      return 'No puedes superar $maximo caracteres en $campo.';
    }
    return null;
  }

  /// Regla de negocio: cualquier usuario registrado como turista o como guÃa
  /// turÃstico puede crear eventos. [perfil] es el documento
  /// `usuarios/{uid}`; `null` si no existe (sin perfil no se puede crear).
  static bool puedeCrear(Map<String, dynamic>? perfil) {
    if (perfil == null) return false;
    final dynamic rol = perfil['rol'];
    return rol is String &&
        (rol.trim() == rolTurista || rol.trim() == rolGuiaTuristico);
  }

  /// Indica si [perfil] es de un guÃa turÃstico con los certificados
  /// aprobados. Es lo que permite mostrar su carnÃ© en sus eventos.
  static bool esGuiaAprobado(Map<String, dynamic>? perfil) =>
      esGuia(perfil) &&
      perfil!['estadoCertificados'] == estadoCertificadosAprobado;

  /// Indica si [perfil] (documento `usuarios/{uid}`) tiene el rol de guÃa
  /// turÃstico, sin importar el estado de sus certificados. Es lo que
  /// decide el diseÃ±o premium de sus eventos.
  static bool esGuia(Map<String, dynamic>? perfil) {
    if (perfil == null) return false;
    final dynamic rol = perfil['rol'];
    return rol is String && rol.trim() == rolGuiaTuristico;
  }

  /// Indica si el usuario autenticado puede crear eventos (ver
  /// [puedeCrear]). Sin sesiÃ³n iniciada devuelve `false`.
  Future<bool> puedeCrearEventos() async {
    final User? usuario = _auth.currentUser;
    if (usuario == null) return false;
    return puedeCrear(await _leerPerfil(usuario.uid));
  }

  /// Lee el perfil `usuarios/{uid}`; `null` si no existe.
  Future<Map<String, dynamic>?> _leerPerfil(String uid) async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> perfil =
          await _firestore.collection('usuarios').doc(uid).get();
      return perfil.data();
    } on FirebaseException catch (error) {
      throw EventoServiceException(
        _mensajeParaErrorDeFirestore(error.code),
        code: error.code,
      );
    }
  }

  /// Crea un evento a nombre del usuario autenticado y lo devuelve ya
  /// guardado.
  ///
  /// Repite todas las validaciones del formulario y comprueba en Firestore
  /// que el usuario tenga un rol que permita crear (ver [puedeCrear]) antes
  /// de subir nada. Si es guÃa, el evento sale con el diseÃ±o premium. La imagen es opcional; si se envÃa, debe cumplir las mismas
  /// reglas que la de una publicaciÃ³n. Lanza [EventoServiceException] con un
  /// mensaje listo para la interfaz si algo falla.
  Future<Evento> crearEvento({
    required String nombre,
    required String lugar,
    required DateTime? fechaHora,
    String? descripcion,
    ArchivoLocal? imagen,
    int? cupoMaximo,
    int? precio,
  }) async {
    final String? errorDatos =
        validarNombre(nombre) ??
        validarLugar(lugar) ??
        validarFechaHora(fechaHora, ahora: _reloj()) ??
        validarDescripcion(descripcion) ??
        validarCupoMaximo(cupoMaximo) ??
        validarPrecio(precio) ??
        (imagen == null ? null : PublicacionService.validarImagen(imagen));
    if (errorDatos != null) {
      throw EventoServiceException(errorDatos, code: 'datos-invalidos');
    }

    final User? usuario = _auth.currentUser;
    if (usuario == null) {
      throw const EventoServiceException(
        'No hay un usuario autenticado para crear el evento.',
        code: 'user-not-authenticated',
      );
    }
    final Map<String, dynamic>? perfil = await _leerPerfil(usuario.uid);
    if (!puedeCrear(perfil)) {
      throw const EventoServiceException(
        'Tu cuenta no tiene un rol que permita crear eventos.',
        code: 'permission-denied',
      );
    }

    CloudinarySubida? subida;
    if (imagen != null) {
      try {
        subida = await _cloudinary.subirImagen(
          bytes: imagen.bytes,
          nombreArchivo: imagen.nombre,
          folder: carpetaImagenesEventos,
        );
      } on CloudinaryException catch (error) {
        throw EventoServiceException(error.message, code: error.code);
      }
    }

    final String? descripcionLimpia = descripcion?.trim();
    final DocumentReference<Map<String, dynamic>> documento =
        _firestore.collection('eventos').doc();
    final Evento evento = Evento(
      id: documento.id,
      creadorUid: usuario.uid,
      nombre: nombre.trim(),
      lugar: lugar.trim(),
      fechaHora: fechaHora!,
      fechaCreacion: _reloj(),
      descripcion: (descripcionLimpia == null || descripcionLimpia.isEmpty)
          ? null
          : descripcionLimpia,
      imagenUrl: subida?.secureUrl,
      imagenPublicId: subida?.publicId,
      cupoMaximo: cupoMaximo,
      precio: precio,
    ).conPerfilDelCreador(perfil);

    try {
      await documento.set(<String, dynamic>{
        'id': evento.id,
        'creadorUid': evento.creadorUid,
        'nombre': evento.nombre,
        'lugar': evento.lugar,
        'fechaHora': Timestamp.fromDate(evento.fechaHora),
        'descripcion': evento.descripcion,
        'imagenUrl': evento.imagenUrl,
        'imagenPublicId': evento.imagenPublicId,
        'cupoMaximo': evento.cupoMaximo,
        'precio': evento.precio,
        'fechaCreacion': Timestamp.fromDate(evento.fechaCreacion),
      });
    } on FirebaseException catch (error) {
      throw EventoServiceException(
        _mensajeParaErrorDeFirestore(error.code, creando: true),
        code: error.code,
      );
    }
    return evento;
  }


  /// Edita un evento existente. Solo puede hacerlo el usuario que lo creó.
  Future<Evento> editarEvento({
    required String eventoId,
    required String nombre,
    required String lugar,
    required DateTime? fechaHora,
    String? descripcion,
    int? cupoMaximo,
    int? precio,
  }) async {
    final String? errorDatos =
        validarNombre(nombre) ??
        validarLugar(lugar) ??
        validarFechaHora(fechaHora, ahora: _reloj()) ??
        validarDescripcion(descripcion) ??
        validarCupoMaximo(cupoMaximo) ??
        validarPrecio(precio);

    if (errorDatos != null) {
      throw EventoServiceException(errorDatos, code: 'datos-invalidos');
    }

    final User? usuario = _auth.currentUser;

    if (usuario == null) {
      throw const EventoServiceException(
        'No hay un usuario autenticado para editar el evento.',
        code: 'user-not-authenticated',
      );
    }

    try {
      final DocumentReference<Map<String, dynamic>> documento =
          _firestore.collection('eventos').doc(eventoId);

      final DocumentSnapshot<Map<String, dynamic>> snapshot =
          await documento.get();

      if (!snapshot.exists) {
        throw const EventoServiceException(
          'El evento que intentas editar no existe.',
          code: 'not-found',
        );
      }

      final Evento eventoActual = Evento.fromFirestore(snapshot);

      if (eventoActual.creadorUid != usuario.uid) {
        throw const EventoServiceException(
          'Solo puedes editar los eventos que tú has creado.',
          code: 'permission-denied',
        );
      }

      final String? descripcionLimpia = descripcion?.trim();

      await documento.update(<String, dynamic>{
        'nombre': nombre.trim(),
        'lugar': lugar.trim(),
        'fechaHora': Timestamp.fromDate(fechaHora!),
        'descripcion':
            (descripcionLimpia == null || descripcionLimpia.isEmpty)
                ? null
                : descripcionLimpia,
        'cupoMaximo': cupoMaximo,
        'precio': precio,
      });

      final DocumentSnapshot<Map<String, dynamic>> actualizado =
          await documento.get();

      return Evento.fromFirestore(actualizado);
    } on EventoServiceException {
      rethrow;
    } on FirebaseException catch (error) {
      throw EventoServiceException(
        _mensajeParaErrorDeFirestore(error.code),
        code: error.code,
      );
    }
  }

  /// Consulta los eventos disponibles: los que aÃºn no han ocurrido
  /// (`fechaHora` a partir de [desde], por defecto ahora), del mÃ¡s prÃ³ximo
  /// al mÃ¡s lejano. Cada evento indica si su creador es guÃa turÃstico y,
  /// si estÃ¡ aprobado, trae su carnÃ© (ver [Evento.conPerfilDelCreador]).
  Future<List<Evento>> obtenerEventosDisponibles({DateTime? desde}) async {
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('eventos')
          .where(
            'fechaHora',
            isGreaterThanOrEqualTo: Timestamp.fromDate(desde ?? _reloj()),
          )
          .orderBy('fechaHora')
          .get();

      final List<Evento> eventos =
          snapshot.docs.map(Evento.fromFirestore).toList();
      final Map<String, Map<String, dynamic>?> perfiles =
          await _perfilesDeCreadores(
            eventos.map((Evento e) => e.creadorUid).toSet(),
          );
      return <Evento>[
        for (final Evento evento in eventos)
          evento.conPerfilDelCreador(perfiles[evento.creadorUid]),
      ];
    } on FirebaseException catch (error) {
      throw EventoServiceException(
        _mensajeParaErrorDeFirestore(error.code),
        code: error.code,
      );
    }
  }

  /// Lee una sola vez el perfil de cada creador de [uids]. Si un perfil no
  /// existe o no se puede leer, queda en `null`: el evento se muestra igual,
  /// solo que sin diseÃ±o premium ni certificado.
  Future<Map<String, Map<String, dynamic>?>> _perfilesDeCreadores(
    Set<String> uids,
  ) async {
    final List<String> validos =
        uids.where((String uid) => uid.isNotEmpty).toList();
    final List<Map<String, dynamic>?> perfiles = await Future.wait(
      validos.map((String uid) async {
        try {
          return await _leerPerfil(uid);
        } on EventoServiceException {
          return null;
        }
      }),
    );
    return <String, Map<String, dynamic>?>{
      for (int i = 0; i < validos.length; i++) validos[i]: perfiles[i],
    };
  }

  String _mensajeParaErrorDeFirestore(String codigo, {bool creando = false}) {
    switch (codigo) {
      case 'unavailable':
      case 'network-request-failed':
        return 'No se pudo completar la operaciÃ³n por un problema de conexiÃ³n.';
      case 'permission-denied':
        return 'No tienes permiso para realizar esta acciÃ³n.';
      default:
        return creando
            ? 'No se pudo crear el evento. IntÃ©ntalo de nuevo.'
            : 'No se pudieron cargar los eventos. IntÃ©ntalo de nuevo.';
    }
  }
}
