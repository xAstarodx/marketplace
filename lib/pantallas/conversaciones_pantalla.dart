import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:audioplayers/audioplayers.dart';
import 'chat_pantalla.dart';
import 'chatia_pantalla.dart';

class PantallaConversaciones extends StatefulWidget {
  const PantallaConversaciones({super.key});

  @override
  State<PantallaConversaciones> createState() => _PantallaConversacionesState();
}

class _PantallaConversacionesState extends State<PantallaConversaciones>
    with SingleTickerProviderStateMixin {
  List<dynamic> compras = [];
  List<dynamic> ventas = [];
  List<dynamic> chatsIA = [];
  bool cargando = true;
  late RealtimeChannel canalConversaciones;
  final audioPlayer = AudioPlayer();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    cargarConversaciones();
    escucharConversaciones();
  }

  Future<void> cargarConversaciones() async {
    final client = Supabase.instance.client;
    final uid = client.auth.currentUser!.id;
    try {
      final dataUser = await client
          .from('conversaciones')
          .select(
            '*, productos(nombre, imagen_url), '
            'perfiles_comprador:perfiles!conversaciones_id_comprador_fkey(nombre, foto_perfil), '
            'perfiles_vendedor:perfiles!conversaciones_id_vendedor_fkey(nombre, foto_perfil)',
          )
          .or('id_comprador.eq.$uid,id_vendedor.eq.$uid')
          .order('ultima_actualizacion', ascending: false);

      final dataIA = await client
          .from('conversaciones_ia')
          .select('*, mensajes_ia(contenido, fecha_envio)')
          .eq('id_usuario', uid)
          .order('fecha_inicio', ascending: false);

      if (mounted) {
        setState(() {
          compras = dataUser.where((c) => c['id_comprador'] == uid).toList();
          ventas = dataUser.where((c) => c['id_vendedor'] == uid).toList();
          chatsIA = dataIA as List;
          cargando = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando conversaciones: $e');
      if (mounted) setState(() => cargando = false);
    }
  }

  void escucharConversaciones() {
    canalConversaciones = Supabase.instance.client
        .channel('conversaciones-changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'conversaciones',
          callback: (payload) async {
            if (payload.eventType == PostgresChangeEvent.insert ||
                payload.eventType == PostgresChangeEvent.update) {
              final nuevo = payload.newRecord;
              final uid = Supabase.instance.client.auth.currentUser?.id;
              if (uid != null && nuevo.isNotEmpty) {
                final soyComprador = nuevo['id_comprador'] == uid;
                final tieneNuevos = soyComprador
                    ? nuevo['comprador_tiene_nuevos'] == true
                    : nuevo['vendedor_tiene_nuevos'] == true;
                if (tieneNuevos) {
                  await audioPlayer.play(AssetSource('sonidos/notificacion.mp3'));
                }
              }
            }
            cargarConversaciones();
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    canalConversaciones.unsubscribe();
    audioPlayer.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final totalNoLeidos = _contarNoLeidos(compras, esComprador: true) +
        _contarNoLeidos(ventas, esComprador: false);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Mensajes'),
            if (totalNoLeidos > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.error,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$totalNoLeidos',
                  style: TextStyle(
                    color: colorScheme.onError,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.shopping_bag_outlined, size: 18),
                  const SizedBox(width: 6),
                  const Text(
                    'Mis compras',
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                  ),
                  if (_contarNoLeidos(compras, esComprador: true) > 0) ...[
                    const SizedBox(width: 6),
                    _BadgeCount(
                      count: _contarNoLeidos(compras, esComprador: true),
                      colorScheme: colorScheme,
                    ),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.sell_outlined, size: 18),
                  const SizedBox(width: 6),
                  const Text(
                    'Mis ventas',
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                  ),
                  if (_contarNoLeidos(ventas, esComprador: false) > 0) ...[
                    const SizedBox(width: 6),
                    _BadgeCount(
                      count: _contarNoLeidos(ventas, esComprador: false),
                      colorScheme: colorScheme,
                    ),
                  ],
                ],
              ),
            ),
            const Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.smart_toy_outlined, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'Asistente IA',
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildListaConversaciones(compras, soyComprador: true),
          _buildListaConversaciones(ventas, soyComprador: false),
          _buildListaChatsIA(chatsIA),
        ],
      ),
    );
  }

  int _contarNoLeidos(List<dynamic> lista, {required bool esComprador}) {
    return lista.where((c) {
      return esComprador
          ? c['comprador_tiene_nuevos'] == true
          : c['vendedor_tiene_nuevos'] == true;
    }).length;
  }

  Widget _buildListaConversaciones(List<dynamic> lista, {required bool soyComprador}) {
    final colorScheme = Theme.of(context).colorScheme;

    if (lista.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                soyComprador ? Icons.shopping_bag_outlined : Icons.sell_outlined,
                size: 48,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              soyComprador ? 'Sin conversaciones de compra' : 'Sin conversaciones de venta',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              soyComprador
                  ? 'Contacta a vendedores para\niniciar una conversación'
                  : 'Los compradores se comunicarán\ncontigo aquí',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: cargarConversaciones,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: lista.length,
        separatorBuilder: (_, _) => Divider(
          height: 1,
          indent: 80,
          endIndent: 16,
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
        itemBuilder: (context, i) {
          final c = lista[i];
          final otroUsuario = soyComprador ? c['perfiles_vendedor'] : c['perfiles_comprador'];
          final producto = c['productos'];
          final hayNuevos = soyComprador
              ? c['comprador_tiene_nuevos'] == true
              : c['vendedor_tiene_nuevos'] == true;

          final fotoUrl = otroUsuario['foto_perfil']?.toString() ?? '';
          final tieneFoto = fotoUrl.isNotEmpty;

          return InkWell(
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PantallaChat(idConversacion: c['id']),
                ),
              );
              cargarConversaciones();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundImage: tieneFoto ? NetworkImage(fotoUrl) : null,
                        backgroundColor: colorScheme.primaryContainer,
                        child: !tieneFoto
                            ? Text(
                                (otroUsuario['nombre'] as String? ?? '?')
                                    .substring(0, 1)
                                    .toUpperCase(),
                                style: TextStyle(
                                  color: colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              )
                            : null,
                      ),
                      if (hayNuevos)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: colorScheme.error,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: colorScheme.surface,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                otroUsuario['nombre'] ?? 'Usuario',
                                style: TextStyle(
                                  fontWeight: hayNuevos
                                      ? FontWeight.bold
                                      : FontWeight.w600,
                                  fontSize: 15,
                                  color: colorScheme.onSurface,
                                ),
                                overflow: TextOverflow.ellipsis,
                                ),
                            ),
                            if (hayNuevos)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'Nuevo',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: colorScheme.onPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 13,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                producto['nombre'] ?? '',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right,
                    color: colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildListaChatsIA(List<dynamic> lista) {
    final colorScheme = Theme.of(context).colorScheme;

    if (lista.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.tertiaryContainer.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.smart_toy_outlined,
                size: 48,
                color: colorScheme.tertiary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Sin historial con la IA',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tus consultas al asistente aparecerán aquí',
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: cargarConversaciones,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: lista.length,
        separatorBuilder: (_, _) => Divider(
          height: 1,
          indent: 80,
          endIndent: 16,
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
        itemBuilder: (context, i) {
          final c = lista[i];
          final mensajes = c['mensajes_ia'] as List;
          final ultimoMsg = mensajes.isNotEmpty ? mensajes.first['contenido'] : 'Nueva conversación';
          final fecha = DateTime.parse(c['fecha_inicio']).toLocal();

          return ListTile(
            leading: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colorScheme.primary, colorScheme.tertiary],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.smart_toy_rounded, color: Colors.white),
            ),
            title: Text(
              'Consulta del ${fecha.day}/${fecha.month}/${fecha.year}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            subtitle: Text(
              ultimoMsg,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
            ),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PantallaChatIA(idConversacion: c['id']),
                ),
              );
              cargarConversaciones();
            },
          );
        },
      ),
    );
  }
}

class _BadgeCount extends StatelessWidget {
  final int count;
  final ColorScheme colorScheme;

  const _BadgeCount({required this.count, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: colorScheme.error,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          color: colorScheme.onError,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
