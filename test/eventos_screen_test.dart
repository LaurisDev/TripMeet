import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripmeet/evento_detalle_screen.dart';
import 'package:tripmeet/evento_service.dart';
import 'package:tripmeet/eventos_screen.dart';
import 'package:tripmeet/widgets/evento_guia_estilo.dart';

final Evento _conTodo = Evento(
  id: 'ev-1',
  creadorUid: 'guia-1',
  nombre: 'Tour nocturno',
  lugar: 'Cartagena',
  fechaHora: DateTime(2026, 10, 5, 18, 30),
  fechaCreacion: DateTime(2026, 9, 1),
  descripcion: 'Recorrido por la ciudad amurallada',
  imagenUrl: 'https://res.cloudinary.com/demo/evento.jpg',
);

final Evento _sinOpcionales = Evento(
  id: 'ev-2',
  creadorUid: 'guia-1',
  nombre: 'Caminata ecológica',
  lugar: 'Minca',
  fechaHora: DateTime(2026, 11, 2, 7, 5),
  fechaCreacion: DateTime(2026, 9, 1),
);

final Evento _deGuia = Evento(
  id: 'ev-3',
  creadorUid: 'guia-1',
  nombre: 'Avistamiento de aves con guía experto',
  lugar: 'Parque Tayrona',
  fechaHora: DateTime(2026, 10, 12, 6),
  fechaCreacion: DateTime(2026, 9, 1),
  descripcion: 'Salida al amanecer',
  creadoPorGuia: true,
);

const String _urlCarne =
    'https://res.cloudinary.com/pncvlky3/image/upload/v1/tripmeet/'
    'certificados/carne-guia.pdf';

final Evento _deGuiaCertificado = Evento(
  id: 'ev-4',
  creadorUid: 'guia-ok',
  nombre: 'Caminata por los paisajes de Antioquia',
  lugar: 'Antioquia',
  fechaHora: DateTime(2026, 10, 20, 8),
  fechaCreacion: DateTime(2026, 9, 1),
  descripcion: 'Ejemplo de evento creado por un guía turístico.',
  creadoPorGuia: true,
  certificadoGuia: const CertificadoGuia(
    nombre: 'carne-guia.pdf',
    url: _urlCarne,
  ),
);

/// Servicio falso: devuelve la lista y el permiso configurados, o falla.
class _ServicioFalso extends Fake implements EventoService {
  _ServicioFalso({
    this.eventos = const <Evento>[],
    this.puedeCrear = false,
    this.error,
  });

  final List<Evento> eventos;
  final bool puedeCrear;
  final EventoServiceException? error;

  @override
  Future<List<Evento>> obtenerEventosDisponibles({DateTime? desde}) async {
    if (error != null) throw error!;
    return eventos;
  }

  @override
  Future<bool> puedeCrearEventos() async => puedeCrear;
}

Future<void> _abrir(
  WidgetTester tester,
  _ServicioFalso servicio, {
  Size tamano = const Size(1080, 2340),
}) async {
  // Viewport amplio: la fuente de pruebas dibuja cada carácter como un
  // cuadrado y desborda filas que en la app real caben.
  tester.view.physicalSize = tamano;
  tester.view.devicePixelRatio = 1.5;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(home: EventosScreen(service: servicio)));
  await tester.pumpAndSettle();
}

