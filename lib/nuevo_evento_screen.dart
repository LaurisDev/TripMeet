import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_theme.dart';
import 'evento_detalle_screen.dart';
import 'evento_service.dart';
import 'form_styles.dart';
import 'guia_service.dart' show ArchivoLocal;
import 'publicacion_service.dart'
    show PublicacionService, extensionesImagenPermitidas;
import 'widgets/archivo_picker.dart';
import 'widgets/aviso_error.dart';
import 'widgets/foto_seleccionada.dart';

/// Formulario para que un turista o un guía cree un evento: nombre, lugar, fecha
/// y hora (obligatorios), descripción, imagen, cupo máximo y precio
/// (opcionales). Se abre desde
/// la sección "Eventos" y, al guardar, devuelve el [Evento] creado.
class NuevoEventoScreen extends StatefulWidget {
  const NuevoEventoScreen({this.service, this.reloj, super.key});

  /// Servicio de eventos (inyectable en pruebas).
  final EventoService? service;

  /// Hora actual (inyectable en pruebas).
  final DateTime Function()? reloj;

  @override
  State<NuevoEventoScreen> createState() => _NuevoEventoScreenState();
}

class _NuevoEventoScreenState extends State<NuevoEventoScreen> {
  late final EventoService _service = widget.service ?? EventoService();
  late final DateTime Function() _reloj = widget.reloj ?? DateTime.now;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _lugarController = TextEditingController();
  final TextEditingController _descripcionController = TextEditingController();
  final TextEditingController _cupoController = TextEditingController();
  final TextEditingController _precioController = TextEditingController();

