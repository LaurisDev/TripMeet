import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripmeet/feed_publicaciones_screen.dart';
import 'package:tripmeet/publicacion_detalle_screen.dart';
import 'package:tripmeet/publicacion_service.dart';

const String _yo = 'yo';
final DateTime _ahora = DateTime(2026, 10, 5, 12);

Publicacion _publicacion(String id, String uid, DateTime fecha) => Publicacion(
  id: id,
  uid: uid,
  imagenUrl: 'https://res.cloudinary.com/demo/$id.jpg',
  imagenPublicId: 'tripmeet/publicaciones/$id',
  descripcion: 'Descripción de $id',
  fechaCreacion: fecha,
);

const AutorPublicacion _autorYo = AutorPublicacion(
  uid: _yo,
  alias: 'julia',
  rol: 'Turista',
);
const AutorPublicacion _autorGuia = AutorPublicacion(
  uid: 'guia',
  alias: 'carlos.guia',
  rol: 'Guía turístico',
);

PublicacionEnFeed _item(
  String id,
  AutorPublicacion autor, {
  DateTime? fecha,
  int likes = 0,
  bool meGusta = false,
}) => PublicacionEnFeed(
  publicacion: _publicacion(id, autor.uid, fecha ?? DateTime(2026, 10, 1)),
  autor: autor,
  totalMeGusta: likes,
  meGusta: meGusta,
);

/// Servicio falso: entrega [todas] en páginas de [tamanoPagina] y registra
/// los "me gusta" y las eliminaciones.
class _ServicioFalso extends Fake implements PublicacionService {
  _ServicioFalso(
    this.todas, {
    this.tamanoPagina = 10,
    this.errorFeed,
    this.errorMeGusta,
  });

  final List<PublicacionEnFeed> todas;
  final int tamanoPagina;
  final PublicacionServiceException? errorFeed;
  final PublicacionServiceException? errorMeGusta;
  final List<(String, bool)> cambiosMeGusta = <(String, bool)>[];
  final List<String> eliminadas = <String>[];
  int paginasPedidas = 0;
  int _entregadas = 0;

  @override
  Future<PaginaFeed> obtenerFeed({
    DocumentSnapshot<Map<String, dynamic>>? despuesDe,
    int limite = PublicacionService.tamanoPaginaFeed,
  }) async {
    if (errorFeed != null) throw errorFeed!;
    paginasPedidas++;
    final List<PublicacionEnFeed> pagina = todas
        .skip(_entregadas)
        .take(tamanoPagina)
        .toList();
    _entregadas += pagina.length;
    return PaginaFeed(
      publicaciones: pagina,
      cursor: null,
      hayMas: _entregadas < todas.length,
    );
  }

  @override
  Future<int> cambiarMeGusta({
    required String publicacionId,
    required bool meGusta,
  }) async {
    cambiosMeGusta.add((publicacionId, meGusta));
    if (errorMeGusta != null) throw errorMeGusta!;
    final PublicacionEnFeed item = todas.firstWhere(
      (PublicacionEnFeed p) => p.publicacion.id == publicacionId,
    );
    return item.totalMeGusta + (meGusta ? 1 : 0) - (item.meGusta ? 1 : 0);
  }

  @override
  Future<void> eliminarPublicacion(String publicacionId) async {
    eliminadas.add(publicacionId);
  }
}

