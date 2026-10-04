import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripmeet/publicacion_detalle_screen.dart';
import 'package:tripmeet/publicacion_service.dart';

const String _uidAutor = 'autor-123';
const String _textoOriginal = 'Atardecer en Cartagena';
const String _mensajeExito = 'Publicación eliminada correctamente.';

final Publicacion _original = Publicacion(
  id: 'pub-1',
  uid: _uidAutor,
  imagenUrl: 'https://res.cloudinary.com/demo/original.jpg',
  imagenPublicId: 'tripmeet/publicaciones/original',
  descripcion: _textoOriginal,
  fechaCreacion: DateTime(2026, 9, 1),
);

/// Servicio falso: aplica las mismas reglas de autoría que el real
/// ([PublicacionService.validarAutoria]) pero sin Firestore.
class _ServicioFalso extends Fake implements PublicacionService {
  _ServicioFalso({required this.uidUsuario, this.error});

  final String uidUsuario;
  final PublicacionServiceException? error;
  final List<String> eliminadas = <String>[];
  int llamadas = 0;

  @override
  Future<void> eliminarPublicacion(String publicacionId) async {
    llamadas++;
    if (error != null) throw error!;

    PublicacionService.validarAutoria(
      actual: publicacionId == _original.id ? _original : null,
      uidUsuario: uidUsuario,
      accion: 'eliminar',
    );
    eliminadas.add(publicacionId);
  }
}

/// Abre el detalle encima de una pantalla "Perfil" de prueba que, igual que
/// la real, avisa del éxito cuando recibe `onPublicacionEliminada`.
Future<void> _abrirDetalle(
  WidgetTester tester, {
  required String uidUsuario,
  required _ServicioFalso servicio,
  ValueChanged<String>? onEliminada,
}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 1.5;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (BuildContext context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PublicacionDetalleScreen(
                    publicacion: _original,
                    uidUsuarioActual: uidUsuario,
                    service: servicio,
                    onPublicacionEliminada: (String id) {
                      onEliminada?.call(id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text(_mensajeExito)),
                      );
                    },
                  ),
                ),
              ),
              child: const Text('Perfil'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Perfil'));
  await tester.pumpAndSettle();
}

Future<void> _tocarEliminar(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Eliminar'));
  await tester.pumpAndSettle();
}

Finder get _botonConfirmar => find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(TextButton, 'Eliminar'),
    );

void main() {
  group('Escenario 1: eliminación exitosa', () {
    testWidgets('pide confirmación, elimina, avisa y vuelve al perfil',
        (WidgetTester tester) async {
      final _ServicioFalso servicio = _ServicioFalso(uidUsuario: _uidAutor);
      String? notificada;
      await _abrirDetalle(
        tester,
        uidUsuario: _uidAutor,
        servicio: servicio,
        onEliminada: (String id) => notificada = id,
      );

      await _tocarEliminar(tester);
      expect(find.text('¿Eliminar publicación?'), findsOneWidget);
      expect(servicio.llamadas, 0,
          reason: 'no debe eliminar antes de confirmar');

      await tester.tap(_botonConfirmar);
      await tester.pumpAndSettle();

      expect(servicio.eliminadas, <String>['pub-1']);
      expect(notificada, 'pub-1');
      expect(find.byType(PublicacionDetalleScreen), findsNothing);
      expect(find.text(_mensajeExito), findsOneWidget);
    });
  });

  group('Escenario 2: cancelación', () {
    testWidgets('cancelar no elimina y la publicación sigue visible',
        (WidgetTester tester) async {
      final _ServicioFalso servicio = _ServicioFalso(uidUsuario: _uidAutor);
      String? notificada;
      await _abrirDetalle(
        tester,
        uidUsuario: _uidAutor,
        servicio: servicio,
        onEliminada: (String id) => notificada = id,
      );

      await _tocarEliminar(tester);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(servicio.llamadas, 0);
      expect(notificada, isNull);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(PublicacionDetalleScreen), findsOneWidget);
      expect(find.text(_textoOriginal), findsOneWidget);
    });
  });

  group('Escenario 3: publicación ajena', () {
    testWidgets('un usuario que no es el autor no ve el botón "Eliminar"',
        (WidgetTester tester) async {
      await _abrirDetalle(
        tester,
        uidUsuario: 'otro-usuario',
        servicio: _ServicioFalso(uidUsuario: 'otro-usuario'),
      );

      expect(find.byTooltip('Eliminar'), findsNothing);
      expect(find.text(_textoOriginal), findsOneWidget);
    });

    testWidgets(
        'si el servidor rechaza la autoría, informa y no muestra éxito',
        (WidgetTester tester) async {
      // La UI cree que es el autor, pero el servicio valida con otro uid
      // (por ejemplo, la sesión cambió): debe prevalecer el rechazo.
      final _ServicioFalso servicio =
          _ServicioFalso(uidUsuario: 'otro-usuario');
      String? notificada;
      await _abrirDetalle(
        tester,
        uidUsuario: _uidAutor,
        servicio: servicio,
        onEliminada: (String id) => notificada = id,
      );

      await _tocarEliminar(tester);
      await tester.tap(_botonConfirmar);
      await tester.pumpAndSettle();

      expect(servicio.eliminadas, isEmpty);
      expect(notificada, isNull);
      expect(find.text('Solo el autor puede eliminar esta publicación.'),
          findsOneWidget);
      expect(find.text(_mensajeExito), findsNothing);
      expect(find.byType(PublicacionDetalleScreen), findsOneWidget);
    });
  });

  group('Escenario 4: error de eliminación', () {
    testWidgets('muestra el error, se queda en el detalle y permite reintentar',
        (WidgetTester tester) async {
      final _ServicioFalso servicio = _ServicioFalso(
        uidUsuario: _uidAutor,
        error: const PublicacionServiceException(
          'No se pudo completar la operación por un problema de conexión.',
          code: 'unavailable',
        ),
      );
      String? notificada;
      await _abrirDetalle(
        tester,
        uidUsuario: _uidAutor,
        servicio: servicio,
        onEliminada: (String id) => notificada = id,
      );

      await _tocarEliminar(tester);
      await tester.tap(_botonConfirmar);
      await tester.pumpAndSettle();

      expect(servicio.llamadas, 1);
      expect(notificada, isNull);
      expect(
        find.text(
          'No se pudo completar la operación por un problema de conexión.',
        ),
        findsOneWidget,
      );
      expect(find.text(_mensajeExito), findsNothing);
      expect(find.byType(PublicacionDetalleScreen), findsOneWidget);
      expect(find.byTooltip('Eliminar'), findsOneWidget,
          reason: 'el botón vuelve a estar disponible para reintentar');
    });
  });
}
