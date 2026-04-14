class Ubicacion {
  final String id;
  final double latitud;
  final double longitud;
  final String? nombre;

  Ubicacion({
    required this.id,
    required this.latitud,
    required this.longitud,
    this.nombre,
  });

  factory Ubicacion.fromMap(Map<String, dynamic> map) {
    return Ubicacion(
      id: map['id'],
      latitud: (map['latitud'] as num).toDouble(),
      longitud: (map['longitud'] as num).toDouble(),
      nombre: map['nombre'],
    );
  }
}
