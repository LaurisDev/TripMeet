import 'package:flutter/material.dart';

import 'reportes_admin_service.dart';

/// Pantalla de administración para HU-33: Revisar reseñas reportadas.
class ResenasReportadasAdminScreen extends StatefulWidget {
  const ResenasReportadasAdminScreen({
    super.key,
    this.service,
  });

  final ReportesAdminService? service;

  @override
  State<ResenasReportadasAdminScreen> createState() =>
      _ResenasReportadasAdminScreenState();
}

class _ResenasReportadasAdminScreenState
    extends State<ResenasReportadasAdminScreen> {
  late final ReportesAdminService _service =
      widget.service ?? ReportesAdminService();

  List<ReporteResena> _reportes = <ReporteResena>[];
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
      final List<ReporteResena> resultado =
          await _service.obtenerResenasReportadas();
      if (!mounted) return;
      setState(() {
        _reportes = resultado;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudieron cargar las reseñas reportadas.';
        _cargando = false;
      });
    }
  }

  Future<void> _resolverReporte(
    ReporteResena reporte, {
    required bool eliminarResena,
  }) async {
    final bool? confirmado = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(
            eliminarResena ? '¿Eliminar reseña?' : '¿Descartar reporte?',
          ),
          content: Text(
            eliminarResena
                ? 'Esta acción eliminará la reseña reportada de forma permanente y resolverá el reporte.'
                : 'El reporte será ignorado/descartado y la reseña permanecerá publicada.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: eliminarResena ? Colors.red : Colors.grey[700],
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(eliminarResena ? 'Eliminar' : 'Descartar'),
            ),
          ],
        );
      },
    );

    if (confirmado != true) return;

    try {
      await _service.resolverReporteResena(
        reporteId: reporte.id,
        resenaId: reporte.resenaId,
        usuarioCalificadoUid: reporte.usuarioCalificadoUid,
        lugarId: reporte.lugarId,
        eliminarResena: eliminarResena,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            eliminarResena
                ? 'Reseña eliminada y reporte resuelto.'
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
        title: const Text('Reseñas reportadas'),
        actions: <Widget>[
          IconButton(
            key: const Key('recargar-resenas-reportadas'),
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
              'No hay reseñas reportadas pendientes',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(height: 8),
          Center(
            child: Text(
              'Todas las reseñas reportadas han sido revisadas.',
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
          final ReporteResena reporte = _reportes[index];
          return Card(
            key: Key('reporte-resena-${reporte.id}'),
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
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
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
                    'Contenido de la reseña:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: <Widget>[
                      Text(
                        reporte.autorResenaNombre,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        children: List<Widget>.generate(
                          5,
                          (int i) => Icon(
                            i < reporte.estrellas
                                ? Icons.star
                                : Icons.star_border,
                            size: 16,
                            color: Colors.amber,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '"${reporte.comentarioResena}"',
                    style: const TextStyle(fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      OutlinedButton.icon(
                        key: Key('descartar-resena-${reporte.id}'),
                        onPressed: () => _resolverReporte(
                          reporte,
                          eliminarResena: false,
                        ),
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('Descartar'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        key: Key('eliminar-resena-${reporte.id}'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        onPressed: () => _resolverReporte(
                          reporte,
                          eliminarResena: true,
                        ),
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Eliminar reseña'),
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
