import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tripmeet/cloudinary_service.dart';
import 'package:tripmeet/evento_service.dart';
import 'package:tripmeet/guia_service.dart' show ArchivoLocal;

final DateTime _ahora = DateTime(2026, 10, 3, 12);
final DateTime _manana = DateTime(2026, 10, 4, 18, 30);

const String _urlSubida =
    'https://res.cloudinary.com/pncvlky3/image/upload/'
    'v1/tripmeet/eventos/foto.png';

/// Imagen PNG mínima válida (firma binaria real) de [tamano] bytes.
ArchivoLocal _png({int tamano = 64, String extension = 'png'}) {
  final Uint8List bytes = Uint8List(tamano)
    ..setAll(0, <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  return ArchivoLocal(
    nombre: 'foto.$extension',
    bytes: bytes,
    extension: extension,
  );
}

Matcher _lanzaCodigo(String codigo) => throwsA(
  isA<EventoServiceException>().having(
    (EventoServiceException e) => e.code,
    'code',
    codigo,
  ),
);

void main() {
  late FakeFirebaseFirestore firestore;

  /// Peticiones HTTP que llegaron a "Cloudinary".
  late List<http.Request> subidas;

  /// Respuesta que devolverá el Cloudinary falso.
  late http.Response Function() respuestaCloudinary;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    subidas = <http.Request>[];
    respuestaCloudinary = () => http.Response(
      jsonEncode(<String, dynamic>{
        'secure_url': _urlSubida,
        'public_id': 'tripmeet/eventos/foto',
        'bytes': 64,
        'format': 'png',
      }),
      200,
    );

    await firestore.collection('usuarios').doc('guia-ok').set(<String, dynamic>{
      'rol': 'Guía turístico',
      'estadoCertificados': 'aprobado',
    });
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

  EventoService servicio({String? uid = 'guia-ok'}) => EventoService(
    auth: MockFirebaseAuth(
      signedIn: uid != null,
      mockUser: MockUser(uid: uid ?? 'sin-sesion'),
    ),
    firestore: firestore,
    cloudinary: CloudinaryService(
      client: MockClient((http.Request peticion) async {
        subidas.add(peticion);
        return respuestaCloudinary();
      }),
    ),
    reloj: () => _ahora,
  );

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  eventosGuardados() async =>
      (await firestore.collection('eventos').get()).docs;

  group('Validaciones de los campos', () {
    test('nombre y lugar son obligatorios', () {
      expect(
        EventoService.validarNombre('   '),
        'Ingresa el nombre del evento.',
      );
      expect(EventoService.validarLugar(null), 'Ingresa el lugar del evento.');
    });

    test('nombre y lugar exigen al menos 3 caracteres', () {
      expect(EventoService.validarNombre(' ab '), contains('al menos 3'));
      expect(EventoService.validarLugar('ab'), contains('al menos 3'));
      expect(EventoService.validarNombre('Tour'), isNull);
    });

    test('nombre y lugar tienen longitud máxima', () {
      expect(
        EventoService.validarNombre('a' * (longitudMaximaNombreEvento + 1)),
        contains('$longitudMaximaNombreEvento'),
      );
      expect(
        EventoService.validarLugar('a' * (longitudMaximaLugarEvento + 1)),
        contains('$longitudMaximaLugarEvento'),
      );
    });

    test('la fecha y hora son obligatorias y deben ser futuras', () {
      expect(
        EventoService.validarFechaHora(null, ahora: _ahora),
        'Selecciona la fecha y la hora del evento.',
      );
      expect(
        EventoService.validarFechaHora(_ahora, ahora: _ahora),
        contains('posteriores'),
      );
      expect(
        EventoService.validarFechaHora(
          _ahora.subtract(const Duration(minutes: 1)),
          ahora: _ahora,
        ),
        contains('posteriores'),
      );
      expect(EventoService.validarFechaHora(_manana, ahora: _ahora), isNull);
    });

    test('la descripción es opcional pero con longitud máxima', () {
      expect(EventoService.validarDescripcion(null), isNull);
      expect(EventoService.validarDescripcion(''), isNull);
      expect(
        EventoService.validarDescripcion(
          'a' * (longitudMaximaDescripcionEvento + 1),
        ),
        contains('$longitudMaximaDescripcionEvento'),
      );
    });
  });

  group('Creación por un guía aprobado', () {
    test(
      'guarda todos los datos, la imagen y el creador en Firestore',
      () async {
        final Evento creado = await servicio().crearEvento(
          nombre: '  Tour nocturno  ',
          lugar: ' Cartagena ',
          fechaHora: _manana,
          descripcion: '  Recorrido por la ciudad amurallada  ',
          imagen: _png(),
        );

        final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
            await eventosGuardados();
        expect(docs, hasLength(1));
        final Map<String, dynamic> datos = docs.single.data();
        expect(docs.single.id, creado.id);
        expect(datos['id'], creado.id);
        expect(datos['creadorUid'], 'guia-ok');
        expect(datos['nombre'], 'Tour nocturno');
        expect(datos['lugar'], 'Cartagena');
        expect((datos['fechaHora'] as Timestamp).toDate(), _manana);
        expect(datos['descripcion'], 'Recorrido por la ciudad amurallada');
        expect(datos['imagenUrl'], _urlSubida);
        expect(datos['imagenPublicId'], 'tripmeet/eventos/foto');
        expect((datos['fechaCreacion'] as Timestamp).toDate(), _ahora);

        expect(creado.imagenUrl, _urlSubida);
        expect(creado.creadorUid, 'guia-ok');
      },
    );

    test('sube la imagen a Cloudinary en la carpeta de eventos', () async {
      await servicio().crearEvento(
        nombre: 'Tour nocturno',
        lugar: 'Cartagena',
        fechaHora: _manana,
        imagen: _png(),
      );

      expect(subidas, hasLength(1));
      final http.Request peticion = subidas.single;
      expect(peticion.method, 'POST');
      expect(
        peticion.url.toString(),
        'https://api.cloudinary.com/v1_1/pncvlky3/image/upload',
      );
      final String cuerpo = latin1.decode(peticion.bodyBytes);
      expect(cuerpo, contains('name="folder"\r\n\r\ntripmeet/eventos'));
      expect(cuerpo, contains('name="upload_preset"\r\n\r\nTripMeet'));
      expect(cuerpo, contains('filename="foto.png"'));
      expect(cuerpo, contains('content-type: image/png'));
    });

    test('sin imagen ni descripción guarda el evento sin subir nada', () async {
      final Evento creado = await servicio().crearEvento(
        nombre: 'Caminata ecológica',
        lugar: 'Minca',
        fechaHora: _manana,
        descripcion: '   ',
      );

      expect(subidas, isEmpty);
      final Map<String, dynamic> datos = (await eventosGuardados()).single
          .data();
      expect(datos['imagenUrl'], isNull);
      expect(datos['imagenPublicId'], isNull);
      expect(datos['descripcion'], isNull);
      expect(creado.descripcion, isNull);
    });

    test(
      'el evento creado aparece en la consulta de eventos disponibles',
      () async {
        final Evento creado = await servicio().crearEvento(
          nombre: 'Tour nocturno',
          lugar: 'Cartagena',
          fechaHora: _manana,
          imagen: _png(),
        );

        final List<Evento> disponibles = await servicio(uid: 'turista-1')
            .obtenerEventosDisponibles();

        expect(disponibles.map((Evento e) => e.id), <String>[creado.id]);
        expect(disponibles.single.nombre, 'Tour nocturno');
        expect(disponibles.single.imagenUrl, _urlSubida);
      },
    );
  });

  test('el evento creado trae el carné aprobado del guía', () async {
    await firestore.collection('usuarios').doc('guia-ok').update(
      <String, dynamic>{
        'certificados': <String, dynamic>{
          'carneGuia': <String, dynamic>{
            'nombre': 'carne.pdf',
            'url': 'https://res.cloudinary.com/pncvlky3/carne.pdf',
          },
        },
      },
    );

    final Evento creado = await servicio().crearEvento(
      nombre: 'Tour nocturno',
      lugar: 'Cartagena',
      fechaHora: _manana,
    );

    expect(creado.creadoPorGuia, isTrue);
    expect(
      creado.certificadoGuia?.url,
      'https://res.cloudinary.com/pncvlky3/carne.pdf',
    );
    final Map<String, dynamic> datos = (await eventosGuardados()).single.data();
    expect(
      datos.containsKey('certificadoGuia'),
      isFalse,
      reason: 'el certificado no se copia al evento; se lee del perfil',
    );
  });

  group('Cupo y precio', () {
    test('se guardan cuando se indican', () async {
      final Evento creado = await servicio().crearEvento(
        nombre: 'Tour nocturno',
        lugar: 'Cartagena',
        fechaHora: _manana,
        cupoMaximo: 25,
        precio: 50000,
      );

      final Map<String, dynamic> datos = (await eventosGuardados()).single
          .data();
      expect(datos['cupoMaximo'], 25);
      expect(datos['precio'], 50000);
      expect(creado.cupoMaximo, 25);
      expect(creado.precio, 50000);

      final Evento leido = (await servicio(
        uid: 'turista-1',
      ).obtenerEventosDisponibles()).single;
      expect(leido.cupoMaximo, 25);
      expect(leido.precio, 50000);
    });

    test('quedan nulos si no se indican', () async {
      await servicio().crearEvento(
        nombre: 'Tour nocturno',
        lugar: 'Cartagena',
        fechaHora: _manana,
      );

      final Map<String, dynamic> datos = (await eventosGuardados()).single
          .data();
      expect(datos['cupoMaximo'], isNull);
      expect(datos['precio'], isNull);
    });

    test('un turista también puede indicarlos', () async {
      final Evento creado = await servicio(uid: 'turista-1').crearEvento(
        nombre: 'Salida en grupo',
        lugar: 'Guatapé',
        fechaHora: _manana,
        cupoMaximo: 8,
        precio: 0,
      );

      expect(creado.cupoMaximo, 8);
      expect(creado.precio, 0);
    });

    for (final (String caso, int? cupo, int? precio) in <(String, int?, int?)>[
      ('cupo 0', 0, null),
      ('cupo mayor a 1000', 1001, null),
      ('precio negativo', null, -1),
      ('precio mayor al máximo', null, precioMaximoEvento + 1),
    ]) {
      test('rechaza $caso sin guardar nada', () async {
        await expectLater(
          servicio().crearEvento(
            nombre: 'Tour nocturno',
            lugar: 'Cartagena',
            fechaHora: _manana,
            cupoMaximo: cupo,
            precio: precio,
          ),
          _lanzaCodigo('datos-invalidos'),
        );
        expect(await eventosGuardados(), isEmpty);
      });
    }
  });

  group('Permisos', () {
    test('un turista crea un evento normal, sin diseño premium', () async {
      final Evento creado = await servicio(uid: 'turista-1').crearEvento(
        nombre: 'Recorrido cultural por el pueblo',
        lugar: 'Guatapé',
        fechaHora: _manana,
        imagen: _png(),
      );

      final Map<String, dynamic> datos = (await eventosGuardados()).single
          .data();
      expect(datos['creadorUid'], 'turista-1');
      expect(datos['imagenUrl'], _urlSubida);
      expect(creado.creadoPorGuia, isFalse);
      expect(creado.certificadoGuia, isNull);
    });

    test('un guía con certificados en revisión crea un evento premium sin '
        'certificado', () async {
      final Evento creado = await servicio(uid: 'guia-revision')
          .crearEvento(nombre: 'Tour', lugar: 'Cartagena', fechaHora: _manana);

      expect(await eventosGuardados(), hasLength(1));
      expect(creado.creadoPorGuia, isTrue);
      expect(creado.certificadoGuia, isNull);
    });

    test('un usuario sin perfil no puede crear eventos', () async {
      await expectLater(
        servicio(uid: 'sin-perfil').crearEvento(
          nombre: 'Tour',
          lugar: 'Cartagena',
          fechaHora: _manana,
          imagen: _png(),
        ),
        _lanzaCodigo('permission-denied'),
      );
      expect(await eventosGuardados(), isEmpty);
      expect(subidas, isEmpty, reason: 'no debe subir la imagen');
    });

    test('un perfil sin rol permitido no puede crear eventos', () async {
      await firestore.collection('usuarios').doc('sin-rol').set(
        <String, dynamic>{'correo': 'x@y.com'},
      );

      await expectLater(
        servicio(
          uid: 'sin-rol',
        ).crearEvento(nombre: 'Tour', lugar: 'Cartagena', fechaHora: _manana),
        _lanzaCodigo('permission-denied'),
      );
      expect(await eventosGuardados(), isEmpty);
    });

    test('sin sesión iniciada no se puede crear', () async {
      await expectLater(
        servicio(
          uid: null,
        ).crearEvento(nombre: 'Tour', lugar: 'Cartagena', fechaHora: _manana),
        _lanzaCodigo('user-not-authenticated'),
      );
      expect(await eventosGuardados(), isEmpty);
    });
  });

  group('Datos inválidos', () {
    Future<void> rechaza({
      String nombre = 'Tour nocturno',
      String lugar = 'Cartagena',
      DateTime? fechaHora,
      bool sinFecha = false,
      String? descripcion,
      ArchivoLocal? imagen,
    }) async {
      await expectLater(
        servicio().crearEvento(
          nombre: nombre,
          lugar: lugar,
          fechaHora: sinFecha ? null : (fechaHora ?? _manana),
          descripcion: descripcion,
          imagen: imagen,
        ),
        _lanzaCodigo('datos-invalidos'),
      );
      expect(await eventosGuardados(), isEmpty);
      expect(subidas, isEmpty);
    }

    test('sin nombre', () => rechaza(nombre: '  '));
    test('sin lugar', () => rechaza(lugar: ''));
    test('sin fecha', () => rechaza(sinFecha: true));
    test(
      'con fecha pasada',
      () => rechaza(fechaHora: DateTime(2026, 10, 1, 9)),
    );
    test(
      'con descripción demasiado larga',
      () => rechaza(descripcion: 'a' * (longitudMaximaDescripcionEvento + 1)),
    );
    test('con imagen de formato no permitido', () {
      return rechaza(imagen: _png(extension: 'gif'));
    });
    test('con imagen de más de 5 MB', () {
      return rechaza(imagen: _png(tamano: 5 * 1024 * 1024 + 1));
    });
  });

  group('Errores de almacenamiento', () {
    test(
      'si falla la subida de la imagen, informa y no guarda el evento',
      () async {
        respuestaCloudinary = () => http.Response(
          jsonEncode(<String, dynamic>{
            'error': <String, dynamic>{'message': 'Upload preset not found'},
          }),
          400,
        );

        await expectLater(
          servicio().crearEvento(
            nombre: 'Tour nocturno',
            lugar: 'Cartagena',
            fechaHora: _manana,
            imagen: _png(),
          ),
          throwsA(
            isA<EventoServiceException>().having(
              (EventoServiceException e) => e.message,
              'message',
              contains('No se pudo subir el archivo'),
            ),
          ),
        );
        expect(await eventosGuardados(), isEmpty);
      },
    );
  });
}
