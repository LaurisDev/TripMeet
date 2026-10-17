import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mock_exceptions/mock_exceptions.dart';
import 'package:tripmeet/calificacion_usuario_service.dart';
import 'package:tripmeet/evento_detalle_screen.dart';
import 'package:tripmeet/evento_service.dart';
import 'package:tripmeet/lugares_service.dart';
import 'package:tripmeet/moderacion_service.dart';
import 'package:tripmeet/perfil_usuario_screen.dart';
import 'package:tripmeet/publicacion_service.dart';

final DateTime _ahora = DateTime(2026, 10, 12, 12);

Matcher _lanzaCodigo(String codigo) => throwsA(
  isA<CalificacionException>().having(
    (CalificacionException e) => e.code,
    'code',
    codigo,
  ),
);

void main() {
  group('CalificacionUsuarioService (Firestore simulado)', () {
    late FakeFirebaseFirestore firestore;

    CalificacionUsuarioService servicio({
      String? uid = 'ana',
      DateTime? reloj,
      ModeradorComentarios? moderador,
    }) => CalificacionUsuarioService(
      auth: MockFirebaseAuth(
        signedIn: uid != null,
        mockUser: MockUser(uid: uid ?? 'sin-sesion'),
      ),
      firestore: firestore,
      reloj: () => reloj ?? _ahora,
      moderador: moderador,
    );

    Future<void> guardarEvento({
      String id = 'ev',
      DateTime? fechaHora,
      List<String> inscritos = const <String>['ana', 'luis'],
    }) => firestore.collection('eventos').doc(id).set(<String, dynamic>{
      'id': id,
      'creadorUid': 'org',
      'nombre': 'Caminata',
      'lugar': 'Medellín',
      'fechaHora': Timestamp.fromDate(fechaHora ?? DateTime(2026, 10, 1, 8)),
      'fechaCreacion': Timestamp.fromDate(DateTime(2026, 9, 1)),
      'inscritos': inscritos,
    });

    Future<Map<String, dynamic>?> calificacionGuardada(
      String calificado,
      String autor, [
      String evento = 'ev',
    ]) async =>
        (await firestore
                .collection('usuarios')
                .doc(calificado)
                .collection('Reseñas')
                .doc('${autor}_$evento')
                .get())
            .data();

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      for (final String uid in <String>['ana', 'luis', 'org', 'carla']) {
        await firestore.collection('usuarios').doc(uid).set(<String, dynamic>{
          'correo': '$uid@gmail.com',
          'rol': 'Turista',
        });
      }
      await guardarEvento();
    });

    test(
      'guarda la calificación relacionada con evento, autor y calificado',
      () async {
        await servicio().calificarUsuario(
          eventoId: 'ev',
          calificadoUid: 'luis',
          calificacion: 4,
          comentario: 'Muy buena compañía',
        );

        final Map<String, dynamic>? datos = await calificacionGuardada(
          'luis',
          'ana',
        );
        expect(datos?['usuarioId'], 'ana');
        expect(datos?['nombreUsuario'], 'ana');
        expect(datos?['calificacion'], 4);
        expect(datos?['eventoId'], 'ev');
        expect(datos?['fecha'], Timestamp.fromDate(_ahora));
      },
    );

    test('actualiza el promedio del usuario calificado', () async {
      expect(
        (await servicio().obtenerResumen('luis')).tieneCalificaciones,
        isFalse,
      );

      await servicio().calificarUsuario(
        eventoId: 'ev',
        calificadoUid: 'luis',
        calificacion: 4,
        comentario: 'Muy buena compañía',
      );
      ResumenCalificaciones resumen = await servicio().obtenerResumen('luis');
      expect(resumen.promedio, 4);
      expect(resumen.total, 1);

      await servicio(uid: 'org').calificarUsuario(
        eventoId: 'ev',
        calificadoUid: 'luis',
        calificacion: 5,
        comentario: 'Muy buena compañía',
      );
      resumen = await servicio().obtenerResumen('luis');
      expect(resumen.promedio, 4.5);
      expect(resumen.total, 2);
    });

    test('participantes y organizador pueden calificarse entre sí', () async {
      await servicio().calificarUsuario(
        eventoId: 'ev',
        calificadoUid: 'org',
        calificacion: 5,
        comentario: 'Muy buena compañía',
      );
      await servicio(uid: 'org').calificarUsuario(
        eventoId: 'ev',
        calificadoUid: 'ana',
        calificacion: 3,
        comentario: 'Muy buena compañía',
      );

      expect((await servicio().obtenerResumen('org')).total, 1);
      expect((await servicio().obtenerResumen('ana')).total, 1);
    });

    test('no puede calificarse a sí mismo', () async {
      await expectLater(
        servicio().calificarUsuario(
          eventoId: 'ev',
          calificadoUid: 'ana',
          calificacion: 5,
          comentario: 'Muy buena compañía',
        ),
        _lanzaCodigo('auto-calificacion'),
      );
    });

    test('quien no participó no puede calificar', () async {
      await expectLater(
        servicio(uid: 'carla').calificarUsuario(
          eventoId: 'ev',
          calificadoUid: 'luis',
          calificacion: 5,
          comentario: 'Muy buena compañía',
        ),
        _lanzaCodigo('no-participaste'),
      );
      expect(await calificacionGuardada('luis', 'carla'), isNull);
    });

    test('no se puede calificar a alguien que no participó', () async {
      await expectLater(
        servicio().calificarUsuario(
          eventoId: 'ev',
          calificadoUid: 'carla',
          calificacion: 5,
          comentario: 'Muy buena compañía',
        ),
        _lanzaCodigo('no-participo'),
      );
      expect(await calificacionGuardada('carla', 'ana'), isNull);
    });

    test('solo se puede calificar cuando el evento finalizó', () async {
      await guardarEvento(id: 'futuro', fechaHora: DateTime(2026, 10, 20));

      await expectLater(
        servicio().calificarUsuario(
          eventoId: 'futuro',
          calificadoUid: 'luis',
          calificacion: 5,
          comentario: 'Muy buena compañía',
        ),
        _lanzaCodigo('evento-no-finalizado'),
      );
    });

    test('no se puede calificar dos veces a la misma persona por el mismo '
        'evento', () async {
      await servicio().calificarUsuario(
        eventoId: 'ev',
        calificadoUid: 'luis',
        calificacion: 2,
        comentario: 'Muy buena compañía',
      );

      await expectLater(
        servicio().calificarUsuario(
          eventoId: 'ev',
          calificadoUid: 'luis',
          calificacion: 5,
          comentario: 'Muy buena compañía',
        ),
        _lanzaCodigo('ya-calificado'),
      );
      expect((await calificacionGuardada('luis', 'ana'))?['calificacion'], 2);
      expect((await servicio().obtenerResumen('luis')).total, 1);
    });

    test('cerrar y abrir la app no permite calificar de nuevo', () async {
      await servicio().calificarUsuario(
        eventoId: 'ev',
        calificadoUid: 'luis',
        calificacion: 3,
        comentario: 'Muy buena compañía',
      );

      // Un servicio nuevo, como al abrir otra vez la app: la restricción
      // sale de lo guardado en Firestore, no de la memoria.
      final CalificacionUsuarioService reabierto = servicio();
      expect(
        await reabierto.calificadosPorMi(
          eventoId: 'ev',
          candidatos: <String>['luis'],
        ),
        <String>{'luis'},
      );
      await expectLater(
        reabierto.calificarUsuario(
          eventoId: 'ev',
          calificadoUid: 'luis',
          calificacion: 5,
          comentario: 'Muy buena compañía',
        ),
        _lanzaCodigo('ya-calificado'),
      );
      expect((await calificacionGuardada('luis', 'ana'))?['calificacion'], 3);
    });

    test('por otro evento compartido sí puede volver a calificarla', () async {
      await guardarEvento(id: 'ev2');
      await servicio().calificarUsuario(
        eventoId: 'ev',
        calificadoUid: 'luis',
        calificacion: 2,
        comentario: 'Muy buena compañía',
      );
      await servicio().calificarUsuario(
        eventoId: 'ev2',
        calificadoUid: 'luis',
        calificacion: 4,
        comentario: 'Muy buena compañía',
      );

      final ResumenCalificaciones resumen = await servicio().obtenerResumen(
        'luis',
      );
      expect(resumen.total, 2);
      expect(resumen.promedio, 3);
    });

    for (final int? invalida in <int?>[null, 0, 6, -1]) {
      test('rechaza la calificación $invalida', () async {
        await expectLater(
          servicio().calificarUsuario(
            eventoId: 'ev',
            calificadoUid: 'luis',
            calificacion: invalida,
            comentario: 'Muy buena compañía',
          ),
          _lanzaCodigo('calificacion-invalida'),
        );
        expect(await calificacionGuardada('luis', 'ana'), isNull);
      });
    }

    test('sin sesión no se puede calificar', () async {
      await expectLater(
        servicio(uid: null).calificarUsuario(
          eventoId: 'ev',
          calificadoUid: 'luis',
          calificacion: 5,
          comentario: 'Muy buena compañía',
        ),
        _lanzaCodigo('user-not-authenticated'),
      );
    });

    test('un evento que no existe informa not-found', () async {
      await expectLater(
        servicio().calificarUsuario(
          eventoId: 'no-existe',
          calificadoUid: 'luis',
          calificacion: 5,
          comentario: 'Muy buena compañía',
        ),
        _lanzaCodigo('not-found'),
      );
    });

    test(
      'calificadosPorMi devuelve a quiénes ya calificó en el evento',
      () async {
        await servicio().calificarUsuario(
          eventoId: 'ev',
          calificadoUid: 'luis',
          calificacion: 4,
          comentario: 'Muy buena compañía',
        );

        expect(
          await servicio().calificadosPorMi(
            eventoId: 'ev',
            candidatos: <String>['luis', 'org'],
          ),
          <String>{'luis'},
        );
      },
    );

    test(
      'guarda el comentario sin espacios sobrantes junto a la calificación',
      () async {
        await servicio().calificarUsuario(
          eventoId: 'ev',
          calificadoUid: 'luis',
          calificacion: 5,
          comentario: '   Gran compañero de ruta   ',
        );

        final Map<String, dynamic>? datos = await calificacionGuardada(
          'luis',
          'ana',
        );
        expect(datos?['comentario'], 'Gran compañero de ruta');
        expect(datos?['calificacion'], 5);
        expect(datos?['usuarioId'], 'ana');
        expect(datos?['eventoId'], 'ev');
      },
    );

    for (final String? vacio in <String?>[null, '', '    ', '\n\t ']) {
      test(
        'no publica un comentario vacío (${vacio == null ? 'null' : '"${vacio.replaceAll('\n', r'\n').replaceAll('\t', r'\t')}"'})',
        () async {
          await expectLater(
            servicio().calificarUsuario(
              eventoId: 'ev',
              calificadoUid: 'luis',
              calificacion: 5,
              comentario: vacio,
            ),
            _lanzaCodigo('comentario-invalido'),
          );
          expect(await calificacionGuardada('luis', 'ana'), isNull);
        },
      );
    }

    test('no publica un comentario de más de 500 caracteres', () async {
      await expectLater(
        servicio().calificarUsuario(
          eventoId: 'ev',
          calificadoUid: 'luis',
          calificacion: 5,
          comentario: 'a' * (longitudMaximaComentarioResena + 1),
        ),
        _lanzaCodigo('comentario-invalido'),
      );
    });

    test('obtenerResenas trae autor, calificación, comentario y evento, de la '
        'más reciente a la más antigua', () async {
      await firestore.collection('eventos').doc('ev').update(<String, dynamic>{
        'nombre': 'Caminata al cerro',
      });
      await guardarEvento(id: 'ev2');
      await firestore.collection('eventos').doc('ev2').update(<String, dynamic>{
        'nombre': 'Tour de café',
      });
      await servicio(reloj: DateTime(2026, 10, 10)).calificarUsuario(
        eventoId: 'ev',
        calificadoUid: 'luis',
        calificacion: 4,
        comentario: 'Puntual',
      );
      await servicio(
        uid: 'org',
        reloj: DateTime(2026, 10, 11),
      ).calificarUsuario(
        eventoId: 'ev2',
        calificadoUid: 'luis',
        calificacion: 5,
        comentario: 'Muy amable',
      );

      final List<ResenaRecibida> resenas = await servicio().obtenerResenas(
        'luis',
      );

      expect(resenas.map((ResenaRecibida r) => r.resena.comentario), <String>[
        'Muy amable',
        'Puntual',
      ]);
      expect(resenas.first.resena.usuarioId, 'org');
      expect(resenas.first.resena.nombreUsuario, 'org');
      expect(resenas.first.resena.calificacion, 5);
      expect(resenas.first.nombreEvento, 'Tour de café');
      expect(resenas.last.nombreEvento, 'Caminata al cerro');
    });

    test(
      'si el evento ya no existe, la reseña se muestra sin su nombre',
      () async {
        await servicio().calificarUsuario(
          eventoId: 'ev',
          calificadoUid: 'luis',
          calificacion: 4,
          comentario: 'Puntual',
        );
        await firestore.collection('eventos').doc('ev').delete();

        final ResenaRecibida resena = (await servicio().obtenerResenas('luis'))
            .single;
        expect(resena.nombreEvento, isNull);
        expect(resena.resena.comentario, 'Puntual');
      },
    );

    test('persistencia: al volver a abrir la app siguen la reseña y el '
        'promedio', () async {
      await servicio().calificarUsuario(
        eventoId: 'ev',
        calificadoUid: 'luis',
        calificacion: 4,
        comentario: 'Muy amable',
      );

      // Servicios nuevos (como al reabrir la app) leen todo de Firestore.
      final CalificacionUsuarioService reabierto = servicio(uid: 'carla');
      final ResumenCalificaciones resumen = await reabierto.obtenerResumen(
        'luis',
      );
      final List<ResenaRecibida> resenas = await reabierto.obtenerResenas(
        'luis',
      );

      expect(resumen.promedio, 4);
      expect(resumen.total, 1);
      expect(resenas.single.resena.comentario, 'Muy amable');
      expect(resenas.single.resena.usuarioId, 'ana');
    });

    test('si falla el guardado en Firestore, lo informa y no queda nada '
        'guardado', () async {
      // La transacción empieza leyendo el evento: se hace fallar esa lectura.
      whenCalling(Invocation.method(#get, null))
          .on(firestore.collection('eventos').doc('ev'))
          .thenThrow(
            FirebaseException(plugin: 'firestore', code: 'unavailable'),
          );

      await expectLater(
        servicio().calificarUsuario(
          eventoId: 'ev',
          calificadoUid: 'luis',
          calificacion: 5,
          comentario: 'Muy amable',
        ),
        throwsA(
          isA<CalificacionException>()
              .having(
                (CalificacionException e) => e.code,
                'code',
                'unavailable',
              )
              .having(
                (CalificacionException e) => e.message,
                'message',
                contains('conexión'),
              ),
        ),
      );
      expect(await calificacionGuardada('luis', 'ana'), isNull);
      expect((await servicio().obtenerResumen('luis')).total, 0);
    });

    group('Moderación del comentario', () {
      test(
        'un comentario ofensivo no se publica y se explica por qué',
        () async {
          await expectLater(
            servicio().calificarUsuario(
              eventoId: 'ev',
              calificadoUid: 'luis',
              calificacion: 5,
              comentario: 'Es un malparido',
            ),
            throwsA(
              isA<CalificacionException>()
                  .having(
                    (CalificacionException e) => e.code,
                    'code',
                    'comentario-ofensivo',
                  )
                  .having(
                    (CalificacionException e) => e.message,
                    'message',
                    allOf(contains('modifícalo'), isNot(contains('malparido'))),
                  ),
            ),
          );
          expect(await calificacionGuardada('luis', 'ana'), isNull);
          expect((await servicio().obtenerResumen('luis')).total, 0);
        },
      );

      test(
        'si la moderación falla, no se publica (no cuenta como aprobado)',
        () async {
          await expectLater(
            servicio(moderador: _ModeradorFalso(falla: true)).calificarUsuario(
              eventoId: 'ev',
              calificadoUid: 'luis',
              calificacion: 5,
              comentario: 'Muy amable',
            ),
            _lanzaCodigo('moderacion-no-disponible'),
          );
          expect(await calificacionGuardada('luis', 'ana'), isNull);
        },
      );

      test('si el moderador lo rechaza, no se publica', () async {
        await expectLater(
          servicio(moderador: _ModeradorFalso(acepta: false)).calificarUsuario(
            eventoId: 'ev',
            calificadoUid: 'luis',
            calificacion: 5,
            comentario: 'Texto sutilmente hostil',
          ),
          _lanzaCodigo('comentario-ofensivo'),
        );
        expect(await calificacionGuardada('luis', 'ana'), isNull);
      });

      test('modera el comentario sin espacios sobrantes y, si pasa, publica '
          'con sus estrellas', () async {
        final _ModeradorFalso moderador = _ModeradorFalso();
        await servicio(moderador: moderador).calificarUsuario(
          eventoId: 'ev',
          calificadoUid: 'luis',
          calificacion: 3,
          comentario: '  Muy amable  ',
        );

        expect(moderador.revisados, <String>['Muy amable']);
        final Map<String, dynamic>? datos = await calificacionGuardada(
          'luis',
          'ana',
        );
        expect(datos?['calificacion'], 3);
        expect(datos?['comentario'], 'Muy amable');
      });

      test(
        'no modera si los datos ya son inválidos (no envía texto de más)',
        () async {
          final _ModeradorFalso moderador = _ModeradorFalso();
          await expectLater(
            servicio(moderador: moderador).calificarUsuario(
              eventoId: 'ev',
              calificadoUid: 'luis',
              calificacion: 9,
              comentario: 'Muy amable',
            ),
            _lanzaCodigo('calificacion-invalida'),
          );
          expect(moderador.revisados, isEmpty);
        },
      );
    });

    test('las reseñas de lugares no cambian: sin eventoId no lo guardan', () {
      final Map<String, dynamic> datos = Resena(
        usuarioId: 'ana',
        nombreUsuario: 'ana',
        comentario: 'Lindo lugar',
        calificacion: 5,
        fecha: _ahora,
      ).toFirestore();

      expect(datos.containsKey('eventoId'), isFalse);
    });
  });

  group('Detalle del evento: calificar participantes', () {
    Evento evento({DateTime? fechaHora}) => Evento(
      id: 'ev',
      creadorUid: 'org',
      nombre: 'Caminata',
      lugar: 'Medellín',
      fechaHora: fechaHora ?? DateTime(2020, 1, 1, 8),
      fechaCreacion: DateTime(2019, 12, 1),
      inscritos: const <String>['ana', 'luis'],
    );

    Future<_ServicioFalso> abrir(
      WidgetTester tester, {
      Evento? ev,
      String uid = 'ana',
      Set<String> yaCalificados = const <String>{},
      CalificacionException? error,
    }) async {
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 1.5;
      addTearDown(tester.view.reset);

      final _ServicioFalso servicio = _ServicioFalso(yaCalificados, error);
      await tester.pumpWidget(
        MaterialApp(
          home: EventoDetalleScreen(
            evento: ev ?? evento(),
            uidUsuarioActual: uid,
            servicioCalificaciones: servicio,
            cargarPerfil: (String uid) async => <String, dynamic>{
              'correo': '$uid@gmail.com',
              'rol': 'Turista',
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      return servicio;
    }

    Finder seccion() => find.byKey(const Key('calificar-participantes'));

    testWidgets('en un evento finalizado lista a los demás participantes', (
      WidgetTester tester,
    ) async {
      await abrir(tester);

      expect(seccion(), findsOneWidget);
      expect(find.byKey(const Key('calificar-org')), findsOneWidget);
      expect(find.byKey(const Key('calificar-luis')), findsOneWidget);
      expect(
        find.byKey(const Key('calificar-ana')),
        findsNothing,
        reason: 'no puede calificarse a sí mismo',
      );
    });

    testWidgets('si el evento no ha finalizado no ofrece calificar', (
      WidgetTester tester,
    ) async {
      await abrir(tester, ev: evento(fechaHora: DateTime(2100)));

      expect(seccion(), findsNothing);
    });

    testWidgets('quien no participó no puede calificar', (
      WidgetTester tester,
    ) async {
      await abrir(tester, uid: 'carla');

      expect(seccion(), findsNothing);
    });

    testWidgets('califica con estrellas, confirma y marca como calificado', (
      WidgetTester tester,
    ) async {
      final _ServicioFalso servicio = await abrir(tester);

      await tester.ensureVisible(find.byKey(const Key('calificar-luis')));
      await tester.tap(find.byKey(const Key('calificar-luis')));
      await tester.pumpAndSettle();

      expect(find.text('Reseña para luis'), findsOneWidget);
      final Finder confirmar = find.byKey(const Key('publicar-resena'));
      expect(
        tester.widget<FilledButton>(confirmar).onPressed,
        isNull,
        reason: 'hay que elegir estrellas primero',
      );

      expect(
        find.byKey(const Key('comentario-resena')),
        findsNothing,
        reason: 'el comentario aparece después de elegir estrellas',
      );
      await tester.tap(find.byKey(const Key('estrella-4')));
      await tester.pump();
      expect(tester.widget<FilledButton>(confirmar).onPressed, isNull);
      await tester.enterText(
        find.byKey(const Key('comentario-resena')),
        '  Muy puntual y amable  ',
      );
      await tester.pump();
      await tester.tap(confirmar);
      await tester.pumpAndSettle();

      expect(servicio.calificaciones, <(String, int, String)>[
        ('luis', 4, 'Muy puntual y amable'),
      ]);
      expect(find.text('Publicaste tu reseña sobre luis.'), findsOneWidget);
      expect(find.byKey(const Key('calificado-luis')), findsOneWidget);
      expect(find.byKey(const Key('calificar-luis')), findsNothing);
    });

    testWidgets('no permite publicar un comentario solo con espacios', (
      WidgetTester tester,
    ) async {
      final _ServicioFalso servicio = await abrir(tester);

      await tester.ensureVisible(find.byKey(const Key('calificar-luis')));
      await tester.tap(find.byKey(const Key('calificar-luis')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('estrella-3')));
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('comentario-resena')),
        '    ',
      );
      await tester.pump();

      final Finder publicar = find.byKey(const Key('publicar-resena'));
      expect(tester.widget<FilledButton>(publicar).onPressed, isNull);
      await tester.tap(publicar);
      await tester.pumpAndSettle();
      expect(servicio.calificaciones, isEmpty);
    });

    testWidgets('si falla, no la muestra como publicada', (
      WidgetTester tester,
    ) async {
      await abrir(
        tester,
        error: const CalificacionException(
          'No se pudo publicar la reseña. Inténtalo de nuevo.',
          code: 'unknown',
        ),
      );

      await tester.ensureVisible(find.byKey(const Key('calificar-luis')));
      await tester.tap(find.byKey(const Key('calificar-luis')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('estrella-4')));
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('comentario-resena')),
        'Muy amable',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('publicar-resena')));
      await tester.pumpAndSettle();

      expect(
        find.text('No se pudo publicar la reseña. Inténtalo de nuevo.'),
        findsOneWidget,
      );
      expect(find.textContaining('Publicaste'), findsNothing);
      expect(find.byKey(const Key('calificado-luis')), findsNothing);
      expect(find.byKey(const Key('calificar-luis')), findsOneWidget);
    });

    testWidgets('si el comentario es ofensivo, el diálogo sigue abierto con '
        'el texto para corregirlo', (WidgetTester tester) async {
      final _ServicioFalso servicio = await abrir(tester);
      servicio.errores = <CalificacionException?>[
        const CalificacionException(
          'Tu comentario incluye expresiones que no están permitidas en '
          'TripMeet. Por favor, modifícalo para que sea respetuoso e '
          'inténtalo de nuevo.',
          code: 'comentario-ofensivo',
        ),
        null,
      ];

      await tester.ensureVisible(find.byKey(const Key('calificar-luis')));
      await tester.tap(find.byKey(const Key('calificar-luis')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('estrella-2')));
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('comentario-resena')),
        'Comentario a corregir',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('publicar-resena')));
      await tester.pumpAndSettle();

      expect(find.text('Reseña para luis'), findsOneWidget);
      expect(find.byKey(const Key('error-resena')), findsOneWidget);
      expect(find.textContaining('modifícalo'), findsOneWidget);
      expect(find.text('Comentario a corregir'), findsOneWidget);
      expect(find.byKey(const Key('calificado-luis')), findsNothing);

      // Al editar desaparece el aviso; al publicar de nuevo se guarda.
      await tester.enterText(
        find.byKey(const Key('comentario-resena')),
        'No fue muy puntual',
      );
      await tester.pump();
      expect(find.byKey(const Key('error-resena')), findsNothing);
      await tester.tap(find.byKey(const Key('publicar-resena')));
      await tester.pumpAndSettle();

      expect(find.text('Reseña para luis'), findsNothing);
      expect(find.text('Publicaste tu reseña sobre luis.'), findsOneWidget);
      expect(servicio.calificaciones, <(String, int, String)>[
        ('luis', 2, 'No fue muy puntual'),
      ]);
    });

    testWidgets('cancelar el diálogo no califica', (WidgetTester tester) async {
      final _ServicioFalso servicio = await abrir(tester);

      await tester.ensureVisible(find.byKey(const Key('calificar-luis')));
      await tester.tap(find.byKey(const Key('calificar-luis')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(servicio.calificaciones, isEmpty);
      expect(find.byKey(const Key('calificar-luis')), findsOneWidget);
    });

    testWidgets('si el servidor responde que ya lo calificó, lo avisa y lo '
        'marca como calificado', (WidgetTester tester) async {
      await abrir(
        tester,
        error: const CalificacionException(
          'Ya calificaste a esta persona por este evento.',
          code: 'ya-calificado',
        ),
      );

      await tester.ensureVisible(find.byKey(const Key('calificar-luis')));
      await tester.tap(find.byKey(const Key('calificar-luis')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('estrella-5')));
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('comentario-resena')),
        'Excelente',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('publicar-resena')));
      await tester.pumpAndSettle();

      expect(
        find.text('Ya calificaste a esta persona por este evento.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('calificado-luis')), findsOneWidget);
      expect(find.byKey(const Key('calificar-luis')), findsNothing);
    });

    testWidgets('a quien ya calificó lo muestra como calificado', (
      WidgetTester tester,
    ) async {
      await abrir(tester, yaCalificados: <String>{'org'});

      expect(find.byKey(const Key('calificado-org')), findsOneWidget);
      expect(find.byKey(const Key('calificar-luis')), findsOneWidget);
    });

    testWidgets('si falla, muestra el error y permite volver a intentarlo', (
      WidgetTester tester,
    ) async {
      await abrir(
        tester,
        error: const CalificacionException(
          'No se pudo completar la operación por un problema de conexión.',
          code: 'unavailable',
        ),
      );

      await tester.ensureVisible(find.byKey(const Key('calificar-luis')));
      await tester.tap(find.byKey(const Key('calificar-luis')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('estrella-5')));
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('comentario-resena')),
        'Excelente',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('publicar-resena')));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'No se pudo completar la operación por un problema de conexión.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('calificar-luis')), findsOneWidget);
    });
  });

  group('Perfil: promedio de calificaciones', () {
    Future<void> abrirPerfil(
      WidgetTester tester,
      ResumenCalificaciones? resumen, {
      Future<List<ResenaRecibida>> Function(String uid)? resenas,
    }) async {
      tester.view.physicalSize = const Size(1080, 2600);
      tester.view.devicePixelRatio = 1.5;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: PerfilUsuarioScreen(
            uid: 'luis',
            uidUsuarioActual: 'ana',
            cargarPerfil: (String uid) async => <String, dynamic>{
              'correo': 'luis@gmail.com',
              'rol': 'Turista',
            },
            cargarPublicaciones: (String uid) async => <Publicacion>[],
            cargarResumenCalificaciones: (String uid) async => resumen,
            cargarResenas: resenas ?? (String uid) async => <ResenaRecibida>[],
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('muestra el promedio con estrellas y el total', (
      WidgetTester tester,
    ) async {
      await abrirPerfil(
        tester,
        const ResumenCalificaciones(promedio: 4.5, total: 2),
      );

      expect(find.byKey(const Key('perfil-calificaciones')), findsOneWidget);
      expect(find.text('4,5'), findsOneWidget);
      expect(find.text('(2 reseñas)'), findsOneWidget);
      expect(find.byIcon(Icons.star_half_rounded), findsOneWidget);
    });

    testWidgets('sin calificaciones lo indica', (WidgetTester tester) async {
      await abrirPerfil(
        tester,
        const ResumenCalificaciones(promedio: null, total: 0),
      );

      expect(find.text('Todavía no tiene reseñas.'), findsOneWidget);
    });

    testWidgets('muestra las reseñas con autor, estrellas, comentario, '
        'evento y fecha', (WidgetTester tester) async {
      await abrirPerfil(
        tester,
        const ResumenCalificaciones(promedio: 4.5, total: 2),
        resenas: (String uid) async => <ResenaRecibida>[
          ResenaRecibida(
            resena: Resena(
              id: 'org_ev2',
              usuarioId: 'org',
              nombreUsuario: 'org',
              comentario: 'Muy amable',
              calificacion: 5,
              fecha: DateTime(2026, 10, 11),
              eventoId: 'ev2',
            ),
            nombreEvento: 'Tour de café',
          ),
          ResenaRecibida(
            resena: Resena(
              id: 'ana_ev',
              usuarioId: 'ana',
              nombreUsuario: 'ana',
              comentario: 'Puntual',
              calificacion: 4,
              fecha: DateTime(2026, 10, 10),
              eventoId: 'ev',
            ),
            nombreEvento: 'Caminata al cerro',
          ),
        ],
      );

      final Finder primera = find.byKey(const Key('resena-org_ev2'));
      await tester.ensureVisible(primera);
      Finder en(Finder tarjeta, Finder f) =>
          find.descendant(of: tarjeta, matching: f);
      expect(en(primera, find.text('org')), findsOneWidget);
      expect(en(primera, find.text('Muy amable')), findsOneWidget);
      expect(en(primera, find.text('Tour de café')), findsOneWidget);
      expect(en(primera, find.text('11 de octubre de 2026')), findsOneWidget);
      expect(en(primera, find.byIcon(Icons.star_rounded)), findsNWidgets(5));

      final Finder segunda = find.byKey(const Key('resena-ana_ev'));
      expect(en(segunda, find.text('Puntual')), findsOneWidget);
      expect(en(segunda, find.byIcon(Icons.star_rounded)), findsNWidgets(4));
      expect(
        tester.getTopLeft(segunda).dy,
        greaterThan(tester.getTopLeft(primera).dy),
      );
    });

    testWidgets('tocar al autor de una reseña abre su perfil', (
      WidgetTester tester,
    ) async {
      await abrirPerfil(
        tester,
        const ResumenCalificaciones(promedio: 5, total: 1),
        resenas: (String uid) async => <ResenaRecibida>[
          ResenaRecibida(
            resena: Resena(
              id: 'org_ev',
              usuarioId: 'org',
              nombreUsuario: 'org',
              comentario: 'Muy amable',
              calificacion: 5,
              fecha: DateTime(2026, 10, 11),
              eventoId: 'ev',
            ),
          ),
        ],
      );

      await tester.ensureVisible(find.text('org'));
      await tester.tap(find.text('org'));
      await tester.pumpAndSettle();

      // El perfil del autor se abre encima del que se estaba viendo.
      expect(
        find.byType(PerfilUsuarioScreen, skipOffstage: false),
        findsNWidgets(2),
      );
    });

    testWidgets('sin reseñas lo indica', (WidgetTester tester) async {
      await abrirPerfil(
        tester,
        const ResumenCalificaciones(promedio: null, total: 0),
      );

      await tester.ensureVisible(find.byKey(const Key('perfil-sin-resenas')));
      expect(find.text('Aún no tiene reseñas.'), findsOneWidget);
    });

    testWidgets('si no se pueden leer las reseñas, lo informa', (
      WidgetTester tester,
    ) async {
      await abrirPerfil(
        tester,
        null,
        resenas: (String uid) async => throw const CalificacionException(
          'No se pudieron cargar las reseñas. Inténtalo de nuevo.',
        ),
      );

      await tester.ensureVisible(
        find.text('No se pudieron cargar las reseñas.'),
      );
      expect(find.text('No se pudieron cargar las reseñas.'), findsOneWidget);
    });

    testWidgets('si no se pudo leer, lo informa en vez de ocultarla', (
      WidgetTester tester,
    ) async {
      await abrirPerfil(tester, null);

      expect(find.byKey(const Key('perfil-reputacion-error')), findsOneWidget);
      expect(find.byKey(const Key('perfil-sin-reputacion')), findsNothing);
    });
  });
}

/// Servicio falso: registra las calificaciones o falla con [error].
class _ServicioFalso extends Fake implements CalificacionUsuarioService {
  _ServicioFalso(this.yaCalificados, CalificacionException? error)
    : errores = <CalificacionException?>[error];

  final Set<String> yaCalificados;

  /// Errores de las siguientes publicaciones, en orden; `null` = éxito. El
  /// último se repite.
  List<CalificacionException?> errores;
  final List<(String, int, String)> calificaciones = <(String, int, String)>[];

  @override
  Future<Set<String>> calificadosPorMi({
    required String eventoId,
    required Iterable<String> candidatos,
  }) async => yaCalificados.intersection(candidatos.toSet());

  @override
  Future<void> calificarUsuario({
    required String eventoId,
    required String calificadoUid,
    required int? calificacion,
    required String? comentario,
  }) async {
    final CalificacionException? error = errores.length > 1
        ? errores.removeAt(0)
        : errores.first;
    if (error != null) throw error;
    calificaciones.add((calificadoUid, calificacion!, comentario!));
  }
}

/// Moderador falso: acepta o rechaza todo, o falla; guarda lo revisado.
class _ModeradorFalso implements ModeradorComentarios {
  _ModeradorFalso({this.acepta = true, this.falla = false});

  final bool acepta;
  final bool falla;
  final List<String> revisados = <String>[];

  @override
  Future<bool> esAceptable(String texto) async {
    if (falla) throw const ModeracionException('sin-conexion');
    revisados.add(texto);
    return acepta;
  }
}
