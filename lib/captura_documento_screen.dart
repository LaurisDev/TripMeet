
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'cloudinary_service.dart';
import 'verificacion_identidad_service.dart';

class CapturaDocumentoScreen extends StatefulWidget {
  const CapturaDocumentoScreen({super.key});

  @override
  State<CapturaDocumentoScreen> createState() =>
      _CapturaDocumentoScreenState();
}

class _CapturaDocumentoScreenState
    extends State<CapturaDocumentoScreen> {
  final VerificacionIdentidadService _servicio =
      VerificacionIdentidadService();

  final CloudinaryService _cloudinary = CloudinaryService();

  CameraController? _controlador;
  Uint8List? _documento;

  bool _cargando = false;
  String? _errorCamara;

  @override
  void initState() {
    super.initState();
    _iniciarCamara();
  }

  Future<void> _iniciarCamara() async {
    try {
      final camaras = await availableCameras();

      if (camaras.isEmpty) {
        throw Exception('No se encontró ninguna cámara.');
      }

      CameraDescription camara = camaras.first;

      for (final disponible in camaras) {
        if (disponible.lensDirection == CameraLensDirection.back) {
          camara = disponible;
          break;
        }
      }

      final controlador = CameraController(
        camara,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await controlador.initialize();

      if (!mounted) {
        await controlador.dispose();
        return;
      }

      setState(() {
        _controlador = controlador;
        _errorCamara = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorCamara =
            'No se pudo iniciar la cámara. Revisa los permisos.\n$e';
      });
    }
  }

  Future<void> _tomarFotografia() async {
    final controlador = _controlador;

    if (controlador == null ||
        !controlador.value.isInitialized ||
        controlador.value.isTakingPicture) {
      return;
    }

    setState(() => _cargando = true);

    try {
      final fotografia = await controlador.takePicture();
      final bytes = await fotografia.readAsBytes();

      if (!mounted) return;

      setState(() => _documento = bytes);

      _mostrarMensaje('Fotografía capturada correctamente.');
    } catch (e) {
      if (!mounted) return;
      _mostrarMensaje('Error al tomar la fotografía: $e');
    } finally {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  Future<void> _enviarSolicitud() async {
    final documento = _documento;

    if (documento == null) {
      _mostrarMensaje('Primero debes tomar la fotografía.');
      return;
    }

    setState(() => _cargando = true);

    try {
      // Revisamos el estado antes de subir otra imagen.
      final datos = await _servicio.consultarEstado();

      if (datos?['estadoVerificacionIdentidad'] == 'pendiente') {
        throw Exception('Ya tienes una solicitud pendiente.');
      }

      if (datos?['identidadVerificada'] == true) {
        throw Exception('Tu identidad ya está verificada.');
      }

      // Esta subida es para la demostración con imágenes ficticias.
      final subida = await _cloudinary.subirImagen(
        bytes: documento,
        nombreArchivo:
            'documento_demo_${DateTime.now().millisecondsSinceEpoch}.jpg',
        folder: 'tripmeet/verificacion-identidad-demo',
      );

      // Guardamos la URL y el identificador junto a la solicitud.
      await _servicio.enviarSolicitud(
        documentoIdentidadUrl: subida.secureUrl,
        documentoIdentidadPublicId: subida.publicId,
      );

      if (!mounted) return;

      _mostrarMensaje(
        'Solicitud registrada y fotografía subida correctamente.',
      );
    } catch (e) {
      if (!mounted) return;

      _mostrarMensaje('No se pudo enviar la solicitud: $e');
    } finally {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  Future<void> _consultarEstado() async {
    setState(() => _cargando = true);

    try {
      final datos = await _servicio.consultarEstado();

      if (!mounted) return;

      final estado =
          datos?['estadoVerificacionIdentidad'] ?? 'sin solicitud';

      final motivo = datos?['motivoRechazoIdentidad'];

      _mostrarMensaje(
        motivo != null && estado == 'rechazado'
            ? 'Estado: $estado. Motivo: $motivo'
            : 'Estado de verificación: $estado',
      );
    } catch (e) {
      if (!mounted) return;
      _mostrarMensaje('No se pudo consultar el estado: $e');
    } finally {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  void _mostrarMensaje(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje)),
    );
  }

  @override
  void dispose() {
    _controlador?.dispose();
    _cloudinary.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controlador = _controlador;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verificar identidad'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Toma una foto clara del documento de prueba.',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Center(
                child: _documento != null
                    ? Image.memory(
                        _documento!,
                        fit: BoxFit.contain,
                      )
                    : _errorCamara != null
                        ? SingleChildScrollView(
                            child: Text(
                              _errorCamara!,
                              textAlign: TextAlign.center,
                            ),
                          )
                        : controlador == null ||
                                !controlador.value.isInitialized
                            ? const CircularProgressIndicator()
                            : AspectRatio(
                                aspectRatio: controlador.value.aspectRatio,
                                child: CameraPreview(controlador),
                              ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _cargando ||
                      controlador == null ||
                      !controlador.value.isInitialized
                  ? null
                  : _tomarFotografia,
              icon: const Icon(Icons.camera_alt),
              label: Text(
                _cargando ? 'Procesando...' : 'Tomar fotografía',
              ),
            ),
            if (_documento != null) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _cargando
                    ? null
                    : () => setState(() => _documento = null),
                child: const Text('Volver a tomar la foto'),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _cargando ? null : _enviarSolicitud,
                icon: const Icon(Icons.send),
                label: const Text('Enviar solicitud'),
              ),
            ],
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _cargando ? null : _consultarEstado,
              child: const Text('Consultar estado'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Usa únicamente imágenes ficticias para esta demostración.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
