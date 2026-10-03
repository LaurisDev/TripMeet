import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'form_styles.dart';
import 'nueva_publicacion_screen.dart';
import 'preferences_screen.dart';
import 'publicacion_detalle_screen.dart';
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
              const SizedBox(height: FormStyles.s20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: FormStyles.s20),
                child: _BotonPreferencias(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const PreferencesScreen(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: FormStyles.s8),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  FormStyles.s20,
                  FormStyles.s20,
                  FormStyles.s20,
                  FormStyles.s12,
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(
                      Icons.grid_on_rounded,
                      size: 18,
                      color: AppTheme.azulPetroleo,
                    ),
                    const SizedBox(width: FormStyles.s8),
                    Text('Mis publicaciones', style: FormStyles.etiqueta()),
                    if (_publicaciones.isNotEmpty) ...<Widget>[
                      const SizedBox(width: FormStyles.s8),
                      Text(
                        '(${_publicaciones.length})',
                        style: FormStyles.cuerpo(
                          size: 13,
                          color: AppTheme.textoSuave.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ],
                ),
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: FormStyles.s16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: FormStyles.s8,
          mainAxisSpacing: FormStyles.s8,
        ),
        itemCount: _publicaciones.length + 1,
        itemBuilder: (BuildContext context, int index) {
          if (index == 0) {
            return _AgregarPublicacionTile(onTap: _abrirNuevaPublicacion);
          }
          final Publicacion publicacion = _publicaciones[index - 1];
          return _PublicacionMiniatura(
            publicacion: publicacion,
            onActualizada: _reemplazarPublicacion,
          );
        },
      ),
    );
  }

  /// Refleja en la grilla una publicación editada sin volver a consultar
  /// Firestore.
  void _reemplazarPublicacion(Publicacion actualizada) {
    if (!mounted) return;
    setState(() {
      _publicaciones = <Publicacion>[
        for (final Publicacion p in _publicaciones)
          p.id == actualizada.id ? actualizada : p,
      ];
    });
  }
}

/// Tile cuadrado con un "+" para crear una nueva publicación, ubicado junto
/// a las publicaciones existentes en la grilla del perfil.
class _AgregarPublicacionTile extends StatelessWidget {
  const _AgregarPublicacionTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.crema,
      borderRadius: BorderRadius.circular(FormStyles.radio),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(FormStyles.radio),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(FormStyles.radio),
            border: Border.all(
              color: AppTheme.azulPetroleo.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: const Center(
            child: Icon(
              Icons.add_rounded,
              size: 28,
              color: AppTheme.azulPetroleo,
            ),
          ),
        ),
      ),
    );
  }
}

/// Miniatura de una publicación dentro de la grilla del perfil: foto con
/// esquinas redondeadas que, al tocarla, abre el detalle con la descripción
/// completa mediante una transición Hero.
class _PublicacionMiniatura extends StatelessWidget {
  const _PublicacionMiniatura({
    required this.publicacion,
    required this.onActualizada,
  });

  final Publicacion publicacion;
  final ValueChanged<Publicacion> onActualizada;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(FormStyles.radio),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => PublicacionDetalleScreen(
                publicacion: publicacion,
                onPublicacionActualizada: onActualizada,
              ),
            ),
          );
        },
        child: Hero(
          tag: 'publicacion-${publicacion.id}',
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Image.network(
                publicacion.imagenUrl,
                fit: BoxFit.cover,
                loadingBuilder: (BuildContext context, Widget child,
                    ImageChunkEvent? progress) {
                  if (progress == null) return child;
                  return Container(
                    color: AppTheme.crema,
                    child: const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                },
                errorBuilder: (BuildContext context, Object error,
                        StackTrace? stackTrace) =>
                    Container(
                  color: AppTheme.crema,
                  child: Icon(
                    Icons.broken_image_outlined,
                    size: 20,
                    color: AppTheme.textoSuave.withValues(alpha: 0.4),
                  ),
                ),
              ),
              if (publicacion.descripcion != null)
                Positioned(
                  right: FormStyles.s4,
                  bottom: FormStyles.s4,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(FormStyles.s4),
                    ),
                    child: const Icon(
                      Icons.chat_bubble_rounded,
                      size: 10,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Botón compacto para entrar a Preferencias de recomendación: ícono
/// destacado en un chip circular, texto breve y una tarjeta pequeña en vez
/// del ListTile ancho anterior.
class _BotonPreferencias extends StatelessWidget {
  const _BotonPreferencias({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(FormStyles.radio),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(FormStyles.radio),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: FormStyles.s16,
            vertical: FormStyles.s12,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(FormStyles.radio),
            border: Border.all(color: FormStyles.colorBorde),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.verdeAzulado.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  size: 18,
                  color: AppTheme.verdeAzulado,
                ),
              ),
              const SizedBox(width: FormStyles.s12),
              Expanded(
                child: Text(
                  'Preferencias de recomendación',
                  style: FormStyles.cuerpo(
                    size: 14,
                    weight: FontWeight.w600,
                    color: AppTheme.azulPetroleo,
                  ),
                ),
              ),
              const SizedBox(width: FormStyles.s8),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppTheme.textoSuave.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
