import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Endpoint de moderación del backend de TripMeet (Vercel).
///
/// **No está configurado:** ese backend aún no tiene una ruta de moderación
/// (a la fecha, `/api/moderateComment` responde 404). Mientras sea `null`,
/// solo se usa el [FiltroLocalOfensivo]. Para activar la moderación remota,
/// hay que implementar en el backend el contrato de [ModeracionRemota] y
/// poner aquí su URL, por ejemplo:
/// `'https://tripmeet-ai-backend-repo.vercel.app/api/moderateComment'`.
const String? endpointModeracion = null;

/// Falla técnica al moderar (sin conexión, tiempo agotado, respuesta
/// inválida...). Nunca debe tratarse como "comentario aceptable".
class ModeracionException implements Exception {
  const ModeracionException(this.code);

  final String code;

  // Intencionalmente no incluye el texto moderado.
  @override
  String toString() => 'ModeracionException($code)';
}

/// Revisa si un comentario puede publicarse.
abstract interface class ModeradorComentarios {
  /// `true` si [texto] puede publicarse; `false` si es ofensivo o incumple
  /// las reglas. Lanza [ModeracionException] si no se pudo revisar.
  Future<bool> esAceptable(String texto);
}

/// Moderador por defecto: el filtro local y, si [endpointModeracion] está
/// configurado, además la moderación remota del backend.
ModeradorComentarios moderadorPorDefecto() {
  final String? endpoint = endpointModeracion;
  if (endpoint == null) return const FiltroLocalOfensivo();
  return ModeracionCombinada(<ModeradorComentarios>[
    const FiltroLocalOfensivo(),
    ModeracionRemota(endpoint: Uri.parse(endpoint)),
  ]);
}

/// Primera barrera, sin red ni claves: busca insultos y groserías comunes en
/// español (incluidos modismos colombianos) e inglés.
///
/// Antes de comparar, normaliza cada palabra (minúsculas, sin tildes,
/// sustituciones como `4`→`a` o `@`→`a`, y letras repetidas como
/// `puuuta`→`puta`), así detecta variantes simples. Es limitado: no entiende
/// contexto, ni insultos sin groserías, ni palabras separadas con símbolos
/// (`p*ta`). Por eso conviene complementarlo con [ModeracionRemota].
class FiltroLocalOfensivo implements ModeradorComentarios {
  const FiltroLocalOfensivo();

  /// Palabras bloqueadas, ya normalizadas con [normalizar].
  static final Set<String> _bloqueadas = <String>{
    for (final String palabra in _listaBase) normalizar(palabra),
  };

  static const List<String> _listaBase = <String>[
    // Español (incluye modismos colombianos).
    'hijueputa', 'hijoeputa', 'hijodeputa', 'hp', 'jueputa', 'malparido',
    'malparida', 'gonorrea', 'puta', 'puto', 'mierda', 'marica', 'maricón',
    'pirobo', 'piroba', 'careverga', 'carechimba', 'verga', 'guisa', 'zunga',
    'imbécil', 'idiota', 'estúpido', 'estúpida', 'pendejo', 'pendeja',
    'cabrón', 'cabrona', 'perra', 'malnacido', 'malnacida', 'basura',
    'asqueroso', 'asquerosa', 'tarado', 'tarada', 'retrasado', 'retrasada',
    'mongólico', 'subnormal',
    // Inglés.
    'fuck', 'fucking', 'shit', 'bitch', 'asshole', 'bastard', 'dick',
    'cunt', 'motherfucker', 'retard',
  ];

  static const Map<String, String> _equivalencias = <String, String>{
    'á': 'a',
    'é': 'e',
    'í': 'i',
    'ó': 'o',
    'ú': 'u',
    'ü': 'u',
    'ñ': 'n',
    '0': 'o',
    '1': 'i',
    '3': 'e',
    '4': 'a',
    '5': 's',
    '7': 't',
    '@': 'a',
    r'$': 's',
  };

