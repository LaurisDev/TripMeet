import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'evento_detalle_screen.dart';
import 'evento_service.dart';
import 'filtro_eventos.dart';
import 'form_styles.dart';
import 'nuevo_evento_screen.dart';
import 'widgets/aviso_error.dart';
import 'widgets/evento_guia_estilo.dart';

/// Sección "Eventos" de la navegación inferior: lista los eventos turísticos
/// disponibles (aún no ocurridos), del más próximo al más lejano, con filtros
/// por fecha y lugar arriba. Los turistas y los guías ven abajo el botón
/// flotante "Crear evento".
class EventosScreen extends StatefulWidget {
  const EventosScreen({this.service, this.reloj, super.key});

  /// Servicio de eventos (inyectable en pruebas).
  final EventoService? service;

  /// Hora actual para los filtros de fecha (inyectable en pruebas).
  final DateTime Function()? reloj;

  @override
  State<EventosScreen> createState() => _EventosScreenState();
}

class _EventosScreenState extends State<EventosScreen> {
  late final EventoService _service = widget.service ?? EventoService();
  late final DateTime Function() _reloj = widget.reloj ?? DateTime.now;

  List<Evento> _eventos = <Evento>[];
  bool _cargando = true;
  String? _error;
  bool _puedeCrear = false;
  FiltroEventos _filtro = const FiltroEventos();

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

  Future<void> _elegirFecha() async {
    final RangoFecha? rango = await showModalBottomSheet<RangoFecha>(
      context: context,
      backgroundColor: Colors.white,
      builder: (BuildContext context) => _OpcionesFiltro<RangoFecha>(
        titulo: 'Filtrar por fecha',
        opciones: RangoFecha.values,
        seleccionada: _filtro.rango,
        nombre: (RangoFecha r) => r.nombre,
        icono: (RangoFecha r) => r == RangoFecha.personalizada
            ? Icons.edit_calendar_outlined
            : Icons.calendar_today_rounded,
      ),
    );
    if (rango == null || !mounted) return;

    if (rango != RangoFecha.personalizada) {
      setState(() => _filtro = _filtro.conFecha(rango));
      return;
    }

    final DateTime ahora = _reloj();
    final DateTime hoy = DateTime(ahora.year, ahora.month, ahora.day);
    final DateTime? anterior = _filtro.fechaPersonalizada;
    final DateTime? dia = await showDatePicker(
      context: context,
      initialDate: anterior != null && !anterior.isBefore(hoy) ? anterior : hoy,
      firstDate: hoy,
      lastDate: DateTime(hoy.year + 2, hoy.month, hoy.day),
      helpText: 'Fecha del evento',
      cancelText: 'Cancelar',
      confirmText: 'Aplicar',
    );
    if (dia == null || !mounted) return;
    setState(() {
      _filtro = _filtro.conFecha(RangoFecha.personalizada, dia: dia);
    });
  }

