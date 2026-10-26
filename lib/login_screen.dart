import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_theme.dart';
import 'auth_service.dart';
import 'home_screen.dart';

import 'panel_admin_certificados_screen.dart';
import 'registro_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.authService});

  final AuthService? authService;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _correoController = TextEditingController();

  final TextEditingController _passwordController = TextEditingController();

  bool _cargando = false;
  bool _obscurePassword = true;

  AuthService get _authService => widget.authService ?? AuthService();

  @override
  void dispose() {
    _correoController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double alto = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Imagen de fondo.
          Positioned.fill(
            child: Image.asset(
              'assets/images/atardecer_playa.jpg.jpg',
              fit: BoxFit.cover,
              alignment: const Alignment(0.0, 0.3),
            ),
          ),

          // Capa oscura para mejorar la lectura.
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.2),
                    AppTheme.crema.withValues(alpha: 0.9),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(height: alto * 0.2),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Card(
                      color: Colors.white.withValues(alpha: 0.95),
                      elevation: 12,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Nombre de la aplicación.
                              Text(
                                'TripMeet',
                                style: GoogleFonts.fraunces(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.azulPetroleo,
                                ),
                              ),

                              const SizedBox(height: 4),

                              Text(
                                'Qué alegría verte de nuevo.',
                                style: GoogleFonts.workSans(
                                  color: Colors.grey.shade600,
                                  fontSize: 16,
                                ),
                              ),

                              const SizedBox(height: 32),

                              // Campo de correo electrónico.
                              TextFormField(
                                controller: _correoController,
                                enabled: !_cargando,
                                keyboardType: TextInputType.emailAddress,
                                decoration: InputDecoration(
                                  labelText: 'Correo electrónico',
                                  prefixIcon: const Icon(Icons.email_outlined),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                ),
                                validator: (valor) {
                                  if (valor == null || valor.trim().isEmpty) {
                                    return 'Ingresa tu correo';
                                  }

                                  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                      .hasMatch(valor.trim())) {
                                    return 'Ingresa un correo válido';
                                  }

                                  return null;
                                },
                              ),

                              const SizedBox(height: 16),

                              // Campo de contraseña.
                              TextFormField(
                                controller: _passwordController,
                                enabled: !_cargando,
                                obscureText: _obscurePassword,
                                decoration: InputDecoration(
                                  labelText: 'Contraseña',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                    ),
                                    onPressed: _cargando
                                        ? null
                                        : () {
                                            setState(() {
                                              _obscurePassword =
                                                  !_obscurePassword;
                                            });
                                          },
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                ),
                                validator: (valor) {
                                  if (valor == null || valor.isEmpty) {
                                    return 'Ingresa tu contraseña';
                                  }

                                  return null;
                                },
                              ),

                              const SizedBox(height: 32),

                              // Botón para iniciar sesión.
                              SizedBox(
                                width: double.infinity,
                                height: 55,
                                child: ElevatedButton(
                                  onPressed: _cargando ? null : _iniciarSesion,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.azulPetroleo,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                  ),
                                  child: _cargando
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2.5,
                                          ),
                                        )
                                      : const Text(
                                          'Iniciar Sesión',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                ),
                              ),

                              const SizedBox(height: 20),

                              // Enlace para crear una cuenta.
                              Center(
                                child: TextButton(
                                  onPressed: _cargando
                                      ? null
                                      : () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  const RegistroScreen(),
                                            ),
                                          );
                                        },
                                  child: Text(
                                    '¿No tienes cuenta? '
                                    'Regístrate aquí',
                                    style: TextStyle(
                                      color: AppTheme.verdeAzulado,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Inicia sesión y dirige al usuario a su pantalla.
  Future<void> _iniciarSesion() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _cargando = true;
    });

    try {
      await _authService.iniciarSesion(
        _correoController.text.trim(),
        _passwordController.text,
      );

      if (!mounted) return;

      // Cuenta administrativa destinada a la demostración.
      if (esCorreoAdministrador(_correoController.text)) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => const PanelAdminCertificadosScreen(),
          ),
          (route) => false,
        );
      } else {
        // Los demás usuarios entran al mapa.
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => const HomeScreen(forzarIndiceMapa: true),
          ),
          (route) => false,
        );
      }
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _cargando = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error al entrar: $error')));
    }
  }
}
