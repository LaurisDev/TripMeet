import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tripmeet/chat_evento_screen.dart';
import 'package:tripmeet/evento_service.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late MockFirebaseAuth mockAuth;
  late Evento eventoPrueba;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    mockAuth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(
        uid: 'user_123',
        email: 'turista@tripmeet.com',
        displayName: 'Turista Prueba',
      ),
    );

    eventoPrueba = Evento(
      id: 'evento_99',
      creadorUid: 'creador_1',
      nombre: 'Caminata Guatavita',
      lugar: 'Guatavita, Cundinamarca',
      fechaHora: DateTime.now().add(const Duration(days: 2)),
      fechaCreacion: DateTime.now(),
    );
  });

  testWidgets('Muestra interfaz de chat e impide mensajes vacíos (Criterio 2)',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChatEventoScreen(
          evento: eventoPrueba,
          firestore: fakeFirestore,
          auth: mockAuth,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verificamos que la pantalla carga con el nombre del evento
    expect(find.text('Caminata Guatavita'), findsOneWidget);
    expect(find.text('¡Sé el primero en escribir!'), findsOneWidget);

    // Intentamos enviar un mensaje vacío (Criterio 2)
    final Finder botonEnviar = find.byIcon(Icons.send_rounded);
    expect(botonEnviar, findsOneWidget);
    await tester.tap(botonEnviar);
    await tester.pumpAndSettle();

    // Verificamos que no se creó ningún mensaje en Firestore
    final snapshot = await fakeFirestore
        .collection('eventos')
        .doc('evento_99')
        .collection('mensajes')
        .get();
    expect(snapshot.docs.isEmpty, isTrue);
  });

  testWidgets('Permite escribir y enviar mensaje en tiempo real (Criterio 1)',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChatEventoScreen(
          evento: eventoPrueba,
          firestore: fakeFirestore,
          auth: mockAuth,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Escribimos un mensaje válido
    final Finder campoTexto = find.byType(TextField);
    await tester.enterText(campoTexto, '¡Hola a todos! ¿A qué hora nos vemos?');
    await tester.pumpAndSettle();

    // Presionamos enviar
    final Finder botonEnviar = find.byIcon(Icons.send_rounded);
    await tester.tap(botonEnviar);
    await tester.pumpAndSettle();

    // Verificamos que el mensaje aparece en la pantalla
    expect(find.text('¡Hola a todos! ¿A qué hora nos vemos?'), findsOneWidget);

    // Verificamos que se guardó en Firestore
    final snapshot = await fakeFirestore
        .collection('eventos')
        .doc('evento_99')
        .collection('mensajes')
        .get();
    expect(snapshot.docs.length, equals(1));
    expect(
      snapshot.docs.first.data()['texto'],
      equals('¡Hola a todos! ¿A qué hora nos vemos?'),
    );
  });
}
