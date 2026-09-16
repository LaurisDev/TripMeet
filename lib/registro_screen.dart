import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:firebase_auth/firebase_auth.dart';

import 'app_theme.dart';
import 'auth_service.dart';
import 'guia_certificados_screen.dart';
import 'home_screen.dart';
import 'login_screen.dart';

/// Pantalla de registro con imagen de fondo sutil y tarjeta elegante.
class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key, this.authService});

  final AuthService? authService;

  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _correoController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmarPasswordController =
      TextEditingController();

  static const List<String> _rolesDisponibles = <String>[
    'Turista',
    'Guía turístico',
  ];
  String _rolSeleccionado = _rolesDisponibles.first;
  String? _errorCorreo;
  bool _cargando = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  AuthService get _authService => widget.authService ?? AuthService();

  @override
  void dispose() {
    _correoController.dispose();
    _passwordController.dispose();
    _confirmarPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool esPantallaPequena = MediaQuery.of(context).size.width < 360;
    final double paddingHorizontal = esPantallaPequena ? 16 : 24;
    final double altoPantalla = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // --- IMAGEN DE FONDO (IGUAL A LOGIN) ---
          Positioned.fill(
            child: Image.asset(
              'assets/images/atardecer_playa.jpg.jpg',
              fit: BoxFit.cover,
              alignment: const Alignment(0.0, 0.3),
            ),
          ),
          // --- OVERLAY PARA DAR PROFUNDIDAD (Sincronizado con Login) ---
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
                  // Espacio para que la imagen se vea
                  SizedBox(height: altoPantalla * 0.1),
                  // --- TARJETA PRINCIPAL ---
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: paddingHorizontal,
                    ),
                    child: Card(
                      color: Colors.white.withValues(alpha: 0.95),
                      elevation: 12,
                      shadowColor: Colors.black.withValues(alpha: 0.15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(esPantallaPequena ? 20 : 28),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // --- HEADER ---
                              Text(
                                'Únete a TripMeet',
                                style: GoogleFonts.fraunces(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.azulPetroleo,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Planifica juntos, viaja más lejos.',
                                style: GoogleFonts.workSans(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 32),

                              // --- CAMPO CORREO ---
                              TextFormField(
                                controller: _correoController,
                                enabled: !_cargando,
                                decoration: InputDecoration(
                                  labelText: 'Correo electrónico',
                                  prefixIcon: const Icon(Icons.email_outlined),
                                  errorText: _errorCorreo,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                ),
                                validator: (String? valor) {
                                  if (valor == null || valor.trim().isEmpty) {
                                    return 'Ingresa tu correo electrónico';
                                  }
                                  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                      .hasMatch(valor.trim())) {
                                    return 'Correo electrónico inválido';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // --- CAMPO CONTRASEÑA ---
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
                                      color: Colors.grey.shade600,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                ),
                                validator: _validarPassword,
                              ),
                              const SizedBox(height: 16),

                              // --- CAMPO CONFIRMAR CONTRASEÑA ---
                              TextFormField(
                                controller: _confirmarPasswordController,
                                enabled: !_cargando,
                                obscureText: _obscureConfirmPassword,
                                decoration: InputDecoration(
                                  labelText: 'Confirmar contraseña',
                                  prefixIcon: const Icon(Icons.lock_reset_outlined),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureConfirmPassword
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                      color: Colors.grey.shade600,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscureConfirmPassword =
                                            !_obscureConfirmPassword;
                                      });
                                    },
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                ),
                                validator: (String? valor) {
                                  if (valor == null || valor.isEmpty) {
                                    return 'Confirma tu contraseña';
                                  }
                                  if (valor != _passwordController.text) {
                                    return 'Las contraseñas no coinciden';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 24),

                              // --- SELECTOR DE ROL ---
                              Text(
                                'Tu rol de viajero',
                                style: GoogleFonts.workSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.azulPetroleo,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildRolButton(
                                      rol: _rolesDisponibles[0],
                                      icono: Icons.person_outline,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _buildRolButton(
                                      rol: _rolesDisponibles[1],
                                      icono: Icons.explore_outlined,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 32),

                              // --- BOTÓN CREAR CUENTA ---
                              SizedBox(
                                width: double.infinity,
                                height: 55,
                                child: ElevatedButton(
                                  onPressed: _cargando ? null : _registrar,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.azulPetroleo, // IGUAL A LOGIN
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                  ),
                                  child: _cargando
                                      ? const CircularProgressIndicator(color: Colors.white)
                                      : const Text(
                                          'Registrarse',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 20),

                              // --- ENLACE A LOGIN ---
                              Center(
                                child: TextButton(
                                  onPressed: () {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute<void>(
                                        builder: (_) => const LoginScreen(),
                                      ),
                                    );
                                  },
                                  child: Text(
                                    '¿Ya tienes cuenta? Inicia sesión',
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
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRolButton({required String rol, required IconData icono}) {
    final bool seleccionado = _rolSeleccionado == rol;
    return GestureDetector(
      onTap: _cargando ? null : () => setState(() => _rolSeleccionado = rol),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: seleccionado ? AppTheme.azulPetroleo : Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: seleccionado ? AppTheme.azulPetroleo : Colors.grey.shade300,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icono,
              size: 18,
              color: seleccionado ? Colors.white : AppTheme.azulPetroleo,
            ),
            const SizedBox(width: 8),
            Text(
              rol,
              style: TextStyle(
                fontSize: 14,
                fontWeight: seleccionado ? FontWeight.bold : FontWeight.w500,
                color: seleccionado ? Colors.white : AppTheme.azulPetroleo,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _validarPassword(String? valor) {
    if (valor == null || valor.isEmpty) return 'Ingresa una contraseña';
    if (valor.length < 6) return 'Mínimo 6 caracteres';
    return null;
  }

  Future<void> _registrar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _cargando = true);
    try {
      final UserCredential credenciales = await _authService.registrarUsuario(
        _correoController.text.trim(),
        _passwordController.text,
        _rolSeleccionado,
      );
      if (!mounted) return;
      final bool esGuia = _rolSeleccionado == 'Guía turístico';
      final String? uid = credenciales.user?.uid;
      if (esGuia && uid != null) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => GuiaCertificadosScreen(userId: uid)));
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen(forzarIndiceMapa: true)));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}
