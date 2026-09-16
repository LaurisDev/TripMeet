import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  final TextEditingController _comentarioController = TextEditingController();
  List<Resena> _resenas = [];
  bool _cargandoResenas = true;
  bool _guardando = false;
  double _estrellasSeleccionadas = 5;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarResenas();
  }

  Future<void> _cargarResenas() async {
    setState(() {
      _cargandoResenas = true;
      _error = null;
    });
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

  Future<void> _guardarResena(BuildContext context, Function setModalState) async {
    if (_comentarioController.text.trim().isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    final String nombreUsuario = user?.email?.split('@')[0] ?? 'Viajero';
    
    setModalState(() => _guardando = true);
    try {
      await FirebaseFirestore.instance
          .collection('Lugares')
          .doc(widget.lugar.id)
          .collection('Reseñas') // Nombre exacto con R mayúscula
          .add({
        'usuarioId': user?.uid ?? '',
        'nombreUsuario': nombreUsuario, 
        'comentario': _comentarioController.text.trim(),
        'calificacion': _estrellasSeleccionadas,
        'fecha': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      _comentarioController.clear();
      Navigator.pop(context);
      _cargarResenas(); 
    } catch (e) {
      if (mounted) {
        setModalState(() => _guardando = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool tieneDescripcion = widget.lugar.descripcion.trim().isNotEmpty;
    final bool tieneFotos = widget.lugar.fotos.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Detalle del lugar')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostrarFormularioResena(context),
        backgroundColor: AppTheme.verdeAzulado,
        icon: const Icon(Icons.rate_review_rounded, color: Colors.white),
        label: const Text('Calificar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImagenPrincipal(tieneFotos),
            const SizedBox(height: 20),
            Text(widget.lugar.nombre, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildUbicacion(),
            const SizedBox(height: 24),
            const Text('Descripción', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(tieneDescripcion ? widget.lugar.descripcion : 'Sin descripción.', 
              style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.black87)),
            const SizedBox(height: 32),
            _seccionFotos(tieneFotos),
            const Divider(height: 60),
            _buildEncabezadoResenas(),
            const SizedBox(height: 20),
            if (_cargandoResenas)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              _buildErrorCase()
            else if (_resenas.isEmpty)
              const Center(child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('Este lugar aún no tiene reseñas.', style: TextStyle(color: Colors.grey)),
              ))
            else
              _buildListaResenas(),
          ],
        ),
      ),
    );
  }

  Widget _buildEncabezadoResenas() {
    double promedio = 0;
    if (_resenas.isNotEmpty) {
      promedio = _resenas.fold(0.0, (p, e) => p + e.calificacion) / _resenas.length;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Reseñas', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.star, color: Colors.amber, size: 24),
            const SizedBox(width: 4),
            Text(promedio.toStringAsFixed(1), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Text('(${_resenas.length} opiniones)', style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ],
    );
  }

  Widget _buildListaResenas() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _resenas.length,
      itemBuilder: (context, index) {
        final r = _resenas[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(r.nombreUsuario, style: const TextStyle(fontWeight: FontWeight.bold)),
                    Row(
                      children: List.generate(5, (i) => Icon(
                        Icons.star_rounded, 
                        size: 16, 
                        color: i < r.calificacion ? Colors.amber : Colors.grey.shade300
                      )),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(r.comentario, style: const TextStyle(color: Colors.black87)),
                const SizedBox(height: 12),
                Text("${r.fecha.day}/${r.fecha.month}/${r.fecha.year}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
        );
      },
    );
  }

  void _mostrarFormularioResena(BuildContext context) {
    _guardando = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('¿Cómo fue tu viaje?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) => IconButton(
                  onPressed: () => setModalState(() => _estrellasSeleccionadas = index + 1.0),
                  icon: Icon(Icons.star_rounded, size: 40, color: index < _estrellasSeleccionadas ? Colors.amber : Colors.grey.shade300),
                )),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _comentarioController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Cuéntanos tu experiencia...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _guardando ? null : () => _guardarResena(context, setModalState),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.azulPetroleo, minimumSize: const Size(double.infinity, 55)),
                child: _guardando ? const CircularProgressIndicator(color: Colors.white) : const Text('Publicar', style: TextStyle(color: Colors.white)),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorCase() => Center(child: Column(children: [Text(_error!, style: const TextStyle(color: Colors.red)), TextButton(onPressed: _cargarResenas, child: const Text('Reintentar'))]));

  Widget _buildImagenPrincipal(bool tieneFotos) => ClipRRect(borderRadius: BorderRadius.circular(20), child: tieneFotos ? Image.network(widget.lugar.fotos.first, height: 250, width: double.infinity, fit: BoxFit.cover) : Container(height: 250, color: Colors.grey.shade200, child: const Icon(Icons.image_not_supported, size: 64)));

  Widget _buildUbicacion() => Row(children: [const Icon(Icons.location_on, color: AppTheme.verdeAzulado, size: 18), const SizedBox(width: 4), Expanded(child: Text(widget.lugar.ubicacion, style: const TextStyle(color: Colors.grey)))]);

  Widget _seccionFotos(bool tieneFotos) {
    if (!tieneFotos) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Galería', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 12), SizedBox(height: 120, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: widget.lugar.fotos.length, separatorBuilder: (_, __) => const SizedBox(width: 12), itemBuilder: (context, index) => ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(widget.lugar.fotos[index], width: 180, fit: BoxFit.cover))))]);
  }
}
