import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Recomendación de un lugar turístico generada por IA.
class PlaceRecommendation {
  const PlaceRecommendation({
    required this.nombre,
    required this.descripcion,
    required this.motivoRecomendacion,
  });

  final String nombre;
  final String descripcion;
  final String motivoRecomendacion;

  factory PlaceRecommendation.fromJson(Map<String, dynamic> json) {
    return PlaceRecommendation(
      nombre: json['nombre'] as String? ?? '',
      descripcion: json['descripcion'] as String? ?? '',
      motivoRecomendacion: json['motivoRecomendacion'] as String? ?? '',
    );
  }
}

/// Excepción de dominio con un mensaje seguro para mostrar en la interfaz.
class AiRecommendationException implements Exception {
  const AiRecommendationException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

/// Consulta al backend de IA (Vercel) que recomienda lugares turísticos
/// según los intereses y preferencias del usuario.
class AiRecommendationService {
  AiRecommendationService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  Uri get _endpoint => Uri.parse(
        'https://tripmeet-ai-backend-repo.vercel.app/api/recommendPlaces',
      );

  /// Pide recomendaciones de lugares turísticos según [intereses] y,
  /// opcionalmente, [preferenciasAdicionales].
  ///
  /// Lanza [AiRecommendationException] con un mensaje listo para mostrar en
  /// la UI si falla la conexión, se agota el tiempo de espera o el servidor
  /// responde con un error.
  Future<List<PlaceRecommendation>> obtenerRecomendaciones({
    required List<String> intereses,
    String? preferenciasAdicionales,
  }) async {
    if (intereses.isEmpty) {
      throw const AiRecommendationException(
        'Indica al menos un interés para obtener recomendaciones.',
        code: 'sin-intereses',
      );
    }

    http.Response respuesta;
    try {
      respuesta = await _client
          .post(
            _endpoint,
            headers: const <String, String>{
              'Content-Type': 'application/json',
            },
            body: jsonEncode(<String, dynamic>{
              'interests': intereses,
              if (preferenciasAdicionales != null &&
                  preferenciasAdicionales.trim().isNotEmpty)
                'additionalPreferences': preferenciasAdicionales.trim(),
            }),
          )
          .timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw const AiRecommendationException(
        'La solicitud tardó demasiado. Revisa tu conexión e inténtalo de nuevo.',
        code: 'timeout',
      );
    } catch (_) {
      // Cubre SocketException, fallas de DNS/TLS y errores de red en Web,
      // sin acoplarse a dart:io (que no existe al compilar para Web).
      throw const AiRecommendationException(
        'No hay conexión a Internet o no se pudo contactar el servidor. '
        'Inténtalo de nuevo.',
        code: 'sin-conexion',
      );
    }

    Map<String, dynamic>? datos;
    try {
      datos = jsonDecode(respuesta.body) as Map<String, dynamic>;
    } catch (_) {
      datos = null;
    }

    if (respuesta.statusCode != 200) {
      throw AiRecommendationException(
        _mensajeDeError(respuesta.statusCode, datos),
        code: 'http-${respuesta.statusCode}',
      );
    }

    final List<dynamic>? recomendaciones =
        datos?['recommendations'] as List<dynamic>?;
    if (datos == null || recomendaciones == null) {
      throw const AiRecommendationException(
        'El servidor no devolvió recomendaciones válidas.',
        code: 'respuesta-invalida',
      );
    }

    return recomendaciones
        .whereType<Map<String, dynamic>>()
        .map(PlaceRecommendation.fromJson)
        .toList();
  }

  String _mensajeDeError(int statusCode, Map<String, dynamic>? datos) {
    final String? error = datos?['error'] as String?;
    if (error != null && error.trim().isNotEmpty) {
      return error;
    }
    switch (statusCode) {
      case 400:
        return 'La solicitud tiene datos inválidos. Revisa tus intereses.';
      case 502:
      case 504:
        return 'El servicio de recomendaciones no está disponible en este momento. Inténtalo de nuevo.';
      default:
        return 'Ocurrió un error al obtener recomendaciones (código $statusCode).';
    }
  }

  /// Libera la conexión HTTP subyacente. Llamar cuando el servicio ya no se
  /// use (por ejemplo, en `dispose()` del widget que lo creó).
  void dispose() => _client.close();
}