Future<void> _abrir(WidgetTester tester, PublicacionService servicio) async {
  // Viewport amplio: la fuente de pruebas dibuja cada carácter como un
  // cuadrado y desborda filas que en la app real caben.
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1.5;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: FeedPublicacionesScreen(
        service: servicio,
        uidUsuarioActual: _yo,
        reloj: () => _ahora,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _tarjeta(String id) => find.byKey(ValueKey<String>('feed-$id'));

void main() {
  group('Fecha relativa', () {
    test('formatos', () {
      expect(
        fechaRelativaPublicacion(_ahora, ahora: _ahora),
        'Hace un momento',
      );
      expect(
        fechaRelativaPublicacion(
          _ahora.subtract(const Duration(minutes: 5)),
          ahora: _ahora,
        ),
        'Hace 5 min',
      );
      expect(
        fechaRelativaPublicacion(
          _ahora.subtract(const Duration(hours: 3)),
          ahora: _ahora,
        ),
        'Hace 3 h',
      );
      expect(
        fechaRelativaPublicacion(
          _ahora.subtract(const Duration(days: 2)),
          ahora: _ahora,
        ),
        'Hace 2 d',
      );
      expect(
        fechaRelativaPublicacion(DateTime(2026, 9, 12), ahora: _ahora),
        '12 sep 2026',
      );
    });
  });

  group('Feed', () {
    testWidgets('muestra las publicaciones propias y las de otros con su '
        'autor y rol', (WidgetTester tester) async {
      await _abrir(
        tester,
        _ServicioFalso(<PublicacionEnFeed>[
          _item('del-guia', _autorGuia, likes: 3),
          _item('mia', _autorYo, likes: 1, meGusta: true),
        ]),
      );

      expect(_tarjeta('del-guia'), findsOneWidget);
      expect(_tarjeta('mia'), findsOneWidget);

      Finder dentro(String id, Finder f) =>
          find.descendant(of: _tarjeta(id), matching: f);
      expect(dentro('del-guia', find.text('carlos.guia')), findsOneWidget);
      expect(dentro('del-guia', find.text('Guía turístico')), findsOneWidget);
      expect(dentro('del-guia', find.text('3 me gusta')), findsOneWidget);
      expect(dentro('mia', find.text('julia')), findsOneWidget);
      expect(dentro('mia', find.text('Turista')), findsOneWidget);
      expect(dentro('mia', find.text('1 me gusta')), findsOneWidget);
      expect(
        dentro('mia', find.textContaining('Descripción de mia')),
        findsOneWidget,
      );
    });

    testWidgets('las publicaciones van una debajo de otra, en el orden del '
        'servicio', (WidgetTester tester) async {
      await _abrir(
        tester,
        _ServicioFalso(<PublicacionEnFeed>[
          _item('primera', _autorGuia),
          _item('segunda', _autorYo),
        ]),
      );

      final double yPrimera = tester.getTopLeft(_tarjeta('primera')).dy;
      final double ySegunda = tester.getTopLeft(_tarjeta('segunda')).dy;
      expect(ySegunda, greaterThan(yPrimera));
    });

    testWidgets('al desplazarse carga más publicaciones hasta el final', (
      WidgetTester tester,
    ) async {
      final _ServicioFalso servicio = _ServicioFalso(<PublicacionEnFeed>[
        for (int i = 0; i < 12; i++)
          _item('p$i', i.isEven ? _autorYo : _autorGuia),
      ], tamanoPagina: 5);
      await _abrir(tester, servicio);
      expect(servicio.paginasPedidas, 1);

      await tester.dragUntilVisible(
        find.text('Ya viste todas las publicaciones.'),
        find.byType(ListView),
        const Offset(0, -800),
      );
      await tester.pumpAndSettle();

      expect(servicio.paginasPedidas, 3);
      expect(_tarjeta('p11'), findsOneWidget);
    });

    testWidgets('sin publicaciones muestra un mensaje', (
      WidgetTester tester,
    ) async {
      await _abrir(tester, _ServicioFalso(<PublicacionEnFeed>[]));

      expect(
        find.text('Todavía no hay publicaciones. ¡Comparte la primera!'),
        findsOneWidget,
      );
    });

    testWidgets('si falla la carga muestra el error', (
      WidgetTester tester,
    ) async {
      await _abrir(
        tester,
        _ServicioFalso(
          <PublicacionEnFeed>[],
          errorFeed: const PublicacionServiceException(
            'No se pudo completar la operación por un problema de conexión.',
          ),
        ),
      );

      expect(
        find.text(
          'No se pudo completar la operación por un problema de conexión.',
        ),
        findsOneWidget,
      );
    });
  });

  group('Presentación de cada publicación', () {
    testWidgets('solo mis publicaciones llevan "Tú" y el botón de opciones', (
      WidgetTester tester,
    ) async {
      await _abrir(
        tester,
        _ServicioFalso(<PublicacionEnFeed>[
          _item('del-guia', _autorGuia),
          _item('mia', _autorYo),
        ]),
      );

      Finder dentro(String id, Finder f) =>
          find.descendant(of: _tarjeta(id), matching: f);
      expect(dentro('mia', find.text('Tú')), findsOneWidget);
      expect(find.byKey(const Key('feed-opciones-mia')), findsOneWidget);
      expect(dentro('del-guia', find.text('Tú')), findsNothing);
      expect(find.byKey(const Key('feed-opciones-del-guia')), findsNothing);
    });

    testWidgets('el botón de opciones abre el detalle con Editar', (
      WidgetTester tester,
    ) async {
      await _abrir(
        tester,
        _ServicioFalso(<PublicacionEnFeed>[_item('mia', _autorYo)]),
      );

      await tester.tap(find.byKey(const Key('feed-opciones-mia')));
      await tester.pumpAndSettle();

      expect(find.byType(PublicacionDetalleScreen), findsOneWidget);
      expect(find.text('Editar'), findsOneWidget);
    });

    testWidgets('muestra la fecha relativa y "Editado" si se editó', (
      WidgetTester tester,
    ) async {
      final PublicacionEnFeed editada = PublicacionEnFeed(
        publicacion: _publicacion(
          'editada',
          'guia',
          _ahora.subtract(const Duration(hours: 3)),
        ).copyWith(editado: true, fechaEdicion: _ahora),
        autor: _autorGuia,
        totalMeGusta: 0,
        meGusta: false,
      );
      await _abrir(tester, _ServicioFalso(<PublicacionEnFeed>[editada]));

      expect(find.text('Hace 3 h'), findsOneWidget);
      expect(find.text('Editado'), findsOneWidget);
      expect(find.byTooltip('Editado: hace un momento'), findsOneWidget);
    });

    testWidgets('una descripción larga se recorta y "más" la muestra '
        'completa', (WidgetTester tester) async {
      final String larga = List<String>.filled(60, 'palabra').join(' ');
      final PublicacionEnFeed item = PublicacionEnFeed(
        publicacion: Publicacion(
          id: 'larga',
          uid: 'guia',
          imagenUrl: 'https://res.cloudinary.com/demo/larga.jpg',
          imagenPublicId: 'x',
          descripcion: larga,
          fechaCreacion: DateTime(2026, 10, 1),
        ),
        autor: _autorGuia,
        totalMeGusta: 0,
        meGusta: false,
      );
      await _abrir(tester, _ServicioFalso(<PublicacionEnFeed>[item]));

      final Finder descripcion = find.textContaining('palabra');
      expect(tester.widget<Text>(descripcion).maxLines, 3);

      await tester.tap(find.text('más'));
      await tester.pumpAndSettle();

      expect(find.text('más'), findsNothing);
      expect(tester.widget<Text>(descripcion).maxLines, isNull);
    });

    testWidgets('las tarjetas quedan separadas entre sí', (
      WidgetTester tester,
    ) async {
      await _abrir(
        tester,
        _ServicioFalso(<PublicacionEnFeed>[
          _item('primera', _autorGuia),
          _item('segunda', _autorYo),
        ]),
      );

      final double finPrimera = tester.getBottomLeft(_tarjeta('primera')).dy;
      final double inicioSegunda = tester.getTopLeft(_tarjeta('segunda')).dy;
      expect(inicioSegunda, greaterThanOrEqualTo(finPrimera));
      final Container tarjeta = tester.widget<Container>(
        find
            .descendant(
              of: _tarjeta('primera'),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(tarjeta.margin?.vertical, greaterThan(0));
    });

    for (final (String nombre, Size tamano) in <(String, Size)>[
      ('teléfono angosto (320 px)', const Size(480, 2000)),
      ('tableta (1200 px)', const Size(1800, 2000)),
    ]) {
      testWidgets('en $nombre no desborda y no supera 560 px de ancho', (
        WidgetTester tester,
      ) async {
        tester.view.physicalSize = tamano;
        tester.view.devicePixelRatio = 1.5;
        addTearDown(tester.view.reset);
        final PublicacionEnFeed largo = _item(
          'nombre-largo',
          const AutorPublicacion(
            uid: 'x',
            alias: 'un.alias.muy.muy.largo.de.correo.electronico',
            rol: 'Guía turístico',
          ),
          likes: 1234,
        );
        await tester.pumpWidget(
          MaterialApp(
            home: FeedPublicacionesScreen(
              service: _ServicioFalso(<PublicacionEnFeed>[largo]),
              uidUsuarioActual: 'x',
              reloj: () => _ahora,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(
          tester.getSize(find.byType(AspectRatio).first).width,
          lessThanOrEqualTo(560),
        );
      });
    }
  });

  testWidgets('una página pedida antes de recargar no se mezcla con la '
      'lista recargada', (WidgetTester tester) async {
    final _ServicioConPausa servicio = _ServicioConPausa();
    await _abrir(tester, servicio);
    expect(_tarjeta('nueva-0'), findsOneWidget);

    // Se pide la página siguiente, que queda en espera.
    await tester.ensureVisible(find.byKey(const Key('feed-ver-mas')));
    await tester.tap(find.byKey(const Key('feed-ver-mas')));
    await tester.pump();
    expect(servicio.pendiente, isNotNull);

    // Mientras tanto, el usuario recarga el feed.
    await tester.fling(find.byType(ListView), const Offset(0, 2000), 1000);
    await tester.pumpAndSettle();
    expect(servicio.recargas, 2);

    // Llega tarde la página vieja: debe descartarse.
    servicio.pendiente!.complete();
    await tester.pumpAndSettle();
    expect(_tarjeta('vieja'), findsNothing);
    expect(_tarjeta('nueva-0'), findsOneWidget);
  });

  group('Me gusta', () {
    testWidgets('el corazón da y quita "me gusta" y actualiza el total', (
      WidgetTester tester,
    ) async {
      final _ServicioFalso servicio = _ServicioFalso(<PublicacionEnFeed>[
        _item('foto', _autorGuia, likes: 2),
      ]);
      await _abrir(tester, servicio);

      await tester.tap(find.byKey(const Key('feed-me-gusta-foto')));
      await tester.pumpAndSettle();
      expect(find.text('3 me gusta'), findsOneWidget);
      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);

      await tester.tap(find.byKey(const Key('feed-me-gusta-foto')));
      await tester.pumpAndSettle();
      expect(find.text('2 me gusta'), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);

      expect(servicio.cambiosMeGusta, <(String, bool)>[
        ('foto', true),
        ('foto', false),
      ]);
    });

    testWidgets('doble toque en la foto da "me gusta"', (
      WidgetTester tester,
    ) async {
      final _ServicioFalso servicio = _ServicioFalso(<PublicacionEnFeed>[
        _item('foto', _autorGuia),
      ]);
      await _abrir(tester, servicio);

      final Finder foto = find.descendant(
        of: _tarjeta('foto'),
        matching: find.byType(AspectRatio),
      );
      await tester.tap(foto);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(foto);
      await tester.pumpAndSettle();

      expect(servicio.cambiosMeGusta, <(String, bool)>[('foto', true)]);
      expect(find.text('1 me gusta'), findsOneWidget);
      expect(find.byType(PublicacionDetalleScreen), findsNothing);
    });

    testWidgets('si falla, revierte el cambio y avisa', (
      WidgetTester tester,
    ) async {
      await _abrir(
        tester,
        _ServicioFalso(
          <PublicacionEnFeed>[_item('foto', _autorGuia, likes: 2)],
          errorMeGusta: const PublicacionServiceException(
            'No se pudo completar la operación por un problema de conexión.',
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('feed-me-gusta-foto')));
      await tester.pumpAndSettle();

      expect(find.text('2 me gusta'), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
      expect(
        find.text(
          'No se pudo completar la operación por un problema de conexión.',
        ),
        findsOneWidget,
      );
    });
  });

  group('Detalle desde el feed', () {
    testWidgets('en mi publicación puedo editar y eliminar; al eliminar '
        'desaparece del feed', (WidgetTester tester) async {
      final _ServicioFalso servicio = _ServicioFalso(<PublicacionEnFeed>[
        _item('del-guia', _autorGuia),
        _item('mia', _autorYo),
      ]);
      await _abrir(tester, servicio);

      await tester.tap(
        find.descendant(
          of: _tarjeta('mia'),
          matching: find.byType(AspectRatio),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PublicacionDetalleScreen), findsOneWidget);
      expect(find.text('Editar'), findsOneWidget);

      await tester.tap(find.byTooltip('Eliminar'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(TextButton, 'Eliminar'),
        ),
      );
      await tester.pumpAndSettle();

      expect(servicio.eliminadas, <String>['mia']);
      expect(find.byType(PublicacionDetalleScreen), findsNothing);
      expect(_tarjeta('mia'), findsNothing);
      expect(_tarjeta('del-guia'), findsOneWidget);
      expect(find.text('Publicación eliminada correctamente.'), findsOneWidget);
    });

    testWidgets('en la publicación de otro no puedo editar ni eliminar', (
      WidgetTester tester,
    ) async {
      await _abrir(
        tester,
        _ServicioFalso(<PublicacionEnFeed>[_item('del-guia', _autorGuia)]),
      );

      await tester.tap(
        find.descendant(
          of: _tarjeta('del-guia'),
          matching: find.byType(AspectRatio),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PublicacionDetalleScreen), findsOneWidget);
      expect(find.text('Editar'), findsNothing);
      expect(find.byTooltip('Eliminar'), findsNothing);
    });
  });
}

/// Servicio cuya segunda página (con cursor) queda en espera hasta completar
/// [pendiente]; cada página inicial cuenta como una recarga.
class _ServicioConPausa extends Fake implements PublicacionService {
  int recargas = 0;
  Completer<void>? pendiente;

  @override
  Future<PaginaFeed> obtenerFeed({
    DocumentSnapshot<Map<String, dynamic>>? despuesDe,
    int limite = PublicacionService.tamanoPaginaFeed,
  }) async {
    if (recargas > 0 && pendiente == null) {
      // Página siguiente: espera y devuelve una publicación "vieja".
      pendiente = Completer<void>();
      await pendiente!.future;
      return PaginaFeed(
        publicaciones: <PublicacionEnFeed>[_item('vieja', _autorGuia)],
        cursor: null,
        hayMas: false,
      );
    }
    recargas++;
    return PaginaFeed(
      publicaciones: <PublicacionEnFeed>[_item('nueva-0', _autorYo)],
      cursor: null,
      hayMas: true,
    );
  }
}
