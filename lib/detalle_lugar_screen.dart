import 'package:flutter/material.dart';
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
  List<Resena> _resenas = [];
  bool _cargandoResenas = true;

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
      setState(() {
        _cargandoResenas = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool tieneDescripcion = widget.lugar.descripcion.trim().isNotEmpty;
    final bool tieneFotos = widget.lugar.fotos.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // CABECERA COLAPSABLE CON IMAGEN (Diseño Premium)
          SliverAppBar(
            expandedHeight: 350,
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
                        colors: [Colors.transparent, Colors.black54],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            leading: CircleAvatar(
              backgroundColor: Colors.white.withOpacity(0.3),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Categoría con estilo badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.verdeAzulado.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.lugar.categoria.toUpperCase(),
                      style: TextStyle(
                        color: AppTheme.verdeAzulado,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.lugar.nombre,
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.redAccent, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        widget.lugar.ubicacion,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  const Text('Sobre este lugar', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text(
                    tieneDescripcion ? widget.lugar.descripcion : 'Sin descripción disponible.',
                    style: TextStyle(fontSize: 16, color: Colors.black87, height: 1.6),
                  ),
                  const SizedBox(height: 32),
                  _seccionFotos(context, tieneFotos),
                  const SizedBox(height: 40),
                  
                  // --- SECCIÓN DE RESEÑAS INNOVADORA (HU-08) ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Experiencias', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      if (_resenas.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            children: [
                              const Icon(Icons.star, color: Colors.amber, size: 18),
                              const SizedBox(width: 4),
                              Text('${_calcularPromedio()}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  if (_cargandoResenas)
                    const Center(child: CircularProgressIndicator())
                  else if (_resenas.isEmpty)
                    _pantallaVaciaResenas()
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _resenas.length,
                      itemBuilder: (context, index) {
                        final r = _resenas[index];
                        return _tarjetaResenaModerna(r);
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _calcularPromedio() {
    if (_resenas.isEmpty) return 0.0;
    double suma = _resenas.fold(0, (prev, element) => prev + element.calificacion);
    return double.parse((suma / _resenas.length).toStringAsFixed(1));
  }

  Widget _tarjetaResenaModerna(Resena r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFBFB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withOpacity(0.03)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppTheme.azulPetroleo.withOpacity(0.1),
                child: Text(r.usuario[0].toUpperCase(), style: TextStyle(color: AppTheme.azulPetroleo, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.usuario, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('Viajero verificado', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                  ],
                ),
              ),
              Row(
                children: List.generate(5, (i) => Icon(
                  Icons.star_rounded,
                  size: 18,
                  color: i < r.calificacion ? Colors.amber : Colors.grey.shade300,
                )),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            r.comentario,
            style: TextStyle(color: Colors.black87.withOpacity(0.8), height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _pantallaVaciaResenas() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withOpacity(0.05), style: BorderStyle.none),
      ),
      child: const Column(
        children: [
          Icon(Icons.chat_bubble_outline_rounded, size: 40, color: Colors.grey),
          SizedBox(height: 12),
          Text('Nadie ha comentado aún', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
          Text('¡Sé el primero en calificar este lugar!', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _imagenPrincipal(bool tieneFotos) {
    if (!tieneFotos) {
      return Container(
        color: Colors.grey.shade200,
        alignment: Alignment.center,
        child: const Icon(Icons.image_not_supported_outlined, size: 64, color: Colors.grey),
      );
    }
    return Image.network(widget.lugar.fotos.first, fit: BoxFit.cover);
  }

  Widget _seccionFotos(BuildContext context, bool tieneFotos) {
    if (!tieneFotos) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Galería', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: widget.lugar.fotos.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) => ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(widget.lugar.fotos[index], width: 220, fit: BoxFit.cover),
            ),
          ),
        ),
      ],
    );
  }
}
