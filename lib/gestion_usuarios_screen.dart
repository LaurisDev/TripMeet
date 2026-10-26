import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'form_styles.dart';
import 'perfil_usuario_screen.dart';
import 'usuarios_admin_service.dart';
import 'widgets/aviso_error.dart';

/// Panel del administrador (HU-30): listado completo de usuarios registrados,
/// paginado, con búsqueda por nombre o correo. Al tocar un usuario se abre
/// su perfil.
class GestionUsuariosScreen extends StatefulWidget {
  const GestionUsuariosScreen({this.service, this.abrirUsuario, super.key});

  /// Servicio de usuarios (inyectable en pruebas).
  final UsuariosAdminService? service;

  /// Abre el perfil del usuario (inyectable en pruebas). Por defecto,
  /// [PerfilUsuarioScreen].
  final void Function(BuildContext context, UsuarioListado usuario)?
  abrirUsuario;

  @override
  State<GestionUsuariosScreen> createState() => _GestionUsuariosScreenState();
}

class _GestionUsuariosScreenState extends State<GestionUsuariosScreen> {
  late final UsuariosAdminService _service =
      widget.service ?? UsuariosAdminService();
  final TextEditingController _busqueda = TextEditingController();
  final ScrollController _scroll = ScrollController();

  List<UsuarioListado> _usuarios = <UsuarioListado>[];
  bool _cargando = true;
  String? _error;
  int _pagina = 1;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _busqueda.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final List<UsuarioListado> usuarios = await _service.obtenerUsuarios();
      if (mounted) setState(() => _usuarios = usuarios);
    } on UsuariosAdminException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _irAPagina(int pagina) {
    setState(() => _pagina = pagina);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _abrir(UsuarioListado usuario) {
    final void Function(BuildContext, UsuarioListado)? abrir =
        widget.abrirUsuario;
    if (abrir != null) {
      abrir(context, usuario);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PerfilUsuarioScreen(uid: usuario.uid),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.crema,
      appBar: AppBar(
        title: const Text('Usuarios'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _cargando ? null : _cargar,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    FormStyles.s16,
                    FormStyles.s16,
                    FormStyles.s16,
                    FormStyles.s8,
                  ),
                  child: TextField(
                    key: const Key('buscar-usuarios'),
                    controller: _busqueda,
                    textInputAction: TextInputAction.search,
                    // Al buscar se vuelve a la primera página.
                    onChanged: (_) => setState(() => _pagina = 1),
                    decoration: FormStyles.input(
                      label: 'Buscar por nombre o correo',
                      icon: Icons.search_rounded,
                      suffixIcon: _busqueda.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Limpiar búsqueda',
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () => setState(() {
                                _busqueda.clear();
                                _pagina = 1;
                              }),
                            ),
                    ),
                  ),
                ),
                Expanded(child: _buildContenido()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContenido() {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(FormStyles.s16),
        children: <Widget>[
          AvisoError(mensaje: _error!),
          const SizedBox(height: FormStyles.s8),
          Center(
            child: TextButton(
              onPressed: _cargar,
              child: const Text('Reintentar'),
            ),
          ),
        ],
      );
    }

    final String consulta = _busqueda.text.trim();
    final List<UsuarioListado> encontrados = UsuariosAdminService.filtrar(
      _usuarios,
      consulta,
    );
    if (encontrados.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(FormStyles.s20),
        children: <Widget>[
          const SizedBox(height: FormStyles.s24),
          Icon(
            Icons.person_search_rounded,
            size: 48,
            color: AppTheme.textoSuave.withValues(alpha: 0.4),
          ),
          const SizedBox(height: FormStyles.s12),
          Text(
            consulta.isEmpty
                ? 'No hay usuarios registrados.'
                : 'No se encontraron usuarios para "$consulta".',
            key: const Key('usuarios-sin-resultados'),
            textAlign: TextAlign.center,
            style: FormStyles.subtitulo(pequena: true),
          ),
        ],
      );
    }

    final PaginaUsuarios pagina = UsuariosAdminService.paginar(
      encontrados,
      _pagina,
    );
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: FormStyles.s16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              consulta.isEmpty
                  ? '${pagina.totalUsuarios} '
                        '${pagina.totalUsuarios == 1 ? 'usuario' : 'usuarios'}'
                  : '${pagina.totalUsuarios} '
                        '${pagina.totalUsuarios == 1 ? 'resultado' : 'resultados'}',
              key: const Key('usuarios-total'),
              style: FormStyles.ayuda(),
            ),
          ),
        ),
        const SizedBox(height: FormStyles.s8),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _cargar,
            child: ListView.separated(
              controller: _scroll,
              padding: const EdgeInsets.symmetric(horizontal: FormStyles.s16),
              itemCount: pagina.usuarios.length,
              separatorBuilder: (_, _) => const SizedBox(height: FormStyles.s8),
              itemBuilder: (BuildContext context, int i) => _FilaUsuario(
                usuario: pagina.usuarios[i],
                onTap: () => _abrir(pagina.usuarios[i]),
              ),
            ),
          ),
        ),
        if (pagina.totalPaginas > 1)
          _Paginacion(pagina: pagina, onIrA: _irAPagina),
      ],
    );
  }
}

