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
  group('EventoService.unirseEvento (Firestore simulado)', () {
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
      String id = 'ev',
      DateTime? fechaHora,
      int? cupo,
      List<String> inscritos = const <String>[],
    }) => firestore.collection('eventos').doc(id).set(<String, dynamic>{
      'id': id,
      'creadorUid': 'organizador',
      'nombre': 'Caminata',
      'lugar': 'Medellín',
      'fechaHora': Timestamp.fromDate(fechaHora ?? DateTime(2026, 10, 20, 8)),
      'fechaCreacion': Timestamp.fromDate(DateTime(2026, 10, 1)),
      'cupoMaximo': cupo,
      'inscritos': inscritos,
    });

    Future<List<String>> inscritosGuardados([String id = 'ev']) async {
      final Map<String, dynamic>? datos =
          (await firestore.collection('eventos').doc(id).get()).data();
      return List<String>.from(datos?['inscritos'] as List<dynamic>? ?? []);
    }

    setUp(() => firestore = FakeFirebaseFirestore());

    test('inscribe al usuario y lo guarda en el evento', () async {
      await guardarEvento(inscritos: <String>['luis']);

      final List<String> inscritos = await servicio().unirseEvento('ev');

      expect(inscritos, <String>['luis', 'ana']);
      expect(await inscritosGuardados(), <String>['luis', 'ana']);
    });

    test('la inscripción persiste: una consulta nueva la trae', () async {
      await guardarEvento();
      await servicio().unirseEvento('ev');

      final Evento leido = (await servicio(
        uid: 'otro',
      ).obtenerEventosDisponibles()).single;

      expect(leido.inscritos, <String>['ana']);
    });

    test('unirse dos veces no duplica la inscripción', () async {
      await guardarEvento();

      await servicio().unirseEvento('ev');
      final List<String> segunda = await servicio().unirseEvento('ev');

      expect(segunda, <String>['ana']);
      expect(await inscritosGuardados(), <String>['ana']);
    });

    test('ya inscrito en un evento lleno no da error', () async {
      await guardarEvento(cupo: 1, inscritos: <String>['ana']);

      expect(await servicio().unirseEvento('ev'), <String>['ana']);
    });

    test('respeta el cupo máximo', () async {
      await guardarEvento(cupo: 2, inscritos: <String>['luis']);

      await servicio().unirseEvento('ev');
      await expectLater(
        servicio(uid: 'sofia').unirseEvento('ev'),
        _lanzaCodigo('evento-lleno'),
      );
      expect(await inscritosGuardados(), <String>['luis', 'ana']);
    });

    test('sin cupo máximo no hay límite', () async {
      await guardarEvento(
        inscritos: List<String>.generate(50, (int i) => 'u$i'),
      );

      expect(await servicio().unirseEvento('ev'), hasLength(51));
    });

    test('el organizador no puede unirse a su propio evento', () async {
      await guardarEvento();

      await expectLater(
        servicio(uid: 'organizador').unirseEvento('ev'),
        _lanzaCodigo('es-creador'),
      );
      expect(await inscritosGuardados(), isEmpty);
    });

    test('no se puede unir a un evento que ya ocurrió', () async {
      await guardarEvento(fechaHora: DateTime(2026, 10, 1, 8));

      await expectLater(
        servicio().unirseEvento('ev'),
        _lanzaCodigo('evento-finalizado'),
      );
      expect(await inscritosGuardados(), isEmpty);
    });

    test('sin sesión iniciada no se puede unir', () async {
      await guardarEvento();

      await expectLater(
        servicio(uid: null).unirseEvento('ev'),
        _lanzaCodigo('user-not-authenticated'),
      );
      expect(await inscritosGuardados(), isEmpty);
    });

    test('un evento que no existe informa not-found', () async {
      await expectLater(
        servicio().unirseEvento('no-existe'),
        _lanzaCodigo('not-found'),
      );
    });

    test('si está lleno lanza EventoLlenoException con los inscritos '
        'actuales', () async {
      await guardarEvento(cupo: 2, inscritos: <String>['luis', 'sofia']);

      await expectLater(
        servicio().unirseEvento('ev'),
        throwsA(
          isA<EventoLlenoException>()
              .having(
                (EventoLlenoException e) => e.message,
                'message',
                'El evento ya no tiene cupos disponibles.',
              )
              .having(
                (EventoLlenoException e) => e.inscritos,
                'inscritos',
                <String>['luis', 'sofia'],
              ),
        ),
      );
    });

    test(
      'si hay más inscritos que cupo (cupo reducido), no se puede unir',
      () async {
        await guardarEvento(cupo: 2, inscritos: <String>['a', 'b', 'c']);

        await expectLater(
          servicio().unirseEvento('ev'),
          _lanzaCodigo('evento-lleno'),
        );
        expect(await inscritosGuardados(), <String>['a', 'b', 'c']);
      },
    );

    test('obtenerEvento trae el estado guardado del evento', () async {
      await guardarEvento(cupo: 4, inscritos: <String>['luis']);
      await servicio().unirseEvento('ev');

      final Evento leido = await servicio(uid: 'otro').obtenerEvento('ev');

      expect(leido.inscritos, <String>['luis', 'ana']);
      expect(leido.cuposDisponibles, 2);
    });

    test('obtenerEvento calcula el diseño premium desde el creador', () async {
      await firestore.collection('usuarios').doc('organizador').set(
        <String, dynamic>{'rol': 'Guía turístico'},
      );
      await guardarEvento();

      expect((await servicio().obtenerEvento('ev')).creadoPorGuia, isTrue);
    });

    test('obtenerEvento informa not-found si el evento no existe', () async {
      await expectLater(
        servicio().obtenerEvento('no-existe'),
        _lanzaCodigo('not-found'),
      );
    });

    test('unirse no modifica los demás datos del evento', () async {
      await guardarEvento(cupo: 10);
      final Map<String, dynamic>? antes =
          (await firestore.collection('eventos').doc('ev').get()).data();

      await servicio().unirseEvento('ev');

      final Map<String, dynamic>? despues =
          (await firestore.collection('eventos').doc('ev').get()).data();
      expect(despues?..remove('inscritos'), antes?..remove('inscritos'));
    });
  });

  group('Evento.cuposDisponibles', () {
    Evento conCupo(int? cupo, int inscritos) => Evento(
      id: 'ev',
      creadorUid: 'organizador',
      nombre: 'Caminata',
      lugar: 'Medellín',
      fechaHora: DateTime(2100),
      fechaCreacion: DateTime(2026),
      cupoMaximo: cupo,
      inscritos: <String>[for (int i = 0; i < inscritos; i++) 'u$i'],
    );

    test('cuenta los cupos que quedan', () {
      expect(conCupo(10, 3).cuposDisponibles, 7);
      expect(conCupo(10, 3).estaLleno, isFalse);
      expect(conCupo(3, 3).cuposDisponibles, 0);
      expect(conCupo(3, 3).estaLleno, isTrue);
    });

    test('nunca es negativo', () {
      expect(conCupo(2, 5).cuposDisponibles, 0);
      expect(conCupo(2, 5).estaLleno, isTrue);
    });

    test('sin cupo máximo no hay límite', () {
      expect(conCupo(null, 500).cuposDisponibles, isNull);
      expect(conCupo(null, 500).estaLleno, isFalse);
    });
  });

  group('Detalle del evento: botón "Unirme"', () {
    Evento evento({List<String> inscritos = const <String>[], int? cupo}) =>
        Evento(
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
      String uid = 'ana',
      EventoServiceException? error,
      Evento? estadoReal,
      EventoServiceException? errorAlAbrir,
      bool esperarConsulta = true,
    }) async {
      tester.view.physicalSize = const Size(1080, 2600);
      tester.view.devicePixelRatio = 1.5;
      addTearDown(tester.view.reset);

      final _ServicioFalso servicio = _ServicioFalso(evento, error: error)
        ..errorObtener = errorAlAbrir;
      if (estadoReal != null) servicio.actual = estadoReal;
      servicio.pausarConsulta = !esperarConsulta;
      await tester.pumpWidget(
        MaterialApp(
          home: EventoDetalleScreen(
            evento: evento,
            service: servicio,
            uidUsuarioActual: uid,
            cargarPerfil: (String uid) async => <String, dynamic>{
              'correo': '$uid@gmail.com',
              'rol': 'Turista',
            },
          ),
        ),
      );
      // Con la consulta en pausa el indicador gira sin fin: no se espera a
      // que la pantalla se estabilice.
      if (esperarConsulta) {
        await tester.pumpAndSettle();
      } else {
        await tester.pump();
      }
      return servicio;
    }

    Finder botonUnirme() => find.byKey(const Key('unirse-evento'));

    testWidgets('un usuario no inscrito ve "Unirme"', (
      WidgetTester tester,
    ) async {
      await abrir(tester, evento: evento());

      expect(find.widgetWithText(FilledButton, 'Unirme'), findsOneWidget);
      expect(find.byKey(const Key('evento-inscrito')), findsNothing);
    });

    testWidgets('al unirse confirma, muestra que está inscrito y aparece en '
        'los participantes', (WidgetTester tester) async {
      final _ServicioFalso servicio = await abrir(
        tester,
        evento: evento(cupo: 5),
      );
      expect(find.text('Participantes (0/5)'), findsOneWidget);

      await tester.ensureVisible(botonUnirme());
      await tester.tap(botonUnirme());
      await tester.pumpAndSettle();

      expect(servicio.llamadas, 1);
      expect(find.text('¡Te uniste a "Caminata"!'), findsOneWidget);
      expect(find.byKey(const Key('evento-inscrito')), findsOneWidget);
      expect(find.text('Ya estás inscrito en este evento.'), findsOneWidget);
      expect(botonUnirme(), findsNothing);
      expect(find.byKey(const Key('salir-evento')), findsOneWidget);
      expect(find.text('Participantes (1/5)'), findsOneWidget);
      expect(find.text('ana'), findsOneWidget);
    });

    testWidgets('quien ya está inscrito no ve "Unirme"', (
      WidgetTester tester,
    ) async {
      await abrir(tester, evento: evento(inscritos: <String>['ana']));

      expect(botonUnirme(), findsNothing);
      expect(find.byKey(const Key('evento-inscrito')), findsOneWidget);
    });

    testWidgets('mientras se guarda, el botón se desactiva', (
      WidgetTester tester,
    ) async {
      final _ServicioFalso servicio = await abrir(tester, evento: evento());
      servicio.pausar = true;

      await tester.ensureVisible(botonUnirme());
      await tester.tap(botonUnirme());
      await tester.pump();

      expect(tester.widget<FilledButton>(botonUnirme()).onPressed, isNull);
      expect(
        find.descendant(
          of: botonUnirme(),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );

      await tester.tap(botonUnirme());
      servicio.continuar();
      await tester.pumpAndSettle();
      expect(servicio.llamadas, 1, reason: 'un segundo toque no se envía');
    });

    testWidgets('si falla, informa y no marca al usuario como inscrito', (
      WidgetTester tester,
    ) async {
      await abrir(
        tester,
        evento: evento(cupo: 1),
        error: const EventoServiceException(
          'El evento ya no tiene cupos disponibles.',
          code: 'evento-lleno',
        ),
      );

      await tester.ensureVisible(botonUnirme());
      await tester.tap(botonUnirme());
      await tester.pumpAndSettle();

      expect(
        find.text('El evento ya no tiene cupos disponibles.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('evento-inscrito')), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Unirme'), findsOneWidget);
    });

    testWidgets('un evento lleno muestra "Evento lleno" deshabilitado', (
      WidgetTester tester,
    ) async {
      await abrir(tester, evento: evento(cupo: 1, inscritos: <String>['luis']));

      expect(find.widgetWithText(FilledButton, 'Evento lleno'), findsOneWidget);
      expect(tester.widget<FilledButton>(botonUnirme()).onPressed, isNull);
    });

    testWidgets('al unirse actualiza el conteo de participantes, sin '
        'mensaje de cupos restantes', (WidgetTester tester) async {
      await abrir(tester, evento: evento(cupo: 3, inscritos: <String>['luis']));
      expect(find.text('Participantes (1/3)'), findsOneWidget);

      await tester.ensureVisible(botonUnirme());
      await tester.tap(botonUnirme());
      await tester.pumpAndSettle();

      expect(find.text('Participantes (2/3)'), findsOneWidget);
      expect(find.textContaining('Queda'), findsNothing);
    });

    testWidgets('sin cupo máximo muestra solo el número de participantes', (
      WidgetTester tester,
    ) async {
      await abrir(tester, evento: evento(inscritos: <String>['luis']));

      expect(find.text('Participantes (1)'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Unirme'), findsOneWidget);
    });

    testWidgets('si otra persona ocupó el último cupo, informa y muestra el '
        'evento lleno', (WidgetTester tester) async {
      await abrir(
        tester,
        evento: evento(cupo: 2, inscritos: <String>['luis']),
        error: const EventoLlenoException(<String>['luis', 'sofia']),
      );
      expect(find.text('Participantes (1/2)'), findsOneWidget);

      await tester.ensureVisible(botonUnirme());
      await tester.tap(botonUnirme());
      await tester.pumpAndSettle();

      expect(
        find.text('El evento ya no tiene cupos disponibles.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(FilledButton, 'Evento lleno'), findsOneWidget);
      expect(tester.widget<FilledButton>(botonUnirme()).onPressed, isNull);
      expect(find.text('Participantes (2/2)'), findsOneWidget);
      expect(find.byKey(const Key('evento-inscrito')), findsNothing);
    });

    testWidgets('al abrir consulta el estado real: si ya estaba inscrito no '
        'ofrece "Unirme"', (WidgetTester tester) async {
      // La lista entregó un evento viejo, sin la inscripción de 'ana'.
      final _ServicioFalso servicio = await abrir(
        tester,
        evento: evento(cupo: 5),
        estadoReal: evento(cupo: 5, inscritos: <String>['ana']),
      );

      expect(servicio.consultas, 1);
      expect(botonUnirme(), findsNothing);
      expect(find.byKey(const Key('evento-inscrito')), findsOneWidget);
      expect(find.text('Participantes (1/5)'), findsOneWidget);
    });

    testWidgets('al abrir consulta el estado real: si se llenó muestra '
        '"Evento lleno"', (WidgetTester tester) async {
      await abrir(
        tester,
        evento: evento(cupo: 1),
        estadoReal: evento(cupo: 1, inscritos: <String>['luis']),
      );

      expect(find.widgetWithText(FilledButton, 'Evento lleno'), findsOneWidget);
      expect(tester.widget<FilledButton>(botonUnirme()).onPressed, isNull);
      expect(find.text('Participantes (1/1)'), findsOneWidget);
    });

    testWidgets('mientras verifica no se puede unir', (
      WidgetTester tester,
    ) async {
      final _ServicioFalso servicio = await abrir(
        tester,
        evento: evento(),
        esperarConsulta: false,
      );

      final Finder verificando = find.byKey(const Key('evento-verificando'));
      expect(verificando, findsOneWidget);
      expect(find.text('Verificando inscripción…'), findsOneWidget);
      expect(tester.widget<FilledButton>(verificando).onPressed, isNull);
      expect(botonUnirme(), findsNothing);

      servicio.continuar();
      await tester.pumpAndSettle();
      expect(verificando, findsNothing);
      expect(find.widgetWithText(FilledButton, 'Unirme'), findsOneWidget);
    });

    testWidgets('si no puede verificar, lo informa y permite reintentar', (
      WidgetTester tester,
    ) async {
      final _ServicioFalso servicio = await abrir(
        tester,
        evento: evento(),
        estadoReal: evento(inscritos: <String>['ana']),
        errorAlAbrir: const EventoServiceException(
          'No se pudo completar la operación por un problema de conexión.',
          code: 'unavailable',
        ),
      );

      expect(
        find.textContaining('No se pudo verificar tu inscripción.'),
        findsOneWidget,
      );
      final Finder reintentar = find.byKey(
        const Key('evento-reintentar-verificacion'),
      );
      expect(reintentar, findsOneWidget);

      servicio.errorObtener = null;
      await tester.ensureVisible(reintentar);
      await tester.tap(reintentar);
      await tester.pumpAndSettle();

      expect(servicio.consultas, 2);
      expect(find.textContaining('No se pudo verificar'), findsNothing);
      expect(find.byKey(const Key('evento-inscrito')), findsOneWidget);
    });

    testWidgets('si el evento ya no existe, lo indica y no ofrece unirse', (
      WidgetTester tester,
    ) async {
      await abrir(
        tester,
        evento: evento(),
        errorAlAbrir: const EventoServiceException(
          'El evento ya no existe.',
          code: 'not-found',
        ),
      );

      expect(find.text('Este evento ya no existe.'), findsOneWidget);
      expect(botonUnirme(), findsNothing);
    });

    testWidgets('un error de conexión al unirse ofrece "Reintentar" y el '
        'reintento funciona', (WidgetTester tester) async {
      final _ServicioFalso servicio = await abrir(tester, evento: evento());
      servicio.erroresUnirse = <EventoServiceException?>[
        const EventoServiceException(
          'No se pudo completar tu inscripción. Inténtalo de nuevo.',
          code: 'unavailable',
        ),
        null,
      ];

      await tester.ensureVisible(botonUnirme());
      await tester.tap(botonUnirme());
      await tester.pumpAndSettle();

      expect(
        find.text('No se pudo completar tu inscripción. Inténtalo de nuevo.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('evento-inscrito')), findsNothing);
      expect(
        tester.widget<FilledButton>(botonUnirme()).onPressed,
        isNotNull,
        reason: 'el botón vuelve a quedar disponible',
      );

      await tester.tap(find.widgetWithText(SnackBarAction, 'Reintentar'));
      await tester.pumpAndSettle();

      expect(servicio.llamadas, 2);
      expect(find.byKey(const Key('evento-inscrito')), findsOneWidget);
    });

    testWidgets('un error definitivo no ofrece "Reintentar"', (
      WidgetTester tester,
    ) async {
      await abrir(
        tester,
        evento: evento(),
        error: const EventoServiceException(
          'Este evento ya finalizó.',
          code: 'evento-finalizado',
        ),
      );

      await tester.ensureVisible(botonUnirme());
      await tester.tap(botonUnirme());
      await tester.pumpAndSettle();

      expect(find.text('Este evento ya finalizó.'), findsOneWidget);
      expect(find.widgetWithText(SnackBarAction, 'Reintentar'), findsNothing);
    });

    testWidgets('el organizador no ve "Unirme"', (WidgetTester tester) async {
      await abrir(tester, evento: evento(), uid: 'organizador');

      expect(botonUnirme(), findsNothing);
      expect(find.byKey(const Key('detalle-editar-evento')), findsOneWidget);
    });
  });
}

/// Servicio falso con el estado "real" del evento en [actual]: el detalle lo
/// consulta al abrirse y la inscripción agrega a 'ana' (sin duplicar).
class _ServicioFalso extends Fake implements EventoService {
  _ServicioFalso(Evento evento, {EventoServiceException? error})
    : actual = evento,
      erroresUnirse = <EventoServiceException?>[error];

  /// Estado guardado del evento (puede diferir del que recibe la pantalla).
  Evento actual;

  /// Errores de las siguientes inscripciones, en orden; `null` = éxito. El
  /// último se repite.
  List<EventoServiceException?> erroresUnirse;

  /// Error al consultar el evento al abrir el detalle.
  EventoServiceException? errorObtener;

  int llamadas = 0;
  int consultas = 0;
  bool pausar = false;
  bool pausarConsulta = false;
  Completer<void>? _espera;

  /// Deja terminar la operación en pausa.
  void continuar() => _espera?.complete();

  @override
  Future<Evento> obtenerEvento(String eventoId) async {
    consultas++;
    if (pausarConsulta) {
      _espera = Completer<void>();
      await _espera!.future;
    }
    if (errorObtener != null) throw errorObtener!;
    return actual;
  }

  @override
  Future<List<String>> unirseEvento(String eventoId) async {
    llamadas++;
    if (pausar) {
      _espera = Completer<void>();
      await _espera!.future;
    }
    final EventoServiceException? error = erroresUnirse.length > 1
        ? erroresUnirse.removeAt(0)
        : erroresUnirse.first;
    if (error != null) throw error;
    actual = actual.conInscritos(<String>{...actual.inscritos, 'ana'}.toList());
    return actual.inscritos;
  }
}