  Future<void> _elegirLugar() async {
    final String? lugar = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      builder: (BuildContext context) => _OpcionesFiltro<String>(
        titulo: 'Filtrar por lugar',
        opciones: lugaresDeEventos(_eventos),
        seleccionada: _filtro.lugar,
        nombre: (String lugar) => lugar,
        icono: (_) => Icons.place_outlined,
      ),
    );
    if (lugar == null || !mounted) return;
    setState(() => _filtro = _filtro.conLugar(lugar));
  }

  /// Quita de la lista un evento que su organizador eliminó desde el
  /// detalle, sin volver a consultar Firestore.
  void _quitarEvento(String id) {
    if (!mounted) return;
    setState(() {
      _eventos = <Evento>[
        for (final Evento evento in _eventos)
          if (evento.id != id) evento,
      ];
    });
  }

  void _limpiarFiltros() {
    setState(() => _filtro = const FiltroEventos());
  }

  @override
  Widget build(BuildContext context) {
    final bool conFiltros =
        !_cargando && _error == null && (_eventos.isNotEmpty || _filtro.activo);

    return Scaffold(
      backgroundColor: AppTheme.crema,
      appBar: AppBar(title: const Text('Eventos')),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _puedeCrear
          ? FloatingActionButton.extended(
              key: const Key('eventos-crear'),
              backgroundColor: AppTheme.azulPetroleo,
              foregroundColor: Colors.white,
              onPressed: _crearEvento,
              icon: const Icon(Icons.add_rounded),
              label: Text(
                'Crear evento',
                style: FormStyles.cuerpo(
                  size: 15,
                  weight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            )
          : null,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            if (conFiltros)
              _BarraFiltros(
                filtro: _filtro,
                onFecha: _elegirFecha,
                onLugar: _elegirLugar,
                onQuitarFecha: () =>
                    setState(() => _filtro = _filtro.sinFecha()),
                onQuitarLugar: () =>
                    setState(() => _filtro = _filtro.sinLugar()),
                onLimpiar: _limpiarFiltros,
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _cargarEventos,
                child: _buildContenido(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Margen de la lista; abajo deja espacio para que el botón flotante no
  /// tape la última tarjeta.
  EdgeInsets get _margenLista => EdgeInsets.fromLTRB(
    FormStyles.s20,
    FormStyles.s20,
    FormStyles.s20,
    _puedeCrear ? 96 : FormStyles.s20,
  );

  Widget _buildContenido() {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    // Los estados sin lista siguen dentro de un ListView para que "deslizar
    // para actualizar" funcione también en ellos.
    if (_error != null) {
      return ListView(
        padding: _margenLista,
        children: <Widget>[AvisoError(mensaje: _error!)],
      );
    }

    if (_eventos.isEmpty && !_filtro.activo) {
      return ListView(
        padding: _margenLista,
        children: <Widget>[
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

    final List<Evento> visibles = _filtro.aplicar(_eventos, _reloj());

    return ListView(
      padding: _margenLista.copyWith(top: FormStyles.s12),
      children: <Widget>[
        Text(
          formatearResultadosEventos(visibles.length),
          key: const Key('eventos-resultados'),
          style: FormStyles.cuerpo(size: 13, weight: FontWeight.w600),
        ),
        const SizedBox(height: FormStyles.s12),
        if (visibles.isEmpty)
          _SinResultados(onLimpiar: _limpiarFiltros)
        else
          for (int i = 0; i < visibles.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: FormStyles.s16),
            _EventoTarjeta(
              evento: visibles[i],
              service: _service,
              onEliminado: _quitarEvento,
            ),
          ],
      ],
    );
  }
}

/// Fila de filtros arriba de la lista: chips de fecha y lugar y, si hay
/// alguno activo, "Limpiar filtros".
class _BarraFiltros extends StatelessWidget {
  const _BarraFiltros({
    required this.filtro,
    required this.onFecha,
    required this.onLugar,
    required this.onQuitarFecha,
    required this.onQuitarLugar,
    required this.onLimpiar,
  });

  final FiltroEventos filtro;
  final VoidCallback onFecha;
  final VoidCallback onLugar;
  final VoidCallback onQuitarFecha;
  final VoidCallback onQuitarLugar;
  final VoidCallback onLimpiar;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('eventos-filtros'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        FormStyles.s20,
        FormStyles.s12,
        FormStyles.s20,
        FormStyles.s8,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: FormStyles.colorBorde)),
      ),
      child: Wrap(
        spacing: FormStyles.s8,
        runSpacing: FormStyles.s8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          _ChipFiltro(
            key: const Key('filtro-fecha'),
            icono: Icons.calendar_today_rounded,
            nombre: 'Fecha',
            valor: filtro.etiquetaFecha,
            onTap: onFecha,
            onQuitar: onQuitarFecha,
          ),
          _ChipFiltro(
            key: const Key('filtro-lugar'),
            icono: Icons.place_outlined,
            nombre: 'Lugar',
            valor: filtro.lugar,
            onTap: onLugar,
            onQuitar: onQuitarLugar,
          ),
          if (filtro.activo)
            TextButton(
              key: const Key('limpiar-filtros'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.naranjaQuemado,
                textStyle: FormStyles.cuerpo(size: 13, weight: FontWeight.w600),
              ),
              onPressed: onLimpiar,
              child: const Text('Limpiar filtros'),
            ),
        ],
      ),
    );
  }
}

/// Chip de un filtro. Inactivo muestra solo el [nombre]; activo se resalta,
/// muestra el [valor] elegido y una "x" para quitarlo.
class _ChipFiltro extends StatelessWidget {
  const _ChipFiltro({
    required this.icono,
    required this.nombre,
    required this.valor,
    required this.onTap,
    required this.onQuitar,
    super.key,
  });

  final IconData icono;
  final String nombre;

  /// Valor elegido; `null` si el filtro no está activo.
  final String? valor;
  final VoidCallback onTap;
  final VoidCallback onQuitar;

  @override
  Widget build(BuildContext context) {
    final String? elegido = valor;
    final bool activo = elegido != null;
    final Color color = activo ? Colors.white : AppTheme.azulPetroleo;

    return Material(
      color: activo ? AppTheme.verdeAzulado : Colors.white,
      shape: StadiumBorder(
        side: BorderSide(
          color: activo ? AppTheme.verdeAzulado : FormStyles.colorBorde,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            FormStyles.s12,
            FormStyles.s8,
            FormStyles.s8,
            FormStyles.s8,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icono, size: 16, color: color),
              const SizedBox(width: FormStyles.s4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Text(
                  elegido ?? nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FormStyles.cuerpo(
                    size: 13,
                    weight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: FormStyles.s4),
              if (activo)
                InkResponse(
                  onTap: onQuitar,
                  radius: 14,
                  child: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: color,
                    semanticLabel: 'Quitar filtro de ${nombre.toLowerCase()}',
                  ),
                )
              else
                Icon(Icons.expand_more_rounded, size: 18, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hoja inferior con las opciones de un filtro; devuelve la elegida.
class _OpcionesFiltro<T> extends StatelessWidget {
  const _OpcionesFiltro({
    required this.titulo,
    required this.opciones,
    required this.seleccionada,
    required this.nombre,
    required this.icono,
  });

  final String titulo;
  final List<T> opciones;
  final T? seleccionada;
  final String Function(T opcion) nombre;
  final IconData Function(T opcion) icono;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: FormStyles.s16),
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                FormStyles.s20,
                0,
                FormStyles.s20,
                FormStyles.s8,
              ),
              child: Text(titulo, style: FormStyles.etiqueta()),
            ),
            for (final T opcion in opciones)
              ListTile(
                leading: Icon(icono(opcion), color: AppTheme.verdeAzulado),
                title: Text(nombre(opcion), style: FormStyles.cuerpo()),
                trailing: opcion == seleccionada
                    ? const Icon(
                        Icons.check_rounded,
                        color: AppTheme.verdeAzulado,
                      )
                    : null,
                onTap: () => Navigator.of(context).pop(opcion),
              ),
          ],
        ),
      ),
    );
  }
}

