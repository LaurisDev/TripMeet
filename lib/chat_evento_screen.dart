import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'cloudinary_service.dart';
import 'evento_service.dart';
import 'form_styles.dart';
import 'guia_service.dart' show ArchivoLocal;
import 'widgets/archivo_picker.dart';

/// Modelo de datos para las opciones de una encuesta en el chat.
class OpcionEncuesta {
  const OpcionEncuesta({
    required this.texto,
    this.votosUids = const <String>[],
  });

  final String texto;
  final List<String> votosUids;

  factory OpcionEncuesta.fromMap(Map<String, dynamic> map) {
    return OpcionEncuesta(
      texto: map['texto'] as String? ?? '',
      votosUids: (map['votosUids'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          const <String>[],
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'texto': texto,
      'votosUids': votosUids,
    };
  }
}

/// Modelo de datos para los mensajes del chat exclusivo de un evento.
class MensajeEvento {
  const MensajeEvento({
    required this.id,
    required this.eventoId,
    required this.usuarioId,
    required this.nombreUsuario,
    this.fotoUsuario,
    required this.texto,
    required this.fecha,
    this.imagenUrl,
    this.editado = false,
    this.fijado = false,
    this.esEncuesta = false,
    this.preguntaEncuesta,
    this.opcionesEncuesta = const <OpcionEncuesta>[],
    this.reacciones = const <String, List<String>>{},
  });

  final String id;
  final String eventoId;
  final String usuarioId;
  final String nombreUsuario;
  final String? fotoUsuario;
  final String texto;
  final DateTime fecha;
  final String? imagenUrl;
  final bool editado;
  final bool fijado;

  // Encuestas
  final bool esEncuesta;
  final String? preguntaEncuesta;
  final List<OpcionEncuesta> opcionesEncuesta;

  // Reacciones { "❤️": ["uid1", "uid2"], "👍": ["uid3"] }
  final Map<String, List<String>> reacciones;

  factory MensajeEvento.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
    String eventoId,
  ) {
    final Map<String, dynamic> datos = doc.data() ?? <String, dynamic>{};

    final List<dynamic>? opcionesRaw =
        datos['opcionesEncuesta'] as List<dynamic>?;
    final List<OpcionEncuesta> opciones = opcionesRaw != null
        ? opcionesRaw
            .whereType<Map<String, dynamic>>()
            .map(OpcionEncuesta.fromMap)
            .toList()
        : const <OpcionEncuesta>[];

    final Map<String, dynamic>? reaccionesRaw =
        datos['reacciones'] as Map<String, dynamic>?;
    final Map<String, List<String>> reaccionesMap = <String, List<String>>{};
    if (reaccionesRaw != null) {
      reaccionesRaw.forEach((String key, dynamic value) {
        if (value is List) {
          reaccionesMap[key] = value.whereType<String>().toList();
        }
      });
    }

    return MensajeEvento(
      id: doc.id,
      eventoId: eventoId,
      usuarioId: datos['usuarioId'] as String? ?? '',
      nombreUsuario: datos['nombreUsuario'] as String? ?? 'Viajero',
      fotoUsuario: datos['fotoUsuario'] as String?,
      texto: datos['texto'] as String? ?? '',
      fecha: (datos['fecha'] as Timestamp?)?.toDate() ?? DateTime.now(),
      imagenUrl: datos['imagenUrl'] as String?,
      editado: datos['editado'] as bool? ?? false,
      fijado: datos['fijado'] as bool? ?? false,
      esEncuesta: datos['esEncuesta'] as bool? ?? false,
      preguntaEncuesta: datos['preguntaEncuesta'] as String?,
      opcionesEncuesta: opciones,
      reacciones: reaccionesMap,
    );
  }

  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'usuarioId': usuarioId,
      'nombreUsuario': nombreUsuario,
      if (fotoUsuario != null) 'fotoUsuario': fotoUsuario,
      'texto': texto,
      'fecha': Timestamp.fromDate(fecha),
      if (imagenUrl != null) 'imagenUrl': imagenUrl,
      'editado': editado,
      'fijado': fijado,
      'esEncuesta': esEncuesta,
      if (preguntaEncuesta != null) 'preguntaEncuesta': preguntaEncuesta,
      if (esEncuesta)
        'opcionesEncuesta': opcionesEncuesta.map((op) => op.toMap()).toList(),
      'reacciones': reacciones,
    };
  }
}

