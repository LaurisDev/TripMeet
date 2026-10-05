import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripmeet/publicacion_service.dart';

void main() {
  late FakeFirebaseFirestore firestore;

  PublicacionService servicio({String? uid = 'yo'}) => PublicacionService(
    auth: MockFirebaseAuth(
      signedIn: uid != null,
      mockUser: MockUser(uid: uid ?? 'sin-sesion'),
    ),
    firestore: firestore,
  );

  Future<void> publicar(String id, String uid, DateTime fecha) =>
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

  Future<void> darMeGusta(String publicacionId, String uid) => firestore
      .collection('publicaciones')
      .doc(publicacionId)
      .collection('likes')
      .doc(uid)
      .set(<String, dynamic>{'uid': uid});

  Matcher lanzaCodigo(String codigo) => throwsA(
    isA<PublicacionServiceException>().having(
      (PublicacionServiceException e) => e.code,
      'code',
      codigo,
    ),
  );

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    await firestore.collection('usuarios').doc('yo').set(<String, dynamic>{
      'correo': 'julia@gmail.com',
      'rol': 'Turista',
    });
    await firestore.collection('usuarios').doc('guia').set(<String, dynamic>{
      'correo': 'carlos.guia@correo.com',
      'rol': 'Guía turístico',
    });
  });

  group('AutorPublicacion', () {
    test('el alias es la parte del correo antes de la @', () {
      expect(AutorPublicacion.aliasDesdeCorreo('julia@gmail.com'), 'julia');
      expect(AutorPublicacion.aliasDesdeCorreo(' ana.m@x.co '), 'ana.m');
      expect(AutorPublicacion.aliasDesdeCorreo('@x.co'), 'Usuario');
      expect(AutorPublicacion.aliasDesdeCorreo(null), 'Usuario');
      expect(AutorPublicacion.aliasDesdeCorreo(42), 'Usuario');
    });

    test('solo muestra roles conocidos', () {
      expect(
        AutorPublicacion.desdePerfil('u', <String, dynamic>{
          'rol': 'Guía turístico',
        }).rol,
        'Guía turístico',
      );
      expect(
        AutorPublicacion.desdePerfil('u', <String, dynamic>{
          'rol': 'Administrador',
        }).rol,
        isNull,
      );
      expect(AutorPublicacion.desdePerfil('u', null).rol, isNull);
    });
  });

  group('Feed', () {
    test('incluye las publicaciones propias y las de otros, de la más '
        'reciente a la más antigua', () async {
      await publicar('mia-vieja', 'yo', DateTime(2026, 9, 1));
      await publicar('del-guia', 'guia', DateTime(2026, 9, 3));
      await publicar('mia-nueva', 'yo', DateTime(2026, 9, 5));

      final PaginaFeed pagina = await servicio().obtenerFeed();

      expect(
        pagina.publicaciones.map((PublicacionEnFeed p) => p.publicacion.id),
        <String>['mia-nueva', 'del-guia', 'mia-vieja'],
      );
      expect(pagina.hayMas, isFalse);
    });

    test('cada publicación muestra el alias y el rol de su autor', () async {
      await publicar('mia', 'yo', DateTime(2026, 9, 1));
      await publicar('del-guia', 'guia', DateTime(2026, 9, 2));

      final Map<String, AutorPublicacion> autores = <String, AutorPublicacion>{
        for (final PublicacionEnFeed p
            in (await servicio().obtenerFeed()).publicaciones)
          p.publicacion.id: p.autor,
      };

      expect(autores['mia']?.alias, 'julia');
      expect(autores['mia']?.rol, 'Turista');
      expect(autores['del-guia']?.alias, 'carlos.guia');
      expect(autores['del-guia']?.rol, 'Guía turístico');
    });

    test('un autor sin perfil se muestra como "Usuario" sin rol', () async {
      await publicar('huerfana', 'no-existe', DateTime(2026, 9, 1));

      final AutorPublicacion autor =
          (await servicio().obtenerFeed()).publicaciones.single.autor;

      expect(autor.alias, 'Usuario');
      expect(autor.rol, isNull);
    });

    test('pagina de 10 en 10 sin repetir ni saltarse publicaciones', () async {
      for (int i = 0; i < 25; i++) {
        await publicar(
          'p$i',
          i.isEven ? 'yo' : 'guia',
          DateTime(2026, 9, 1).add(Duration(hours: i)),
        );
      }

      final List<String> vistas = <String>[];
      final List<bool> hayMas = <bool>[];
      PaginaFeed? pagina;
      do {
        pagina = await servicio().obtenerFeed(despuesDe: pagina?.cursor);
        vistas.addAll(
          pagina.publicaciones.map((PublicacionEnFeed p) => p.publicacion.id),
        );
        hayMas.add(pagina.hayMas);
      } while (pagina.hayMas);

      expect(hayMas, <bool>[true, true, false]);
      expect(vistas, <String>[for (int i = 24; i >= 0; i--) 'p$i']);
    });

    test(
      'trae el total de "me gusta" y si el usuario actual dio "me gusta"',
      () async {
        await publicar('popular', 'guia', DateTime(2026, 9, 2));
        await publicar('sin-likes', 'yo', DateTime(2026, 9, 1));
        await darMeGusta('popular', 'yo');
        await darMeGusta('popular', 'guia');
        await darMeGusta('popular', 'otro');

        final Map<String, PublicacionEnFeed> feed = <String, PublicacionEnFeed>{
          for (final PublicacionEnFeed p
              in (await servicio().obtenerFeed()).publicaciones)
            p.publicacion.id: p,
        };

        expect(feed['popular']?.totalMeGusta, 3);
        expect(feed['popular']?.meGusta, isTrue);
        expect(feed['sin-likes']?.totalMeGusta, 0);
        expect(feed['sin-likes']?.meGusta, isFalse);

        final PublicacionEnFeed vistoPorGuia = (await servicio(
          uid: 'turista-2',
        ).obtenerFeed()).publicaciones.first;
        expect(vistoPorGuia.meGusta, isFalse);
      },
    );

    test('las publicaciones propias siguen consultándose como antes', () async {
      await publicar('mia', 'yo', DateTime(2026, 9, 1));
      await publicar('del-guia', 'guia', DateTime(2026, 9, 2));

      final List<Publicacion> mias = await servicio()
          .obtenerPublicacionesDeUsuario('yo');

      expect(mias.map((Publicacion p) => p.id), <String>['mia']);
    });
  });

  group('Me gusta', () {
    setUp(() => publicar('foto', 'guia', DateTime(2026, 9, 1)));

    Future<bool> existeLike(String uid) async =>
        (await firestore
                .collection('publicaciones')
                .doc('foto')
                .collection('likes')
                .doc(uid)
                .get())
            .exists;

    test('dar y quitar "me gusta" actualiza el total', () async {
      expect(
        await servicio().cambiarMeGusta(publicacionId: 'foto', meGusta: true),
        1,
      );
      expect(await existeLike('yo'), isTrue);

      expect(
        await servicio().cambiarMeGusta(publicacionId: 'foto', meGusta: false),
        0,
      );
      expect(await existeLike('yo'), isFalse);
    });

    test(
      'un usuario no puede dar dos "me gusta" a la misma publicación',
      () async {
        await servicio().cambiarMeGusta(publicacionId: 'foto', meGusta: true);
        final int total = await servicio().cambiarMeGusta(
          publicacionId: 'foto',
          meGusta: true,
        );

        expect(total, 1);
      },
    );

    test('los "me gusta" de varios usuarios se suman', () async {
      await servicio().cambiarMeGusta(publicacionId: 'foto', meGusta: true);
      final int total = await servicio(uid: 'guia')
          .cambiarMeGusta(publicacionId: 'foto', meGusta: true);

      expect(total, 2);
      final PublicacionEnFeed enFeed =
          (await servicio().obtenerFeed()).publicaciones.single;
      expect(enFeed.totalMeGusta, 2);
      expect(enFeed.meGusta, isTrue);
    });

    test('se puede dar "me gusta" a una publicación propia', () async {
      final int total = await servicio(uid: 'guia')
          .cambiarMeGusta(publicacionId: 'foto', meGusta: true);

      expect(total, 1);
    });

    test('sin sesión iniciada no se puede dar "me gusta"', () async {
      await expectLater(
        servicio(uid: null)
            .cambiarMeGusta(publicacionId: 'foto', meGusta: true),
        lanzaCodigo('user-not-authenticated'),
      );
    });

    test(
      'no se puede dar "me gusta" a una publicación que ya no existe',
      () async {
        await expectLater(
          servicio().cambiarMeGusta(publicacionId: 'borrada', meGusta: true),
          lanzaCodigo('not-found'),
        );
        expect(
          (await firestore
                  .collection('publicaciones')
                  .doc('borrada')
                  .collection('likes')
                  .get())
              .docs,
          isEmpty,
        );
      },
    );

    test(
      'los "me gusta" no modifican el documento de la publicación',
      () async {
        final Map<String, dynamic>? antes =
            (await firestore.collection('publicaciones').doc('foto').get())
                .data();

        await servicio().cambiarMeGusta(publicacionId: 'foto', meGusta: true);

        final Map<String, dynamic>? despues =
            (await firestore.collection('publicaciones').doc('foto').get())
                .data();
        expect(despues, antes);
      },
    );
  });
}
