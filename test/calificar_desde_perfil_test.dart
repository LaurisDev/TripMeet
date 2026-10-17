import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripmeet/calificacion_usuario_service.dart';
import 'package:tripmeet/moderacion_service.dart';
import 'package:tripmeet/perfil_usuario_screen.dart';
import 'package:tripmeet/publicacion_service.dart';

Matcher _lanzaCodigo(String codigo) => throwsA(
  isA<CalificacionException>().having(
    (CalificacionException e) => e.code,
    'code',
    codigo,
  ),
);

void main() {
  group('CalificacionUsuarioService.calificarDesdePerfil', () {
    late FakeFirebaseFirestore firestore;

    CalificacionUsuarioService servicio({
      String? uid = 'ana',
      ModeradorComentarios? moderador,
    }) => CalificacionUsuarioService(
      auth: MockFirebaseAuth(
        signedIn: uid != null,
        mockUser: MockUser(uid: uid ?? 'sin-sesion'),
      ),
      firestore: firestore,
      reloj: () => DateTime(2026, 10, 16, 12),
      moderador: moderador,
    );

    Future<Map<String, dynamic>?> guardada(
      String calificado,
      String autor,
    ) async =>
        (await firestore
                .collection('usuarios')
                .doc(calificado)
                .collection('Reseñas')
                .doc('${autor}_perfil')
                .get())
            .data();

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      for (final String uid in <String>['ana', 'luis']) {
        await firestore.collection('usuarios').doc(uid).set(<String, dynamic>{
          'correo': '$uid@gmail.com',
          'rol': 'Turista',
        });
      }
    });

    test(
      'califica a cualquier usuario sin haber compartido un evento',
      () async {
        await servicio().calificarDesdePerfil(
          calificadoUid: 'luis',
          calificacion: 4,
          comentario: '  Muy buena persona  ',
        );

        final Map<String, dynamic>? datos = await guardada('luis', 'ana');
        expect(datos?['usuarioId'], 'ana');
        expect(datos?['nombreUsuario'], 'ana');
        expect(datos?['calificacion'], 4);
        expect(datos?['comentario'], 'Muy buena persona');
        expect(datos?.containsKey('eventoId'), isFalse);

        final ResumenCalificaciones resumen = await servicio().obtenerResumen(
          'luis',
        );
        expect(resumen.total, 1);
        expect(resumen.promedio, 4);
        expect(
          (await servicio().obtenerResenas('luis')).single.nombreEvento,
          isNull,
        );
      },
    );

    test('solo una reseña general por persona', () async {
      await servicio().calificarDesdePerfil(
        calificadoUid: 'luis',
        calificacion: 2,
        comentario: 'Regular',
      );

      await expectLater(
        servicio().calificarDesdePerfil(
          calificadoUid: 'luis',
          calificacion: 5,
          comentario: 'Ahora sí',
        ),
        _lanzaCodigo('ya-calificado'),
      );
      expect((await guardada('luis', 'ana'))?['calificacion'], 2);
      expect(await servicio().yaCalificoDesdePerfil('luis'), isTrue);
      expect(await servicio(uid: 'luis').yaCalificoDesdePerfil('ana'), isFalse);
    });

    test('no puede calificarse a sí mismo', () async {
      await expectLater(
        servicio().calificarDesdePerfil(
          calificadoUid: 'ana',
          calificacion: 5,
          comentario: 'Soy genial',
        ),
        _lanzaCodigo('auto-calificacion'),
      );
    });

    test('aplica la moderación: un comentario ofensivo no se guarda', () async {
      await expectLater(
        servicio().calificarDesdePerfil(
          calificadoUid: 'luis',
          calificacion: 1,
          comentario: 'Es un idiota',
        ),
        _lanzaCodigo('comentario-ofensivo'),
      );
      expect(await guardada('luis', 'ana'), isNull);
    });

    test('si la moderación falla, no se guarda', () async {
      await expectLater(
        servicio(moderador: _ModeradorQueFalla()).calificarDesdePerfil(
          calificadoUid: 'luis',
          calificacion: 5,
          comentario: 'Muy amable',
        ),
        _lanzaCodigo('moderacion-no-disponible'),
      );
      expect(await guardada('luis', 'ana'), isNull);
    });

    test('valida estrellas, comentario y sesión', () async {
      await expectLater(
        servicio().calificarDesdePerfil(
          calificadoUid: 'luis',
          calificacion: 0,
          comentario: 'Bien',
        ),
        _lanzaCodigo('calificacion-invalida'),
      );
      await expectLater(
        servicio().calificarDesdePerfil(
          calificadoUid: 'luis',
          calificacion: 5,
          comentario: '   ',
        ),
        _lanzaCodigo('comentario-invalido'),
      );
      await expectLater(
        servicio(uid: null).calificarDesdePerfil(
          calificadoUid: 'luis',
          calificacion: 5,
          comentario: 'Bien',
        ),
        _lanzaCodigo('user-not-authenticated'),
      );
      expect(await guardada('luis', 'ana'), isNull);
    });
  });

  group('Perfil: botón "Calificar"', () {
    Future<_ServicioFalso> abrir(
      WidgetTester tester, {
      String? uid = 'luis',
      bool yaCalifique = false,
      CalificacionException? error,
    }) async {
      tester.view.physicalSize = const Size(1080, 2600);
      tester.view.devicePixelRatio = 1.5;
      addTearDown(tester.view.reset);

      final _ServicioFalso servicio = _ServicioFalso(yaCalifique, error);
      int lecturasReputacion = 0;
      servicio.lecturasReputacion = () => lecturasReputacion;
      await tester.pumpWidget(
        MaterialApp(
          home: PerfilUsuarioScreen(
            uid: uid,
            uidUsuarioActual: 'ana',
            cargarPerfil: (String uid) async => <String, dynamic>{
              'correo': '$uid@gmail.com',
              'rol': 'Turista',
            },
            cargarPublicaciones: (String uid) async => <Publicacion>[],
            cargarResenas: (String uid) async => <ResenaRecibida>[],
            cargarResumenCalificaciones: (String uid) async {
              lecturasReputacion++;
              return servicio.publicadas.isEmpty
                  ? const ResumenCalificaciones(promedio: null, total: 0)
                  : const ResumenCalificaciones(promedio: 4, total: 1);
            },
            servicioCalificaciones: servicio,
          ),
        ),
      );
      await tester.pumpAndSettle();
      return servicio;
    }

    Finder boton() => find.byKey(const Key('perfil-calificar'));

    Future<void> publicar(WidgetTester tester, String comentario) async {
      await tester.ensureVisible(boton());
      await tester.tap(boton());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('estrella-4')));
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('comentario-resena')),
        comentario,
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('publicar-resena')));
      await tester.pumpAndSettle();
    }

    testWidgets('en el perfil de otra persona aparece "Calificar"', (
      WidgetTester tester,
    ) async {
      await abrir(tester);

      expect(
        find.widgetWithText(OutlinedButton, 'Calificar a luis'),
        findsOneWidget,
      );
    });

    testWidgets('en el perfil propio no aparece', (WidgetTester tester) async {
      await abrir(tester, uid: null);

      expect(boton(), findsNothing);
    });

    testWidgets('al publicar avisa, actualiza la reputación y ya no ofrece '
        'calificar', (WidgetTester tester) async {
      final _ServicioFalso servicio = await abrir(tester);
      expect(find.text('Todavía no tiene reseñas.'), findsOneWidget);
      final int lecturasAntes = servicio.lecturasReputacion!();

      await publicar(tester, 'Muy buena persona');

      expect(servicio.publicadas, <(String, int, String)>[
        ('luis', 4, 'Muy buena persona'),
      ]);
      expect(find.text('Publicaste tu reseña sobre luis.'), findsOneWidget);
      expect(servicio.lecturasReputacion!(), greaterThan(lecturasAntes));
      expect(find.text('(1 reseña)'), findsOneWidget);
      expect(boton(), findsNothing);
      expect(find.byKey(const Key('perfil-ya-calificado')), findsOneWidget);
    });

    testWidgets('si ya lo calificó, no ofrece calificar de nuevo', (
      WidgetTester tester,
    ) async {
      await abrir(tester, yaCalifique: true);

      expect(boton(), findsNothing);
      expect(find.text('Ya calificaste a este usuario'), findsOneWidget);
    });

    testWidgets('si el comentario es ofensivo, el diálogo lo explica y no se '
        'marca como calificado', (WidgetTester tester) async {
      await abrir(
        tester,
        error: const CalificacionException(
          'Tu comentario incluye expresiones que no están permitidas en '
          'TripMeet. Por favor, modifícalo para que sea respetuoso e '
          'inténtalo de nuevo.',
          code: 'comentario-ofensivo',
        ),
      );

      await publicar(tester, 'Comentario a corregir');

      expect(find.byKey(const Key('error-resena')), findsOneWidget);
      expect(find.text('Comentario a corregir'), findsOneWidget);
      expect(find.byKey(const Key('perfil-ya-calificado')), findsNothing);
    });
  });
}

class _ModeradorQueFalla implements ModeradorComentarios {
  @override
  Future<bool> esAceptable(String texto) async =>
      throw const ModeracionException('sin-conexion');
}

/// Servicio falso: registra las reseñas publicadas desde el perfil o falla.
class _ServicioFalso extends Fake implements CalificacionUsuarioService {
  _ServicioFalso(this.yaCalifique, this.error);

  final bool yaCalifique;
  final CalificacionException? error;
  final List<(String, int, String)> publicadas = <(String, int, String)>[];
  int Function()? lecturasReputacion;

  @override
  Future<bool> yaCalificoDesdePerfil(String calificadoUid) async => yaCalifique;

  @override
  Future<void> calificarDesdePerfil({
    required String calificadoUid,
    required int? calificacion,
    required String? comentario,
  }) async {
    if (error != null) throw error!;
    publicadas.add((calificadoUid, calificacion!, comentario!));
  }
}
