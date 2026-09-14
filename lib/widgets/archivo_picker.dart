import 'dart:typed_data';
import 'dart:ui' show PathMetric;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MissingPluginException;

import '../app_theme.dart';
import '../form_styles.dart';
import '../guia_service.dart';

// Solo PDF: Cloudinary (unsigned upload preset "TripMeet") está configurado
// para aceptar este formato como resource_type "image".
const List<String> _extensionesPermitidas = <String>['pdf'];

/// Error al abrir el selector de archivos del sistema.
class SeleccionArchivoException implements Exception {
  const SeleccionArchivoException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Abre el selector del sistema y devuelve los archivos elegidos (con sus bytes
/// en memoria para funcionar igual en móvil y web). Devuelve lista vacía si el
/// usuario cancela. Lanza [SeleccionArchivoException] si el picker no está
/// disponible en la plataforma actual.
Future<List<ArchivoLocal>> seleccionarArchivos({bool multiple = false}) async {
  List<PlatformFile> seleccionados;
  try {
    if (multiple) {
      seleccionados = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: _extensionesPermitidas,
      );
    } else {
      final PlatformFile? archivo = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: _extensionesPermitidas,
      );
      seleccionados =
          archivo == null ? const <PlatformFile>[] : <PlatformFile>[archivo];
    }
  } on UnimplementedError {
    throw const SeleccionArchivoException(
      'El selector de archivos no está disponible en esta plataforma. '
      'Reinicia la app por completo (no hot reload) tras instalar el paquete.',
    );
  } on MissingPluginException {
    throw const SeleccionArchivoException(
      'Falta registrar el plugin de selección de archivos. Detén la app y '
      'vuelve a ejecutarla (flutter run) para completar la instalación.',
    );
  } catch (error) {
    throw SeleccionArchivoException(
      'No se pudo abrir el selector de archivos: $error',
    );
  }

  final List<ArchivoLocal> archivos = <ArchivoLocal>[];
  for (final PlatformFile f in seleccionados) {
    final Uint8List bytes = await f.readAsBytes();
    archivos.add(
      ArchivoLocal(
        nombre: f.name,
        bytes: bytes,
        extension: (f.extension ?? '').toLowerCase(),
      ),
    );
  }
  return archivos;
}

/// Campo de subida de UN archivo con vista previa, obligatorio u opcional.
///
/// - Vacío: muestra una zona pulsable con instrucciones.
/// - Con archivo: muestra nombre, tamaño y acciones de reemplazar / quitar.
class ArchivoPickerField extends StatelessWidget {
  const ArchivoPickerField({
    super.key,
    required this.etiqueta,
    required this.archivo,
    required this.onSeleccionar,
    required this.onQuitar,
    this.obligatorio = false,
    this.descripcion,
    this.errorText,
    this.habilitado = true,
  });

  final String etiqueta;
  final ArchivoLocal? archivo;
  final VoidCallback onSeleccionar;
  final VoidCallback onQuitar;
  final bool obligatorio;
  final String? descripcion;
  final String? errorText;
  final bool habilitado;

  @override
  Widget build(BuildContext context) {
    final bool conError = errorText != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
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
        if (descripcion != null) ...<Widget>[
          const SizedBox(height: FormStyles.s4),
          Text(descripcion!, style: FormStyles.ayuda()),
        ],
        const SizedBox(height: FormStyles.s8),
        if (archivo == null)
          _ZonaVacia(
            conError: conError,
            habilitado: habilitado,
            onTap: habilitado ? onSeleccionar : null,
          )
        else
          _TarjetaArchivo(
            archivo: archivo!,
            habilitado: habilitado,
            onReemplazar: onSeleccionar,
            onQuitar: onQuitar,
          ),
        if (conError) ...<Widget>[
          const SizedBox(height: FormStyles.s4),
          Text(errorText!, style: FormStyles.error()),
        ],
      ],
    );
  }
}

/// Lista de archivos opcionales (múltiples): primeros auxilios, idiomas, etc.
class ArchivoPickerMultiple extends StatelessWidget {
  const ArchivoPickerMultiple({
    super.key,
    required this.etiqueta,
    required this.archivos,
    required this.onAgregar,
    required this.onQuitar,
    this.descripcion,
    this.habilitado = true,
  });

