import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'form_styles.dart';
import 'guia_perfil_laboral_screen.dart';
import 'guia_service.dart';
import 'home_screen.dart';
import 'widgets/archivo_picker.dart';
import 'widgets/aviso_error.dart';
import 'widgets/registro_scaffold.dart';

/// Pantalla 2 del registro de guías turísticos: subida de certificados.
///
/// Recibe el [userId] (UID de Firebase Auth) de la cuenta ya creada en la
/// Pantalla 1. Se navega hacia aquí solo cuando el rol elegido fue
/// "Guía turístico" y la cuenta quedó en estado "pendiente de aprobación".
class GuiaCertificadosScreen extends StatefulWidget {
  const GuiaCertificadosScreen({
    super.key,
    required this.userId,
    this.guiaService,
  });

  final String userId;
  final GuiaService? guiaService;

  @override
  State<GuiaCertificadosScreen> createState() => _GuiaCertificadosScreenState();
}

class _GuiaCertificadosScreenState extends State<GuiaCertificadosScreen> {
  GuiaService get _service => widget.guiaService ?? GuiaService();

  ArchivoLocal? _carne;
  ArchivoLocal? _antecedentes;
  final List<ArchivoLocal> _adicionales = <ArchivoLocal>[];

  String? _errorCarne;
  String? _errorAntecedentes;
  String? _errorGeneral;
  bool _cargando = false;

  /// Envuelve la apertura del selector para mostrar cualquier error en pantalla
  /// (por ejemplo, si el plugin aún no está registrado tras instalarlo).
  Future<List<ArchivoLocal>> _seleccionar({bool multiple = false}) async {
    setState(() => _errorGeneral = null);
    try {
      return await seleccionarArchivos(multiple: multiple);
    } on SeleccionArchivoException catch (error) {
      if (mounted) setState(() => _errorGeneral = error.message);
    } catch (error) {
      if (mounted) {
        setState(() => _errorGeneral =
            'No se pudo abrir el selector de archivos. Inténtalo de nuevo.');
      }
    }
    return const <ArchivoLocal>[];
  }

  Future<void> _elegirCarne() async {
    final List<ArchivoLocal> archivos = await _seleccionar();
    if (archivos.isEmpty) return;
    setState(() {
      _carne = archivos.first;
      _errorCarne = null;
    });
  }

  Future<void> _elegirAntecedentes() async {
    final List<ArchivoLocal> archivos = await _seleccionar();
    if (archivos.isEmpty) return;
    setState(() {
      _antecedentes = archivos.first;
      _errorAntecedentes = null;
    });
  }

  Future<void> _agregarAdicionales() async {
    final List<ArchivoLocal> archivos = await _seleccionar(multiple: true);
    if (archivos.isEmpty) return;
    setState(() => _adicionales.addAll(archivos));
  }

  bool _validar() {
    setState(() {
      _errorCarne =
          _carne == null ? 'Adjunta tu carné de guía turístico' : null;
      _errorAntecedentes = _antecedentes == null
          ? 'Adjunta tu certificado de antecedentes judiciales'
          : null;
    });
    return _carne != null && _antecedentes != null;
  }

  Future<void> _continuar() async {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _errorGeneral = null);
    if (!_validar()) return;

    setState(() => _cargando = true);
    try {
      await _service.subirCertificados(
        userId: widget.userId,
        carneGuia: _carne!,
        antecedentesJudiciales: _antecedentes!,
        adicionales: _adicionales,
      );
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => GuiaPerfilLaboralScreen(userId: widget.userId),
        ),
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
        _errorGeneral =
            'No se pudieron subir los archivos. Inténtalo de nuevo.';
      });
    } finally {
      if (mounted && _cargando) setState(() => _cargando = false);
    }
  }

  Future<void> _completarDespues() async {
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FormStyles.radio),
        ),
        title: Text('Completar después', style: FormStyles.titulo(pequena: true)),
        content: Text(
          'No podrás ofrecer servicios hasta completar tus certificados. '
          'Podrás subirlos más adelante desde tu perfil.',
          style: FormStyles.subtitulo(pequena: true),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Seguir aquí'),
          ),
          FilledButton(
            style: FormStyles.botonPrimario(),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Completar después'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    setState(() {
      _cargando = true;
      _errorGeneral = null;
    });
    try {
      await _service.posponerCertificados(widget.userId);
    } catch (_) {
      // Aunque falle el marcado, se permite continuar a Home.
    }
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute<void>(
        builder: (_) => const HomeScreen(
          avisoRevision:
              'Tu perfil está en revisión. Completa tus certificados para ofrecer servicios.',
        ),
      ),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return RegistroScaffold(
      paso: 2,
      totalPasos: 3,
      titulo: 'Verifica tu identidad',
      subtitulo:
          'Sube tus documentos para validar tu perfil como guía turístico.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ArchivoPickerField(
            etiqueta: 'Carné de guía turístico',
            obligatorio: true,
            descripcion:
                'Documento oficial que acredita tu registro como guía (formato PDF).',
            archivo: _carne,
            errorText: _errorCarne,
            habilitado: !_cargando,
            onSeleccionar: _elegirCarne,
            onQuitar: () => setState(() => _carne = null),
          ),
          const SizedBox(height: FormStyles.s24),
          ArchivoPickerField(
            etiqueta: 'Certificado de antecedentes judiciales',
            obligatorio: true,
            descripcion:
                'Con fecha de expedición no mayor a 3 meses (formato PDF).',
            archivo: _antecedentes,
            errorText: _errorAntecedentes,
            habilitado: !_cargando,
            onSeleccionar: _elegirAntecedentes,
            onQuitar: () => setState(() => _antecedentes = null),
          ),
          const SizedBox(height: FormStyles.s24),
          ArchivoPickerMultiple(
            etiqueta: 'Certificados adicionales (opcional)',
            descripcion:
                'Primeros auxilios, idiomas, especialidades u otras acreditaciones.',
            archivos: _adicionales,
            habilitado: !_cargando,
            onAgregar: _agregarAdicionales,
            onQuitar: (int i) => setState(() => _adicionales.removeAt(i)),
          ),
          if (_errorGeneral != null) ...<Widget>[
            const SizedBox(height: FormStyles.s16),
            AvisoError(mensaje: _errorGeneral!),
          ],
          const SizedBox(height: FormStyles.s28),
          FilledButton(
            style: FormStyles.botonPrimario(),
            onPressed: _cargando ? null : _continuar,
            child: _cargando
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Text('Continuar'),
          ),
          const SizedBox(height: FormStyles.s8),
          TextButton(
            onPressed: _cargando ? null : _completarDespues,
            child: Text(
              'Completar después',
              style: FormStyles.cuerpo(
                weight: FontWeight.w600,
                color: AppTheme.verdeAzulado,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
