import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'evento_detalle_screen.dart';
import 'evento_service.dart';
import 'form_styles.dart';
import 'publicacion_detalle_screen.dart';
import 'publicacion_service.dart';
import 'widgets/evento_guia_estilo.dart';
import 'widgets/imagen_remota.dart';

/// Lee las publicaciones de un usuario, de la más reciente a la más antigua.
typedef CargarPublicaciones = Future<List<Publicacion>> Function(String uid);

// async: si Firebase no está inicializado (pruebas), el error queda en el
// Future y la pantalla muestra el aviso en vez de fallar.
Future<List<Publicacion>> cargarPublicacionesDeFirestore(String uid) async =>
    PublicacionService().obtenerPublicacionesDeUsuario(uid);

/// Abre el perfil del usuario [uid] desde cualquier pantalla (eventos,
/// publicaciones o reseñas). No hace nada si [uid] está vacío.
void abrirPerfilUsuario(BuildContext context, String? uid) {
  if (uid == null || uid.isEmpty) return;
  Navigator.push<void>(
    context,
    MaterialPageRoute<void>(builder: (_) => PerfilUsuarioScreen(uid: uid)),
  );
}

/// Datos de `usuarios/{uid}` que se pueden mostrar a otros usuarios.
class PerfilPublico {
  const PerfilPublico(this.datos);

  /// Documento `usuarios/{uid}`; `null` si no existe o no se pudo leer.
  final Map<String, dynamic>? datos;

  /// `nombre` del perfil; si no tiene, la parte del correo antes de la "@".
  String get nombre {
    final dynamic nombre = datos?['nombre'];
    if (nombre is String && nombre.trim().isNotEmpty) return nombre.trim();
    return AutorPublicacion.aliasDesdeCorreo(datos?['correo']);
  }

  String? get fotoUrl {
    final dynamic foto = datos?['fotoUrl'];
    return foto is String && foto.trim().isNotEmpty ? foto.trim() : null;
  }

  /// "Turista" o "Guía turístico"; `null` si no tiene un rol conocido.
  String? get rol {
    final dynamic rol = datos?['rol'];
    final String? limpio = rol is String ? rol.trim() : null;
    return AutorPublicacion.rolesConocidos.contains(limpio) ? limpio : null;
  }

  bool get esGuia => EventoService.esGuia(datos);

  /// Estado de revisión de los certificados del guía.
  String? get estadoCertificados {
    final dynamic estado = datos?['estadoCertificados'];
    return estado is String ? estado : null;
  }

  /// Perfil laboral del guía (`perfilLaboral`); vacío si no lo llenó.
  Map<String, dynamic> get perfilLaboral {
    final dynamic laboral = datos?['perfilLaboral'];
    return laboral is Map<String, dynamic> ? laboral : <String, dynamic>{};
  }
}

/// Foto del usuario o, si no tiene o no carga, su inicial.
class AvatarUsuario extends StatelessWidget {
  const AvatarUsuario({required this.perfil, this.radio = 24, super.key});

  final PerfilPublico perfil;
  final double radio;

