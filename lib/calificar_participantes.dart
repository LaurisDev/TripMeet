import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'calificacion_usuario_service.dart';
import 'evento_detalle_screen.dart' show CargarPerfil;
import 'evento_service.dart';
import 'form_styles.dart';
import 'perfil_usuario_screen.dart' show AvatarUsuario, PerfilPublico;
import 'widgets/calificacion_estrellas.dart';

/// Sección del detalle de un evento finalizado (HU-28): lista a quienes
/// participaron con el usuario (organizador e inscritos, sin él mismo) y le
/// permite calificar a cada uno de 1 a 5 estrellas, una vez por evento.
///
/// Solo se muestra si [uidUsuarioActual] participó en [evento]; el servicio
/// vuelve a validarlo todo antes de guardar.
class CalificarParticipantes extends StatefulWidget {
  const CalificarParticipantes({
    required this.evento,
    required this.uidUsuarioActual,
    required this.cargarPerfil,
    this.service,
    super.key,
  });

  final Evento evento;
  final String uidUsuarioActual;
  final CargarPerfil cargarPerfil;

  /// Servicio de calificaciones (inyectable en pruebas).
  final CalificacionUsuarioService? service;

  /// Personas que [uid] puede calificar en [evento]: los demás
  /// participantes. Vacío si [uid] no participó.
  static List<String> calificables(Evento evento, String uid) {
    final Set<String> participantes = CalificacionUsuarioService.participantes(
      evento,
    );
    if (!participantes.contains(uid)) return const <String>[];
    return <String>[
      for (final String otro in participantes)
        if (otro != uid) otro,
    ];
  }

  @override
  State<CalificarParticipantes> createState() => _CalificarParticipantesState();
}

class _CalificarParticipantesState extends State<CalificarParticipantes> {
  late final CalificacionUsuarioService? _service = _crearServicio();
  late List<String> _candidatos;
  late Future<List<Map<String, dynamic>?>> _perfiles;

  /// Personas que el usuario ya calificó por este evento.
  Set<String> _calificados = <String>{};

  /// Persona cuya calificación se está guardando.
  String? _guardando;

