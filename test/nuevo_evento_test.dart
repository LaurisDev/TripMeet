import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripmeet/evento_detalle_screen.dart';
import 'package:tripmeet/evento_service.dart';
import 'package:tripmeet/eventos_screen.dart';
import 'package:tripmeet/guia_service.dart' show ArchivoLocal;
import 'package:tripmeet/nuevo_evento_screen.dart';

final DateTime _ahora = DateTime(2026, 10, 3, 12);

/// Servicio falso con memoria: guarda en una lista los eventos creados (con
/// las mismas validaciones que el real) y los devuelve al consultar.
class _ServicioFalso extends Fake implements EventoService {
  _ServicioFalso({this.puedeCrear = true, this.error});

  final bool puedeCrear;
  final EventoServiceException? error;
  final List<Evento> guardados = <Evento>[];
  int llamadasCrear = 0;

  @override
  Future<bool> puedeCrearEventos() async => puedeCrear;

  @override
  Future<List<Evento>> obtenerEventosDisponibles({DateTime? desde}) async =>
      List<Evento>.of(guardados);

  @override
  Future<Evento> crearEvento({
    required String nombre,
    required String lugar,
    required DateTime? fechaHora,
    String? descripcion,
    ArchivoLocal? imagen,
    int? cupoMaximo,
    int? precio,
  }) async {
    llamadasCrear++;
    if (error != null) throw error!;
    if (!puedeCrear) {
      throw const EventoServiceException(
        'Tu cuenta no tiene un rol que permita crear eventos.',
        code: 'permission-denied',
      );
    }

    final Evento evento = Evento(
      id: 'ev-${guardados.length + 1}',
      creadorUid: 'guia-ok',
      nombre: nombre.trim(),
      lugar: lugar.trim(),
      fechaHora: fechaHora!,
      fechaCreacion: _ahora,
      descripcion: descripcion?.trim().isEmpty ?? true
          ? null
          : descripcion!.trim(),
      cupoMaximo: cupoMaximo,
      precio: precio,
    );
    guardados.add(evento);
    return evento;
  }
}

void _viewportAmplio(WidgetTester tester) {
  // La fuente de pruebas dibuja cada carácter como un cuadrado y desborda
  // filas que en la app real caben.
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 1.5;
  addTearDown(tester.view.reset);
}

Future<void> _abrirFormulario(
  WidgetTester tester,
  _ServicioFalso servicio,
) async {
  _viewportAmplio(tester);
  await tester.pumpWidget(
    MaterialApp(
      home: NuevoEventoScreen(service: servicio, reloj: () => _ahora),
    ),
  );
  await tester.pumpAndSettle();
}

/// Elige en los selectores la fecha y hora iniciales que propone el
/// formulario: mañana a la misma hora (4 de octubre de 2026, 12:00).
Future<void> _elegirFechaHoraPorDefecto(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('evento-fecha-hora')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Siguiente'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Aceptar'));
  await tester.pumpAndSettle();
}

Future<void> _llenarObligatorios(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const Key('evento-nombre')),
    'Tour nocturno',
  );
  await tester.enterText(find.byKey(const Key('evento-lugar')), 'Cartagena');
  await _elegirFechaHoraPorDefecto(tester);
}

Future<void> _tocarCrear(WidgetTester tester) async {
  final Finder boton = find.widgetWithText(FilledButton, 'Crear evento');
  await tester.ensureVisible(boton);
  await tester.tap(boton);
  await tester.pumpAndSettle();
}

