import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../form_styles.dart';

/// Estructura visual compartida por las Pantallas 2 y 3 del registro de guías:
/// misma imagen de fondo, overlay y tarjeta blanca que la Pantalla 1, con un
/// indicador de paso ("Paso 2 de 3") en la cabecera.
class RegistroScaffold extends StatelessWidget {
  const RegistroScaffold({
    super.key,
    required this.titulo,
    required this.subtitulo,
    required this.paso,
    required this.totalPasos,
    required this.child,
    this.onAtras,
  });

  final String titulo;
  final String subtitulo;
  final int paso;
  final int totalPasos;
  final Widget child;
  final VoidCallback? onAtras;

  @override
  Widget build(BuildContext context) {
    final bool esPantallaPequena = MediaQuery.of(context).size.width < 360;
    final double paddingHorizontal = esPantallaPequena ? 16 : 24;
    final double altoPantalla = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Positioned.fill(
            child: Image.asset(
              'assets/images/atardecer_playa.jpg.jpg',
              fit: BoxFit.cover,
              alignment: const Alignment(0.0, 0.3),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Colors.black.withValues(alpha: 0.10),
                    Colors.black.withValues(alpha: 0.30),
                    AppTheme.crema.withValues(alpha: 0.85),
                  ],
                  stops: const <double>[0.0, 0.4, 0.9],
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: <Widget>[
                  SizedBox(height: altoPantalla * 0.10),
                  Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: paddingHorizontal),
                    child: Card(
                      color: Colors.white.withValues(alpha: 0.94),
                      elevation: 12,
                      shadowColor: Colors.black.withValues(alpha: 0.15),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(FormStyles.radioTarjeta),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(esPantallaPequena ? 20 : 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                if (onAtras != null)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      right: FormStyles.s8,
                                    ),
                                    child: InkWell(
                                      onTap: onAtras,
                                      borderRadius: BorderRadius.circular(20),
                                      child: const Padding(
                                        padding: EdgeInsets.all(4),
                                        child: Icon(
                                          Icons.arrow_back_rounded,
                                          size: 20,
                                          color: AppTheme.azulPetroleo,
                                        ),
                                      ),
                                    ),
                                  ),
                                Text(
                                  'Paso $paso de $totalPasos',
                                  style: FormStyles.cuerpo(
                                    size: 13,
                                    weight: FontWeight.w600,
                                    color: AppTheme.verdeAzulado,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: FormStyles.s12),
                            _BarraProgreso(paso: paso, total: totalPasos),
                            const SizedBox(height: FormStyles.s20),
                            Text(titulo, style: FormStyles.titulo(
                              pequena: esPantallaPequena,
                            )),
                            const SizedBox(height: FormStyles.s4),
                            Text(
                              subtitulo,
                              style: FormStyles.subtitulo(
                                pequena: esPantallaPequena,
                              ),
                            ),
                            const SizedBox(height: FormStyles.s24),
                            child,
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BarraProgreso extends StatelessWidget {
  const _BarraProgreso({required this.paso, required this.total});

  final int paso;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List<Widget>.generate(total, (int i) {
        final bool completado = i < paso;
        return Expanded(
          child: Container(
            height: 4,
            margin: EdgeInsets.only(right: i == total - 1 ? 0 : FormStyles.s4),
            decoration: BoxDecoration(
              color: completado
                  ? AppTheme.naranjaQuemado
                  : FormStyles.colorBorde,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}
