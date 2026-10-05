import 'package:flutter/material.dart';

import '../app_theme.dart';

/// Imagen desde una URL (Cloudinary) que ocupa todo su espacio, con un
/// indicador mientras carga y un ícono si no se puede mostrar.
class ImagenRemota extends StatelessWidget {
  const ImagenRemota({required this.url, this.fondo = Colors.white, super.key});

  final String url;

  /// Color de fondo mientras carga o si falla.
  final Color fondo;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      loadingBuilder:
          (BuildContext context, Widget child, ImageChunkEvent? progress) {
            if (progress == null) return child;
            return Container(
              color: fondo,
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          },
      errorBuilder:
          (BuildContext context, Object error, StackTrace? stackTrace) =>
              Container(
                color: fondo,
                child: Icon(
                  Icons.broken_image_outlined,
                  size: 48,
                  color: AppTheme.textoSuave.withValues(alpha: 0.4),
                ),
              ),
    );
  }
}
