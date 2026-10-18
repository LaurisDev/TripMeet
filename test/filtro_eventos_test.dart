import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripmeet/evento_service.dart';
import 'package:tripmeet/eventos_screen.dart';
import 'package:tripmeet/filtro_eventos.dart';

/// Miércoles 14 de octubre de 2026, 10:00. La semana va hasta el domingo 18.
final DateTime _ahora = DateTime(2026, 10, 14, 10);

Evento _evento(
  String id,
  String nombre,
  String lugar,
  DateTime fechaHora, {
  String? categoria,
}) => Evento(
  id: id,
  creadorUid: 'creador',
  nombre: nombre,
  lugar: lugar,
  fechaHora: fechaHora,
  fechaCreacion: DateTime(2026, 9, 1),
  descripcion: categoria,
);

/// Datos de prueba: 9 eventos de distintas fechas, lugares y categorías
/// (la categoría va en la descripción, el modelo no tiene ese campo).
final List<Evento> _mock = <Evento>[
  _evento(
    '1',
    'Tour de grafitis Comuna 13',
    'Medellín',
    DateTime(2026, 10, 14, 18),
    categoria: 'Cultura',
  ),
  _evento(
    '2',
    'Paseo en lancha por el embalse',
    'Guatapé',
    DateTime(2026, 10, 16, 9),
    categoria: 'Naturaleza',
  ),
  _evento(
    '3',
    'Tour gastronómico',
    'Medellín',
    DateTime(2026, 10, 18, 19),
    categoria: 'Gastronomía',
  ),
  _evento(
    '4',
    'Tour nocturno',
    'Cartagena',
    DateTime(2026, 10, 19, 20),
    categoria: 'Cultura',
  ),
  _evento(
    '5',
    'Buceo en Taganga',
    'Santa Marta',
    DateTime(2026, 10, 25, 8),
    categoria: 'Aventura',
  ),
  _evento(
    '6',
    'Recorrido por La Candelaria',
    'Bogotá',
    DateTime(2026, 10, 31, 10),
    categoria: 'Historia',
  ),
  _evento(
    '7',
    'Caminata al cerro',
    'Medellín',
    DateTime(2026, 11, 5, 7),
    categoria: 'Naturaleza',
  ),
  _evento(
    '8',
    'Clase de cocina caribeña',
    'Cartagena',
    DateTime(2026, 11, 20, 16),
    categoria: 'Gastronomía',
  ),
  _evento(
    '9',
    'Valle de Cocora',
    'Salento',
    DateTime(2026, 12, 10, 6),
    categoria: 'Naturaleza',
  ),
];

List<String> _ids(List<Evento> eventos) => <String>[
  for (final Evento e in eventos) e.id,
];

class _ServicioFalso extends Fake implements EventoService {
  _ServicioFalso({this.puedeCrear = false});

  final bool puedeCrear;

  @override
  Future<List<Evento>> obtenerEventosDisponibles({DateTime? desde}) async =>
      _mock;

  @override
  Future<bool> puedeCrearEventos() async => puedeCrear;
}

Future<void> _abrir(WidgetTester tester, {bool puedeCrear = false}) async {
  // Viewport amplio: la fuente de pruebas dibuja cada carácter como un
  // cuadrado y desborda filas que en la app real caben.
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 1.5;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: EventosScreen(
        service: _ServicioFalso(puedeCrear: puedeCrear),
        reloj: () => _ahora,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _filtrarFecha(WidgetTester tester, String opcion) async {
  await tester.tap(find.byKey(const Key('filtro-fecha')));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(ListTile, opcion));
  await tester.pumpAndSettle();
}

Future<void> _filtrarLugar(WidgetTester tester, String lugar) async {
  await tester.tap(find.byKey(const Key('filtro-lugar')));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(ListTile, lugar));
  await tester.pumpAndSettle();
}

Finder _tarjeta(String nombre) => find.text(nombre);

