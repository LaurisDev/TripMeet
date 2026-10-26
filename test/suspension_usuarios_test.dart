import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripmeet/auth_service.dart';
import 'package:tripmeet/gestion_usuarios_screen.dart';
import 'package:tripmeet/usuarios_admin_service.dart';

MockFirebaseAuth _sesion(String uid, String correo) => MockFirebaseAuth(
  signedIn: true,
  mockUser: MockUser(uid: uid, email: correo),
);

Matcher _lanzaCodigo<T>(String codigo) =>
    throwsA(isA<T>().having((dynamic e) => e.code, 'code', codigo));

/// HU-31: suspensión de cuentas por el administrador.
void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    await firestore.collection('usuarios').doc('u1').set(<String, dynamic>{
      'correo': 'julia@gmail.com',
      'rol': 'Turista',
    });
  });

  Future<Map<String, dynamic>?> perfil(String uid) async =>
      (await firestore.collection('usuarios').doc(uid).get()).data();

  group('UsuariosAdminService.suspenderUsuario', () {
    UsuariosAdminService servicio({String correo = correoAdministrador}) =>
        UsuariosAdminService(
          firestore: firestore,
          auth: _sesion('admin', correo),
        );

    test('el administrador suspende la cuenta y se guarda el motivo', () async {
      await servicio().suspenderUsuario('u1', '  Lenguaje ofensivo  ');

      final Map<String, dynamic>? datos = await perfil('u1');
      expect(datos?['suspendido'], isTrue);
      expect(datos?['motivoSuspension'], 'Lenguaje ofensivo');
      expect(datos?['fechaSuspension'], isA<Timestamp>());

      final List<UsuarioListado> usuarios = await servicio().obtenerUsuarios();
      expect(usuarios.single.suspendido, isTrue);
      expect(usuarios.single.motivoSuspension, 'Lenguaje ofensivo');
    });

    test('sin motivo no se registra la suspensión', () async {
      await expectLater(
        servicio().suspenderUsuario('u1', '   '),
        _lanzaCodigo<UsuariosAdminException>('motivo-requerido'),
      );
      expect((await perfil('u1'))?.containsKey('suspendido'), isFalse);
    });

    test('un usuario que no es administrador no puede suspender', () async {
      await expectLater(
        servicio(correo: 'otro@gmail.com').suspenderUsuario('u1', 'Spam'),
        _lanzaCodigo<UsuariosAdminException>('permission-denied'),
      );
      expect((await perfil('u1'))?.containsKey('suspendido'), isFalse);
    });

    test('no se suspende dos veces la misma cuenta', () async {
      await servicio().suspenderUsuario('u1', 'Spam');
      await expectLater(
        servicio().suspenderUsuario('u1', 'Otro motivo'),
        _lanzaCodigo<UsuariosAdminException>('ya-suspendido'),
      );
      expect((await perfil('u1'))?['motivoSuspension'], 'Spam');
    });

    test('un usuario inexistente lo indica', () async {
      await expectLater(
        servicio().suspenderUsuario('no-existe', 'Spam'),
        _lanzaCodigo<UsuariosAdminException>('not-found'),
      );
    });
  });

  group('UsuariosAdminService.quitarSuspension', () {
    UsuariosAdminService servicio({String correo = correoAdministrador}) =>
        UsuariosAdminService(
          firestore: firestore,
          auth: _sesion('admin', correo),
        );

    test('el administrador quita la suspensión y borra sus datos', () async {
      await servicio().suspenderUsuario('u1', 'Spam');
      await servicio().quitarSuspension('u1');

      final Map<String, dynamic>? datos = await perfil('u1');
      expect(datos?.containsKey('suspendido'), isFalse);
      expect(datos?.containsKey('motivoSuspension'), isFalse);
      expect(datos?.containsKey('fechaSuspension'), isFalse);
      expect(datos?['correo'], 'julia@gmail.com');
      expect(datos?['rol'], 'Turista');
      expect((await servicio().obtenerUsuarios()).single.suspendido, isFalse);
    });

    test('un usuario que no es administrador no puede quitarla', () async {
      await servicio().suspenderUsuario('u1', 'Spam');
      await expectLater(
        servicio(correo: 'otro@gmail.com').quitarSuspension('u1'),
        _lanzaCodigo<UsuariosAdminException>('permission-denied'),
      );
      expect((await perfil('u1'))?['suspendido'], isTrue);
    });

    test('una cuenta activa o inexistente lo indica', () async {
      await expectLater(
        servicio().quitarSuspension('u1'),
        _lanzaCodigo<UsuariosAdminException>('no-suspendido'),
      );
      await expectLater(
        servicio().quitarSuspension('no-existe'),
        _lanzaCodigo<UsuariosAdminException>('not-found'),
      );
    });

    test('después de quitarla el usuario vuelve a iniciar sesión', () async {
      await servicio().suspenderUsuario('u1', 'Spam');
      await servicio().quitarSuspension('u1');

      final MockFirebaseAuth auth = MockFirebaseAuth(
        mockUser: MockUser(uid: 'u1', email: 'julia@gmail.com'),
      );
      await AuthService(
        auth: auth,
        firestore: firestore,
      ).iniciarSesion('julia@gmail.com', 'secreta');
      expect(auth.currentUser?.uid, 'u1');
    });
  });

  group('Inicio de sesión de una cuenta suspendida', () {
    test('se rechaza con el motivo y la sesión queda cerrada', () async {
      await firestore.collection('usuarios').doc('u1').update(<String, dynamic>{
        'suspendido': true,
        'motivoSuspension': 'Spam',
      });
      final MockFirebaseAuth auth = MockFirebaseAuth(
        mockUser: MockUser(uid: 'u1', email: 'julia@gmail.com'),
      );

      await expectLater(
        AuthService(
          auth: auth,
          firestore: firestore,
        ).iniciarSesion('julia@gmail.com', 'secreta'),
        throwsA(
          isA<AuthServiceException>()
              .having((e) => e.code, 'code', 'account-suspended')
              .having((e) => e.message, 'message', contains('Spam')),
        ),
      );
      expect(auth.currentUser, isNull);
    });

    test('una cuenta activa inicia sesión con normalidad', () async {
      final MockFirebaseAuth auth = MockFirebaseAuth(
        mockUser: MockUser(uid: 'u1', email: 'julia@gmail.com'),
      );

      await AuthService(
        auth: auth,
        firestore: firestore,
      ).iniciarSesion('julia@gmail.com', 'secreta');

      expect(auth.currentUser?.uid, 'u1');
    });
  });

  group('Escenarios de la HU-31 (servicio + inicio de sesión)', () {
    MockFirebaseAuth cuentaDe(String uid, String correo) => MockFirebaseAuth(
      mockUser: MockUser(uid: uid, email: correo),
    );

    Future<void> entrar(MockFirebaseAuth auth, String correo) => AuthService(
      auth: auth,
      firestore: firestore,
    ).iniciarSesion(correo, 'secreta');

    setUp(() async {
      await firestore.collection('usuarios').doc('u2').set(<String, dynamic>{
        'correo': 'pedro@gmail.com',
        'rol': 'Guía turístico',
        'estadoCertificados': 'aprobado',
      });
    });

    test(
      '1. suspensión exitosa: se guarda el motivo y se bloquea el acceso',
      () async {
        await UsuariosAdminService(
          firestore: firestore,
          auth: _sesion('admin', correoAdministrador),
        ).suspenderUsuario('u1', 'Fraude');

        final MockFirebaseAuth auth = cuentaDe('u1', 'julia@gmail.com');
        await expectLater(
          entrar(auth, 'julia@gmail.com'),
          throwsA(
            isA<AuthServiceException>()
                .having((e) => e.code, 'code', 'account-suspended')
                .having((e) => e.message, 'message', contains('Fraude')),
          ),
        );
        expect(auth.currentUser, isNull);
      },
    );

    test(
      '3. persistencia: tras cerrar sesión sigue sin poder entrar',
      () async {
        await UsuariosAdminService(
          firestore: firestore,
          auth: _sesion('admin', correoAdministrador),
        ).suspenderUsuario('u1', 'Fraude');

        // Cada intento es una sesión nueva sobre los mismos datos guardados.
        for (int intento = 0; intento < 3; intento++) {
          final MockFirebaseAuth auth = cuentaDe('u1', 'julia@gmail.com');
          await expectLater(
            entrar(auth, 'julia@gmail.com'),
            _lanzaCodigo<AuthServiceException>('account-suspended'),
          );
          expect(auth.currentUser, isNull);
        }
        expect((await perfil('u1'))?['suspendido'], isTrue);
      },
    );

    test(
      '4. seguridad: sin sesión o sin ser administrador no se suspende',
      () async {
        await expectLater(
          UsuariosAdminService(
            firestore: firestore,
            auth: MockFirebaseAuth(),
          ).suspenderUsuario('u1', 'Spam'),
          _lanzaCodigo<UsuariosAdminException>('permission-denied'),
        );
        // Un usuario normal tampoco, ni siquiera sobre otra cuenta.
        await expectLater(
          UsuariosAdminService(
            firestore: firestore,
            auth: _sesion('u2', 'pedro@gmail.com'),
          ).suspenderUsuario('u1', 'Spam'),
          _lanzaCodigo<UsuariosAdminException>('permission-denied'),
        );
        expect((await perfil('u1'))?.containsKey('suspendido'), isFalse);
      },
    );

    test(
      '4. seguridad: el administrador no puede suspenderse a sí mismo',
      () async {
        await expectLater(
          UsuariosAdminService(
            firestore: firestore,
            auth: _sesion('u1', correoAdministrador),
          ).suspenderUsuario('u1', 'Prueba'),
          _lanzaCodigo<UsuariosAdminException>('auto-suspension'),
        );
        expect((await perfil('u1'))?.containsKey('suspendido'), isFalse);
      },
    );

    test(
      '5. integridad: no afecta a otros usuarios ni al resto del perfil',
      () async {
        final Map<String, dynamic>? otroAntes = await perfil('u2');

        await UsuariosAdminService(
          firestore: firestore,
          auth: _sesion('admin', correoAdministrador),
        ).suspenderUsuario('u1', 'Fraude');

        expect(await perfil('u2'), otroAntes);
        final Map<String, dynamic>? suspendido = await perfil('u1');
        expect(suspendido?['correo'], 'julia@gmail.com');
        expect(suspendido?['rol'], 'Turista');

        final MockFirebaseAuth auth = cuentaDe('u2', 'pedro@gmail.com');
        await entrar(auth, 'pedro@gmail.com');
        expect(auth.currentUser?.uid, 'u2');
      },
    );
  });

  group('Pantalla de gestión de usuarios', () {
    Future<_ServicioFalso> abrir(
      WidgetTester tester, {
      bool suspendido = false,
    }) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.5;
      addTearDown(tester.view.reset);

      final _ServicioFalso servicio = _ServicioFalso(<UsuarioListado>[
        UsuarioListado(
          uid: 'u1',
          nombre: 'julia',
          correo: 'julia@gmail.com',
          rol: 'Turista',
          suspendido: suspendido,
          motivoSuspension: suspendido ? 'Spam' : null,
        ),
      ]);
      await tester.pumpWidget(
        MaterialApp(home: GestionUsuariosScreen(service: servicio)),
      );
      await tester.pumpAndSettle();
      return servicio;
    }

    Future<void> elegirSuspender(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('acciones-u1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('opcion-suspender')));
      await tester.pumpAndSettle();
    }

    testWidgets('al cancelar la cuenta sigue activa', (
      WidgetTester tester,
    ) async {
      final _ServicioFalso servicio = await abrir(tester);
      await elegirSuspender(tester);

      await tester.enterText(find.byKey(const Key('motivo-suspension')), 'X');
      await tester.tap(find.byKey(const Key('cancelar-suspension')));
      await tester.pumpAndSettle();

      expect(servicio.suspensiones, isEmpty);
      expect(find.byKey(const Key('suspendido-u1')), findsNothing);
    });

    testWidgets('exige el motivo antes de confirmar', (
      WidgetTester tester,
    ) async {
      final _ServicioFalso servicio = await abrir(tester);
      await elegirSuspender(tester);

      await tester.tap(find.byKey(const Key('confirmar-suspension')));
      await tester.pumpAndSettle();

      expect(
        find.text('Debes escribir el motivo de la suspensión.'),
        findsOneWidget,
      );
      expect(servicio.suspensiones, isEmpty);
    });

    testWidgets('al confirmar suspende la cuenta con el motivo y lo muestra', (
      WidgetTester tester,
    ) async {
      final _ServicioFalso servicio = await abrir(tester);
      await elegirSuspender(tester);

      await tester.enterText(
        find.byKey(const Key('motivo-suspension')),
        'Spam',
      );
      await tester.tap(find.byKey(const Key('confirmar-suspension')));
      await tester.pumpAndSettle();

      expect(servicio.suspensiones, <String>['u1: Spam']);
      expect(find.text('Se suspendió la cuenta de julia.'), findsOneWidget);
      expect(find.byKey(const Key('suspendido-u1')), findsOneWidget);
    });

    Future<void> elegirQuitarSuspension(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('acciones-u1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('opcion-quitar-suspension')));
      await tester.pumpAndSettle();
    }

    testWidgets('una cuenta suspendida ofrece quitar la suspensión, no '
        'suspender de nuevo', (WidgetTester tester) async {
      await abrir(tester, suspendido: true);

      expect(find.byKey(const Key('suspendido-u1')), findsOneWidget);
      await tester.tap(find.byKey(const Key('acciones-u1')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('opcion-quitar-suspension')), findsOneWidget);
      expect(find.byKey(const Key('opcion-suspender')), findsNothing);
    });

    testWidgets('al confirmar se quita la suspensión y se muestra el motivo', (
      WidgetTester tester,
    ) async {
      final _ServicioFalso servicio = await abrir(tester, suspendido: true);
      await elegirQuitarSuspension(tester);

      expect(
        find.textContaining('Motivo de la suspensión: Spam'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('confirmar-quitar-suspension')));
      await tester.pumpAndSettle();

      expect(servicio.reactivaciones, <String>['u1']);
      expect(find.text('Se reactivó la cuenta de julia.'), findsOneWidget);
      expect(find.byKey(const Key('suspendido-u1')), findsNothing);
    });

    testWidgets('al cancelar la cuenta sigue suspendida', (
      WidgetTester tester,
    ) async {
      final _ServicioFalso servicio = await abrir(tester, suspendido: true);
      await elegirQuitarSuspension(tester);

      await tester.tap(find.byKey(const Key('cancelar-quitar-suspension')));
      await tester.pumpAndSettle();

      expect(servicio.reactivaciones, isEmpty);
      expect(find.byKey(const Key('suspendido-u1')), findsOneWidget);
    });
  });
}

class _ServicioFalso extends Fake implements UsuariosAdminService {
  _ServicioFalso(this.usuarios);

  List<UsuarioListado> usuarios;
  final List<String> suspensiones = <String>[];
  final List<String> reactivaciones = <String>[];

  @override
  Future<List<UsuarioListado>> obtenerUsuarios() async => usuarios;

  @override
  Future<void> suspenderUsuario(String uid, String motivo) async {
    suspensiones.add('$uid: $motivo');
    usuarios = <UsuarioListado>[
      for (final UsuarioListado u in usuarios)
        if (u.uid == uid)
          UsuarioListado(
            uid: u.uid,
            nombre: u.nombre,
            correo: u.correo,
            rol: u.rol,
            suspendido: true,
            motivoSuspension: motivo,
          )
        else
          u,
    ];
  }

  @override
  Future<void> quitarSuspension(String uid) async {
    reactivaciones.add(uid);
    usuarios = <UsuarioListado>[
      for (final UsuarioListado u in usuarios)
        if (u.uid == uid)
          UsuarioListado(
            uid: u.uid,
            nombre: u.nombre,
            correo: u.correo,
            rol: u.rol,
          )
        else
          u,
    ];
  }
}
