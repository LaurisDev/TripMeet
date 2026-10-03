import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripmeet/guia_service.dart' show ArchivoLocal;
import 'package:tripmeet/publicacion_detalle_screen.dart';
import 'package:tripmeet/publicacion_service.dart';

const String _uidAutor = 'autor-123';
const String _textoOriginal = 'Atardecer en Cartagena';

final Publicacion _original = Publicacion(
  id: 'pub-1',
  uid: _uidAutor,
  imagenUrl: 'https://res.cloudinary.com/demo/original.jpg',
  imagenPublicId: 'tripmeet/publicaciones/original',
  descripcion: _textoOriginal,
  fechaCreacion: DateTime(2026, 9, 1),
);

/// Servicio falso: aplica las mismas reglas de negocio que el real
/// ([PublicacionService.validarEdicion]) pero sin Firestore ni Cloudinary.
class _ServicioFalso extends Fake implements PublicacionService {
  _ServicioFalso({required this.uidUsuario, this.error});

  final String uidUsuario;
  final PublicacionServiceException? error;
  int llamadas = 0;

  @override
  Future<Publicacion> editarPublicacion({
    required String publicacionId,
    String? descripcion,
    ArchivoLocal? nuevaImagen,
  }) async {
    llamadas++;
    if (error != null) throw error!;

    final EdicionPublicacion edicion = PublicacionService.validarEdicion(
      actual: _original,
      uidUsuario: uidUsuario,
      descripcion: descripcion,
      nuevaImagen: nuevaImagen,
    );
    return edicion.actual.copyWith(
      descripcion: () => edicion.descripcion,
      editado: true,
      fechaEdicion: DateTime(2026, 10, 2, 9, 30),
    );
  }
}

