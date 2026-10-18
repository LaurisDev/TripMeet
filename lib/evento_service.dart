import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'cloudinary_service.dart';
import 'guia_service.dart' show ArchivoLocal;
import 'publicacion_service.dart' show PublicacionService;

/// Roles con los que se registra un usuario (ver `registro_screen.dart`).
const String rolTurista = 'Turista';
const String rolGuiaTuristico = 'Guía turístico';

/// Valor de `estadoCertificados` de un guía cuyos certificados ya fueron
/// aprobados. `GuiaService` solo escribe `pendiente` y `en_revision`; la
/// aprobación se registra fuera de la app.
const String estadoCertificadosAprobado = 'aprobado';

/// Longitudes máximas de los textos de un evento.
const int longitudMaximaNombreEvento = 100;
const int longitudMaximaLugarEvento = 150;
const int longitudMaximaDescripcionEvento = 1000;

/// Longitud mínima del nombre y el lugar (sin espacios sobrantes).
const int longitudMinimaTextoEvento = 3;

/// Carpeta de Cloudinary para las fotos de eventos.
const String carpetaImagenesEventos = 'tripmeet/eventos';

/// Rango permitido para el cupo máximo de personas (opcional).
const int cupoMinimoEvento = 1;
const int cupoMaximoEvento = 1000;

/// Precio máximo de un evento, en pesos colombianos (opcional; 0 = gratis).
const int precioMaximoEvento = 50000000;

/// Certificado aprobado del guía que creó un evento, tal como lo guarda
/// `GuiaService` en `usuarios/{uid}.certificados.carneGuia` (PDF en
/// Cloudinary). Solo se expone el carné de guía turístico: los antecedentes
/// judiciales y los certificados adicionales son datos personales que no se
/// muestran a los turistas.
class CertificadoGuia {
  const CertificadoGuia({required this.nombre, required this.url});

  /// Nombre del archivo subido (por ejemplo, `carne.pdf`).
  final String nombre;

  /// `secure_url` del PDF en Cloudinary.
  final String url;

  /// Devuelve el carné de guía de [perfil] solo si el usuario es guía
  /// turístico, sus certificados están aprobados (`estadoCertificados`) y el
  /// carné tiene un enlace https válido. En cualquier otro caso, `null`: no
  /// se muestra ninguna certificación.
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
          : 'Carné de guía turístico',
      url: enlace.toString(),
    );
  }
}

/// Evento turístico publicado por un turista o un guía, visible para todos
/// en la sección "Eventos". Se guarda en la colección `eventos`, separada de las
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
    this.inscritos = const <String>[],
  });

  final String id;

  /// UID del usuario que creó el evento.
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

  /// `true` si el creador tiene el rol de guía turístico en su perfil
  /// (`usuarios/{creadorUid}`). No se lee del documento del evento: lo
  /// calcula [EventoService] a partir del rol real del creador, para que
  /// nadie pueda darle el diseño premium escribiendo un campo.
  final bool creadoPorGuia;

  /// Carné aprobado del guía creador; `null` si el creador no es guía, si
  /// sus certificados no están aprobados o si no hay un carné registrado.
  /// Igual que [creadoPorGuia], sale del perfil real del creador.
  final CertificadoGuia? certificadoGuia;

  /// Número máximo de personas; `null` si el creador no lo indicó.
  final int? cupoMaximo;

  /// Precio por persona en pesos colombianos (0 = gratis); `null` si el
  /// creador no lo indicó.
  final int? precio;

  /// UIDs de los usuarios inscritos en el evento (campo `inscritos`); vacía
  /// si nadie se ha unido.
  final List<String> inscritos;

  /// `true` si hay cupo máximo y ya se completó. Un evento sin
  /// [cupoMaximo] no tiene límite de participantes, así que nunca se llena.
  bool get estaLleno => cupoMaximo != null && inscritos.length >= cupoMaximo!;

  /// Cupos que quedan; `null` si el evento no tiene cupo máximo. Nunca es
  /// negativo (si el cupo se redujo por debajo de los inscritos, es 0).
  int? get cuposDisponibles {
    final int? cupo = cupoMaximo;
    if (cupo == null) return null;
    final int restantes = cupo - inscritos.length;
    return restantes < 0 ? 0 : restantes;
  }

  /// Copia con la lista de [inscritos] reemplazada (por ejemplo, después de
  /// que el usuario se une).
  Evento conInscritos(List<String> inscritos) => Evento(
    id: id,
    creadorUid: creadorUid,
    nombre: nombre,
    lugar: lugar,
    fechaHora: fechaHora,
    fechaCreacion: fechaCreacion,
    descripcion: descripcion,
    imagenUrl: imagenUrl,
    imagenPublicId: imagenPublicId,
    creadoPorGuia: creadoPorGuia,
    certificadoGuia: certificadoGuia,
    cupoMaximo: cupoMaximo,
    precio: precio,
    inscritos: inscritos,
  );

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
    inscritos: inscritos,
    creadoPorGuia: EventoService.esGuia(perfil),
    certificadoGuia: CertificadoGuia.desdePerfil(perfil),
  );

  factory Evento.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> documento,
  ) {
    final Map<String, dynamic> datos = documento.data() ?? <String, dynamic>{};

    return Evento(
      id: documento.id,
      creadorUid: datos['creadorUid'] as String? ?? '',
      nombre: datos['nombre'] as String? ?? '',
      lugar: datos['lugar'] as String? ?? '',
      fechaHora: (datos['fechaHora'] as Timestamp?)?.toDate() ?? DateTime.now(),
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
      inscritos: _listaDeUids(datos['inscritos']),
    );
  }

  static List<String> _listaDeUids(dynamic valor) {
    if (valor is! List) return const <String>[];
    return valor.whereType<String>().toList();
  }

  /// Lee un entero guardado; si falta o está fuera de rango, `null` (no se
  /// muestra un cupo o precio inválido).
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