  @override
  Widget build(BuildContext context) {
    final String? fotoUrl = perfil.fotoUrl;

    return CircleAvatar(
      radius: radio,
      backgroundColor: AppTheme.azulPetroleo,
      foregroundImage: fotoUrl == null ? null : NetworkImage(fotoUrl),
      onForegroundImageError: fotoUrl == null
          ? null
          : (Object error, StackTrace? stackTrace) {},
      child: Text(
        perfil.nombre.characters.first.toUpperCase(),
        style: FormStyles.cuerpo(
          size: radio * 0.75,
          weight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Perfil de otro usuario: foto, nombre, rol y sus publicaciones. Si es guía
/// turístico, también su perfil laboral y su carné de guía (solo cuando está
/// aprobado; los antecedentes judiciales y los certificados adicionales no se
/// muestran).
class PerfilUsuarioScreen extends StatefulWidget {
  const PerfilUsuarioScreen({
    required this.uid,
    this.cargarPerfil = cargarPerfilDeFirestore,
    this.abrirEnlace = abrirEnlaceExterno,
    this.cargarPublicaciones = cargarPublicacionesDeFirestore,
    super.key,
  });

  final String uid;

  /// Lee el perfil `usuarios/{uid}` (inyectable en pruebas).
  final CargarPerfil cargarPerfil;

  /// Abre el PDF del certificado (inyectable en pruebas).
  final AbrirEnlace abrirEnlace;

  /// Lee las publicaciones del usuario (inyectable en pruebas).
  final CargarPublicaciones cargarPublicaciones;

  @override
  State<PerfilUsuarioScreen> createState() => _PerfilUsuarioScreenState();
}

class _PerfilUsuarioScreenState extends State<PerfilUsuarioScreen> {
  late Future<Map<String, dynamic>?> _perfil;
  late Future<List<Publicacion>> _publicaciones;

  @override
  void initState() {
    super.initState();
    _perfil = widget.cargarPerfil(widget.uid);
    _cargarPublicaciones();
  }

  void _cargarPublicaciones() {
    _publicaciones = widget.cargarPublicaciones(widget.uid);
    // Su FutureBuilder aparece hasta que carga el perfil; así un error que
    // llegue antes no queda como no manejado.
    _publicaciones.ignore();
  }

  /// Si el dueño edita o elimina una publicación desde el detalle, se
  /// vuelve a consultar la lista.
  void _recargarPublicaciones([Object? _]) {
    if (!mounted) return;
    setState(_cargarPublicaciones);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.crema,
      appBar: AppBar(title: const Text('Perfil')),
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>?>(
          future: _perfil,
          builder:
              (
                BuildContext context,
                AsyncSnapshot<Map<String, dynamic>?> snapshot,
              ) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.data == null) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(FormStyles.s20),
                      child: Text(
                        'No se pudo cargar el perfil de este usuario.',
                        textAlign: TextAlign.center,
                        style: FormStyles.ayuda(),
                      ),
                    ),
                  );
                }
                return _buildPerfil(PerfilPublico(snapshot.data));
              },
        ),
      ),
    );
  }

  Widget _buildPerfil(PerfilPublico perfil) {
    final String? rol = perfil.rol;

    return ListView(
      padding: const EdgeInsets.all(FormStyles.s20),
      children: <Widget>[
        Row(
          children: <Widget>[
            AvatarUsuario(perfil: perfil, radio: 32),
            const SizedBox(width: FormStyles.s16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    perfil.nombre,
                    style: FormStyles.titulo(pequena: true),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (rol != null) ...<Widget>[
                    const SizedBox(height: FormStyles.s4),
                    Text(rol, style: FormStyles.ayuda()),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (perfil.esGuia) ...<Widget>[
          const SizedBox(height: FormStyles.s24),
          _PerfilLaboral(datos: perfil.perfilLaboral),
          const SizedBox(height: FormStyles.s24),
          Text('Certificados', style: FormStyles.etiqueta()),
          const SizedBox(height: FormStyles.s8),
          _buildCertificados(perfil),
        ],
        const SizedBox(height: FormStyles.s24),
        _buildPublicaciones(),
      ],
    );
  }

  Widget _buildPublicaciones() {
    return FutureBuilder<List<Publicacion>>(
      future: _publicaciones,
      builder:
          (BuildContext context, AsyncSnapshot<List<Publicacion>> snapshot) {
            final List<Publicacion>? publicaciones = snapshot.data;

            final Widget contenido;
            if (snapshot.connectionState != ConnectionState.done) {
              contenido = const Padding(
                padding: EdgeInsets.symmetric(vertical: FormStyles.s24),
                child: Center(child: CircularProgressIndicator()),
              );
            } else if (snapshot.hasError || publicaciones == null) {
              contenido = Text(
                'No se pudieron cargar las publicaciones.',
                style: FormStyles.ayuda(),
              );
            } else if (publicaciones.isEmpty) {
              contenido = Text(
                'Aún no tiene publicaciones.',
                key: const Key('perfil-sin-publicaciones'),
                style: FormStyles.ayuda(),
              );
            } else {
              contenido = GridView.builder(
                key: const Key('perfil-publicaciones'),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: FormStyles.s8,
                  mainAxisSpacing: FormStyles.s8,
                ),
                itemCount: publicaciones.length,
                itemBuilder: (BuildContext context, int index) =>
                    _MiniaturaPublicacion(
                      publicacion: publicaciones[index],
                      onActualizada: _recargarPublicaciones,
                      onEliminada: _recargarPublicaciones,
                    ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(
                      Icons.grid_on_rounded,
                      size: 18,
                      color: AppTheme.azulPetroleo,
                    ),
                    const SizedBox(width: FormStyles.s8),
                    Text('Publicaciones', style: FormStyles.etiqueta()),
                    if (publicaciones != null &&
                        publicaciones.isNotEmpty) ...<Widget>[
                      const SizedBox(width: FormStyles.s8),
                      Text(
                        '(${publicaciones.length})',
                        style: FormStyles.cuerpo(
                          size: 13,
                          color: AppTheme.textoSuave.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: FormStyles.s12),
                contenido,
              ],
            );
          },
    );
  }

  Widget _buildCertificados(PerfilPublico perfil) {
    final CertificadoGuia? certificado = CertificadoGuia.desdePerfil(
      perfil.datos,
    );

    if (certificado != null) {
      return CertificadoDelGuia(
        certificado: certificado,
        abrirEnlace: widget.abrirEnlace,
      );
    }

    final String mensaje = switch (perfil.estadoCertificados) {
      'en_revision' => 'Los certificados de este guía están en revisión.',
      estadoCertificadosAprobado =>
        'Este guía no tiene un carné de guía disponible para ver.',
      _ => 'Este guía aún no tiene certificados aprobados.',
    };

    return Container(
      key: const Key('perfil-sin-certificado'),
      padding: const EdgeInsets.all(FormStyles.s12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(FormStyles.radio),
        border: Border.all(color: FormStyles.colorBorde),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.hourglass_empty_rounded,
            size: 20,
            color: EstiloEventoGuia.titulo,
          ),
          const SizedBox(width: FormStyles.s8),
          Expanded(child: Text(mensaje, style: FormStyles.ayuda())),
        ],
      ),
    );
  }
}

/// Experiencia, zonas, especialidades, idiomas y biografía del guía.
class _PerfilLaboral extends StatelessWidget {
  const _PerfilLaboral({required this.datos});

  final Map<String, dynamic> datos;

  List<String> _lista(String campo) {
    final dynamic valor = datos[campo];
    return valor is List ? valor.whereType<String>().toList() : <String>[];
  }

  @override
  Widget build(BuildContext context) {
    final dynamic anios = datos['aniosExperiencia'];
    final dynamic biografia = datos['biografia'];
    final List<String> zonas = _lista('zonas');
    final List<String> especialidades = _lista('especialidades');
    final List<String> idiomas = _lista('idiomas');

    if (anios is! int &&
        zonas.isEmpty &&
        especialidades.isEmpty &&
        idiomas.isEmpty &&
        biografia is! String) {
      return Text(
        'Este guía aún no completó su perfil laboral.',
        style: FormStyles.ayuda(),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Perfil del guía', style: FormStyles.etiqueta()),
        const SizedBox(height: FormStyles.s8),
        if (anios is int)
          DatoEvento(
            icono: Icons.workspace_premium_outlined,
            texto: anios == 1
                ? '1 año de experiencia'
                : '$anios años de experiencia',
          ),
        if (zonas.isNotEmpty) ...<Widget>[
          const SizedBox(height: FormStyles.s8),
          DatoEvento(icono: Icons.map_outlined, texto: zonas.join(', ')),
        ],
        if (especialidades.isNotEmpty) ...<Widget>[
          const SizedBox(height: FormStyles.s8),
          DatoEvento(
            icono: Icons.hiking_rounded,
            texto: especialidades.join(', '),
          ),
        ],
        if (idiomas.isNotEmpty) ...<Widget>[
          const SizedBox(height: FormStyles.s8),
          DatoEvento(icono: Icons.translate_rounded, texto: idiomas.join(', ')),
        ],
        if (biografia is String && biografia.trim().isNotEmpty) ...<Widget>[
          const SizedBox(height: FormStyles.s12),
          Text(biografia.trim(), style: FormStyles.subtitulo()),
        ],
      ],
    );
  }
}

/// Foto cuadrada de una publicación; al tocarla abre su detalle.
class _MiniaturaPublicacion extends StatelessWidget {
  const _MiniaturaPublicacion({
    required this.publicacion,
    required this.onActualizada,
    required this.onEliminada,
  });

  final Publicacion publicacion;
  final ValueChanged<Publicacion> onActualizada;
  final ValueChanged<String> onEliminada;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(FormStyles.radio),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push<void>(
            context,
            MaterialPageRoute<void>(
              builder: (_) => PublicacionDetalleScreen(
                publicacion: publicacion,
                onPublicacionActualizada: onActualizada,
                onPublicacionEliminada: onEliminada,
              ),
            ),
          );
        },
        child: Hero(
          tag: 'publicacion-${publicacion.id}',
          child: ImagenRemota(
            url: publicacion.imagenUrl,
            fondo: AppTheme.crema,
          ),
        ),
      ),
    );
  }
}
