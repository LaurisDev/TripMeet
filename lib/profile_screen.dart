import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'form_styles.dart';
import 'preferences_screen.dart';

/// Pantalla de Perfil: encabezado con los datos básicos del turista y una
/// lista de opciones de configuración (hoy solo preferencias de
/// recomendación, pensada para crecer con más ajustes más adelante).
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final String correo = FirebaseAuth.instance.currentUser?.email ?? '';

    return Scaffold(
      backgroundColor: AppTheme.crema,
      appBar: AppBar(title: const Text('Perfil')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: FormStyles.s20),
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: FormStyles.s20),
              child: Row(
                children: <Widget>[
                  const CircleAvatar(
                    radius: 28,
                    backgroundColor: AppTheme.azulPetroleo,
                    child: Icon(Icons.person, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: FormStyles.s16),
                  Expanded(
                    child: Text(
                      correo.isEmpty ? 'Tu cuenta' : correo,
                      style: FormStyles.titulo(pequena: true),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: FormStyles.s24),
            const Divider(height: 1, color: FormStyles.colorBorde),
            ListTile(
              leading: const Icon(Icons.tune_rounded, color: AppTheme.azulPetroleo),
              title: const Text('Preferencias de recomendación'),
              subtitle: const Text('Elige tus categorías de interés favoritas'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const PreferencesScreen(),
                  ),
                );
              },
            ),
            const Divider(height: 1, color: FormStyles.colorBorde),
          ],
        ),
      ),
    );
  }
}
