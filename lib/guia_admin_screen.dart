

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'guia_service.dart';

class GuiaAdminScreen extends StatefulWidget {
  const GuiaAdminScreen({super.key});

  @override
  State<GuiaAdminScreen> createState() => _GuiaAdminScreenState();
}

class _GuiaAdminScreenState extends State<GuiaAdminScreen> {
  final GuiaService _guiaService = GuiaService();

  List<Map<String, dynamic>> _solicitudes = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarSolicitudes();
  }

  // Carga las solicitudes que están pendientes de revisión.
  Future<void> _cargarSolicitudes() async {
    if (!mounted) return;

    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final solicitudes =
          await _guiaService.obtenerSolicitudesPendientes();

      if (!mounted) return;

      setState(() {
        _solicitudes = solicitudes;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _cargando = false;
      });
    }
  }

  String _texto(dynamic valor) {
    if (valor == null || valor.toString().trim().isEmpty) {
      return 'No registrado';
    }

    return valor.toString();
  }

  // Abre el documento en el navegador.
  Future<void> _abrirDocumento(String url) async {
    final uri = Uri.tryParse(url);

    if (uri == null ||
        (uri.scheme != 'https' && uri.scheme != 'http')) {
      _mostrarMensaje('El enlace del documento no es válido.');
      return;
    }

    try {
      final abierto = await launchUrl(
        uri,
        mode: LaunchMode.platformDefault,
      );

      if (!mounted) return;

      if (!abierto) {
        _mostrarMensaje('No se pudo abrir el documento.');
      }
    } catch (_) {
      _mostrarMensaje('Ocurrió un error al abrir el documento.');
    }
  }

  void _mostrarMensaje(String mensaje) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje)),
    );
  }

  // Solicita un motivo para rechazar o devolver documentos.
  Future<String?> _pedirMotivo({
    required String titulo,
    required String etiqueta,
  }) async {
    final controlador = TextEditingController();

    try {
      return await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(titulo),
          content: TextField(
            controller: controlador,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: etiqueta,
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final motivo = controlador.text.trim();

                if (motivo.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('Debes escribir un motivo.'),
                    ),
                  );
                  return;
                }

                Navigator.pop(dialogContext, motivo);
              },
              child: const Text('Continuar'),
            ),
          ],
        ),
      );
    } finally {
      controlador.dispose();
    }
  }

  // Aprueba los certificados del guía.
  Future<void> _aprobar(String uid) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Aprobar certificados'),
        content: const Text(
          '¿Confirmas que los documentos del guía son correctos?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Aprobar'),
          ),
        ],
      ),
    );

    if (!mounted || confirmar != true) return;

    try {
      await _guiaService.aprobarSolicitud(uid);

      if (!mounted) return;

      _mostrarMensaje('Solicitud aprobada.');
      await _cargarSolicitudes();
    } catch (e) {
      _mostrarMensaje('No se pudo aprobar: $e');
    }
  }

  // Rechaza la solicitud y guarda el motivo.
  Future<void> _rechazar(String uid) async {
    final motivo = await _pedirMotivo(
      titulo: 'Rechazar solicitud',
      etiqueta: 'Motivo del rechazo',
    );

    if (!mounted || motivo == null) return;

    try {
      await _guiaService.rechazarSolicitud(
        userId: uid,
        motivo: motivo,
      );

      if (!mounted) return;

      _mostrarMensaje('Solicitud rechazada.');
      await _cargarSolicitudes();
    } catch (e) {
      _mostrarMensaje('No se pudo rechazar: $e');
    }
  }

  // Solicita correcciones indicando qué documentos debe modificar.
  Future<void> _solicitarCorrecciones(String uid) async {
    final motivo = await _pedirMotivo(
      titulo: 'Solicitar correcciones',
      etiqueta: 'Documentos que debe corregir',
    );

    if (!mounted || motivo == null) return;

    try {
      await _guiaService.solicitarCorrecciones(
        userId: uid,
        motivo: motivo,
      );

      if (!mounted) return;

      _mostrarMensaje('Se solicitaron las correcciones.');
      await _cargarSolicitudes();
    } catch (e) {
      _mostrarMensaje(
        'No se pudieron solicitar correcciones: $e',
      );
    }
  }

  
  // Devuelve los certificados aprobados a revisión.
  Future<void> _revertirAprobacion(String uid) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Revertir aprobación'),
        content: const Text(
          'La solicitud volverá a revisión para que puedas evaluarla.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Revertir'),
          ),
        ],
      ),
    );

    if (!mounted || confirmar != true) return;

    try {
      // Usamos el servicio para actualizar el estado y crear la notificación.
      await _guiaService.revertirAprobacion(uid);

      if (!mounted) return;

      _mostrarMensaje(
        'Los certificados volvieron al estado de revisión.',
      );

      await _cargarSolicitudes();
    } catch (e) {
      _mostrarMensaje('No se pudo revertir la aprobación: $e');
    }
  }


  // Muestra un documento adjunto.
  Widget _construirDocumento(
    String titulo,
    dynamic datos,
  ) {
    if (datos is! Map) {
      return ListTile(
        title: Text(titulo),
        subtitle: const Text('Documento no registrado'),
      );
    }

    final nombre = _texto(datos['nombre']);
    final url = _texto(datos['url']);

    return ListTile(
      leading: const Icon(Icons.picture_as_pdf),
      title: Text(titulo),
      subtitle: Text(nombre),
      trailing: IconButton(
        tooltip: 'Abrir documento',
        icon: const Icon(Icons.open_in_new),
        onPressed: url == 'No registrado'
            ? null
            : () => _abrirDocumento(url),
      ),
    );
  }

  // Construye la tarjeta de cada solicitud.
  Widget _construirSolicitud(
    Map<String, dynamic> solicitud,
  ) {
    final uid = _texto(solicitud['uid']);
    final certificados = solicitud['certificados'];

    final Map<String, dynamic> docs = certificados is Map
        ? Map<String, dynamic>.from(certificados)
        : <String, dynamic>{};

    final adicionales = docs['adicionales'];

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _texto(
                solicitud['nombreCompleto'] ??
                    solicitud['nombre'] ??
                    solicitud['nombres'],
              ),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text('Correo: ${_texto(solicitud['correo'])}'),
            Text('UID: $uid'),
            const Divider(height: 24),
            const Text(
              'Documentos enviados',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            _construirDocumento(
              'Carné de guía',
              docs['carneGuia'],
            ),
            _construirDocumento(
              'Antecedentes judiciales',
              docs['antecedentesJudiciales'],
            ),
            if (adicionales is List)
              for (int i = 0; i < adicionales.length; i++)
                _construirDocumento(
                  'Documento adicional ${i + 1}',
                  adicionales[i],
                ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: uid == 'No registrado'
                      ? null
                      : () => _aprobar(uid),
                  icon: const Icon(Icons.check),
                  label: const Text('Aprobar'),
                ),
                OutlinedButton.icon(
                  onPressed: uid == 'No registrado'
                      ? null
                      : () => _solicitarCorrecciones(uid),
                  icon: const Icon(Icons.edit_document),
                  label: const Text('Solicitar correcciones'),
                ),
                OutlinedButton.icon(
                  onPressed: uid == 'No registrado'
                      ? null
                      : () => _rechazar(uid),
                  icon: const Icon(Icons.close),
                  label: const Text('Rechazar'),
                ),
                OutlinedButton.icon(
                  onPressed: uid == 'No registrado'
                      ? null
                      : () => _revertirAprobacion(uid),
                  icon: const Icon(Icons.undo),
                  label: const Text('Revertir aprobación'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Revisión de guías'),
        actions: [
          IconButton(
            tooltip: 'Actualizar solicitudes',
            onPressed: _cargando ? null : _cargarSolicitudes,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _cargando
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _cargarSolicitudes,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              : _solicitudes.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No hay solicitudes de certificados pendientes.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _cargarSolicitudes,
                      child: ListView.builder(
                        physics:
                            const AlwaysScrollableScrollPhysics(),
                        itemCount: _solicitudes.length,
                        itemBuilder: (context, index) {
                          return _construirSolicitud(
                            _solicitudes[index],
                          );
                        },
                      ),
                    ),
    );
  }
}