void main() {
  group('FiltroEventos', () {
    test('sin filtros devuelve todos', () {
      expect(_ids(const FiltroEventos().aplicar(_mock, _ahora)), _ids(_mock));
    });

    test('Hoy, Esta semana y Este mes', () {
      expect(
        _ids(const FiltroEventos(rango: RangoFecha.hoy).aplicar(_mock, _ahora)),
        <String>['1'],
      );
      expect(
        _ids(
          const FiltroEventos(rango: RangoFecha.estaSemana)
              .aplicar(_mock, _ahora),
        ),
        <String>['1', '2', '3'],
      );
      expect(
        _ids(
          const FiltroEventos(rango: RangoFecha.esteMes).aplicar(_mock, _ahora),
        ),
        <String>['1', '2', '3', '4', '5', '6'],
      );
    });

    test('la semana termina el domingo a medianoche', () {
      final List<Evento> borde = <Evento>[
        _evento('dom', 'Domingo', 'X', DateTime(2026, 10, 18, 23, 59)),
        _evento('lun', 'Lunes', 'X', DateTime(2026, 10, 19)),
      ];
      expect(
        _ids(
          const FiltroEventos(rango: RangoFecha.estaSemana)
              .aplicar(borde, _ahora),
        ),
        <String>['dom'],
      );
    });

    test('Este mes funciona en diciembre', () {
      final List<Evento> fin = <Evento>[
        _evento('dic', 'Diciembre', 'X', DateTime(2026, 12, 31, 22)),
        _evento('ene', 'Enero', 'X', DateTime(2027, 1, 1, 8)),
      ];
      expect(
        _ids(
          const FiltroEventos(rango: RangoFecha.esteMes)
              .aplicar(fin, DateTime(2026, 12, 20)),
        ),
        <String>['dic'],
      );
    });

    test('fecha personalizada toma todo ese día', () {
      final FiltroEventos filtro = const FiltroEventos().conFecha(
        RangoFecha.personalizada,
        dia: DateTime(2026, 11, 20),
      );
      expect(_ids(filtro.aplicar(_mock, _ahora)), <String>['8']);
      expect(filtro.etiquetaFecha, '20/11/2026');
    });

    test('lugar ignora mayúsculas y espacios', () {
      expect(
        _ids(const FiltroEventos(lugar: ' medellín ').aplicar(_mock, _ahora)),
        <String>['1', '3', '7'],
      );
    });

    test('combina fecha y lugar', () {
      expect(
        _ids(
          const FiltroEventos(
            rango: RangoFecha.esteMes,
            lugar: 'Medellín',
          ).aplicar(_mock, _ahora),
        ),
        <String>['1', '3'],
      );
      expect(
        const FiltroEventos(
          rango: RangoFecha.hoy,
          lugar: 'Cartagena',
        ).aplicar(_mock, _ahora),
        isEmpty,
      );
    });

    test('lugaresDeEventos los lista una vez y en orden', () {
      expect(lugaresDeEventos(_mock), <String>[
        'Bogotá',
        'Cartagena',
        'Guatapé',
        'Medellín',
        'Salento',
        'Santa Marta',
      ]);
    });

    test('formatearResultadosEventos', () {
      expect(formatearResultadosEventos(0), '0 eventos encontrados');
      expect(formatearResultadosEventos(1), '1 evento encontrado');
      expect(formatearResultadosEventos(6), '6 eventos encontrados');
    });
  });

  group('Criterio 1: filtro aplicado', () {
    testWidgets('sin filtros muestra todos y no ofrece limpiar', (
      WidgetTester tester,
    ) async {
      await _abrir(tester);

      expect(find.byKey(const Key('eventos-filtros')), findsOneWidget);
      expect(find.text('Fecha'), findsOneWidget);
      expect(find.text('Lugar'), findsOneWidget);
      expect(find.text('9 eventos encontrados'), findsOneWidget);
      expect(find.byKey(const Key('limpiar-filtros')), findsNothing);
    });

    testWidgets('"Este mes" deja solo los eventos de octubre y resalta el '
        'chip con el valor', (WidgetTester tester) async {
      await _abrir(tester);
      await _filtrarFecha(tester, 'Este mes');

      expect(find.text('6 eventos encontrados'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('filtro-fecha')),
          matching: find.text('Este mes'),
        ),
        findsOneWidget,
      );
      final Material chip = tester.widget<Material>(
        find
            .descendant(
              of: find.byKey(const Key('filtro-fecha')),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(chip.color, isNot(Colors.white));
      expect(find.byKey(const Key('limpiar-filtros')), findsOneWidget);

      await tester.scrollUntilVisible(
        _tarjeta('Recorrido por La Candelaria'),
        300,
      );
      expect(_tarjeta('Recorrido por La Candelaria'), findsOneWidget);
      expect(_tarjeta('Caminata al cerro'), findsNothing);
      expect(_tarjeta('Valle de Cocora'), findsNothing);
    });

    testWidgets('"Hoy" y "Esta semana"', (WidgetTester tester) async {
      await _abrir(tester);

      await _filtrarFecha(tester, 'Hoy');
      expect(find.text('1 evento encontrado'), findsOneWidget);
      expect(_tarjeta('Tour de grafitis Comuna 13'), findsOneWidget);

      await _filtrarFecha(tester, 'Esta semana');
      expect(find.text('3 eventos encontrados'), findsOneWidget);
      expect(_tarjeta('Tour gastronómico'), findsOneWidget);
      expect(_tarjeta('Tour nocturno'), findsNothing);
    });

    testWidgets('fecha personalizada desde el calendario', (
      WidgetTester tester,
    ) async {
      await _abrir(tester);
      await _filtrarFecha(tester, 'Elegir fecha');

      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();
      await tester.tap(find.text('20'));
      await tester.tap(find.text('Aplicar'));
      await tester.pumpAndSettle();

      expect(find.text('20/11/2026'), findsOneWidget);
      expect(find.text('1 evento encontrado'), findsOneWidget);
      expect(_tarjeta('Clase de cocina caribeña'), findsOneWidget);
    });

    testWidgets('lugar lista las ciudades y combina con la fecha', (
      WidgetTester tester,
    ) async {
      await _abrir(tester);

      await tester.tap(find.byKey(const Key('filtro-lugar')));
      await tester.pumpAndSettle();
      for (final String lugar in lugaresDeEventos(_mock)) {
        expect(find.widgetWithText(ListTile, lugar), findsOneWidget);
      }
      await tester.tap(find.widgetWithText(ListTile, 'Medellín'));
      await tester.pumpAndSettle();

      expect(find.text('3 eventos encontrados'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('filtro-lugar')),
          matching: find.text('Medellín'),
        ),
        findsOneWidget,
      );
      expect(_tarjeta('Buceo en Taganga'), findsNothing);

      await _filtrarFecha(tester, 'Este mes');
      expect(find.text('2 eventos encontrados'), findsOneWidget);
      expect(_tarjeta('Tour de grafitis Comuna 13'), findsOneWidget);
      expect(_tarjeta('Tour gastronómico'), findsOneWidget);
      expect(_tarjeta('Caminata al cerro'), findsNothing);
    });

    testWidgets('la "x" del chip quita solo ese filtro', (
      WidgetTester tester,
    ) async {
      await _abrir(tester);
      await _filtrarLugar(tester, 'Medellín');
      await _filtrarFecha(tester, 'Hoy');
      expect(find.text('1 evento encontrado'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('filtro-fecha')),
          matching: find.byIcon(Icons.close_rounded),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Fecha'), findsOneWidget);
      expect(find.text('3 eventos encontrados'), findsOneWidget);
      expect(find.byKey(const Key('limpiar-filtros')), findsOneWidget);
    });

    testWidgets('"Limpiar filtros" vuelve a mostrar todos', (
      WidgetTester tester,
    ) async {
      await _abrir(tester);
      await _filtrarLugar(tester, 'Cartagena');
      expect(find.text('2 eventos encontrados'), findsOneWidget);

      await tester.tap(find.byKey(const Key('limpiar-filtros')));
      await tester.pumpAndSettle();

      expect(find.text('9 eventos encontrados'), findsOneWidget);
      expect(find.byKey(const Key('limpiar-filtros')), findsNothing);
    });
  });

  group('Criterio 2: filtro sin resultados', () {
    testWidgets('"Hoy" en Cartagena no tiene eventos: muestra el mensaje y '
        'permite limpiar', (WidgetTester tester) async {
      await _abrir(tester);
      await _filtrarLugar(tester, 'Cartagena');
      await _filtrarFecha(tester, 'Hoy');

      expect(find.text('0 eventos encontrados'), findsOneWidget);
      expect(find.byKey(const Key('eventos-sin-resultados')), findsOneWidget);
      expect(find.byIcon(Icons.search_off_rounded), findsOneWidget);
      expect(
        find.text('No hay eventos que coincidan con tu búsqueda'),
        findsOneWidget,
      );
      expect(_tarjeta('Tour nocturno'), findsNothing);

      await tester.tap(find.byKey(const Key('sin-resultados-limpiar')));
      await tester.pumpAndSettle();

      expect(find.text('9 eventos encontrados'), findsOneWidget);
      expect(find.byKey(const Key('eventos-sin-resultados')), findsNothing);
    });
  });

  group('Botón "Crear evento"', () {
    testWidgets('es un botón flotante que sigue visible al hacer scroll', (
      WidgetTester tester,
    ) async {
      await _abrir(tester, puedeCrear: true);

      final Finder crear = find.byKey(const Key('eventos-crear'));
      expect(
        find.ancestor(of: find.text('Crear evento'), matching: crear),
        findsOneWidget,
      );
      expect(tester.widget(crear), isA<FloatingActionButton>());
      expect(
        find.descendant(
          of: find.byKey(const Key('eventos-filtros')),
          matching: crear,
        ),
        findsNothing,
        reason: 'arriba quedan solo los filtros',
      );

      expect(
        tester.getCenter(crear).dx,
        moreOrLessEquals(tester.view.physicalSize.width / 1.5 / 2),
        reason: 'centrado abajo, lejos del botón de IA de la esquina',
      );

      await tester.scrollUntilVisible(_tarjeta('Valle de Cocora'), 300);
      expect(crear.hitTestable(), findsOneWidget);
    });
  });
}
