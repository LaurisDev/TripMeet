import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app_theme.dart';
import '../form_styles.dart';

/// Selector múltiple con apariencia de chips, consistente con los botones de
/// rol de la Pantalla 1 (naranja al seleccionar, borde gris al no).
///
/// Reutilizable para zonas, especialidades e idiomas de la Pantalla 3.
class MultiSelectChips extends StatelessWidget {
  const MultiSelectChips({
    super.key,
    required this.opciones,
    required this.seleccionadas,
    required this.onChanged,
    this.etiqueta,
    this.obligatorio = false,
    this.errorText,
    this.ayuda,
  });

  final List<String> opciones;
  final Set<String> seleccionadas;
  final ValueChanged<Set<String>> onChanged;
  final String? etiqueta;
  final bool obligatorio;
  final String? errorText;
  final String? ayuda;

  void _alternar(String opcion) {
    final Set<String> nuevo = Set<String>.of(seleccionadas);
    if (!nuevo.add(opcion)) {
      nuevo.remove(opcion);
    }
    onChanged(nuevo);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (etiqueta != null) ...<Widget>[
          Text.rich(
            TextSpan(
              text: etiqueta,
              style: FormStyles.etiqueta(),
              children: <InlineSpan>[
                if (obligatorio)
                  TextSpan(
                    text: ' *',
                    style: FormStyles.etiqueta()
                        .copyWith(color: FormStyles.colorError),
                  ),
              ],
            ),
          ),
          const SizedBox(height: FormStyles.s8),
        ],
        Wrap(
          spacing: FormStyles.s8,
          runSpacing: FormStyles.s8,
          children: opciones.map((String opcion) {
            final bool activa = seleccionadas.contains(opcion);
            return _Chip(
              texto: opcion,
              activa: activa,
              onTap: () => _alternar(opcion),
            );
          }).toList(),
        ),
        if (errorText != null) ...<Widget>[
          const SizedBox(height: FormStyles.s8),
          Text(errorText!, style: FormStyles.error()),
        ] else if (ayuda != null) ...<Widget>[
          const SizedBox(height: FormStyles.s4),
          Text(ayuda!, style: FormStyles.ayuda()),
        ],
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.texto,
    required this.activa,
    required this.onTap,
  });

  final String texto;
  final bool activa;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
          horizontal: FormStyles.s16,
          vertical: FormStyles.s12,
        ),
        decoration: BoxDecoration(
          color: activa ? AppTheme.naranjaQuemado : Colors.white,
          borderRadius: BorderRadius.circular(FormStyles.radioPill),
          border: Border.all(
            color: activa ? AppTheme.naranjaQuemado : FormStyles.colorBorde,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              activa ? Icons.check_rounded : Icons.add_rounded,
              size: 16,
              color: activa ? Colors.white : AppTheme.azulPetroleo,
            ),
            const SizedBox(width: FormStyles.s4),
            Text(
              texto,
              style: GoogleFonts.workSans(
                fontSize: 14,
                fontWeight: activa ? FontWeight.w600 : FontWeight.w500,
                color: activa ? Colors.white : AppTheme.azulPetroleo,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