  /// Minúsculas, sin tildes, sustituciones de números/símbolos y sin letras
  /// repetidas seguidas.
  static String normalizar(String palabra) {
    final StringBuffer salida = StringBuffer();
    String? anterior;
    for (final String c in palabra.toLowerCase().split('')) {
      final String letra = _equivalencias[c] ?? c;
      if (letra != anterior) salida.write(letra);
      anterior = letra;
    }
    return salida.toString();
  }

  @override
  Future<bool> esAceptable(String texto) async {
    // Palabras: letras y los símbolos que se usan para disfrazarlas.
    final Iterable<String> palabras = RegExp(r'[a-zA-Z0-9@$áéíóúüñÁÉÍÓÚÜÑ]+')
        .allMatches(texto)
        .map((RegExpMatch m) => normalizar(m[0]!));

    for (final String palabra in palabras) {
      if (_bloqueadas.contains(palabra)) return false;
      // Plurales simples: "putas", "idiotas", "pendejos"...
      if (palabra.endsWith('s') &&
          _bloqueadas.contains(palabra.substring(0, palabra.length - 1))) {
        return false;
      }
    }
    return true;
  }
}

/// Moderación en el backend de TripMeet. **Preparada pero no activa**: el
/// endpoint aún no existe (ver [endpointModeracion]).
///
/// Contrato esperado:
///
/// - `POST {endpoint}` con `Content-Type: application/json` y cuerpo
///   `{"text": "<comentario>"}`;
/// - responde `200` con `{"allowed": true}` o `{"allowed": false}`.
///
/// Cualquier otra respuesta (otro código, JSON inválido, sin `allowed`),
/// un error de red o más de [tiempoMaximo] se trata como falla
/// ([ModeracionException]), nunca como aprobación. El texto solo viaja al
/// endpoint por HTTPS; no se registra en logs ni en los errores.
class ModeracionRemota implements ModeradorComentarios {
  ModeracionRemota({
    required this.endpoint,
    http.Client? client,
    this.tiempoMaximo = const Duration(seconds: 10),
  }) : _client = client ?? http.Client();

  final Uri endpoint;
  final Duration tiempoMaximo;
  final http.Client _client;

  @override
  Future<bool> esAceptable(String texto) async {
    if (endpoint.scheme != 'https') {
      throw const ModeracionException('endpoint-inseguro');
    }

    final http.Response respuesta;
    try {
      respuesta = await _client
          .post(
            endpoint,
            headers: const <String, String>{'Content-Type': 'application/json'},
            body: jsonEncode(<String, String>{'text': texto}),
          )
          .timeout(tiempoMaximo);
    } on TimeoutException {
      throw const ModeracionException('timeout');
    } catch (_) {
      throw const ModeracionException('sin-conexion');
    }

    if (respuesta.statusCode != 200) {
      throw ModeracionException('http-${respuesta.statusCode}');
    }
    try {
      final dynamic datos = jsonDecode(respuesta.body);
      final dynamic permitido = datos is Map ? datos['allowed'] : null;
      if (permitido is bool) return permitido;
    } catch (_) {
      // Se trata abajo como respuesta inválida.
    }
    throw const ModeracionException('respuesta-invalida');
  }
}

/// Aplica varios moderadores en orden: el comentario es aceptable solo si
/// todos lo aceptan. Se detiene en el primero que lo rechaza (así un
/// comentario bloqueado por el filtro local no se envía al backend) y
/// propaga cualquier falla.
class ModeracionCombinada implements ModeradorComentarios {
  const ModeracionCombinada(this.moderadores);

  final List<ModeradorComentarios> moderadores;

  @override
  Future<bool> esAceptable(String texto) async {
    for (final ModeradorComentarios moderador in moderadores) {
      if (!await moderador.esAceptable(texto)) return false;
    }
    return true;
  }
}
