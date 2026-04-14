class Categoria {
  final String id;
  final String nombre;

  Categoria({required this.id, required this.nombre});

  factory Categoria.fromMap(Map<String, dynamic> map) {
    return Categoria(id: map['id'], nombre: map['nombre']);
  }
}
