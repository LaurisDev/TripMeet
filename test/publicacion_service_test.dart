import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tripmeet/guia_service.dart' show ArchivoLocal;
import 'package:tripmeet/publicacion_service.dart';

Publicacion _publicacion({String? descripcion = 'Atardecer en Cartagena'}) =>
    Publicacion(
      id: 'pub-1',
      uid: 'autor-123',
      imagenUrl: 'https://res.cloudinary.com/demo/original.jpg',
      imagenPublicId: 'tripmeet/publicaciones/original',
      descripcion: descripcion,
      fechaCreacion: DateTime(2026, 9, 1),
    );

/// Imagen PNG mínima válida (firma binaria real) de [tamano] bytes.
ArchivoLocal _png({int tamano = 64, String extension = 'png'}) {
  final Uint8List bytes = Uint8List(tamano)
    ..setAll(0, <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  return ArchivoLocal(
    nombre: 'nueva.$extension',
    bytes: bytes,
    extension: extension,
  );
}

Matcher _lanzaCodigo(String codigo) => throwsA(
      isA<PublicacionServiceException>()
          .having((PublicacionServiceException e) => e.code, 'code', codigo),
    );

void main() {
  group('Publicacion', () {
    test('una publicación nueva no está editada y no tiene fechaEdicion', () {
      final Publicacion publicacion = _publicacion();

      expect(publicacion.editado, isFalse);
      expect(publicacion.fechaEdicion, isNull);
    });

    test('copyWith permite dejar la descripción en null', () {
      final Publicacion editada =
          _publicacion().copyWith(descripcion: () => null, editado: true);

      expect(editada.descripcion, isNull);
      expect(editada.editado, isTrue);
      expect(editada.imagenUrl, _publicacion().imagenUrl);
    });
  });

  group('PublicacionService.validarEdicion', () {
    test('el autor que cambia el texto genera un cambio real', () {
      final EdicionPublicacion edicion = PublicacionService.validarEdicion(
        actual: _publicacion(),
        uidUsuario: 'autor-123',
        descripcion: '  Atardecer en Santa Marta  ',
      );

      expect(edicion.hayCambios, isTrue);
      expect(edicion.cambiaDescripcion, isTrue);
      expect(edicion.descripcion, 'Atardecer en Santa Marta');
    });

    test('el autor que reemplaza la imagen genera un cambio real', () {
      final EdicionPublicacion edicion = PublicacionService.validarEdicion(
        actual: _publicacion(),
        uidUsuario: 'autor-123',
        descripcion: 'Atardecer en Cartagena',
        nuevaImagen: _png(),
      );

      expect(edicion.hayCambios, isTrue);
      expect(edicion.cambiaDescripcion, isFalse);
      expect(edicion.nuevaImagen, isNotNull);
    });

    test('sin cambios reales (solo espacios) no se marca como editada', () {
      final EdicionPublicacion edicion = PublicacionService.validarEdicion(
        actual: _publicacion(),
        uidUsuario: 'autor-123',
        descripcion: 'Atardecer en Cartagena   ',
      );

      expect(edicion.hayCambios, isFalse);
    });

    test('vaciar una descripción que ya era nula no es un cambio', () {
      final EdicionPublicacion edicion = PublicacionService.validarEdicion(
        actual: _publicacion(descripcion: null),
        uidUsuario: 'autor-123',
        descripcion: '   ',
      );

      expect(edicion.hayCambios, isFalse);
    });

    test('un usuario que no es el autor no puede editar (403)', () {
      expect(
        () => PublicacionService.validarEdicion(
          actual: _publicacion(),
          uidUsuario: 'otro-usuario',
          descripcion: 'Texto ajeno',
        ),
        _lanzaCodigo('permission-denied'),
      );
    });

    test('una publicación inexistente no se puede editar (404)', () {
      expect(
        () => PublicacionService.validarEdicion(
          actual: null,
          uidUsuario: 'autor-123',
          descripcion: 'Texto',
        ),
        _lanzaCodigo('not-found'),
      );
    });

    test('sin sesión iniciada no se puede editar', () {
      expect(
        () => PublicacionService.validarEdicion(
          actual: _publicacion(),
          uidUsuario: null,
          descripcion: 'Texto',
        ),
        _lanzaCodigo('user-not-authenticated'),
      );
    });

    test('rechaza una imagen nueva con formato inválido', () {
      expect(
        () => PublicacionService.validarEdicion(
          actual: _publicacion(),
          uidUsuario: 'autor-123',
          descripcion: 'Texto',
          nuevaImagen: ArchivoLocal(
            nombre: 'falsa.png',
            bytes: Uint8List(64),
            extension: 'png',
          ),
        ),
        _lanzaCodigo('imagen-invalida'),
      );
    });
  });

  group('PublicacionService.validarImagen', () {
    test('acepta un PNG válido dentro del límite', () {
      expect(PublicacionService.validarImagen(_png()), isNull);
    });

    test('rechaza una imagen de más de 5 MB', () {
      final String? error = PublicacionService.validarImagen(
        _png(tamano: tamanoMaximoImagenBytes + 1),
      );

      expect(error, contains('5 MB'));
    });

    test('rechaza una extensión no permitida', () {
      expect(PublicacionService.validarImagen(_png(extension: 'gif')),
          isNotNull);
    });
  });
}
