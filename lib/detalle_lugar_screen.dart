import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'lugares_service.dart';
import 'perfil_usuario_screen.dart';

class DetalleLugarScreen extends StatefulWidget {
  final Lugar lugar;

  const DetalleLugarScreen({super.key, required this.lugar});

  @override
  State<DetalleLugarScreen> createState() => _DetalleLugarScreenState();
}

class _DetalleLugarScreenState extends State<DetalleLugarScreen> {
  final LugaresService _lugaresService = LugaresService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Resena> _resenas = [];
  bool _cargandoResenas = true;

  @override
  void initState() {
    super.initState();
    _cargarResenas();
  }

  Future<void> _cargarResenas() async {
    try {
      final resenas = await _lugaresService.obtenerResenas(widget.lugar.id);
      if (mounted) {
        setState(() {
          _resenas = resenas;
          _cargandoResenas = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cargandoResenas = false;
        });
      }
    }
  }

  /// HU-14 y HU-15: Muestra formulario para crear o editar una reseña.
  void _mostrarFormularioResena({Resena? resenaExistente}) {
    final bool esEdicion = resenaExistente != null;
    double calificacionSeleccionada = resenaExistente?.calificacion ?? 5.0;
    final TextEditingController comentarioController = TextEditingController(
      text: resenaExistente?.comentario ?? '',
    );
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        bool guardando = false;
        return StatefulBuilder(
          builder: (builderContext, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                esEdicion ? 'Editar reseña' : 'Escribir reseña',
                style: const TextStyle(
                  color: AppTheme.azulPetroleo,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Calificación:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        final starRating = index + 1;
                        return IconButton(
                          icon: Icon(
                            starRating <= calificacionSeleccionada
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: Colors.orange,
                            size: 32,
                          ),
                          onPressed: () {
                            setDialogState(() {
                              calificacionSeleccionada = starRating.toDouble();
                            });
                          },
                        );
                      }),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: comentarioController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Tu comentario',
                        hintText: 'Cuéntanos tu experiencia en este lugar...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: guardando
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.azulPetroleo,
                  ),
                  onPressed: guardando
                      ? null
                      : () async {
                          final comentarioTexto = comentarioController.text.trim();
                          if (comentarioTexto.isEmpty) {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Escribe un comentario antes de publicar.'),
                              ),
                            );
                            return;
                          }

                          setDialogState(() => guardando = true);