/// Excepción de dominio con un mensaje seguro para mostrar en la interfaz.
class EventoServiceException implements Exception {
  const EventoServiceException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

/// El evento ya no tiene cupos (`evento-lleno`). Trae los [inscritos] tal
/// como están guardados para que la interfaz se actualice: por ejemplo, si
/// otra persona ocupó el último cupo mientras el usuario veía el detalle.
class EventoLlenoException extends EventoServiceException {
  const EventoLlenoException(this.inscritos)
    : super('El evento ya no tiene cupos disponibles.', code: 'evento-lleno');

  final List<String> inscritos;
}

/// Crea y consulta los eventos turísticos: sube la foto a Cloudinary (mismo
/// preset que publicaciones y certificados, carpeta `tripmeet/eventos`) y
/// guarda el documento en la colección `eventos` de Firestore.
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
  /// Devuelve el mensaje de error o `null` si es válido.
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

  /// Convierte el texto de un campo numérico opcional en entero: `null` si
  /// está vacío. Lanza [FormatException] si no es un entero (por ejemplo,
  /// "abc" o "2,5"). Acepta puntos y espacios como separadores de miles.
  static int? leerEnteroOpcional(String? texto) {
    final String limpio = (texto ?? '').replaceAll(RegExp(r'[\s.]'), '');
    if (limpio.isEmpty) return null;
    final int? valor = int.tryParse(limpio);
    if (valor == null) throw FormatException('No es un entero', texto);
    return valor;
  }

  /// Valida el cupo máximo: opcional, entero entre [cupoMinimoEvento] y
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

  /// Validador de formulario para un campo numérico opcional: revisa que el
  /// texto sea un entero y luego aplica [reglas].
  static String? validarCampoEntero(
    String? texto,
    String? Function(int?) reglas,
  ) {
    try {
      return reglas(leerEnteroOpcional(texto));
    } on FormatException {
      return 'Ingresa solo números enteros.';
    }
  }

