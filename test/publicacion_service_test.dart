import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mock_exceptions/mock_exceptions.dart';
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

  group('PublicacionService.validarAutoria (eliminar)', () {
    test('el autor puede eliminar su publicación', () {
      final Publicacion actual = _publicacion();

      expect(
        PublicacionService.validarAutoria(
          actual: actual,
          uidUsuario: 'autor-123',
          accion: 'eliminar',
        ),
        same(actual),
      );
    });

    test('un usuario que no es el autor no puede eliminar (403)', () {
      expect(
        () => PublicacionService.validarAutoria(
          actual: _publicacion(),
          uidUsuario: 'otro-usuario',
          accion: 'eliminar',
        ),
        _lanzaCodigo('permission-denied'),
      );
    });

    test('una publicación inexistente no se puede eliminar (404)', () {
      expect(
        () => PublicacionService.validarAutoria(
          actual: null,
          uidUsuario: 'autor-123',
          accion: 'eliminar',
        ),
        _lanzaCodigo('not-found'),
      );
    });

    test('sin sesión iniciada no se puede eliminar', () {
      expect(
        () => PublicacionService.validarAutoria(
          actual: _publicacion(),
          uidUsuario: null,
          accion: 'eliminar',
        ),
        _lanzaCodigo('user-not-authenticated'),
      );
    });
  });

  group('PublicacionService.eliminarPublicacion (Firestore simulado)', () {
    late FakeFirebaseFirestore firestore;

    PublicacionService servicio({String? uid = 'autor-123'}) =>
        PublicacionService(
          auth: MockFirebaseAuth(
            signedIn: uid != null,
            mockUser: MockUser(uid: uid ?? 'sin-sesion'),
          ),
          firestore: firestore,
        );

    Future<void> guardar(String id, String uid, DateTime fecha) =>
        firestore.collection('publicaciones').doc(id).set(<String, dynamic>{
          'id': id,
          'uid': uid,
          'imagenUrl': 'https://res.cloudinary.com/demo/$id.jpg',
          'imagenPublicId': 'tripmeet/publicaciones/$id',
          'descripcion': 'Foto $id',
          'fechaCreacion': Timestamp.fromDate(fecha),
          'editado': false,
          'fechaEdicion': null,
        });

    Future<bool> existe(String id) async =>
        (await firestore.collection('publicaciones').doc(id).get()).exists;

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      await guardar('pub-1', 'autor-123', DateTime(2026, 9, 1));
      await guardar('pub-2', 'autor-123', DateTime(2026, 9, 2));
      await guardar('pub-ajena', 'otro-usuario', DateTime(2026, 9, 3));
    });

    test('el autor elimina su publicación y ya no aparece al consultar',
        () async {
      await servicio().eliminarPublicacion('pub-1');

      expect(await existe('pub-1'), isFalse);
      final List<Publicacion> restantes =
          await servicio().obtenerPublicacionesDeUsuario('autor-123');
      expect(
        restantes.map((Publicacion p) => p.id),
        <String>['pub-2'],
        reason: 'la consulta posterior no debe devolver la eliminada',
      );
    });

    test('no elimina una publicación de otro usuario', () async {
      await expectLater(
        servicio().eliminarPublicacion('pub-ajena'),
        _lanzaCodigo('permission-denied'),
      );

      expect(await existe('pub-ajena'), isTrue);
    });

    test('sin sesión iniciada no elimina nada', () async {
      await expectLater(
        servicio(uid: null).eliminarPublicacion('pub-1'),
        _lanzaCodigo('user-not-authenticated'),
      );

      expect(await existe('pub-1'), isTrue);
    });

    test('una publicación que ya no existe informa not-found', () async {
      await expectLater(
        servicio().eliminarPublicacion('no-existe'),
        _lanzaCodigo('not-found'),
      );
    });

    test('si Firestore falla, informa el error y la publicación se conserva',
        () async {
      final DocumentReference<Map<String, dynamic>> documento =
          firestore.collection('publicaciones').doc('pub-1');
      whenCalling(Invocation.method(#delete, null))
          .on(documento)
          .thenThrow(FirebaseException(plugin: 'firestore', code: 'unavailable'));

      await expectLater(
        servicio().eliminarPublicacion('pub-1'),
        throwsA(
          isA<PublicacionServiceException>()
              .having((PublicacionServiceException e) => e.code, 'code',
                  'unavailable')
              .having((PublicacionServiceException e) => e.message, 'message',
                  contains('conexión')),
        ),
      );
      expect(await existe('pub-1'), isTrue);
    });
  });
}