                          try {
                            final User? usuarioActual = _auth.currentUser;
                            final String nombreUser = usuarioActual?.displayName ??
                                (usuarioActual?.email?.split('@').first) ??
                                'Viajero';

                            final nuevaResena = Resena(
                              id: resenaExistente?.id,
                              usuarioId: usuarioActual?.uid ?? resenaExistente?.usuarioId,
                              nombreUsuario: resenaExistente?.nombreUsuario ?? nombreUser,
                              fotoUsuario: usuarioActual?.photoURL ?? resenaExistente?.fotoUsuario,
                              comentario: comentarioTexto,
                              calificacion: calificacionSeleccionada,
                              fecha: DateTime.now(),
                            );

                            final navigator = Navigator.of(dialogContext);

                            if (esEdicion && resenaExistente.id != null) {
                              await _lugaresService.actualizarResena(
                                widget.lugar.id,
                                resenaExistente.id!,
                                nuevaResena,
                              );
                            } else {
                              await _lugaresService.crearResena(
                                widget.lugar.id,
                                nuevaResena,
                              );
                            }

                            if (mounted) {
                              navigator.pop();
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    esEdicion
                                        ? '¡Reseña actualizada con éxito!'
                                        : '¡Reseña publicada con éxito!',
                                  ),
                                ),
                              );
                              _cargarResenas();
                            }
                          } catch (e) {
                            setDialogState(() => guardando = false);
                            if (mounted) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('Error al guardar la reseña: $e'),
                                ),
                              );
                            }
                          }
                        },
                  child: guardando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(esEdicion ? 'Actualizar' : 'Publicar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// HU-16: Diálogo de confirmación para eliminar reseña.
  void _confirmarEliminarResena(Resena resena) {
    if (resena.id == null) return;
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        bool eliminando = false;
        return StatefulBuilder(
          builder: (builderContext, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text('Eliminar reseña'),
              content: const Text(
                '¿Estás seguro de que deseas eliminar esta reseña? Esta acción no se puede deshacer.',
              ),
              actions: [
                TextButton(
                  onPressed: eliminando
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                  ),
                  onPressed: eliminando
                      ? null
                      : () async {
                          final navigator = Navigator.of(dialogContext);
                          setDialogState(() => eliminando = true);
                          try {
                            await _lugaresService.eliminarResena(
                              widget.lugar.id,
                              resena.id!,
                            );
                            if (mounted) {
                              navigator.pop();
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Reseña eliminada correctamente.'),
                                ),
                              );
                              _cargarResenas();
                            }
                          } catch (e) {
                            setDialogState(() => eliminando = false);
                            if (mounted) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('Error al eliminar la reseña: $e'),
                                ),
                              );
                            }
                          }
                        },
                  child: eliminando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Eliminar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: Text(widget.lugar.nombre)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImagenPrincipal(),
            const SizedBox(height: 20),
            Text(widget.lugar.nombre, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildUbicacion(),
            const SizedBox(height: 24),
            const Text('Descripción', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(widget.lugar.descripcion, style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.black)),
            const Divider(height: 60),
            
            // --- SECCIÓN DE RESEÑAS ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Reseñas de viajeros', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                TextButton.icon(
                  onPressed: () => _mostrarFormularioResena(),
                  icon: const Icon(Icons.rate_review_outlined, color: AppTheme.verdeAzulado),
                  label: const Text(
                    'Escribir',
                    style: TextStyle(color: AppTheme.verdeAzulado, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (_cargandoResenas)
              const Center(child: CircularProgressIndicator())
            else if (_resenas.isEmpty)
              const Text('Este lugar aún no tiene reseñas.', style: TextStyle(color: Colors.grey))
            else
              _buildListaResenas(),
          ],
        ),
      ),
    );
  }

  Widget _buildListaResenas() {
    final String? uidActual = _auth.currentUser?.uid;

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _resenas.length,
      itemBuilder: (context, index) {
        final r = _resenas[index];
        final bool esPropietario = uidActual != null && r.usuarioId == uidActual;

        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.black12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Foto y nombre del autor: al tocarlos se abre su perfil.
                  Flexible(
                    child: GestureDetector(
                      key: const Key('resena-autor'),
                      onTap: () => abrirPerfilUsuario(context, r.usuarioId),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: AppTheme.azulPetroleo,
                            foregroundImage: (r.fotoUsuario ?? '').isEmpty ? null : NetworkImage(r.fotoUsuario!),
                            onForegroundImageError: (r.fotoUsuario ?? '').isEmpty ? null : (_, _) {},
                            child: Text(
                              r.nombreUsuario.isEmpty ? '?' : r.nombreUsuario.characters.first.toUpperCase(),
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              r.nombreUsuario,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.azulPetroleo),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    children: List.generate(5, (i) => Icon(
                      Icons.star_rounded, 
                      size: 20, // Más grandes
                      color: i < r.calificacion ? Colors.orange : Colors.grey.shade300,
                    )),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // COMENTARIO FORZADO EN COLOR NEGRO
              Text(
                r.comentario, 
                style: const TextStyle(fontSize: 15, color: Colors.black, height: 1.4),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "${r.fecha.day}/${r.fecha.month}/${r.fecha.year}",
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  // HU-15 y HU-16: Botones para editar y borrar (visibles ÚNICAMENTE para el creador de la reseña)
                  if (esPropietario)
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.verdeAzulado),
                          onPressed: () => _mostrarFormularioResena(resenaExistente: r),
                          tooltip: 'Editar reseña',
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(4),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                          onPressed: () => _confirmarEliminarResena(r),
                          tooltip: 'Eliminar reseña',
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(4),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildImagenPrincipal() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: widget.lugar.fotos.isNotEmpty 
        ? Image.network(widget.lugar.fotos.first, height: 250, width: double.infinity, fit: BoxFit.cover)
        : Container(height: 250, color: Colors.grey.shade200, child: const Icon(Icons.image_not_supported, size: 64)),
    );
  }

  Widget _buildUbicacion() {
    return Row(children: [const Icon(Icons.location_on, color: AppTheme.verdeAzulado, size: 18), const SizedBox(width: 4), Expanded(child: Text(widget.lugar.ubicacion, style: const TextStyle(color: Colors.grey)))]);
  }
}