  /// Valida la descripción: opcional, hasta
  /// [longitudMaximaDescripcionEvento] caracteres.
  static String? validarDescripcion(String? descripcion) {
    if ((descripcion?.trim().length ?? 0) > longitudMaximaDescripcionEvento) {
      return 'La descripción no puede superar '
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

  /// Regla de negocio: cualquier usuario registrado como turista o como guía
  /// turístico puede crear eventos. [perfil] es el documento
  /// `usuarios/{uid}`; `null` si no existe (sin perfil no se puede crear).
  static bool puedeCrear(Map<String, dynamic>? perfil) {
    if (perfil == null) return false;
    final dynamic rol = perfil['rol'];
    return rol is String &&
        (rol.trim() == rolTurista || rol.trim() == rolGuiaTuristico);
  }

  /// Indica si [perfil] es de un guía turístico con los certificados
  /// aprobados. Es lo que permite mostrar su carné en sus eventos.
  static bool esGuiaAprobado(Map<String, dynamic>? perfil) =>
      esGuia(perfil) &&
      perfil!['estadoCertificados'] == estadoCertificadosAprobado;

  /// Indica si [perfil] (documento `usuarios/{uid}`) tiene el rol de guía
  /// turístico, sin importar el estado de sus certificados. Es lo que
  /// decide el diseño premium de sus eventos.
  static bool esGuia(Map<String, dynamic>? perfil) {
    if (perfil == null) return false;
    final dynamic rol = perfil['rol'];
    return rol is String && rol.trim() == rolGuiaTuristico;
  }

  /// UID del usuario con sesión iniciada; `null` si no hay sesión.
  String? get uidUsuarioActual => _auth.currentUser?.uid;

  /// Indica si el usuario autenticado puede crear eventos (ver
  /// [puedeCrear]). Sin sesión iniciada devuelve `false`.
  Future<bool> puedeCrearEventos() async {
    final User? usuario = _auth.currentUser;
    if (usuario == null) return false;
    return puedeCrear(await _leerPerfil(usuario.uid));
  }

  /// Lee el perfil `usuarios/{uid}`; `null` si no existe.
  Future<Map<String, dynamic>?> _leerPerfil(String uid) async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> perfil = await _firestore
          .collection('usuarios')
          .doc(uid)
          .get();
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
  /// de subir nada. Si es guía, el evento sale con el diseño premium. La imagen es opcional; si se envía, debe cumplir las mismas
  /// reglas que la de una publicación. Lanza [EventoServiceException] con un
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
    final DocumentReference<Map<String, dynamic>> documento = _firestore
        .collection('eventos')
        .doc();
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
      final DocumentReference<Map<String, dynamic>> documento = _firestore
          .collection('eventos')
          .doc(eventoId);

      final DocumentSnapshot<Map<String, dynamic>> snapshot = await documento
          .get();

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
        'descripcion': (descripcionLimpia == null || descripcionLimpia.isEmpty)
            ? null
            : descripcionLimpia,
        'cupoMaximo': cupoMaximo,
        'precio': precio,
      });

      final DocumentSnapshot<Map<String, dynamic>> actualizado = await documento
          .get();

      // El diseño premium y el carné del guía salen del perfil del creador,
      // no del documento del evento; sin esto se perderían tras editar.
      Map<String, dynamic>? perfil;
      try {
        perfil = await _leerPerfil(usuario.uid);
      } on EventoServiceException {
        perfil = null;
      }

