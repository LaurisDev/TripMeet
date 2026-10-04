import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripmeet/evento_service.dart';

void main() {
  group('Cupo y precio: conversión y validación', () {
    test('leerEnteroOpcional', () {
      expect(EventoService.leerEnteroOpcional(null), isNull);
      expect(EventoService.leerEnteroOpcional('  '), isNull);
      expect(EventoService.leerEnteroOpcional('25'), 25);
      expect(EventoService.leerEnteroOpcional('50.000'), 50000);
      expect(
        () => EventoService.leerEnteroOpcional('2,5'),
        throwsFormatException,
      );
      expect(
        () => EventoService.leerEnteroOpcional('abc'),
        throwsFormatException,
      );
    });

    test('validarCampoEntero informa si el texto no es un entero', () {
      expect(
        EventoService.validarCampoEntero('abc', EventoService.validarPrecio),
        'Ingresa solo números enteros.',
      );
      expect(
        EventoService.validarCampoEntero('', EventoService.validarCupoMaximo),
        isNull,
      );
    });
  });

  group('EventoService.puedeCrear', () {
    test('un turista puede crear eventos', () {
      expect(
        EventoService.puedeCrear(<String, dynamic>{'rol': 'Turista'}),
        isTrue,
      );
    });

    test('un guía puede crear eventos, aprobado o no', () {
      expect(
        EventoService.puedeCrear(<String, dynamic>{
          'rol': 'Guía turístico',
          'estadoCertificados': 'en_revision',
        }),
        isTrue,
      );
    });

    test('sin perfil, sin rol o con un rol desconocido no puede', () {
      expect(EventoService.puedeCrear(null), isFalse);
      expect(EventoService.puedeCrear(<String, dynamic>{}), isFalse);
      expect(
        EventoService.puedeCrear(<String, dynamic>{'rol': 'Administrador'}),
        isFalse,
      );
    });
  });

  group('EventoService.esGuiaAprobado', () {
    test('un guía con certificados aprobados está aprobado', () {
      expect(
        EventoService.esGuiaAprobado(<String, dynamic>{
          'rol': 'Guía turístico',
          'estadoCertificados': 'aprobado',
        }),
        isTrue,
      );
    });

    test('un guía con certificados en revisión no está aprobado', () {
      expect(
        EventoService.esGuiaAprobado(<String, dynamic>{
          'rol': 'Guía turístico',
          'estadoCertificados': 'en_revision',
        }),
        isFalse,
      );
    });

    test('un guía que pospuso sus certificados no está aprobado', () {
      expect(
        EventoService.esGuiaAprobado(<String, dynamic>{
          'rol': 'Guía turístico',
          'estadoCertificados': 'pendiente',
        }),
        isFalse,
      );
    });

    test('un turista no es guía aprobado, aunque tenga el campo de '
        'certificados', () {
      expect(
        EventoService.esGuiaAprobado(<String, dynamic>{
          'rol': 'Turista',
          'estadoCertificados': 'aprobado',
        }),
        isFalse,
      );
    });

    test('sin perfil no está aprobado', () {
      expect(EventoService.esGuiaAprobado(null), isFalse);
    });
  });

  group('EventoService (Firestore simulado)', () {
    late FakeFirebaseFirestore firestore;

    EventoService servicio({String? uid}) => EventoService(
      auth: MockFirebaseAuth(
        signedIn: uid != null,
        mockUser: MockUser(uid: uid ?? 'sin-sesion'),
      ),
      firestore: firestore,
    );

    Future<void> guardarEvento(
      String id,
      DateTime fechaHora, {
      String? descripcion,
      String? imagenUrl,
      String creadorUid = 'guia-1',
      Map<String, dynamic> extra = const <String, dynamic>{},
    }) => firestore.collection('eventos').doc(id).set(<String, dynamic>{
      ...extra,
      'id': id,
      'creadorUid': creadorUid,
      'nombre': 'Evento $id',
      'lugar': 'Cartagena',
      'fechaHora': Timestamp.fromDate(fechaHora),
      'descripcion': descripcion,
      'imagenUrl': imagenUrl,
      'imagenPublicId': null,
      'fechaCreacion': Timestamp.fromDate(DateTime(2026, 9, 1)),
    });

    setUp(() {
      firestore = FakeFirebaseFirestore();
    });

    test('lista solo los eventos que no han ocurrido, del más próximo al '
        'más lejano', () async {
      final DateTime ahora = DateTime(2026, 10, 3, 12);
      await guardarEvento('lejano', DateTime(2026, 12, 24, 20));
      await guardarEvento('pasado', DateTime(2026, 10, 1, 9));
      await guardarEvento('proximo', DateTime(2026, 10, 5, 18, 30));

      final List<Evento> eventos = await servicio(uid: 'turista-1')
          .obtenerEventosDisponibles(desde: ahora);

      expect(eventos.map((Evento e) => e.id), <String>['proximo', 'lejano']);
    });

    test('lee todos los campos del evento', () async {
      await guardarEvento(
        'completo',
        DateTime(2026, 10, 5, 18, 30),
        descripcion: 'Recorrido nocturno',
        imagenUrl: 'https://res.cloudinary.com/demo/evento.jpg',
      );

      final Evento evento = (await servicio(
        uid: 'turista-1',
      ).obtenerEventosDisponibles(desde: DateTime(2026, 10, 1))).single;

      expect(evento.creadorUid, 'guia-1');
      expect(evento.nombre, 'Evento completo');
      expect(evento.lugar, 'Cartagena');
      expect(evento.fechaHora, DateTime(2026, 10, 5, 18, 30));
      expect(evento.descripcion, 'Recorrido nocturno');
      expect(evento.imagenUrl, 'https://res.cloudinary.com/demo/evento.jpg');
    });

    test('cupo y precio inválidos guardados no se muestran', () async {
      await guardarEvento(
        'raro',
        DateTime(2026, 10, 5),
        extra: <String, dynamic>{'cupoMaximo': 0, 'precio': -5},
      );
      await guardarEvento(
        'decimal',
        DateTime(2026, 10, 6),
        extra: <String, dynamic>{'cupoMaximo': 2.5, 'precio': 'mil'},
      );
      await guardarEvento(
        'valido',
        DateTime(2026, 10, 7),
        extra: <String, dynamic>{'cupoMaximo': 12, 'precio': 0},
      );

      final List<Evento> eventos = await servicio(uid: 'turista-1')
          .obtenerEventosDisponibles(desde: DateTime(2026, 10, 1));

      expect(
        <String, List<int?>>{
          for (final Evento e in eventos) e.id: <int?>[e.cupoMaximo, e.precio],
        },
        <String, List<int?>>{
          'raro': <int?>[null, null],
          'decimal': <int?>[null, null],
          'valido': <int?>[12, 0],
        },
      );
    });

    test('descripción e imagen vacías se leen como ausentes', () async {
      await guardarEvento(
        'minimo',
        DateTime(2026, 10, 5),
        descripcion: '   ',
        imagenUrl: '',
      );

      final Evento evento = (await servicio(
        uid: 'turista-1',
      ).obtenerEventosDisponibles(desde: DateTime(2026, 10, 1))).single;

      expect(evento.descripcion, isNull);
      expect(evento.imagenUrl, isNull);
    });

    group('Certificado del guía según su perfil real', () {
      final DateTime desde = DateTime(2026, 10, 1);
      const String urlCarne =
          'https://res.cloudinary.com/pncvlky3/image/upload/v1/tripmeet/'
          'certificados/carne.pdf';

      Map<String, dynamic> certificados({String url = urlCarne}) =>
          <String, dynamic>{
            'carneGuia': <String, dynamic>{'nombre': 'carne.pdf', 'url': url},
            'antecedentesJudiciales': <String, dynamic>{
              'nombre': 'antecedentes.pdf',
              'url': 'https://res.cloudinary.com/x/antecedentes.pdf',
            },
            'adicionales': <dynamic>[],
          };

      Future<void> perfil(String uid, Map<String, dynamic> datos) =>
          firestore.collection('usuarios').doc(uid).set(datos);

      Future<Evento> eventoDe(String creadorUid) async {
        await guardarEvento(
          'ev',
          DateTime(2026, 10, 5),
          creadorUid: creadorUid,
        );
        return (await servicio(uid: 'turista-1')
                .obtenerEventosDisponibles(desde: desde))
            .single;
      }

      test(
        'un guía aprobado con carné registrado muestra su certificado',
        () async {
          await perfil('guia-ok', <String, dynamic>{
            'rol': 'Guía turístico',
            'estadoCertificados': 'aprobado',
            'certificados': certificados(),
          });

          final Evento evento = await eventoDe('guia-ok');

          expect(evento.creadoPorGuia, isTrue);
          expect(evento.certificadoGuia?.nombre, 'carne.pdf');
          expect(
            evento.certificadoGuia?.url,
            urlCarne,
            reason: 'solo se expone el carné, nunca los antecedentes',
          );
        },
      );

      test(
        'un guía con certificados en revisión no muestra certificado',
        () async {
          await perfil('guia-revision', <String, dynamic>{
            'rol': 'Guía turístico',
            'estadoCertificados': 'en_revision',
            'certificados': certificados(),
          });

          final Evento evento = await eventoDe('guia-revision');

          expect(evento.creadoPorGuia, isTrue);
          expect(evento.certificadoGuia, isNull);
        },
      );

      test(
        'un guía aprobado sin carné registrado no muestra certificado',
        () async {
          await perfil('guia-sin-carne', <String, dynamic>{
            'rol': 'Guía turístico',
            'estadoCertificados': 'aprobado',
          });

          expect((await eventoDe('guia-sin-carne')).certificadoGuia, isNull);
        },
      );

      test('un enlace de carné que no es https no se muestra', () async {
        await perfil('guia-enlace-raro', <String, dynamic>{
          'rol': 'Guía turístico',
          'estadoCertificados': 'aprobado',
          'certificados': certificados(url: 'javascript:alert(1)'),
        });

        expect((await eventoDe('guia-enlace-raro')).certificadoGuia, isNull);
      });

      test(
        'un turista con datos de certificado no aparece certificado',
        () async {
          await perfil('turista-1', <String, dynamic>{
            'rol': 'Turista',
            'estadoCertificados': 'aprobado',
            'certificados': certificados(),
          });

          final Evento evento = await eventoDe('turista-1');

          expect(evento.creadoPorGuia, isFalse);
          expect(evento.certificadoGuia, isNull);
        },
      );

      test('un certificado escrito en el evento se ignora', () async {
        await perfil('turista-1', <String, dynamic>{'rol': 'Turista'});
        await guardarEvento(
          'falso',
          DateTime(2026, 10, 5),
          creadorUid: 'turista-1',
          extra: <String, dynamic>{
            'certificadoGuia': <String, dynamic>{'url': urlCarne},
            'estadoCertificados': 'aprobado',
          },
        );

        final Evento evento = (await servicio(
          uid: 'turista-1',
        ).obtenerEventosDisponibles(desde: desde)).single;

        expect(evento.certificadoGuia, isNull);
      });
    });

    group('Diseño premium según el rol real del creador', () {
      final DateTime desde = DateTime(2026, 10, 1);

      setUp(() async {
        await firestore.collection('usuarios').doc('guia-ok').set(
          <String, dynamic>{
            'rol': 'Guía turístico',
            'estadoCertificados': 'aprobado',
          },
        );
        await firestore.collection('usuarios').doc('guia-revision').set(
          <String, dynamic>{
            'rol': 'Guía turístico',
            'estadoCertificados': 'en_revision',
          },
        );
        await firestore.collection('usuarios').doc('turista-1').set(
          <String, dynamic>{'rol': 'Turista'},
        );
      });

      Future<Map<String, bool>> premiumPorEvento() async => <String, bool>{
        for (final Evento e in await servicio(
          uid: 'turista-1',
        ).obtenerEventosDisponibles(desde: desde))
          e.id: e.creadoPorGuia,
      };

      test('los eventos de un guía turístico son premium', () async {
        await guardarEvento(
          'de-guia',
          DateTime(2026, 10, 5),
          creadorUid: 'guia-ok',
        );
        await guardarEvento(
          'de-guia-en-revision',
          DateTime(2026, 10, 6),
          creadorUid: 'guia-revision',
        );

        expect(await premiumPorEvento(), <String, bool>{
          'de-guia': true,
          'de-guia-en-revision': true,
        });
      });

      test('los eventos de quien no es guía no son premium', () async {
        await guardarEvento(
          'de-turista',
          DateTime(2026, 10, 5),
          creadorUid: 'turista-1',
        );
        await guardarEvento(
          'sin-perfil',
          DateTime(2026, 10, 6),
          creadorUid: 'no-existe',
        );

        expect(await premiumPorEvento(), <String, bool>{
          'de-turista': false,
          'sin-perfil': false,
        });
      });

      test('un campo escrito en el evento no lo vuelve premium', () async {
        await guardarEvento(
          'falsificado',
          DateTime(2026, 10, 5),
          creadorUid: 'turista-1',
          extra: <String, dynamic>{
            'creadoPorGuia': true,
            'rol': 'Guía turístico',
          },
        );

        expect(await premiumPorEvento(), <String, bool>{'falsificado': false});
      });

      test(
        'cambiar el rol del creador cambia el diseño de sus eventos',
        () async {
          await guardarEvento(
            'ev',
            DateTime(2026, 10, 5),
            creadorUid: 'guia-ok',
          );
          expect(await premiumPorEvento(), <String, bool>{'ev': true});

          await firestore.collection('usuarios').doc('guia-ok').update(
            <String, dynamic>{'rol': 'Turista'},
          );

          expect(await premiumPorEvento(), <String, bool>{'ev': false});
        },
      );
    });

    test(
      'puedeCrearEventos consulta el perfil del usuario autenticado',
      () async {
        await firestore.collection('usuarios').doc('guia-ok').set(
          <String, dynamic>{
            'rol': 'Guía turístico',
            'estadoCertificados': 'aprobado',
          },
        );
        await firestore.collection('usuarios').doc('guia-revision').set(
          <String, dynamic>{
            'rol': 'Guía turístico',
            'estadoCertificados': 'en_revision',
          },
        );
        await firestore.collection('usuarios').doc('turista-1').set(
          <String, dynamic>{'rol': 'Turista'},
        );

        expect(await servicio(uid: 'guia-ok').puedeCrearEventos(), isTrue);
        expect(
          await servicio(uid: 'guia-revision').puedeCrearEventos(),
          isTrue,
        );
        expect(await servicio(uid: 'turista-1').puedeCrearEventos(), isTrue);
        expect(await servicio(uid: 'sin-perfil').puedeCrearEventos(), isFalse);
        expect(await servicio().puedeCrearEventos(), isFalse);
      },
    );
  });
}
