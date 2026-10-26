import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Modelo para un reporte sobre una reseña (de un usuario o de un lugar).
class ReporteResena {
  const ReporteResena({
    required this.id,
    required this.resenaId,
    this.usuarioCalificadoUid,
    this.lugarId,
    required this.autorResenaNombre,
    required this.comentarioResena,
    required this.estrellas,
    required this.reportadoPorUid,
    required this.reportadoPorNombre,
    required this.motivo,
    required this.fecha,
    this.estado = 'pendiente',
  });

  final String id;
  final String resenaId;
  final String? usuarioCalificadoUid;
  final String? lugarId;
  final String autorResenaNombre;
  final String comentarioResena;
  final double estrellas;
  final String reportadoPorUid;
  final String reportadoPorNombre;
  final String motivo;
  final DateTime fecha;
  final String estado;

  factory ReporteResena.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> datos = doc.data() ?? <String, dynamic>{};
    return ReporteResena(
      id: doc.id,
      resenaId: datos['resenaId'] as String? ?? '',
      usuarioCalificadoUid: datos['usuarioCalificadoUid'] as String?,
      lugarId: datos['lugarId'] as String?,
      autorResenaNombre: datos['autorResenaNombre'] as String? ?? 'Anónimo',
      comentarioResena: datos['comentarioResena'] as String? ?? '',
      estrellas: (datos['estrellas'] as num?)?.toDouble() ?? 5.0,
      reportadoPorUid: datos['reportadoPorUid'] as String? ?? '',
      reportadoPorNombre: datos['reportadoPorNombre'] as String? ?? 'Usuario',
      motivo: datos['motivo'] as String? ?? 'Sin motivo',
      fecha: (datos['fecha'] as Timestamp?)?.toDate() ?? DateTime.now(),
      estado: datos['estado'] as String? ?? 'pendiente',
    );
  }

  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'resenaId': resenaId,
      'usuarioCalificadoUid': usuarioCalificadoUid,
      'lugarId': lugarId,
      'autorResenaNombre': autorResenaNombre,
      'comentarioResena': comentarioResena,
      'estrellas': estrellas,
      'reportadoPorUid': reportadoPorUid,
      'reportadoPorNombre': reportadoPorNombre,
      'motivo': motivo,
      'fecha': Timestamp.fromDate(fecha),
      'estado': estado,
    };
  }
}

/// Modelo para un reporte sobre una publicación del feed.
class ReportePublicacion {
  const ReportePublicacion({
    required this.id,
    required this.publicacionId,
    required this.autorPublicacionUid,
    this.autorPublicacionNombre,
    this.imagenUrl,
    this.descripcionPublicacion,
    required this.reportadoPorUid,
    required this.reportadoPorNombre,
    required this.motivo,
    required this.fecha,
    this.estado = 'pendiente',
  });

  final String id;
  final String publicacionId;
  final String autorPublicacionUid;
  final String? autorPublicacionNombre;
  final String? imagenUrl;
  final String? descripcionPublicacion;
  final String reportadoPorUid;
  final String reportadoPorNombre;
  final String motivo;
  final DateTime fecha;
  final String estado;

  factory ReportePublicacion.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> datos = doc.data() ?? <String, dynamic>{};
    return ReportePublicacion(
      id: doc.id,
      publicacionId: datos['publicacionId'] as String? ?? '',
      autorPublicacionUid: datos['autorPublicacionUid'] as String? ?? '',
      autorPublicacionNombre: datos['autorPublicacionNombre'] as String?,
      imagenUrl: datos['imagenUrl'] as String?,
      descripcionPublicacion: datos['descripcionPublicacion'] as String?,
      reportadoPorUid: datos['reportadoPorUid'] as String? ?? '',
      reportadoPorNombre: datos['reportadoPorNombre'] as String? ?? 'Usuario',
      motivo: datos['motivo'] as String? ?? 'Sin motivo',
      fecha: (datos['fecha'] as Timestamp?)?.toDate() ?? DateTime.now(),
      estado: datos['estado'] as String? ?? 'pendiente',
    );
  }

  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'publicacionId': publicacionId,
      'autorPublicacionUid': autorPublicacionUid,
      'autorPublicacionNombre': autorPublicacionNombre,
      'imagenUrl': imagenUrl,
      'descripcionPublicacion': descripcionPublicacion,
      'reportadoPorUid': reportadoPorUid,
      'reportadoPorNombre': reportadoPorNombre,
      'motivo': motivo,
      'fecha': Timestamp.fromDate(fecha),
      'estado': estado,
    };
  }
}

/// Servicio de administración para HU-33 (Revisar reseñas reportadas)
/// y HU-34 (Revisar publicaciones reportadas).
class ReportesAdminService {
  ReportesAdminService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _customFirestore = firestore,
        _customAuth = auth;

  final FirebaseFirestore? _customFirestore;
  final FirebaseAuth? _customAuth;

  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _customAuth ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _colReportesResenas =>
      _firestore.collection('reportes_resenas');

  CollectionReference<Map<String, dynamic>> get _colReportesPublicaciones =>
      _firestore.collection('reportes_publicaciones');

