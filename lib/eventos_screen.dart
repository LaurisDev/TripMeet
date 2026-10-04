import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'evento_detalle_screen.dart';
import 'evento_service.dart';
import 'form_styles.dart';
import 'nuevo_evento_screen.dart';
import 'widgets/aviso_error.dart';
import 'widgets/evento_guia_estilo.dart';

/// Sección "Eventos" de la navegación inferior: lista los eventos turísticos
/// disponibles (aún no ocurridos), del más próximo al más lejano. Los
/// turistas y los guías ven arriba el botón "Crear evento".
class EventosScreen extends StatefulWidget {
  const EventosScreen({this.service, super.key});

  /// Servicio de eventos (inyectable en pruebas).
  final EventoService? service;

  @override
  State<EventosScreen> createState() => _EventosScreenState();
}

class _EventosScreenState extends State<EventosScreen> {
  late final EventoService _service = widget.service ?? EventoService();

  List<Evento> _eventos = <Evento>[];
  bool _cargando = true;
  String? _error;
  bool _puedeCrear = false;

  @override
  void initState() {
    super.initState();
    _cargarEventos();
    _consultarPermisoDeCreacion();
  }

  Future<void> _cargarEventos() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final List<Evento> eventos = await _service.obtenerEventosDisponibles();
      if (mounted) setState(() => _eventos = eventos);
    } on EventoServiceException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _consultarPermisoDeCreacion() async {
    try {
      final bool puedeCrear = await _service.puedeCrearEventos();
      if (mounted) setState(() => _puedeCrear = puedeCrear);
    } on EventoServiceException {
      // Si no se puede verificar el permiso, simplemente no se ofrece crear.
    }
  }

  Future<void> _crearEvento() async {
    final Evento? creado = await Navigator.of(context).push<Evento>(
      MaterialPageRoute<Evento>(
        builder: (_) => NuevoEventoScreen(service: _service),
      ),
    );
    if (creado == null || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Evento "${creado.nombre}" creado correctamente.'),
      ),
    );
    // Se vuelve a consultar Firestore para mostrar el evento tal como quedó
    // guardado, en su posición por fecha.
    await _cargarEventos();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.crema,
      appBar: AppBar(title: const Text('Eventos')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _cargarEventos,
          child: _buildContenido(),
        ),
      ),
    );
  }

  /// Botón principal para crear un evento, arriba de la lista. Solo aparece
  /// si el usuario tiene un rol que permite crear.
  List<Widget> _botonCrear() => <Widget>[
    if (_puedeCrear) ...<Widget>[
      FilledButton.icon(
        key: const Key('eventos-crear'),
        style: FormStyles.botonPrimario(),
        onPressed: _crearEvento,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Crear evento'),
      ),
      const SizedBox(height: FormStyles.s20),
    ],
  ];

  Widget _buildContenido() {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    // Los estados sin lista siguen dentro de un ListView para que "deslizar
    // para actualizar" funcione también en ellos.
    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(FormStyles.s20),
        children: <Widget>[
          ..._botonCrear(),
          AvisoError(mensaje: _error!),
        ],
      );
    }

    if (_eventos.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(FormStyles.s20),
        children: <Widget>[
          ..._botonCrear(),
          const SizedBox(height: FormStyles.s28),
          Icon(
            Icons.event_busy_rounded,
            size: 48,
            color: AppTheme.textoSuave.withValues(alpha: 0.4),
          ),
          const SizedBox(height: FormStyles.s12),
          Text(
            'No hay eventos disponibles por ahora.',
            textAlign: TextAlign.center,
            style: FormStyles.subtitulo(pequena: true),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(FormStyles.s20),
      children: <Widget>[
        ..._botonCrear(),
        for (int i = 0; i < _eventos.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: FormStyles.s16),
          _EventoTarjeta(evento: _eventos[i]),
        ],
      ],
    );
  }
}

/// Tarjeta de un evento en la lista: miniatura a la izquierda y, a la
/// derecha, nombre, descripción, lugar y fecha y hora. Al tocarla abre el
/// detalle. Los eventos creados por guías turísticos llevan la etiqueta
/// "Premium" y el recuadro amarillo "Experiencia premium".
class _EventoTarjeta extends StatelessWidget {
  const _EventoTarjeta({required this.evento});

  final Evento evento;

  @override
  Widget build(BuildContext context) {
    final String? descripcion = evento.descripcion;

    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FormStyles.radio),
        side: const BorderSide(color: FormStyles.colorBorde),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => EventoDetalleScreen(evento: evento),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(FormStyles.s12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _Miniatura(evento: evento),
              const SizedBox(width: FormStyles.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Wrap(
                      spacing: FormStyles.s8,
                      runSpacing: FormStyles.s4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        Text(
                          evento.nombre,
                          style: FormStyles.cuerpo(
                            size: 16,
                            weight: FontWeight.w700,
                            color: AppTheme.azulPetroleo,
                          ),
                        ),
                        if (evento.creadoPorGuia) const EtiquetaPremium(),
                      ],
                    ),
                    if (descripcion != null) ...<Widget>[
                      const SizedBox(height: FormStyles.s4),
                      Text(
                        descripcion,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: FormStyles.ayuda(),
                      ),
                    ],
                    const SizedBox(height: FormStyles.s8),
                    Text('Lugar: ${evento.lugar}', style: FormStyles.cuerpo()),
                    const SizedBox(height: FormStyles.s4),
                    Text(
                      'Fecha y hora: ${formatearFechaEvento(evento.fechaHora)}'
                      ' · ${formatearHoraEvento(evento.fechaHora)}',
                      style: FormStyles.cuerpo(),
                    ),
                    if (evento.cupoMaximo != null) ...<Widget>[
                      const SizedBox(height: FormStyles.s4),
                      Text(
                        'Cupo: ${formatearCupoEvento(evento.cupoMaximo!)}',
                        style: FormStyles.cuerpo(),
                      ),
                    ],
                    if (evento.precio != null) ...<Widget>[
                      const SizedBox(height: FormStyles.s4),
                      Text(
                        'Precio: ${formatearPrecioEvento(evento.precio!)}',
                        style: FormStyles.cuerpo(),
                      ),
                    ],
                    if (evento.creadoPorGuia) ...<Widget>[
                      const SizedBox(height: FormStyles.s12),
                      RecuadroExperienciaPremium(
                        certificadoAprobado: evento.certificadoGuia != null,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Miniatura vertical del evento; si no tiene foto, un ícono de evento.
class _Miniatura extends StatelessWidget {
  const _Miniatura({required this.evento});

  final Evento evento;

  @override
  Widget build(BuildContext context) {
    final String? imagenUrl = evento.imagenUrl;

    return ClipRRect(
      borderRadius: BorderRadius.circular(FormStyles.radio),
      child: SizedBox(
        width: 96,
        height: 128,
        child: imagenUrl == null
            ? Container(
                color: AppTheme.crema,
                child: Icon(
                  Icons.event_rounded,
                  size: 32,
                  color: AppTheme.azulPetroleo.withValues(alpha: 0.4),
                ),
              )
            : Hero(
                tag: 'evento-${evento.id}',
                child: ImagenEvento(url: imagenUrl),
              ),
      ),
    );
  }
}
