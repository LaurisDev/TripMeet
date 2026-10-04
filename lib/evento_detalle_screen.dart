import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_theme.dart';
import 'editar_evento_screen.dart';
import 'evento_service.dart';
import 'form_styles.dart';
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

Future<bool> _abrirEnlaceExterno(Uri enlace) =>
    launchUrl(enlace, mode: LaunchMode.externalApplication);

/// Detalle de un evento.
class EventoDetalleScreen extends StatefulWidget {
  const EventoDetalleScreen({
    required this.evento,
    this.abrirEnlace = _abrirEnlaceExterno,
    super.key,
  });

  final Evento evento;

  /// Abre el PDF del certificado (inyectable en pruebas).
  final AbrirEnlace abrirEnlace;

  @override
  State<EventoDetalleScreen> createState() => _EventoDetalleScreenState();
}

class _EventoDetalleScreenState extends State<EventoDetalleScreen> {
  late Evento _evento;

  @override
  void initState() {
    super.initState();
    _evento = widget.evento;
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
      });
    }
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
      appBar: AppBar(
        title: const Text('Evento'),
        actions: <Widget>[
          if (usuarioActualUid == evento.creadorUid)
            IconButton(
              key: const Key('editar-evento'),
              tooltip: 'Editar evento',
              icon: const Icon(Icons.edit_outlined),
              onPressed: _editarEvento,
            ),
        ],
      ),
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
                      Text(
                        evento.nombre,
                        style: FormStyles.titulo(),
                      ),
                      if (evento.creadoPorGuia)
                        const EtiquetaPremium(),
                    ],
                  ),
                  const SizedBox(height: FormStyles.s16),
                  DatoEvento(
                    icono: Icons.place_outlined,
                    texto: evento.lugar,
                  ),
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
                      texto:
                          'Precio: ${formatearPrecioEvento(evento.precio!)}',
                    ),
                  ],
                  if (evento.creadoPorGuia) ...<Widget>[
                    const SizedBox(height: FormStyles.s20),
                    RecuadroExperienciaPremium(
                      certificadoAprobado: certificado != null,
                      child: certificado == null
                          ? null
                          : _CertificadoDelGuia(
                              certificado: certificado,
                              abrirEnlace: widget.abrirEnlace,
                            ),
                    ),
                  ],
                  const SizedBox(height: FormStyles.s20),
                  Text(
                    'Descripción',
                    style: FormStyles.etiqueta(),
                  ),
                  const SizedBox(height: FormStyles.s8),
                  Text(
                    evento.descripcion ?? 'Sin descripción.',
                    style: evento.descripcion == null
                        ? FormStyles.ayuda()
                        : FormStyles.subtitulo(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Carné aprobado del guía dentro del recuadro premium.
class _CertificadoDelGuia extends StatelessWidget {
  const _CertificadoDelGuia({
    required this.certificado,
    required this.abrirEnlace,
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
            icon: const Icon(
              Icons.picture_as_pdf_outlined,
              size: 18,
            ),
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
        Icon(
          icono,
          size: 16,
          color: color,
        ),
        const SizedBox(width: FormStyles.s8),
        Expanded(
          child: Text(
            texto,
            style: FormStyles.cuerpo(
              weight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

/// Foto de un evento desde Cloudinary.
class ImagenEvento extends StatelessWidget {
  const ImagenEvento({
    required this.url,
    super.key,
  });

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