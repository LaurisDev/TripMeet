import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'auth_service.dart' show esCorreoAdministrador;
import 'firebase_options.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'panel_admin_certificados_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Widget _decidirPantallaInicial() {
    try {
      final User? usuario = FirebaseAuth.instance.currentUser;
      if (usuario != null) {
        if (esCorreoAdministrador(usuario.email)) {
          return const PanelAdminCertificadosScreen();
        }
        return const HomeScreen(forzarIndiceMapa: true);
      }
    } catch (_) {
      // Si Firebase no está inicializado (ej. en pruebas) muestra Login por defecto
    }
    return const LoginScreen();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TripMeet',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: _decidirPantallaInicial(),
    );
  }
}
