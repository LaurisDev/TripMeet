import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'evento_service.dart';
import 'lugares_service.dart' show Resena;
import 'moderacion_service.dart';
import 'publicacion_service.dart' show AutorPublicacion;

/// Calificación mínima y máxima (estrellas) de un usuario.
const int calificacionMinima = 1;
const int calificacionMaxima = 5;

/// Longitud máxima del comentario de una reseña.
const int longitudMaximaComentarioResena = 500;

/// Promedio y cantidad de calificaciones que ha recibido un usuario.
class ResumenCalificaciones {
  const ResumenCalificaciones({required this.promedio, required this.total});

  /// Promedio de estrellas; `null` si aún no tiene calificaciones.
  final double? promedio;
  final int total;

  bool get tieneCalificaciones => total > 0 && promedio != null;
}

/// Reseña recibida por un usuario, con el nombre del evento compartido para
/// mostrarlo en su perfil.
class ResenaRecibida {
  const ResenaRecibida({required this.resena, this.nombreEvento});

  final Resena resena;

  /// Nombre del evento; `null` si ya no existe o no se pudo leer.
  final String? nombreEvento;
}

/// Excepción de dominio con un mensaje seguro para mostrar en la interfaz.
class CalificacionException implements Exception {
  const CalificacionException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

/// Calificaciones entre usuarios que compartieron un evento (HU-28).
///
/// Cada calificación es una [Resena] (el mismo modelo de las reseñas de
/// lugares) guardada en `usuarios/{calificado}/Reseñas/{autor}_{evento}`:
///
/// - `usuarioId`: quien califica; `nombreUsuario`: su nombre visible;
/// - `calificacion`: de 1 a 5 estrellas; `fecha`;
/// - `eventoId`: el evento compartido.
///
/// El id del documento une autor y evento, así que cada persona solo puede
/// calificar una vez a otra por cada evento compartido. El promedio no se
/// guarda aparte: se calcula en Firestore sobre esas reseñas, así que
/// siempre refleja las calificaciones registradas.
class CalificacionUsuarioService {
  CalificacionUsuarioService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    DateTime Function()? reloj,
    ModeradorComentarios? moderador,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _reloj = reloj ?? DateTime.now,
       _moderador = moderador ?? moderadorPorDefecto();

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final DateTime Function() _reloj;

  /// Revisa el comentario antes de publicarlo (ver [moderadorPorDefecto]).
  final ModeradorComentarios _moderador;

  /// Quienes participaron en [evento]: el organizador y los inscritos.
  static Set<String> participantes(Evento evento) => <String>{
    if (evento.creadorUid.isNotEmpty) evento.creadorUid,
    ...evento.inscritos,
  };

  /// Id del documento de la calificación de [autorUid] en [eventoId].
  static String idCalificacion(String autorUid, String eventoId) =>
      '${autorUid}_$eventoId';

  /// Valida que [calificacion] esté entre 1 y 5 estrellas.
  static String? validarCalificacion(int? calificacion) {
    if (calificacion == null) return 'Selecciona de 1 a 5 estrellas.';
    if (calificacion < calificacionMinima ||
        calificacion > calificacionMaxima) {
      return 'La calificación debe estar entre $calificacionMinima y '
          '$calificacionMaxima estrellas.';
    }
    return null;
  }

  CollectionReference<Map<String, dynamic>> _resenasDe(String uid) =>
      _firestore.collection('usuarios').doc(uid).collection('Reseñas');

  /// Valida el comentario de la reseña: obligatorio (no vacío ni solo
  /// espacios) y de hasta [longitudMaximaComentarioResena] caracteres.
  static String? validarComentario(String? comentario) {
    final String limpio = comentario?.trim() ?? '';
    if (limpio.isEmpty) return 'Escribe un comentario para tu reseña.';
    if (limpio.length > longitudMaximaComentarioResena) {
      return 'El comentario no puede superar '
          '$longitudMaximaComentarioResena caracteres.';
    }
    return null;
  }

