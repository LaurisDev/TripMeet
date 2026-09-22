import 'package:cloud_firestore/cloud_firestore.dart';
import 'lugares_service.dart';

class RecomendacionesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LugaresService _lugaresService = LugaresService();

  /// El algoritmo de recomendación: 
  /// 1. Busca las categorías preferidas del usuario.
  /// 2. Filtra lugares que coincidan.
  /// 3. Calcula un "Ranking" basado en calificación y coincidencia.
  Future<List<Lugar>> obtenerRecomendacionesPersonalizadas(String userId) async {
    try {
      // 1. Obtener preferencias del usuario desde Firestore
      final userDoc = await _firestore.collection('usuarios').doc(userId).get();
      List<String> preferencias = [];
      
      if (userDoc.exists && userDoc.data()!.containsKey('preferencias')) {
        preferencias = List<String>.from(userDoc.data()!['preferencias']);
      } else {
        // Si no tiene preferencias, usamos categorías populares por defecto
        preferencias = ['Playa', 'Aventura', 'Cultura'];
      }

      // 2. Obtener todos los lugares disponibles
      final snapshot = await _firestore.collection('Lugares').get();
      List<Lugar> todosLosLugares = snapshot.docs.map((doc) => Lugar.fromFirestore(doc)).toList();

      // 3. Algoritmo de Ranking
      List<Map<String, dynamic>> ranking = [];

      for (var lugar in todosLosLugares) {
        double score = 0;

        // +5 puntos si el lugar coincide con una categoría favorita
        if (preferencias.contains(lugar.categoria)) {
          score += 5.0;
        }

        // Sumamos las reseñas promedio (HU-08) al puntaje (0 a 5 puntos extra)
        final resenas = await _lugaresService.obtenerResenas(lugar.id);
        if (resenas.isNotEmpty) {
          double promedio = resenas.fold(0.0, (p, e) => p + e.calificacion) / resenas.length;
          score += promedio;
        }

        ranking.add({'lugar': lugar, 'score': score});
      }

      // 4. Ordenar de mayor a menor puntaje
      ranking.sort((a, b) => b['score'].compareTo(a['score']));

      // Retornar los top 5 lugares recomendados
      return ranking.map((e) => e['lugar'] as Lugar).take(5).toList();
      
    } catch (e) {
      print('Error en el motor de recomendaciones: $e');
      return [];
    }
  }
}