/// Pantalla moderna, completa e innovadora de Chat para los asistentes a un Evento.
class ChatEventoScreen extends StatefulWidget {
  const ChatEventoScreen({
    required this.evento,
    this.firestore,
    this.auth,
    this.cloudinary,
    super.key,
  });

  final Evento evento;
  final FirebaseFirestore? firestore;
  final FirebaseAuth? auth;
  final CloudinaryService? cloudinary;

  @override
  State<ChatEventoScreen> createState() => _ChatEventoScreenState();
}

class _ChatEventoScreenState extends State<ChatEventoScreen> {
  late final FirebaseFirestore _firestore =
      widget.firestore ?? FirebaseFirestore.instance;
  late final FirebaseAuth _auth = widget.auth ?? FirebaseAuth.instance;
  late final CloudinaryService _cloudinary =
      widget.cloudinary ?? CloudinaryService();

  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _enviando = false;
  bool _subiendoFoto = false;

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Stream en tiempo real de mensajes del evento en Firestore.
  Stream<List<MensajeEvento>> _obtenerStreamMensajes() {
    return _firestore
        .collection('eventos')
        .doc(widget.evento.id)
        .collection('mensajes')
        .orderBy('fecha', descending: false)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
      return snapshot.docs
          .map((doc) => MensajeEvento.fromFirestore(doc, widget.evento.id))
          .toList();
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Envía un mensaje de texto.
  Future<void> _enviarMensaje([String? textoPersonalizado]) async {
    final String texto = (textoPersonalizado ?? _textController.text).trim();

    if (texto.isEmpty || _enviando) return;

    final User? usuario = _auth.currentUser;
    if (usuario == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes iniciar sesión para participar en el chat.'),
        ),
      );
      return;
    }

    _textController.clear();
    setState(() => _enviando = true);

    try {
      final String nombre = usuario.displayName ??
          (usuario.email?.split('@').first) ??
          'Viajero';

      final MensajeEvento nuevoMensaje = MensajeEvento(
        id: '',
        eventoId: widget.evento.id,
        usuarioId: usuario.uid,
        nombreUsuario: nombre,
        fotoUsuario: usuario.photoURL,
        texto: texto,
        fecha: DateTime.now(),
      );

      await _firestore
          .collection('eventos')
          .doc(widget.evento.id)
          .collection('mensajes')
          .add(nuevoMensaje.toFirestore());

      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo enviar el mensaje: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  /// Permite seleccionar y enviar una fotografía al chat del evento.
  Future<void> _adjuntarFoto() async {
    final List<ArchivoLocal> seleccionados = await seleccionarArchivos(
      extensiones: const <String>['jpg', 'jpeg', 'png', 'webp'],
    );

    if (seleccionados.isEmpty) return;
    final ArchivoLocal archivo = seleccionados.first;
    final Uint8List bytes = archivo.bytes;

    if (bytes.isEmpty) return;

    final User? usuario = _auth.currentUser;
    if (usuario == null) return;

    setState(() => _subiendoFoto = true);

    try {
      final CloudinarySubida subida = await _cloudinary.subirImagen(
        bytes: bytes,
        nombreArchivo: archivo.nombre,
        folder: 'tripmeet/chat_eventos',
      );

      final String nombre = usuario.displayName ??
          (usuario.email?.split('@').first) ??
          'Viajero';

      final MensajeEvento mensajeFoto = MensajeEvento(
        id: '',
        eventoId: widget.evento.id,
        usuarioId: usuario.uid,
        nombreUsuario: nombre,
        fotoUsuario: usuario.photoURL,
        texto: '📷 Fotografía enviada',
        imagenUrl: subida.secureUrl,
        fecha: DateTime.now(),
      );

      await _firestore
          .collection('eventos')
          .doc(widget.evento.id)
          .collection('mensajes')
          .add(mensajeFoto.toFirestore());

      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al subir la imagen: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _subiendoFoto = false);
    }
  }

