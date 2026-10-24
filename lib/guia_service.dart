import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'cloudinary_service.dart';
import 'notificacion_service.dart';

/// Archivo elegido en el dispositivo, listo para subirse.
///
/// Se guarda en memoria (`bytes`) para funcionar igual en móvil y web.
class ArchivoLocal {
  const ArchivoLocal({
    required this.nombre,
    required this.bytes,
    required this.extension,
  });

  final String nombre;
  final Uint8List bytes;
  final String extension;

  int get tamano => bytes.length;

  bool get esPdf => extension.toLowerCase() == 'pdf';

  String get tamanoLegible {
    if (tamano < 1024) return '$tamano B';
    if (tamano < 1024 * 1024) {
      return '${(tamano / 1024).toStringAsFixed(0)} KB';
    }
    return '${(tamano / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get contentType => esPdf ? 'application/pdf' : 'application/octet-stream';
}

/// Metadatos de un archivo ya subido a Cloudinary y guardado en Firestore.
class CertificadoSubido {
  const CertificadoSubido({
    required this.nombre,
    required this.url,
    required this.publicId,
    required this.contentType,
    required this.tamano,
  });

  final String nombre;

  /// `secure_url` devuelta por Cloudinary. Este es el enlace que ya se
  /// guardaba en Firestore cuando el archivo venía de Firebase Storage: el
  /// campo se llama igual, solo cambia de dónde sale el link.
  final String url;

  /// `public_id` de Cloudinary (reemplaza a la antigua ruta de Storage).
  final String publicId;
  final String contentType;
  final int tamano;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'nombre': nombre,
        'url': url,
        'publicId': publicId,
        'contentType': contentType,
        'tamano': tamano,
        'fechaSubida': Timestamp.now(),
      };
}

/// Datos del perfil laboral del guía (Pantalla 3).
class PerfilLaboral {
  const PerfilLaboral({
    required this.aniosExperiencia,
    required this.zonas,
    required this.especialidades,
    required this.idiomas,
    this.biografia,
  });

  final int aniosExperiencia;
  final List<String> zonas;
  final List<String> especialidades;
  final List<String> idiomas;
  final String? biografia;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'aniosExperiencia': aniosExperiencia,
        'zonas': zonas,
        'especialidades': especialidades,
        'idiomas': idiomas,
        if (biografia != null && biografia!.trim().isNotEmpty)
          'biografia': biografia!.trim(),
      };
}