/// Estado cuando ningún evento cumple los filtros.
class _SinResultados extends StatelessWidget {
  const _SinResultados({required this.onLimpiar});

  final VoidCallback onLimpiar;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('eventos-sin-resultados'),
      children: <Widget>[
        const SizedBox(height: FormStyles.s28),
        Icon(
          Icons.search_off_rounded,
          size: 56,
          color: AppTheme.textoSuave.withValues(alpha: 0.4),
        ),
        const SizedBox(height: FormStyles.s12),
        Text(
          'No hay eventos que coincidan con tu búsqueda',
          textAlign: TextAlign.center,
          style: FormStyles.subtitulo(pequena: true),
        ),
        const SizedBox(height: FormStyles.s16),
        OutlinedButton.icon(
          key: const Key('sin-resultados-limpiar'),
          style: FormStyles.botonSecundario().copyWith(
            minimumSize: const WidgetStatePropertyAll<Size>(Size(0, 44)),
          ),
          onPressed: onLimpiar,
          icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
          label: const Text('Limpiar filtros'),
        ),
      ],
    );
  }
}

/// Tarjeta de un evento en la lista: miniatura a la izquierda y, a la
/// derecha, nombre, descripción, lugar y fecha y hora. Al tocarla abre el
/// detalle. Los eventos creados por guías turísticos llevan la etiqueta
/// "Premium" y el recuadro amarillo "Experiencia premium".
class _EventoTarjeta extends StatelessWidget {
  const _EventoTarjeta({
    required this.evento,
    required this.service,
    required this.onEliminado,
  });

  final Evento evento;

  /// El mismo servicio de la lista, para que el detalle consulte y elimine
  /// con él.
  final EventoService service;

  /// Se llama si el organizador elimina el evento desde el detalle.
  final ValueChanged<String> onEliminado;

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
              builder: (_) => EventoDetalleScreen(
                evento: evento,
                service: service,
                onEventoEliminado: onEliminado,
              ),
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
