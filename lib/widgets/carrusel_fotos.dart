import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../form_styles.dart';
import 'imagen_remota.dart';

/// Fotos de una publicación que se pasan deslizando de lado, con un
/// contador "2/5" y puntos que indican la foto actual. Con una sola foto se
/// ve como una imagen normal.
class CarruselFotos extends StatefulWidget {
  const CarruselFotos({
    required this.urls,
    this.fondo = Colors.white,
    this.onTap,
    this.onDoubleTap,
    super.key,
  });

  final List<String> urls;

  /// Color de fondo mientras carga cada foto.
  final Color fondo;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;

  @override
  State<CarruselFotos> createState() => _CarruselFotosState();
}

class _CarruselFotosState extends State<CarruselFotos> {
  final PageController _controller = PageController();
  int _actual = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<String> urls = widget.urls;
    final Widget contenido = urls.length <= 1
        ? ImagenRemota(url: urls.isEmpty ? '' : urls.first, fondo: widget.fondo)
        : Stack(
            fit: StackFit.expand,
            children: <Widget>[
              PageView.builder(
                key: const Key('carrusel-fotos'),
                controller: _controller,
                itemCount: urls.length,
                onPageChanged: (int pagina) => setState(() => _actual = pagina),
                itemBuilder: (BuildContext context, int index) =>
                    ImagenRemota(url: urls[index], fondo: widget.fondo),
              ),
              Positioned(
                top: FormStyles.s12,
                right: FormStyles.s12,
                child: _Contador(texto: '${_actual + 1}/${urls.length}'),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: FormStyles.s12,
                child: _Puntos(total: urls.length, actual: _actual),
              ),
            ],
          );

    return GestureDetector(
      onTap: widget.onTap,
      onDoubleTap: widget.onDoubleTap,
      child: contenido,
    );
  }
}

class _Contador extends StatelessWidget {
  const _Contador({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: FormStyles.s8,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(FormStyles.radioPill),
      ),
      child: Text(
        texto,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _Puntos extends StatelessWidget {
  const _Puntos({required this.total, required this.actual});

  final int total;
  final int actual;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        for (int i = 0; i < total; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == actual ? 8 : 6,
            height: i == actual ? 8 : 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i == actual
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.5),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: AppTheme.azulPetroleo.withValues(alpha: 0.3),
                  blurRadius: 2,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
