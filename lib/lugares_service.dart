import 'package:cloud_firestore/cloud_firestore.dart';

class Lugar {
  final String nombre;
  final String descripcion;
  final String categoria;
  final String ubicacion;
  final double latitud;
  final double longitud;
  final List<String> fotos;

  Lugar({
    required this.nombre,
    required this.descripcion,
    required this.categoria,
    required this.ubicacion,
    required this.latitud,
    required this.longitud,
    required this.fotos,
  });

  factory Lugar.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> documento,
  ) {
    final datos = documento.data() ?? {};

    return Lugar(
      nombre: datos['nombre'] as String? ?? '',
      descripcion: datos['descripcion'] as String? ?? '',
      categoria: datos['categoria'] as String? ?? '',
      ubicacion: datos['Ubicacion'] as String? ?? '',
      latitud: datos['latitud'] == null
          ? 0.0
          : (datos['latitud'] as num).toDouble(),
      longitud: datos['longitud'] == null
          ? 0.0
          : (datos['longitud'] as num).toDouble(),
      fotos: datos['Fotos'] == null
          ? []
          : (datos['Fotos'] as List<dynamic>)
              .map((elemento) => elemento.toString())
              .toList(),
    );
  }
}

class LugarService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Lugar>> obtenerLugares() async {
    final snapshot = await _firestore
        .collection('Lugares')
        .get()
        .timeout(const Duration(seconds: 10));

    return snapshot.docs.map(Lugar.fromFirestore).toList();
  }

  Future<List<Lugar>> buscarLugares(String texto) async {
    final consulta = texto.trim().toLowerCase();

    if (consulta.isEmpty) {
      return [];
    }

    final snapshot = await _firestore
        .collection('Lugares')
        .get()
        .timeout(const Duration(seconds: 10));

    return snapshot.docs
        .map((documento) => Lugar.fromFirestore(documento))
        .where(
          (lugar) => lugar.nombre.toLowerCase().contains(consulta),
        )
        .toList();
  }

  Future<Lugar?> obtenerLugar(String id) async {
    final documento =
        await _firestore.collection('Lugares').doc(id).get();

    if (!documento.exists) {
      return null;
    }

    return Lugar.fromFirestore(documento);
  }
}

typedef LugaresService = LugarService;