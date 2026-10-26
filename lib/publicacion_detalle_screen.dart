import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'editar_publicacion_screen.dart';
import 'form_styles.dart';
import 'publicacion_service.dart';
import 'reportes_admin_service.dart';
import 'widgets/carrusel_fotos.dart';

const List<String> _meses = <String>[
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

String _formatearFecha(DateTime fecha) =>
    '${fecha.day} de ${_meses[fecha.month - 1]} de ${fecha.year}';

String _formatearHora(DateTime fecha) =>
    '${fecha.hour.toString().padLeft(2, '0')}:'
    '${fecha.minute.toString().padLeft(2, '0')}';

/// Pantalla de detalle de una publicación: muestra la foto en grande junto
/// con su descripción y fecha. Se abre al tocar una foto en la grilla del
/// Perfil. Si quien la ve es el autor, permite editarla o eliminarla.
class PublicacionDetalleScreen extends StatefulWidget {
  const PublicacionDetalleScreen({
    required this.publicacion,
    this.onPublicacionActualizada,
    this.onPublicacionEliminada,
    this.uidUsuarioActual,
    this.service,
    super.key,
  });

  final Publicacion publicacion;

  /// Se llama tras guardar una edición, para que la pantalla anterior
  /// (por ejemplo, la grilla del Perfil) refleje el cambio sin recargar.
  final ValueChanged<Publicacion>? onPublicacionActualizada;

  /// Se llama con el id de la publicación tras eliminarla, para que la
  /// pantalla anterior la quite de su lista sin recargar.
  final ValueChanged<String>? onPublicacionEliminada;

  /// UID de quien está viendo la publicación. Por defecto, el usuario
  /// autenticado en Firebase; se puede inyectar en pruebas.
  final String? uidUsuarioActual;

  /// Servicio para eliminar la publicación y que se pasa a la pantalla de
  /// edición (inyectable en pruebas).
  final PublicacionService? service;

  @override
  State<PublicacionDetalleScreen> createState() =>
      _PublicacionDetalleScreenState();
}

class _PublicacionDetalleScreenState extends State<PublicacionDetalleScreen> {
  late Publicacion _publicacion = widget.publicacion;
  late final PublicacionService _service =
      widget.service ?? PublicacionService();
  bool _eliminando = false;

  bool get _esAutor {
    final String? uid =
        widget.uidUsuarioActual ?? FirebaseAuth.instance.currentUser?.uid;
    return uid != null && uid == _publicacion.uid;
  }

  Future<void> _editar() async {
    final Publicacion? actualizada = await Navigator.of(context)
        .push<Publicacion>(
          MaterialPageRoute<Publicacion>(
            builder: (_) => EditarPublicacionScreen(
              publicacion: _publicacion,
              service: widget.service,
            ),
          ),
        );
    if (actualizada == null || !mounted) return;

    setState(() => _publicacion = actualizada);
    widget.onPublicacionActualizada?.call(actualizada);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Publicación actualizada correctamente.')),
    );
  }

  Future<bool> _confirmarEliminacion() async {
    final bool? eliminar = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(
          '¿Eliminar publicación?',
          style: FormStyles.titulo(pequena: true),
        ),
        content: Text(
          'La publicación se eliminará de forma permanente. Esta acción no '
          'se puede deshacer.',
          style: FormStyles.subtitulo(pequena: true),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: FormStyles.colorError),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    return eliminar ?? false;
  }

  Future<void> _eliminar() async {
    if (!await _confirmarEliminacion() || !mounted) return;

    setState(() => _eliminando = true);
    try {
      await _service.eliminarPublicacion(_publicacion.id);
    } on PublicacionServiceException catch (error) {
      if (!mounted) return;
      setState(() => _eliminando = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
      return;
    }
    if (!mounted) return;

    widget.onPublicacionEliminada?.call(_publicacion.id);
    Navigator.of(context).pop();
  }

  Future<void> _reportarPublicacion() async {
    final TextEditingController motivoController = TextEditingController();
    final bool? enviar = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Reportar publicación'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text(
                'Por favor indica la razón por la que consideras que esta publicación incumple las normas:',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: motivoController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Ej. Contenido ofensivo, spam, violencia...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Enviar reporte'),
            ),
          ],
        );
      },
    );

    if (enviar != true || !mounted) return;
    final String motivo = motivoController.text.trim();
    if (motivo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe un motivo para el reporte.')),
      );
      return;
    }

    try {
      await ReportesAdminService().reportarPublicacion(
        publicacionId: _publicacion.id,
        autorPublicacionUid: _publicacion.uid,
        imagenUrl: _publicacion.imagenUrl,
        descripcionPublicacion: _publicacion.descripcion,
        motivo: motivo,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reporte enviado a los administradores. ¡Gracias!'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo enviar el reporte: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final Publicacion publicacion = _publicacion;

    return PopScope<void>(
      canPop: !_eliminando,
      child: Scaffold(
        backgroundColor: AppTheme.crema,
        appBar: AppBar(
          title: const Text('Publicación'),
          actions: <Widget>[
            if (_esAutor) ...<Widget>[
              TextButton.icon(
                onPressed: _eliminando ? null : _editar,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Editar'),
              ),
              if (_eliminando)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: FormStyles.s16),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                IconButton(
                  onPressed: _eliminar,
                  tooltip: 'Eliminar',
                  color: FormStyles.colorError,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
            ] else
              IconButton(
                key: const Key('reportar-publicacion-btn'),
                icon: const Icon(Icons.flag_outlined, color: Colors.orange),
                tooltip: 'Reportar publicación',
                onPressed: _reportarPublicacion,
              ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: <Widget>[
              Hero(
                tag: 'publicacion-${publicacion.id}',
                child: AspectRatio(
                  aspectRatio: 1,
                  child: CarruselFotos(
                    urls: <String>[
                      for (final ImagenPublicacion imagen
                          in publicacion.imagenes)
                        imagen.url,
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(FormStyles.s20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        const Icon(
                          Icons.calendar_today_rounded,
                          size: 16,
                          color: AppTheme.verdeAzulado,
                        ),
                        const SizedBox(width: FormStyles.s8),
                        Text(
                          _formatearFecha(publicacion.fechaCreacion),
                          style: FormStyles.cuerpo(
                            weight: FontWeight.w600,
                            color: AppTheme.verdeAzulado,
                          ),
                        ),
                        if (publicacion.editado) ...<Widget>[
                          const SizedBox(width: FormStyles.s8),
                          _EtiquetaEditado(
                            fechaEdicion: publicacion.fechaEdicion,
                          ),
                        ],
                      ],
                    ),
                    if (publicacion.ubicacion != null) ...<Widget>[
                      const SizedBox(height: FormStyles.s8),
                      Row(
                        children: <Widget>[
                          const Icon(
                            Icons.place_outlined,
                            size: 16,
                            color: AppTheme.verdeAzulado,
                          ),
                          const SizedBox(width: FormStyles.s8),
                          Expanded(
                            child: Text(
                              publicacion.ubicacion!,
                              style: FormStyles.cuerpo(
                                weight: FontWeight.w600,
                                color: AppTheme.azulPetroleo,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: FormStyles.s16),
                    Text(
                      publicacion.descripcion ?? 'Sin descripción.',
                      style: publicacion.descripcion == null
                          ? FormStyles.ayuda()
                          : FormStyles.subtitulo(),
                    ),
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

/// Etiqueta discreta "Editado" junto a la fecha; al mantenerla presionada
/// (o pasar el cursor en web) muestra cuándo fue la última edición.
class _EtiquetaEditado extends StatelessWidget {
  const _EtiquetaEditado({required this.fechaEdicion});

  final DateTime? fechaEdicion;

  @override
  Widget build(BuildContext context) {
    final Text etiqueta = Text(
      'Editado',
      style: FormStyles.cuerpo(
        size: 12,
        color: AppTheme.textoSuave.withValues(alpha: 0.6),
      ),
    );

    final DateTime? fecha = fechaEdicion;
    if (fecha == null) return etiqueta;

    return Tooltip(
      message:
          'Editado el ${_formatearFecha(fecha)} a las ${_formatearHora(fecha)}',
      child: etiqueta,
    );
  }
}
