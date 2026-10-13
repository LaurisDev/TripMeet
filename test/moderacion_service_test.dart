import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tripmeet/moderacion_service.dart';

Matcher _fallaModeracion(String codigo) => throwsA(
  isA<ModeracionException>().having(
    (ModeracionException e) => e.code,
    'code',
    codigo,
  ),
);

void main() {
  group('FiltroLocalOfensivo', () {
    const FiltroLocalOfensivo filtro = FiltroLocalOfensivo();

    for (final String ofensivo in <String>[
      'Es un malparido',
      'qué gonorrea de persona',
      'IDIOTA total',
      'eres un estúpido',
      'eres un estupido', // sin tilde
      'Puuuuta vida', // letras repetidas
      'p4ndejo no, pend3jo', // números en lugar de letras
      'una m!erda... no: una mierda',
      'son unos idiotas', // plural
      'what a bitch',
      'hp', // abreviatura común en Colombia
    ]) {
      test('bloquea "$ofensivo"', () async {
        expect(await filtro.esAceptable(ofensivo), isFalse);
      });
    }

    for (final String aceptable in <String>[
      'Muy buena compañía, puntual y amable.',
      'Excelente guía, nos explicó todo con paciencia.',
      'No fue puntual, pero la caminata estuvo bien.',
      'La computadora del hostal no servía', // contiene "puta" dentro
      'Hubo una disputa por el precio', // contiene "puta" dentro
      'Ñoño pero buena gente',
      'Recomendado 100%',
    ]) {
      test('permite "$aceptable"', () async {
        expect(await filtro.esAceptable(aceptable), isTrue);
      });
    }

    test('normalizar quita tildes, sustituciones y letras repetidas', () {
      expect(FiltroLocalOfensivo.normalizar('IdIooOta'), 'idiota');
      expect(FiltroLocalOfensivo.normalizar('3stúp1d0'), 'estupido');
      expect(FiltroLocalOfensivo.normalizar('m@ld1t0'), 'maldito');
    });
  });

  group('ModeracionRemota (backend preparado)', () {
    final Uri endpoint = Uri.parse(
      'https://backend.ejemplo/api/moderateComment',
    );

    ModeracionRemota remota(
      Future<http.Response> Function(http.Request peticion) responder, {
      Duration tiempoMaximo = const Duration(seconds: 10),
    }) => ModeracionRemota(
      endpoint: endpoint,
      client: MockClient(responder),
      tiempoMaximo: tiempoMaximo,
    );

    test('envía solo el texto y respeta "allowed": true', () async {
      http.Request? enviada;
      final ModeracionRemota moderador = remota((http.Request p) async {
        enviada = p;
        return http.Response(jsonEncode(<String, bool>{'allowed': true}), 200);
      });

      expect(await moderador.esAceptable('Muy amable'), isTrue);
      expect(enviada?.method, 'POST');
      expect(enviada?.url, endpoint);
      expect(jsonDecode(enviada!.body), <String, String>{'text': 'Muy amable'});
    });

    test('"allowed": false bloquea', () async {
      final ModeracionRemota moderador = remota(
        (_) async =>
            http.Response(jsonEncode(<String, bool>{'allowed': false}), 200),
      );

      expect(await moderador.esAceptable('texto'), isFalse);
    });

    for (final (String caso, http.Response respuesta, String codigo)
        in <(String, http.Response, String)>[
          ('404 (endpoint inexistente)', http.Response('', 404), 'http-404'),
          ('500', http.Response('error', 500), 'http-500'),
          (
            'JSON inválido',
            http.Response('no es json', 200),
            'respuesta-invalida',
          ),
          (
            'sin el campo allowed',
            http.Response(jsonEncode(<String, String>{'ok': 'si'}), 200),
            'respuesta-invalida',
          ),
          (
            'allowed que no es booleano',
            http.Response(jsonEncode(<String, String>{'allowed': 'true'}), 200),
            'respuesta-invalida',
          ),
        ]) {
      test('$caso es una falla, no una aprobación', () async {
        await expectLater(
          remota((_) async => respuesta).esAceptable('texto'),
          _fallaModeracion(codigo),
        );
      });
    }

    test('sin conexión es una falla', () async {
      await expectLater(
        remota((_) async => throw http.ClientException('sin red'))
            .esAceptable('texto'),
        _fallaModeracion('sin-conexion'),
      );
    });

    test('si tarda demasiado es una falla', () async {
      final Completer<http.Response> nunca = Completer<http.Response>();
      await expectLater(
        remota(
          (_) => nunca.future,
          tiempoMaximo: const Duration(milliseconds: 50),
        ).esAceptable('texto'),
        _fallaModeracion('timeout'),
      );
    });

    test('no envía el comentario a un endpoint sin HTTPS', () async {
      bool llamado = false;
      final ModeracionRemota moderador = ModeracionRemota(
        endpoint: Uri.parse('http://backend.ejemplo/api/moderateComment'),
        client: MockClient((_) async {
          llamado = true;
          return http.Response('{"allowed":true}', 200);
        }),
      );

      await expectLater(
        moderador.esAceptable('texto'),
        _fallaModeracion('endpoint-inseguro'),
      );
      expect(llamado, isFalse);
    });

    test('el error no incluye el texto del comentario', () async {
      try {
        await remota((_) async => http.Response('', 503))
            .esAceptable('comentario privado');
        fail('debió fallar');
      } on ModeracionException catch (error) {
        expect(error.toString(), isNot(contains('comentario privado')));
      }
    });
  });

  group('ModeracionCombinada', () {
    test('si el filtro local bloquea, no se envía al backend', () async {
      bool remotoLlamado = false;
      final ModeracionCombinada moderador = ModeracionCombinada(
        <ModeradorComentarios>[
          const FiltroLocalOfensivo(),
          ModeracionRemota(
            endpoint: Uri.parse('https://backend.ejemplo/api/moderateComment'),
            client: MockClient((_) async {
              remotoLlamado = true;
              return http.Response('{"allowed":true}', 200);
            }),
          ),
        ],
      );

      expect(await moderador.esAceptable('eres un idiota'), isFalse);
      expect(remotoLlamado, isFalse);
    });

    test('pasa el local y el backend decide', () async {
      final ModeracionCombinada moderador = ModeracionCombinada(
        <ModeradorComentarios>[
          const FiltroLocalOfensivo(),
          ModeracionRemota(
            endpoint: Uri.parse('https://backend.ejemplo/api/moderateComment'),
            client: MockClient(
              (_) async => http.Response('{"allowed":false}', 200),
            ),
          ),
        ],
      );

      expect(await moderador.esAceptable('Texto sutilmente hostil'), isFalse);
    });

    test('si el backend falla, la falla se propaga', () async {
      final ModeracionCombinada moderador = ModeracionCombinada(
        <ModeradorComentarios>[
          const FiltroLocalOfensivo(),
          ModeracionRemota(
            endpoint: Uri.parse('https://backend.ejemplo/api/moderateComment'),
            client: MockClient((_) async => http.Response('', 404)),
          ),
        ],
      );

      await expectLater(
        moderador.esAceptable('Muy amable'),
        _fallaModeracion('http-404'),
      );
    });
  });

  test('sin endpoint configurado, el moderador por defecto es solo el filtro '
      'local', () {
    expect(endpointModeracion, isNull);
    expect(moderadorPorDefecto(), isA<FiltroLocalOfensivo>());
  });
}
