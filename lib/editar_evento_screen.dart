import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_theme.dart';
import 'evento_service.dart';
import 'form_styles.dart';
import 'widgets/aviso_error.dart';

/// Formulario para editar un evento existente.
/// Recibe el evento que se desea modificar y devuelve el evento actualizado.
class EditarEventoScreen extends StatefulWidget {
  const EditarEventoScreen({
    required this.evento,
    this.service,
    this.reloj,
    super.key,
  });

  final Evento evento;
  final EventoService? service;
  final DateTime Function()? reloj;

  @override
  State<EditarEventoScreen> createState() => _EditarEventoScreenState();
}

class _EditarEventoScreenState extends State<EditarEventoScreen> {
  late final EventoService _service = widget.service ?? EventoService();
  late final DateTime Function() _reloj = widget.reloj ?? DateTime.now;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _nombreController;
  late final TextEditingController _lugarController;
  late final TextEditingController _descripcionController;
  late final TextEditingController _cupoController;
  late final TextEditingController _precioController;

  late DateTime? _fechaHora;
  String? _errorFechaHora;
  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();

    _nombreController = TextEditingController(text: widget.evento.nombre);
    _lugarController = TextEditingController(text: widget.evento.lugar);
    _descripcionController =
        TextEditingController(text: widget.evento.descripcion ?? '');
    _cupoController = TextEditingController(
      text: widget.evento.cupoMaximo?.toString() ?? '',
    );
    _precioController = TextEditingController(
      text: widget.evento.precio?.toString() ?? '',
    );
    _fechaHora = widget.evento.fechaHora;
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _lugarController.dispose();
    _descripcionController.dispose();
    _cupoController.dispose();
    _precioController.dispose();
    super.dispose();
  }

  Future<void> _seleccionarFechaHora() async {
    final DateTime ahora = _reloj();
    final DateTime inicial = _fechaHora ?? ahora.add(const Duration(days: 1));

    final DateTime? fecha = await showDatePicker(
      context: context,
      initialDate: inicial.isBefore(ahora) ? ahora : inicial,
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
      _error = null;
    });
  }

  Future<void> _guardar() async {
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
      final Evento eventoActualizado = await _service.editarEvento(
        eventoId: widget.evento.id,
        nombre: _nombreController.text,
        lugar: _lugarController.text,
        fechaHora: _fechaHora,
        descripcion: _descripcionController.text,
        cupoMaximo: EventoService.leerEnteroOpcional(_cupoController.text),
        precio: EventoService.leerEnteroOpcional(_precioController.text),
      );

      if (!mounted) return;
      Navigator.of(context).pop(eventoActualizado);
    } on EventoServiceException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } finally {
      if (mounted) {
        setState(() => _guardando = false);
      }
    }
  }

  String _formatearFecha(DateTime fecha) {
    final String dia = fecha.day.toString().padLeft(2, '0');
    final String mes = fecha.month.toString().padLeft(2, '0');
    return '$dia/$mes/${fecha.year}';
  }

  String _formatearHora(DateTime fecha) {
    final String hora = fecha.hour.toString().padLeft(2, '0');
    final String minuto = fecha.minute.toString().padLeft(2, '0');
    return '$hora:$minuto';
  }

  @override
  Widget build(BuildContext context) {
    final DateTime? fechaHora = _fechaHora;

    return PopScope<Evento>(
      canPop: !_guardando,
      child: Scaffold(
        backgroundColor: AppTheme.crema,
        appBar: AppBar(
          title: const Text('Editar evento'),
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(FormStyles.s20),
              children: <Widget>[
                Text(
                  'Actualiza la información de tu evento',
                  style: FormStyles.etiqueta(),
                ),
                const SizedBox(height: FormStyles.s20),
                TextFormField(
                  key: const Key('editar-evento-nombre'),
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
                  key: const Key('editar-evento-lugar'),
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
                  key: const Key('editar-evento-fecha-hora'),
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
                            '${_formatearFecha(fechaHora)} · '
                            '${_formatearHora(fechaHora)}',
                            style: FormStyles.cuerpo(size: 16),
                          ),
                  ),
                ),
                const SizedBox(height: FormStyles.s20),
                TextFormField(
                  key: const Key('editar-evento-descripcion'),
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
                Text(
                  'Cupo y precio (opcional)',
                  style: FormStyles.etiqueta(),
                ),
                const SizedBox(height: FormStyles.s4),
                Text(
                  'Déjalos vacíos si no aplican.',
                  style: FormStyles.ayuda(),
                ),
                const SizedBox(height: FormStyles.s12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: TextFormField(
                        key: const Key('editar-evento-cupo'),
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
                        key: const Key('editar-evento-precio'),
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
                  onPressed: _guardando ? null : _guardar,
                  child: _guardando
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Guardar cambios'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