  final String etiqueta;
  final List<ArchivoLocal> archivos;
  final VoidCallback onAgregar;
  final ValueChanged<int> onQuitar;
  final String? descripcion;
  final bool habilitado;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(etiqueta, style: FormStyles.etiqueta()),
        if (descripcion != null) ...<Widget>[
          const SizedBox(height: FormStyles.s4),
          Text(descripcion!, style: FormStyles.ayuda()),
        ],
        const SizedBox(height: FormStyles.s8),
        for (int i = 0; i < archivos.length; i++) ...<Widget>[
          _TarjetaArchivo(
            archivo: archivos[i],
            habilitado: habilitado,
            onQuitar: () => onQuitar(i),
          ),
          const SizedBox(height: FormStyles.s8),
        ],
        OutlinedButton.icon(
          onPressed: habilitado ? onAgregar : null,
          style: FormStyles.botonSecundario(),
          icon: const Icon(Icons.attach_file_rounded, size: 18),
          label: const Text('Agregar archivo'),
        ),
      ],
    );
  }
}

class _ZonaVacia extends StatelessWidget {
  const _ZonaVacia({
    required this.conError,
    required this.habilitado,
    required this.onTap,
  });

  final bool conError;
  final bool habilitado;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(FormStyles.radio),
      child: DottedBorderBox(
        color: conError
            ? FormStyles.colorError
            : AppTheme.verdeAzulado.withValues(alpha: 0.5),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: FormStyles.s16,
            vertical: FormStyles.s20,
          ),
          child: Row(
            children: <Widget>[
              Icon(
                Icons.cloud_upload_outlined,
                color: habilitado
                    ? AppTheme.azulPetroleo
                    : AppTheme.textoSuave.withValues(alpha: 0.4),
              ),
              const SizedBox(width: FormStyles.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Toca para seleccionar un archivo',
                      style: FormStyles.cuerpo(
                        weight: FontWeight.w600,
                        color: AppTheme.azulPetroleo,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text('Solo PDF', style: FormStyles.ayuda()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TarjetaArchivo extends StatelessWidget {
  const _TarjetaArchivo({
    required this.archivo,
    required this.habilitado,
    this.onReemplazar,
    required this.onQuitar,
  });

  final ArchivoLocal archivo;
  final bool habilitado;
  final VoidCallback? onReemplazar;
  final VoidCallback onQuitar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(FormStyles.s12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(FormStyles.radio),
        border: Border.all(color: FormStyles.colorBorde),
      ),
      child: Row(
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(FormStyles.s8),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Container(
                color: AppTheme.crema,
                child: const Icon(
                  Icons.picture_as_pdf_outlined,
                  color: AppTheme.azulPetroleo,
                ),
              ),
            ),
          ),
          const SizedBox(width: FormStyles.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  archivo.nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FormStyles.cuerpo(
                    weight: FontWeight.w600,
                    color: AppTheme.azulPetroleo,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${archivo.extension.toUpperCase()} · ${archivo.tamanoLegible}',
                  style: FormStyles.ayuda().copyWith(fontStyle: FontStyle.normal),
                ),
              ],
            ),
          ),
          if (onReemplazar != null)
            IconButton(
              tooltip: 'Reemplazar',
              onPressed: habilitado ? onReemplazar : null,
              icon: const Icon(Icons.autorenew_rounded, size: 20),
              color: AppTheme.azulPetroleo,
            ),
          IconButton(
            tooltip: 'Quitar',
            onPressed: habilitado ? onQuitar : null,
            icon: const Icon(Icons.close_rounded, size: 20),
            color: FormStyles.colorError,
          ),
        ],
      ),
    );
  }
}

/// Borde punteado sencillo (sin dependencias extra) para la zona de subida.
class DottedBorderBox extends StatelessWidget {
  const DottedBorderBox({super.key, required this.child, required this.color});

  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRectPainter(color: color),
      child: child,
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  _DashedRectPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final RRect rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(FormStyles.radio),
    );
    final Path path = Path()..addRRect(rrect);

    const double dash = 6;
    const double gap = 4;
    for (final PathMetric metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + dash),
          paint,
        );
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRectPainter oldDelegate) =>
      oldDelegate.color != color;
}
