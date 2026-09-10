import 'package:cloud_firestore/cloud_firestore.dart';

class Lugar {
  final String id;
  final String nombre;
  final String descripcion;
  final String ubicacion;
  final String categoria; // Agregado para HU-07
  final List<String> fotos;

  Lugar({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.ubicacion,
    required this.categoria,
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
      categoria: datos['categoria'] as String? ?? 'Otros', // Agregado
      fotos: List<String>.from(datos['Fotos'] ?? []),
    );
  }
}

class LugaresService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Modificado para soportar filtro opcional por categoría
  Future<List<Lugar>> buscarLugares(String texto, {String? categoria}) async {
    final consulta = texto.trim().toLowerCase();

    final snapshot = await _firestore
        .collection('Lugares')
        .get()
        .timeout(const Duration(seconds: 10));

    var lugares = snapshot.docs.map((doc) => Lugar.fromFirestore(doc)).toList();

    // Filtrar por texto si existe
    if (consulta.isNotEmpty) {
      lugares = lugares.where((l) => l.nombre.toLowerCase().contains(consulta)).toList();
    }

    // Filtrar por categoría si el usuario seleccionó una (HU-07)
    if (categoria != null && categoria != 'Todos') {
      lugares = lugares.where((l) => l.categoria == categoria).toList();
    }

    return lugares;
  }

  // HU-08: Obtener reseñas de un lugar
  Future<List<Resena>> obtenerResenas(String lugarId) async {
    final snapshot = await _firestore
        .collection('Lugares')
        .doc(lugarId)
        .collection('Resenas')
        .orderBy('fecha', descending: true)
        .get();

    return snapshot.docs.map((doc) => Resena.fromFirestore(doc)).toList();
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

// HU-08: Modelo de Reseña
class Resena {
  final String usuario;
  final String comentario;
  final double calificacion;
  final DateTime fecha;

  Resena({
    required this.usuario,
    required this.comentario,
    required this.calificacion,
    required this.fecha,
  });

  factory Resena.fromFirestore(DocumentSnapshot doc) {
    final datos = doc.data() as Map<String, dynamic>;
    return Resena(
      usuario: datos['usuario'] ?? 'Anónimo',
      comentario: datos['comentario'] ?? '',
      calificacion: (datos['calificacion'] ?? 0).toDouble(),
      fecha: (datos['fecha'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
