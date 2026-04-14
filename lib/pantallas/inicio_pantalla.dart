import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/tarjeta_producto.dart';
import 'buscar_pantalla.dart';
import 'detalle_producto_pantalla.dart';
import '../modelos/producto.dart';
import '../modelos/categoria.dart';

class PantallaInicio extends StatefulWidget {
  const PantallaInicio({super.key});

  @override
  State<PantallaInicio> createState() => _PantallaInicioState();
}

class _PantallaInicioState extends State<PantallaInicio> {
  List<dynamic> productos = [];
  bool cargando = true;
  late RealtimeChannel canalProductos;
  List<Categoria> categorias = [];
  String? categoriaNombreSeleccionada;

  @override
  void initState() {
    super.initState();
    cargarCategorias();
    cargarProductos();
    _escucharProductos();
  }

  Future<void> cargarCategorias() async {
    try {
      final data = await Supabase.instance.client.from('categorias').select();
      if (mounted) {
        setState(
          () => categorias = data.map((map) => Categoria.fromMap(map)).toList(),
        );
      }
    } catch (_) {}
  }

  Future<void> cargarProductos() async {
    if (mounted) setState(() => cargando = true);

    try {
      var query = Supabase.instance.client
          .from('productos')
          .select(
            '*, categorias(nombre), ubicaciones(nombre, latitud, longitud)',
          )
          .eq('disponible', true);

      if (categoriaNombreSeleccionada != null &&
          categoriaNombreSeleccionada != 'Todos') {
        final cat = categorias.firstWhere(
          (c) => c.nombre == categoriaNombreSeleccionada,
          orElse: () => Categoria(id: '', nombre: ''),
        );
        if (cat.id.isNotEmpty) query = query.eq('categoria_id', cat.id);
      }

      final data = await query.order('fecha_creacion', ascending: false);

      if (mounted) {
        setState(() {
          productos = data;
          cargando = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => cargando = false);
    }
  }

  void _escucharProductos() {
    canalProductos = Supabase.instance.client
        .channel('inicio-productos-realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'productos',
          callback: (_) {
            cargarProductos();
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    canalProductos.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: cargarProductos,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              snap: true,
              title: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset('logo/logo.png', fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Marketplace',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(60),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PantallaBuscar()),
                    ),
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: colorScheme.outlineVariant.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 14),
                          Icon(
                            Icons.search,
                            color: colorScheme.onSurfaceVariant,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Buscar productos...',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Explorar por categoría',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: ['Todos', ...categorias.map((c) => c.nombre)]
                            .map((nombre) {
                              final seleccionado =
                                  (nombre == 'Todos' &&
                                      categoriaNombreSeleccionada == null) ||
                                  categoriaNombreSeleccionada == nombre;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: FilterChip(
                                  label: Text(nombre),
                                  selected: seleccionado,
                                  showCheckmark: false,
                                  onSelected: (_) {
                                    setState(() {
                                      categoriaNombreSeleccionada =
                                          nombre == 'Todos' ? null : nombre;
                                    });
                                    cargarProductos();
                                  },
                                ),
                              );
                            })
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (!cargando)
                      Text(
                        '${productos.length} producto${productos.length != 1 ? "s" : ""}',
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ),

            if (cargando)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (productos.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 72,
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Sin productos disponibles',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        categoriaNombreSeleccionada != null
                            ? 'No hay productos en esta categoría'
                            : 'Sé el primero en publicar algo',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 14,
                        ),
                      ),
                      if (categoriaNombreSeleccionada != null) ...[
                        const SizedBox(height: 20),
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() => categoriaNombreSeleccionada = null);
                            cargarProductos();
                          },
                          icon: const Icon(Icons.grid_view),
                          label: const Text('Ver todos'),
                        ),
                      ],
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.72,
                  ),
                  delegate: SliverChildBuilderDelegate((context, i) {
                    final p = productos[i];
                    return TarjetaProducto(
                      producto: Producto.fromMap(p),
                      alTocar: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PantallaDetalleProducto(producto: p),
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
