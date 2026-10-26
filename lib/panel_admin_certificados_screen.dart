
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'gestion_usuarios_screen.dart';
import 'publicaciones_reportadas_admin_screen.dart';
import 'resenas_reportadas_admin_screen.dart';
import 'verificacion_admin_screen.dart';

import 'guia_service.dart';

class PanelAdminCertificadosScreen extends StatefulWidget {
  const PanelAdminCertificadosScreen({super.key});

  @override
  State<PanelAdminCertificadosScreen> createState() =>
      _PanelAdminCertificadosScreenState();
}

class _PanelAdminCertificadosScreenState
    extends State<PanelAdminCertificadosScreen> {
  final GuiaService _guiaService = GuiaService();

  List<Map<String, dynamic>> _solicitudes = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarSolicitudes();
  }

  // Carga las solicitudes pendientes desde Firestore.
  Future<void> _cargarSolicitudes() async {
    if (!mounted) return;

    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final resultado =
          await _guiaService.obtenerSolicitudesPendientes();

      if (!mounted) return;

      setState(() {
        _solicitudes = resultado;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'No se pudieron cargar las solicitudes.';
        _cargando = false;
      });
    }
  }

  String _texto(dynamic valor) {
    if (valor == null || valor.toString().trim().isEmpty) {
      return 'No disponible';
    }

    return valor.toString();
  }

  String _nombreGuia(Map<String, dynamic> solicitud) {
    final nombre = solicitud['nombreCompleto'] ??
        solicitud['nombre'] ??
        solicitud['nombres'];

    if (nombre != null && nombre.toString().trim().isNotEmpty) {
      return nombre.toString();
    }

    return _texto(solicitud['correo']);
  }

  Map<String, dynamic> _mapa(dynamic valor) {
    if (valor is Map<String, dynamic>) {
      return valor;
    }

    if (valor is Map) {
      return Map<String, dynamic>.from(valor);
    }

    return {};
  }

  // Obtiene los documentos guardados en el perfil del guía.
  List<Map<String, dynamic>> _obtenerDocumentos(
    Map<String, dynamic> solicitud,
  ) {
    final certificados = _mapa(solicitud['certificados']);
    final documentos = <Map<String, dynamic>>[];

    final carne = _mapa(certificados['carneGuia']);

    if (carne.isNotEmpty) {
      documentos.add({
        'titulo': 'Carné de guía turístico',
        ...carne,
      });
    }

    final antecedentes = _mapa(
      certificados['antecedentesJudiciales'],
    );

    if (antecedentes.isNotEmpty) {
      documentos.add({
        'titulo': 'Antecedentes judiciales',
        ...antecedentes,
      });
    }

    final adicionales = certificados['adicionales'];

    if (adicionales is List) {
      for (final adicional in adicionales) {
        final documento = _mapa(adicional);

        if (documento.isNotEmpty) {
          documentos.add({
            'titulo': 'Documento adicional',
            ...documento,
          });
        }
      }
    }

    return documentos;
  }

  // Muestra el enlace del documento y permite copiarlo.
  Future<void> _mostrarDocumento(
    Map<String, dynamic> documento,
  ) async {
    final url = documento['url']?.toString() ?? '';

    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Este documento no tiene una URL disponible.',
          ),
        ),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_texto(documento['titulo'])),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Archivo: ${_texto(documento['nombre'])}'),
              const SizedBox(height: 12),
              const Text(
                'Enlace del documento:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              SelectableText(url),
              const SizedBox(height: 12),
              const Text(
                'Puedes copiar el enlace para abrirlo en el navegador. '
                'Esta pantalla no comprueba si el documento es legible.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cerrar'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(text: url),
              );

              if (!dialogContext.mounted) return;

              Navigator.of(dialogContext).pop();

              if (!mounted) return;

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Enlace copiado.'),
                ),
              );
            },
            icon: const Icon(Icons.copy),
            label: const Text('Copiar enlace'),
          ),
        ],
      ),
    );
  }

  // Pide un motivo para rechazar o solicitar correcciones.
  Future<String?> _pedirMotivo(String titulo) async {
    final controlador = TextEditingController();

    try {
      return await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(titulo),
          content: TextField(
            controller: controlador,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Escribe el motivo',
              border: OutlineInputBorder(),
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
                      content: Text(
                        'Debes escribir un motivo.',
                      ),
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
  Future<void> _aprobarSolicitud(String uid) async {
    try {
      await _guiaService.aprobarSolicitud(uid);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solicitud aprobada.'),
        ),
      );

      await _cargarSolicitudes();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo aprobar: $e'),
        ),
      );
    }
  }

  // Rechaza la solicitud indicando el motivo.
  Future<void> _rechazarSolicitud(String uid) async {
    final motivo = await _pedirMotivo('Rechazar solicitud');

    if (!mounted || motivo == null) return;

    try {
      await _guiaService.rechazarSolicitud(
        userId: uid,
        motivo: motivo,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solicitud rechazada.'),
        ),
      );

      await _cargarSolicitudes();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo rechazar: $e'),
        ),
      );
    }
  }

  // Solicita al guía que corrija los documentos enviados.
  Future<void> _solicitarCorrecciones(String uid) async {
    final motivo = await _pedirMotivo(
      'Solicitar correcciones',
    );

    if (!mounted || motivo == null) return;

    try {
      await _guiaService.solicitarCorrecciones(
        userId: uid,
        motivo: motivo,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Correcciones solicitadas correctamente.',
          ),
        ),
      );

      await _cargarSolicitudes();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudieron solicitar las correcciones: $e',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de Administración'),
        actions: [
          IconButton(
            tooltip: 'Usuarios',
            icon: const Icon(Icons.people_alt_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const GestionUsuariosScreen(),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Verificación de identidad',
            icon: const Icon(Icons.verified_user_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => VerificacionAdminScreen(),
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.report_problem_outlined),
            tooltip: 'Moderación de reportes',
            onSelected: (String opcion) {
              if (opcion == 'resenas') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ResenasReportadasAdminScreen(),
                  ),
                );
              } else if (opcion == 'publicaciones') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PublicacionesReportadasAdminScreen(),
                  ),
                );
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'resenas',
                child: Row(
                  children: <Widget>[
                    Icon(Icons.rate_review_outlined, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Reseñas reportadas (HU-33)'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'publicaciones',
                child: Row(
                  children: <Widget>[
                    Icon(Icons.photo_library_outlined, color: Colors.redAccent),
                    SizedBox(width: 8),
                    Text('Publicaciones reportadas (HU-34)'),
                  ],
                ),
              ),
            ],
          ),
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
              ? _construirError()
              : _solicitudes.isEmpty
                  ? _construirVacio()
                  : _construirLista(),
    );
  }

  Widget _construirError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 52,
              color: Colors.red,
            ),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _cargarSolicitudes,
              child: const Text('Intentar de nuevo'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _construirVacio() {
    return RefreshIndicator(
      onRefresh: _cargarSolicitudes,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 130),
          Icon(
            Icons.assignment_turned_in_outlined,
            size: 76,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Center(
            child: Text(
              'No hay solicitudes pendientes',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(height: 8),
          Center(
            child: Text(
              'Cuando un guía envíe sus certificados, '
              'aparecerán aquí.',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirLista() {
    return RefreshIndicator(
      onRefresh: _cargarSolicitudes,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _solicitudes.length,
        itemBuilder: (context, index) {
          final solicitud = _solicitudes[index];
          final uid = solicitud['uid']?.toString() ?? '';
          final documentos = _obtenerDocumentos(solicitud);

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const CircleAvatar(
                        child: Icon(Icons.person_outline),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _nombreGuia(solicitud),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Estado: ${_texto(solicitud['estadoCertificados'])}',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    'Identificador: ${uid.isEmpty ? "No disponible" : uid}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Divider(height: 28),
                  const Text(
                    'Documentos adjuntos',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (documentos.isEmpty)
                    const Text('No se encontraron documentos.')
                  else
                    ...documentos.map((documento) {
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.picture_as_pdf_outlined,
                        ),
                        title: Text(
                          _texto(documento['titulo']),
                        ),
                        subtitle: Text(
                          _texto(documento['nombre']),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          tooltip: 'Ver enlace del documento',
                          onPressed: () =>
                              _mostrarDocumento(documento),
                          icon: const Icon(
                            Icons.visibility_outlined,
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: 12),
                  const Text(
                    'Selecciona una acción para revisar esta solicitud.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: uid.isEmpty
                            ? null
                            : () => _aprobarSolicitud(uid),
                        icon: const Icon(
                          Icons.check_circle_outline,
                        ),
                        label: const Text('Aprobar'),
                      ),
                      OutlinedButton.icon(
                        onPressed: uid.isEmpty
                            ? null
                            : () => _solicitarCorrecciones(uid),
                        icon: const Icon(
                          Icons.edit_document,
                        ),
                        label: const Text(
                          'Solicitar correcciones',
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: uid.isEmpty
                            ? null
                            : () => _rechazarSolicitud(uid),
                        icon: const Icon(
                          Icons.cancel_outlined,
                        ),
                        label: const Text('Rechazar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
