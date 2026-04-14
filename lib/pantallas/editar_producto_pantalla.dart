import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'seleccionar_ubicacion_pantalla.dart';
import '../modelos/categoria.dart';

class PantallaEditarProducto extends StatefulWidget {
  final Map<String, dynamic> producto;

  const PantallaEditarProducto({super.key, required this.producto});

  @override
  State<PantallaEditarProducto> createState() => _PantallaEditarProductoState();
}

class _PantallaEditarProductoState extends State<PantallaEditarProducto> {
  late TextEditingController nombreCtrl;
  late TextEditingController descripcionCtrl;
  late TextEditingController precioCtrl;

  File? nuevaImagen;
  LatLng? ubicacion;
  String? ubicacionNombre;
  bool cargando = false;
  List<Categoria> categorias = [];
  String? categoriaIdSeleccionada;
  bool disponible = true;
  bool _ubicacionModificada = false;

  @override
  void initState() {
    super.initState();
    final p = widget.producto;
    nombreCtrl = TextEditingController(text: p['nombre'] ?? '');
    descripcionCtrl = TextEditingController(text: p['descripcion'] ?? '');
    precioCtrl = TextEditingController(text: p['precio']?.toString() ?? '');
    categoriaIdSeleccionada = p['categoria_id'];
    disponible = p['disponible'] ?? true;

    if (p['ubicaciones'] != null) {
      final u = p['ubicaciones'];
      if (u['latitud'] != null && u['longitud'] != null) {
        ubicacion = LatLng(
          (u['latitud'] as num).toDouble(),
          (u['longitud'] as num).toDouble(),
        );
        ubicacionNombre = u['nombre'];
      }
    } else if (p['ubicacion_id'] != null) {
      _cargarUbicacion(p['ubicacion_id']);
    }

    cargarCategorias();
  }

  @override
  void dispose() {
    nombreCtrl.dispose();
    descripcionCtrl.dispose();
    precioCtrl.dispose();
    super.dispose();
  }

  Future<void> cargarCategorias() async {
    try {
      final data = await Supabase.instance.client.from('categorias').select();
      if (mounted) {
        setState(
          () => categorias = data.map((m) => Categoria.fromMap(m)).toList(),
        );
      }
    } catch (_) {}
  }

  Future<void> _cargarUbicacion(String ubicacionId) async {
    try {
      final data = await Supabase.instance.client
          .from('ubicaciones')
          .select('latitud, longitud, nombre')
          .eq('id', ubicacionId)
          .single();
      if (mounted) {
        setState(() {
          ubicacion = LatLng(
            (data['latitud'] as num).toDouble(),
            (data['longitud'] as num).toDouble(),
          );
          ubicacionNombre = data['nombre'];
        });
      }
    } catch (_) {}
  }

