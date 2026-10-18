import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mock_exceptions/mock_exceptions.dart';
import 'package:tripmeet/evento_detalle_screen.dart';
import 'package:tripmeet/evento_service.dart';
import 'package:tripmeet/eventos_screen.dart';

final DateTime _ahora = DateTime(2026, 10, 12, 12);

Matcher _lanzaCodigo(String codigo) => throwsA(
  isA<EventoServiceException>().having(
    (EventoServiceException e) => e.code,
    'code',
    codigo,
  ),
);

void main() {
  late FakeFirebaseFirestore firestore;

  EventoService servicio({String? uid = 'organizador'}) => EventoService(
    auth: MockFirebaseAuth(
      signedIn: uid != null,
      mockUser: MockUser(uid: uid ?? 'sin-sesion'),
    ),
    firestore: firestore,
    reloj: () => _ahora,
  );

  Future<void> guardarEvento(String id, String nombre) =>
      firestore.collection('eventos').doc(id).set(<String, dynamic>{
        'id': id,
        'creadorUid': 'organizador',
        'nombre': nombre,
        'lugar': 'Medellín',
        // Lejos en el futuro: el detalle compara con la hora real.
        'fechaHora': Timestamp.fromDate(DateTime(2099, 10, 20, 8)),
        'fechaCreacion': Timestamp.fromDate(DateTime(2026, 10, 1)),
        'inscritos': <String>['luis'],
      });

  Future<bool> existe(String id) async =>
      (await firestore.collection('eventos').doc(id).get()).exists;

  setUp(() => firestore = FakeFirebaseFirestore());

  group('EventoService.eliminarEvento', () {
    test('el organizador lo elimina', () async {
      await guardarEvento('ev', 'Caminata');

      await servicio().eliminarEvento('ev');

      expect(await existe('ev'), isFalse);
      expect(await servicio().obtenerEventosDisponibles(), isEmpty);
    });

    test('otro usuario no puede eliminarlo', () async {
      await guardarEvento('ev', 'Caminata');

      await expectLater(
        servicio(uid: 'luis').eliminarEvento('ev'),
        _lanzaCodigo('permission-denied'),
      );
      expect(await existe('ev'), isTrue);
    });

    test('sin sesión no se elimina', () async {
      await guardarEvento('ev', 'Caminata');

      await expectLater(
        servicio(uid: null).eliminarEvento('ev'),
        _lanzaCodigo('user-not-authenticated'),
      );
      expect(await existe('ev'), isTrue);
    });

    test('un evento que ya no existe da not-found', () async {
      await expectLater(
        servicio().eliminarEvento('no-existe'),
        _lanzaCodigo('not-found'),
      );
    });

    test('si Firestore falla, lo informa y el evento queda intacto', () async {
      await guardarEvento('ev', 'Caminata');
      whenCalling(Invocation.method(#delete, null))
          .on(firestore.collection('eventos').doc('ev'))
          .thenThrow(
            FirebaseException(plugin: 'firestore', code: 'unavailable'),
          );

      await expectLater(
        servicio().eliminarEvento('ev'),
        _lanzaCodigo('unavailable'),
      );
      expect(await existe('ev'), isTrue);
    });
  });

  group('Pantalla', () {
    /// Abre la lista de eventos con el servicio real sobre Firestore simulado
    /// y entra al detalle de "Caminata".
    Future<void> abrirDetalle(
      WidgetTester tester, {
      String uid = 'organizador',
    }) async {
      tester.view.physicalSize = const Size(1080, 2600);
      tester.view.devicePixelRatio = 1.5;
      addTearDown(tester.view.reset);

      await guardarEvento('ev', 'Caminata');
      await guardarEvento('otro', 'Tour nocturno');
      await tester.pumpWidget(
        MaterialApp(
          home: EventosScreen(service: servicio(uid: uid)),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Caminata'));
      await tester.pumpAndSettle();
      expect(find.byType(EventoDetalleScreen), findsOneWidget);
    }

    Finder botonEliminar() => find.byKey(const Key('detalle-eliminar-evento'));

    Future<void> tocarEliminar(WidgetTester tester) async {
      await tester.ensureVisible(botonEliminar());
      await tester.tap(botonEliminar());
      await tester.pumpAndSettle();
    }

    testWidgets('quien no es el organizador no ve "Eliminar"', (
      WidgetTester tester,
    ) async {
      await abrirDetalle(tester, uid: 'luis');

      expect(botonEliminar(), findsNothing);
    });

    testWidgets('muestra el modal de confirmación con sus textos', (
      WidgetTester tester,
    ) async {
      await abrirDetalle(tester);
      await tocarEliminar(tester);

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('¿Eliminar este evento?'), findsOneWidget);
      expect(
        find.text(
          'Esta acción no se puede deshacer. El evento dejará de estar '
          'disponible para todos los usuarios.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('cancelar-eliminar-evento')), findsOneWidget);

      // "Eliminar" con alerta suave: fondo claro, no rojo intenso.
      final FilledButton eliminar = tester.widget<FilledButton>(
        find.byKey(const Key('confirmar-eliminar-evento')),
      );
      final Color fondo = eliminar.style!.backgroundColor!.resolve(
        <WidgetState>{},
      )!;
      expect(fondo.computeLuminance(), greaterThan(0.8));
    });

    testWidgets('Criterio 1: al confirmar elimina el evento, vuelve a la '
        'lista sin él y avisa', (WidgetTester tester) async {
      await abrirDetalle(tester);
      await tocarEliminar(tester);

      await tester.tap(find.byKey(const Key('confirmar-eliminar-evento')));
      await tester.pumpAndSettle();

      expect(await existe('ev'), isFalse);
      expect(find.byType(EventoDetalleScreen), findsNothing);
      expect(find.byType(EventosScreen), findsOneWidget);
      expect(find.text('El evento fue eliminado'), findsOneWidget);
      expect(find.text('Caminata'), findsNothing);
      expect(find.text('Tour nocturno'), findsOneWidget);
      expect(find.text('1 evento encontrado'), findsOneWidget);
    });

    testWidgets('Criterio 2: al cancelar cierra el modal y deja el evento '
        'sin cambios', (WidgetTester tester) async {
      await abrirDetalle(tester);
      await tocarEliminar(tester);

      await tester.tap(find.byKey(const Key('cancelar-eliminar-evento')));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(EventoDetalleScreen), findsOneWidget);
      expect(find.text('Caminata'), findsOneWidget);
      expect(find.text('El evento fue eliminado'), findsNothing);
      expect(await existe('ev'), isTrue);
      expect(
        (await firestore.collection('eventos').doc('ev').get())
            .data()?['nombre'],
        'Caminata',
      );
    });

    testWidgets('cerrar el modal tocando afuera también cancela', (
      WidgetTester tester,
    ) async {
      await abrirDetalle(tester);
      await tocarEliminar(tester);

      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(EventoDetalleScreen), findsOneWidget);
      expect(await existe('ev'), isTrue);
    });

    testWidgets('si falla, lo informa y sigue en el detalle', (
      WidgetTester tester,
    ) async {
      await abrirDetalle(tester);
      whenCalling(Invocation.method(#delete, null))
          .on(firestore.collection('eventos').doc('ev'))
          .thenThrow(
            FirebaseException(plugin: 'firestore', code: 'unavailable'),
          );
      await tocarEliminar(tester);

      await tester.tap(find.byKey(const Key('confirmar-eliminar-evento')));
      await tester.pumpAndSettle();

      expect(find.byType(EventoDetalleScreen), findsOneWidget);
      expect(
        find.text(
          'No se pudo completar la operación por un problema de conexión.',
        ),
        findsOneWidget,
      );
      expect(find.text('Reintentar'), findsOneWidget);
      expect(await existe('ev'), isTrue);
    });
  });
}
