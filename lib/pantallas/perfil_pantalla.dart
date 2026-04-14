import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import 'editar_perfil_pantalla.dart';
import 'detalle_producto_pantalla.dart';
import 'login_pantalla.dart';

class PantallaPerfil extends StatefulWidget {
  final dynamic usuarioActual;

  const PantallaPerfil({super.key, required this.usuarioActual});

  @override
  State<PantallaPerfil> createState() => _PantallaPerfilState();
}

class _PantallaPerfilState extends State<PantallaPerfil>
    with AutomaticKeepAliveClientMixin {
  Map<String, dynamic>? perfil;
  List<dynamic> productos = [];
  bool cargando = true;
  late RealtimeChannel canalProductos;
  String? fotoUrlOverride;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    cargarDatos();
    _escucharProductos();
  }

  void _escucharProductos() {
    canalProductos = Supabase.instance.client
        .channel('perfil-productos-${widget.usuarioActual.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'productos',
          callback: (payload) {
            cargarDatos();
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    canalProductos.unsubscribe();
    super.dispose();
  }

  Future<void> cargarDatos() async {
    try {
      final uid = widget.usuarioActual.id;

      final p = await Supabase.instance.client
          .from('perfiles')
          .select()
          .eq('id', uid)
          .single();

      final prods = await Supabase.instance.client
          .from('productos')
          .select(
            '*, categorias(nombre), ubicaciones(nombre, latitud, longitud)',
          )
          .eq('id_dueno', uid)
          .order('fecha_creacion', ascending: false);

      if (mounted) {
        setState(() {
          perfil = p;
          productos = prods;
          cargando = false;
          fotoUrlOverride = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => cargando = false);
    }
  }

  void _onFotoActualizada(String? nuevaUrl) {
    setState(() => fotoUrlOverride = nuevaUrl);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colorScheme = Theme.of(context).colorScheme;

    if (cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (perfil == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: colorScheme.error),
              const SizedBox(height: 16),
              const Text('No se pudo cargar el perfil'),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: cargarDatos,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final fotoUrl = fotoUrlOverride ?? perfil!['foto_perfil'];
    final tieneFoto = fotoUrl != null && fotoUrl.toString().isNotEmpty;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: cargarDatos,
        child: CustomScrollView(
          slivers: [
            SliverAppBar.large(
              title: const Text('Mi perfil'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Editar perfil',
                  onPressed: () async {
                    final actualizado = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EditarPerfilPantalla(
                          perfil: perfil!,
                          onFotoActualizada: _onFotoActualizada,
                        ),
                      ),
                    );
                    if (actualizado == true) cargarDatos();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.logout),
                  tooltip: 'Cerrar sesión',
                  onPressed: () async {
                    final confirmar = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Cerrar sesión'),
                        content: const Text('¿Deseas cerrar tu sesión?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancelar'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Cerrar sesión'),
                          ),
                        ],
                      ),
                    );
                    if (confirmar != true || !mounted) return;

                    await Supabase.instance.client.auth.signOut();
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.clear();

                    if (context.mounted) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PantallaLogin(),
                        ),
                        (route) => false,
                      );
                    }
                  },
                ),
              ],
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        CircleAvatar(
                          radius: 52,
                          backgroundColor: colorScheme.primaryContainer,
                          key: ValueKey(fotoUrl),
                          backgroundImage: tieneFoto
                              ? NetworkImage(fotoUrl!)
                              : null,
                          child: !tieneFoto
                              ? Icon(
                                  Icons.person,
                                  size: 52,
                                  color: colorScheme.onPrimaryContainer,
                                )
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      perfil!['nombre'] ?? '',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      perfil!['correo'] ?? '',
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if ((perfil!['descripcion'] ?? '')
                        .toString()
                        .isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        perfil!['descripcion'],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: colorScheme.outlineVariant.withValues(
                            alpha: 0.4,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _StatItem(
                            valor: '${productos.length}',
                            etiqueta: 'Productos',
                            colorScheme: colorScheme,
                          ),
                          Container(
                            width: 1,
                            height: 32,
                            color: colorScheme.outlineVariant,
                          ),
                          _StatItem(
                            valor:
                                '${productos.where((p) => p['disponible'] == true).length}',
                            etiqueta: 'Disponibles',
                            colorScheme: colorScheme,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      margin: EdgeInsets.zero,
                      child: ListTile(
                        leading: Icon(
                          MyApp.themeNotifier.value == ThemeMode.dark
                              ? Icons.dark_mode
                              : Icons.light_mode,
                          color: colorScheme.primary,
                        ),
                        title: const Text('Modo oscuro'),
                        trailing: Switch(
                          value: MyApp.themeNotifier.value == ThemeMode.dark,
                          onChanged: (value) async {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool('esModoOscuro', value);
                            setState(() {
                              MyApp.themeNotifier.value = value
                                  ? ThemeMode.dark
                                  : ThemeMode.light;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Mis productos',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    if (productos.isNotEmpty)
                      Text(
                        '${productos.length}',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 14,
                        ),
                      ),
                  ],
                ),
              ),
            ),

            if (productos.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 56,
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Aún no tienes productos publicados',
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, i) {
                    final p = productos[i];
                    final imagenUrl = p['imagen_url']?.toString() ?? '';
                    final tieneFotoP = imagenUrl.isNotEmpty;
                    final disponible = p['disponible'] == true;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Card(
                        margin: EdgeInsets.zero,
                        child: InkWell(
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    PantallaDetalleProducto(producto: p),
                              ),
                            );
                            cargarDatos();
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: tieneFotoP
                                      ? Image.network(
                                          imagenUrl,
                                          width: 64,
                                          height: 64,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) =>
                                              _PlaceholderImagen(
                                                colorScheme: colorScheme,
                                              ),
                                        )
                                      : _PlaceholderImagen(
                                          colorScheme: colorScheme,
                                        ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p['nombre'] ?? '',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '\$${p['precio']}',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: colorScheme.primary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: disponible
                                                  ? Colors.green
                                                  : colorScheme.error,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            disponible
                                                ? 'Disponible'
                                                : 'No disponible',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }, childCount: productos.length),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String valor;
  final String etiqueta;
  final ColorScheme colorScheme;

  const _StatItem({
    required this.valor,
    required this.etiqueta,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          valor,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          etiqueta,
          style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _PlaceholderImagen extends StatelessWidget {
  final ColorScheme colorScheme;
  const _PlaceholderImagen({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      color: colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.image_outlined,
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
        size: 28,
      ),
    );
  }
}
