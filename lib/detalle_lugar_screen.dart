import 'package:flutter/material.dart';
import 'lugares_service.dart';
import 'app_theme.dart';

class DetalleLugarScreen extends StatefulWidget {
  final Lugar lugar;

  const DetalleLugarScreen({super.key, required this.lugar});

  @override
  State<DetalleLugarScreen> createState() => _DetalleLugarScreenState();
}

class _DetalleLugarScreenState extends State<DetalleLugarScreen> {
  final LugaresService _lugaresService = LugaresService();
  List<Resena> _resenas = [];
  bool _cargandoResenas = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarResenas();
  }

  Future<void> _cargarResenas() async {
    try {
      final resenas = await _lugaresService.obtenerResenas(widget.lugar.id);
      if (mounted) {
        setState(() {
          _resenas = resenas;
          _cargandoResenas = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "No se pudieron cargar las reseñas.";
          _cargandoResenas = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: Text(widget.lugar.nombre)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImagenPrincipal(),
            const SizedBox(height: 20),
            Text(widget.lugar.nombre, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildUbicacion(),
            const SizedBox(height: 24),
            const Text('Descripción', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(widget.lugar.descripcion, style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.black)),
            const Divider(height: 60),
            
            // --- SECCIÓN DE RESEÑAS ---
            const Text('Reseñas de viajeros', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            if (_cargandoResenas)
              const Center(child: CircularProgressIndicator())
            else if (_resenas.isEmpty)
              const Text('Este lugar aún no tiene reseñas.', style: TextStyle(color: Colors.grey))
            else
              _buildListaResenas(),
          ],
        ),
      ),
    );
  }

  Widget _buildListaResenas() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _resenas.length,
      itemBuilder: (context, index) {
        final r = _resenas[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.black12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(r.nombreUsuario, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.azulPetroleo)),
                  Row(
                    children: List.generate(5, (i) => Icon(
                      Icons.star_rounded, 
                      size: 20, // Más grandes
                      color: i < r.calificacion ? Colors.orange : Colors.grey.shade300,
                    )),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // COMENTARIO FORZADO EN COLOR NEGRO
              Text(
                r.comentario, 
                style: const TextStyle(fontSize: 15, color: Colors.black, height: 1.4),
              ),
              const SizedBox(height: 10),
              Text(
                "${r.fecha.day}/${r.fecha.month}/${r.fecha.year}",
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildImagenPrincipal() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: widget.lugar.fotos.isNotEmpty 
        ? Image.network(widget.lugar.fotos.first, height: 250, width: double.infinity, fit: BoxFit.cover)
        : Container(height: 250, color: Colors.grey.shade200, child: const Icon(Icons.image_not_supported, size: 64)),
    );
  }

  Widget _buildUbicacion() {
    return Row(children: [const Icon(Icons.location_on, color: AppTheme.verdeAzulado, size: 18), const SizedBox(width: 4), Expanded(child: Text(widget.lugar.ubicacion, style: const TextStyle(color: Colors.grey)))]);
  }
}
