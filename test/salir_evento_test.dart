import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripmeet/evento_detalle_screen.dart';
import 'package:tripmeet/evento_service.dart';

final DateTime _ahora = DateTime(2026, 10, 12, 12);

Matcher _lanzaCodigo(String codigo) => throwsA(
  isA<EventoServiceException>().having(
    (EventoServiceException e) => e.code,
    'code',
    codigo,
  ),
);

void main() {
  group('EventoService.salirEvento (Firestore simulado)', () {
    late FakeFirebaseFirestore firestore;

    EventoService servicio({String? uid = 'ana'}) => EventoService(
      auth: MockFirebaseAuth(
        signedIn: uid != null,
        mockUser: MockUser(uid: uid ?? 'sin-sesion'),
      ),
      firestore: firestore,
      reloj: () => _ahora,
    );

    Future<void> guardarEvento({
      DateTime? fechaHora,
      int? cupo,
      List<String> inscritos = const <String>[],
    }) => firestore.collection('eventos').doc('ev').set(<String, dynamic>{
      'id': 'ev',
      'creadorUid': 'organizador',
      'nombre': 'Caminata',
      'lugar': 'Medellín',
      'fechaHora': Timestamp.fromDate(fechaHora ?? DateTime(2026, 10, 20, 8)),
      'fechaCreacion': Timestamp.fromDate(DateTime(2026, 10, 1)),
      'cupoMaximo': cupo,
      'inscritos': inscritos,
    });

    Future<List<String>> inscritosGuardados() async {
      final Map<String, dynamic>? datos =
          (await firestore.collection('eventos').doc('ev').get()).data();
      return List<String>.from(datos?['inscritos'] as List<dynamic>? ?? []);
    }

    setUp(() => firestore = FakeFirebaseFirestore());

    test(
      'criterio 1: retira al usuario de la lista de participantes',
      () async {
        await guardarEvento(inscritos: <String>['luis', 'ana', 'sofia']);

        final List<String> inscritos = await servicio().salirEvento('ev');

        expect(inscritos, <String>['luis', 'sofia']);
        expect(await inscritosGuardados(), <String>['luis', 'sofia']);
      },
    );

    test('la salida persiste: una consulta nueva ya no lo incluye', () async {
      await guardarEvento(inscritos: <String>['ana']);
      await servicio().salirEvento('ev');

      final Evento leido = await servicio(uid: 'otro').obtenerEvento('ev');

      expect(leido.inscritos, isEmpty);
    });

    test(
      'criterio 2: en un evento lleno libera un cupo para otra persona',
      () async {
        await guardarEvento(cupo: 2, inscritos: <String>['luis', 'ana']);
        await expectLater(
          servicio(uid: 'sofia').unirseEvento('ev'),
          _lanzaCodigo('evento-lleno'),
        );

        await servicio().salirEvento('ev');
        final Evento despues = await servicio().obtenerEvento('ev');
        expect(despues.estaLleno, isFalse);
        expect(despues.cuposDisponibles, 1);

        expect(await servicio(uid: 'sofia').unirseEvento('ev'), <String>[
          'luis',
          'sofia',
        ]);
      },
    );

    test('salir sin estar inscrito no cambia nada ni da error', () async {
      await guardarEvento(inscritos: <String>['luis']);

      expect(await servicio().salirEvento('ev'), <String>['luis']);
      expect(await inscritosGuardados(), <String>['luis']);
    });

    test('el organizador no puede salir de su propio evento', () async {
      await guardarEvento(inscritos: <String>['luis']);

      await expectLater(
        servicio(uid: 'organizador').salirEvento('ev'),
        _lanzaCodigo('es-creador'),
      );
    });

    test('no se puede salir de un evento que ya ocurrió', () async {
      await guardarEvento(
        fechaHora: DateTime(2026, 10, 1, 8),
        inscritos: <String>['ana'],
      );

      await expectLater(
        servicio().salirEvento('ev'),
        _lanzaCodigo('evento-finalizado'),
      );
      expect(await inscritosGuardados(), <String>['ana']);
    });

    test('sin sesión iniciada no se puede salir', () async {
      await guardarEvento(inscritos: <String>['ana']);

      await expectLater(
        servicio(uid: null).salirEvento('ev'),
        _lanzaCodigo('user-not-authenticated'),
      );
      expect(await inscritosGuardados(), <String>['ana']);
    });

    test('un evento que no existe informa not-found', () async {
      await expectLater(
        servicio().salirEvento('no-existe'),
        _lanzaCodigo('not-found'),
      );
    });

    test('salir no modifica los demás datos del evento', () async {
      await guardarEvento(cupo: 10, inscritos: <String>['ana']);
      final Map<String, dynamic>? antes =
          (await firestore.collection('eventos').doc('ev').get()).data();

      await servicio().salirEvento('ev');

      final Map<String, dynamic>? despues =
          (await firestore.collection('eventos').doc('ev').get()).data();
      expect(despues?..remove('inscritos'), antes?..remove('inscritos'));
    });
  });

  group('Detalle del evento: "Salir del evento"', () {
    Evento evento({
      List<String> inscritos = const <String>['ana'],
      int? cupo,
    }) => Evento(
      id: 'ev',
      creadorUid: 'organizador',
      nombre: 'Caminata',
      lugar: 'Medellín',
      fechaHora: DateTime(2100, 1, 1, 8),
      fechaCreacion: DateTime(2026, 10, 1),
      cupoMaximo: cupo,
      inscritos: inscritos,
    );

    Future<_ServicioFalso> abrir(
      WidgetTester tester, {
      required Evento evento,
      List<EventoServiceException?> erroresSalir =
          const <EventoServiceException?>[null],
    }) async {
      tester.view.physicalSize = const Size(1080, 2600);
      tester.view.devicePixelRatio = 1.5;
      addTearDown(tester.view.reset);

      final _ServicioFalso servicio = _ServicioFalso(evento)
        ..erroresSalir = List<EventoServiceException?>.of(erroresSalir);
      await tester.pumpWidget(
        MaterialApp(
          home: EventoDetalleScreen(
            evento: evento,
            service: servicio,
            uidUsuarioActual: 'ana',
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

    Finder botonSalir() => find.byKey(const Key('salir-evento'));

    Future<void> tocarSalir(WidgetTester tester) async {
      await tester.ensureVisible(botonSalir());
      await tester.tap(botonSalir());
      await tester.pumpAndSettle();
    }

    testWidgets('un inscrito ve "Salir del evento"', (
      WidgetTester tester,
    ) async {
      await abrir(tester, evento: evento());

      expect(
        find.widgetWithText(OutlinedButton, 'Salir del evento'),
        findsOneWidget,
      );
    });

    testWidgets('pide confirmación; al cancelar no sale', (
      WidgetTester tester,
    ) async {
      final _ServicioFalso servicio = await abrir(tester, evento: evento());

      await tocarSalir(tester);
      expect(find.text('¿Salir del evento?'), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(servicio.salidas, 0);
      expect(find.byKey(const Key('evento-inscrito')), findsOneWidget);
    });

    testWidgets('al confirmar sale, avisa, lo quita de los participantes y '
        'vuelve a ofrecer "Unirme"', (WidgetTester tester) async {
      final _ServicioFalso servicio = await abrir(
        tester,
        evento: evento(inscritos: <String>['luis', 'ana'], cupo: 2),
      );
      expect(find.text('Participantes (2/2)'), findsOneWidget);
      expect(find.text('ana'), findsOneWidget);

      await tocarSalir(tester);
      await tester.tap(find.byKey(const Key('confirmar-salir-evento')));
      await tester.pumpAndSettle();

      expect(servicio.salidas, 1);
      expect(
        find.text('Saliste de "Caminata". Tu cupo quedó disponible.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('evento-inscrito')), findsNothing);
      expect(botonSalir(), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Unirme'), findsOneWidget);
      expect(find.text('Participantes (1/2)'), findsOneWidget);
      expect(find.text('ana'), findsNothing);
    });

    testWidgets('mientras sale, el botón se desactiva', (
      WidgetTester tester,
    ) async {
      final _ServicioFalso servicio = await abrir(tester, evento: evento());
      servicio.pausar = true;

      await tocarSalir(tester);
      await tester.tap(find.byKey(const Key('confirmar-salir-evento')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.widget<OutlinedButton>(botonSalir()).onPressed, isNull);

      servicio.continuar();
      await tester.pumpAndSettle();
      expect(servicio.salidas, 1);
    });

    testWidgets('si falla por conexión, informa, sigue inscrito y permite '
        'reintentar', (WidgetTester tester) async {
      final _ServicioFalso servicio = await abrir(
        tester,
        evento: evento(),
        erroresSalir: <EventoServiceException?>[
          const EventoServiceException(
            'No se pudo completar tu salida del evento. Inténtalo de nuevo.',
            code: 'unavailable',
          ),
          null,
        ],
      );

      await tocarSalir(tester);
      await tester.tap(find.byKey(const Key('confirmar-salir-evento')));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'No se pudo completar tu salida del evento. Inténtalo de nuevo.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('evento-inscrito')), findsOneWidget);

      await tester.tap(find.widgetWithText(SnackBarAction, 'Reintentar'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirmar-salir-evento')));
      await tester.pumpAndSettle();

      expect(servicio.salidas, 2);
      expect(find.byKey(const Key('evento-inscrito')), findsNothing);
    });

    testWidgets('un error definitivo no ofrece reintentar', (
      WidgetTester tester,
    ) async {
      await abrir(
        tester,
        evento: evento(),
        erroresSalir: <EventoServiceException?>[
          const EventoServiceException(
            'Este evento ya finalizó.',
            code: 'evento-finalizado',
          ),
        ],
      );

      await tocarSalir(tester);
      await tester.tap(find.byKey(const Key('confirmar-salir-evento')));
      await tester.pumpAndSettle();

      expect(find.text('Este evento ya finalizó.'), findsOneWidget);
      expect(find.widgetWithText(SnackBarAction, 'Reintentar'), findsNothing);
    });
  });
}

/// Servicio falso con el estado del evento en [actual]: la consulta inicial
/// lo devuelve y la salida quita a 'ana' (o falla según [erroresSalir]).
class _ServicioFalso extends Fake implements EventoService {
  _ServicioFalso(this.actual);

  Evento actual;

  /// Errores de las siguientes salidas, en orden; `null` = éxito. El último
  /// se repite.
  List<EventoServiceException?> erroresSalir = <EventoServiceException?>[null];
  int salidas = 0;
  bool pausar = false;
  Completer<void>? _espera;

  void continuar() => _espera?.complete();

  @override
  Future<Evento> obtenerEvento(String eventoId) async => actual;

  @override
  Future<List<String>> salirEvento(String eventoId) async {
    salidas++;
    if (pausar) {
      _espera = Completer<void>();
      await _espera!.future;
    }
    final EventoServiceException? error = erroresSalir.length > 1
        ? erroresSalir.removeAt(0)
        : erroresSalir.first;
    if (error != null) throw error;
    actual = actual.conInscritos(<String>[
      for (final String uid in actual.inscritos)
        if (uid != 'ana') uid,
    ]);
    return actual.inscritos;
  }
}