  Future<void> seleccionarImagen() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );
    if (xfile != null) setState(() => nuevaImagen = File(xfile.path));
  }

  Future<String?> _insertarUbicacion(LatLng pos, String? nombre) async {
    final data = await Supabase.instance.client
        .from('ubicaciones')
        .insert({
          'latitud': pos.latitude,
          'longitud': pos.longitude,
          'nombre': nombre,
        })
        .select('id')
        .single();
    return data['id'];
  }

  Future<String?> subirNuevaImagen() async {
    if (nuevaImagen == null) return widget.producto['imagen_url'];
    final uid = Supabase.instance.client.auth.currentUser!.id;
    final nombreArchivo = '${uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final bytes = await nuevaImagen!.readAsBytes();
    await Supabase.instance.client.storage
        .from('productos')
        .uploadBinary(
          nombreArchivo,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );
    return Supabase.instance.client.storage
        .from('productos')
        .getPublicUrl(nombreArchivo);
  }

  Future<void> guardarCambios() async {
    if (nombreCtrl.text.trim().isEmpty ||
        descripcionCtrl.text.trim().isEmpty ||
        precioCtrl.text.trim().isEmpty ||
        categoriaIdSeleccionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa todos los campos requeridos')),
      );
      return;
    }

    final precio = double.tryParse(precioCtrl.text.replaceAll(',', '.'));
    if (precio == null || precio < 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ingresa un precio válido')));
      return;
    }

    setState(() => cargando = true);

    try {
      final nuevaUrl = await subirNuevaImagen();

      String? ubicacionId = widget.producto['ubicacion_id'];
      if (_ubicacionModificada) {
        ubicacionId = ubicacion != null
            ? await _insertarUbicacion(ubicacion!, ubicacionNombre)
            : null;
      }

      await Supabase.instance.client
          .from('productos')
          .update({
            'nombre': nombreCtrl.text.trim(),
            'descripcion': descripcionCtrl.text.trim(),
            'precio': precio,
            'categoria_id': categoriaIdSeleccionada,
            'imagen_url': nuevaUrl,
            'ubicacion_id': ubicacionId,
            'disponible': disponible,
          })
          .eq('id', widget.producto['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Producto actualizado correctamente')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
      }
    }

    if (mounted) setState(() => cargando = false);
  }

  Future<void> eliminarProducto() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: const Text(
          '¿Seguro que deseas eliminar este producto? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => cargando = true);

    try {
      await Supabase.instance.client
          .from('productos')
          .delete()
          .eq('id', widget.producto['id']);

      if (mounted) {
        Navigator.pop(context, null);
      }
    } catch (e) {
      if (mounted) {
        setState(() => cargando = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final imagenActual = widget.producto['imagen_url'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar producto'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Eliminar producto',
            color: colorScheme.error,
            onPressed: cargando ? null : eliminarProducto,
          ),
          if (!cargando)
            TextButton(
              onPressed: guardarCambios,
              child: const Text(
                'Guardar',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GestureDetector(
                    onTap: seleccionarImagen,
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: nuevaImagen != null
                              ? Image.file(
                                  nuevaImagen!,
                                  height: 200,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                )
                              : imagenActual != null &&
                                    imagenActual.toString().isNotEmpty
                              ? Image.network(
                                  imagenActual,
                                  height: 200,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => _PlaceholderImagen(
                                    colorScheme: colorScheme,
                                  ),
                                )
                              : _PlaceholderImagen(colorScheme: colorScheme),
                        ),
                        Positioned(
                          bottom: 10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.surface.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.camera_alt_outlined,
                                  size: 16,
                                  color: colorScheme.primary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Cambiar foto',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  TextField(
                    controller: nombreCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del producto *',
                      prefixIcon: Icon(Icons.label_outline),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: descripcionCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Descripción *',
                      prefixIcon: Icon(Icons.description_outlined),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: precioCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Precio *',
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 14),

                  DropdownButtonFormField<String>(
                    initialValue: categoriaIdSeleccionada,
                    decoration: const InputDecoration(
                      labelText: 'Categoría *',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    items: categorias
                        .map(
                          (cat) => DropdownMenuItem(
                            value: cat.id,
                            child: Text(cat.nombre),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => categoriaIdSeleccionada = value),
                  ),
                  const SizedBox(height: 14),

                  Card(
                    margin: EdgeInsets.zero,
                    child: SwitchListTile(
                      secondary: Icon(
                        disponible
                            ? Icons.check_circle_outline
                            : Icons.cancel_outlined,
                        color: disponible ? Colors.green : colorScheme.error,
                      ),
                      title: const Text('Disponible para venta'),
                      subtitle: Text(
                        disponible
                            ? 'Visible en el marketplace'
                            : 'Oculto del marketplace',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      value: disponible,
                      onChanged: (v) => setState(() => disponible = v),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Ubicación',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (ubicacion != null)
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        ubicacionNombre ??
                                            'Ubicación seleccionada',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        '${ubicacion!.latitude.toStringAsFixed(4)}, ${ubicacion!.longitude.toStringAsFixed(4)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    final resultado = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const PantallaSeleccionarUbicacion(),
                                      ),
                                    );
                                    if (resultado != null) {
                                      setState(() {
                                        ubicacion = resultado['posicion'];
                                        ubicacionNombre = resultado['nombre'];
                                        _ubicacionModificada = true;
                                      });
                                    }
                                  },
                                  child: const Text('Cambiar'),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () => setState(() {
                                    ubicacion = null;
                                    ubicacionNombre = null;
                                    _ubicacionModificada = true;
                                  }),
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ],
                            )
                          else
                            OutlinedButton.icon(
                              onPressed: () async {
                                final resultado = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const PantallaSeleccionarUbicacion(),
                                  ),
                                );
                                if (resultado != null) {
                                  setState(() {
                                    ubicacion = resultado['posicion'];
                                    ubicacionNombre = resultado['nombre'];
                                    _ubicacionModificada = true;
                                  });
                                }
                              },
                              icon: const Icon(Icons.add_location_alt_outlined),
                              label: const Text('Agregar ubicación'),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),
                  FilledButton.icon(
                    onPressed: guardarCambios,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Guardar cambios'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: eliminarProducto,
                    icon: Icon(Icons.delete_outline, color: colorScheme.error),
                    label: Text(
                      'Eliminar producto',
                      style: TextStyle(color: colorScheme.error),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: colorScheme.error.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}

class _PlaceholderImagen extends StatelessWidget {
  final ColorScheme colorScheme;
  const _PlaceholderImagen({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      width: double.infinity,
      color: colorScheme.surfaceContainerHighest,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_photo_alternate_outlined,
            size: 52,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(
            'Toca para agregar imagen',
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
