import 'package:flutter/material.dart';

import '../form_styles.dart';

/// Aviso de error inline (no snackbar) para los submit de las pantallas
/// de registro.
class AvisoError extends StatelessWidget {
  const AvisoError({super.key, required this.mensaje});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(FormStyles.s12),
      decoration: BoxDecoration(
        color: FormStyles.colorError.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(FormStyles.radio),
        border: Border.all(color: FormStyles.colorError.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.error_outline_rounded,
              color: FormStyles.colorError, size: 20),
          const SizedBox(width: FormStyles.s8),
          Expanded(
            child: Text(
              mensaje,
              style: FormStyles.cuerpo(color: FormStyles.colorError),
            ),
          ),
        ],
      ),
    );
  }
}
