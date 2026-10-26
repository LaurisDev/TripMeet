import 'package:flutter/material.dart';

import 'reportes_admin_service.dart';

/// Pantalla de administración para HU-34: Revisar publicaciones reportadas.
class PublicacionesReportadasAdminScreen extends StatefulWidget {
  const PublicacionesReportadasAdminScreen({
    super.key,
    this.service,
  });

  final ReportesAdminService? service;

  @override
  State<PublicacionesReportadasAdminScreen> createState() =>
      _PublicacionesReportadasAdminScreenState();
}

class _PublicacionesReportadasAdminScreenState
    extends State<PublicacionesReportadasAdminScreen> {
  late final ReportesAdminService _service =
      widget.service ?? ReportesAdminService();

  List<ReportePublicacion> _reportes = <ReportePublicacion>[];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarReportes();
  }

  Future<void> _cargarReportes() async {
    if (!mounted) return;
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final List<ReportePublicacion> resultado =
          await _service.obtenerPublicacionesReportadas();
      if (!mounted) return;
      setState(() {
        _reportes = resultado;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudieron cargar las publicaciones reportadas.';
        _cargando = false;
      });
    }
  }

  Future<void> _resolverReporte(
    ReportePublicacion reporte, {
    required bool eliminarPublicacion,
  }) async {
    final bool? confirmado = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(
            eliminarPublicacion
                ? '¿Eliminar publicación?'
                : '¿Descartar reporte?',
          ),
          content: Text(
            eliminarPublicacion
                ? 'Esta acción eliminará la publicación reportada del feed de forma permanente.'
                : 'El reporte será ignorado/descartado y la publicación seguirá visible.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor:
                    eliminarPublicacion ? Colors.red : Colors.grey[700],
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(eliminarPublicacion ? 'Eliminar' : 'Descartar'),
            ),
          ],
        );
      },
    );

    if (confirmado != true) return;

    try {
      await _service.resolverReportePublicacion(
        reporteId: reporte.id,
        publicacionId: reporte.publicacionId,
        eliminarPublicacion: eliminarPublicacion,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            eliminarPublicacion
                ? 'Publicación eliminada y reporte resuelto.'
                : 'Reporte descartado.',
          ),
        ),
      );

      _cargarReportes();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al procesar el reporte: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Publicaciones reportadas'),
        actions: <Widget>[
          IconButton(
            key: const Key('recargar-publicaciones-reportadas'),
            icon: const Icon(Icons.refresh),
            onPressed: _cargando ? null : _cargarReportes,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorView()
              : _reportes.isEmpty
                  ? _buildEmptyView()
                  : _buildListView(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(_error ?? 'Ocurrió un error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _cargarReportes,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return RefreshIndicator(
      onRefresh: _cargarReportes,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const <Widget>[
          SizedBox(height: 100),
          Icon(Icons.check_circle_outline, size: 72, color: Colors.green),
          SizedBox(height: 16),
          Center(
            child: Text(
              'No hay publicaciones reportadas pendientes',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(height: 8),
          Center(
            child: Text(
              'Todas las publicaciones reportadas han sido revisadas.',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListView() {
    return RefreshIndicator(
      onRefresh: _cargarReportes,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _reportes.length,
        itemBuilder: (BuildContext context, int index) {
          final ReportePublicacion reporte = _reportes[index];
          return Card(
            key: Key('reporte-publicacion-${reporte.id}'),
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Icon(Icons.warning_amber_rounded,
                          color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Reportado por: ${reporte.reportadoPorNombre}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Text(
                        '${reporte.fecha.day}/${reporte.fecha.month}/${reporte.fecha.year}',
                        style:
                            TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          'Motivo del reporte:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(reporte.motivo),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Publicación reportada:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  if (reporte.imagenUrl != null &&
                      reporte.imagenUrl!.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        reporte.imagenUrl!,
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 100,
                          color: Colors.grey.shade200,
                          child: const Center(
                            child: Icon(Icons.broken_image, color: Colors.grey),
                          ),
                        ),
                      ),
                    ),
                  if (reporte.descripcionPublicacion != null &&
                      reporte.descripcionPublicacion!.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      reporte.descripcionPublicacion!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      OutlinedButton.icon(
                        key: Key('descartar-publicacion-${reporte.id}'),
                        onPressed: () => _resolverReporte(
                          reporte,
                          eliminarPublicacion: false,
                        ),
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('Descartar'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        key: Key('eliminar-publicacion-${reporte.id}'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        onPressed: () => _resolverReporte(
                          reporte,
                          eliminarPublicacion: true,
                        ),
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Eliminar publicación'),
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