/// Excepción de dominio con un mensaje seguro para mostrar en la interfaz.
class GuiaServiceException implements Exception {
  const GuiaServiceException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

/// Sube certificados (PDF, vía Cloudinary) y guarda el perfil laboral del
/// guía turístico.
///
/// Los archivos se almacenan en Cloudinary y sus metadatos (nombre y URL)
/// quedan registrados en el documento `usuarios/{uid}` de Firestore, igual
/// que los datos capturados en el registro (Pantalla 1). Firestore y
/// Firebase Auth siguen siendo la base de datos y la autenticación de la
/// app; solo cambió el destino de los archivos.
class GuiaService {
  GuiaService({
    FirebaseFirestore? firestore,
    CloudinaryService? cloudinary,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _cloudinary = cloudinary ?? CloudinaryService();

  final FirebaseFirestore _firestore;
  final CloudinaryService _cloudinary;
  late final NotificacionService _notificacionService =
      NotificacionService(firestore: _firestore);

  DocumentReference<Map<String, dynamic>> _usuario(String userId) =>
      _firestore.collection('usuarios').doc(userId);

  /// Sube un PDF a Cloudinary y devuelve sus metadatos.
  Future<CertificadoSubido> _subirArchivo({
    required ArchivoLocal archivo,
  }) async {
    if (!archivo.esPdf) {
      throw const GuiaServiceException(
        'Solo se permiten archivos en formato PDF.',
        code: 'formato-invalido',
      );
    }

    try {
      final CloudinarySubida subida = await _cloudinary.subirPdf(
        bytes: archivo.bytes,
        nombreArchivo: archivo.nombre,
      );
      return CertificadoSubido(
        nombre: archivo.nombre,
        url: subida.secureUrl,
        publicId: subida.publicId,
        contentType: archivo.contentType,
        tamano: subida.bytes,
      );
    } on CloudinaryException catch (error) {
      throw GuiaServiceException(error.message, code: error.code);
    }
  }

  /// Sube los certificados (2 obligatorios + adicionales opcionales) y marca
  /// el perfil como "en revisión".
  Future<void> subirCertificados({
    required String userId,
    required ArchivoLocal carneGuia,
    required ArchivoLocal antecedentesJudiciales,
    List<ArchivoLocal> adicionales = const <ArchivoLocal>[],
  }) async {
    try {
      final CertificadoSubido carne = await _subirArchivo(archivo: carneGuia);
      final CertificadoSubido antecedentes =
          await _subirArchivo(archivo: antecedentesJudiciales);

      final List<CertificadoSubido> extra = <CertificadoSubido>[];
      for (final ArchivoLocal archivo in adicionales) {
        extra.add(await _subirArchivo(archivo: archivo));
      }

      await _usuario(userId).set(<String, dynamic>{
        'certificados': <String, dynamic>{
          'carneGuia': carne.toMap(),
          'antecedentesJudiciales': antecedentes.toMap(),
          'adicionales':
              extra.map((CertificadoSubido c) => c.toMap()).toList(),
        },
        'estadoCertificados': 'en_revision',
        'fechaEnvioCertificados': Timestamp.now(),
      }, SetOptions(merge: true));
    } on GuiaServiceException {
      rethrow;
    } on FirebaseException catch (error) {
      throw GuiaServiceException(
        'Los archivos se subieron, pero no se pudo guardar tu perfil. '
        'Inténtalo de nuevo.',
        code: error.code,
      );
    } catch (_) {
      throw const GuiaServiceException(
        'Ocurrió un error inesperado al subir los certificados.',
        code: 'unknown-error',
      );
    }
  }

  /// Marca los certificados como pendientes ("Completar después").
  Future<void> posponerCertificados(String userId) async {
    try {
      await _usuario(userId).set(<String, dynamic>{
        'estadoCertificados': 'pendiente',
      }, SetOptions(merge: true));
    } on FirebaseException catch (error) {
      throw GuiaServiceException(
        'No se pudo guardar el cambio. Inténtalo de nuevo.',
        code: error.code,
      );
    }
  }

  /// Guarda el perfil laboral y deja la cuenta lista para revisión.
  Future<void> guardarPerfilLaboral({
    required String userId,
    required PerfilLaboral perfil,
  }) async {
    try {
      await _usuario(userId).set(<String, dynamic>{
        'perfilLaboral': perfil.toMap(),
        'perfilCompleto': true,
        'estado': 'pendiente_aprobacion',
        'fechaPerfilLaboral': Timestamp.now(),
      }, SetOptions(merge: true));
    } on FirebaseException catch (error) {
      throw GuiaServiceException(
        'No se pudo guardar tu perfil. Inténtalo de nuevo.',
        code: error.code,
      );
    } catch (_) {
      throw const GuiaServiceException(
        'Ocurrió un error inesperado al guardar tu perfil.',
        code: 'unknown-error',
      );
    }
  }


    /// Consulta los guías cuyos certificados están pendientes de revisión.
  Future<List<Map<String, dynamic>>> obtenerSolicitudesPendientes() async {
    try {
      final QuerySnapshot<Map<String, dynamic>> resultado =
          await _firestore
              .collection('usuarios')
              .where('estadoCertificados', isEqualTo: 'en_revision')
              .get();

      return resultado.docs.map((documento) {
        return <String, dynamic>{
          'uid': documento.id,
          ...documento.data(),
        };
      }).toList();
    } on FirebaseException catch (error) {
      throw GuiaServiceException(
        'No se pudieron consultar las solicitudes de guías.',
        code: error.code,
      );
    }
  }

    /// Aprueba los certificados de un guía después de revisarlos.
  Future<void> aprobarSolicitud(String userId) async {
    try {
      final DocumentReference<Map<String, dynamic>> referencia =
          _usuario(userId);

      await _firestore.runTransaction((transaccion) async {
        final DocumentSnapshot<Map<String, dynamic>> documento =
            await transaccion.get(referencia);

        if (!documento.exists) {
          throw const GuiaServiceException(
            'No se encontró la solicitud del guía.',
            code: 'solicitud-no-encontrada',
          );
        }

        final String estado =
            documento.data()?['estadoCertificados'] as String? ?? 'pendiente';

        if (estado != 'en_revision') {
          throw const GuiaServiceException(
            'La solicitud no está pendiente de revisión.',
            code: 'estado-invalido',
          );
        }

        transaccion.set(
  referencia,
  <String, dynamic>{
    'rol': 'Guía turístico',
    'estadoCertificados': 'aprobado',
    'fechaRevisionCertificados': FieldValue.serverTimestamp(),
    'motivoRechazoCertificados': null,
  },
  SetOptions(merge: true),
);
      });

      await _notificacionService.crearNotificacion(
        usuarioId: userId,
        titulo: '¡Certificados aprobados!',
        mensaje: 'Tus certificados fueron aprobados. Ya tienes el rol de guía turístico.',
        tipo: 'aprobacion',
      );
    } on GuiaServiceException {
      rethrow;
    } on FirebaseException catch (error) {
      throw GuiaServiceException(
        'No se pudo aprobar la solicitud del guía.',
        code: error.code,
      );
    }
  }
    /// Rechaza una solicitud indicando el motivo de la decisión.
  Future<void> rechazarSolicitud({
    required String userId,
    required String motivo,
  }) async {
    final String motivoLimpio = motivo.trim();

    if (motivoLimpio.isEmpty) {
      throw const GuiaServiceException(
        'Debes indicar el motivo del rechazo.',
        code: 'motivo-vacio',
      );
    }

    try {
      final DocumentReference<Map<String, dynamic>> referencia =
          _usuario(userId);

      await _firestore.runTransaction((transaccion) async {
        final DocumentSnapshot<Map<String, dynamic>> documento =
            await transaccion.get(referencia);

        if (!documento.exists) {
          throw const GuiaServiceException(
            'No se encontró la solicitud del guía.',
            code: 'solicitud-no-encontrada',
          );
        }

        final String estado =
            documento.data()?['estadoCertificados'] as String? ?? 'pendiente';

        if (estado != 'en_revision') {
          throw const GuiaServiceException(
            'La solicitud no está pendiente de revisión.',
            code: 'estado-invalido',
          );
        }

        transaccion.set(
          referencia,
          <String, dynamic>{
            'estadoCertificados': 'rechazado',
            'motivoRechazoCertificados': motivoLimpio,
            'fechaRevisionCertificados': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      });

      await _notificacionService.crearNotificacion(
        usuarioId: userId,
        titulo: 'Solicitud rechazada',
        mensaje: 'El administrador rechazó tus certificados. Motivo: $motivoLimpio',
        tipo: 'rechazo',
      );
    } on GuiaServiceException {
      rethrow;
    } on FirebaseException catch (error) {
      throw GuiaServiceException(
        'No se pudo rechazar la solicitud del guía.',
        code: error.code,
      );
    }
  }
    /// Devuelve los documentos para que el guía pueda corregirlos y reenviarlos.
  Future<void> solicitarCorrecciones({
    required String userId,
    required String motivo,
  }) async {
    final String motivoLimpio = motivo.trim();

    if (motivoLimpio.isEmpty) {
      throw const GuiaServiceException(
        'Debes indicar qué documentos debe corregir el guía.',
        code: 'motivo-vacio',
      );
    }

    try {
      final DocumentReference<Map<String, dynamic>> referencia =
          _usuario(userId);

      await _firestore.runTransaction((transaccion) async {
        final DocumentSnapshot<Map<String, dynamic>> documento =
            await transaccion.get(referencia);

        if (!documento.exists) {
          throw const GuiaServiceException(
            'No se encontró la solicitud del guía.',
            code: 'solicitud-no-encontrada',
          );
        }

        final String estado =
            documento.data()?['estadoCertificados'] as String? ?? 'pendiente';

        if (estado != 'en_revision' &&
            estado != 'aprobado' &&
            estado != 'rechazado') {
          throw const GuiaServiceException(
            'No se pueden solicitar correcciones en el estado actual.',
            code: 'estado-invalido',
          );
        }

        transaccion.set(
          referencia,
          <String, dynamic>{
            'estadoCertificados': 'requiere_correcciones',
            'motivoRechazoCertificados': motivoLimpio,
            'fechaRevisionCertificados': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      });

      await _notificacionService.crearNotificacion(
        usuarioId: userId,
        titulo: 'Debes corregir tus documentos',
        mensaje: 'El administrador solicita estos cambios: $motivoLimpio',
        tipo: 'correcciones',
      );
    } on GuiaServiceException {
      rethrow;
    } on FirebaseException catch (error) {
      throw GuiaServiceException(
        'No se pudieron solicitar las correcciones.',
        code: error.code,
      );
    }
  }


  /// Devuelve los certificados a revisión y notifica al guía.
  Future<void> revertirAprobacion(String userId) async {
    try {
      final DocumentReference<Map<String, dynamic>> referencia =
          _usuario(userId);

      await _firestore.runTransaction((transaccion) async {
        final documento = await transaccion.get(referencia);

        if (!documento.exists) {
          throw const GuiaServiceException(
            'No se encontró la solicitud del guía.',
            code: 'solicitud-no-encontrada',
          );
        }

        final estado =
            documento.data()?['estadoCertificados'] as String? ?? 'pendiente';

        if (estado != 'aprobado') {
          throw const GuiaServiceException(
            'Solo se puede revertir una solicitud aprobada.',
            code: 'estado-invalido',
          );
        }

        transaccion.set(
          referencia,
          <String, dynamic>{
            'estadoCertificados': 'en_revision',
            'fechaRevisionCertificados': FieldValue.serverTimestamp(),
            'motivoRechazoCertificados': FieldValue.delete(),
          },
          SetOptions(merge: true),
        );
      });

      await _notificacionService.crearNotificacion(
        usuarioId: userId,
        titulo: 'Certificados en revisión',
        mensaje: 'La aprobación de tus certificados fue revertida y tu solicitud volvió a revisión.',
        tipo: 'reversion',
      );
    } on GuiaServiceException {
      rethrow;
    } on FirebaseException catch (error) {
      throw GuiaServiceException(
        'No se pudo revertir la aprobación.',
        code: error.code,
      );
    }
  }
}
