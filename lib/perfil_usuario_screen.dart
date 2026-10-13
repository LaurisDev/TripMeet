import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'calificacion_usuario_service.dart';
import 'evento_detalle_screen.dart';
import 'evento_service.dart';
import 'form_styles.dart';
import 'login_screen.dart';
import 'lugares_service.dart' show Resena;
import 'nueva_publicacion_screen.dart';
import 'preferences_screen.dart';
import 'publicacion_detalle_screen.dart';
import 'publicacion_service.dart';
import 'widgets/calificacion_estrellas.dart';
import 'widgets/evento_guia_estilo.dart';
import 'widgets/imagen_remota.dart';

/// Lee las publicaciones de un usuario, de la más reciente a la más antigua.
typedef CargarPublicaciones = Future<List<Publicacion>> Function(String uid);

// async: si Firebase no está inicializado (pruebas), el error queda en el
// Future y la pantalla muestra el aviso en vez de fallar.
Future<List<Publicacion>> cargarPublicacionesDeFirestore(String uid) async =>
    PublicacionService().obtenerPublicacionesDeUsuario(uid);

/// Lee el promedio y el total de calificaciones de [uid]; `null` si no se
/// pudieron leer.
typedef CargarResumenCalificaciones =
    Future<ResumenCalificaciones?> Function(String uid);

Future<ResumenCalificaciones?> cargarResumenDeFirestore(String uid) async {
  if (uid.isEmpty) return null;
  try {
    return await CalificacionUsuarioService().obtenerResumen(uid);
  } catch (_) {
    // Sin conexión, sin permisos o Firebase sin inicializar (pruebas).
    return null;
  }
}

/// Lee las reseñas recibidas por [uid] (inyectable en pruebas).
typedef CargarResenas = Future<List<ResenaRecibida>> Function(String uid);

Future<List<ResenaRecibida>> cargarResenasDeFirestore(String uid) =>
    CalificacionUsuarioService().obtenerResenas(uid);

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

/// Perfil de un usuario: foto, nombre, rol y sus publicaciones. Si es guía
/// turístico, también su perfil laboral y su carné de guía (solo cuando está
/// aprobado; los antecedentes judiciales y los certificados adicionales no se
/// muestran).
///
/// Es la misma pantalla para el perfil propio (pestaña "Perfil") y el de
/// otras personas. Si es el propio, además permite cerrar sesión, abrir las
/// preferencias de recomendación y crear publicaciones; editar o eliminar
/// una publicación se hace desde su detalle, que solo lo permite al autor.
class PerfilUsuarioScreen extends StatefulWidget {
  const PerfilUsuarioScreen({
    this.uid,
    this.uidUsuarioActual,
    this.cargarPerfil = cargarPerfilDeFirestore,
    this.abrirEnlace = abrirEnlaceExterno,
    this.cargarPublicaciones = cargarPublicacionesDeFirestore,
    this.cargarResumenCalificaciones = cargarResumenDeFirestore,
    this.cargarResenas = cargarResenasDeFirestore,
    super.key,
  });

  /// Usuario cuyo perfil se muestra; `null` para el del usuario autenticado.
  final String? uid;

  /// UID de quien está viendo el perfil. Por defecto, el usuario autenticado
  /// en Firebase; se puede inyectar en pruebas.
  final String? uidUsuarioActual;

  /// Lee el perfil `usuarios/{uid}` (inyectable en pruebas).
  final CargarPerfil cargarPerfil;

  /// Abre el PDF del certificado (inyectable en pruebas).
  final AbrirEnlace abrirEnlace;

  /// Lee las publicaciones del usuario (inyectable en pruebas).
  final CargarPublicaciones cargarPublicaciones;

  /// Lee el promedio de calificaciones del usuario (inyectable en pruebas).
  final CargarResumenCalificaciones cargarResumenCalificaciones;

  /// Lee las reseñas que recibió el usuario (inyectable en pruebas).
  final CargarResenas cargarResenas;

  @override
  State<PerfilUsuarioScreen> createState() => _PerfilUsuarioScreenState();
}

