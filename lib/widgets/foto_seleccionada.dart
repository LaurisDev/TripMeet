import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../form_styles.dart';
import '../guia_service.dart' show ArchivoLocal;

/// Recuadro para elegir la foto de un formulario: muestra una invitación a
/// seleccionarla o, si ya hay una, su vista previa con "Cambiar foto". Lo
/// usan la nueva publicación y el nuevo evento.
class FotoSeleccionada extends StatelessWidget {
  const FotoSeleccionada({
    required this.imagen,
    required this.habilitado,
    required this.onTap,
    this.aspectRatio = 1,
    super.key,
  });

  final ArchivoLocal? imagen;
  final bool habilitado;
  final VoidCallback onTap;

  /// Proporción del recuadro: cuadrado en publicaciones, 16:9 en eventos.
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: habilitado ? onTap : null,
      borderRadius: BorderRadius.circular(FormStyles.radioTarjeta),
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(FormStyles.radioTarjeta),
            border: Border.all(color: FormStyles.colorBorde),
          ),
          clipBehavior: Clip.antiAlias,
          child: imagen == null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    const Icon(
                      Icons.add_a_photo_outlined,
                      size: 40,
                      color: AppTheme.azulPetroleo,
                    ),
                    const SizedBox(height: FormStyles.s8),
                    Text(
                      'Toca para seleccionar una foto',
                      style: FormStyles.cuerpo(
                        weight: FontWeight.w600,
                        color: AppTheme.azulPetroleo,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'JPG, JPEG, PNG o WEBP',
                      style: FormStyles.ayuda(),
                    ),
                  ],
                )
              : Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    Image.memory(imagen!.bytes, fit: BoxFit.cover),
                    Positioned(
                      right: FormStyles.s8,
                      bottom: FormStyles.s8,
                      child: Material(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(FormStyles.radioPill),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: FormStyles.s12,
                            vertical: FormStyles.s8,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(Icons.autorenew_rounded, size: 16, color: Colors.white),
                              SizedBox(width: FormStyles.s4),
                              Text(
                                'Cambiar foto',
                                style: TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
