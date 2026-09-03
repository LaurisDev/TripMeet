import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'home_screen.dart';

/// Pantalla para crear una cuenta nueva en TripMeet.
class RegistroScreen extends StatefulWidget {
  const RegistroScreen({
    super.key,
    this.authService,
  });

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

  // La lista permite agregar nuevos roles sin cambiar el selector.
  static const List<String> _rolesDisponibles = <String>['Turista'];
  String _rolSeleccionado = _rolesDisponibles.first;
  String? _errorCorreo;
  bool _cargando = false;

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
    final double anchoPantalla = MediaQuery.of(context).size.width;
    final bool esPantallaPequena = anchoPantalla < 360;
    final double paddingHorizontal = esPantallaPequena ? 16 : 24;
    final double tamanoFuente = esPantallaPequena ? 15 : 16;

    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            paddingHorizontal,
            24,
            paddingHorizontal,
            32,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'Regístrate en TripMeet',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontSize: esPantallaPequena ? 23 : 26,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Completa tus datos para comenzar.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontSize: tamanoFuente,
                      ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _correoController,
                  enabled: !_cargando,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Correo electrónico',
                    prefixIcon: const Icon(Icons.email_outlined),
                    errorText: _errorCorreo,
                  ),
                  onChanged: (_) {
                    if (_errorCorreo != null) {
                      setState(() => _errorCorreo = null);
                    }
                  },
                  validator: (String? valor) {
                    if (valor == null || valor.trim().isEmpty) {
                      return 'Escribe tu correo electrónico.';
                    }
                    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                        .hasMatch(valor.trim())) {
                      return 'Escribe un correo electrónico válido.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  enabled: !_cargando,
                  obscureText: true,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: _validarPassword,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmarPasswordController,
                  enabled: !_cargando,
                  obscureText: true,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Confirmar contraseña',
                    prefixIcon: Icon(Icons.lock_reset_outlined),
                  ),
                  validator: (String? valor) {
                    if (valor == null || valor.isEmpty) {
                      return 'Confirma tu contraseña.';
                    }
                    if (valor != _passwordController.text) {
                      return 'Las contraseñas no coinciden.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _rolSeleccionado,
                  decoration: const InputDecoration(
                    labelText: 'Rol',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  items: _rolesDisponibles
                      .map(
                        (String rol) => DropdownMenuItem<String>(
                          value: rol,
                          child: Text(rol),
                        ),
                      )
                      .toList(),
                  onChanged: _cargando
                      ? null
                      : (String? nuevoRol) {
                          if (nuevoRol != null) {
                            setState(() => _rolSeleccionado = nuevoRol);
                          }
                        },
                ),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: _cargando ? null : _registrar,
                  child: _cargando
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Crear cuenta'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Valida la contraseña localmente antes de contactar con Firebase.
  String? _validarPassword(String? valor) {
    if (valor == null || valor.isEmpty) {
      return 'Escribe una contraseña.';
    }
    if (valor.length < 6) {
      return 'Debe tener al menos 6 caracteres.';
    }
    if (!RegExp(r'[A-Z]').hasMatch(valor)) {
      return 'Debe incluir al menos una mayúscula.';
    }
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(valor)) {
      return 'Debe incluir al menos un carácter especial.';
    }
    return null;
  }

  Future<void> _registrar() async {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _errorCorreo = null);

    // La validación del Form ocurre antes de iniciar cualquier petición.
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _cargando = true);
    try {
      await _authService.registrarUsuario(
        _correoController.text,
        _passwordController.text,
        _rolSeleccionado,
      );

      if (!mounted) {
        return;
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(
          builder: (_) => const HomeScreen(),
        ),
      );
    } on AuthServiceException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _cargando = false;
        if (error.code == 'email-already-in-use') {
          _errorCorreo = error.message;
        }
      });
      if (error.code != 'email-already-in-use') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _cargando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo completar el registro. Inténtalo de nuevo.'),
        ),
      );
    }
  }
}
