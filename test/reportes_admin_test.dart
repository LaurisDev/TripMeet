import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripmeet/publicaciones_reportadas_admin_screen.dart';
import 'package:tripmeet/reportes_admin_service.dart';
import 'package:tripmeet/resenas_reportadas_admin_screen.dart';

class MockReportesAdminService extends ReportesAdminService {
  MockReportesAdminService({
    this.resenas = const <ReporteResena>[],
    this.publicaciones = const <ReportePublicacion>[],
  });

  List<ReporteResena> resenas;
  List<ReportePublicacion> publicaciones;

  bool resenaResuelta = false;
  bool resenaEliminada = false;
  bool publicacionResuelta = false;
  bool publicacionEliminada = false;

  @override
  Future<List<ReporteResena>> obtenerResenasReportadas() async {
    return resenas;
  }

  @override
  Future<List<ReportePublicacion>> obtenerPublicacionesReportadas() async {
    return publicaciones;
  }

  @override
  Future<void> resolverReporteResena({
    required String reporteId,
    required String resenaId,
    String? usuarioCalificadoUid,
    String? lugarId,
    required bool eliminarResena,
  }) async {
    resenaResuelta = true;
    resenaEliminada = eliminarResena;
    resenas.removeWhere((ReporteResena r) => r.id == reporteId);
  }

  @override
  Future<void> resolverReportePublicacion({
    required String reporteId,
    required String publicacionId,
    required bool eliminarPublicacion,
  }) async {
    publicacionResuelta = true;
    publicacionEliminada = eliminarPublicacion;
    publicaciones.removeWhere((ReportePublicacion p) => p.id == reporteId);
  }
}

void main() {
  group('HU-33: Reseñas Reportadas Admin Screen', () {
    testWidgets('Muestra estado vacío si no hay reseñas reportadas',
        (WidgetTester tester) async {
      final MockReportesAdminService mockService = MockReportesAdminService();

      await tester.pumpWidget(
        MaterialApp(
          home: ResenasReportadasAdminScreen(service: mockService),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Reseñas reportadas'), findsOneWidget);
      expect(find.text('No hay reseñas reportadas pendientes'), findsOneWidget);
    });

    testWidgets('Muestra lista de reseñas reportadas con motivo y acciones',
        (WidgetTester tester) async {
      final MockReportesAdminService mockService = MockReportesAdminService(
        resenas: <ReporteResena>[
          ReporteResena(
            id: 'rep-1',
            resenaId: 'res-1',
            autorResenaNombre: 'Carlos Perez',
            comentarioResena: 'Este lugar es pesimo y una estafa',
            estrellas: 1,
            reportadoPorUid: 'usr-2',
            reportadoPorNombre: 'Maria Lopez',
            motivo: 'Lenguaje ofensivo y difamacion',
            fecha: DateTime.now(),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ResenasReportadasAdminScreen(service: mockService),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Reportado por: Maria Lopez'), findsOneWidget);
      expect(find.text('Lenguaje ofensivo y difamacion'), findsOneWidget);
      expect(find.text('"Este lugar es pesimo y una estafa"'), findsOneWidget);

      expect(find.byKey(const Key('eliminar-resena-rep-1')), findsOneWidget);
      expect(find.byKey(const Key('descartar-resena-rep-1')), findsOneWidget);
    });
  });

  group('HU-34: Publicaciones Reportadas Admin Screen', () {
    testWidgets('Muestra estado vacío si no hay publicaciones reportadas',
        (WidgetTester tester) async {
      final MockReportesAdminService mockService = MockReportesAdminService();

      await tester.pumpWidget(
        MaterialApp(
          home: PublicacionesReportadasAdminScreen(service: mockService),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Publicaciones reportadas'), findsOneWidget);
      expect(
          find.text('No hay publicaciones reportadas pendientes'), findsOneWidget);
    });

    testWidgets('Muestra lista de publicaciones reportadas y permite descartar',
        (WidgetTester tester) async {
      final MockReportesAdminService mockService = MockReportesAdminService(
        publicaciones: <ReportePublicacion>[
          ReportePublicacion(
            id: 'rep-pub-1',
            publicacionId: 'pub-100',
            autorPublicacionUid: 'usr-3',
            descripcionPublicacion: 'Foto no relacionada con viajes',
            reportadoPorUid: 'usr-4',
            reportadoPorNombre: 'Juan Gomez',
            motivo: 'Spam o contenido inapropiado',
            fecha: DateTime.now(),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PublicacionesReportadasAdminScreen(service: mockService),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Reportado por: Juan Gomez'), findsOneWidget);
      expect(find.text('Spam o contenido inapropiado'), findsOneWidget);
      expect(find.text('Foto no relacionada con viajes'), findsOneWidget);

      expect(
          find.byKey(const Key('eliminar-publicacion-rep-pub-1')), findsOneWidget);
      expect(
          find.byKey(const Key('descartar-publicacion-rep-pub-1')), findsOneWidget);
    });
  });
}
