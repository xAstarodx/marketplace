import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'detalle_producto_pantalla.dart';

class PantallaBuscar extends StatefulWidget {
  const PantallaBuscar({super.key});

  @override
  State<PantallaBuscar> createState() => _PantallaBuscarState();
}

class _PantallaBuscarState extends State<PantallaBuscar> {
  final busquedaCtrl = TextEditingController();
  final focusNode = FocusNode();
  List<dynamic> resultados = [];
  bool cargando = false;
  bool busquedaRealizada = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    busquedaCtrl.dispose();
    focusNode.dispose();
    super.dispose();
  }

  Future<void> buscar() async {
    final texto = busquedaCtrl.text.trim();
    if (texto.isEmpty) {
      setState(() {
        resultados = [];
        busquedaRealizada = false;
      });
      return;
    }

    setState(() {
      cargando = true;
      busquedaRealizada = true;
    });

    try {
      final data = await Supabase.instance.client
          .from('productos')
          .select(
            '*, categorias(nombre), ubicaciones(nombre, latitud, longitud)',
          )
          .ilike('nombre', '%$texto%')
          .eq('disponible', true)
          .order('fecha_creacion', ascending: false);

      if (mounted) setState(() => resultados = data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al buscar. Intenta de nuevo.')),
        );
      }
    }

    if (mounted) setState(() => cargando = false);
  }

  void limpiar() {
    busquedaCtrl.clear();
    setState(() {
      resultados = [];
      busquedaRealizada = false;
    });
    focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: busquedaCtrl,
          focusNode: focusNode,
          decoration: InputDecoration(
            hintText: 'Buscar productos...',
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
            contentPadding: EdgeInsets.zero,
            suffixIcon: busquedaCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: limpiar,
                    iconSize: 20,
                  )
                : null,
          ),
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => buscar(),
          onChanged: (v) {
            setState(() {});
            if (v.isEmpty) {
              setState(() {
                resultados = [];
                busquedaRealizada = false;
              });
            }
          },
        ),
        actions: [
          TextButton(onPressed: buscar, child: const Text('Buscar')),
          const SizedBox(width: 4),
        ],
        leading: const BackButton(),
      ),
      body: _buildCuerpo(colorScheme),
    );
  }

  Widget _buildCuerpo(ColorScheme colorScheme) {
    if (cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!busquedaRealizada) {
      return _buildEstadoInicial(colorScheme);
    }

    if (resultados.isEmpty) {
      return _buildSinResultados(colorScheme);
    }

    return _buildListaResultados(colorScheme);
  }

  Widget _buildEstadoInicial(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.search, size: 56, color: colorScheme.primary),
          ),
          const SizedBox(height: 20),
          Text(
            'Busca lo que necesitas',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Escribe el nombre del producto\ny presiona buscar',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildSinResultados(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 64,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Sin resultados',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No encontramos productos para\n"${busquedaCtrl.text}"',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: limpiar,
            icon: const Icon(Icons.refresh),
            label: const Text('Nueva búsqueda'),
          ),
        ],
      ),
    );
  }

  Widget _buildListaResultados(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            '${resultados.length} resultado${resultados.length != 1 ? "s" : ""} encontrado${resultados.length != 1 ? "s" : ""}',
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: resultados.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final p = resultados[i];
              return _TarjetaBusqueda(
                producto: p,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PantallaDetalleProducto(producto: p),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TarjetaBusqueda extends StatelessWidget {
  final Map<String, dynamic> producto;
  final VoidCallback onTap;

  const _TarjetaBusqueda({required this.producto, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final imagenUrl = producto['imagen_url']?.toString() ?? '';
    final categoria = producto['categorias']?['nombre'];
    final ubicacion = producto['ubicaciones']?['nombre'];

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: imagenUrl.isNotEmpty
                    ? Image.network(
                        imagenUrl,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            _imagenPlaceholder(colorScheme),
                      )
                    : _imagenPlaceholder(colorScheme),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      producto['nombre'] ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '\$${producto['precio']}',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (categoria != null) ...[
                          _Chip(
                            texto: categoria,
                            icono: Icons.category_outlined,
                            colorScheme: colorScheme,
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (ubicacion != null)
                          _Chip(
                            texto: ubicacion,
                            icono: Icons.location_on_outlined,
                            colorScheme: colorScheme,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imagenPlaceholder(ColorScheme colorScheme) {
    return Container(
      width: 80,
      height: 80,
      color: colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.image_outlined,
        color: colorScheme.onSurfaceVariant,
        size: 32,
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String texto;
  final IconData icono;
  final ColorScheme colorScheme;

  const _Chip({
    required this.texto,
    required this.icono,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 11, color: colorScheme.onSecondaryContainer),
          const SizedBox(width: 3),
          Text(
            texto,
            style: TextStyle(
              fontSize: 11,
              color: colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
