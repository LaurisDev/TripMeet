import 'package:cloud_firestore/cloud_firestore.dart';

class Lugar {
  final String id;
  final String nombre;
  final String descripcion;
  final String categoria;
  final String ubicacion;
  final double latitud;
  final double longitud;
  final List<String> fotos;

  Lugar({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.categoria,
    required this.ubicacion,
    required this.latitud,
    required this.longitud,
    required this.fotos,
  });

  factory Lugar.fromFirestore(DocumentSnapshot<Map<String, dynamic>> documento) {
    final datos = documento.data() ?? {};
    return Lugar(
      id: documento.id,
      nombre: datos['nombre'] as String? ?? '',
      descripcion: datos['descripcion'] as String? ?? '',
      categoria: datos['categoria'] as String? ?? 'Otros',
      ubicacion: datos['Ubicacion'] as String? ?? '', 
      latitud: (datos['latitud'] as num?)?.toDouble() ?? 0.0,
      longitud: (datos['longitud'] as num?)?.toDouble() ?? 0.0,
      fotos: (datos['Fotos'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}

class LugaresService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Lugar>> obtenerLugares() async {
    final snapshot = await _firestore.collection('Lugares').get();
    return snapshot.docs.map(Lugar.fromFirestore).toList();
  }

  Future<List<Lugar>> buscarLugares(String texto, {String? categoria}) async {
    final consulta = texto.trim().toLowerCase();
    final snapshot = await _firestore.collection('Lugares').get();
    var lugares = snapshot.docs.map((doc) => Lugar.fromFirestore(doc)).toList();

    if (consulta.isNotEmpty) {
      lugares = lugares.where((l) => l.nombre.toLowerCase().contains(consulta)).toList();
    }
    if (categoria != null && categoria != 'Todos') {
      lugares = lugares.where((l) => l.categoria.toLowerCase() == categoria.toLowerCase()).toList();
    }
    return lugares;
  }

  Future<List<Resena>> obtenerResenas(String lugarId) async {
    try {
      final snapshot = await _firestore
          .collection('Lugares')
          .doc(lugarId)
          .collection('Reseñas') 
          .orderBy('fecha', descending: true)
          .get();
      
      return snapshot.docs.map((doc) => Resena.fromFirestore(doc)).toList();
    } catch (e) {
      rethrow;
    }
  }
}

class Resena {
  final String nombreUsuario; 
  final String comentario;
  final double calificacion;
  final DateTime fecha;

  Resena({
    required this.nombreUsuario,
    required this.comentario,
    required this.calificacion,
    required this.fecha,
  });

  factory Resena.fromFirestore(DocumentSnapshot doc) {
    final datos = doc.data() as Map<String, dynamic>;
    
    // --- MEJORA: Detección inteligente de tipos ---
    dynamic cal = datos['calificacion'] ?? 0;
    double calFinal = 0;
    if (cal is num) {
      calFinal = cal.toDouble();
    } else if (cal is String) {
      calFinal = double.tryParse(cal) ?? 0;
    }

    return Resena(
      nombreUsuario: datos['nombreUsuario']?.toString() ?? 'Anónimo',
      comentario: datos['comentario']?.toString() ?? 'Sin comentario',
      calificacion: calFinal,
      fecha: (datos['fecha'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

typedef LugarService = LugaresService;