class _FilaUsuario extends StatelessWidget {
  const _FilaUsuario({required this.usuario, required this.onTap});

  final UsuarioListado usuario;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String? rol = usuario.rol;
    return Material(
      key: Key('usuario-${usuario.uid}'),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FormStyles.radio),
        side: const BorderSide(color: FormStyles.colorBorde),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(FormStyles.s12),
          child: Row(
            children: <Widget>[
              CircleAvatar(
                radius: 20,
                backgroundColor: AppTheme.azulPetroleo,
                child: Text(
                  usuario.nombre.characters.first.toUpperCase(),
                  style: FormStyles.cuerpo(
                    weight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: FormStyles.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      usuario.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FormStyles.cuerpo(
                        weight: FontWeight.w700,
                        color: AppTheme.azulPetroleo,
                      ),
                    ),
                    Text(
                      usuario.correo.isEmpty ? 'Sin correo' : usuario.correo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FormStyles.cuerpo(size: 13),
                    ),
                  ],
                ),
              ),
              if (rol != null) ...<Widget>[
                const SizedBox(width: FormStyles.s8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: FormStyles.s8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.crema,
                    borderRadius: BorderRadius.circular(FormStyles.radioPill),
                    border: Border.all(color: FormStyles.colorBorde),
                  ),
                  child: Text(
                    rol,
                    style: FormStyles.cuerpo(
                      size: 12,
                      color: AppTheme.azulPetroleo,
                    ),
                  ),
                ),
              ],
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textoSuave,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Paginacion extends StatelessWidget {
  const _Paginacion({required this.pagina, required this.onIrA});

  final PaginaUsuarios pagina;
  final ValueChanged<int> onIrA;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(FormStyles.s12),
      child: Row(
        children: <Widget>[
          TextButton.icon(
            key: const Key('pagina-anterior'),
            onPressed: pagina.hayAnterior
                ? () => onIrA(pagina.pagina - 1)
                : null,
            icon: const Icon(Icons.chevron_left_rounded),
            label: const Text('Anterior'),
          ),
          Expanded(
            child: Text(
              'Página ${pagina.pagina} de ${pagina.totalPaginas}',
              key: const Key('pagina-actual'),
              textAlign: TextAlign.center,
              style: FormStyles.cuerpo(size: 13),
            ),
          ),
          TextButton(
            key: const Key('pagina-siguiente'),
            onPressed: pagina.haySiguiente
                ? () => onIrA(pagina.pagina + 1)
                : null,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text('Siguiente'),
                Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
