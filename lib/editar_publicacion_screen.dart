import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'form_styles.dart';
import 'publicacion_service.dart';
import 'widgets/aviso_error.dart';
import 'widgets/selector_fotos.dart';

/// Pantalla para editar una publicación propia: precarga las fotos, la
/// ubicación y la descripción actuales y permite cambiarlas (agregar,
/// quitar o cambiar la portada del carrusel).
///
/// Al guardar hace `pop` con la [Publicacion] actualizada; al cancelar hace
/// `pop` sin resultado y la publicación conserva su contenido original. Si
/// hay cambios sin guardar, pide confirmación antes de descartarlos (tanto
/// con el botón "Cancelar" como con el botón/gesto de volver).
class EditarPublicacionScreen extends StatefulWidget {
  const EditarPublicacionScreen({
    required this.publicacion,
    this.service,
    super.key,
  });

  final Publicacion publicacion;

  /// Permite inyectar el servicio en pruebas; por defecto usa Firebase y
  /// Cloudinary reales.
  final PublicacionService? service;

  @override
  State<EditarPublicacionScreen> createState() =>
      _EditarPublicacionScreenState();
}

class _EditarPublicacionScreenState extends State<EditarPublicacionScreen> {
  late final PublicacionService _service =
      widget.service ?? PublicacionService();
  late final TextEditingController _descripcionController =
      TextEditingController(text: widget.publicacion.descripcion ?? '');
  late final TextEditingController _ubicacionController = TextEditingController(
    text: widget.publicacion.ubicacion ?? '',
  );

  late final List<FotoEdicion> _fotos = <FotoEdicion>[
    for (final ImagenPublicacion imagen in widget.publicacion.imagenes)
      FotoPublicada(imagen),
  ];
  bool _guardando = false;
  String? _error;

  /// Progreso de la subida de fotos nuevas: (subidas, total).
  (int, int)? _progreso;

  /// `true` si se agregó, quitó o reordenó alguna foto.
  bool get _cambianFotos {
    final List<ImagenPublicacion> originales = widget.publicacion.imagenes;
    if (_fotos.length != originales.length) return true;
    for (int i = 0; i < _fotos.length; i++) {
      final FotoEdicion foto = _fotos[i];
      if (foto is! FotoPublicada || foto.imagen != originales[i]) return true;
    }
    return false;
  }

  /// La descripción y la ubicación se comparan ya normalizadas para que
  /// agregar espacios no cuente como edición.
  bool get _hayCambios =>
      _cambianFotos ||
      PublicacionService.normalizarDescripcion(_descripcionController.text) !=
          widget.publicacion.descripcion ||
      PublicacionService.normalizarUbicacion(_ubicacionController.text) !=
          widget.publicacion.ubicacion;

  @override
  void initState() {
    super.initState();
    _descripcionController.addListener(() => setState(() {}));
    _ubicacionController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _descripcionController.dispose();
    _ubicacionController.dispose();
    super.dispose();
  }

  Future<void> _agregarFotos() async {
    setState(() => _error = null);
    final (List<FotoNueva> nuevas, String? aviso) = await elegirFotosNuevas(
      disponibles: maximoFotosPublicacion - _fotos.length,
    );
    if (!mounted) return;
    setState(() {
      _fotos.addAll(nuevas);
      _error = aviso;
    });
  }

  Future<void> _guardar() async {
    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      final Publicacion actualizada = await _service.editarPublicacion(
        publicacionId: widget.publicacion.id,
        descripcion: _descripcionController.text,
        ubicacion: _ubicacionController.text,
        imagenes: _cambianFotos ? List<FotoEdicion>.of(_fotos) : null,
        onProgreso: (int subidas, int total) {
          if (mounted) setState(() => _progreso = (subidas, total));
        },
      );
      if (!mounted) return;
      // `pop` (a diferencia de `maybePop`) no consulta el PopScope, así que
      // no pide confirmación de descarte tras guardar.
      Navigator.of(context).pop(actualizada);
    } on PublicacionServiceException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _guardando = false;
          _progreso = null;
        });
      }
    }
  }

  Future<bool> _confirmarDescarte() async {
    final bool? descartar = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(
          '¿Descartar cambios?',
          style: FormStyles.titulo(pequena: true),
        ),
        content: Text(
          'Los cambios que hiciste en esta publicación no se guardarán.',
          style: FormStyles.subtitulo(pequena: true),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Seguir editando'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: FormStyles.colorError),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    return descartar ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final bool hayCambios = _hayCambios;

    return PopScope<Publicacion>(
      canPop: !_guardando && !hayCambios,
      onPopInvokedWithResult: (bool didPop, Publicacion? result) async {
        if (didPop || _guardando) return;
        final bool descartar = await _confirmarDescarte();
        if (descartar && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.crema,
        appBar: AppBar(title: const Text('Editar publicación')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(FormStyles.s20),
            children: <Widget>[
              SelectorFotos(
                fotos: _fotos,
                habilitado: !_guardando,
                onAgregar: _agregarFotos,
                onQuitar: (int index) {
                  // La publicación debe conservar al menos una foto.
                  if (_fotos.length == 1) {
                    setState(
                      () => _error =
                          'La publicación debe tener al menos una foto. '
                          'Agrega otra antes de quitar esta.',
                    );
                    return;
                  }
                  setState(() => _fotos.removeAt(index));
                },
                onHacerPortada: (int index) =>
                    setState(() => _fotos.insert(0, _fotos.removeAt(index))),
              ),
              const SizedBox(height: FormStyles.s20),
              TextField(
                key: const Key('editar-ubicacion'),
                controller: _ubicacionController,
                enabled: !_guardando,
                maxLength: PublicacionService.largoMaximoUbicacion,
                textCapitalization: TextCapitalization.words,
                decoration:
                    FormStyles.input(
                      label: 'Ubicación (opcional)',
                      hint: '¿Dónde fue? Ej: Guatapé, Antioquia',
                    ).copyWith(
                      prefixIcon: const Icon(
                        Icons.place_outlined,
                        color: AppTheme.verdeAzulado,
                      ),
                    ),
              ),
              const SizedBox(height: FormStyles.s12),
              TextField(
                key: const Key('editar-descripcion'),
                controller: _descripcionController,
                enabled: !_guardando,
                maxLines: 4,
                decoration: FormStyles.input(
                  label: 'Descripción (opcional)',
                  hint: 'Escribe algo sobre tu experiencia... (opcional)',
                ),
              ),
              const SizedBox(height: FormStyles.s20),
              if (_error != null) ...<Widget>[
                AvisoError(mensaje: _error!),
                const SizedBox(height: FormStyles.s16),
              ],
              FilledButton(
                style: FormStyles.botonPrimario(),
                onPressed: (!hayCambios || _guardando) ? null : _guardar,
                child: _guardando
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          if (_progreso
                              case (final int subidas, final int total)
                              when total > 1) ...<Widget>[
                            const SizedBox(width: FormStyles.s12),
                            Text('Subiendo $subidas de $total...'),
                          ],
                        ],
                      )
                    : const Text('Guardar cambios'),
              ),
              const SizedBox(height: FormStyles.s12),
              OutlinedButton(
                style: FormStyles.botonSecundario(),
                onPressed: _guardando
                    ? null
                    : () => Navigator.of(context).maybePop(),
                child: const Text('Cancelar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
