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

  // HU-08: Leer reseñas desde la SUBCOLECCIÓN exacta de tu imagen (Reseñas con R mayúscula)
  Future<List<Resena>> obtenerResenas(String lugarId) async {
    try {
      print("🚀 Intentando leer de: Lugares/$lugarId/Reseñas");
      
      final snapshot = await _firestore
          .collection('Lugares')
          .doc(lugarId)
          .collection('Reseñas') // Nombre exacto de tu captura de pantalla
          .get();

      print("✅ ¡ÉXITO! Se encontraron ${snapshot.docs.length} reseñas.");
      
      return snapshot.docs.map((doc) => Resena.fromFirestore(doc)).toList();
    } catch (e) {
      print("🚨 ERROR EN FIREBASE: $e");
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
    return Resena(
      nombreUsuario: datos['nombreUsuario'] ?? 'Anónimo',
      comentario: datos['comentario'] ?? '',
      calificacion: (datos['calificacion'] ?? 0).toDouble(),
      fecha: (datos['fecha'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

typedef LugarService = LugaresService;
