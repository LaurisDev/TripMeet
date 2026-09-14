import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

/// Resultado de una subida exitosa a Cloudinary.
class CloudinarySubida {
  const CloudinarySubida({
    required this.secureUrl,
    required this.publicId,
    required this.bytes,
    required this.formato,
  });

  /// URL segura (https) del archivo, lista para guardarse en Firestore.
  final String secureUrl;

  /// Identificador del recurso en Cloudinary (útil para borrarlo después).
  final String publicId;
  final int bytes;
  final String formato;
}

/// Excepción de dominio con un mensaje seguro para mostrar en la interfaz.
class CloudinaryException implements Exception {
  const CloudinaryException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

/// Sube archivos PDF a Cloudinary mediante un *unsigned upload preset*
/// (no requiere API key/secret en el cliente).
///
/// Cloudinary trata los PDF como `resource_type: image` (con `format: pdf`),
/// así que se suben al mismo endpoint que una imagen:
/// `https://api.cloudinary.com/v1_1/{cloud_name}/image/upload`.
class CloudinaryService {
  CloudinaryService({
    this.cloudName = 'pncvlky3',
    this.uploadPreset = 'TripMeet',
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String cloudName;
  final String uploadPreset;
  final http.Client _client;

  Uri get _endpointSubida =>
      Uri.https('api.cloudinary.com', '/v1_1/$cloudName/image/upload');

  /// Sube [bytes] (debe corresponder a un archivo `.pdf`) con nombre
  /// [nombreArchivo] y devuelve la URL segura generada por Cloudinary.
  ///
  /// Lanza [CloudinaryException] con un mensaje listo para mostrar en la UI
  /// si el archivo no es PDF, si falla la conexión o si Cloudinary rechaza
  /// la subida.
  Future<CloudinarySubida> subirPdf({
    required Uint8List bytes,
    required String nombreArchivo,
  }) async {
    if (!nombreArchivo.toLowerCase().trim().endsWith('.pdf')) {
      throw const CloudinaryException(
        'Solo se permiten archivos en formato PDF.',
        code: 'formato-invalido',
      );
    }
    if (bytes.isEmpty) {
      throw const CloudinaryException(
        'El archivo seleccionado está vacío.',
        code: 'archivo-vacio',
      );
    }

    final http.MultipartRequest peticion =
        http.MultipartRequest('POST', _endpointSubida)
          ..fields['upload_preset'] = uploadPreset
          ..files.add(
            http.MultipartFile.fromBytes(
              'file',
              bytes,
              filename: nombreArchivo,
              contentType: MediaType('application', 'pdf'),
            ),
          );

    http.StreamedResponse enviada;
    try {
      enviada = await _client
          .send(peticion)
          .timeout(const Duration(seconds: 45));
    } on TimeoutException {
      throw const CloudinaryException(
        'La subida tardó demasiado. Revisa tu conexión e inténtalo de nuevo.',
        code: 'timeout',
      );
    } catch (_) {
      // Cubre SocketException, fallas de DNS/TLS y errores de red en Web,
      // sin acoplarse a dart:io (que no existe al compilar para Web).
      throw const CloudinaryException(
        'No hay conexión a Internet o no se pudo contactar el servidor. '
        'Inténtalo de nuevo.',
        code: 'sin-conexion',
      );
    }

    final http.Response respuesta = await http.Response.fromStream(enviada);

    Map<String, dynamic>? datos;
    try {
      datos = jsonDecode(respuesta.body) as Map<String, dynamic>;
    } catch (_) {
      datos = null;
    }

    if (respuesta.statusCode != 200) {
      throw CloudinaryException(
        _mensajeDeError(respuesta.statusCode, datos),
        code: 'http-${respuesta.statusCode}',
      );
    }

    final String? secureUrl = datos?['secure_url'] as String?;
    final String? publicId = datos?['public_id'] as String?;
    if (datos == null || secureUrl == null || publicId == null) {
      throw const CloudinaryException(
        'Cloudinary no devolvió un enlace válido para el archivo.',
        code: 'respuesta-invalida',
      );
    }

    return CloudinarySubida(
      secureUrl: secureUrl,
      publicId: publicId,
      bytes: (datos['bytes'] as num?)?.toInt() ?? bytes.length,
      formato: (datos['format'] as String?) ?? 'pdf',
    );
  }

  String _mensajeDeError(int statusCode, Map<String, dynamic>? datos) {
    final dynamic error = datos?['error'];
    if (error is Map && error['message'] is String) {
      return 'No se pudo subir el archivo: ${error['message']}';
    }
    return 'No se pudo subir el archivo (código $statusCode). Inténtalo de nuevo.';
  }

  /// Libera la conexión HTTP subyacente. Llamar cuando el servicio ya no se
  /// use (por ejemplo, en `dispose()` del widget que lo creó).
  void dispose() => _client.close();
}
