
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tripmeet/guia_service.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late GuiaService guiaService;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    guiaService = GuiaService(firestore: firestore);
  });

  group('Pruebas de solicitudes de guías', () {
    test('Consulta las solicitudes que están en revisión', () async {
      await firestore.collection('usuarios').doc('guia1').set({
        'nombre': 'Guía Uno',
        'estadoCertificados': 'en_revision',
      });

      await firestore.collection('usuarios').doc('guia2').set({
        'nombre': 'Guía Dos',
        'estadoCertificados': 'aprobado',
      });

      final solicitudes =
          await guiaService.obtenerSolicitudesPendientes();

      expect(solicitudes.length, 1);
      expect(solicitudes.first['uid'], 'guia1');
      expect(solicitudes.first['nombre'], 'Guía Uno');
    });

    test('Aprueba una solicitud en revisión', () async {
      await firestore.collection('usuarios').doc('guia1').set({
        'estadoCertificados': 'en_revision',
      });

      await guiaService.aprobarSolicitud('guia1');

      final documento =
          await firestore.collection('usuarios').doc('guia1').get();

      expect(documento.data()?['estadoCertificados'], 'aprobado');
      expect(
        documento.data()?['motivoRechazoCertificados'],
        isNull,
      );
    });

    test('No permite aprobar una solicitud que no está en revisión',
        () async {
      await firestore.collection('usuarios').doc('guia1').set({
        'estadoCertificados': 'aprobado',
      });

      expect(
        () => guiaService.aprobarSolicitud('guia1'),
        throwsA(isA<GuiaServiceException>()),
      );
    });

    test('Rechaza una solicitud y guarda el motivo', () async {
      await firestore.collection('usuarios').doc('guia1').set({
        'estadoCertificados': 'en_revision',
      });

      await guiaService.rechazarSolicitud(
        userId: 'guia1',
        motivo: 'El documento está vencido.',
      );

      final documento =
          await firestore.collection('usuarios').doc('guia1').get();

      expect(documento.data()?['estadoCertificados'], 'rechazado');
      expect(
        documento.data()?['motivoRechazoCertificados'],
        'El documento está vencido.',
      );
    });

    test('No permite rechazar sin indicar un motivo', () async {
      await expectLater(
        guiaService.rechazarSolicitud(
          userId: 'guia1',
          motivo: '   ',
        ),
        throwsA(isA<GuiaServiceException>()),
      );
    });

    test('Solicita correcciones y guarda el motivo', () async {
      await firestore.collection('usuarios').doc('guia1').set({
        'estadoCertificados': 'en_revision',
      });

      await guiaService.solicitarCorrecciones(
        userId: 'guia1',
        motivo: 'Debes actualizar el carné de guía.',
      );

      final documento =
          await firestore.collection('usuarios').doc('guia1').get();

      expect(
        documento.data()?['estadoCertificados'],
        'requiere_correcciones',
      );
      expect(
        documento.data()?['motivoRechazoCertificados'],
        'Debes actualizar el carné de guía.',
      );
    });
  });
}