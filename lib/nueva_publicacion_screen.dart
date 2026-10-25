import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'form_styles.dart';
import 'publicacion_service.dart';
import 'widgets/aviso_error.dart';
import 'widgets/selector_fotos.dart';

/// Pantalla para crear una publicación: elegir una o varias fotos (al menos
/// una; con varias se ven como carrusel), indicar dónde fue (opcional),
/// escribir una descripción (opcional) y publicar. Se abre desde el Perfil
/// del turista y desde el feed.
class NuevaPublicacionScreen extends StatefulWidget {
  const NuevaPublicacionScreen({super.key});

  @override
  State<NuevaPublicacionScreen> createState() => _NuevaPublicacionScreenState();
}

class _NuevaPublicacionScreenState extends State<NuevaPublicacionScreen> {
  final PublicacionService _service = PublicacionService();
  final TextEditingController _descripcionController = TextEditingController();
  final TextEditingController _ubicacionController = TextEditingController();

  final List<FotoEdicion> _fotos = <FotoEdicion>[];
  bool _publicando = false;
  String? _error;

  /// Progreso de la subida: (fotos subidas, total).
  (int, int)? _progreso;

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

  Future<void> _publicar() async {
    if (_fotos.isEmpty) return;

    setState(() {
      _publicando = true;
      _error = null;
    });

    try {
      final List<ImagenPublicacion> imagenes = await _service.subirImagenes(
        _fotos,
        onProgreso: (int subidas, int total) {
          if (mounted) setState(() => _progreso = (subidas, total));
        },
      );
      await _service.crearPublicacion(
        imagenes: imagenes,
        descripcion: _descripcionController.text,
        ubicacion: _ubicacionController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on PublicacionServiceException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) {
        setState(() {
          _publicando = false;
          _progreso = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final (int, int)? progreso = _progreso;

    return Scaffold(
      backgroundColor: AppTheme.crema,
      appBar: AppBar(title: const Text('Nueva publicación')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(FormStyles.s20),
          children: <Widget>[
            SelectorFotos(
              fotos: _fotos,
              habilitado: !_publicando,
              onAgregar: _agregarFotos,
              onQuitar: (int index) => setState(() => _fotos.removeAt(index)),
              onHacerPortada: (int index) =>
                  setState(() => _fotos.insert(0, _fotos.removeAt(index))),
            ),
            const SizedBox(height: FormStyles.s20),
            TextField(
              key: const Key('nueva-ubicacion'),
              controller: _ubicacionController,
              enabled: !_publicando,
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
              onPressed: (_fotos.isEmpty || _publicando) ? null : _publicar,
              child: _publicando
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
                        if (progreso != null && progreso.$2 > 1) ...<Widget>[
                          const SizedBox(width: FormStyles.s12),
                          Text('Subiendo ${progreso.$1} de ${progreso.$2}...'),
                        ],
                      ],
                    )
                  : Text(
                      _fotos.length > 1
                          ? 'Publicar ${_fotos.length} fotos'
                          : 'Publicar',
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
