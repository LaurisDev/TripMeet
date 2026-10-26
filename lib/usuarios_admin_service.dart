import 'package:cloud_firestore/cloud_firestore.dart';

import 'perfil_usuario_screen.dart' show PerfilPublico;

/// Usuarios por página en el panel de gestión de usuarios.
const int usuariosPorPagina = 20;

/// Un usuario tal como lo ve el administrador en el listado (HU-30).
class UsuarioListado {
  const UsuarioListado({
    required this.uid,
    required this.nombre,
    required this.correo,
    this.rol,
    this.fechaRegistro,
  });

  final String uid;

  /// `nombre` del perfil o, si no tiene, la parte del correo antes de la @
  /// (el mismo nombre visible del perfil).
  final String nombre;

  /// Correo registrado; vacío si el perfil no lo tiene.
  final String correo;

  /// "Turista" o "Guía turístico"; `null` si no tiene un rol conocido.
  final String? rol;
  final DateTime? fechaRegistro;

  factory UsuarioListado.desdeDocumento(
    DocumentSnapshot<Map<String, dynamic>> documento,
  ) {
    final Map<String, dynamic> datos = documento.data() ?? <String, dynamic>{};
    final PerfilPublico perfil = PerfilPublico(datos);
    final dynamic correo = datos['correo'];
    return UsuarioListado(
      uid: documento.id,
      nombre: perfil.nombre,
      correo: correo is String ? correo.trim() : '',
      rol: perfil.rol,
      fechaRegistro: (datos['fechaCreacion'] as Timestamp?)?.toDate(),
    );
  }
}

/// Una página del listado: los usuarios de esa página y el total.
class PaginaUsuarios {
  const PaginaUsuarios({
    required this.usuarios,
    required this.pagina,
    required this.totalPaginas,
    required this.totalUsuarios,
  });

  final List<UsuarioListado> usuarios;

  /// Página actual, empezando en 1.
  final int pagina;
  final int totalPaginas;
  final int totalUsuarios;

  bool get hayAnterior => pagina > 1;
  bool get haySiguiente => pagina < totalPaginas;
}

/// Excepción con un mensaje seguro para mostrar en la interfaz.
class UsuariosAdminException implements Exception {
  const UsuariosAdminException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

/// Consulta de usuarios para el panel del administrador (HU-30): listado
/// completo, búsqueda por nombre o correo y paginación.
///
/// Firestore no permite buscar "contiene" ni ignorar mayúsculas y tildes,
/// así que se leen los perfiles de `usuarios` una vez y la búsqueda y la
/// paginación se hacen en la app. Es adecuado para cientos o pocos miles
/// de usuarios; con muchos más convendría guardar campos normalizados y
/// buscar por prefijo en el servidor.
class UsuariosAdminService {
  UsuariosAdminService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Todos los usuarios registrados, ordenados por nombre (y por correo si
  /// el nombre coincide).
  Future<List<UsuarioListado>> obtenerUsuarios() async {
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('usuarios')
          .get();
      final List<UsuarioListado> usuarios = snapshot.docs
          .map(UsuarioListado.desdeDocumento)
          .toList();
      usuarios.sort((UsuarioListado a, UsuarioListado b) {
        final int porNombre = normalizar(a.nombre)
            .compareTo(normalizar(b.nombre));
        return porNombre != 0
            ? porNombre
            : normalizar(a.correo).compareTo(normalizar(b.correo));
      });
      return usuarios;
    } on FirebaseException catch (error) {
      throw UsuariosAdminException(
        error.code == 'permission-denied'
            ? 'No tienes permiso para ver los usuarios.'
            : 'No se pudieron cargar los usuarios. Inténtalo de nuevo.',
        code: error.code,
      );
    }
  }

  /// Minúsculas y sin tildes, para comparar y buscar.
  static String normalizar(String texto) {
    const Map<String, String> sinTilde = <String, String>{
      'á': 'a',
      'é': 'e',
      'í': 'i',
      'ó': 'o',
      'ú': 'u',
      'ü': 'u',
      'ñ': 'n',
    };
    final StringBuffer salida = StringBuffer();
    for (final String c in texto.trim().toLowerCase().split('')) {
      salida.write(sinTilde[c] ?? c);
    }
    return salida.toString();
  }

  /// Usuarios cuyo nombre o correo contienen [consulta], sin distinguir
  /// mayúsculas ni tildes. Una consulta vacía devuelve todos.
  static List<UsuarioListado> filtrar(
    List<UsuarioListado> usuarios,
    String consulta,
  ) {
    final String buscado = normalizar(consulta);
    if (buscado.isEmpty) return usuarios;
    return <UsuarioListado>[
      for (final UsuarioListado u in usuarios)
        if (normalizar(u.nombre).contains(buscado) ||
            normalizar(u.correo).contains(buscado))
          u,
    ];
  }

  /// La página [pagina] (desde 1) de [usuarios], de [tamano] en [tamano].
  /// Si [pagina] se sale del rango, se ajusta a la primera o la última.
  static PaginaUsuarios paginar(
    List<UsuarioListado> usuarios,
    int pagina, {
    int tamano = usuariosPorPagina,
  }) {
    final int totalPaginas = usuarios.isEmpty
        ? 1
        : (usuarios.length / tamano).ceil();
    final int actual = pagina.clamp(1, totalPaginas);
    final int inicio = (actual - 1) * tamano;
    return PaginaUsuarios(
      usuarios: usuarios.skip(inicio).take(tamano).toList(),
      pagina: actual,
      totalPaginas: totalPaginas,
      totalUsuarios: usuarios.length,
    );
  }
}
