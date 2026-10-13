import 'package:flutter/material.dart';

import '../calificacion_usuario_service.dart';
import '../form_styles.dart';
import 'aviso_error.dart';

/// Color de las estrellas, el mismo de las reseñas de lugares.
const Color colorEstrella = Colors.orange;

/// Fila de 5 estrellas para elegir una calificación; [valor] `null` = sin
/// elegir. Cada estrella mide 48 px de toque.
class SelectorEstrellas extends StatelessWidget {
  const SelectorEstrellas({
    required this.valor,
    required this.onChanged,
    super.key,
  });

  final int? valor;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        for (int i = calificacionMinima; i <= calificacionMaxima; i++)
          IconButton(
            key: Key('estrella-$i'),
            tooltip: i == 1 ? '1 estrella' : '$i estrellas',
            onPressed: () => onChanged(i),
            icon: Icon(
              valor != null && i <= valor!
                  ? Icons.star_rounded
                  : Icons.star_outline_rounded,
              size: 36,
              color: colorEstrella,
            ),
          ),
      ],
    );
  }
}

/// Estrellas de solo lectura para un promedio (por ejemplo, 4,5 muestra
/// cuatro llenas y una a la mitad).
class EstrellasPromedio extends StatelessWidget {
  const EstrellasPromedio({
    required this.promedio,
    this.tamano = 18,
    super.key,
  });

  final double promedio;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 1; i <= calificacionMaxima; i++)
          Icon(
            promedio >= i
                ? Icons.star_rounded
                : promedio >= i - 0.5
                ? Icons.star_half_rounded
                : Icons.star_outline_rounded,
            size: tamano,
            color: colorEstrella,
          ),
      ],
    );
  }
}

/// "4,5" (un decimal, con coma).
String formatearPromedio(double promedio) =>
    promedio.toStringAsFixed(1).replaceAll('.', ',');

/// Reseña escrita en el diálogo: estrellas y comentario.
typedef ResenaEscrita = ({int estrellas, String comentario});

/// Publica la reseña escrita. Devuelve `null` si se publicó, o el mensaje
/// para mostrar si no (por ejemplo, comentario ofensivo o falla de red).
typedef PublicarResena = Future<String?> Function(ResenaEscrita resena);

/// Diálogo para reseñar a [nombre]: primero se eligen de 1 a 5 estrellas y
/// luego se escribe el comentario. "Publicar reseña" solo se habilita con
/// estrellas y un comentario que no sea vacío ni solo espacios, y llama a
/// [onPublicar]. Si no se pudo publicar, el diálogo sigue abierto con el
/// comentario y el motivo, para corregirlo. Devuelve `true` si se publicó.
Future<bool?> mostrarDialogoResena(
  BuildContext context, {
  required String nombre,
  required PublicarResena onPublicar,
}) {
  return showDialog<bool>(
    context: context,
    builder: (BuildContext context) =>
        _DialogoResena(nombre: nombre, onPublicar: onPublicar),
  );
}

class _DialogoResena extends StatefulWidget {
  const _DialogoResena({required this.nombre, required this.onPublicar});

  final String nombre;
  final PublicarResena onPublicar;

  @override
  State<_DialogoResena> createState() => _DialogoResenaState();
}

class _DialogoResenaState extends State<_DialogoResena> {
  final TextEditingController _comentario = TextEditingController();
  int? _estrellas;

  /// `true` mientras se modera y guarda la reseña.
  bool _publicando = false;

  /// Motivo por el que no se publicó; se muestra sobre el comentario.
  String? _error;

  @override
  void dispose() {
    _comentario.dispose();
    super.dispose();
  }

  bool get _listo =>
      !_publicando &&
      _estrellas != null &&
      CalificacionUsuarioService.validarComentario(_comentario.text) == null;

  Future<void> _publicar() async {
    setState(() {
      _publicando = true;
      _error = null;
    });
    final String? error = await widget.onPublicar((
      estrellas: _estrellas!,
      comentario: _comentario.text.trim(),
    ));
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _publicando = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final int? estrellas = _estrellas;

    return AlertDialog(
      title: Text(
        'Reseña para ${widget.nombre}',
        style: FormStyles.titulo(pequena: true),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              '¿Cómo fue compartir esta experiencia?',
              textAlign: TextAlign.center,
              style: FormStyles.subtitulo(pequena: true),
            ),
            const SizedBox(height: FormStyles.s12),
            FittedBox(
              child: SelectorEstrellas(
                valor: estrellas,
                onChanged: (int valor) {
                  if (!_publicando) setState(() => _estrellas = valor);
                },
              ),
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: FormStyles.s12),
              AvisoError(key: const Key('error-resena'), mensaje: _error!),
            ],
            if (estrellas != null) ...<Widget>[
              const SizedBox(height: FormStyles.s12),
              TextField(
                key: const Key('comentario-resena'),
                controller: _comentario,
                enabled: !_publicando,
                autofocus: true,
                maxLines: 4,
                maxLength: longitudMaximaComentarioResena,
                textCapitalization: TextCapitalization.sentences,
                // Al editar el comentario se quita el aviso anterior.
                onChanged: (_) => setState(() => _error = null),
                decoration: FormStyles.input(
                  label: 'Comentario',
                  hint: 'Cuenta cómo fue compartir el evento con esta persona',
                ),
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _publicando ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const Key('publicar-resena'),
          onPressed: _listo ? _publicar : null,
          child: _publicando
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Publicar reseña'),
        ),
      ],
    );
  }
}
