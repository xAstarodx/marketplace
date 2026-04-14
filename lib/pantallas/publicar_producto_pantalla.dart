import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'seleccionar_ubicacion_pantalla.dart';
import '../modelos/categoria.dart';

class PantallaPublicarProducto extends StatefulWidget {
  final VoidCallback? onProductPublished;
  const PantallaPublicarProducto({super.key, this.onProductPublished});

  @override
  State<PantallaPublicarProducto> createState() =>
      _PantallaPublicarProductoState();
}

class _PantallaPublicarProductoState extends State<PantallaPublicarProducto> {
  final nombreCtrl = TextEditingController();
  final descripcionCtrl = TextEditingController();
  final precioCtrl = TextEditingController();

  File? imagen;
  bool cargando = false;
  bool cargandoUbicacion = false;
  LatLng? ubicacion;
  String? ubicacionNombre;
  List<Categoria> categorias = [];
  String? categoriaIdSeleccionada;

  @override
  void initState() {
    super.initState();
    cargarCategorias();
    _obtenerUbicacionActual();
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
          () => categorias = data.map((map) => Categoria.fromMap(map)).toList(),
        );
      }
    } catch (_) {}
  }

  Future<void> _obtenerUbicacionActual() async {
    setState(() => cargandoUbicacion = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => cargandoUbicacion = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => cargandoUbicacion = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => cargandoUbicacion = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );

      final newLatLng = LatLng(position.latitude, position.longitude);

      String nombre = 'Mi ubicación';
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          final partes = [
            p.subLocality,
            p.locality,
            p.administrativeArea,
          ].where((s) => s != null && s.isNotEmpty).toList();
          if (partes.isNotEmpty) nombre = partes.take(2).join(', ');
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          ubicacion = newLatLng;
          ubicacionNombre = nombre;
          cargandoUbicacion = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => cargandoUbicacion = false);
    }
  }

  void limpiarFormulario() {
    nombreCtrl.clear();
    descripcionCtrl.clear();
    precioCtrl.clear();
    setState(() {
      imagen = null;
      ubicacion = null;
      ubicacionNombre = null;
      categoriaIdSeleccionada = null;
    });
  }

  Future<void> seleccionarImagen() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );
    if (xfile != null) setState(() => imagen = File(xfile.path));
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

  Future<String?> subirImagen() async {
    if (imagen == null) return null;
    final uid = Supabase.instance.client.auth.currentUser!.id;
    final nombreArchivo = '${uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final bytes = await imagen!.readAsBytes();
    await Supabase.instance.client.storage
        .from('productos')
        .uploadBinary(nombreArchivo, bytes);
    return Supabase.instance.client.storage
        .from('productos')
        .getPublicUrl(nombreArchivo);
  }

  Future<void> publicar() async {
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
      final imagenUrl = await subirImagen();
      final uid = Supabase.instance.client.auth.currentUser!.id;

      String? ubicacionId;
      if (ubicacion != null) {
        ubicacionId = await _insertarUbicacion(ubicacion!, ubicacionNombre);
      }

      await Supabase.instance.client.from('productos').insert({
        'id_dueno': uid,
        'nombre': nombreCtrl.text.trim(),
        'descripcion': descripcionCtrl.text.trim(),
        'precio': precio,
        'categoria_id': categoriaIdSeleccionada,
        'imagen_url': imagenUrl,
        'ubicacion_id': ubicacionId,
        'disponible': true,
      });

      if (mounted) {
        limpiarFormulario();
        setState(() => cargando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Producto publicado exitosamente!')),
        );
        widget.onProductPublished?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() => cargando = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al publicar: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Publicar producto')),
      body: cargando
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Publicando producto...',
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GestureDetector(
                    onTap: seleccionarImagen,
                    child: imagen == null
                        ? Container(
                            height: 200,
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: colorScheme.outline.withValues(
                                  alpha: 0.4,
                                ),
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_photo_alternate_outlined,
                                  size: 52,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Toca para agregar una imagen',
                                  style: TextStyle(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Opcional',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colorScheme.onSurfaceVariant
                                        .withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.file(
                                  imagen!,
                                  height: 200,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: CircleAvatar(
                                  backgroundColor: colorScheme.surface,
                                  child: IconButton(
                                    icon: const Icon(Icons.close),
                                    onPressed: () =>
                                        setState(() => imagen = null),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 8,
                                right: 8,
                                child: SizedBox(
                                  width: 120,
                                  child: FilledButton.tonal(
                                    onPressed: seleccionarImagen,
                                    child: const Text('Cambiar'),
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
                  const SizedBox(height: 20),

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
                              const SizedBox(width: 4),
                              Text(
                                '(opcional)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (cargandoUbicacion)
                            Row(
                              children: [
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Obteniendo tu ubicación...',
                                  style: TextStyle(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            )
                          else if (ubicacion != null)
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
                                  }),
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ],
                            )
                          else
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Sin ubicación',
                                    style: TextStyle(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: _obtenerUbicacionActual,
                                  icon: const Icon(Icons.my_location, size: 16),
                                  label: const Text('Usar mi ubicación'),
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
                                      });
                                    }
                                  },
                                  child: const Text('Elegir'),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),
                  FilledButton.icon(
                    onPressed: publicar,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Publicar producto'),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}
