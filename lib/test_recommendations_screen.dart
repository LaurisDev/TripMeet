import 'package:flutter/material.dart';

import 'ai_recommendation_service.dart';
import 'app_theme.dart';
import 'preferences_service.dart';
import 'widgets/aviso_error.dart';

/// Modelo de mensaje dentro de la conversación del chat con la IA.
class ChatMessage {
  ChatMessage({
    required this.isUser,
    this.text,
    this.recommendations = const <PlaceRecommendation>[],
    this.isLoading = false,
    this.error,
  });

  final bool isUser;
  final String? text;
  final List<PlaceRecommendation> recommendations;
  final bool isLoading;
  final String? error;
}

/// Pantalla de chat con Inteligencia Artificial para obtener recomendaciones
/// personalizadas de lugares turísticos en Colombia.
class TestRecommendationsScreen extends StatefulWidget {
  const TestRecommendationsScreen({super.key});

  @override
  State<TestRecommendationsScreen> createState() =>
      _TestRecommendationsScreenState();
}

class _TestRecommendationsScreenState
    extends State<TestRecommendationsScreen> {
  final AiRecommendationService _service = AiRecommendationService();
  final PreferencesService _preferencesService = PreferencesService();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<ChatMessage> _messages = <ChatMessage>[];
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    _messages.add(
      ChatMessage(
        isUser: false,
        text: '¡Hola! 🌴 Soy tu asistente de viajes TripMeet con Inteligencia Artificial.\n\n'
            'Cuéntame qué tipo de experiencia o destinos buscas en Colombia (por ejemplo: "naturaleza y cascadas", "lugares tranquilos para descansar", "historia y cultura"), o usa tus preferencias guardadas.',
      ),
    );
  }

  @override
  void dispose() {
    _service.dispose();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
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

  /// Carga las preferencias guardadas del turista y pide recomendaciones con ellas.
  Future<void> _usarPreferenciasGuardadas() async {
    if (_cargando) return;

    setState(() {
      _cargando = true;
      _messages.add(
        ChatMessage(
          isUser: true,
          text: 'Quiero recomendaciones basadas en mis preferencias guardadas.',
        ),
      );
      _messages.add(ChatMessage(isUser: false, isLoading: true));
    });

    _scrollToBottom();

    try {
      final List<String> intereses =
          await _preferencesService.obtenerPreferenciasParaRecomendaciones();

      final List<PlaceRecommendation> resultado =
          await _service.obtenerRecomendaciones(
        intereses: intereses,
      );

      setState(() {
        _messages.removeLast(); // Quitar mensaje de carga
        _messages.add(
          ChatMessage(
            isUser: false,
            text:
                'Analicé tus preferencias guardadas (${intereses.join(", ")}) y encontré estas excelentes opciones para ti en Colombia: 🇨🇴✨',
            recommendations: resultado,
          ),
        );
      });
    } on PreferencesServiceException catch (error) {
      setState(() {
        _messages.removeLast();
        _messages.add(
          ChatMessage(
            isUser: false,
            text: 'No se pudieron cargar tus preferencias:',
            error: error.message,
          ),
        );
      });
    } on AiRecommendationException catch (error) {
      setState(() {
        _messages.removeLast();
        _messages.add(
          ChatMessage(
            isUser: false,
            text: 'Hubo un inconveniente al consultar las recomendaciones:',
            error: error.message,
          ),
        );
      });
    } catch (_) {
      setState(() {
        _messages.removeLast();
        _messages.add(
          ChatMessage(
            isUser: false,
            text: 'Ocurrió un error inesperado. Inténtalo de nuevo.',
          ),
        );
      });
    } finally {
      setState(() => _cargando = false);
      _scrollToBottom();
    }
  }

  Future<void> _handleSubmitted(String text) async {
    final String query = text.trim();
    if (query.isEmpty || _cargando) return;

    _textController.clear();
    setState(() {
      _cargando = true;
      _messages.add(ChatMessage(isUser: true, text: query));
      _messages.add(ChatMessage(isUser: false, isLoading: true));
    });

    _scrollToBottom();

    final List<String> intereses = query
        .split(',')
        .map((String texto) => texto.trim())
        .where((String texto) => texto.isNotEmpty)
        .toList();

    try {
      final List<PlaceRecommendation> resultado =
          await _service.obtenerRecomendaciones(
        intereses: intereses.isEmpty ? <String>[query] : intereses,
        preferenciasAdicionales: query,
      );

      setState(() {
        _messages.removeLast(); // Quitar mensaje de carga
        _messages.add(
          ChatMessage(
            isUser: false,
            text: resultado.isEmpty
                ? 'No encontré recomendaciones específicas para esa búsqueda. Intenta con otros intereses o palabras clave.'
                : '¡Aquí tienes las mejores opciones que encontré para ti en Colombia! 🇨🇴✨',
            recommendations: resultado,
          ),
        );
      });
    } on AiRecommendationException catch (error) {
      setState(() {
        _messages.removeLast();
        _messages.add(
          ChatMessage(
            isUser: false,
            text: 'Hubo un inconveniente al consultar la IA:',
            error: error.message,
          ),
        );
      });
    } catch (_) {
      setState(() {
        _messages.removeLast();
        _messages.add(
          ChatMessage(
            isUser: false,
            text: 'Ocurrió un error inesperado al procesar tu solicitud.',
          ),
        );
      });
    } finally {
      setState(() => _cargando = false);
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.crema,
      appBar: AppBar(
        backgroundColor: AppTheme.crema,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppTheme.azulPetroleo,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.verdeAzulado.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.smart_toy_rounded,
                color: AppTheme.verdeAzulado,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Recomendaciones IA',
                  style: TextStyle(
                    color: AppTheme.azulPetroleo,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Asistente de viaje en Colombia',
                  style: TextStyle(
                    color: AppTheme.textoSuave,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: AppTheme.azulPetroleo),
            tooltip: 'Mis preferencias',
            onPressed: _usarPreferenciasGuardadas,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(vertical: 12),
                itemCount: _messages.length,
                itemBuilder: (BuildContext context, int index) {
                  final ChatMessage message = _messages[index];
                  return _buildMessageItem(message);
                },
              ),
            ),
            _buildQuickSuggestions(),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageItem(ChatMessage message) {
    if (message.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(left: 48, right: 16, top: 6, bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.azulPetroleo,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(4),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            message.text ?? '',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14.5,
              height: 1.4,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          CircleAvatar(
            radius: 16,
            backgroundColor: AppTheme.verdeAzulado,
            child: const Icon(
              Icons.smart_toy_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.superficieClara,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(18),
                      bottomLeft: Radius.circular(18),
                      bottomRight: Radius.circular(18),
                    ),
                    border: Border.all(
                      color: AppTheme.verdeAzulado.withValues(alpha: 0.15),
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: message.isLoading
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.verdeAzulado,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Buscando las mejores recomendaciones...',
                              style: TextStyle(
                                color: AppTheme.textoSuave,
                                fontSize: 13.5,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            if (message.text != null &&
                                message.text!.isNotEmpty)
                              Text(
                                message.text!,
                                style: const TextStyle(
                                  color: AppTheme.azulPetroleo,
                                  fontSize: 14.5,
                                  height: 1.4,
                                ),
                              ),
                            if (message.error != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: AvisoError(mensaje: message.error!),
                              ),
                          ],
                        ),
                ),
                if (message.recommendations.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Column(
                      children: message.recommendations
                          .map((PlaceRecommendation rec) =>
                              _buildRecommendationCard(rec))
                          .toList(),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationCard(PlaceRecommendation rec) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.superficieClara,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.verdeSuave.withValues(alpha: 0.3),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.verdeAzulado.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.place_rounded,
                    color: AppTheme.verdeAzulado,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    rec.nombre,
                    style: const TextStyle(
                      color: AppTheme.azulPetroleo,
                      fontWeight: FontWeight.bold,
                      fontSize: 15.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              rec.descripcion,
              style: const TextStyle(
                color: AppTheme.textoSuave,
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
            if (rec.motivoRecomendacion.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.crema,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppTheme.arena.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Icon(
                      Icons.auto_awesome,
                      color: AppTheme.naranjaQuemado,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        rec.motivoRecomendacion,
                        style: const TextStyle(
                          color: AppTheme.azulPetroleo,
                          fontSize: 12.5,
                          fontStyle: FontStyle.italic,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuickSuggestions() {
    if (_cargando) return const SizedBox.shrink();

    final List<Map<String, dynamic>> suggestions = <Map<String, dynamic>>[
      <String, dynamic>{
        'label': 'Usar mis preferencias',
        'icon': Icons.star_rounded,
        'action': _usarPreferenciasGuardadas,
      },
      <String, dynamic>{
        'label': 'Naturaleza y cascadas',
        'icon': Icons.landscape_rounded,
        'query': 'Naturaleza, cascadas y ecoturismo',
      },
      <String, dynamic>{
        'label': 'Pueblos patrimoniales',
        'icon': Icons.location_city_rounded,
        'query': 'Pueblos coloniales y patrimoniales de Colombia',
      },
      <String, dynamic>{
        'label': 'Playas y descanso',
        'icon': Icons.beach_access_rounded,
        'query': 'Playas y lugares tranquilos para descansar',
      },
    ];

    return Container(
      height: 42,
      margin: const EdgeInsets.only(bottom: 6),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: suggestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int index) {
          final Map<String, dynamic> item = suggestions[index];
          return ActionChip(
            avatar: Icon(
              item['icon'] as IconData,
              size: 16,
              color: AppTheme.azulPetroleo,
            ),
            label: Text(
              item['label'] as String,
              style: const TextStyle(
                color: AppTheme.azulPetroleo,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            backgroundColor: AppTheme.superficieClara,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: AppTheme.verdeAzulado.withValues(alpha: 0.3),
              ),
            ),
            onPressed: () {
              if (item.containsKey('action')) {
                (item['action'] as VoidCallback)();
              } else if (item.containsKey('query')) {
                _handleSubmitted(item['query'] as String);
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.superficieClara,
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
              onSubmitted: _handleSubmitted,
              enabled: !_cargando,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              decoration: InputDecoration(
                hintText: 'Escribe tus gustos, lugar o actividad...',
                hintStyle: TextStyle(
                  color: AppTheme.textoSuave.withValues(alpha: 0.6),
                  fontSize: 14,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
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
                    color: AppTheme.verdeSuave.withValues(alpha: 0.2),
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
            color: _cargando ? AppTheme.verdeSuave : AppTheme.azulPetroleo,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _cargando
                  ? null
                  : () => _handleSubmitted(_textController.text),
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