  /// Publica la reseña del usuario autenticado sobre [calificadoUid] por el
  /// evento [eventoId]: la calificación de 1 a 5 estrellas y su comentario,
  /// guardados juntos en un solo documento (no queda una calificación sin
  /// comentario ni al revés).
  ///
  /// Se hace en una transacción que lee el evento y comprueba que:
  ///
  /// - haya sesión (`user-not-authenticated`), la calificación sea de 1 a 5
  ///   (`calificacion-invalida`) y el comentario no esté vacío
  ///   (`comentario-invalido`);
  /// - no se califique a sí mismo (`auto-calificacion`);
  /// - el evento exista (`not-found`) y ya haya finalizado
  ///   (`evento-no-finalizado`);
  /// - ambos hayan participado en él como organizador o inscritos
  ///   (`no-participaste`, `no-participo`);
  /// - no lo haya calificado ya por este evento (`ya-calificado`).
  ///
  /// Antes de la transacción, el comentario pasa por la moderación: si es
  /// ofensivo no se guarda nada (`comentario-ofensivo`), y si la moderación
  /// falla tampoco (`moderacion-no-disponible`): un error técnico nunca
  /// cuenta como comentario aprobado.
  Future<void> calificarUsuario({
    required String eventoId,
    required String calificadoUid,
    required int? calificacion,
    required String? comentario,
  }) async {
    final User usuario = await _validarAntesDePublicar(
      calificadoUid: calificadoUid,
      calificacion: calificacion,
      comentario: comentario,
    );

    final DocumentReference<Map<String, dynamic>> eventoRef = _firestore
        .collection('eventos')
        .doc(eventoId);
    final DocumentReference<Map<String, dynamic>> calificacionRef = _resenasDe(
      calificadoUid,
    ).doc(idCalificacion(usuario.uid, eventoId));

    try {
      final String nombreAutor = await _nombreDe(usuario.uid);

      await _firestore.runTransaction<void>((Transaction transaccion) async {
        final DocumentSnapshot<Map<String, dynamic>> eventoSnap =
            await transaccion.get(eventoRef);
        if (!eventoSnap.exists) {
          throw const CalificacionException(
            'El evento ya no existe.',
            code: 'not-found',
          );
        }

        final Evento evento = Evento.fromFirestore(eventoSnap);
        if (!evento.fechaHora.isBefore(_reloj())) {
          throw const CalificacionException(
            'Podrás calificar cuando el evento haya finalizado.',
            code: 'evento-no-finalizado',
          );
        }
        final Set<String> enEvento = participantes(evento);
        if (!enEvento.contains(usuario.uid)) {
          throw const CalificacionException(
            'Solo puedes calificar a personas con quienes participaste en '
            'este evento.',
            code: 'no-participaste',
          );
        }
        if (!enEvento.contains(calificadoUid)) {
          throw const CalificacionException(
            'Esta persona no participó en el evento.',
            code: 'no-participo',
          );
        }
        if ((await transaccion.get(calificacionRef)).exists) {
          throw const CalificacionException(
            'Ya calificaste a esta persona por este evento.',
            code: 'ya-calificado',
          );
        }

        transaccion.set(
          calificacionRef,
          Resena(
            usuarioId: usuario.uid,
            nombreUsuario: nombreAutor,
            comentario: comentario!.trim(),
            calificacion: calificacion!.toDouble(),
            fecha: _reloj(),
            eventoId: eventoId,
          ).toFirestore(),
        );
      });
    } on FirebaseException catch (error) {
      throw CalificacionException(
        _mensajeParaErrorDeFirestore(error.code),
        code: error.code,
      );
    }
  }

  /// Id de la reseña general que [autorUid] deja desde un perfil (sin
  /// evento). Al ser fijo, solo puede haber una por persona.
  static String idCalificacionDesdePerfil(String autorUid) =>
      '${autorUid}_perfil';