  /// Registra un nuevo reporte sobre una reseña.
  Future<void> reportarResena({
    required String resenaId,
    String? usuarioCalificadoUid,
    String? lugarId,
    required String autorResenaNombre,
    required String comentarioResena,
    required double estrellas,
    required String motivo,
  }) async {
    final User? user = _auth.currentUser;
    final String reporterUid = user?.uid ?? 'anonimo';
    final String reporterNombre =
        user?.displayName ?? user?.email ?? 'Usuario de TripMeet';

    final ReporteResena nuevoReporte = ReporteResena(
      id: '',
      resenaId: resenaId,
      usuarioCalificadoUid: usuarioCalificadoUid,
      lugarId: lugarId,
      autorResenaNombre: autorResenaNombre,
      comentarioResena: comentarioResena,
      estrellas: estrellas,
      reportadoPorUid: reporterUid,
      reportadoPorNombre: reporterNombre,
      motivo: motivo,
      fecha: DateTime.now(),
    );

    await _colReportesResenas.add(nuevoReporte.toFirestore());
  }

  /// Registra un nuevo reporte sobre una publicación.
  Future<void> reportarPublicacion({
    required String publicacionId,
    required String autorPublicacionUid,
    String? autorPublicacionNombre,
    String? imagenUrl,
    String? descripcionPublicacion,
    required String motivo,
  }) async {
    final User? user = _auth.currentUser;
    final String reporterUid = user?.uid ?? 'anonimo';
    final String reporterNombre =
        user?.displayName ?? user?.email ?? 'Usuario de TripMeet';

    final ReportePublicacion nuevoReporte = ReportePublicacion(
      id: '',
      publicacionId: publicacionId,
      autorPublicacionUid: autorPublicacionUid,
      autorPublicacionNombre: autorPublicacionNombre,
      imagenUrl: imagenUrl,
      descripcionPublicacion: descripcionPublicacion,
      reportadoPorUid: reporterUid,
      reportadoPorNombre: reporterNombre,
      motivo: motivo,
      fecha: DateTime.now(),
    );

    await _colReportesPublicaciones.add(nuevoReporte.toFirestore());
  }

  /// Obtiene los reportes pendientes de reseñas.
  Future<List<ReporteResena>> obtenerResenasReportadas() async {
    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await _colReportesResenas.where('estado', isEqualTo: 'pendiente').get();

    final List<ReporteResena> lista = snapshot.docs
        .map(ReporteResena.fromFirestore)
        .toList();
    lista.sort((ReporteResena a, ReporteResena b) => b.fecha.compareTo(a.fecha));
    return lista;
  }

  /// Obtiene los reportes pendientes de publicaciones.
  Future<List<ReportePublicacion>> obtenerPublicacionesReportadas() async {
    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await _colReportesPublicaciones
            .where('estado', isEqualTo: 'pendiente')
            .get();

    final List<ReportePublicacion> lista = snapshot.docs
        .map(ReportePublicacion.fromFirestore)
        .toList();
    lista.sort(
        (ReportePublicacion a, ReportePublicacion b) => b.fecha.compareTo(a.fecha));
    return lista;
  }

  /// Resuelve un reporte de reseña: si [eliminarResena] es true, elimina la
  /// reseña original de Firestore y marca el reporte como 'resuelto'. Si es
  /// false, simplemente marca el reporte como 'descartado'.
  Future<void> resolverReporteResena({
    required String reporteId,
    required String resenaId,
    String? usuarioCalificadoUid,
    String? lugarId,
    required bool eliminarResena,
  }) async {
    if (eliminarResena) {
      if (usuarioCalificadoUid != null && usuarioCalificadoUid.isNotEmpty) {
        // Eliminar reseña de usuario
        await _firestore
            .collection('usuarios')
            .doc(usuarioCalificadoUid)
            .collection('Reseñas')
            .doc(resenaId)
            .delete();
      } else if (lugarId != null && lugarId.isNotEmpty) {
        // Eliminar reseña de lugar
        await _firestore
            .collection('Lugares')
            .doc(lugarId)
            .collection('Resenas')
            .doc(resenaId)
            .delete();
      }
      await _colReportesResenas
          .doc(reporteId)
          .update(<String, dynamic>{'estado': 'resuelto'});
    } else {
      await _colReportesResenas
          .doc(reporteId)
          .update(<String, dynamic>{'estado': 'descartado'});
    }
  }

  /// Resuelve un reporte de publicación: si [eliminarPublicacion] es true,
  /// elimina la publicación original de Firestore y marca el reporte como
  /// 'resuelto'. Si es false, marca el reporte como 'descartado'.
  Future<void> resolverReportePublicacion({
    required String reporteId,
    required String publicacionId,
    required bool eliminarPublicacion,
  }) async {
    if (eliminarPublicacion) {
      await _firestore.collection('publicaciones').doc(publicacionId).delete();
      await _colReportesPublicaciones
          .doc(reporteId)
          .update(<String, dynamic>{'estado': 'resuelto'});
    } else {
      await _colReportesPublicaciones
          .doc(reporteId)
          .update(<String, dynamic>{'estado': 'descartado'});
    }
  }
}
