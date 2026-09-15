import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'lugares_service.dart';
import 'app_theme.dart';

class DetalleLugarScreen extends StatefulWidget {
  final Lugar lugar;

  const DetalleLugarScreen({
    super.key,
    required this.lugar,
  });

  @override
  State<DetalleLugarScreen> createState() => _DetalleLugarScreenState();
}

class _DetalleLugarScreenState extends State<DetalleLugarScreen> {
  final LugaresService _lugaresService = LugaresService();
  final TextEditingController _comentarioController = TextEditingController();
  List<Resena> _resenas = [];
  bool _cargandoResenas = true;
  double _estrellasSeleccionadas = 5;

  @override
  void initState() {
    super.initState();
    _cargarResenas();
  }

  Future<void> _cargarResenas() async {
    try {
      final resenas = await _lugaresService.obtenerResenas(widget.lugar.id);
      setState(() {
        _resenas = resenas;
        _cargandoResenas = false;
      });
    } catch (e) {
      setState(() => _cargandoResenas = false);
    }
  }

  Future<void> _guardarResena(BuildContext context) async {
    if (_comentarioController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, escribe un comentario')),
      );
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('Lugares')
          .doc(widget.lugar.id)
          .collection('Resenas')
          .add({
        'usuario': 'Viajero', 
        'comentario': _comentarioController.text.trim(),
        'calificacion': _estrellasSeleccionadas,
        'fecha': FieldValue.serverTimestamp(),
      });

      _comentarioController.clear();
      if (mounted) Navigator.pop(context);
      _cargarResenas(); 
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al guardar tu reseña')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool tieneDescripcion = widget.lugar.descripcion.trim().isNotEmpty;
    final bool tieneFotos = widget.lugar.fotos.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostrarFormularioResena(context),
        backgroundColor: AppTheme.verdeAzulado,
        icon: const Icon(Icons.rate_review_rounded, color: Colors.white),
        label: const Text('Calificar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: CustomScrollView(
        slivers: [
          // CABECERA COLAPSABLE PREMIUM (Anderson)
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  _imagenPrincipal(tieneFotos),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black45],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                backgroundColor: Colors.black26,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Categoría
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.azulPetroleo.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(widget.lugar.categoria, style: TextStyle(color: AppTheme.azulPetroleo, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  const SizedBox(height: 16),
                  
                  // Nombre del Lugar
                  Text(widget.lugar.nombre, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  
                  const SizedBox(height: 16),

                  // Ubicación con Diseño de Juan (Integrado)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.verdeAzulado.withOpacity(0.1)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.verdeAzulado.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.location_on, color: AppTheme.verdeAzulado, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Ubicación', style: TextStyle(color: AppTheme.azulPetroleo, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 3),
                              Text(widget.lugar.ubicacion.isEmpty ? 'No disponible' : widget.lugar.ubicacion, 
                                style: const TextStyle(color: Colors.black54)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                  const Text('Sobre este lugar', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text(tieneDescripcion ? widget.lugar.descripcion : 'Sin descripción.', 
                    style: const TextStyle(fontSize: 16, height: 1.6, color: Colors.black87)),
                  
                  const SizedBox(height: 32),
                  _seccionFotos(context, tieneFotos),
                  
                  const SizedBox(height: 40),
                  
                  // --- SECCIÓN DE RESEÑAS INNOVADORA (Anderson) ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Experiencias', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      if (_resenas.isNotEmpty)
                        _badgeCalificacion(),
                    ],
                  ),
                  const SizedBox(height: 20),

                  if (_cargandoResenas)
                    const Center(child: CircularProgressIndicator())
                  else if (_resenas.isEmpty)
                    const Center(child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Text('Nadie ha comentado aún. ¡Sé el primero!'),
                    ))
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _resenas.length,
                      itemBuilder: (context, index) => _tarjetaResenaModerna(_resenas[index]),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarFormularioResena(BuildContext context) {
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
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => _guardarResena(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.azulPetroleo,
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: const Text('Publicar Comentario', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badgeCalificacion() {
    double suma = _resenas.fold(0, (p, e) => p + e.calificacion);
    double promedio = double.parse((suma / _resenas.length).toStringAsFixed(1));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(8)),
      child: Row(children: [const Icon(Icons.star, color: Colors.amber, size: 18), const SizedBox(width: 4), Text('$promedio', style: const TextStyle(fontWeight: FontWeight.bold))]),
    );
  }

  Widget _tarjetaResenaModerna(Resena r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFFFBFBFB), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.black.withOpacity(0.03))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(backgroundColor: AppTheme.verdeAzulado.withOpacity(0.1), child: Text(r.usuario.isNotEmpty ? r.usuario[0] : 'U', style: const TextStyle(fontWeight: FontWeight.bold))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(r.usuario, style: const TextStyle(fontWeight: FontWeight.bold)), const Text('Viajero verificado', style: TextStyle(color: Colors.grey, fontSize: 12))])),
              Row(children: List.generate(5, (i) => Icon(Icons.star_rounded, size: 16, color: i < r.calificacion ? Colors.amber : Colors.grey.shade300))),
            ],
          ),
          const SizedBox(height: 12),
          Text(r.comentario, style: const TextStyle(color: Colors.black87, height: 1.4)),
        ],
      ),
    );
  }

  Widget _imagenPrincipal(bool tieneFotos) {
    return tieneFotos ? Image.network(widget.lugar.fotos.first, fit: BoxFit.cover) : Container(color: Colors.grey.shade200, child: const Icon(Icons.image_not_supported_outlined, size: 64));
  }

  Widget _seccionFotos(BuildContext context, bool tieneFotos) {
    if (!tieneFotos) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Galería', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        SizedBox(height: 150, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: widget.lugar.fotos.length, separatorBuilder: (_, __) => const SizedBox(width: 12), itemBuilder: (context, index) => ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.network(widget.lugar.fotos[index], width: 220, fit: BoxFit.cover)))),
      ],
    );
  }
}