  /// Publica la reseña general del usuario autenticado sobre [calificadoUid]
  /// desde su perfil, sin necesidad de haber compartido un evento.
  ///
  /// Aplica las mismas validaciones y la misma moderación que
  /// [calificarUsuario] (sesión, 1 a 5 estrellas, comentario, no
  /// calificarse a sí mismo) y, en una transacción, que no exista ya la
  /// reseña general de este autor (`ya-calificado`): una por persona.
  Future<void> calificarDesdePerfil({
    required String calificadoUid,
    required int? calificacion,
    required String? comentario,
  }) async {
    final User usuario = await _validarAntesDePublicar(
      calificadoUid: calificadoUid,
      calificacion: calificacion,
      comentario: comentario,
    );
    final DocumentReference<Map<String, dynamic>> calificacionRef = _resenasDe(
      calificadoUid,
    ).doc(idCalificacionDesdePerfil(usuario.uid));

    try {
      final String nombreAutor = await _nombreDe(usuario.uid);

      await _firestore.runTransaction<void>((Transaction transaccion) async {
        if ((await transaccion.get(calificacionRef)).exists) {
          throw const CalificacionException(
            'Ya calificaste a este usuario.',
            code: 'ya-calificado',
          );
        }
        transaccion.set(
          calificacionRef,
          Resena(
            usuarioId: usuario.uid,
            nombreUsuario: nombreAutor,
            comentario: comentario!.trim(),
            calificacion: calificacion!.toDouble(),
            fecha: _reloj(),
          ).toFirestore(),
        );
      });
    } on FirebaseException catch (error) {
      throw CalificacionException(
        _mensajeParaErrorDeFirestore(error.code),
        code: error.code,
      );
    }
  }

  /// `true` si el usuario autenticado ya dejó su reseña general (desde el
  /// perfil) a [calificadoUid]. Si no se puede leer, `false`: el servidor
  /// igual rechaza una segunda reseña.
  Future<bool> yaCalificoDesdePerfil(String calificadoUid) async {
    final String? autor = _auth.currentUser?.uid;
    if (autor == null) return false;
    try {
      return (await _resenasDe(
        calificadoUid,
      ).doc(idCalificacionDesdePerfil(autor)).get()).exists;
    } on FirebaseException {
      return false;
    }
  }

  /// Validaciones comunes antes de publicar cualquier reseña: sesión, 1 a 5
  /// estrellas, comentario, no calificarse a sí mismo y moderación del
  /// comentario. Devuelve el usuario autenticado.
  Future<User> _validarAntesDePublicar({
    required String calificadoUid,
    required int? calificacion,
    required String? comentario,
  }) async {
    final User? usuario = _auth.currentUser;
    if (usuario == null) {
      throw const CalificacionException(
        'Inicia sesión para calificar.',
        code: 'user-not-authenticated',
      );
    }
    final String? errorCalificacion = validarCalificacion(calificacion);
    if (errorCalificacion != null) {
      throw CalificacionException(
        errorCalificacion,
        code: 'calificacion-invalida',
      );
    }
    final String? errorComentario = validarComentario(comentario);
    if (errorComentario != null) {
      throw CalificacionException(errorComentario, code: 'comentario-invalido');
    }
    if (calificadoUid == usuario.uid) {
      throw const CalificacionException(
        'No puedes calificarte a ti mismo.',
        code: 'auto-calificacion',
      );
    }
    await _moderar(comentario!.trim());
    return usuario;
  }

  /// Revisa [comentario] con el moderador. Bloquea si es ofensivo y también
  /// si la moderación falla. No incluye el comentario en ningún mensaje.
  Future<void> _moderar(String comentario) async {
    final bool aceptable;
    try {
      aceptable = await _moderador.esAceptable(comentario);
    } catch (_) {
      throw const CalificacionException(
        'No pudimos revisar tu comentario en este momento, así que aún no se '
        'publicó. Inténtalo de nuevo en unos minutos.',
        code: 'moderacion-no-disponible',
      );
    }
    if (!aceptable) {
      throw const CalificacionException(
        'Tu comentario incluye expresiones que no están permitidas en '
        'TripMeet. Por favor, modifícalo para que sea respetuoso e inténtalo '
        'de nuevo.',
        code: 'comentario-ofensivo',
      );
    }
  }