void main() {
  group('Consulta de eventos', () {
    testWidgets('muestra nombre, lugar, fecha y hora de cada evento', (
      WidgetTester tester,
    ) async {
      await _abrir(
        tester,
        _ServicioFalso(eventos: <Evento>[_conTodo, _sinOpcionales]),
      );

      expect(find.text('Tour nocturno'), findsOneWidget);
      expect(find.text('Recorrido por la ciudad amurallada'), findsOneWidget);
      expect(find.text('Lugar: Cartagena'), findsOneWidget);
      expect(
        find.text('Fecha y hora: 5 de octubre de 2026 · 18:30'),
        findsOneWidget,
      );
      expect(find.text('Caminata ecológica'), findsOneWidget);
      expect(find.text('Lugar: Minca'), findsOneWidget);
      expect(
        find.text('Fecha y hora: 2 de noviembre de 2026 · 07:05'),
        findsOneWidget,
      );
      expect(
        find.byType(ImagenEvento),
        findsOneWidget,
        reason: 'solo el evento con imagen la muestra',
      );
    });

    testWidgets('sin eventos muestra un mensaje', (WidgetTester tester) async {
      await _abrir(tester, _ServicioFalso());

      expect(
        find.text('No hay eventos disponibles por ahora.'),
        findsOneWidget,
      );
    });

    testWidgets('si falla la consulta muestra el error', (
      WidgetTester tester,
    ) async {
      await _abrir(
        tester,
        _ServicioFalso(
          error: const EventoServiceException(
            'No se pudieron cargar los eventos. Inténtalo de nuevo.',
          ),
        ),
      );

      expect(
        find.text('No se pudieron cargar los eventos. Inténtalo de nuevo.'),
        findsOneWidget,
      );
    });
  });

  group('Detalle', () {
    testWidgets('muestra todos los datos del evento', (
      WidgetTester tester,
    ) async {
      await _abrir(tester, _ServicioFalso(eventos: <Evento>[_conTodo]));

      await tester.tap(find.text('Tour nocturno'));
      await tester.pumpAndSettle();

      expect(find.byType(EventoDetalleScreen), findsOneWidget);
      expect(find.text('Tour nocturno'), findsOneWidget);
      expect(find.text('Cartagena'), findsOneWidget);
      expect(find.text('5 de octubre de 2026'), findsOneWidget);
      expect(find.text('18:30'), findsOneWidget);
      expect(find.text('Recorrido por la ciudad amurallada'), findsOneWidget);
      expect(find.byType(ImagenEvento), findsOneWidget);
    });

    testWidgets('sin descripción ni imagen lo indica y no muestra foto', (
      WidgetTester tester,
    ) async {
      await _abrir(tester, _ServicioFalso(eventos: <Evento>[_sinOpcionales]));

      await tester.tap(find.text('Caminata ecológica'));
      await tester.pumpAndSettle();

      expect(find.text('Sin descripción.'), findsOneWidget);
      expect(find.byType(ImagenEvento), findsNothing);
    });
  });

  group('Diseño premium de eventos de guías', () {
    Finder recuadroGuia() => find.byKey(const Key('evento-recuadro-guia'));
    Finder certificado() => find.byKey(const Key('evento-certificado-guia'));

    testWidgets('solo la tarjeta del evento de un guía lleva "Premium" y el '
        'recuadro amarillo', (WidgetTester tester) async {
      await _abrir(
        tester,
        _ServicioFalso(eventos: <Evento>[_deGuia, _sinOpcionales]),
      );

      expect(recuadroGuia(), findsOneWidget);
      expect(find.byType(EtiquetaPremium), findsOneWidget);
      expect(find.text('Experiencia premium'), findsOneWidget);
      final Container recuadro = tester.widget<Container>(recuadroGuia());
      expect(
        (recuadro.decoration! as BoxDecoration).color,
        EstiloEventoGuia.fondo,
      );

      // El recuadro está en la tarjeta del guía, no en la del evento normal.
      final Finder tarjetaGuia = find.ancestor(
        of: find.text(_deGuia.nombre),
        matching: find.byType(InkWell),
      );
      expect(
        find.descendant(of: tarjetaGuia, matching: recuadroGuia()),
        findsOneWidget,
      );
      final Finder tarjetaNormal = find.ancestor(
        of: find.text(_sinOpcionales.nombre),
        matching: find.byType(InkWell),
      );
      expect(
        find.descendant(of: tarjetaNormal, matching: recuadroGuia()),
        findsNothing,
      );
    });

    testWidgets('sin certificado aprobado no afirma que el guía esté '
        'certificado', (WidgetTester tester) async {
      await _abrir(tester, _ServicioFalso(eventos: <Evento>[_deGuia]));

      expect(
        find.text('Evento publicado por un guía turístico.'),
        findsOneWidget,
      );
      expect(find.textContaining('certificado aprobado'), findsNothing);

      await tester.tap(find.text(_deGuia.nombre));
      await tester.pumpAndSettle();

      expect(find.byType(EventoDetalleScreen), findsOneWidget);
      expect(recuadroGuia(), findsOneWidget);
      expect(certificado(), findsNothing);
      expect(find.text('Ver certificado'), findsNothing);
      expect(find.textContaining('certificado aprobado'), findsNothing);
    });

    testWidgets('con certificado aprobado lo indica en la tarjeta y lo muestra '
        'en el detalle', (WidgetTester tester) async {
      await _abrir(
        tester,
        _ServicioFalso(eventos: <Evento>[_deGuiaCertificado]),
      );

      expect(
        find.text(
          'Evento publicado por un guía turístico con certificado aprobado.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text(_deGuiaCertificado.nombre));
      await tester.pumpAndSettle();

      expect(recuadroGuia(), findsOneWidget);
      expect(
        find.descendant(of: recuadroGuia(), matching: certificado()),
        findsOneWidget,
        reason: 'el certificado va dentro del recuadro amarillo',
      );
      expect(find.text('Carné de guía turístico'), findsOneWidget);
      expect(
        find.text('Certificado aprobado · carne-guia.pdf'),
        findsOneWidget,
      );
      expect(find.text('Ver certificado'), findsOneWidget);
    });

    testWidgets('"Ver certificado" abre el PDF del carné', (
      WidgetTester tester,
    ) async {
      final List<Uri> abiertos = <Uri>[];
      await tester.pumpWidget(
        MaterialApp(
          home: EventoDetalleScreen(
            evento: _deGuiaCertificado,
            abrirEnlace: (Uri enlace) async {
              abiertos.add(enlace);
              return true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Ver certificado'));
      await tester.tap(find.text('Ver certificado'));
      await tester.pumpAndSettle();

      expect(abiertos, <Uri>[Uri.parse(_urlCarne)]);
      expect(find.textContaining('No se pudo abrir'), findsNothing);
    });

    testWidgets('si el certificado no se puede abrir, lo informa', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: EventoDetalleScreen(
            evento: _deGuiaCertificado,
            abrirEnlace: (Uri enlace) async => false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Ver certificado'));
      await tester.tap(find.text('Ver certificado'));
      await tester.pumpAndSettle();

      expect(
        find.text('No se pudo abrir el certificado. Inténtalo de nuevo.'),
        findsOneWidget,
      );
    });

    testWidgets('el detalle de un evento normal no lleva el estilo', (
      WidgetTester tester,
    ) async {
      await _abrir(tester, _ServicioFalso(eventos: <Evento>[_conTodo]));

      await tester.tap(find.text(_conTodo.nombre));
      await tester.pumpAndSettle();

      expect(recuadroGuia(), findsNothing);
      expect(find.byType(EtiquetaPremium), findsNothing);
      expect(certificado(), findsNothing);
    });

    testWidgets('en pantalla angosta la tarjeta y el detalle premium no '
        'desbordan', (WidgetTester tester) async {
      // 320 px lógicos de ancho (480 / 1.5), el teléfono más angosto común.
      await _abrir(
        tester,
        _ServicioFalso(eventos: <Evento>[_deGuiaCertificado]),
        tamano: const Size(480, 1400),
      );
      expect(recuadroGuia(), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text(_deGuiaCertificado.nombre));
      await tester.pumpAndSettle();
      expect(certificado(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Cupo y precio', () {
    final Evento conCupoYPrecio = Evento(
      id: 'ev-5',
      creadorUid: 'guia-ok',
      nombre: 'Tour gastronómico',
      lugar: 'Medellín',
      fechaHora: DateTime(2026, 10, 25, 19),
      fechaCreacion: DateTime(2026, 9, 1),
      creadoPorGuia: true,
      cupoMaximo: 20,
      precio: 1250000,
    );
    final Evento gratisUnaPersona = Evento(
      id: 'ev-6',
      creadorUid: 'turista-1',
      nombre: 'Caminata libre',
      lugar: 'Envigado',
      fechaHora: DateTime(2026, 10, 26, 7),
      fechaCreacion: DateTime(2026, 9, 1),
      cupoMaximo: 1,
      precio: 0,
    );

    test('formatos', () {
      expect(formatearPrecioEvento(0), 'Gratis');
      expect(formatearPrecioEvento(500), r'$500 COP');
      expect(formatearPrecioEvento(50000), r'$50.000 COP');
      expect(formatearPrecioEvento(1250000), r'$1.250.000 COP');
      expect(formatearCupoEvento(1), '1 persona');
      expect(formatearCupoEvento(20), '20 personas');
    });

    testWidgets('la tarjeta y el detalle los muestran cuando existen', (
      WidgetTester tester,
    ) async {
      await _abrir(
        tester,
        _ServicioFalso(eventos: <Evento>[conCupoYPrecio, gratisUnaPersona]),
      );

      expect(find.text('Cupo: 20 personas'), findsOneWidget);
      expect(find.text(r'Precio: $1.250.000 COP'), findsOneWidget);
      expect(find.text('Cupo: 1 persona'), findsOneWidget);
      expect(find.text('Precio: Gratis'), findsOneWidget);

      await tester.tap(find.text('Tour gastronómico'));
      await tester.pumpAndSettle();

      expect(find.text('Cupo máximo: 20 personas'), findsOneWidget);
      expect(find.text(r'Precio: $1.250.000 COP'), findsOneWidget);
    });

    testWidgets('sin cupo ni precio no se muestran', (
      WidgetTester tester,
    ) async {
      await _abrir(tester, _ServicioFalso(eventos: <Evento>[_conTodo]));

      expect(find.textContaining('Cupo'), findsNothing);
      expect(find.textContaining('Precio'), findsNothing);

      await tester.tap(find.text(_conTodo.nombre));
      await tester.pumpAndSettle();

      expect(find.textContaining('Cupo'), findsNothing);
      expect(find.textContaining('Precio'), findsNothing);
    });
  });

  group('Permisos', () {
    testWidgets('un turista o un guía ve el botón "Crear evento"', (
      WidgetTester tester,
    ) async {
      await _abrir(tester, _ServicioFalso(puedeCrear: true));

      expect(find.text('Crear evento'), findsOneWidget);
    });

    testWidgets('quien no tiene un rol permitido no ve "Crear evento"', (
      WidgetTester tester,
    ) async {
      await _abrir(tester, _ServicioFalso(eventos: <Evento>[_conTodo]));

      expect(find.text('Crear evento'), findsNothing);
      expect(
        find.text('Tour nocturno'),
        findsOneWidget,
        reason: 'cualquiera puede consultar los eventos',
      );
    });
  });
}