class _PerfilUsuarioScreenState extends State<PerfilUsuarioScreen> {
  late final String? _uidActual;
  late final String _uid;
  late Future<Map<String, dynamic>?> _perfil;
  late Future<List<Publicacion>> _publicaciones;
  late Future<ResumenCalificaciones?> _calificaciones;
  late Future<List<ResenaRecibida>> _resenas;

  /// `true` si el perfil es del usuario autenticado.
  bool get _esPropio => _uidActual != null && _uidActual == _uid;

  @override
  void initState() {
    super.initState();
    _uidActual = widget.uidUsuarioActual ?? _obtenerUidUsuarioActual();
    _uid = widget.uid ?? _uidActual ?? '';
    _cargarPerfil();
    _cargarPublicaciones();
  }

  /// UID del usuario autenticado; `null` si no hay sesión o si Firebase no
  /// está inicializado (pruebas).
  String? _obtenerUidUsuarioActual() {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } on FirebaseException {
      return null;
    }
  }

  void _cargarPerfil() {
    _perfil = widget.cargarPerfil(_uid);
    // El promedio se vuelve a consultar cada vez que se carga el perfil, así
    // refleja las calificaciones recién registradas.
    _calificaciones = widget.cargarResumenCalificaciones(_uid);
    _resenas = Future<List<ResenaRecibida>>.sync(
      () => widget.cargarResenas(_uid),
    );
    // Su FutureBuilder aparece hasta que carga el perfil; así un error que
    // llegue antes no queda como no manejado.
    _resenas.ignore();
  }

  void _cargarPublicaciones() {
    _publicaciones = widget.cargarPublicaciones(_uid);
    // Su FutureBuilder aparece hasta que carga el perfil; así un error que
    // llegue antes no queda como no manejado.
    _publicaciones.ignore();
  }

  /// Si el dueño edita una publicación desde el detalle, se vuelve a
  /// consultar la lista.
  void _recargarPublicaciones([Object? _]) {
    if (!mounted) return;
    setState(_cargarPublicaciones);
  }

  void _publicacionEliminada(String _) {
    _recargarPublicaciones();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Publicación eliminada correctamente.')),
    );
  }

  Future<void> _refrescar() async {
    setState(() {
      _cargarPerfil();
      _cargarPublicaciones();
    });
    try {
      await Future.wait<Object?>(<Future<Object?>>[_perfil, _publicaciones]);
    } catch (_) {
      // El error ya se muestra en su sección.
    }
  }

  Future<void> _abrirNuevaPublicacion() async {
    final bool? publicado = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const NuevaPublicacionScreen()),
    );
    if (publicado == true) {
      _recargarPublicaciones();
    }
  }

  void _abrirPreferencias() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const PreferencesScreen()));
  }

  Future<void> _cerrarSesion() async {
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FormStyles.radio),
          ),
          title: const Text('Cerrar sesión'),
          content: const Text(
            '¿Estás seguro de que deseas cerrar sesión en TripMeet?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Cerrar sesión'),
            ),
          ],
        );
      },
    );

    if (confirmar == true && mounted) {
      final NavigatorState navigator = Navigator.of(context);
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      navigator.pushAndRemoveUntil<void>(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
        (Route<dynamic> route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.crema,
      appBar: AppBar(
        title: const Text('Perfil'),
        actions: <Widget>[
          if (_esPropio)
            IconButton(
              icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
              tooltip: 'Cerrar sesión',
              onPressed: _cerrarSesion,
            ),
        ],
      ),
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
                  return RefreshIndicator(
                    onRefresh: _refrescar,
                    child: ListView(
                      padding: const EdgeInsets.all(FormStyles.s20),
                      children: <Widget>[
                        Text(
                          _uid.isEmpty
                              ? 'Inicia sesión para ver tu perfil.'
                              : 'No se pudo cargar el perfil de este usuario.',
                          textAlign: TextAlign.center,
                          style: FormStyles.ayuda(),
                        ),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: _refrescar,
                  child: _buildPerfil(PerfilPublico(snapshot.data)),
                );
              },
        ),
      ),
    );
  }

  Widget _buildPerfil(PerfilPublico perfil) {
    return ListView(
      padding: const EdgeInsets.all(FormStyles.s20),
      children: <Widget>[
        _EncabezadoPerfil(perfil: perfil),
        const SizedBox(height: FormStyles.s12),
        FutureBuilder<ResumenCalificaciones?>(
          future: _calificaciones,
          builder:
              (
                BuildContext context,
                AsyncSnapshot<ResumenCalificaciones?> snapshot,
              ) {
                final ResumenCalificaciones? resumen = snapshot.data;
                if (resumen == null) return const SizedBox.shrink();
                return _ResumenCalificacionesPerfil(resumen: resumen);
              },
        ),
        if (_esPropio) ...<Widget>[
          const SizedBox(height: FormStyles.s16),
          _BotonPreferencias(onTap: _abrirPreferencias),
        ],
        if (perfil.esGuia) ...<Widget>[
          const SizedBox(height: FormStyles.s16),
          _PerfilLaboral(datos: perfil.perfilLaboral),
          const SizedBox(height: FormStyles.s16),
          _Seccion(
            icono: Icons.verified_outlined,
            titulo: 'Certificados',
            child: _buildCertificados(perfil),
          ),
        ],
        const SizedBox(height: FormStyles.s16),
        _Seccion(
          icono: Icons.rate_review_outlined,
          titulo: 'Reseñas',
          child: _buildResenas(),
        ),
        const SizedBox(height: FormStyles.s24),
        _buildPublicaciones(),
      ],
    );
  }

  /// Reseñas recibidas (HU-28): autor, estrellas, comentario, evento y
  /// fecha, de la más reciente a la más antigua.
  Widget _buildResenas() {
    return FutureBuilder<List<ResenaRecibida>>(
      future: _resenas,
      builder:
          (BuildContext context, AsyncSnapshot<List<ResenaRecibida>> snapshot) {
            final List<ResenaRecibida>? resenas = snapshot.data;
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: FormStyles.s12),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError || resenas == null) {
              return Text(
                'No se pudieron cargar las reseñas.',
                style: FormStyles.ayuda(),
              );
            }
            if (resenas.isEmpty) {
              return Text(
                'Aún no tiene reseñas.',
                key: const Key('perfil-sin-resenas'),
                style: FormStyles.ayuda(),
              );
            }
            return Column(
              key: const Key('perfil-resenas'),
              children: <Widget>[
                for (int i = 0; i < resenas.length; i++) ...<Widget>[
                  if (i > 0)
                    const Divider(height: FormStyles.s24, color: FormStyles.colorBorde),
                  _TarjetaResena(resena: resenas[i]),
                ],
              ],
            );
          },
    );
  }

  Widget _buildPublicaciones() {
    return FutureBuilder<List<Publicacion>>(
      future: _publicaciones,
      builder:
          (BuildContext context, AsyncSnapshot<List<Publicacion>> snapshot) {
            final List<Publicacion>? publicaciones = snapshot.data;
            // En el perfil propio, el primer recuadro es "+" para publicar.
            final int extra = _esPropio ? 1 : 0;

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
            } else if (publicaciones.isEmpty && !_esPropio) {
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
                itemCount: publicaciones.length + extra,
                itemBuilder: (BuildContext context, int index) {
                  if (_esPropio && index == 0) {
                    return _AgregarPublicacionTile(
                      onTap: _abrirNuevaPublicacion,
                    );
                  }
                  return _MiniaturaPublicacion(
                    publicacion: publicaciones[index - extra],
                    onActualizada: _recargarPublicaciones,
                    onEliminada: _publicacionEliminada,
                  );
                },
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
                    Text(
                      _esPropio ? 'Mis publicaciones' : 'Publicaciones',
                      style: FormStyles.etiqueta(),
                    ),
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
        color: EstiloEventoGuia.fondo.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(FormStyles.radio),
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

/// Tarjeta superior: foto, nombre y rol. Los guías llevan un aro dorado y,
/// si sus certificados están aprobados, la marca "Verificado".
/// Promedio de calificaciones del usuario (HU-28): estrellas, "4,5" y
/// cuántas calificaciones tiene, o un aviso si aún no tiene.
class _ResumenCalificacionesPerfil extends StatelessWidget {
  const _ResumenCalificacionesPerfil({required this.resumen});

  final ResumenCalificaciones resumen;

  @override
  Widget build(BuildContext context) {
    final double? promedio = resumen.promedio;

    return Container(
      key: const Key('perfil-calificaciones'),
      padding: const EdgeInsets.symmetric(
        horizontal: FormStyles.s16,
        vertical: FormStyles.s12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(FormStyles.radio),
        border: Border.all(color: FormStyles.colorBorde),
      ),
      child: !resumen.tieneCalificaciones || promedio == null
          ? Text(
              'Aún no tiene calificaciones.',
              textAlign: TextAlign.center,
              style: FormStyles.ayuda(),
            )
          : Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: FormStyles.s8,
              runSpacing: FormStyles.s4,
              children: <Widget>[
                EstrellasPromedio(promedio: promedio, tamano: 22),
                Text(
                  formatearPromedio(promedio),
                  style: FormStyles.cuerpo(
                    size: 16,
                    weight: FontWeight.w700,
                    color: AppTheme.azulPetroleo,
                  ),
                ),
                Text(
                  resumen.total == 1
                      ? '(1 calificación)'
                      : '(${resumen.total} calificaciones)',
                  style: FormStyles.cuerpo(size: 13),
                ),
              ],
            ),
    );
  }
}

/// Una reseña recibida: autor (abre su perfil), estrellas, fecha, evento y
/// comentario.
class _TarjetaResena extends StatelessWidget {
  const _TarjetaResena({required this.resena});

  final ResenaRecibida resena;

  @override
  Widget build(BuildContext context) {
    final Resena datos = resena.resena;
    final String? nombreEvento = resena.nombreEvento;
    final String comentario = datos.comentario.trim();
    final String autor = datos.nombreUsuario.trim().isEmpty
        ? 'Usuario'
        : datos.nombreUsuario.trim();

    return Column(
      key: Key('resena-${datos.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        InkWell(
          onTap: () => abrirPerfilUsuario(context, datos.usuarioId),
          borderRadius: BorderRadius.circular(FormStyles.radio),
          child: Row(
            children: <Widget>[
              CircleAvatar(
                radius: 16,
                backgroundColor: AppTheme.azulPetroleo,
                child: Text(
                  autor.characters.first.toUpperCase(),
                  style: FormStyles.cuerpo(
                    size: 13,
                    weight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: FormStyles.s8),
              Expanded(
                child: Text(
                  autor,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FormStyles.cuerpo(
                    weight: FontWeight.w700,
                    color: AppTheme.azulPetroleo,
                  ),
                ),
              ),
              Text(
                formatearFechaEvento(datos.fecha),
                style: FormStyles.cuerpo(size: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: FormStyles.s8),
        EstrellasPromedio(promedio: datos.calificacion, tamano: 16),
        if (nombreEvento != null) ...<Widget>[
          const SizedBox(height: FormStyles.s4),
          Row(
            children: <Widget>[
              const Icon(
                Icons.event_rounded,
                size: 14,
                color: AppTheme.verdeAzulado,
              ),
              const SizedBox(width: FormStyles.s4),
              Expanded(
                child: Text(
                  nombreEvento,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FormStyles.cuerpo(size: 12),
                ),
              ),
            ],
          ),
        ],
        if (comentario.isNotEmpty) ...<Widget>[
          const SizedBox(height: FormStyles.s8),
          Text(comentario, style: FormStyles.cuerpo()),
        ],
      ],
    );
  }
}

class _EncabezadoPerfil extends StatelessWidget {
  const _EncabezadoPerfil({required this.perfil});

  final PerfilPublico perfil;

  @override
  Widget build(BuildContext context) {
    final String? rol = perfil.rol;
    final bool esGuia = perfil.esGuia;
    final bool verificado = EventoService.esGuiaAprobado(perfil.datos);

    return Container(
      key: const Key('perfil-encabezado'),
      padding: const EdgeInsets.symmetric(
        horizontal: FormStyles.s20,
        vertical: FormStyles.s24,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(FormStyles.radioTarjeta),
        border: Border.all(color: FormStyles.colorBorde),
      ),
      child: Column(
        children: <Widget>[
          Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: esGuia
                        ? EstiloEventoGuia.borde
                        : AppTheme.verdeAzulado.withValues(alpha: 0.4),
                    width: 2.5,
                  ),
                ),
                child: AvatarUsuario(perfil: perfil, radio: 44),
              ),
              if (verificado)
                Positioned(
                  right: 0,
                  bottom: 2,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.verified_rounded,
                      size: 24,
                      color: EstiloEventoGuia.titulo,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: FormStyles.s12),
          Text(
            perfil.nombre,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: FormStyles.titulo(pequena: true),
          ),
          if (rol != null) ...<Widget>[
            const SizedBox(height: FormStyles.s8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: FormStyles.s8,
              runSpacing: FormStyles.s4,
              children: <Widget>[
                _Pastilla(
                  icono: esGuia ? Icons.hiking_rounded : Icons.luggage_outlined,
                  texto: rol,
                  fondo: esGuia
                      ? EstiloEventoGuia.fondoEtiqueta
                      : AppTheme.verdeAzulado.withValues(alpha: 0.12),
                  color: esGuia
                      ? EstiloEventoGuia.textoEtiqueta
                      : AppTheme.azulPetroleo,
                ),
                if (verificado)
                  const _Pastilla(
                    icono: Icons.verified_outlined,
                    texto: 'Verificado',
                    fondo: EstiloEventoGuia.fondo,
                    color: EstiloEventoGuia.texto,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Experiencia, zonas, especialidades, idiomas y biografía del guía,
/// organizados en una fila de datos clave y secciones con chips.
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
    final dynamic bio = datos['biografia'];
    final String? biografia = bio is String && bio.trim().isNotEmpty
        ? bio.trim()
        : null;
    final List<String> zonas = _lista('zonas');
    final List<String> especialidades = _lista('especialidades');
    final List<String> idiomas = _lista('idiomas');

    if (anios is! int &&
        zonas.isEmpty &&
        especialidades.isEmpty &&
        idiomas.isEmpty &&
        biografia == null) {
      return _Seccion(
        icono: Icons.badge_outlined,
        titulo: 'Perfil del guía',
        child: Text(
          'Este guía aún no completó su perfil laboral.',
          style: FormStyles.ayuda(),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            if (anios is int)
              _DatoClave(
                valor: '$anios',
                etiqueta: anios == 1
                    ? 'año de experiencia'
                    : 'años de experiencia',
              ),
            if (idiomas.isNotEmpty) ...<Widget>[
              if (anios is int) const SizedBox(width: FormStyles.s8),
              _DatoClave(
                valor: '${idiomas.length}',
                etiqueta: idiomas.length == 1 ? 'idioma' : 'idiomas',
              ),
            ],
            if (zonas.isNotEmpty) ...<Widget>[
              if (anios is int || idiomas.isNotEmpty)
                const SizedBox(width: FormStyles.s8),
              _DatoClave(
                valor: '${zonas.length}',
                etiqueta: zonas.length == 1 ? 'zona' : 'zonas',
              ),
            ],
          ],
        ),
        if (biografia != null) ...<Widget>[
          const SizedBox(height: FormStyles.s16),
          _Seccion(
            icono: Icons.format_quote_rounded,
            titulo: 'Sobre mí',
            child: Text(biografia, style: FormStyles.subtitulo()),
          ),
        ],
        if (especialidades.isNotEmpty ||
            zonas.isNotEmpty ||
            idiomas.isNotEmpty) ...<Widget>[
          const SizedBox(height: FormStyles.s16),
          _Seccion(
            icono: Icons.badge_outlined,
            titulo: 'Perfil del guía',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (especialidades.isNotEmpty)
                  _GrupoChips(
                    icono: Icons.hiking_rounded,
                    titulo: 'Especialidades',
                    valores: especialidades,
                  ),
                if (zonas.isNotEmpty)
                  _GrupoChips(
                    icono: Icons.map_outlined,
                    titulo: 'Zonas donde guía',
                    valores: zonas,
                  ),
                if (idiomas.isNotEmpty)
                  _GrupoChips(
                    icono: Icons.translate_rounded,
                    titulo: 'Idiomas',
                    valores: idiomas,
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Recuadro blanco con un título e ícono.
class _Seccion extends StatelessWidget {
  const _Seccion({
    required this.icono,
    required this.titulo,
    required this.child,
  });

  final IconData icono;
  final String titulo;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(FormStyles.s16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(FormStyles.radio),
        border: Border.all(color: FormStyles.colorBorde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icono, size: 18, color: AppTheme.verdeAzulado),
              const SizedBox(width: FormStyles.s8),
              Text(titulo, style: FormStyles.etiqueta()),
            ],
          ),
          const SizedBox(height: FormStyles.s12),
          child,
        ],
      ),
    );
  }
}

/// Número destacado con su descripción (por ejemplo, "5 · años de
/// experiencia").
class _DatoClave extends StatelessWidget {
  const _DatoClave({required this.valor, required this.etiqueta});

  final String valor;
  final String etiqueta;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: FormStyles.s8,
          vertical: FormStyles.s12,
        ),
        decoration: BoxDecoration(
          color: AppTheme.verdeAzulado.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(FormStyles.radio),
        ),
        child: Column(
          children: <Widget>[
            Text(
              valor,
              style: FormStyles.cuerpo(
                size: 22,
                weight: FontWeight.w700,
                color: AppTheme.azulPetroleo,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              etiqueta,
              textAlign: TextAlign.center,
              style: FormStyles.cuerpo(size: 12, color: AppTheme.textoSuave),
            ),
          ],
        ),
      ),
    );
  }
}

/// Subtítulo pequeño con los valores como chips.
class _GrupoChips extends StatelessWidget {
  const _GrupoChips({
    required this.icono,
    required this.titulo,
    required this.valores,
  });

  final IconData icono;
  final String titulo;
  final List<String> valores;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: FormStyles.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icono, size: 14, color: AppTheme.textoSuave),
              const SizedBox(width: FormStyles.s4),
              Text(
                titulo,
                style: FormStyles.cuerpo(
                  size: 13,
                  weight: FontWeight.w600,
                  color: AppTheme.textoSuave,
                ),
              ),
            ],
          ),
          const SizedBox(height: FormStyles.s8),
          Wrap(
            spacing: FormStyles.s8,
            runSpacing: FormStyles.s8,
            children: <Widget>[
              for (final String valor in valores)
                _Pastilla(
                  texto: valor,
                  fondo: AppTheme.crema,
                  color: AppTheme.azulPetroleo,
                  borde: FormStyles.colorBorde,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Etiqueta redondeada con ícono opcional.
class _Pastilla extends StatelessWidget {
  const _Pastilla({
    required this.texto,
    required this.fondo,
    required this.color,
    this.icono,
    this.borde,
  });

  final String texto;
  final Color fondo;
  final Color color;
  final IconData? icono;
  final Color? borde;

  @override
  Widget build(BuildContext context) {
    final IconData? icono = this.icono;
    final Color? borde = this.borde;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: FormStyles.s12,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(FormStyles.radioPill),
        border: borde == null ? null : Border.all(color: borde),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icono != null) ...<Widget>[
            Icon(icono, size: 14, color: color),
            const SizedBox(width: FormStyles.s4),
          ],
          Flexible(
            child: Text(
              texto,
              overflow: TextOverflow.ellipsis,
              style: FormStyles.cuerpo(
                size: 13,
                weight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
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

/// Recuadro con un "+" para crear una nueva publicación, al inicio de la
/// grilla del perfil propio.
class _AgregarPublicacionTile extends StatelessWidget {
  const _AgregarPublicacionTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.crema,
      borderRadius: BorderRadius.circular(FormStyles.radio),
      child: InkWell(
        key: const Key('perfil-agregar-publicacion'),
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

/// Acceso a Preferencias de recomendación, solo en el perfil propio.
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