void main() {
  group('Validaciones del formulario', () {
    testWidgets('sin datos muestra los errores y no crea nada', (
      WidgetTester tester,
    ) async {
      final _ServicioFalso servicio = _ServicioFalso();
      await _abrirFormulario(tester, servicio);

      await _tocarCrear(tester);

      expect(find.text('Ingresa el nombre del evento.'), findsOneWidget);
      expect(find.text('Ingresa el lugar del evento.'), findsOneWidget);
      expect(
        find.text('Selecciona la fecha y la hora del evento.'),
        findsOneWidget,
      );
      expect(servicio.llamadasCrear, 0);
    });

    testWidgets('nombre y lugar demasiado cortos muestran el error', (
      WidgetTester tester,
    ) async {
      final _ServicioFalso servicio = _ServicioFalso();
      await _abrirFormulario(tester, servicio);

      await tester.enterText(find.byKey(const Key('evento-nombre')), 'ab');
      await tester.enterText(find.byKey(const Key('evento-lugar')), ' x ');
      await _elegirFechaHoraPorDefecto(tester);
      await _tocarCrear(tester);

      expect(
        find.text('Escribe al menos 3 caracteres para el nombre del evento.'),
        findsOneWidget,
      );
      expect(
        find.text('Escribe al menos 3 caracteres para el lugar del evento.'),
        findsOneWidget,
      );
      expect(servicio.llamadasCrear, 0);
    });

    testWidgets('la fecha y hora elegidas se muestran en el campo', (
      WidgetTester tester,
    ) async {
      await _abrirFormulario(tester, _ServicioFalso());

      await _elegirFechaHoraPorDefecto(tester);

      expect(find.text('4 de octubre de 2026 · 12:00'), findsOneWidget);
    });
  });

  group('Cupo y precio (opcionales)', () {
    Future<Evento?> crearCon(
      WidgetTester tester, {
      String cupo = '',
      String precio = '',
    }) async {
      final _ServicioFalso servicio = _ServicioFalso();
      await _abrirFormulario(tester, servicio);
      await _llenarObligatorios(tester);
      await tester.enterText(find.byKey(const Key('evento-cupo')), cupo);
      await tester.enterText(find.byKey(const Key('evento-precio')), precio);
      await _tocarCrear(tester);
      return servicio.guardados.isEmpty ? null : servicio.guardados.single;
    }

    testWidgets('vacíos crean el evento sin cupo ni precio', (
      WidgetTester tester,
    ) async {
      final Evento? creado = await crearCon(tester);

      expect(creado, isNotNull);
      expect(creado!.cupoMaximo, isNull);
      expect(creado.precio, isNull);
    });

    testWidgets('con valores válidos los envía como enteros', (
      WidgetTester tester,
    ) async {
      final Evento? creado = await crearCon(
        tester,
        cupo: '25',
        precio: '50000',
      );

      expect(creado?.cupoMaximo, 25);
      expect(creado?.precio, 50000);
    });

    testWidgets('precio 0 se acepta (evento gratis)', (
      WidgetTester tester,
    ) async {
      final Evento? creado = await crearCon(tester, precio: '0');

      expect(creado?.precio, 0);
    });

    testWidgets('cupo 0 muestra el error y no crea', (
      WidgetTester tester,
    ) async {
      final Evento? creado = await crearCon(tester, cupo: '0');

      expect(
        find.text('El cupo debe estar entre 1 y 1000 personas.'),
        findsOneWidget,
      );
      expect(creado, isNull);
    });

    testWidgets('cupo y precio fuera de rango muestran sus errores', (
      WidgetTester tester,
    ) async {
      final Evento? creado = await crearCon(
        tester,
        cupo: '1001',
        precio: '50000001',
      );

      expect(
        find.text('El cupo debe estar entre 1 y 1000 personas.'),
        findsOneWidget,
      );
      expect(
        find.text(r'El precio no puede superar $50.000.000 COP.'),
        findsOneWidget,
      );
      expect(creado, isNull);
    });

    testWidgets('los campos solo aceptan dígitos', (WidgetTester tester) async {
      await _abrirFormulario(tester, _ServicioFalso());

      await tester.enterText(find.byKey(const Key('evento-cupo')), '2a5-');
      await tester.enterText(find.byKey(const Key('evento-precio')), '1.5e3');

      expect(find.text('25'), findsOneWidget);
      expect(find.text('153'), findsOneWidget);
    });
  });

  group('Creación', () {
    testWidgets('con datos válidos crea el evento y devuelve el resultado', (
      WidgetTester tester,
    ) async {
      _viewportAmplio(tester);
      final _ServicioFalso servicio = _ServicioFalso();
      Evento? devuelto;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (BuildContext context) => TextButton(
              onPressed: () async {
                devuelto = await Navigator.of(context).push<Evento>(
                  MaterialPageRoute<Evento>(
                    builder: (_) => NuevoEventoScreen(
                      service: servicio,
                      reloj: () => _ahora,
                    ),
                  ),
                );
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      await _llenarObligatorios(tester);
      await tester.enterText(
        find.byKey(const Key('evento-descripcion')),
        'Recorrido por la ciudad amurallada',
      );
      await _tocarCrear(tester);

      expect(servicio.llamadasCrear, 1);
      expect(find.byType(NuevoEventoScreen), findsNothing);
      expect(devuelto?.nombre, 'Tour nocturno');
      expect(devuelto?.lugar, 'Cartagena');
      expect(devuelto?.fechaHora, DateTime(2026, 10, 4, 12));
      expect(devuelto?.descripcion, 'Recorrido por la ciudad amurallada');
    });

    testWidgets('si falla, muestra el error y se queda en el formulario', (
      WidgetTester tester,
    ) async {
      final _ServicioFalso servicio = _ServicioFalso(
        error: const EventoServiceException(
          'No se pudo crear el evento. Inténtalo de nuevo.',
          code: 'unavailable',
        ),
      );
      await _abrirFormulario(tester, servicio);

      await _llenarObligatorios(tester);
      await _tocarCrear(tester);

      expect(servicio.llamadasCrear, 1);
      expect(
        find.text('No se pudo crear el evento. Inténtalo de nuevo.'),
        findsOneWidget,
      );
      expect(find.byType(NuevoEventoScreen), findsOneWidget);
      expect(
        find.text('Tour nocturno'),
        findsOneWidget,
        reason: 'conserva lo escrito para reintentar',
      );
    });

    testWidgets('si el servidor rechaza el permiso, lo informa', (
      WidgetTester tester,
    ) async {
      final _ServicioFalso servicio = _ServicioFalso(puedeCrear: false);
      await _abrirFormulario(tester, servicio);

      await _llenarObligatorios(tester);
      await _tocarCrear(tester);

      expect(
        find.text('Tu cuenta no tiene un rol que permita crear eventos.'),
        findsOneWidget,
      );
      expect(servicio.guardados, isEmpty);
    });
  });

  testWidgets(
    'flujo completo: crear desde Eventos, verlo en la lista y abrir su '
    'detalle',
    (WidgetTester tester) async {
      _viewportAmplio(tester);
      final _ServicioFalso servicio = _ServicioFalso();
      await tester.pumpWidget(
        MaterialApp(home: EventosScreen(service: servicio)),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('No hay eventos disponibles por ahora.'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('eventos-crear')));
      await tester.pumpAndSettle();
      expect(find.byType(NuevoEventoScreen), findsOneWidget);

      // El formulario abierto desde la lista usa el reloj real; la fecha que
      // propone por defecto (mañana a esta hora) siempre es futura.
      await tester.enterText(
        find.byKey(const Key('evento-nombre')),
        'Tour nocturno',
      );
      await tester.enterText(
        find.byKey(const Key('evento-lugar')),
        'Cartagena',
      );
      await tester.enterText(
        find.byKey(const Key('evento-descripcion')),
        'Recorrido por la ciudad amurallada',
      );
      await _elegirFechaHoraPorDefecto(tester);
      await _tocarCrear(tester);

      expect(find.byType(NuevoEventoScreen), findsNothing);
      expect(
        find.text('Evento "Tour nocturno" creado correctamente.'),
        findsOneWidget,
      );
      expect(find.text('Tour nocturno'), findsOneWidget);
      expect(find.text('Lugar: Cartagena'), findsOneWidget);

      await tester.tap(find.text('Tour nocturno'));
      await tester.pumpAndSettle();
      expect(find.byType(EventoDetalleScreen), findsOneWidget);
      expect(find.text('Recorrido por la ciudad amurallada'), findsOneWidget);
    },
  );

  testWidgets('quien no tiene un rol permitido no ve el botón para crear', (
    WidgetTester tester,
  ) async {
    _viewportAmplio(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: EventosScreen(service: _ServicioFalso(puedeCrear: false)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('eventos-crear')), findsNothing);
  });
}