  /// Reseñas recibidas por [uid], de la más reciente a la más antigua, con
  /// el nombre de cada evento (leído una sola vez por evento).
  Future<List<ResenaRecibida>> obtenerResenas(String uid) async {
    final List<Resena> resenas;
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _resenasDe(uid)
          .orderBy('fecha', descending: true)
          .get();
      resenas = snapshot.docs.map(Resena.fromFirestore).toList();
    } on FirebaseException catch (error) {
      throw CalificacionException(
        _mensajeParaErrorDeFirestore(error.code, leyendo: true),
        code: error.code,
      );
    }

    final Set<String> eventos = <String>{
      for (final Resena r in resenas)
        if (r.eventoId != null) r.eventoId!,
    };
    final Map<String, String?> nombres = <String, String?>{
      for (final MapEntry<String, String?> e in await Future.wait(
        eventos.map((String id) async {
          try {
            final Map<String, dynamic>? datos =
                (await _firestore.collection('eventos').doc(id).get()).data();
            final dynamic nombre = datos?['nombre'];
            return MapEntry<String, String?>(
              id,
              nombre is String && nombre.trim().isNotEmpty ? nombre : null,
            );
          } on FirebaseException {
            return MapEntry<String, String?>(id, null);
          }
        }),
      ))
        e.key: e.value,
    };

    return <ResenaRecibida>[
      for (final Resena r in resenas)
        ResenaRecibida(
          resena: r,
          nombreEvento: r.eventoId == null ? null : nombres[r.eventoId],
        ),
    ];
  }

  /// Promedio y total de calificaciones recibidas por [uid].
  Future<ResumenCalificaciones> obtenerResumen(String uid) async {
    try {
      final AggregateQuerySnapshot resumen = await _resenasDe(uid)
          .aggregate(count(), average('calificacion'))
          .get();
      final int total = resumen.count ?? 0;
      return ResumenCalificaciones(
        promedio: total == 0 ? null : resumen.getAverage('calificacion'),
        total: total,
      );
    } on FirebaseException catch (error) {
      throw CalificacionException(
        _mensajeParaErrorDeFirestore(error.code),
        code: error.code,
      );
    }
  }

  /// De entre [candidatos], a quiénes ya calificó el usuario autenticado
  /// por [eventoId]. Si no se puede leer alguno, se trata como no
  /// calificado: el servidor igual rechaza una calificación repetida.
  Future<Set<String>> calificadosPorMi({
    required String eventoId,
    required Iterable<String> candidatos,
  }) async {
    final String? autor = _auth.currentUser?.uid;
    if (autor == null) return <String>{};

    final List<String?> calificados = await Future.wait(
      candidatos.map((String uid) async {
        try {
          final DocumentSnapshot<Map<String, dynamic>> doc = await _resenasDe(
            uid,
          ).doc(idCalificacion(autor, eventoId)).get();
          return doc.exists ? uid : null;
        } on FirebaseException {
          return null;
        }
      }),
    );
    return calificados.whereType<String>().toSet();
  }

  /// Nombre visible de [uid]: su `nombre` o, si no tiene, la parte del
  /// correo antes de la "@".
  Future<String> _nombreDe(String uid) async {
    final Map<String, dynamic>? perfil =
        (await _firestore.collection('usuarios').doc(uid).get()).data();
    final dynamic nombre = perfil?['nombre'];
    if (nombre is String && nombre.trim().isNotEmpty) return nombre.trim();
    return AutorPublicacion.aliasDesdeCorreo(perfil?['correo']);
  }

  String _mensajeParaErrorDeFirestore(String codigo, {bool leyendo = false}) {
    switch (codigo) {
      case 'unavailable':
      case 'network-request-failed':
        return 'No se pudo completar la operación por un problema de conexión.';
      case 'permission-denied':
        return 'No tienes permiso para realizar esta acción.';
      default:
        return leyendo
            ? 'No se pudieron cargar las reseñas. Inténtalo de nuevo.'
            : 'No se pudo publicar la reseña. Inténtalo de nuevo.';
    }
  }
}
