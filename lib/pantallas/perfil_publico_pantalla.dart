import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'detalle_producto_pantalla.dart';
import 'chat_pantalla.dart';

class PerfilPublicoPantalla extends StatefulWidget {
  final String idUsuario;

  const PerfilPublicoPantalla({super.key, required this.idUsuario});

  @override
  State<PerfilPublicoPantalla> createState() => _PerfilPublicoPantallaState();
}

class _PerfilPublicoPantallaState extends State<PerfilPublicoPantalla> {
  Map<String, dynamic>? perfil;
  List<dynamic> productos = [];
  bool cargando = true;

  @override
  void initState() {
    super.initState();
    cargarDatos();
  }

  Future<void> cargarDatos() async {
    try {
      final p = await Supabase.instance.client
          .from('perfiles')
          .select()
          .eq('id', widget.idUsuario)
          .single();

      final prods = await Supabase.instance.client
          .from('productos')
          .select(
            '*, categorias(nombre), ubicaciones(nombre, latitud, longitud)',
          )
          .eq('id_dueno', widget.idUsuario)
          .eq('disponible', true)
          .order('fecha_creacion', ascending: false);

      setState(() {
        perfil = p;
        productos = prods;
        cargando = false;
      });
    } catch (e) {
      debugPrint("ERROR PERFIL PUBLICO: $e");
      setState(() => cargando = false);
    }
  }

  Future<String> crearConversacion() async {
    final uid = Supabase.instance.client.auth.currentUser!.id;

    if (uid == widget.idUsuario) {
      throw "No puedes chatear contigo mismo";
    }

    if (productos.isEmpty) {
      throw "No hay productos disponibles para iniciar la conversación";
    }

    final idProducto = productos.first['id'];

    final existente = await Supabase.instance.client
        .from('conversaciones')
        .select()
        .eq('id_comprador', uid)
        .eq('id_vendedor', widget.idUsuario)
        .eq('id_producto', idProducto)
        .maybeSingle();

    if (existente != null) return existente['id'];

    final nueva = await Supabase.instance.client
        .from('conversaciones')
        .insert({
          'id_comprador': uid,
          'id_vendedor': widget.idUsuario,
          'id_producto': idProducto,
        })
        .select()
        .single();

    return nueva['id'];
  }

  @override
  Widget build(BuildContext context) {
    if (cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (perfil == null) {
      return const Scaffold(body: Center(child: Text("Perfil no encontrado")));
    }

    final foto = perfil!['foto_perfil'];
    final tieneFoto = foto != null && foto.toString().isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: Text(perfil!['nombre'])),

      body: RefreshIndicator(
        onRefresh: cargarDatos,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundImage: tieneFoto ? NetworkImage(foto) : null,
                child: !tieneFoto ? const Icon(Icons.person, size: 50) : null,
              ),

              const SizedBox(height: 16),

              Text(
                perfil!['nombre'],
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                perfil!['correo'],
                style: const TextStyle(color: Colors.grey),
              ),

              const SizedBox(height: 10),

              Text(
                perfil!['descripcion'] ?? "Sin descripción",
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 20),

              ElevatedButton.icon(
                icon: const Icon(Icons.chat),
                label: const Text("Enviar mensaje"),
                onPressed: productos.isEmpty
                    ? null
                    : () async {
                        try {
                          final idConversacion = await crearConversacion();

                          if (!context.mounted) return;

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  PantallaChat(idConversacion: idConversacion),
                            ),
                          );
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(e.toString())));
                        }
                      },
              ),

              const SizedBox(height: 30),
              const Divider(),
              const SizedBox(height: 10),

              const Text(
                "Productos en venta",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 10),

              productos.isEmpty
                  ? const Text("Este usuario no tiene productos publicados")
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: productos.length,
                      itemBuilder: (context, i) {
                        final p = productos[i];

                        return ListTile(
                          leading:
                              p['imagen_url'] != null &&
                                  p['imagen_url'].toString().isNotEmpty
                              ? Image.network(
                                  p['imagen_url'],
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(Icons.error),
                                )
                              : const Icon(Icons.image_not_supported),
                          title: Text(p['nombre']),
                          subtitle: Text("\$${p['precio']}"),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    PantallaDetalleProducto(producto: p),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
