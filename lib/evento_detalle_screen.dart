import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_theme.dart';
import 'editar_evento_screen.dart';
import 'evento_service.dart';
import 'form_styles.dart';
import 'perfil_usuario_screen.dart';
import 'widgets/evento_guia_estilo.dart';

const List<String> _meses = <String>[
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

/// "12 de octubre de 2026".
String formatearFechaEvento(DateTime fecha) =>
    '${fecha.day} de ${_meses[fecha.month - 1]} de ${fecha.year}';

/// "09:30" (24 horas).
String formatearHoraEvento(DateTime fecha) =>
    '${fecha.hour.toString().padLeft(2, '0')}:'
    '${fecha.minute.toString().padLeft(2, '0')}';

/// "1 persona" / "25 personas".
String formatearCupoEvento(int cupo) =>
    cupo == 1 ? '1 persona' : '$cupo personas';

/// "\$50.000 COP" con puntos de miles; "Gratis" si es 0.
String formatearPrecioEvento(int precio) {
  if (precio == 0) return 'Gratis';

  final String digitos = precio.toString();
  final StringBuffer conPuntos = StringBuffer();

  for (int i = 0; i < digitos.length; i++) {
    if (i > 0 && (digitos.length - i) % 3 == 0) {
      conPuntos.write('.');
    }
    conPuntos.write(digitos[i]);
  }

  return '\$$conPuntos COP';
}

/// Abre [enlace] fuera de la app.
typedef AbrirEnlace = Future<bool> Function(Uri enlace);

Future<bool> abrirEnlaceExterno(Uri enlace) =>
    launchUrl(enlace, mode: LaunchMode.externalApplication);

/// Lee el perfil `usuarios/{uid}`; `null` si no existe o no se pudo leer.
typedef CargarPerfil = Future<Map<String, dynamic>?> Function(String uid);

Future<Map<String, dynamic>?> cargarPerfilDeFirestore(String uid) async {
  if (uid.isEmpty) return null;
  try {
    return (await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(uid)
            .get())
        .data();
  } catch (_) {
    // Sin conexión, sin permisos o Firebase sin inicializar (pruebas).
    return null;
  }
}

/// Detalle de un evento.
class EventoDetalleScreen extends StatefulWidget {
  const EventoDetalleScreen({
    required this.evento,
    this.abrirEnlace = abrirEnlaceExterno,
    this.cargarPerfil = cargarPerfilDeFirestore,
    super.key,
  });

  final Evento evento;

  /// Abre el PDF del certificado (inyectable en pruebas).
  final AbrirEnlace abrirEnlace;

  /// Lee el perfil del organizador (inyectable en pruebas).
  final CargarPerfil cargarPerfil;

  @override
  State<EventoDetalleScreen> createState() => _EventoDetalleScreenState();
}

class _EventoDetalleScreenState extends State<EventoDetalleScreen> {
  late Evento _evento;
  late Future<Map<String, dynamic>?> _perfilOrganizador;
  late Future<List<Map<String, dynamic>?>> _perfilesParticipantes;

  @override
  void initState() {
    super.initState();
    _evento = widget.evento;
    _perfilOrganizador = widget.cargarPerfil(_evento.creadorUid).then((
      Map<String, dynamic>? perfil,
    ) {
      // Con el perfil recién leído se asegura que el recuadro premium y el
      // carné del guía estén al día antes de que el turista decida unirse.
      if (perfil != null && mounted) {
        setState(() {
          _evento = _evento.conPerfilDelCreador(perfil);
        });
      }
      return perfil;
    });
    _cargarParticipantes();
  }

  /// Lee el perfil de cada inscrito, en el mismo orden de `inscritos`.
  void _cargarParticipantes() {
    _perfilesParticipantes = Future.wait(
      _evento.inscritos.map(widget.cargarPerfil),
    );
  }

  Future<void> _editarEvento() async {
    final Evento? eventoActualizado = await Navigator.push<Evento>(
      context,
      MaterialPageRoute<Evento>(
        builder: (_) => EditarEventoScreen(evento: _evento),
      ),
    );

    if (eventoActualizado != null && mounted) {
      setState(() {
        _evento = eventoActualizado;
        _cargarParticipantes();
      });
    }
  }

  Future<void> _eliminarEvento() async {
    // TODO: pedir confirmación, eliminar el evento y volver al listado.
  }

  Future<void> _unirseEvento() async {
    // TODO: agregar el UID del usuario actual a `inscritos` del evento.
  }

  Future<void> _salirEvento() async {
    // TODO: quitar el UID del usuario actual de `inscritos` del evento.
  }

  void _abrirPerfil(String uid) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => PerfilUsuarioScreen(
          uid: uid,
          cargarPerfil: widget.cargarPerfil,
          abrirEnlace: widget.abrirEnlace,
        ),
      ),
    );
  }

  /// Botones según quién mira el evento y su estado.
  Widget _buildAcciones(Evento evento, String? usuarioActualUid) {
    final bool esCreador =
        usuarioActualUid != null && usuarioActualUid == evento.creadorUid;
    final bool estaInscrito =
        usuarioActualUid != null && evento.inscritos.contains(usuarioActualUid);
    final bool finalizado = evento.fechaHora.isBefore(DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (finalizado) ...<Widget>[
          const Center(child: _EtiquetaFinalizado()),
          const SizedBox(height: FormStyles.s16),
        ],
        if (esCreador)
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('detalle-editar-evento'),
                  style: FormStyles.botonSecundario(),
                  onPressed: _editarEvento,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Editar'),
                ),
              ),
              const SizedBox(width: FormStyles.s12),
              Expanded(
                child: FilledButton.icon(
                  key: const Key('detalle-eliminar-evento'),
                  style: FormStyles.botonPrimario(color: FormStyles.colorError)
                      .copyWith(
                        minimumSize: const WidgetStatePropertyAll<Size>(
                          Size.fromHeight(48),
                        ),
                      ),
                  onPressed: _eliminarEvento,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Eliminar'),
                ),
              ),
            ],
          )
        else if (!finalizado && estaInscrito)
          OutlinedButton.icon(
            key: const Key('salir-evento'),
            style: FormStyles.botonSecundario(),
            onPressed: _salirEvento,
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Salir'),
          )
        else if (!finalizado)
          FilledButton(
            key: const Key('unirse-evento'),
            style: FormStyles.botonPrimario(),
            onPressed: evento.estaLleno ? null : _unirseEvento,
            child: Text(evento.estaLleno ? 'Evento lleno' : 'Unirse'),
          ),
      ],
    );
  }

  /// Obtiene el UID del usuario autenticado.
  ///
  /// En la aplicación normal consulta Firebase Authentication.
  /// En los tests, si Firebase todavía no fue inicializado, devuelve null
  /// para evitar que la pantalla falle.
  String? _obtenerUidUsuarioActual() {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } on FirebaseException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Evento evento = _evento;
    final String? imagenUrl = evento.imagenUrl;
    final CertificadoGuia? certificado = evento.certificadoGuia;
    final String? usuarioActualUid = _obtenerUidUsuarioActual();

    return Scaffold(
      backgroundColor: AppTheme.crema,
      appBar: AppBar(title: const Text('Evento')),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            if (imagenUrl != null)
              Hero(
                tag: 'evento-${evento.id}',
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ImagenEvento(url: imagenUrl),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(FormStyles.s20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Wrap(
                    spacing: FormStyles.s8,
                    runSpacing: FormStyles.s8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      Text(evento.nombre, style: FormStyles.titulo()),
                      if (evento.creadoPorGuia) const EtiquetaPremium(),
                    ],
                  ),
                  const SizedBox(height: FormStyles.s16),
                  DatoEvento(icono: Icons.place_outlined, texto: evento.lugar),
                  const SizedBox(height: FormStyles.s8),
                  DatoEvento(
                    icono: Icons.calendar_today_rounded,
                    texto: formatearFechaEvento(evento.fechaHora),
                  ),
                  const SizedBox(height: FormStyles.s8),
                  DatoEvento(
                    icono: Icons.schedule_rounded,
                    texto: formatearHoraEvento(evento.fechaHora),
                  ),
                  if (evento.cupoMaximo != null) ...<Widget>[
                    const SizedBox(height: FormStyles.s8),
                    DatoEvento(
                      icono: Icons.group_outlined,
                      texto:
                          'Cupo máximo: ${formatearCupoEvento(evento.cupoMaximo!)}',
                    ),
                  ],
                  if (evento.precio != null) ...<Widget>[
                    const SizedBox(height: FormStyles.s8),
                    DatoEvento(
                      icono: Icons.payments_outlined,
                      texto: 'Precio: ${formatearPrecioEvento(evento.precio!)}',
                    ),
                  ],
                  if (evento.creadoPorGuia) ...<Widget>[
                    const SizedBox(height: FormStyles.s20),
                    RecuadroExperienciaPremium(
                      certificadoAprobado: certificado != null,
                      child: certificado == null
                          ? null
                          : CertificadoDelGuia(
                              certificado: certificado,
                              abrirEnlace: widget.abrirEnlace,
                            ),
                    ),
                  ],
                  const SizedBox(height: FormStyles.s20),
                  Text('Descripción', style: FormStyles.etiqueta()),
                  const SizedBox(height: FormStyles.s8),
                  Text(
                    evento.descripcion ?? 'Sin descripción.',
                    style: evento.descripcion == null
                        ? FormStyles.ayuda()
                        : FormStyles.subtitulo(),
                  ),
                  const SizedBox(height: FormStyles.s20),
                  Text('Organizador', style: FormStyles.etiqueta()),
                  const SizedBox(height: FormStyles.s8),
                  FutureBuilder<Map<String, dynamic>?>(
                    future: _perfilOrganizador,
                    builder:
                        (
                          BuildContext context,
                          AsyncSnapshot<Map<String, dynamic>?> snapshot,
                        ) => _TarjetaOrganizador(
                          perfil: snapshot.data,
                          cargando:
                              snapshot.connectionState != ConnectionState.done,
                          onTap: () => _abrirPerfil(evento.creadorUid),
                        ),
                  ),
                  const SizedBox(height: FormStyles.s20),
                  Text(
                    evento.cupoMaximo == null
                        ? 'Participantes (${evento.inscritos.length})'
                        : 'Participantes '
                              '(${evento.inscritos.length}/${evento.cupoMaximo})',
                    style: FormStyles.etiqueta(),
                  ),
                  const SizedBox(height: FormStyles.s8),
                  if (evento.inscritos.isEmpty)
                    Text(
                      'Aún no hay personas unidas a este evento.',
                      key: const Key('evento-sin-participantes'),
                      style: FormStyles.ayuda(),
                    )
                  else
                    FutureBuilder<List<Map<String, dynamic>?>>(
                      future: _perfilesParticipantes,
                      builder:
                          (
                            BuildContext context,
                            AsyncSnapshot<List<Map<String, dynamic>?>> snapshot,
                          ) => _ListaParticipantes(
                            uids: evento.inscritos,
                            perfiles: snapshot.data,
                            onTap: _abrirPerfil,
                          ),
                    ),
                  const SizedBox(height: FormStyles.s24),
                  _buildAcciones(evento, usuarioActualUid),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Etiqueta "Evento finalizado" para eventos cuya fecha ya pasó.
class _EtiquetaFinalizado extends StatelessWidget {
  const _EtiquetaFinalizado();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('evento-finalizado'),
      padding: const EdgeInsets.symmetric(
        horizontal: FormStyles.s12,
        vertical: FormStyles.s4,
      ),
      decoration: BoxDecoration(
        color: AppTheme.textoSuave.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(FormStyles.radioPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Icons.event_busy_outlined,
            size: 16,
            color: AppTheme.textoSuave,
          ),
          const SizedBox(width: FormStyles.s4),
          Text(
            'Evento finalizado',
            style: FormStyles.cuerpo(
              size: 13,
              weight: FontWeight.w600,
              color: AppTheme.textoSuave,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta con la foto, el nombre y el rol de quien creó el evento.
class _TarjetaOrganizador extends StatelessWidget {
  const _TarjetaOrganizador({
    required this.perfil,
    required this.cargando,
    required this.onTap,
  });

  /// Perfil `usuarios/{creadorUid}`; `null` si no existe o no se pudo leer.
  final Map<String, dynamic>? perfil;
  final bool cargando;

  /// Abre el perfil del organizador.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _TarjetaUsuarios(
      key: const Key('evento-organizador'),
      children: <Widget>[
        if (cargando)
          const SizedBox(
            height: 48,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else
          _FilaUsuario(perfil: perfil, onTap: onTap),
      ],
    );
  }
}

/// Personas inscritas en el evento, una por fila.
class _ListaParticipantes extends StatelessWidget {
  const _ListaParticipantes({
    required this.uids,
    required this.perfiles,
    required this.onTap,
  });

  /// UIDs de los inscritos, en el mismo orden que [perfiles].
  final List<String> uids;

  /// Abre el perfil del inscrito con el UID dado.
  final ValueChanged<String> onTap;

  /// Perfil de cada inscrito; `null` mientras se cargan.
  final List<Map<String, dynamic>?>? perfiles;

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>?>? cargados = perfiles;

    return _TarjetaUsuarios(
      key: const Key('evento-participantes'),
      children: <Widget>[
        if (cargados == null)
          const SizedBox(
            height: 48,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else
          for (int i = 0; i < cargados.length; i++) ...<Widget>[
            if (i > 0)
              const Divider(
                height: FormStyles.s16,
                color: FormStyles.colorBorde,
              ),
            _FilaUsuario(perfil: cargados[i], onTap: () => onTap(uids[i])),
          ],
      ],
    );
  }
}

/// Recuadro blanco con borde donde se listan usuarios.
class _TarjetaUsuarios extends StatelessWidget {
  const _TarjetaUsuarios({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(FormStyles.s12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(FormStyles.radio),
        border: Border.all(color: FormStyles.colorBorde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

/// Foto (o inicial), nombre y rol de un usuario; al tocarla abre su perfil.
class _FilaUsuario extends StatelessWidget {
  const _FilaUsuario({required this.perfil, required this.onTap});

  /// Perfil `usuarios/{uid}`; `null` si no existe o no se pudo leer.
  final Map<String, dynamic>? perfil;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final PerfilPublico datos = PerfilPublico(perfil);
    final String? rol = datos.rol;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(FormStyles.radio),
      child: Row(
        children: <Widget>[
          AvatarUsuario(perfil: datos),
          const SizedBox(width: FormStyles.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  datos.nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FormStyles.cuerpo(
                    size: 15,
                    weight: FontWeight.w700,
                    color: AppTheme.azulPetroleo,
                  ),
                ),
                if (rol != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(rol, style: FormStyles.ayuda()),
                ],
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: AppTheme.textoSuave.withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }
}

/// Carné aprobado del guía dentro del recuadro premium.
class CertificadoDelGuia extends StatelessWidget {
  const CertificadoDelGuia({
    required this.certificado,
    required this.abrirEnlace,
    super.key,
  });

  final CertificadoGuia certificado;
  final AbrirEnlace abrirEnlace;

  Future<void> _abrir(BuildContext context) async {
    final ScaffoldMessengerState mensajes = ScaffoldMessenger.of(context);
    bool abierto;

    try {
      abierto = await abrirEnlace(Uri.parse(certificado.url));
    } catch (_) {
      abierto = false;
    }

    if (!abierto) {
      mensajes.showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir el certificado. Inténtalo de nuevo.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('evento-certificado-guia'),
      padding: const EdgeInsets.all(FormStyles.s12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(FormStyles.radio),
        border: Border.all(color: EstiloEventoGuia.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Icon(
                Icons.verified_rounded,
                size: 22,
                color: EstiloEventoGuia.titulo,
              ),
              const SizedBox(width: FormStyles.s8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Carné de guía turístico',
                      style: FormStyles.cuerpo(
                        weight: FontWeight.w700,
                        color: AppTheme.azulPetroleo,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Certificado aprobado · ${certificado.nombre}',
                      style: FormStyles.ayuda(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: FormStyles.s12),
          OutlinedButton.icon(
            style: FormStyles.botonSecundario(),
            onPressed: () => _abrir(context),
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
            label: const Text('Ver certificado'),
          ),
        ],
      ),
    );
  }
}

/// Fila "ícono + texto" para los datos de un evento.
class DatoEvento extends StatelessWidget {
  const DatoEvento({
    required this.icono,
    required this.texto,
    this.color = AppTheme.verdeAzulado,
    super.key,
  });

  final IconData icono;
  final String texto;

  /// Color del ícono y del texto.
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icono, size: 16, color: color),
        const SizedBox(width: FormStyles.s8),
        Expanded(
          child: Text(
            texto,
            style: FormStyles.cuerpo(weight: FontWeight.w600, color: color),
          ),
        ),
      ],
    );
  }
}

/// Foto de un evento desde Cloudinary.
class ImagenEvento extends StatelessWidget {
  const ImagenEvento({required this.url, super.key});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      loadingBuilder:
          (BuildContext context, Widget child, ImageChunkEvent? progress) {
            if (progress == null) return child;

            return Container(
              color: Colors.white,
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          },
      errorBuilder:
          (BuildContext context, Object error, StackTrace? stackTrace) =>
              Container(
                color: Colors.white,
                child: Icon(
                  Icons.broken_image_outlined,
                  size: 48,
                  color: AppTheme.textoSuave.withValues(alpha: 0.4),
                ),
              ),
    );
  }
}
