import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'form_styles.dart';
import 'guia_service.dart';
import 'home_screen.dart';
import 'widgets/aviso_error.dart';
import 'widgets/multi_select_chips.dart';
import 'widgets/registro_scaffold.dart';

/// Pantalla 3 del registro de guías turísticos: perfil laboral.
///
/// Recibe el [userId] de la cuenta creada en la Pantalla 1. Al finalizar guarda
/// el perfil en `usuarios/{userId}` y lleva a Home con un aviso de revisión.
class GuiaPerfilLaboralScreen extends StatefulWidget {
  const GuiaPerfilLaboralScreen({
    super.key,
    required this.userId,
    this.guiaService,
  });

  final String userId;
  final GuiaService? guiaService;

  @override
  State<GuiaPerfilLaboralScreen> createState() =>
      _GuiaPerfilLaboralScreenState();
}

class _GuiaPerfilLaboralScreenState extends State<GuiaPerfilLaboralScreen> {
  static const List<String> _zonasDisponibles = <String>[
    'Centro histórico',
    'Zona norte',
    'Zona sur',
    'Rural / veredas',
    'Costa',
    'Montaña',
    'Toda la ciudad',
  ];

  static const Map<String, String> _especialidadesDisponibles = <String, String>{
    'historico': 'Histórico',
    'aventura': 'Aventura',
    'gastronomico': 'Gastronómico',
    'cultural': 'Cultural',
    'naturaleza': 'Naturaleza',
    'otro': 'Otro',
  };

  static const List<String> _idiomasDisponibles = <String>[
    'Español',
    'Inglés',
    'Francés',
    'Portugués',
    'Alemán',
    'Italiano',
    'Mandarín',
  ];

  static const int _maxBiografia = 200;

  GuiaService get _service => widget.guiaService ?? GuiaService();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _experienciaController = TextEditingController();
  final TextEditingController _biografiaController = TextEditingController();

  final Set<String> _zonas = <String>{};
  final Set<String> _especialidades = <String>{};
  final Set<String> _idiomas = <String>{};

  String? _errorZonas;
  String? _errorEspecialidades;
  String? _errorGeneral;
  bool _cargando = false;

  @override
  void dispose() {
    _experienciaController.dispose();
    _biografiaController.dispose();
    super.dispose();
  }

  bool _validarSelecciones() {
    setState(() {
      _errorZonas =
          _zonas.isEmpty ? 'Selecciona al menos una zona donde ofreces tours' : null;
      _errorEspecialidades = _especialidades.isEmpty
          ? 'Selecciona al menos una especialidad'
          : null;
    });
    return _zonas.isNotEmpty && _especialidades.isNotEmpty;
  }

  Future<void> _finalizar() async {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _errorGeneral = null);

    final bool formOk = _formKey.currentState?.validate() ?? false;
    final bool seleccionesOk = _validarSelecciones();
    if (!formOk || !seleccionesOk) return;

    final PerfilLaboral perfil = PerfilLaboral(
      aniosExperiencia: int.parse(_experienciaController.text.trim()),
      zonas: _zonas.toList(),
      especialidades: _especialidades.toList(),
      idiomas: _idiomas.toList(),
      biografia: _biografiaController.text.trim().isEmpty
          ? null
          : _biografiaController.text.trim(),
    );

