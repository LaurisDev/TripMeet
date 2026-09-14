import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:firebase_auth/firebase_auth.dart';

import 'app_theme.dart';
import 'auth_service.dart';
import 'guia_certificados_screen.dart';
import 'home_screen.dart';

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
          // --- IMAGEN DE FONDO (SUTIL Y ELEGANTE) ---
          Positioned.fill(
            child: Image.asset(
              'assets/images/atardecer_playa.jpg.jpg',
              fit: BoxFit.cover,
              alignment: const Alignment(0.0, 0.3),
            ),
          ),
          // --- OVERLAY PARA DAR PROFUNDIDAD ---
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.1),
                    Colors.black.withOpacity(0.3),
                    AppTheme.crema.withOpacity(0.85),
                  ],
                  stops: const [0.0, 0.4, 0.9],
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Espacio para que la imagen se vea
                  SizedBox(height: altoPantalla * 0.15),
                  // --- TARJETA PRINCIPAL ---
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: paddingHorizontal),
                    child: Card(
                      color: Colors.white.withOpacity(0.92),
                      elevation: 12,
                      shadowColor: Colors.black.withOpacity(0.15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
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
                                'Únete a la comunidad global',
                                style: GoogleFonts.workSans(
                                  fontSize: esPantallaPequena ? 22 : 24,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.azulPetroleo,
                                  height: 1.2,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Planifica juntos, viaja más lejos.',
                                style: GoogleFonts.workSans(
                                  fontSize: esPantallaPequena ? 14 : 16,
                                  color: AppTheme.textoSuave,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 24),

                              // --- CAMPO CORREO ---
                              TextFormField(
                                controller: _correoController,
                                enabled: !_cargando,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                decoration: InputDecoration(
                                  labelText: 'Correo electrónico',
                                  hintText: 'correo@viaje.com',
                                  prefixIcon: const Icon(Icons.email_outlined),
                                  errorText: _errorCorreo,
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade200,
                                      width: 1,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: AppTheme.verdeAzulado,
                                      width: 2,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
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
                              const SizedBox(height: 14),

                              // --- CAMPO CONTRASEÑA ---
                              TextFormField(
                                controller: _passwordController,
                                enabled: !_cargando,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.next,
                                decoration: InputDecoration(
                                  labelText: 'Contraseña',
                                  hintText: 'Crea una contraseña segura',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: Colors.grey.shade600,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade200,
                                      width: 1,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: AppTheme.verdeAzulado,
                                      width: 2,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                ),
                                validator: _validarPassword,
                              ),
                              const SizedBox(height: 14),

                              // --- CAMPO CONFIRMAR CONTRASEÑA ---
                              TextFormField(
                                controller: _confirmarPasswordController,
                                enabled: !_cargando,
                                obscureText: _obscureConfirmPassword,
                                textInputAction: TextInputAction.next,
                                decoration: InputDecoration(
                                  labelText: 'Confirmar contraseña',
                                  hintText: 'Confirma tu contraseña',
                                  prefixIcon:
                                      const Icon(Icons.lock_reset_outlined),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureConfirmPassword
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: Colors.grey.shade600,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscureConfirmPassword =
                                            !_obscureConfirmPassword;
                                      });
                                    },
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade200,
                                      width: 1,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: AppTheme.verdeAzulado,
                                      width: 2,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
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
                              const SizedBox(height: 18),

                              // --- SELECTOR DE ROL ---
                              Text(
                                'Rol',
                                style: GoogleFonts.workSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.azulPetroleo,
                                ),
                              ),
                              const SizedBox(height: 10),
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
                              const SizedBox(height: 6),
                              Text(
                                _rolSeleccionado == _rolesDisponibles[0]
                                    ? 'Cuéntanos cuál es tu enfoque de viaje.'
                                    : 'Comparte tu experiencia y conecta viajeros.',
                                style: GoogleFonts.workSans(
                                  fontSize: 12,
                                  color: AppTheme.textoSuave.withOpacity(0.7),
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              const SizedBox(height: 28),

                              // --- BOTÓN CREAR CUENTA ---
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: FilledButton(
                                  onPressed: _cargando ? null : _registrar,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppTheme.naranjaQuemado,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 2,
                                  ),
                                  child: _cargando
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text(
                                          'Crear cuenta y explorar',
                                          style: GoogleFonts.workSans(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // --- ENLACE A LOGIN ---
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '¿Ya tienes cuenta?',
                                    style: GoogleFonts.workSans(
                                      color: AppTheme.textoSuave,
                                      fontSize: 14,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      // Navegar a Login
                                    },
                                    child: Text(
                                      ' Iniciar sesión',
                                      style: GoogleFonts.workSans(
                                        color: AppTheme.verdeAzulado,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
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
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: seleccionado ? AppTheme.naranjaQuemado : Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: seleccionado ? AppTheme.naranjaQuemado : Colors.grey.shade300,
            width: 1.5,
          ),
          boxShadow: seleccionado
              ? [
                  BoxShadow(
                    color: AppTheme.naranjaQuemado.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
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
            Flexible(
              child: Text(
                rol,
                style: GoogleFonts.workSans(
                  fontSize: 14,
                  fontWeight: seleccionado ? FontWeight.w600 : FontWeight.w500,
                  color: seleccionado ? Colors.white : AppTheme.azulPetroleo,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _validarPassword(String? valor) {
    if (valor == null || valor.isEmpty) {
      return 'Ingresa una contraseña';
    }
    if (valor.length < 6) {
      return 'Mínimo 6 caracteres';
    }
    if (!RegExp(r'[A-Z]').hasMatch(valor)) {
      return 'Incluye al menos una mayúscula';
    }
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(valor)) {
      return 'Incluye al menos un carácter especial';
    }
    return null;
  }

  Future<void> _registrar() async {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _errorCorreo = null);

    if (!_formKey.currentState!.validate()) {
      return;
    }

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
        // El guía continúa con la subida de certificados (Pantalla 2).
        Navigator.pushReplacement(
          context,
          MaterialPageRoute<void>(
            builder: (_) => GuiaCertificadosScreen(userId: uid),
          ),
        );
      } else {
        // El turista entra directo al Home.
        Navigator.pushReplacement(
          context,
          MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
        );
      }
    } on AuthServiceException catch (error) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        if (error.code == 'email-already-in-use') {
          _errorCorreo = error.message;
        }
      });
      if (error.code != 'email-already-in-use') {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _cargando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo completar el registro. Inténtalo de nuevo.'),
        ),
      );
    }
  }
}