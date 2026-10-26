import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripmeet/gestion_usuarios_screen.dart';
import 'package:tripmeet/usuarios_admin_service.dart';

UsuarioListado _usuario(
  String uid,
  String nombre,
  String correo, [
  String? rol,
]) => UsuarioListado(uid: uid, nombre: nombre, correo: correo, rol: rol);

/// HU-30: listado de usuarios para el administrador.
void main() {
  group('UsuariosAdminService (Firestore simulado)', () {
    late FakeFirebaseFirestore firestore;

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      await firestore.collection('usuarios').doc('u1').set(<String, dynamic>{
        'correo': 'zoe@gmail.com',
        'rol': 'Turista',
        'fechaCreacion': Timestamp.fromDate(DateTime(2026, 9, 1)),
      });
      await firestore.collection('usuarios').doc('u2').set(<String, dynamic>{
        'correo': 'carlos@correo.com',
        'nombre': 'Ángela Ruiz',
        'rol': 'Guía turístico',
      });
      // Un perfil incompleto también aparece en el listado.
      await firestore.collection('usuarios').doc('u3').set(<String, dynamic>{
        'rol': 'Turista',
      });
    });

    test('criterio 1: trae el listado completo, incluso perfiles '
        'incompletos, ordenado por nombre', () async {
      final List<UsuarioListado> usuarios = await UsuariosAdminService(
        firestore: firestore,
      ).obtenerUsuarios();

      expect(usuarios.map((UsuarioListado u) => u.uid), <String>[
        'u2', // Ángela (sin tilde: angela)
        'u3', // Usuario (sin correo)
        'u1', // zoe
      ]);
      final UsuarioListado angela = usuarios.first;
      expect(angela.nombre, 'Ángela Ruiz');
      expect(angela.correo, 'carlos@correo.com');
      expect(angela.rol, 'Guía turístico');
      expect(usuarios[1].nombre, 'Usuario');
      expect(usuarios[1].correo, '');
      expect(usuarios.last.nombre, 'zoe', reason: 'sin nombre, usa el correo');
      expect(usuarios.last.fechaRegistro, DateTime(2026, 9, 1));
    });
  });

  group('Búsqueda y paginación', () {
    final List<UsuarioListado> usuarios = <UsuarioListado>[
      _usuario('1', 'Ángela Ruiz', 'angela@gmail.com', 'Guía turístico'),
      _usuario('2', 'julia', 'julia@gmail.com', 'Turista'),
      _usuario('3', 'Pedro Gómez', 'pgomez@correo.co', 'Turista'),
    ];

    test(
      'criterio 3: busca por nombre sin distinguir mayúsculas ni tildes',
      () {
        expect(
          UsuariosAdminService.filtrar(usuarios, 'ANGELA').map((u) => u.uid),
          <String>['1'],
        );
        expect(
          UsuariosAdminService.filtrar(usuarios, 'gómez').map((u) => u.uid),
          <String>['3'],
        );
        expect(
          UsuariosAdminService.filtrar(usuarios, 'gomez').map((u) => u.uid),
          <String>['3'],
        );
      },
    );

    test('criterio 3: busca por correo, también por una parte', () {
      expect(
        UsuariosAdminService.filtrar(usuarios, 'correo.co').map((u) => u.uid),
        <String>['3'],
      );
      expect(
        UsuariosAdminService.filtrar(usuarios, '@gmail').map((u) => u.uid),
        <String>['1', '2'],
      );
    });

    test('criterio 4: sin coincidencias devuelve una lista vacía', () {
      expect(UsuariosAdminService.filtrar(usuarios, 'noexiste'), isEmpty);
    });

    test('una búsqueda vacía o con espacios devuelve todos', () {
      expect(UsuariosAdminService.filtrar(usuarios, '   '), hasLength(3));
    });

    test('criterio 2: pagina de 20 en 20', () {
      final List<UsuarioListado> muchos = <UsuarioListado>[
        for (int i = 0; i < 45; i++) _usuario('$i', 'u$i', 'u$i@x.co'),
      ];

      final PaginaUsuarios primera = UsuariosAdminService.paginar(muchos, 1);
      final PaginaUsuarios tercera = UsuariosAdminService.paginar(muchos, 3);

      expect(primera.usuarios, hasLength(20));
      expect(primera.totalPaginas, 3);
      expect(primera.hayAnterior, isFalse);
      expect(primera.haySiguiente, isTrue);
      expect(tercera.usuarios.map((u) => u.uid), <String>[
        for (int i = 40; i < 45; i++) '$i',
      ]);
      expect(tercera.haySiguiente, isFalse);
      expect(UsuariosAdminService.paginar(muchos, 99).pagina, 3);
      expect(
        UsuariosAdminService.paginar(<UsuarioListado>[], 1).totalPaginas,
        1,
      );
    });
  });

  group('Pantalla de gestión de usuarios', () {
    Future<void> abrir(
      WidgetTester tester,
      List<UsuarioListado> usuarios, {
      UsuariosAdminException? error,
      void Function(BuildContext, UsuarioListado)? abrirUsuario,
    }) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.5;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: GestionUsuariosScreen(
            service: _ServicioFalso(usuarios, error),
            abrirUsuario: abrirUsuario,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    final List<UsuarioListado> pocos = <UsuarioListado>[
      _usuario('1', 'Ángela Ruiz', 'angela@gmail.com', 'Guía turístico'),
      _usuario('2', 'julia', 'julia@gmail.com', 'Turista'),
      _usuario('3', 'Pedro Gómez', 'pgomez@correo.co', 'Turista'),
    ];

    testWidgets('criterio 1: muestra el listado completo de usuarios', (
      WidgetTester tester,
    ) async {
      await abrir(tester, pocos);

      expect(find.text('3 usuarios'), findsOneWidget);
      for (final UsuarioListado u in pocos) {
        expect(find.byKey(Key('usuario-${u.uid}')), findsOneWidget);
        expect(find.text(u.nombre), findsOneWidget);
        expect(find.text(u.correo), findsOneWidget);
      }
      expect(find.text('Guía turístico'), findsOneWidget);
      expect(
        find.byKey(const Key('pagina-actual')),
        findsNothing,
        reason: 'con una sola página no hace falta paginar',
      );
    });

    testWidgets('criterio 2: con muchos usuarios pagina y permite avanzar y '
        'retroceder', (WidgetTester tester) async {
      await abrir(tester, <UsuarioListado>[
        for (int i = 0; i < 45; i++)
          _usuario('$i', 'Usuario ${i.toString().padLeft(2, '0')}', 'u$i@x.co'),
      ]);

      expect(find.text('Página 1 de 3'), findsOneWidget);
      expect(find.text('45 usuarios'), findsOneWidget);
      expect(find.text('Usuario 00'), findsOneWidget);
      expect(find.text('Usuario 20'), findsNothing);
      expect(
        tester
            .widget<TextButton>(find.byKey(const Key('pagina-anterior')))
            .onPressed,
        isNull,
      );

      await tester.tap(find.byKey(const Key('pagina-siguiente')));
      await tester.pumpAndSettle();
      expect(find.text('Página 2 de 3'), findsOneWidget);
      expect(find.text('Usuario 20'), findsOneWidget);
      expect(find.text('Usuario 00'), findsNothing);

      await tester.tap(find.byKey(const Key('pagina-siguiente')));
      await tester.pumpAndSettle();
      expect(find.text('Página 3 de 3'), findsOneWidget);
      expect(find.text('Usuario 44'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(find.byKey(const Key('pagina-siguiente')))
            .onPressed,
        isNull,
      );

      await tester.tap(find.byKey(const Key('pagina-anterior')));
      await tester.pumpAndSettle();
      expect(find.text('Página 2 de 3'), findsOneWidget);
    });

    testWidgets('criterio 3: al escribir un nombre o correo muestra las '
        'coincidencias', (WidgetTester tester) async {
      await abrir(tester, pocos);

      await tester.enterText(find.byKey(const Key('buscar-usuarios')), 'gomez');
      await tester.pump();
      expect(find.text('1 resultado'), findsOneWidget);
      expect(find.text('Pedro Gómez'), findsOneWidget);
      expect(find.text('julia'), findsNothing);

      await tester.enterText(
        find.byKey(const Key('buscar-usuarios')),
        'JULIA@GMAIL',
      );
      await tester.pump();
      expect(find.text('julia'), findsOneWidget);
      expect(find.text('Pedro Gómez'), findsNothing);
    });

    testWidgets('criterio 4: si no hay coincidencias lo indica', (
      WidgetTester tester,
    ) async {
      await abrir(tester, pocos);

      await tester.enterText(
        find.byKey(const Key('buscar-usuarios')),
        'noexiste',
      );
      await tester.pump();

      expect(
        find.text('No se encontraron usuarios para "noexiste".'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('usuario-1')), findsNothing);
    });

    testWidgets('buscar vuelve a la primera página y limpiar restaura el '
        'listado', (WidgetTester tester) async {
      await abrir(tester, <UsuarioListado>[
        for (int i = 0; i < 45; i++)
          _usuario('$i', 'Usuario ${i.toString().padLeft(2, '0')}', 'u$i@x.co'),
      ]);
      await tester.tap(find.byKey(const Key('pagina-siguiente')));
      await tester.pumpAndSettle();
      expect(find.text('Página 2 de 3'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('buscar-usuarios')),
        'usuario',
      );
      await tester.pump();
      expect(find.text('Página 1 de 3'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('buscar-usuarios')), 'u4');
      await tester.pump();
      expect(find.text('6 resultados'), findsOneWidget); // u4, u40..u44

      await tester.tap(find.byTooltip('Limpiar búsqueda'));
      await tester.pump();
      expect(find.text('45 usuarios'), findsOneWidget);
    });

    testWidgets('sin usuarios registrados lo indica', (
      WidgetTester tester,
    ) async {
      await abrir(tester, <UsuarioListado>[]);

      expect(find.text('No hay usuarios registrados.'), findsOneWidget);
    });

    testWidgets('si falla la carga, lo informa y permite reintentar', (
      WidgetTester tester,
    ) async {
      await abrir(
        tester,
        pocos,
        error: const UsuariosAdminException(
          'No se pudieron cargar los usuarios. Inténtalo de nuevo.',
        ),
      );

      expect(
        find.text('No se pudieron cargar los usuarios. Inténtalo de nuevo.'),
        findsOneWidget,
      );
      expect(find.text('Reintentar'), findsOneWidget);
    });

    testWidgets('tocar un usuario abre su perfil', (WidgetTester tester) async {
      UsuarioListado? abierto;
      await abrir(
        tester,
        pocos,
        abrirUsuario: (_, UsuarioListado u) => abierto = u,
      );

      await tester.tap(find.byKey(const Key('usuario-3')));
      await tester.pumpAndSettle();

      expect(abierto?.uid, '3');
    });
  });
}

class _ServicioFalso extends Fake implements UsuariosAdminService {
  _ServicioFalso(this.usuarios, this.error);

  final List<UsuarioListado> usuarios;
  final UsuariosAdminException? error;

  @override
  Future<List<UsuarioListado>> obtenerUsuarios() async {
    if (error != null) throw error!;
    return usuarios;
  }
}
