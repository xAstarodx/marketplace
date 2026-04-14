import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditarPerfilPantalla extends StatefulWidget {
  final Map<String, dynamic> perfil;
  final void Function(String? nuevaFotoUrl)? onFotoActualizada;

  const EditarPerfilPantalla({
    super.key,
    required this.perfil,
    this.onFotoActualizada,
  });

  @override
  State<EditarPerfilPantalla> createState() => _EditarPerfilPantallaState();
}

class _EditarPerfilPantallaState extends State<EditarPerfilPantalla> {
  final nombreCtrl = TextEditingController();
  final descripcionCtrl = TextEditingController();
  File? nuevaFoto;
  bool cargando = false;
  bool subiendoFoto = false;
  String? fotoUrlActual;

  @override
  void initState() {
    super.initState();
    nombreCtrl.text = widget.perfil['nombre'] ?? '';
    descripcionCtrl.text = widget.perfil['descripcion'] ?? '';
    fotoUrlActual = widget.perfil['foto_perfil'];
  }

  @override
  void dispose() {
    nombreCtrl.dispose();
    descripcionCtrl.dispose();
    super.dispose();
  }

  Future<void> seleccionarFoto() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (xfile != null) {
      setState(() => nuevaFoto = File(xfile.path));
    }
  }

  Future<void> tomarFoto() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (xfile != null) {
      setState(() => nuevaFoto = File(xfile.path));
    }
  }

  void mostrarOpcionesFoto() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de galería'),
              onTap: () {
                Navigator.pop(context);
                seleccionarFoto();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Tomar foto'),
              onTap: () {
                Navigator.pop(context);
                tomarFoto();
              },
            ),
            if (fotoUrlActual != null && fotoUrlActual!.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'Eliminar foto',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    nuevaFoto = null;
                    fotoUrlActual = null;
                  });
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<String?> subirFoto() async {
    if (nuevaFoto == null) return fotoUrlActual;

    final uid = Supabase.instance.client.auth.currentUser!.id;
    final nombreArchivo = 'perfil_$uid.jpg';
    final bytes = await nuevaFoto!.readAsBytes();

    await Supabase.instance.client.storage
        .from('perfiles')
        .uploadBinary(
          nombreArchivo,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );

    final baseUrl = Supabase.instance.client.storage
        .from('perfiles')
        .getPublicUrl(nombreArchivo);
    return '$baseUrl?t=${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<void> guardar() async {
    if (nombreCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El nombre no puede estar vacío')),
      );
      return;
    }

    setState(() => cargando = true);

    try {
      setState(() => subiendoFoto = true);
      final fotoUrl = await subirFoto();
      setState(() => subiendoFoto = false);

      await Supabase.instance.client
          .from('perfiles')
          .update({
            'nombre': nombreCtrl.text.trim(),
            'descripcion': descripcionCtrl.text.trim(),
            'foto_perfil': fotoUrl,
          })
          .eq('id', widget.perfil['id']);

      widget.onFotoActualizada?.call(fotoUrl);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil actualizado correctamente')),
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tieneFoto = fotoUrlActual != null && fotoUrlActual!.isNotEmpty;

    ImageProvider? imagenProvider;
    if (nuevaFoto != null) {
      imagenProvider = FileImage(nuevaFoto!);
    } else if (tieneFoto) {
      imagenProvider = NetworkImage(fotoUrlActual!);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar perfil'),
        actions: [
          if (!cargando)
            TextButton(
              onPressed: guardar,
              child: const Text(
                'Guardar',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: cargando
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    subiendoFoto ? 'Subiendo foto...' : 'Guardando cambios...',
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: mostrarOpcionesFoto,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 56,
                          backgroundColor: colorScheme.primaryContainer,
                          backgroundImage: imagenProvider,
                          child: imagenProvider == null
                              ? Icon(
                                  Icons.person,
                                  size: 56,
                                  color: colorScheme.onPrimaryContainer,
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: colorScheme.surface,
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              Icons.camera_alt,
                              size: 16,
                              color: colorScheme.onPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: mostrarOpcionesFoto,
                    child: const Text('Cambiar foto de perfil'),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: nombreCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descripcionCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Descripción',
                      prefixIcon: Icon(Icons.info_outline),
                      alignLabelWithHint: true,
                      helperText: 'Cuéntanos un poco sobre ti',
                    ),
                    maxLines: 3,
                    textInputAction: TextInputAction.done,
                  ),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: guardar,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Guardar cambios'),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }
}
