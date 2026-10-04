import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'cloudinary_service.dart' show CloudinarySubida;
import 'form_styles.dart';
import 'guia_service.dart' show ArchivoLocal;
import 'publicacion_service.dart';
import 'widgets/archivo_picker.dart';
import 'widgets/aviso_error.dart';
import 'widgets/foto_seleccionada.dart';

/// Pantalla para crear una publicación: elegir foto (obligatoria), escribir
/// una descripción (opcional) y publicar. Se abre desde el Perfil del
/// turista.
class NuevaPublicacionScreen extends StatefulWidget {
  const NuevaPublicacionScreen({super.key});

  @override
  State<NuevaPublicacionScreen> createState() =>
      _NuevaPublicacionScreenState();
}

class _NuevaPublicacionScreenState extends State<NuevaPublicacionScreen> {
  final PublicacionService _service = PublicacionService();
  final TextEditingController _descripcionController = TextEditingController();

  ArchivoLocal? _imagen;
  bool _publicando = false;
  String? _error;

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

      setState(() => _imagen = archivo);
    } on SeleccionArchivoException catch (error) {
      setState(() => _error = error.message);
    }
  }

  Future<void> _publicar() async {
    final ArchivoLocal? imagen = _imagen;
    if (imagen == null) return;

    setState(() {
      _publicando = true;
      _error = null;
    });

    try {
      final CloudinarySubida subida = await _service.subirImagen(imagen);
      await _service.crearPublicacion(
        imagenUrl: subida.secureUrl,
        imagenPublicId: subida.publicId,
        descripcion: _descripcionController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on PublicacionServiceException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _publicando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.crema,
      appBar: AppBar(title: const Text('Nueva publicación')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(FormStyles.s20),
          children: <Widget>[
            FotoSeleccionada(
              imagen: _imagen,
              habilitado: !_publicando,
              onTap: _seleccionarImagen,
            ),
            const SizedBox(height: FormStyles.s20),
            TextField(
              controller: _descripcionController,
              enabled: !_publicando,
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
              onPressed: (_imagen == null || _publicando) ? null : _publicar,
              child: _publicando
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Publicar'),
            ),
          ],
        ),
      ),
    );
  }
}
