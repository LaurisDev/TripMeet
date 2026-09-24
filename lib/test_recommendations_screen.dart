import 'package:flutter/material.dart';

import 'ai_recommendation_service.dart';
import 'preferences_service.dart';
import 'widgets/aviso_error.dart';

/// Pantalla temporal para probar de punta a punta el flujo
/// Flutter -> Vercel -> Gemini -> UI de recomendaciones con IA.
///
/// No es la interfaz final de la historia de usuario, solo permite validar
/// que el servicio [AiRecommendationService] funciona correctamente.
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
  final TextEditingController _interesesController = TextEditingController();
  final TextEditingController _preferenciasController =
      TextEditingController();

  bool _cargando = false;
  String? _error;
  List<PlaceRecommendation> _recomendaciones = <PlaceRecommendation>[];

  @override
  void dispose() {
    _service.dispose();
    _interesesController.dispose();
    _preferenciasController.dispose();
    super.dispose();
  }

  /// Carga las preferencias guardadas del turista (o la lista amplia por
  /// defecto si no ha configurado ninguna) y pide recomendaciones con ellas,
  /// sin que tenga que volver a escribirlas.
  Future<void> _usarPreferenciasGuardadas() async {
    setState(() {
      _cargando = true;
      _error = null;
      _recomendaciones = <PlaceRecommendation>[];
    });

    try {
      final List<String> intereses =
          await _preferencesService.obtenerPreferenciasParaRecomendaciones();
      _interesesController.text = intereses.join(', ');

      final List<PlaceRecommendation> resultado =
          await _service.obtenerRecomendaciones(
        intereses: intereses,
        preferenciasAdicionales: _preferenciasController.text,
      );
      setState(() => _recomendaciones = resultado);
    } on PreferencesServiceException catch (error) {
      setState(() => _error = error.message);
    } on AiRecommendationException catch (error) {
      setState(() => _error = error.message);
    } finally {
      setState(() => _cargando = false);
    }
  }

  Future<void> _obtenerRecomendaciones() async {
    final List<String> intereses = _interesesController.text
        .split(',')
        .map((String texto) => texto.trim())
        .where((String texto) => texto.isNotEmpty)
        .toList();

    setState(() {
      _cargando = true;
      _error = null;
      _recomendaciones = <PlaceRecommendation>[];
    });

    try {
      final List<PlaceRecommendation> resultado =
          await _service.obtenerRecomendaciones(
        intereses: intereses,
        preferenciasAdicionales: _preferenciasController.text,
      );
      setState(() => _recomendaciones = resultado);
    } on AiRecommendationException catch (error) {
      setState(() => _error = error.message);
    } finally {
      setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Prueba: recomendaciones IA')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            TextField(
              controller: _interesesController,
              decoration: const InputDecoration(
                labelText: 'Intereses (separados por coma)',
                hintText: 'Naturaleza, Aventura, Fotografía',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _preferenciasController,
              decoration: const InputDecoration(
                labelText: 'Preferencias adicionales (opcional)',
                hintText: 'Quiero un lugar tranquilo para caminar',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _cargando ? null : _obtenerRecomendaciones,
              child: const Text('Obtener recomendaciones'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _cargando ? null : _usarPreferenciasGuardadas,
              child: const Text('Usar mis preferencias guardadas'),
            ),
            const SizedBox(height: 16),
            if (_cargando)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              AvisoError(mensaje: _error!)
            else
              ..._recomendaciones.map(
                (PlaceRecommendation recomendacion) => Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          recomendacion.nombre,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(recomendacion.descripcion),
                        const SizedBox(height: 6),
                        Text(
                          'Motivo: ${recomendacion.motivoRecomendacion}',
                          style: const TextStyle(fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
