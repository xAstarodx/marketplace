class Producto {
  final String id;
  final String idDueno;
  final String nombre;
  final String descripcion;
  final double precio;
  final String imagenUrl;
  final bool disponible;
  final String? categoria;
  final String? categoriaId;
  final String? ubicacionNombre;
  final String? ubicacionId;
  final double? latitud;
  final double? longitud;
  final DateTime fechaCreacion;

  Producto({
    required this.id,
    required this.idDueno,
    required this.nombre,
    required this.descripcion,
    required this.precio,
    required this.imagenUrl,
    required this.disponible,
    this.categoria,
    this.categoriaId,
    this.ubicacionNombre,
    this.ubicacionId,
    this.latitud,
    this.longitud,
    required this.fechaCreacion,
  });

  factory Producto.fromMap(Map<String, dynamic> map) {
    return Producto(
      id: map['id'],
      idDueno: map['id_dueno'],
      nombre: map['nombre'],
      descripcion: map['descripcion'],
      precio: (map['precio'] as num).toDouble(),
      imagenUrl: map['imagen_url'] ?? "",
      disponible: map['disponible'] ?? true,
      categoria: map['categorias']?['nombre'],
      categoriaId: map['categoria_id'],
      ubicacionNombre: map['ubicaciones']?['nombre'],
      ubicacionId: map['ubicacion_id'],
      latitud: map['ubicaciones']?['latitud'] != null
          ? (map['ubicaciones']['latitud'] as num).toDouble()
          : null,
      longitud: map['ubicaciones']?['longitud'] != null
          ? (map['ubicaciones']['longitud'] as num).toDouble()
          : null,
      fechaCreacion: DateTime.parse(map['fecha_creacion']),
    );
  }
}
