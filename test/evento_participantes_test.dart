import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripmeet/evento_detalle_screen.dart';
import 'package:tripmeet/evento_service.dart';
import 'package:tripmeet/perfil_usuario_screen.dart';
import 'package:tripmeet/publicacion_service.dart';

Evento _evento({List<String> inscritos = const <String>[], int? cupo}) =>
    Evento(
      id: 'evento-1',
      creadorUid: 'creador',
      nombre: 'Caminata al cerro',
      lugar: 'Medellín',
      fechaHora: DateTime(2100, 1, 1, 8),
      fechaCreacion: DateTime(2026, 1, 1),
      cupoMaximo: cupo,
      inscritos: inscritos,
    );

const Map<String, Map<String, dynamic>> _perfiles =
    <String, Map<String, dynamic>>{
  'creador': <String, dynamic>{'correo': 'org@gmail.com', 'rol': 'Turista'},
  'ana': <String, dynamic>{'correo': 'ana@gmail.com', 'rol': 'Turista'},
  'luis': <String, dynamic>{
    'correo': 'luis@gmail.com',
    'rol': 'Guía turístico',
    'estadoCertificados': 'aprobado',
    'certificados': <String, dynamic>{
      'carneGuia': <String, dynamic>{
        'nombre': 'carne.pdf',
        'url': 'https://res.cloudinary.com/demo/carne.pdf',
      },
      'antecedentesJudiciales': <String, dynamic>{
        'nombre': 'antecedentes.pdf',
        'url': 'https://res.cloudinary.com/demo/antecedentes.pdf',
      },
    },
    'perfilLaboral': <String, dynamic>{
      'aniosExperiencia': 5,
      'idiomas': <String>['Español', 'Inglés'],
    },
  },
  'sofia': <String, dynamic>{
    'correo': 'sofia@gmail.com',
    'rol': 'Guía turístico',
    'estadoCertificados': 'en_revision',
  },
};

Future<void> _abrir(WidgetTester tester, Evento evento) async {
  await tester.pumpWidget(
    MaterialApp(
      home: EventoDetalleScreen(
        evento: evento,
        cargarPerfil: (String uid) async => _perfiles[uid],
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('sin inscritos muestra que aún no hay personas unidas',
      (WidgetTester tester) async {
    await _abrir(tester, _evento());

    expect(find.text('Participantes (0)'), findsOneWidget);
    expect(
      find.text('Aún no hay personas unidas a este evento.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('evento-participantes')), findsNothing);
  });

  testWidgets('con inscritos lista a cada participante y el cupo usado',
      (WidgetTester tester) async {
    await _abrir(tester, _evento(inscritos: <String>['ana', 'luis'], cupo: 10));

    expect(find.text('Participantes (2/10)'), findsOneWidget);
    expect(
      find.text('Aún no hay personas unidas a este evento.'),
      findsNothing,
    );

    final Finder lista = find.byKey(const Key('evento-participantes'));
    expect(
      find.descendant(of: lista, matching: find.text('ana')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: lista, matching: find.text('luis')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: lista, matching: find.text('Guía turístico')),
      findsOneWidget,
    );
  });

  group('perfil del usuario', () {
    testWidgets('tocar al organizador abre su perfil',
        (WidgetTester tester) async {
      await _abrir(tester, _evento());

      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('evento-organizador')),
          matching: find.text('org'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PerfilUsuarioScreen), findsOneWidget);
      expect(find.text('Turista'), findsOneWidget);
      // Un turista no tiene sección de certificados.
      expect(find.text('Certificados'), findsNothing);
    });

    testWidgets('un guía aprobado muestra su perfil laboral y su carné, '
        'pero no los antecedentes', (WidgetTester tester) async {
      await _abrir(tester, _evento(inscritos: <String>['luis']));

      await tester.ensureVisible(find.text('luis'));
      await tester.tap(find.text('luis'));
      await tester.pumpAndSettle();

      expect(find.byType(PerfilUsuarioScreen), findsOneWidget);
      expect(find.text('5 años de experiencia'), findsOneWidget);
      expect(find.text('Español, Inglés'), findsOneWidget);
      expect(find.text('Certificados'), findsOneWidget);
      expect(find.text('Ver certificado'), findsOneWidget);
      expect(find.textContaining('antecedentes'), findsNothing);
    });

    testWidgets('un guía en revisión no muestra archivos',
        (WidgetTester tester) async {
      await _abrir(tester, _evento(inscritos: <String>['sofia']));

      await tester.ensureVisible(find.text('sofia'));
      await tester.tap(find.text('sofia'));
      await tester.pumpAndSettle();

      expect(find.text('Ver certificado'), findsNothing);
      expect(
        find.text('Los certificados de este guía están en revisión.'),
        findsOneWidget,
      );
    });
  });

  group('publicaciones en el perfil', () {
    Future<void> abrirPerfil(
      WidgetTester tester,
      List<Publicacion> publicaciones,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PerfilUsuarioScreen(
            uid: 'ana',
            cargarPerfil: (String uid) async => _perfiles[uid],
            cargarPublicaciones: (String uid) async => publicaciones,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('muestra la grilla con las publicaciones del usuario',
        (WidgetTester tester) async {
      await abrirPerfil(tester, <Publicacion>[
        for (int i = 0; i < 2; i++)
          Publicacion(
            id: 'p$i',
            uid: 'ana',
            imagenUrl: 'https://res.cloudinary.com/demo/p$i.jpg',
            imagenPublicId: 'p$i',
            fechaCreacion: DateTime(2026, 1, 1),
          ),
      ]);

      expect(find.text('Publicaciones'), findsOneWidget);
      expect(find.text('(2)'), findsOneWidget);
      expect(find.byKey(const Key('perfil-publicaciones')), findsOneWidget);
    });

    testWidgets('sin publicaciones lo indica', (WidgetTester tester) async {
      await abrirPerfil(tester, <Publicacion>[]);

      expect(find.text('Aún no tiene publicaciones.'), findsOneWidget);
    });
  });
}