  DateTime? _fechaHora;
  String? _errorFechaHora;
  ArchivoLocal? _imagen;
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _nombreController.dispose();
    _lugarController.dispose();
    _descripcionController.dispose();
    _cupoController.dispose();
    _precioController.dispose();
    super.dispose();
  }

  Future<void> _seleccionarImagen() async {
    setState(() => _error = null);

    try {
      final List<ArchivoLocal> seleccionados = await seleccionarArchivos(
        extensiones: extensionesImagenPermitidas,
      );
      if (seleccionados.isEmpty) return;

      final ArchivoLocal archivo = seleccionados.first;
      final String? errorImagen = PublicacionService.validarImagen(archivo);
      if (errorImagen != null) {
        setState(() => _error = errorImagen);
        return;
      }

      setState(() => _imagen = archivo);
    } on SeleccionArchivoException catch (error) {
      setState(() => _error = error.message);
    }
  }

  Future<void> _seleccionarFechaHora() async {
    final DateTime ahora = _reloj();
    final DateTime inicial = _fechaHora ?? ahora.add(const Duration(days: 1));

    final DateTime? fecha = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: DateTime(ahora.year, ahora.month, ahora.day),
      lastDate: DateTime(ahora.year + 2, ahora.month, ahora.day),
      helpText: 'Fecha del evento',
      cancelText: 'Cancelar',
      confirmText: 'Siguiente',
    );
    if (fecha == null || !mounted) return;

    final TimeOfDay? hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(inicial),
      helpText: 'Hora del evento',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );
    if (hora == null || !mounted) return;

    final DateTime elegida = DateTime(
      fecha.year,
      fecha.month,
      fecha.day,
      hora.hour,
      hora.minute,
    );
    setState(() {
      _fechaHora = elegida;
      _errorFechaHora = EventoService.validarFechaHora(
        elegida,
        ahora: _reloj(),
      );
    });
  }

  Future<void> _crear() async {
    final bool camposValidos = _formKey.currentState!.validate();
    final String? errorFechaHora = EventoService.validarFechaHora(
      _fechaHora,
      ahora: _reloj(),
    );
    setState(() {
      _errorFechaHora = errorFechaHora;
      _error = null;
    });
    if (!camposValidos || errorFechaHora != null) return;

    setState(() => _guardando = true);
    try {
      final Evento evento = await _service.crearEvento(
        nombre: _nombreController.text,
        lugar: _lugarController.text,
        fechaHora: _fechaHora,
        descripcion: _descripcionController.text,
        imagen: _imagen,
        // El formulario ya validó que, si hay texto, sea un entero.
        cupoMaximo: EventoService.leerEnteroOpcional(_cupoController.text),
        precio: EventoService.leerEnteroOpcional(_precioController.text),
      );
      if (!mounted) return;
      Navigator.of(context).pop(evento);
    } on EventoServiceException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final DateTime? fechaHora = _fechaHora;

    return PopScope<Evento>(
      canPop: !_guardando,
      child: Scaffold(
        backgroundColor: AppTheme.crema,
        appBar: AppBar(title: const Text('Nuevo evento')),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(FormStyles.s20),
              children: <Widget>[
                FotoSeleccionada(
                  imagen: _imagen,
                  habilitado: !_guardando,
                  onTap: _seleccionarImagen,
                  aspectRatio: 16 / 9,
                ),
                if (_imagen != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _guardando
                          ? null
                          : () => setState(() => _imagen = null),
                      child: const Text('Quitar foto'),
                    ),
                  )
                else ...<Widget>[
                  const SizedBox(height: FormStyles.s4),
                  Text('Imagen (opcional)', style: FormStyles.ayuda()),
                ],
                const SizedBox(height: FormStyles.s20),
                TextFormField(
                  key: const Key('evento-nombre'),
                  controller: _nombreController,
                  enabled: !_guardando,
                  maxLength: longitudMaximaNombreEvento,
                  textInputAction: TextInputAction.next,
                  decoration: FormStyles.input(
                    label: 'Nombre del evento',
                    icon: Icons.event_rounded,
                  ),
                  validator: EventoService.validarNombre,
                ),
                const SizedBox(height: FormStyles.s12),
                TextFormField(
                  key: const Key('evento-lugar'),
                  controller: _lugarController,
                  enabled: !_guardando,
                  maxLength: longitudMaximaLugarEvento,
                  textInputAction: TextInputAction.next,
                  decoration: FormStyles.input(
                    label: 'Lugar',
                    icon: Icons.place_outlined,
                  ),
                  validator: EventoService.validarLugar,
                ),
                const SizedBox(height: FormStyles.s12),
                InkWell(
                  key: const Key('evento-fecha-hora'),
                  onTap: _guardando ? null : _seleccionarFechaHora,
                  borderRadius: BorderRadius.circular(FormStyles.radio),
                  child: InputDecorator(
                    isEmpty: fechaHora == null,
                    decoration: FormStyles.input(
                      label: 'Fecha y hora',
                      icon: Icons.calendar_today_rounded,
                      errorText: _errorFechaHora,
                    ),
                    child: fechaHora == null
                        ? null
                        : Text(
                            '${formatearFechaEvento(fechaHora)} · '
                            '${formatearHoraEvento(fechaHora)}',
                            style: FormStyles.cuerpo(size: 16),
                          ),
                  ),
                ),
                const SizedBox(height: FormStyles.s20),
                TextFormField(
                  key: const Key('evento-descripcion'),
                  controller: _descripcionController,
                  enabled: !_guardando,
                  maxLines: 4,
                  maxLength: longitudMaximaDescripcionEvento,
                  decoration: FormStyles.input(
                    label: 'Descripción (opcional)',
                    hint: 'Cuéntales a los turistas de qué se trata...',
                  ),
                  validator: EventoService.validarDescripcion,
                ),
                const SizedBox(height: FormStyles.s12),
                Text('Cupo y precio (opcional)', style: FormStyles.etiqueta()),
                const SizedBox(height: FormStyles.s4),
                Text(
                  'Útiles sobre todo si ofreces el evento como guía turístico. '
                  'Déjalos vacíos si no aplican.',
                  style: FormStyles.ayuda(),
                ),
                const SizedBox(height: FormStyles.s12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: TextFormField(
                        key: const Key('evento-cupo'),
                        controller: _cupoController,
                        enabled: !_guardando,
                        keyboardType: TextInputType.number,
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: FormStyles.input(
                          label: 'Cupo máximo',
                          icon: Icons.group_outlined,
                          helperText: 'Personas',
                        ),
                        validator: (String? texto) =>
                            EventoService.validarCampoEntero(
                              texto,
                              EventoService.validarCupoMaximo,
                            ),
                      ),
                    ),
                    const SizedBox(width: FormStyles.s12),
                    Expanded(
                      child: TextFormField(
                        key: const Key('evento-precio'),
                        controller: _precioController,
                        enabled: !_guardando,
                        keyboardType: TextInputType.number,
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: FormStyles.input(
                          label: 'Precio',
                          icon: Icons.payments_outlined,
                          helperText: 'COP por persona · 0 = gratis',
                        ),
                        validator: (String? texto) =>
                            EventoService.validarCampoEntero(
                              texto,
                              EventoService.validarPrecio,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: FormStyles.s20),
                if (_error != null) ...<Widget>[
                  AvisoError(mensaje: _error!),
                  const SizedBox(height: FormStyles.s16),
                ],
                FilledButton(
                  style: FormStyles.botonPrimario(),
                  onPressed: _guardando ? null : _crear,
                  child: _guardando
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Crear evento'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
