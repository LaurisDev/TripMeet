import 'package:cloud_firestore/cloud_firestore.dart';

class Lugar {
  final String id;
  final String nombre;
  final String descripcion;
  final String ubicacion;
  final List<String> fotos;

  Lugar({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.ubicacion,
    required this.fotos,
  });

  factory Lugar.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> documento,
  ) {
    final datos = documento.data() ?? {};

    return Lugar(
      id: documento.id,
      nombre: datos['nombre'] as String? ?? '',
      descripcion: datos['descripcion'] as String? ?? '',
      ubicacion: datos['Ubicacion'] as String? ?? '',
      fotos: List<String>.from(datos['Fotos'] ?? []),
    );
  }
}

class LugaresService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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