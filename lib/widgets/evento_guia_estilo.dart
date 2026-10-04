import 'package:flutter/material.dart';

import '../form_styles.dart';

/// Paleta del diseño premium de los eventos creados por guías turísticos.
/// Es exclusiva de la sección "Eventos": no forma parte de `AppTheme`.
///
/// Contrastes (WCAG): [titulo] sobre [fondo] 5.9:1, [texto] sobre [fondo]
/// 8.0:1 y [textoEtiqueta] sobre [fondoEtiqueta] 6.3:1. Todos cumplen AA
/// para texto normal.
abstract final class EstiloEventoGuia {
  /// Amarillo cálido del recuadro "Experiencia premium".
  static const Color fondo = Color(0xFFFFF1B8);

  /// Dorado del borde del recuadro.
  static const Color borde = Color(0xFFE8C54F);

  /// Dorado oscuro para el título y los íconos del recuadro.
  static const Color titulo = Color(0xFF7A5600);

  /// Texto del recuadro.
  static const Color texto = Color(0xFF5C4600);

  /// Fondo y texto de la etiqueta "Premium" junto al nombre del evento.
  static const Color fondoEtiqueta = Color(0xFFFBE3D6);
  static const Color textoEtiqueta = Color(0xFF8A3B12);
}

/// Etiqueta discreta "Premium" que acompaña el nombre de un evento creado
/// por un guía turístico.
class EtiquetaPremium extends StatelessWidget {
  const EtiquetaPremium({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: FormStyles.s8,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: EstiloEventoGuia.fondoEtiqueta,
        borderRadius: BorderRadius.circular(FormStyles.radioPill),
      ),
      child: Text(
        'Premium',
        style: FormStyles.cuerpo(
          size: 12,
          weight: FontWeight.w600,
          color: EstiloEventoGuia.textoEtiqueta,
        ),
      ),
    );
  }
}

/// Recuadro amarillo "Experiencia premium" de un evento creado por un guía
/// turístico. Afirma que el guía tiene certificado aprobado solo si
/// [certificadoAprobado] es `true`; [child] permite añadir contenido extra
/// (en el detalle, el acceso al certificado).
class RecuadroExperienciaPremium extends StatelessWidget {
  const RecuadroExperienciaPremium({
    required this.certificadoAprobado,
    this.child,
    super.key,
  });

  final bool certificadoAprobado;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final Widget? extra = child;

    return Container(
      key: const Key('evento-recuadro-guia'),
      width: double.infinity,
      padding: const EdgeInsets.all(FormStyles.s12),
      decoration: BoxDecoration(
        color: EstiloEventoGuia.fondo,
        borderRadius: BorderRadius.circular(FormStyles.radio),
        border: Border.all(color: EstiloEventoGuia.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.star_border_rounded,
                size: 20,
                color: EstiloEventoGuia.titulo,
              ),
              const SizedBox(width: FormStyles.s8),
              Expanded(
                child: Text(
                  'Experiencia premium',
                  style: FormStyles.cuerpo(
                    size: 15,
                    weight: FontWeight.w700,
                    color: EstiloEventoGuia.titulo,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: FormStyles.s4),
          Text(
            certificadoAprobado
                ? 'Evento publicado por un guía turístico con certificado '
                      'aprobado.'
                : 'Evento publicado por un guía turístico.',
            style: FormStyles.cuerpo(color: EstiloEventoGuia.texto),
          ),
          if (extra != null) ...<Widget>[
            const SizedBox(height: FormStyles.s12),
            extra,
          ],
        ],
      ),
    );
  }
}