  /// Diálogo para crear una nueva Encuesta interactiva en el grupo.
  void _mostrarDialogoCrearEncuesta() {
    final TextEditingController preguntaController = TextEditingController();
    final List<TextEditingController> opcionesControllers = <TextEditingController>[
      TextEditingController(),
      TextEditingController(),
    ];

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(FormStyles.radio),
              ),
              title: const Row(
                children: <Widget>[
                  Icon(Icons.poll_rounded, color: AppTheme.verdeAzulado),
                  SizedBox(width: 8),
                  Text('Crear Encuesta'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextField(
                      controller: preguntaController,
                      decoration: const InputDecoration(
                        labelText: 'Pregunta de la encuesta',
                        hintText: 'Ej: ¿A qué hora nos vemos?',
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...List.generate(opcionesControllers.length, (int index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: TextField(
                          controller: opcionesControllers[index],
                          decoration: InputDecoration(
                            labelText: 'Opción ${index + 1}',
                            hintText: 'Escribe la opción',
                          ),
                        ),
                      );
                    }),
                    if (opcionesControllers.length < 4)
                      TextButton.icon(
                        onPressed: () {
                          setDialogState(() {
                            opcionesControllers.add(TextEditingController());
                          });
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Agregar otra opción'),
                      ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.azulPetroleo,
                  ),
                  onPressed: () async {
                    final String pregunta = preguntaController.text.trim();
                    final List<OpcionEncuesta> opciones = opcionesControllers
                        .map((c) => OpcionEncuesta(texto: c.text.trim()))
                        .where((op) => op.texto.isNotEmpty)
                        .toList();

                    if (pregunta.isEmpty || opciones.length < 2) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Ingresa una pregunta y al menos 2 opciones.',
                          ),
                        ),
                      );
                      return;
                    }

                    final User? usuario = _auth.currentUser;
                    if (usuario == null) return;

                    final String nombre = usuario.displayName ??
                        (usuario.email?.split('@').first) ??
                        'Viajero';

                    final MensajeEvento mensajeEncuesta = MensajeEvento(
                      id: '',
                      eventoId: widget.evento.id,
                      usuarioId: usuario.uid,
                      nombreUsuario: nombre,
                      texto: '📊 Encuesta: $pregunta',
                      fecha: DateTime.now(),
                      esEncuesta: true,
                      preguntaEncuesta: pregunta,
                      opcionesEncuesta: opciones,
                    );

                    await _firestore
                        .collection('eventos')
                        .doc(widget.evento.id)
                        .collection('mensajes')
                        .add(mensajeEncuesta.toFirestore());

                    if (mounted) {
                      Navigator.of(dialogContext).pop();
                      _scrollToBottom();
                    }
                  },
                  child: const Text('Publicar encuesta'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Permite a los usuarios votar en una encuesta.
  Future<void> _votarEncuesta(
    MensajeEvento mensaje,
    int opcionIndex,
  ) async {
    final User? usuario = _auth.currentUser;
    if (usuario == null) return;

    final List<OpcionEncuesta> nuevasOpciones = <OpcionEncuesta>[];
    for (int i = 0; i < mensaje.opcionesEncuesta.length; i++) {
      final OpcionEncuesta op = mensaje.opcionesEncuesta[i];
      final List<String> nuevosVotos = List<String>.from(op.votosUids);

      if (i == opcionIndex) {
        if (!nuevosVotos.contains(usuario.uid)) {
          nuevosVotos.add(usuario.uid);
        }
      } else {
        nuevosVotos.remove(usuario.uid);
      }
      nuevasOpciones.add(
        OpcionEncuesta(texto: op.texto, votosUids: nuevosVotos),
      );
    }

    await _firestore
        .collection('eventos')
        .doc(widget.evento.id)
        .collection('mensajes')
        .doc(mensaje.id)
        .update(<String, dynamic>{
      'opcionesEncuesta': nuevasOpciones.map((op) => op.toMap()).toList(),
    });
  }

  /// Permite editar un mensaje propio.
  void _editarMensaje(MensajeEvento mensaje) {
    final TextEditingController editController =
        TextEditingController(text: mensaje.texto);

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Editar mensaje'),
          content: TextField(
            controller: editController,
            maxLines: null,
            decoration: const InputDecoration(
              labelText: 'Mensaje',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final String nuevoTexto = editController.text.trim();
                if (nuevoTexto.isEmpty) return;

                await _firestore
                    .collection('eventos')
                    .doc(widget.evento.id)
                    .collection('mensajes')
                    .doc(mensaje.id)
                    .update(<String, dynamic>{
                  'texto': nuevoTexto,
                  'editado': true,
                });

                if (mounted) Navigator.of(dialogContext).pop();
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  /// Permite eliminar un mensaje propio.
  Future<void> _eliminarMensaje(MensajeEvento mensaje) async {
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Eliminar mensaje'),
        content: const Text(
          '¿Estás seguro de que deseas eliminar este mensaje?',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await _firestore
          .collection('eventos')
          .doc(widget.evento.id)
          .collection('mensajes')
          .doc(mensaje.id)
          .delete();
    }
  }

  /// Fijar/Desfijar anuncio importante del organizador.
  Future<void> _alternarFijarMensaje(MensajeEvento mensaje) async {
    await _firestore
        .collection('eventos')
        .doc(widget.evento.id)
        .collection('mensajes')
        .doc(mensaje.id)
        .update(<String, dynamic>{'fijado': !mensaje.fijado});
  }

  /// Reaccionar a un mensaje con emoji.
  Future<void> _reaccionarMensaje(
    MensajeEvento mensaje,
    String emoji,
  ) async {
    final User? usuario = _auth.currentUser;
    if (usuario == null) return;

    final Map<String, List<String>> reacciones =
        Map<String, List<String>>.from(mensaje.reacciones);

    final List<String> usuariosEmoji =
        List<String>.from(reacciones[emoji] ?? <String>[]);

    if (usuariosEmoji.contains(usuario.uid)) {
      usuariosEmoji.remove(usuario.uid);
      if (usuariosEmoji.isEmpty) {
        reacciones.remove(emoji);
      } else {
        reacciones[emoji] = usuariosEmoji;
      }
    } else {
      usuariosEmoji.add(usuario.uid);
      reacciones[emoji] = usuariosEmoji;
    }

    await _firestore
        .collection('eventos')
        .doc(widget.evento.id)
        .collection('mensajes')
        .doc(mensaje.id)
        .update(<String, dynamic>{'reacciones': reacciones});
  }

  @override
  Widget build(BuildContext context) {
    final String? usuarioActualUid = _auth.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppTheme.crema,
      appBar: AppBar(
        backgroundColor: AppTheme.crema,
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.verdeAzulado.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_rounded,
                color: AppTheme.verdeAzulado,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    widget.evento.nombre,
                    style: FormStyles.titulo(pequena: true),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: <Widget>[
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Chat del evento · En vivo',
                        style: FormStyles.cuerpo(
                          size: 11,
                          color: AppTheme.textoSuave,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.poll_rounded, color: AppTheme.azulPetroleo),
            tooltip: 'Crear encuesta',
            onPressed: _mostrarDialogoCrearEncuesta,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            // Banner informativo del evento
            Container(
              margin: const EdgeInsets.symmetric(
                horizontal: FormStyles.s16,
                vertical: FormStyles.s8,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: FormStyles.s12,
                vertical: FormStyles.s8,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(FormStyles.radio),
                border: Border.all(
                  color: AppTheme.verdeAzulado.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.place_outlined,
                    size: 16,
                    color: AppTheme.verdeAzulado,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Punto de encuentro: ${widget.evento.lugar}',
                      style: FormStyles.cuerpo(
                        size: 12,
                        weight: FontWeight.w600,
                        color: AppTheme.azulPetroleo,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // Stream en tiempo real de mensajes
            Expanded(
              child: StreamBuilder<List<MensajeEvento>>(
                stream: _obtenerStreamMensajes(),
                builder: (
                  BuildContext context,
                  AsyncSnapshot<List<MensajeEvento>> snapshot,
                ) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.verdeAzulado,
                      ),
                    );
                  }

                  final List<MensajeEvento> mensajes =
                      snapshot.data ?? <MensajeEvento>[];

                  final MensajeEvento? mensajeFijado = mensajes
                      .where((m) => m.fijado)
                      .lastOrNull;

                  if (mensajes.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(FormStyles.s24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.verdeAzulado.withValues(
                                  alpha: 0.1,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.forum_outlined,
                                size: 48,
                                color: AppTheme.verdeAzulado,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '¡Sé el primero en escribir!',
                              style: FormStyles.titulo(pequena: true),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Coordina detalles, hora de encuentro, fotos y encuestas con los demás asistentes.',
                              textAlign: TextAlign.center,
                              style: FormStyles.ayuda(),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  _scrollToBottom();

                  return Column(
                    children: <Widget>[
                      if (mensajeFijado != null)
                        _buildBannerMensajeFijado(mensajeFijado),
                      Expanded(
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(
                            horizontal: FormStyles.s16,
                            vertical: FormStyles.s8,
                          ),
                          itemCount: mensajes.length,
                          itemBuilder: (BuildContext context, int index) {
                            final MensajeEvento msg = mensajes[index];
                            final bool esPropio = usuarioActualUid != null &&
                                msg.usuarioId == usuarioActualUid;
                            final bool esOrganizador = usuarioActualUid != null &&
                                widget.evento.creadorUid == usuarioActualUid;

                            return _BurbujaMensaje(
                              mensaje: msg,
                              esPropio: esPropio,
                              esOrganizador: esOrganizador,
                              uidActual: usuarioActualUid,
                              onEditar: () => _editarMensaje(msg),
                              onEliminar: () => _eliminarMensaje(msg),
                              onFijar: () => _alternarFijarMensaje(msg),
                              onReaccionar: (emoji) =>
                                  _reaccionarMensaje(msg, emoji),
                              onVotarEncuesta: (opIndex) =>
                                  _votarEncuesta(msg, opIndex),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            if (_subiendoFoto)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Subiendo fotografía...',
                      style: TextStyle(fontSize: 12, color: AppTheme.textoSuave),
                    ),
                  ],
                ),
              ),

            _buildSugerenciasRapidas(),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildBannerMensajeFijado(MensajeEvento mensaje) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: FormStyles.s16,
        vertical: 4,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: FormStyles.s12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: AppTheme.naranjaQuemado.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(FormStyles.radio),
        border: Border.all(
          color: AppTheme.naranjaQuemado.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.push_pin_rounded,
            size: 16,
            color: AppTheme.naranjaQuemado,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Anuncio fijado por ${mensaje.nombreUsuario}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.naranjaQuemado,
                  ),
                ),
                Text(
                  mensaje.texto,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppTheme.azulPetroleo,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSugerenciasRapidas() {
    if (_enviando) return const SizedBox.shrink();

    final List<Map<String, String>> sugerencias = <Map<String, String>>[
      <String, String>{
        'label': '📍 ¿Lugar de encuentro?',
        'texto': 'Hola, ¿dónde nos encontramos exactamente?',
      },
      <String, String>{
        'label': '⏰ ¿A qué hora nos vemos?',
        'texto': '¡Hola! ¿A qué hora nos encontramos?',
      },
      <String, String>{
        'label': '🎒 ¿Qué debemos llevar?',
        'texto': '¿Qué recomiendan llevar para la actividad?',
      },
      <String, String>{
        'label': '👋 ¡Ya voy en camino!',
        'texto': '¡Hola a todos! Ya voy en camino al evento.',
      },
    ];

    return Container(
      height: 38,
      margin: const EdgeInsets.only(bottom: 6),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: FormStyles.s16),
        scrollDirection: Axis.horizontal,
        itemCount: sugerencias.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int index) {
          final Map<String, String> item = sugerencias[index];
          return ActionChip(
            label: Text(
              item['label']!,
              style: const TextStyle(
                color: AppTheme.azulPetroleo,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: AppTheme.verdeAzulado.withValues(alpha: 0.3),
              ),
            ),
            onPressed: () => _enviarMensaje(item['texto']),
          );
        },
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          IconButton(
            icon: const Icon(
              Icons.photo_camera_rounded,
              color: AppTheme.verdeAzulado,
            ),
            tooltip: 'Enviar foto',
            onPressed: _subiendoFoto ? null : _adjuntarFoto,
          ),
          Expanded(
            child: TextField(
              controller: _textController,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _enviarMensaje(),
              enabled: !_enviando,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              decoration: InputDecoration(
                hintText: 'Escribe un mensaje al grupo...',
                hintStyle: TextStyle(
                  color: AppTheme.textoSuave.withValues(alpha: 0.6),
                  fontSize: 14,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                filled: true,
                fillColor: AppTheme.crema,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(
                    color: AppTheme.verdeSuave.withValues(alpha: 0.3),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(
                    color: AppTheme.verdeAzulado,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Material(
            color: _enviando ? AppTheme.verdeSuave : AppTheme.azulPetroleo,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _enviando ? null : () => _enviarMensaje(),
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Burbuja estilizada de mensaje para la lista de chat con reacciones, encuestas y fotos.
class _BurbujaMensaje extends StatelessWidget {
  const _BurbujaMensaje({
    required this.mensaje,
    required this.esPropio,
    required this.esOrganizador,
    required this.uidActual,
    required this.onEditar,
    required this.onEliminar,
    required this.onFijar,
    required this.onReaccionar,
    required this.onVotarEncuesta,
  });

  final MensajeEvento mensaje;
  final bool esPropio;
  final bool esOrganizador;
  final String? uidActual;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;
  final VoidCallback onFijar;
  final ValueChanged<String> onReaccionar;
  final ValueChanged<int> onVotarEncuesta;

  String _formatearHora(DateTime fecha) {
    final String hora = fecha.hour.toString().padLeft(2, '0');
    final String minuto = fecha.minute.toString().padLeft(2, '0');
    return '$hora:$minuto';
  }

  void _mostrarOpcionesMensaje(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // Tira de reacciones rápidas con Emojis
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <String>['👍', '❤️', '🔥', '😂', '😮'].map((
                    String emoji,
                  ) {
                    return InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        onReaccionar(emoji);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: AppTheme.crema,
                          shape: BoxShape.circle,
                        ),
                        child: Text(emoji, style: const TextStyle(fontSize: 22)),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const Divider(),
              if (esPropio && !mensaje.esEncuesta)
                ListTile(
                  leading: const Icon(
                    Icons.edit_outlined,
                    color: AppTheme.verdeAzulado,
                  ),
                  title: const Text('Editar mensaje'),
                  onTap: () {
                    Navigator.pop(context);
                    onEditar();
                  },
                ),
              if (esPropio)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('Eliminar mensaje'),
                  onTap: () {
                    Navigator.pop(context);
                    onEliminar();
                  },
                ),
              if (esOrganizador)
                ListTile(
                  leading: Icon(
                    mensaje.fijado
                        ? Icons.push_pin_outlined
                        : Icons.push_pin_rounded,
                    color: AppTheme.naranjaQuemado,
                  ),
                  title: Text(
                    mensaje.fijado ? 'Desfijar anuncio' : 'Fijar como anuncio',
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    onFijar();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final String? fotoUrl = mensaje.imagenUrl;

    return GestureDetector(
      onLongPress: () => _mostrarOpcionesMensaje(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment:
              esPropio ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: <Widget>[
            if (!esPropio) ...<Widget>[
              CircleAvatar(
                radius: 14,
                backgroundColor: AppTheme.verdeAzulado,
                child: Text(
                  mensaje.nombreUsuario.isNotEmpty
                      ? mensaje.nombreUsuario[0].toUpperCase()
                      : 'V',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Container(
                margin: EdgeInsets.only(
                  left: esPropio ? 48 : 0,
                  right: esPropio ? 4 : 48,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: esPropio ? AppTheme.azulPetroleo : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(esPropio ? 16 : 4),
                    bottomRight: Radius.circular(esPropio ? 4 : 16),
                  ),
                  border: esPropio
                      ? null
                      : Border.all(
                          color: AppTheme.verdeAzulado.withValues(alpha: 0.15),
                        ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (!esPropio) ...<Widget>[
                      Text(
                        mensaje.nombreUsuario,
                        style: const TextStyle(
                          color: AppTheme.verdeAzulado,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                    ],

                    // Fotografía en el chat
                    if (fotoUrl != null) ...<Widget>[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          constraints: const BoxConstraints(maxHeight: 220),
                          child: Image.network(
                            fotoUrl,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            loadingBuilder: (BuildContext context, Widget child,
                                ImageChunkEvent? progress) {
                              if (progress == null) return child;
                              return Container(
                                height: 150,
                                color: AppTheme.crema,
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],

                    // Encuesta interactiva
                    if (mensaje.esEncuesta) ...<Widget>[
                      _buildWidgetEncuesta(context),
                    ] else ...<Widget>[
                      Text(
                        mensaje.texto,
                        style: TextStyle(
                          color: esPropio ? Colors.white : AppTheme.azulPetroleo,
                          fontSize: 14,
                          height: 1.3,
                        ),
                      ),
                    ],

                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          _formatearHora(mensaje.fecha),
                          style: TextStyle(
                            color: esPropio
                                ? Colors.white.withValues(alpha: 0.7)
                                : AppTheme.textoSuave.withValues(alpha: 0.6),
                            fontSize: 10,
                          ),
                        ),
                        if (mensaje.editado) ...<Widget>[
                          const SizedBox(width: 4),
                          Text(
                            '(editado)',
                            style: TextStyle(
                              color: esPropio
                                  ? Colors.white.withValues(alpha: 0.7)
                                  : AppTheme.textoSuave.withValues(alpha: 0.6),
                              fontSize: 9,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),

                    // Badge de reacciones con Emojis
                    if (mensaje.reacciones.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: mensaje.reacciones.entries.map((
                          MapEntry<String, List<String>> entry,
                        ) {
                          final bool yaVoto = uidActual != null &&
                              entry.value.contains(uidActual);
                          return InkWell(
                            onTap: () => onReaccionar(entry.key),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: yaVoto
                                    ? AppTheme.verdeAzulado.withValues(
                                        alpha: 0.2,
                                      )
                                    : Colors.grey.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${entry.key} ${entry.value.length}',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Renderiza el widget interactivo de Encuestas dentro de la burbuja.
  Widget _buildWidgetEncuesta(BuildContext context) {
    int totalVotos = 0;
    for (final OpcionEncuesta op in mensaje.opcionesEncuesta) {
      totalVotos += op.votosUids.length;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          mensaje.preguntaEncuesta ?? 'Encuesta del grupo',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: esPropio ? Colors.white : AppTheme.azulPetroleo,
            fontSize: 14.5,
          ),
        ),
        const SizedBox(height: 8),
        ...List.generate(mensaje.opcionesEncuesta.length, (int index) {
          final OpcionEncuesta op = mensaje.opcionesEncuesta[index];
          final bool yaVoto =
              uidActual != null && op.votosUids.contains(uidActual);
          final double porcentaje = totalVotos == 0
              ? 0.0
              : op.votosUids.length / totalVotos.toDouble();

          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: InkWell(
              onTap: () => onVotarEncuesta(index),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: yaVoto
                      ? AppTheme.verdeAzulado.withValues(alpha: 0.2)
                      : (esPropio
                          ? Colors.white.withValues(alpha: 0.15)
                          : AppTheme.crema),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: yaVoto
                        ? AppTheme.verdeAzulado
                        : AppTheme.verdeSuave.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(
                          op.texto,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                yaVoto ? FontWeight.bold : FontWeight.normal,
                            color: esPropio
                                ? Colors.white
                                : AppTheme.azulPetroleo,
                          ),
                        ),
                        Text(
                          '${(porcentaje * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: esPropio
                                ? Colors.white.withValues(alpha: 0.8)
                                : AppTheme.textoSuave,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: porcentaje,
                      backgroundColor: esPropio
                          ? Colors.white.withValues(alpha: 0.2)
                          : Colors.grey.shade300,
                      color: AppTheme.verdeAzulado,
                      minHeight: 4,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        Text(
          'Total: $totalVotos votos',
          style: TextStyle(
            fontSize: 10.5,
            color: esPropio
                ? Colors.white.withValues(alpha: 0.7)
                : AppTheme.textoSuave,
          ),
        ),
      ],
    );
  }
}
