import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'evento_service.dart';
import 'form_styles.dart';

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
  });

  final String id;
  final String eventoId;
  final String usuarioId;
  final String nombreUsuario;
  final String? fotoUsuario;
  final String texto;
  final DateTime fecha;

  factory MensajeEvento.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
    String eventoId,
  ) {
    final Map<String, dynamic> datos = doc.data() ?? <String, dynamic>{};
    return MensajeEvento(
      id: doc.id,
      eventoId: eventoId,
      usuarioId: datos['usuarioId'] as String? ?? '',
      nombreUsuario: datos['nombreUsuario'] as String? ?? 'Viajero',
      fotoUsuario: datos['fotoUsuario'] as String?,
      texto: datos['texto'] as String? ?? '',
      fecha: (datos['fecha'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'usuarioId': usuarioId,
      'nombreUsuario': nombreUsuario,
      if (fotoUsuario != null) 'fotoUsuario': fotoUsuario,
      'texto': texto,
      'fecha': Timestamp.fromDate(fecha),
    };
  }
}

/// Pantalla moderna e innovadora de Chat exclusivo para los participantes de un Evento.
class ChatEventoScreen extends StatefulWidget {
  const ChatEventoScreen({
    required this.evento,
    this.firestore,
    this.auth,
    super.key,
  });

  final Evento evento;
  final FirebaseFirestore? firestore;
  final FirebaseAuth? auth;

  @override
  State<ChatEventoScreen> createState() => _ChatEventoScreenState();
}

class _ChatEventoScreenState extends State<ChatEventoScreen> {
  late final FirebaseFirestore _firestore =
      widget.firestore ?? FirebaseFirestore.instance;
  late final FirebaseAuth _auth = widget.auth ?? FirebaseAuth.instance;

  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _enviando = false;

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

  /// Auto-scroll suave al final del chat.
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

  /// Envía un mensaje a la subcolección `eventos/{eventoId}/mensajes`.
  Future<void> _enviarMensaje([String? textoPersonalizado]) async {
    final String texto = (textoPersonalizado ?? _textController.text).trim();

    // Criterio de Aceptación: No permite mensajes vacíos.
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
                              'Coordina detalles, hora de encuentro y preguntas con los demás asistentes al evento.',
                              textAlign: TextAlign.center,
                              style: FormStyles.ayuda(),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  _scrollToBottom();

                  return ListView.builder(
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
                      return _BurbujaMensaje(
                        mensaje: msg,
                        esPropio: esPropio,
                      );
                    },
                  );
                },
              ),
            ),

            // Sugerencias rápidas de coordinación
            _buildSugerenciasRapidas(),

            // Barra inferior de entrada de texto
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  /// Chips rápidos para coordinación ágil entre participantes.
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

  /// Barra de entrada de mensajes fija en la parte inferior.
  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
          const SizedBox(width: 8),
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

/// Burbuja estilizada de mensaje para la lista de chat.
class _BurbujaMensaje extends StatelessWidget {
  const _BurbujaMensaje({
    required this.mensaje,
    required this.esPropio,
  });

  final MensajeEvento mensaje;
  final bool esPropio;

  String _formatearHora(DateTime fecha) {
    final String hora = fecha.hour.toString().padLeft(2, '0');
    final String minuto = fecha.minute.toString().padLeft(2, '0');
    return '$hora:$minuto';
  }

  @override
  Widget build(BuildContext context) {
    if (esPropio) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(left: 48, right: 4, top: 4, bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.azulPetroleo,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(4),
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
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                mensaje.texto,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatearHora(mensaje.fecha),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
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
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.only(right: 48),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  border: Border.all(
                    color: AppTheme.verdeAzulado.withValues(alpha: 0.15),
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      mensaje.nombreUsuario,
                      style: const TextStyle(
                        color: AppTheme.verdeAzulado,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      mensaje.texto,
                      style: const TextStyle(
                        color: AppTheme.azulPetroleo,
                        fontSize: 14,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatearHora(mensaje.fecha),
                      style: TextStyle(
                        color: AppTheme.textoSuave.withValues(alpha: 0.6),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