      return Evento.fromFirestore(actualizado).conPerfilDelCreador(perfil);
    } on EventoServiceException {
      rethrow;
    } on FirebaseException catch (error) {
      throw EventoServiceException(
        _mensajeParaErrorDeFirestore(error.code),
        code: error.code,
      );
    }
  }

  /// Elimina permanentemente el evento [eventoId] (HU-20). Solo puede
  /// hacerlo quien lo creó.
  ///
  /// Lee el documento antes de borrarlo para comprobar que haya sesión
  /// (`user-not-authenticated`), que el evento exista (`not-found`) y que el
  /// usuario sea su organizador (`permission-denied`). Si algo falla, el
  /// evento queda intacto.
  ///
  /// Igual que con las publicaciones, la foto no se borra de Cloudinary
  /// (borrar exige la API secret, que no puede vivir en la app).
  Future<void> eliminarEvento(String eventoId) async {
    final User? usuario = _auth.currentUser;
    if (usuario == null) {
      throw const EventoServiceException(
        'Inicia sesión para eliminar el evento.',
        code: 'user-not-authenticated',
      );
    }

    final DocumentReference<Map<String, dynamic>> documento = _firestore
        .collection('eventos')
        .doc(eventoId);

    try {
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await documento
          .get();
      if (!snapshot.exists) {
        throw const EventoServiceException(
          'El evento ya no existe.',
          code: 'not-found',
        );
      }
      if (Evento.fromFirestore(snapshot).creadorUid != usuario.uid) {
        throw const EventoServiceException(
          'Solo puedes eliminar los eventos que tú has creado.',
          code: 'permission-denied',
        );
      }

      await documento.delete();
    } on FirebaseException catch (error) {
      throw EventoServiceException(
        _mensajeParaErrorDeFirestore(error.code, eliminando: true),
        code: error.code,
      );
    }
  }

  /// Inscribe al usuario autenticado en el evento [eventoId] y devuelve la
  /// lista de inscritos actualizada.
  ///
  /// La inscripción es el UID del usuario dentro del arreglo `inscritos` del
  /// documento del evento. Se hace en una transacción que lee el evento y
  /// comprueba que:
  ///
  /// - haya sesión iniciada (`user-not-authenticated`);
  /// - el evento exista (`not-found`) y no haya ocurrido
  ///   (`evento-finalizado`);
  /// - quien se une no sea el creador (`es-creador`);
  /// - quede cupo, si el evento tiene cupo máximo (`evento-lleno`, como
  ///   [EventoLlenoException] con los inscritos actuales). Sin cupo máximo
  ///   no hay límite.
  ///
  /// Así, si dos personas se unen a la vez al último cupo, solo una lo
  /// consigue. Si el usuario ya estaba inscrito no se escribe nada: no hay
  /// inscripciones duplicadas.
  Future<List<String>> unirseEvento(String eventoId) async {
    final User? usuario = _auth.currentUser;
    if (usuario == null) {
      throw const EventoServiceException(
        'Inicia sesión para unirte al evento.',
        code: 'user-not-authenticated',
      );
    }

    final DocumentReference<Map<String, dynamic>> documento = _firestore
        .collection('eventos')
        .doc(eventoId);

    try {
      return await _firestore.runTransaction<List<String>>((
        Transaction transaccion,
      ) async {
        final DocumentSnapshot<Map<String, dynamic>> snapshot =
            await transaccion.get(documento);
        if (!snapshot.exists) {
          throw const EventoServiceException(
            'El evento ya no existe.',
            code: 'not-found',
          );
        }

        final Evento evento = Evento.fromFirestore(snapshot);
        if (evento.creadorUid == usuario.uid) {
          throw const EventoServiceException(
            'Eres el organizador de este evento.',
            code: 'es-creador',
          );
        }
        if (evento.inscritos.contains(usuario.uid)) {
          return evento.inscritos;
        }
        if (!evento.fechaHora.isAfter(_reloj())) {
          throw const EventoServiceException(
            'Este evento ya finalizó.',
            code: 'evento-finalizado',
          );
        }
        // La verificación del cupo y la escritura van en la misma
        // transacción: si otra persona se inscribe entre la lectura y la
        // escritura, Firestore repite la transacción con los datos nuevos y
        // esta comprobación vuelve a correr. Así nunca se supera el cupo.
        if (evento.estaLleno) {
          throw EventoLlenoException(evento.inscritos);
        }

        transaccion.update(documento, <String, dynamic>{
          'inscritos': FieldValue.arrayUnion(<String>[usuario.uid]),
        });
        return <String>[...evento.inscritos, usuario.uid];
      });
    } on FirebaseException catch (error) {
      throw EventoServiceException(
        _mensajeParaErrorDeFirestore(error.code, inscribiendo: true),
        code: error.code,
      );
    }
  }

  /// Retira al usuario autenticado del evento [eventoId] (HU-25) y devuelve
  /// la lista de inscritos actualizada. Al quitar su UID de `inscritos`, su
  /// cupo queda libre para otras personas.
  ///
  /// Igual que [unirseEvento], se hace en una transacción que comprueba que
  /// haya sesión (`user-not-authenticated`), que el evento exista
  /// (`not-found`) y no haya ocurrido (`evento-finalizado`), y que quien
  /// sale no sea el organizador (`es-creador`). Si el usuario no estaba
  /// inscrito no se escribe nada.
  Future<List<String>> salirEvento(String eventoId) async {
    final User? usuario = _auth.currentUser;
    if (usuario == null) {
      throw const EventoServiceException(
        'Inicia sesión para salir del evento.',
        code: 'user-not-authenticated',
      );
    }

    final DocumentReference<Map<String, dynamic>> documento = _firestore
        .collection('eventos')
        .doc(eventoId);

    try {
      return await _firestore.runTransaction<List<String>>((
        Transaction transaccion,
      ) async {
        final DocumentSnapshot<Map<String, dynamic>> snapshot =
            await transaccion.get(documento);
        if (!snapshot.exists) {
          throw const EventoServiceException(
            'El evento ya no existe.',
            code: 'not-found',
          );
        }

        final Evento evento = Evento.fromFirestore(snapshot);
        if (evento.creadorUid == usuario.uid) {
          throw const EventoServiceException(
            'Eres el organizador de este evento.',
            code: 'es-creador',
          );
        }
        if (!evento.inscritos.contains(usuario.uid)) {
          return evento.inscritos;
        }
        if (!evento.fechaHora.isAfter(_reloj())) {
          throw const EventoServiceException(
            'Este evento ya finalizó.',
            code: 'evento-finalizado',
          );
        }

        transaccion.update(documento, <String, dynamic>{
          'inscritos': FieldValue.arrayRemove(<String>[usuario.uid]),
        });
        return <String>[
          for (final String uid in evento.inscritos)
            if (uid != usuario.uid) uid,
        ];
      });
    } on FirebaseException catch (error) {
      throw EventoServiceException(
        _mensajeParaErrorDeFirestore(error.code, saliendo: true),
        code: error.code,
      );
    }
  }

  /// Lee el estado actual del evento [eventoId] (incluidos sus inscritos y
  /// los datos de su creador). La usa el detalle al abrirse, para no mostrar
  /// una inscripción desactualizada. Lanza `not-found` si ya no existe.
  Future<Evento> obtenerEvento(String eventoId) async {
    final DocumentSnapshot<Map<String, dynamic>> snapshot;
    try {
      snapshot = await _firestore.collection('eventos').doc(eventoId).get();
    } on FirebaseException catch (error) {
      throw EventoServiceException(
        _mensajeParaErrorDeFirestore(error.code),
        code: error.code,
      );
    }
    if (!snapshot.exists) {
      throw const EventoServiceException(
        'El evento ya no existe.',
        code: 'not-found',
      );
    }

    final Evento evento = Evento.fromFirestore(snapshot);
    Map<String, dynamic>? perfil;
    try {
      perfil = await _leerPerfil(evento.creadorUid);
    } on EventoServiceException {
      perfil = null;
    }
    return evento.conPerfilDelCreador(perfil);
  }

  /// Consulta los eventos disponibles: los que aún no han ocurrido
  /// (`fechaHora` a partir de [desde], por defecto ahora), del más próximo
  /// al más lejano. Cada evento indica si su creador es guía turístico y,
  /// si está aprobado, trae su carné (ver [Evento.conPerfilDelCreador]).
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

      final List<Evento> eventos = snapshot.docs
          .map(Evento.fromFirestore)
          .toList();
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
  /// solo que sin diseño premium ni certificado.
  Future<Map<String, Map<String, dynamic>?>> _perfilesDeCreadores(
    Set<String> uids,
  ) async {
    final List<String> validos = uids
        .where((String uid) => uid.isNotEmpty)
        .toList();
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

  String _mensajeParaErrorDeFirestore(
    String codigo, {
    bool creando = false,
    bool inscribiendo = false,
    bool saliendo = false,
    bool eliminando = false,
  }) {
    switch (codigo) {
      case 'unavailable':
      case 'network-request-failed':
        return 'No se pudo completar la operación por un problema de conexión.';
      case 'permission-denied':
        return 'No tienes permiso para realizar esta acción.';
      default:
        if (inscribiendo) {
          return 'No se pudo completar tu inscripción. Inténtalo de nuevo.';
        }
        if (saliendo) {
          return 'No se pudo completar tu salida del evento. '
              'Inténtalo de nuevo.';
        }
        if (eliminando) {
          return 'No se pudo eliminar el evento. Inténtalo de nuevo.';
        }
        return creando
            ? 'No se pudo crear el evento. Inténtalo de nuevo.'
            : 'No se pudieron cargar los eventos. Inténtalo de nuevo.';
    }
  }
}
