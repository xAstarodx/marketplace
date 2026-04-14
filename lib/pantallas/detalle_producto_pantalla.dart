import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_pantalla.dart';
import 'editar_producto_pantalla.dart';
import 'perfil_publico_pantalla.dart';

class PantallaDetalleProducto extends StatefulWidget {
  final Map<String, dynamic> producto;

  const PantallaDetalleProducto({super.key, required this.producto});

  @override
  State<PantallaDetalleProducto> createState() =>
      _PantallaDetalleProductoState();
}

class _PantallaDetalleProductoState extends State<PantallaDetalleProducto> {
  Map<String, dynamic>? vendedor;
  late Map<String, dynamic> p;

  @override
  void initState() {
    super.initState();
    p = Map<String, dynamic>.from(widget.producto);
    cargarVendedor();
  }

  Future<void> cargarVendedor() async {
    try {
      final data = await Supabase.instance.client
          .from('perfiles')
          .select()
          .eq('id', p['id_dueno'])
          .single();
      if (mounted) setState(() => vendedor = data);
    } catch (_) {}
  }

  Future<String> crearConversacion() async {
    final uid = Supabase.instance.client.auth.currentUser!.id;
    final idProducto = p['id'];
    final idVendedor = p['id_dueno'];

    if (uid == idVendedor) throw 'No puedes chatear contigo mismo';

    final existente = await Supabase.instance.client
        .from('conversaciones')
        .select()
        .eq('id_comprador', uid)
        .eq('id_producto', idProducto)
        .maybeSingle();

    if (existente != null) return existente['id'];

    final nueva = await Supabase.instance.client
        .from('conversaciones')
        .insert({
          'id_comprador': uid,
          'id_vendedor': idVendedor,
          'id_producto': idProducto,
        })
        .select()
        .single();

    return nueva['id'];
  }

  String? get _categoriaNombre => p['categorias']?['nombre'] as String?;
  String? get _ubicacionNombre => p['ubicaciones']?['nombre'] as String?;
  double? get _latitud {
    final lat = p['ubicaciones']?['latitud'];
    return lat != null ? (lat as num).toDouble() : null;
  }

  double? get _longitud {
    final lng = p['ubicaciones']?['longitud'];
    return lng != null ? (lng as num).toDouble() : null;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final uid = Supabase.instance.client.auth.currentUser!.id;
    final esPropietario = uid == p['id_dueno'];

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(
              p['nombre'] ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            actions: esPropietario
                ? [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () async {
                        final resultado = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PantallaEditarProducto(producto: p),
                          ),
                        );
                        if (!context.mounted) return;
                        if (resultado == null) {
                          Navigator.pop(context);
                        } else if (resultado == true) {
                          cargarVendedor();
                        }
                      },
                    ),
                  ]
                : null,
          ),

          if (vendedor == null)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    p['imagen_url'] != null &&
                            p['imagen_url'].toString().isNotEmpty
                        ? Hero(
                            tag: p['id'],
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.network(
                                p['imagen_url'],
                                height: 280,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => _ImagenError(
                                  colorScheme: colorScheme,
                                  height: 280,
                                ),
                              ),
                            ),
                          )
                        : _ImagenError(colorScheme: colorScheme, height: 200),

                    const SizedBox(height: 20),

                    Text(
                      p['nombre'] ?? '',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Text(
                      '\$${p['precio']}',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (_categoriaNombre != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Wrap(
                          children: [
                            Chip(
                              avatar: Icon(
                                Icons.category_outlined,
                                size: 16,
                                color: colorScheme.onSecondaryContainer,
                              ),
                              label: Text(_categoriaNombre!),
                              backgroundColor: colorScheme.secondaryContainer,
                              labelStyle: TextStyle(
                                color: colorScheme.onSecondaryContainer,
                              ),
                              side: BorderSide.none,
                            ),
                          ],
                        ),
                      ),

                    if (esPropietario)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: p['disponible'] == true
                                    ? Colors.green
                                    : colorScheme.error,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              p['disponible'] == true
                                  ? 'Visible en el marketplace'
                                  : 'Oculto del marketplace',
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),

                    Text(
                      'Descripción',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      p['descripcion'] ?? 'Sin descripción',
                      style: TextStyle(
                        fontSize: 16,
                        color: colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),

                    if (_ubicacionNombre != null) ...[
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.location_on,
                              color: colorScheme.onPrimaryContainer,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _ubicacionNombre!,
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],

                    if (_latitud != null && _longitud != null) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 180,
                        width: double.infinity,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: GoogleMap(
                            initialCameraPosition: CameraPosition(
                              target: LatLng(_latitud!, _longitud!),
                              zoom: 14,
                            ),
                            markers: {
                              Marker(
                                markerId: const MarkerId('ubicacion_producto'),
                                position: LatLng(_latitud!, _longitud!),
                              ),
                            },
                            liteModeEnabled: true,
                            scrollGesturesEnabled: false,
                            zoomGesturesEnabled: false,
                            mapToolbarEnabled: false,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    Text(
                      'Vendedor',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: colorScheme.primaryContainer,
                          backgroundImage:
                              (vendedor!['foto_perfil'] != null &&
                                  vendedor!['foto_perfil']
                                      .toString()
                                      .isNotEmpty)
                              ? NetworkImage(vendedor!['foto_perfil'])
                              : null,
                          child:
                              (vendedor!['foto_perfil'] == null ||
                                  vendedor!['foto_perfil'].toString().isEmpty)
                              ? Icon(
                                  Icons.person,
                                  color: colorScheme.onPrimaryContainer,
                                )
                              : null,
                        ),
                        title: Text(
                          vendedor!['nombre'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(vendedor!['correo'] ?? ''),
                        trailing: Icon(
                          Icons.chevron_right,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PerfilPublicoPantalla(
                                idUsuario: vendedor!['id'],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 24),

                    if (!esPropietario)
                      FilledButton.icon(
                        onPressed: () async {
                          try {
                            final idConversacion = await crearConversacion();
                            if (!context.mounted) return;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PantallaChat(
                                  idConversacion: idConversacion,
                                ),
                              ),
                            );
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.toString())),
                            );
                          }
                        },
                        icon: const Icon(Icons.chat),
                        label: const Text('Contactar al vendedor'),
                      ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ImagenError extends StatelessWidget {
  final ColorScheme colorScheme;
  final double height;
  const _ImagenError({required this.colorScheme, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(
        Icons.image_not_supported_outlined,
        size: 64,
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
      ),
    );
  }
}
