import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripmeet/calificacion_usuario_service.dart';
import 'package:tripmeet/perfil_usuario_screen.dart';
import 'package:tripmeet/publicacion_service.dart';

/// HU-29: ver la reputación de otro usuario antes de compartir un plan.
void main() {
  group('Perfil de otro miembro', () {
    Future<void> abrirPerfil(
      WidgetTester tester, {
      required Future<ResumenCalificaciones?> Function(String uid) reputacion,
      String? uid = 'luis',
      String uidActual = 'ana',
    }) async {
      tester.view.physicalSize = const Size(1080, 2600);
      tester.view.devicePixelRatio = 1.5;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: PerfilUsuarioScreen(
            uid: uid,
            uidUsuarioActual: uidActual,
            cargarPerfil: (String uid) async => <String, dynamic>{
              'correo': '$uid@gmail.com',
              'rol': 'Turista',
            },
            cargarPublicaciones: (String uid) async => <Publicacion>[],
            cargarResenas: (String uid) async => <ResenaRecibida>[],
            cargarResumenCalificaciones: reputacion,
          ),
        ),
      );
    }

    Finder reputacion() => find.byKey(const Key('perfil-calificaciones'));

    testWidgets('criterio 1: muestra la calificación promedio y el número de '
        'reseñas', (WidgetTester tester) async {
      String? consultado;
      await abrirPerfil(
        tester,
        reputacion: (String uid) async {
          consultado = uid;
          return const ResumenCalificaciones(promedio: 4.33, total: 3);
        },
      );
      await tester.pumpAndSettle();

      expect(consultado, 'luis', reason: 'la reputación es del perfil visto');
      expect(reputacion(), findsOneWidget);
      expect(
        find.descendant(of: reputacion(), matching: find.text('Reputación')),
        findsOneWidget,
      );
      expect(find.text('4,3'), findsOneWidget);
      expect(find.text('(3 reseñas)'), findsOneWidget);
      expect(
        find.descendant(
          of: reputacion(),
          matching: find.byIcon(Icons.star_rounded),
        ),
        findsNWidgets(4),
      );
    });

    testWidgets('con una sola reseña usa el singular', (
      WidgetTester tester,
    ) async {
      await abrirPerfil(
        tester,
        reputacion: (String uid) async =>
            const ResumenCalificaciones(promedio: 5, total: 1),
      );
      await tester.pumpAndSettle();

      expect(find.text('5,0'), findsOneWidget);
      expect(find.text('(1 reseña)'), findsOneWidget);
    });

    testWidgets('criterio 2: si no tiene calificaciones indica que todavía no '
        'tiene reseñas', (WidgetTester tester) async {
      await abrirPerfil(
        tester,
        reputacion: (String uid) async =>
            const ResumenCalificaciones(promedio: null, total: 0),
      );
      await tester.pumpAndSettle();

      expect(find.text('Todavía no tiene reseñas.'), findsOneWidget);
      expect(find.byKey(const Key('perfil-promedio')), findsNothing);
      expect(
        find.descendant(
          of: reputacion(),
          matching: find.byIcon(Icons.star_rounded),
        ),
        findsNothing,
      );
    });

    testWidgets('mientras carga muestra un indicador, no "sin reseñas"', (
      WidgetTester tester,
    ) async {
      final Completer<ResumenCalificaciones?> pendiente =
          Completer<ResumenCalificaciones?>();
      await abrirPerfil(tester, reputacion: (_) => pendiente.future);
      await tester.pump();
      await tester.pump();

      expect(
        find.descendant(
          of: reputacion(),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      expect(find.text('Todavía no tiene reseñas.'), findsNothing);

      pendiente.complete(const ResumenCalificaciones(promedio: 4, total: 2));
      await tester.pumpAndSettle();
      expect(find.text('(2 reseñas)'), findsOneWidget);
    });

    testWidgets('si no se puede leer, lo informa y deslizar reintenta', (
      WidgetTester tester,
    ) async {
      int intentos = 0;
      await abrirPerfil(
        tester,
        reputacion: (String uid) async {
          intentos++;
          return intentos == 1
              ? null
              : const ResumenCalificaciones(promedio: 3.5, total: 2);
        },
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('perfil-reputacion-error')), findsOneWidget);
      expect(
        find.text('Todavía no tiene reseñas.'),
        findsNothing,
        reason: 'un error no debe parecer falta de reputación',
      );

      await tester.fling(find.byType(ListView), const Offset(0, 600), 1000);
      await tester.pumpAndSettle();

      expect(intentos, 2);
      expect(find.text('3,5'), findsOneWidget);
      expect(find.text('(2 reseñas)'), findsOneWidget);
    });

    testWidgets('el perfil propio también muestra su reputación', (
      WidgetTester tester,
    ) async {
      await abrirPerfil(
        tester,
        uid: null,
        uidActual: 'luis',
        reputacion: (String uid) async =>
            const ResumenCalificaciones(promedio: 4.5, total: 2),
      );
      await tester.pumpAndSettle();

      expect(find.text('4,5'), findsOneWidget);
    });
  });

  group('Datos de la reputación (Firestore simulado)', () {
    late FakeFirebaseFirestore firestore;

    CalificacionUsuarioService servicio(String uid) =>
        CalificacionUsuarioService(
          auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: uid)),
          firestore: firestore,
          reloj: () => DateTime(2026, 10, 16, 12),
        );

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      for (final String uid in <String>['org', 'ana', 'luis', 'sofia']) {
        await firestore.collection('usuarios').doc(uid).set(<String, dynamic>{
          'correo': '$uid@gmail.com',
          'rol': 'Turista',
        });
      }
      await firestore.collection('eventos').doc('ev').set(<String, dynamic>{
        'creadorUid': 'org',
        'nombre': 'Caminata',
        'lugar': 'Medellín',
        'fechaHora': Timestamp.fromDate(DateTime(2026, 10, 1)),
        'fechaCreacion': Timestamp.fromDate(DateTime(2026, 9, 1)),
        'inscritos': <String>['ana', 'luis', 'sofia'],
      });
    });

    test('el número de reseñas coincide con las reseñas guardadas y el '
        'promedio con sus estrellas', () async {
      final List<(String, int)> autores = <(String, int)>[
        ('ana', 5),
        ('org', 4),
        ('sofia', 3),
      ];
      for (final (String autor, int estrellas) in autores) {
        await servicio(autor).calificarUsuario(
          eventoId: 'ev',
          calificadoUid: 'luis',
          calificacion: estrellas,
          comentario: 'Reseña de $autor',
        );
      }

      final ResumenCalificaciones resumen = await servicio('ana')
          .obtenerResumen('luis');
      final List<ResenaRecibida> resenas = await servicio('ana')
          .obtenerResenas('luis');

      expect(resumen.total, 3);
      expect(resenas, hasLength(resumen.total));
      expect(resumen.promedio, 4);
    });

    test('un usuario sin reseñas tiene total 0 y sin promedio', () async {
      final ResumenCalificaciones resumen = await servicio('ana')
          .obtenerResumen('sofia');

      expect(resumen.total, 0);
      expect(resumen.promedio, isNull);
      expect(resumen.tieneCalificaciones, isFalse);
    });
  });
}