Future<void> _abrirDetalle(
  WidgetTester tester, {
  required String uidUsuario,
  _ServicioFalso? servicio,
  ValueChanged<Publicacion>? onActualizada,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: PublicacionDetalleScreen(
        publicacion: _original,
        uidUsuarioActual: uidUsuario,
        service: servicio ?? _ServicioFalso(uidUsuario: uidUsuario),
        onPublicacionActualizada: onActualizada,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _irAEditar(WidgetTester tester) async {
  await tester.tap(find.text('Editar'));
  await tester.pumpAndSettle();
}

FilledButton _botonGuardar(WidgetTester tester) => tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Guardar cambios'),
    );

void main() {
  group('Criterio 1: editar y guardar', () {
    testWidgets(
        'actualiza el contenido en pantalla, avisa y muestra "Editado"',
        (WidgetTester tester) async {
      Publicacion? notificada;
      final _ServicioFalso servicio = _ServicioFalso(uidUsuario: _uidAutor);
      await _abrirDetalle(
        tester,
        uidUsuario: _uidAutor,
        servicio: servicio,
        onActualizada: (Publicacion p) => notificada = p,
      );
      expect(find.text('Editado'), findsNothing);

      await _irAEditar(tester);
      expect(find.text(_textoOriginal), findsOneWidget,
          reason: 'el formulario se precarga con el texto actual');

      await tester.enterText(
        find.byKey(const Key('editar-descripcion')),
        'Atardecer en Santa Marta',
      );
      await tester.pump();
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();

      expect(servicio.llamadas, 1);
      expect(find.text('Atardecer en Santa Marta'), findsOneWidget);
      expect(find.text(_textoOriginal), findsNothing);
      expect(find.text('Editado'), findsOneWidget);
      expect(find.text('Publicación actualizada correctamente.'),
          findsOneWidget);
      expect(notificada?.descripcion, 'Atardecer en Santa Marta');
      expect(notificada?.editado, isTrue);
    });

    testWidgets('"Guardar cambios" está deshabilitado si no hay cambios',
        (WidgetTester tester) async {
      await _abrirDetalle(tester, uidUsuario: _uidAutor);
      await _irAEditar(tester);

      expect(_botonGuardar(tester).onPressed, isNull);

      await tester.enterText(
        find.byKey(const Key('editar-descripcion')),
        '$_textoOriginal   ',
      );
      await tester.pump();
      expect(_botonGuardar(tester).onPressed, isNull,
          reason: 'agregar solo espacios no cuenta como cambio');

      await tester.enterText(
        find.byKey(const Key('editar-descripcion')),
        'Otro texto',
      );
      await tester.pump();
      expect(_botonGuardar(tester).onPressed, isNotNull);
    });

    testWidgets('si falla el guardado muestra el error y no sale',
        (WidgetTester tester) async {
      await _abrirDetalle(
        tester,
        uidUsuario: _uidAutor,
        servicio: _ServicioFalso(
          uidUsuario: _uidAutor,
          error: const PublicacionServiceException(
            'No se pudo completar la operación por un problema de conexión.',
            code: 'unavailable',
          ),
        ),
      );
      await _irAEditar(tester);

      await tester.enterText(
        find.byKey(const Key('editar-descripcion')),
        'Otro texto',
      );
      await tester.pump();
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();

      expect(
        find.text(
            'No se pudo completar la operación por un problema de conexión.'),
        findsOneWidget,
      );
      expect(find.text('Editar publicación'), findsOneWidget);
    });
  });

  group('Criterio 2: editar y cancelar', () {
    testWidgets('cancelar sin cambios vuelve sin pedir confirmación',
        (WidgetTester tester) async {
      await _abrirDetalle(tester, uidUsuario: _uidAutor);
      await _irAEditar(tester);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.text('¿Descartar cambios?'), findsNothing);
      expect(find.text(_textoOriginal), findsOneWidget);
      expect(find.text('Editado'), findsNothing);
    });

    testWidgets(
        'descartar cambios deja la publicación intacta y sin "Editado"',
        (WidgetTester tester) async {
      final _ServicioFalso servicio = _ServicioFalso(uidUsuario: _uidAutor);
      await _abrirDetalle(tester, uidUsuario: _uidAutor, servicio: servicio);
      await _irAEditar(tester);

      await tester.enterText(
        find.byKey(const Key('editar-descripcion')),
        'Cambio que no quiero',
      );
      await tester.pump();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.text('¿Descartar cambios?'), findsOneWidget);
      await tester.tap(find.text('Descartar'));
      await tester.pumpAndSettle();

      expect(servicio.llamadas, 0);
      expect(find.text('Publicación'), findsOneWidget);
      expect(find.text(_textoOriginal), findsOneWidget);
      expect(find.text('Cambio que no quiero'), findsNothing);
      expect(find.text('Editado'), findsNothing);
    });

    testWidgets('"Seguir editando" conserva lo escrito en el formulario',
        (WidgetTester tester) async {
      await _abrirDetalle(tester, uidUsuario: _uidAutor);
      await _irAEditar(tester);

      await tester.enterText(
        find.byKey(const Key('editar-descripcion')),
        'Borrador',
      );
      await tester.pump();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Seguir editando'));
      await tester.pumpAndSettle();

      expect(find.text('Editar publicación'), findsOneWidget);
      expect(find.text('Borrador'), findsOneWidget);
    });
  });

  group('Autoría', () {
    testWidgets('un usuario que no es el autor no ve el botón "Editar"',
        (WidgetTester tester) async {
      await _abrirDetalle(tester, uidUsuario: 'otro-usuario');

      expect(find.text('Editar'), findsNothing);
      expect(find.text(_textoOriginal), findsOneWidget);
    });

    testWidgets('el autor sí ve el botón "Editar"',
        (WidgetTester tester) async {
      await _abrirDetalle(tester, uidUsuario: _uidAutor);

      expect(find.text('Editar'), findsOneWidget);
    });
  });

  testWidgets('una publicación ya editada muestra "Editado" con tooltip',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PublicacionDetalleScreen(
          publicacion: _original.copyWith(
            editado: true,
            fechaEdicion: DateTime(2026, 10, 2, 9, 30),
          ),
          uidUsuarioActual: 'otro-usuario',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Editado'), findsOneWidget);
    expect(
      find.byTooltip('Editado el 2 de octubre de 2026 a las 09:30'),
      findsOneWidget,
    );
  });
}
