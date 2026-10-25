import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../form_styles.dart';
import '../guia_service.dart' show ArchivoLocal;
import '../publicacion_service.dart';
import 'archivo_picker.dart';
import 'imagen_remota.dart';

/// Abre el selector del dispositivo para elegir varias fotos y devuelve las
/// válidas (hasta [disponibles]) junto con un aviso si alguna se descartó
/// por formato, tamaño o por pasar el máximo; el aviso es `null` si todo
/// entró.
Future<(List<FotoNueva>, String?)> elegirFotosNuevas({
  required int disponibles,
}) async {
  final List<ArchivoLocal> seleccionados;
  try {
    seleccionados = await seleccionarArchivos(
      multiple: true,
      extensiones: extensionesImagenPermitidas,
    );
  } on SeleccionArchivoException catch (error) {
    return (const <FotoNueva>[], error.message);
  }

  final List<FotoNueva> validas = <FotoNueva>[];
  String? aviso;
  for (final ArchivoLocal archivo in seleccionados) {
    final String? error = PublicacionService.validarImagen(archivo);
    if (error != null) {
      aviso = '"${archivo.nombre}": $error';
    } else if (validas.length < disponibles) {
      validas.add(FotoNueva(archivo));
    } else {
      aviso =
          'Puedes subir hasta $maximoFotosPublicacion fotos por publicación; '
          'algunas no se agregaron.';
    }
  }
  return (validas, aviso);
}

/// Selector de las fotos de una publicación (carrusel): una vista grande de
/// la foto elegida y, debajo, las miniaturas de todas, con opciones para
/// agregar más, quitar una o usarla como portada (la primera). Lo usan la
/// nueva publicación y la edición.
class SelectorFotos extends StatefulWidget {
  const SelectorFotos({
    required this.fotos,
    required this.habilitado,
    required this.onAgregar,
    required this.onQuitar,
    required this.onHacerPortada,
    super.key,
  });

  final List<FotoEdicion> fotos;
  final bool habilitado;
  final VoidCallback onAgregar;
  final ValueChanged<int> onQuitar;
  final ValueChanged<int> onHacerPortada;

  @override
  State<SelectorFotos> createState() => _SelectorFotosState();
}

class _SelectorFotosState extends State<SelectorFotos> {
  int _seleccionada = 0;

  @override
  Widget build(BuildContext context) {
    final List<FotoEdicion> fotos = widget.fotos;
    if (fotos.isEmpty) return _buildVacio();

    final int actual = _seleccionada.clamp(0, fotos.length - 1);
    final bool puedeAgregar = fotos.length < maximoFotosPublicacion;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(FormStyles.radioTarjeta),
              border: Border.all(color: FormStyles.colorBorde),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                _VistaFoto(foto: fotos[actual]),
                if (actual > 0)
                  Positioned(
                    left: FormStyles.s8,
                    bottom: FormStyles.s8,
                    child: _AccionFoto(
                      key: const Key('selector-hacer-portada'),
                      icono: Icons.star_outline_rounded,
                      texto: 'Usar como portada',
                      onTap: widget.habilitado
                          ? () {
                              widget.onHacerPortada(actual);
                              setState(() => _seleccionada = 0);
                            }
                          : null,
                    ),
                  ),
                Positioned(
                  right: FormStyles.s8,
                  bottom: FormStyles.s8,
                  child: _AccionFoto(
                    key: const Key('selector-quitar-foto'),
                    icono: Icons.delete_outline_rounded,
                    texto: 'Quitar',
                    onTap: widget.habilitado
                        ? () {
                            widget.onQuitar(actual);
                            if (actual > 0) {
                              setState(() => _seleccionada = actual - 1);
                            }
                          }
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: FormStyles.s12),
        SizedBox(
          height: 72,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: fotos.length + (puedeAgregar ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(width: FormStyles.s8),
            itemBuilder: (BuildContext context, int index) {
              if (index == fotos.length) {
                return _AgregarMiniatura(
                  onTap: widget.habilitado ? widget.onAgregar : null,
                );
              }
              return _Miniatura(
                key: Key('selector-miniatura-$index'),
                foto: fotos[index],
                seleccionada: index == actual,
                esPortada: index == 0,
                onTap: () => setState(() => _seleccionada = index),
              );
            },
          ),
        ),
        const SizedBox(height: FormStyles.s8),
        Text(
          '${fotos.length} de $maximoFotosPublicacion fotos · '
          'la primera es la portada. Desliza para verlas en el carrusel.',
          style: FormStyles.ayuda(),
        ),
      ],
    );
  }

  Widget _buildVacio() {
    return InkWell(
      key: const Key('selector-fotos-vacio'),
      onTap: widget.habilitado ? widget.onAgregar : null,
      borderRadius: BorderRadius.circular(FormStyles.radioTarjeta),
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(FormStyles.radioTarjeta),
            border: Border.all(color: FormStyles.colorBorde),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Icon(
                Icons.add_photo_alternate_outlined,
                size: 40,
                color: AppTheme.azulPetroleo,
              ),
              const SizedBox(height: FormStyles.s8),
              Text(
                'Toca para seleccionar tus fotos',
                style: FormStyles.cuerpo(
                  weight: FontWeight.w600,
                  color: AppTheme.azulPetroleo,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Hasta $maximoFotosPublicacion · JPG, JPEG, PNG o WEBP',
                style: FormStyles.ayuda(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VistaFoto extends StatelessWidget {
  const _VistaFoto({required this.foto});

  final FotoEdicion foto;

  @override
  Widget build(BuildContext context) {
    return switch (foto) {
      FotoNueva(:final archivo) => Image.memory(
        archivo.bytes,
        fit: BoxFit.cover,
      ),
      FotoPublicada(:final imagen) => ImagenRemota(url: imagen.url),
    };
  }
}

class _Miniatura extends StatelessWidget {
  const _Miniatura({
    required this.foto,
    required this.seleccionada,
    required this.esPortada,
    required this.onTap,
    super.key,
  });

  final FotoEdicion foto;
  final bool seleccionada;
  final bool esPortada;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(FormStyles.radio),
          border: Border.all(
            color: seleccionada ? AppTheme.verdeAzulado : FormStyles.colorBorde,
            width: seleccionada ? 2.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            _VistaFoto(foto: foto),
            if (esPortada)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  color: Colors.black.withValues(alpha: 0.55),
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: const Text(
                    'Portada',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AgregarMiniatura extends StatelessWidget {
  const _AgregarMiniatura({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(FormStyles.radio),
      child: InkWell(
        key: const Key('selector-agregar-fotos'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(FormStyles.radio),
        child: Container(
          width: 72,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(FormStyles.radio),
            border: Border.all(color: FormStyles.colorBorde),
          ),
          child: const Icon(
            Icons.add_photo_alternate_outlined,
            color: AppTheme.azulPetroleo,
          ),
        ),
      ),
    );
  }
}

class _AccionFoto extends StatelessWidget {
  const _AccionFoto({
    required this.icono,
    required this.texto,
    required this.onTap,
    super.key,
  });

  final IconData icono;
  final String texto;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(FormStyles.radioPill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(FormStyles.radioPill),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: FormStyles.s12,
            vertical: FormStyles.s8,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icono, size: 16, color: Colors.white),
              const SizedBox(width: FormStyles.s4),
              Text(
                texto,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
