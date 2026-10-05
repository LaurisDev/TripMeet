import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'form_styles.dart';
import 'nueva_publicacion_screen.dart';
import 'publicacion_detalle_screen.dart';
import 'publicacion_service.dart';
import 'widgets/aviso_error.dart';
import 'widgets/imagen_remota.dart';

const List<String> _meses = <String>[
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

/// Fecha de una publicación al estilo de una red social: "Hace un momento",
/// "Hace 5 min", "Hace 3 h", "Hace 2 d" o, si pasó más de una semana,
/// "12 oct 2026".
String fechaRelativaPublicacion(DateTime fecha, {required DateTime ahora}) {
  final Duration diferencia = ahora.difference(fecha);
  if (diferencia.inMinutes < 1) return 'Hace un momento';
  if (diferencia.inHours < 1) return 'Hace ${diferencia.inMinutes} min';
  if (diferencia.inDays < 1) return 'Hace ${diferencia.inHours} h';
  if (diferencia.inDays < 7) return 'Hace ${diferencia.inDays} d';
  return '${fecha.day} ${_meses[fecha.month - 1]} ${fecha.year}';
}

/// Sección "Publicaciones": feed con las publicaciones de todos los usuarios
/// (incluidas las propias), una debajo de otra y de la más reciente a la más
/// antigua. Carga más al acercarse al final, permite dar "me gusta" (botón
/// o doble toque en la foto) y abre el detalle existente, donde el autor
/// puede editar o eliminar.
class FeedPublicacionesScreen extends StatefulWidget {
  const FeedPublicacionesScreen({
    this.service,
    this.uidUsuarioActual,
    this.reloj,
    super.key,
  });

  /// Servicio de publicaciones (inyectable en pruebas).
  final PublicacionService? service;

  /// UID de quien ve el feed; se pasa al detalle para decidir si puede
  /// editar o eliminar (por defecto, el usuario autenticado).
  final String? uidUsuarioActual;

  /// Hora actual para las fechas relativas (inyectable en pruebas).
  final DateTime Function()? reloj;

  @override
  State<FeedPublicacionesScreen> createState() =>
      _FeedPublicacionesScreenState();
}

class _FeedPublicacionesScreenState extends State<FeedPublicacionesScreen> {
  late final PublicacionService _service =
      widget.service ?? PublicacionService();
  late final DateTime Function() _reloj = widget.reloj ?? DateTime.now;
  final ScrollController _scroll = ScrollController();

  List<PublicacionEnFeed> _items = <PublicacionEnFeed>[];
  PaginaFeed? _ultimaPagina;
  bool _cargando = true;
  bool _cargandoMas = false;
  String? _error;
  String? _errorMas;

  /// Aumenta con cada recarga: una página pedida antes de recargar llega
  /// con datos y cursor viejos, y se descarta.
  int _generacion = 0;

  /// Publicaciones con un cambio de "me gusta" en curso (evita dobles
  /// toques mientras se guarda).
  final Set<String> _meGustaEnCurso = <String>{};

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_alDesplazar);
    _recargar();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _alDesplazar() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 600) {
      _cargarMas();
    }
  }

  Future<void> _recargar() async {
    final int generacion = ++_generacion;
    setState(() {
      _cargando = true;
      _cargandoMas = false;
      _error = null;
      _errorMas = null;
    });

    try {
      final PaginaFeed pagina = await _service.obtenerFeed();
      if (!mounted || generacion != _generacion) return;
      setState(() {
        _items = pagina.publicaciones;
        _ultimaPagina = pagina;
      });
    } on PublicacionServiceException catch (error) {
      if (mounted && generacion == _generacion) {
        setState(() => _error = error.message);
      }
    } finally {
      if (mounted && generacion == _generacion) {
        setState(() => _cargando = false);
      }
    }
  }

  Future<void> _cargarMas() async {
    final PaginaFeed? anterior = _ultimaPagina;
    if (_cargando || _cargandoMas || anterior == null || !anterior.hayMas) {
      return;
    }

    final int generacion = _generacion;
    setState(() {
      _cargandoMas = true;
      _errorMas = null;
    });
    try {
      final PaginaFeed pagina = await _service.obtenerFeed(
        despuesDe: anterior.cursor,
      );
      if (!mounted || generacion != _generacion) return;
      final Set<String> yaMostradas = <String>{
        for (final PublicacionEnFeed item in _items) item.publicacion.id,
      };
      setState(() {
        _items = <PublicacionEnFeed>[
          ..._items,
          for (final PublicacionEnFeed item in pagina.publicaciones)
            if (!yaMostradas.contains(item.publicacion.id)) item,
        ];
        _ultimaPagina = pagina;
      });
    } on PublicacionServiceException catch (error) {
      if (mounted && generacion == _generacion) {
        setState(() => _errorMas = error.message);
      }
    } finally {
      if (mounted && generacion == _generacion) {
        setState(() => _cargandoMas = false);
      }
    }
  }

  Future<void> _nuevaPublicacion() async {
    final bool? publicada = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const NuevaPublicacionScreen()),
    );
    if (publicada == true && mounted) {
      await _recargar();
    }
  }

  void _reemplazar(String id, PublicacionEnFeed Function(PublicacionEnFeed) f) {
    setState(() {
      _items = <PublicacionEnFeed>[
        for (final PublicacionEnFeed item in _items)
          item.publicacion.id == id ? f(item) : item,
      ];
    });
  }

  /// Cambia el "me gusta" de inmediato en pantalla y lo guarda; si falla,
  /// lo revierte y avisa.
  Future<void> _cambiarMeGusta(PublicacionEnFeed item, bool meGusta) async {
    final String id = item.publicacion.id;
    if (item.meGusta == meGusta || _meGustaEnCurso.contains(id)) return;

    _meGustaEnCurso.add(id);
    _reemplazar(
      id,
      (PublicacionEnFeed actual) => actual.copyWith(
        meGusta: meGusta,
        totalMeGusta: actual.totalMeGusta + (meGusta ? 1 : -1),
      ),
    );

    try {
      final int total = await _service.cambiarMeGusta(
        publicacionId: id,
        meGusta: meGusta,
      );
      if (mounted) {
        _reemplazar(
          id,
          (PublicacionEnFeed actual) => actual.copyWith(totalMeGusta: total),
        );
      }
    } on PublicacionServiceException catch (error) {
      if (!mounted) return;
      _reemplazar(
        id,
        (PublicacionEnFeed actual) => actual.copyWith(
          meGusta: item.meGusta,
          totalMeGusta: item.totalMeGusta,
        ),
      );
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      _meGustaEnCurso.remove(id);
    }
  }

  void _abrirDetalle(PublicacionEnFeed item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PublicacionDetalleScreen(
          publicacion: item.publicacion,
          service: _service,
          uidUsuarioActual: widget.uidUsuarioActual,
          onPublicacionActualizada: (Publicacion actualizada) {
            if (!mounted) return;
            _reemplazar(
              actualizada.id,
              (PublicacionEnFeed actual) =>
                  actual.copyWith(publicacion: actualizada),
            );
          },
          onPublicacionEliminada: (String id) {
            if (!mounted) return;
            setState(() {
              _items = <PublicacionEnFeed>[
                for (final PublicacionEnFeed p in _items)
                  if (p.publicacion.id != id) p,
              ];
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Publicación eliminada correctamente.'),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.crema,
      appBar: AppBar(
        title: const Text('Publicaciones'),
        actions: <Widget>[
          IconButton(
            key: const Key('feed-nueva-publicacion'),
            tooltip: 'Nueva publicación',
            onPressed: _nuevaPublicacion,
            icon: const Icon(Icons.add_box_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(onRefresh: _recargar, child: _buildContenido()),
      ),
    );
  }

  Widget _buildContenido() {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    // Los estados sin lista siguen dentro de un ListView para que "deslizar
    // para actualizar" funcione también en ellos.
    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(FormStyles.s20),
        children: <Widget>[AvisoError(mensaje: _error!)],
      );
    }

    if (_items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(FormStyles.s20),
        children: <Widget>[
          const SizedBox(height: FormStyles.s28),
          Icon(
            Icons.photo_library_outlined,
            size: 48,
            color: AppTheme.textoSuave.withValues(alpha: 0.4),
          ),
          const SizedBox(height: FormStyles.s12),
          Text(
            'Todavía no hay publicaciones. ¡Comparte la primera!',
            textAlign: TextAlign.center,
            style: FormStyles.subtitulo(pequena: true),
          ),
        ],
      );
    }

    final DateTime ahora = _reloj();
    final String? uidActual =
        widget.uidUsuarioActual ?? FirebaseAuth.instance.currentUser?.uid;
    return ListView.builder(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: FormStyles.s16),
      itemCount: _items.length + 1,
      itemBuilder: (BuildContext context, int index) {
        if (index == _items.length) return _buildPie();
        final PublicacionEnFeed item = _items[index];
        return _TarjetaPublicacion(
          key: ValueKey<String>('feed-${item.publicacion.id}'),
          item: item,
          ahora: ahora,
          esPropia: uidActual != null && uidActual == item.publicacion.uid,
          onAbrir: () => _abrirDetalle(item),
          onMeGusta: (bool meGusta) => _cambiarMeGusta(item, meGusta),
        );
      },
    );
  }

  /// Final de la lista: cargando más, error con reintento, botón "Ver más"
  /// o aviso de que no hay más.
  Widget _buildPie() {
    final Widget contenido;
    if (_cargandoMas) {
      contenido = const CircularProgressIndicator();
    } else if (_errorMas != null) {
      contenido = Column(
        children: <Widget>[
          AvisoError(mensaje: _errorMas!),
          TextButton(onPressed: _cargarMas, child: const Text('Reintentar')),
        ],
      );
    } else if (_ultimaPagina?.hayMas ?? false) {
      contenido = TextButton(
        key: const Key('feed-ver-mas'),
        onPressed: _cargarMas,
        child: const Text('Ver más publicaciones'),
      );
    } else {
      contenido = Text(
        'Ya viste todas las publicaciones.',
        style: FormStyles.ayuda(),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(FormStyles.s20),
      child: Center(child: contenido),
    );
  }
}

/// Una publicación del feed como tarjeta independiente, en este orden:
/// autor (avatar, alias, rol, fecha y "Editado"), foto, acciones ("me
/// gusta" y, si es propia, opciones) y descripción.
class _TarjetaPublicacion extends StatefulWidget {
  const _TarjetaPublicacion({
    required this.item,
    required this.ahora,
    required this.esPropia,
    required this.onAbrir,
    required this.onMeGusta,
    super.key,
  });

  final PublicacionEnFeed item;
  final DateTime ahora;

  /// `true` si la publicó el usuario actual.
  final bool esPropia;
  final VoidCallback onAbrir;
  final ValueChanged<bool> onMeGusta;

  @override
  State<_TarjetaPublicacion> createState() => _TarjetaPublicacionState();
}

class _TarjetaPublicacionState extends State<_TarjetaPublicacion> {
  /// Las descripciones largas se muestran recortadas hasta tocar "más".
  bool _descripcionCompleta = false;

  static const int _lineasDescripcion = 3;

  @override
  Widget build(BuildContext context) {
    final PublicacionEnFeed item = widget.item;
    final Publicacion publicacion = item.publicacion;

    return Center(
      child: ConstrainedBox(
        // En tabletas y web la tarjeta no se estira de borde a borde.
        constraints: const BoxConstraints(maxWidth: 560),
        child: Container(
          margin: const EdgeInsets.fromLTRB(
            FormStyles.s12,
            0,
            FormStyles.s12,
            FormStyles.s20,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(FormStyles.radio),
            border: Border.all(color: FormStyles.colorBorde),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _buildEncabezado(),
              _buildFoto(publicacion),
              _buildAcciones(),
              if (publicacion.descripcion != null)
                _buildDescripcion(publicacion.descripcion!),
              const SizedBox(height: FormStyles.s16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEncabezado() {
    final AutorPublicacion autor = widget.item.autor;
    final Publicacion publicacion = widget.item.publicacion;
    final DateTime? fechaEdicion = publicacion.fechaEdicion;

    final Widget editado = Text('Editado', style: FormStyles.cuerpo(size: 12));

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        FormStyles.s12,
        FormStyles.s12,
        FormStyles.s4,
        FormStyles.s12,
      ),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 20,
            backgroundColor: AppTheme.azulPetroleo,
            child: Text(
              autor.alias.characters.first.toUpperCase(),
              style: FormStyles.cuerpo(
                size: 16,
                weight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: FormStyles.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        autor.alias,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: FormStyles.cuerpo(
                          size: 15,
                          weight: FontWeight.w700,
                          color: AppTheme.azulPetroleo,
                        ),
                      ),
                    ),
                    if (widget.esPropia) ...<Widget>[
                      const SizedBox(width: FormStyles.s8),
                      const _EtiquetaTu(),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Wrap(
                  spacing: FormStyles.s4,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    if (autor.rol != null) ...<Widget>[
                      _EtiquetaRol(rol: autor.rol!),
                      const _Separador(),
                    ],
                    Text(
                      fechaRelativaPublicacion(
                        publicacion.fechaCreacion,
                        ahora: widget.ahora,
                      ),
                      style: FormStyles.cuerpo(size: 12),
                    ),
                    if (publicacion.editado) ...<Widget>[
                      const _Separador(),
                      if (fechaEdicion == null)
                        editado
                      else
                        Tooltip(
                          message:
                              'Editado: ${fechaRelativaPublicacion(fechaEdicion, ahora: widget.ahora).toLowerCase()}',
                          child: editado,
                        ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (widget.esPropia)
            IconButton(
              key: Key('feed-opciones-${publicacion.id}'),
              tooltip: 'Opciones de tu publicación',
              onPressed: widget.onAbrir,
              icon: const Icon(
                Icons.more_horiz_rounded,
                color: AppTheme.azulPetroleo,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFoto(Publicacion publicacion) {
    return GestureDetector(
      onTap: widget.onAbrir,
      // Doble toque en la foto: da "me gusta" (no lo quita).
      onDoubleTap: () => widget.onMeGusta(true),
      child: Hero(
        tag: 'publicacion-${publicacion.id}',
        child: AspectRatio(
          aspectRatio: 1,
          child: ImagenRemota(
            url: publicacion.imagenUrl,
            fondo: AppTheme.crema,
          ),
        ),
      ),
    );
  }

  Widget _buildAcciones() {
    final PublicacionEnFeed item = widget.item;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        FormStyles.s4,
        FormStyles.s4,
        FormStyles.s12,
        0,
      ),
      child: Row(
        children: <Widget>[
          IconButton(
            key: Key('feed-me-gusta-${item.publicacion.id}'),
            tooltip: item.meGusta ? 'Quitar me gusta' : 'Me gusta',
            onPressed: () => widget.onMeGusta(!item.meGusta),
            icon: Icon(
              item.meGusta
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: item.meGusta
                  ? FormStyles.colorError
                  : AppTheme.azulPetroleo,
            ),
          ),
          Flexible(
            child: Text(
              item.totalMeGusta == 1
                  ? '1 me gusta'
                  : '${item.totalMeGusta} me gusta',
              style: FormStyles.cuerpo(
                weight: FontWeight.w600,
                color: AppTheme.azulPetroleo,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescripcion(String descripcion) {
    final String alias = widget.item.autor.alias;
    final TextSpan texto = TextSpan(
      children: <InlineSpan>[
        TextSpan(
          text: '$alias ',
          style: FormStyles.cuerpo(
            weight: FontWeight.w700,
            color: AppTheme.azulPetroleo,
          ),
        ),
        TextSpan(text: descripcion, style: FormStyles.cuerpo()),
      ],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        FormStyles.s16,
        FormStyles.s4,
        FormStyles.s16,
        0,
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          // Se mide el texto para ofrecer "más" solo si de verdad no cabe.
          final TextPainter medida = TextPainter(
            text: texto,
            maxLines: _lineasDescripcion,
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout(maxWidth: constraints.maxWidth);
          final bool recortada =
              medida.didExceedMaxLines && !_descripcionCompleta;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text.rich(
                texto,
                maxLines: recortada ? _lineasDescripcion : null,
                overflow: recortada ? TextOverflow.ellipsis : null,
              ),
              if (recortada)
                GestureDetector(
                  onTap: () => setState(() => _descripcionCompleta = true),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('más', style: FormStyles.ayuda()),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Punto medio que separa los datos bajo el nombre del autor.
class _Separador extends StatelessWidget {
  const _Separador();

  @override
  Widget build(BuildContext context) {
    return Text('·', style: FormStyles.cuerpo(size: 12));
  }
}

/// Marca discreta "Tú" junto al nombre en las publicaciones propias.
class _EtiquetaTu extends StatelessWidget {
  const _EtiquetaTu();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: FormStyles.s8,
        vertical: 1,
      ),
      decoration: BoxDecoration(
        color: AppTheme.crema,
        borderRadius: BorderRadius.circular(FormStyles.radioPill),
        border: Border.all(color: FormStyles.colorBorde),
      ),
      child: Text(
        'Tú',
        style: FormStyles.cuerpo(
          size: 11,
          weight: FontWeight.w600,
          color: AppTheme.azulPetroleo,
        ),
      ),
    );
  }
}

/// Rol del autor bajo su nombre: "Turista" o "Guía turístico".
class _EtiquetaRol extends StatelessWidget {
  const _EtiquetaRol({required this.rol});

  final String rol;

  @override
  Widget build(BuildContext context) {
    final bool esGuia = rol == 'Guía turístico';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(
          esGuia ? Icons.workspace_premium_rounded : Icons.luggage_outlined,
          size: 12,
          color: AppTheme.verdeAzulado,
        ),
        const SizedBox(width: 2),
        Text(rol, style: FormStyles.cuerpo(size: 12)),
      ],
    );
  }
}
