import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'form_styles.dart';
import 'preferences_service.dart';
import 'widgets/aviso_error.dart';
import 'widgets/multi_select_chips.dart';

/// Sub-pantalla del Perfil donde el turista elige (o borra) las categorías
/// de interés que personalizan sus recomendaciones.
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
        _mensaje = 'Tus preferencias se borraron. Volverás a ver recomendaciones generales.';
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
      appBar: AppBar(title: const Text('Preferencias de recomendación')),
      body: SafeArea(
        child: _cargando
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(FormStyles.s20),
                children: <Widget>[
                  Text(
                    'Elige las categorías que más te interesan. Las usaremos '
                    'para personalizar tus recomendaciones de lugares.',
                    style: FormStyles.subtitulo(),
                  ),
                  const SizedBox(height: FormStyles.s20),
                  MultiSelectChips(
                    etiqueta: 'Categorías de interés',
                    opciones: categoriasDeInteres,
                    seleccionadas: _seleccionadas,
                    onChanged: (Set<String> nuevo) =>
                        setState(() => _seleccionadas = nuevo),
                  ),
                  const SizedBox(height: FormStyles.s24),
                  if (_error != null) ...<Widget>[
                    AvisoError(mensaje: _error!),
                    const SizedBox(height: FormStyles.s16),
                  ],
                  if (_mensaje != null) ...<Widget>[
                    Text(_mensaje!, style: FormStyles.cuerpo(color: AppTheme.verdeAzulado)),
                    const SizedBox(height: FormStyles.s16),
                  ],
                  FilledButton(
                    style: FormStyles.botonPrimario(),
                    onPressed: _guardando ? null : _guardarPreferencias,
                    child: _guardando
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
                  OutlinedButton(
                    style: FormStyles.botonSecundario(),
                    onPressed: _guardando || _seleccionadas.isEmpty
                        ? null
                        : _borrarPreferencias,
                    child: const Text('Borrar preferencias'),
                  ),
                ],
              ),
      ),
    );
  }
}
