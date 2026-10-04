import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_theme.dart';
import 'form_styles.dart';
import 'preferences_service.dart';
import 'widgets/aviso_error.dart';
import 'widgets/multi_select_chips.dart';

/// Sub-pantalla del Perfil donde el turista elige (o borra) las categorías
/// de interés que personalizan sus recomendaciones en Colombia.
class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  final PreferencesService _service = PreferencesService();

  Set<String> _seleccionadas = <String>{};
  bool _cargando = true;
  bool _guardando = false;
  String? _error;
  String? _mensaje;

  @override
  void initState() {
    super.initState();
    _cargarPreferencias();
  }

  Future<void> _cargarPreferencias() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final List<String> guardadas = await _service.obtenerPreferenciasUsuario();
      setState(() => _seleccionadas = guardadas.toSet());
    } on PreferencesServiceException catch (error) {
      setState(() => _error = error.message);
    } finally {
      setState(() => _cargando = false);
    }
  }

  Future<void> _guardarPreferencias() async {
    setState(() {
      _guardando = true;
      _error = null;
      _mensaje = null;
    });
    try {
      await _service.guardarPreferenciasUsuario(_seleccionadas.toList());
      setState(() => _mensaje = 'Tus preferencias se guardaron correctamente.');
    } on PreferencesServiceException catch (error) {
      setState(() => _error = error.message);
    } finally {
      setState(() => _guardando = false);
    }
  }

  Future<void> _borrarPreferencias() async {
    setState(() {
      _guardando = true;
      _error = null;
      _mensaje = null;
    });
    try {
      await _service.borrarPreferenciasUsuario();
      setState(() {
        _seleccionadas = <String>{};
        _mensaje =
            'Tus preferencias se borraron. Volverás a ver recomendaciones generales de Colombia.';
      });
    } on PreferencesServiceException catch (error) {
      setState(() => _error = error.message);
    } finally {
      setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.crema,
      appBar: AppBar(
        title: Text(
          'Preferencias de recomendación',
          style: GoogleFonts.fraunces(
            color: AppTheme.azulPetroleo,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: _cargando
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.azulPetroleo),
              )
            : ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: FormStyles.s20,
                  vertical: FormStyles.s16,
                ),
                children: <Widget>[
                  // Banner Hero principal con temática de TripMeet (Azul Petróleo)
                  Container(
                    padding: const EdgeInsets.all(FormStyles.s20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: <Color>[
                          AppTheme.azulPetroleo,
                          AppTheme.verdeAzulado,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(FormStyles.radioTarjeta),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: AppTheme.azulPetroleo.withValues(alpha: 0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Container(
                              padding: const EdgeInsets.all(FormStyles.s8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.auto_awesome_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: FormStyles.s12,
                                vertical: FormStyles.s4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.25),
                                borderRadius:
                                    BorderRadius.circular(FormStyles.radioPill),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  const Icon(
                                    Icons.location_on_rounded,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: FormStyles.s4),
                                  Text(
                                    '🇨🇴 Colombia',
                                    style: GoogleFonts.workSans(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: FormStyles.s16),
                        Text(
                          'Personaliza tu experiencia',
                          style: GoogleFonts.fraunces(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: FormStyles.s8),
                        Text(
                          'Selecciona tus intereses favoritos. Nuestra inteligencia artificial sugerirá los mejores destinos y actividades exclusivas en Colombia para ti.',
                          style: GoogleFonts.workSans(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.92),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: FormStyles.s20),

                  // Tarjeta con la selección de categorías
                  Container(
                    padding: const EdgeInsets.all(FormStyles.s20),
                    decoration: BoxDecoration(
                      color: AppTheme.superficieClara,
                      borderRadius: BorderRadius.circular(FormStyles.radioTarjeta),
                      border: Border.all(color: FormStyles.colorBorde),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            const Icon(
                              Icons.explore_outlined,
                              color: AppTheme.verdeAzulado,
                              size: 22,
                            ),
                            const SizedBox(width: FormStyles.s8),
                            Expanded(
                              child: Text(
                                'Categorías de interés',
                                style: GoogleFonts.fraunces(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.azulPetroleo,
                                ),
                              ),
                            ),
                            if (_seleccionadas.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: FormStyles.s8,
                                  vertical: FormStyles.s4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.verdeAzulado.withValues(alpha: 0.12),
                                  borderRadius:
                                      BorderRadius.circular(FormStyles.radioPill),
                                ),
                                child: Text(
                                  '${_seleccionadas.length} sel.',
                                  style: GoogleFonts.workSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.verdeAzulado,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: FormStyles.s8),
                        Text(
                          'Toca las opciones para activar o desactivar:',
                          style: FormStyles.subtitulo(pequena: true),
                        ),
                        const SizedBox(height: FormStyles.s16),
                        MultiSelectChips(
                          opciones: categoriasDeInteres,
                          seleccionadas: _seleccionadas,
                          activeColor: AppTheme.azulPetroleo,
                          activeTextColor: Colors.white,
                          onChanged: (Set<String> nuevo) =>
                              setState(() => _seleccionadas = nuevo),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: FormStyles.s20),

                  // Mensajes de éxito y error
                  if (_error != null) ...<Widget>[
                    AvisoError(mensaje: _error!),
                    const SizedBox(height: FormStyles.s16),
                  ],
                  if (_mensaje != null) ...<Widget>[
                    Container(
                      padding: const EdgeInsets.all(FormStyles.s12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(FormStyles.radio),
                        border: Border.all(
                          color: AppTheme.verdeAzulado.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: <Widget>[
                          const Icon(
                            Icons.check_circle_rounded,
                            color: AppTheme.verdeAzulado,
                            size: 20,
                          ),
                          const SizedBox(width: FormStyles.s8),
                          Expanded(
                            child: Text(
                              _mensaje!,
                              style: FormStyles.cuerpo(
                                color: AppTheme.azulPetroleo,
                                weight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: FormStyles.s16),
                  ],

                  // Botones de acción
                  FilledButton.icon(
                    style: FormStyles.botonPrimario(color: AppTheme.azulPetroleo),
                    onPressed: _guardando ? null : _guardarPreferencias,
                    icon: _guardando
                        ? const SizedBox.shrink()
                        : const Icon(Icons.save_rounded, size: 20),
                    label: _guardando
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Guardar preferencias'),
                  ),
                  const SizedBox(height: FormStyles.s12),
                  OutlinedButton.icon(
                    style: FormStyles.botonSecundario(),
                    onPressed: _guardando || _seleccionadas.isEmpty
                        ? null
                        : _borrarPreferencias,
                    icon: const Icon(Icons.delete_outline_rounded, size: 20),
                    label: const Text('Borrar preferencias'),
                  ),
                ],
              ),
      ),
    );
  }
}