    setState(() => _cargando = true);
    try {
      await _service.guardarPerfilLaboral(
        userId: widget.userId,
        perfil: perfil,
      );
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute<void>(
          builder: (_) => const HomeScreen(
            avisoRevision:
                'Tu perfil está en revisión, te notificaremos cuando sea aprobado.',
          ),
        ),
        (Route<dynamic> route) => false,
      );
    } on GuiaServiceException catch (error) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _errorGeneral = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _errorGeneral = 'No se pudo guardar tu perfil. Inténtalo de nuevo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RegistroScaffold(
      paso: 3,
      totalPasos: 3,
      titulo: 'Cuéntanos sobre tu trabajo',
      subtitulo: 'Esta información ayuda a los viajeros a elegirte.',
      onAtras: _cargando ? null : () => Navigator.of(context).maybePop(),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // --- AÑOS DE EXPERIENCIA ---
            TextFormField(
              controller: _experienciaController,
              enabled: !_cargando,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(2),
              ],
              decoration: FormStyles.input(
                label: 'Años de experiencia *',
                hint: 'Ej. 5',
                icon: Icons.workspace_premium_outlined,
              ),
              validator: (String? valor) {
                final String v = (valor ?? '').trim();
                if (v.isEmpty) return 'Indica tus años de experiencia';
                final int? n = int.tryParse(v);
                if (n == null || n < 0) return 'Ingresa un número válido';
                if (n > 70) return 'Revisa el valor ingresado';
                return null;
              },
            ),
            const SizedBox(height: FormStyles.s24),

            // --- ZONAS ---
            MultiSelectChips(
              etiqueta: 'Zona(s) donde ofreces tours',
              obligatorio: true,
              opciones: _zonasDisponibles,
              seleccionadas: _zonas,
              errorText: _errorZonas,
              onChanged: (Set<String> nuevas) => setState(() {
                _zonas
                  ..clear()
                  ..addAll(nuevas);
                if (_zonas.isNotEmpty) _errorZonas = null;
              }),
            ),
            const SizedBox(height: FormStyles.s24),

            // --- ESPECIALIDADES ---
            MultiSelectChips(
              etiqueta: 'Especialidad(es)',
              obligatorio: true,
              opciones: _especialidadesDisponibles.values.toList(),
              seleccionadas: _especialidades
                  .map((String k) => _especialidadesDisponibles[k] ?? k)
                  .toSet(),
              errorText: _errorEspecialidades,
              onChanged: (Set<String> etiquetas) => setState(() {
                _especialidades
                  ..clear()
                  ..addAll(
                    etiquetas.map(
                      (String etq) => _especialidadesDisponibles.entries
                          .firstWhere((MapEntry<String, String> e) =>
                              e.value == etq)
                          .key,
                    ),
                  );
                if (_especialidades.isNotEmpty) _errorEspecialidades = null;
              }),
            ),
            const SizedBox(height: FormStyles.s24),

            // --- IDIOMAS ---
            MultiSelectChips(
              etiqueta: 'Idiomas que manejas',
              opciones: _idiomasDisponibles,
              seleccionadas: _idiomas,
              ayuda: 'Opcional, pero recomendado.',
              onChanged: (Set<String> nuevos) => setState(() {
                _idiomas
                  ..clear()
                  ..addAll(nuevos);
              }),
            ),
            const SizedBox(height: FormStyles.s24),

            // --- BIOGRAFÍA ---
            TextFormField(
              controller: _biografiaController,
              enabled: !_cargando,
              maxLines: 4,
              maxLength: _maxBiografia,
              textInputAction: TextInputAction.newline,
              decoration: FormStyles.input(
                label: 'Biografía corta',
                hint: 'Preséntate en pocas líneas (opcional)',
              ),
            ),
            const SizedBox(height: FormStyles.s8),
            if (_errorGeneral != null) ...<Widget>[
              const SizedBox(height: FormStyles.s16),
              AvisoError(mensaje: _errorGeneral!),
            ],
            const SizedBox(height: FormStyles.s28),

            FilledButton(
              style: FormStyles.botonPrimario(),
              onPressed: _cargando ? null : _finalizar,
              child: _cargando
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Finalizar registro'),
            ),
            const SizedBox(height: FormStyles.s8),
            Text(
              'Al finalizar, tu perfil pasará a revisión del equipo de TripMeet.',
              textAlign: TextAlign.center,
              style: FormStyles.ayuda(),
            ),
          ],
        ),
      ),
    );
  }
}
