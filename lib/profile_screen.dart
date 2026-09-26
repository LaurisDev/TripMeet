import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'form_styles.dart';
import 'nueva_publicacion_screen.dart';
import 'preferences_screen.dart';
import 'publicacion_service.dart';
import 'widgets/aviso_error.dart';

/// Pantalla de Perfil: encabezado con los datos básicos del turista, una
/// lista de opciones de configuración y la grilla de publicaciones propias
/// (estilo Instagram).
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final PublicacionService _publicacionService = PublicacionService();

  List<Publicacion> _publicaciones = <Publicacion>[];
  bool _cargandoPublicaciones = true;
  String? _errorPublicaciones;

  @override
  void initState() {
    super.initState();
    _cargarPublicaciones();
  }

  Future<void> _cargarPublicaciones() async {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _cargandoPublicaciones = false);
      return;
    }

    setState(() {
      _cargandoPublicaciones = true;
      _errorPublicaciones = null;
    });

    try {
      final List<Publicacion> publicaciones =
          await _publicacionService.obtenerPublicacionesDeUsuario(uid);
      setState(() => _publicaciones = publicaciones);
    } on PublicacionServiceException catch (error) {
      setState(() => _errorPublicaciones = error.message);
    } finally {
      setState(() => _cargandoPublicaciones = false);
    }
  }

  Future<void> _abrirNuevaPublicacion() async {
    final bool? publicado = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const NuevaPublicacionScreen(),
      ),
    );
    if (publicado == true) {
      _cargarPublicaciones();
    }
  }

  @override
  Widget build(BuildContext context) {
    final String correo = FirebaseAuth.instance.currentUser?.email ?? '';

    return Scaffold(
      backgroundColor: AppTheme.crema,
      appBar: AppBar(
        title: const Text('Perfil'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Nueva publicación',
            onPressed: _abrirNuevaPublicacion,
            icon: const Icon(Icons.add_a_photo_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _cargarPublicaciones,
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
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  FormStyles.s20,
                  FormStyles.s20,
                  FormStyles.s20,
                  FormStyles.s12,
                ),
                child: Text('Mis publicaciones', style: FormStyles.etiqueta()),
              ),
              _buildPublicaciones(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPublicaciones() {
    if (_cargandoPublicaciones) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: FormStyles.s24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorPublicaciones != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: FormStyles.s20),
        child: AvisoError(mensaje: _errorPublicaciones!),
      );
    }

    if (_publicaciones.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: FormStyles.s20,
          vertical: FormStyles.s24,
        ),
        child: Column(
          children: <Widget>[
            Icon(
              Icons.photo_camera_outlined,
              size: 40,
              color: AppTheme.textoSuave.withValues(alpha: 0.4),
            ),
            const SizedBox(height: FormStyles.s8),
            Text(
              'Aún no tienes publicaciones. ¡Comparte tu primera experiencia!',
              textAlign: TextAlign.center,
              style: FormStyles.subtitulo(pequena: true),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: FormStyles.s4),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
        ),
        itemCount: _publicaciones.length,
        itemBuilder: (BuildContext context, int index) {
          final Publicacion publicacion = _publicaciones[index];
          return Image.network(publicacion.imagenUrl, fit: BoxFit.cover);
        },
      ),
    );
  }
}