  CalificacionUsuarioService? _crearServicio() {
    final CalificacionUsuarioService? inyectado = widget.service;
    if (inyectado != null) return inyectado;
    try {
      return CalificacionUsuarioService();
    } catch (_) {
      // Firebase sin inicializar (pruebas de otras pantallas).
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void didUpdateWidget(CalificarParticipantes anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.evento.inscritos != widget.evento.inscritos ||
        anterior.evento.creadorUid != widget.evento.creadorUid) {
      _cargar();
    }
  }

  void _cargar() {
    _candidatos = CalificarParticipantes.calificables(
      widget.evento,
      widget.uidUsuarioActual,
    );
    _perfiles = Future.wait(_candidatos.map(widget.cargarPerfil));
    _cargarCalificados();
  }

  Future<void> _cargarCalificados() async {
    final CalificacionUsuarioService? servicio = _service;
    if (servicio == null || _candidatos.isEmpty) return;
    final Set<String> calificados = await servicio.calificadosPorMi(
      eventoId: widget.evento.id,
      candidatos: _candidatos,
    );
    if (mounted) setState(() => _calificados = calificados);
  }

  Future<void> _calificar(String uid, String nombre) async {
    if (_guardando != null) return;

    final bool? publicada = await mostrarDialogoResena(
      context,
      nombre: nombre,
      onPublicar: (ResenaEscrita resena) => _publicar(uid, resena),
    );
    if (publicada == true && mounted) {
      _avisar('Publicaste tu reseña sobre $nombre.');
    }
  }

  /// Guarda la reseña (el servicio la modera antes). Devuelve `null` si se
  /// publicó o el mensaje de error, que el diálogo muestra sin cerrarse.
  Future<String?> _publicar(String uid, ResenaEscrita resena) async {
    final CalificacionUsuarioService? servicio = _service;
    if (servicio == null) {
      return 'No se pudo publicar la reseña. Inténtalo de nuevo.';
    }

    setState(() => _guardando = uid);
    try {
      await servicio.calificarUsuario(
        eventoId: widget.evento.id,
        calificadoUid: uid,
        calificacion: resena.estrellas,
        comentario: resena.comentario,
      );
      if (mounted) {
        setState(() => _calificados = <String>{..._calificados, uid});
      }
      return null;
    } on CalificacionException catch (error) {
      if (mounted && error.code == 'ya-calificado') {
        setState(() => _calificados = <String>{..._calificados, uid});
      }
      return error.message;
    } finally {
      if (mounted) setState(() => _guardando = null);
    }
  }

  void _avisar(String mensaje) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensaje)));
  }

  @override
  Widget build(BuildContext context) {
    if (_candidatos.isEmpty) return const SizedBox.shrink();

    return Column(
      key: const Key('calificar-participantes'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Califica a quienes compartieron este evento',
          style: FormStyles.etiqueta(),
        ),
        const SizedBox(height: FormStyles.s8),
        FutureBuilder<List<Map<String, dynamic>?>>(
          future: _perfiles,
          builder:
              (
                BuildContext context,
                AsyncSnapshot<List<Map<String, dynamic>?>> snapshot,
              ) {
                final List<Map<String, dynamic>?>? perfiles = snapshot.data;
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(FormStyles.radio),
                    border: Border.all(color: FormStyles.colorBorde),
                  ),
                  child: Column(
                    children: <Widget>[
                      for (int i = 0; i < _candidatos.length; i++) ...<Widget>[
                        if (i > 0)
                          const Divider(
                            height: 1,
                            color: FormStyles.colorBorde,
                          ),
                        _FilaCalificable(
                          uid: _candidatos[i],
                          perfil: PerfilPublico(
                            perfiles == null ? null : perfiles[i],
                          ),
                          esOrganizador:
                              _candidatos[i] == widget.evento.creadorUid,
                          calificado: _calificados.contains(_candidatos[i]),
                          guardando: _guardando == _candidatos[i],
                          onCalificar: _calificar,
                        ),
                      ],
                    ],
                  ),
                );
              },
        ),
      ],
    );
  }
}

class _FilaCalificable extends StatelessWidget {
  const _FilaCalificable({
    required this.uid,
    required this.perfil,
    required this.esOrganizador,
    required this.calificado,
    required this.guardando,
    required this.onCalificar,
  });

  final String uid;
  final PerfilPublico perfil;
  final bool esOrganizador;
  final bool calificado;
  final bool guardando;
  final void Function(String uid, String nombre) onCalificar;

  @override
  Widget build(BuildContext context) {
    final Widget accion;
    if (calificado) {
      accion = Row(
        key: Key('calificado-$uid'),
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Icons.check_circle_rounded,
            size: 18,
            color: AppTheme.verdeAzulado,
          ),
          const SizedBox(width: FormStyles.s4),
          Text('Calificado', style: FormStyles.cuerpo(size: 13)),
        ],
      );
    } else if (guardando) {
      accion = const SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else {
      accion = TextButton.icon(
        key: Key('calificar-$uid'),
        onPressed: () => onCalificar(uid, perfil.nombre),
        icon: const Icon(Icons.star_outline_rounded, color: colorEstrella),
        label: const Text('Calificar'),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: FormStyles.s12,
        vertical: FormStyles.s8,
      ),
      child: Row(
        children: <Widget>[
          AvatarUsuario(perfil: perfil, radio: 18),
          const SizedBox(width: FormStyles.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  perfil.nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FormStyles.cuerpo(
                    weight: FontWeight.w600,
                    color: AppTheme.azulPetroleo,
                  ),
                ),
                if (esOrganizador)
                  Text('Organizador', style: FormStyles.cuerpo(size: 12)),
              ],
            ),
          ),
          const SizedBox(width: FormStyles.s8),
          accion,
        ],
      ),
    );
  }
}
