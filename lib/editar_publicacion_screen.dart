import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'form_styles.dart';
import 'guia_service.dart' show ArchivoLocal;
import 'publicacion_service.dart';
import 'widgets/archivo_picker.dart';
import 'widgets/aviso_error.dart';

/// Pantalla para editar una publicación propia: precarga la foto y la
/// descripción actuales y permite cambiar el texto o reemplazar la foto.
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

  ArchivoLocal? _nuevaImagen;
  bool _guardando = false;
  String? _error;

  /// La foto es obligatoria (igual que al crear), así que solo cuenta como
  /// cambio reemplazarla; la descripción se compara ya normalizada para que
  /// agregar espacios no cuente como edición.
  bool get _hayCambios =>
      _nuevaImagen != null ||
      PublicacionService.normalizarDescripcion(_descripcionController.text) !=
          widget.publicacion.descripcion;

  @override
  void initState() {
    super.initState();
    _descripcionController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _descripcionController.dispose();
    super.dispose();
  }

  Future<void> _seleccionarImagen() async {
    setState(() => _error = null);

    try {
      final List<ArchivoLocal> seleccionados = await seleccionarArchivos(
        extensiones: extensionesImagenPermitidas,
      );
      if (seleccionados.isEmpty) {
        return;
      }

      final ArchivoLocal archivo = seleccionados.first;
      final String? errorImagen = PublicacionService.validarImagen(archivo);
      if (errorImagen != null) {
        setState(() => _error = errorImagen);
        return;
      }

      setState(() => _nuevaImagen = archivo);
    } on SeleccionArchivoException catch (error) {
      setState(() => _error = error.message);
    }
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
        nuevaImagen: _nuevaImagen,
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
        });
      }
    }
  }

  Future<bool> _confirmarDescarte() async {
    final bool? descartar = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('¿Descartar cambios?', style: FormStyles.titulo(pequena: true)),
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
              _FotoEditable(
                imagenUrlActual: widget.publicacion.imagenUrl,
                nuevaImagen: _nuevaImagen,
                habilitado: !_guardando,
                onCambiar: _seleccionarImagen,
                onDeshacer: () => setState(() => _nuevaImagen = null),
              ),
              const SizedBox(height: FormStyles.s20),
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
              const SizedBox(height: FormStyles.s12),
              OutlinedButton(
                style: FormStyles.botonSecundario(),
                onPressed:
                    _guardando ? null : () => Navigator.of(context).maybePop(),
                child: const Text('Cancelar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Vista previa de la foto de la publicación: la actual (desde Cloudinary) o
/// la nueva elegida (desde memoria), con acciones para cambiarla o volver a
/// la original.
class _FotoEditable extends StatelessWidget {
  const _FotoEditable({
    required this.imagenUrlActual,
    required this.nuevaImagen,
    required this.habilitado,
    required this.onCambiar,
    required this.onDeshacer,
  });

  final String imagenUrlActual;
  final ArchivoLocal? nuevaImagen;
  final bool habilitado;
  final VoidCallback onCambiar;
  final VoidCallback onDeshacer;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(FormStyles.radioTarjeta),
          border: Border.all(color: FormStyles.colorBorde),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (nuevaImagen != null)
              Image.memory(nuevaImagen!.bytes, fit: BoxFit.cover)
            else
              Image.network(
                imagenUrlActual,
                fit: BoxFit.cover,
                errorBuilder: (BuildContext context, Object error,
                        StackTrace? stackTrace) =>
                    Icon(
                  Icons.broken_image_outlined,
                  size: 48,
                  color: AppTheme.textoSuave.withValues(alpha: 0.4),
                ),
              ),
            Positioned(
              right: FormStyles.s8,
              bottom: FormStyles.s8,
              child: _AccionFoto(
                icono: Icons.autorenew_rounded,
                texto: 'Cambiar foto',
                onTap: habilitado ? onCambiar : null,
              ),
            ),
            if (nuevaImagen != null)
              Positioned(
                left: FormStyles.s8,
                bottom: FormStyles.s8,
                child: _AccionFoto(
                  icono: Icons.undo_rounded,
                  texto: 'Usar la original',
                  onTap: habilitado ? onDeshacer : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AccionFoto extends StatelessWidget {
  const _AccionFoto({
    required this.icono,
    required this.texto,
    required this.onTap,
  });

  final IconData icono;
  final String texto;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(FormStyles.radioPill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(FormStyles.radioPill),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: FormStyles.s12,
            vertical: FormStyles.s8,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icono, size: 16, color: Colors.white),
              const SizedBox(width: FormStyles.s4),
              Text(
                texto,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
