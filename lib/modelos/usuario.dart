class Usuario {
  String id;
  String correo;
  String nombre;
  String descripcion;
  String fotoPerfil;

  Usuario({
    required this.id,
    required this.correo,
    required this.nombre,
    required this.descripcion,
    required this.fotoPerfil,
  });

  factory Usuario.desdeSupabase(Map data) {
    return Usuario(
      id: data['id'],
      correo: data['correo'],
      nombre: data['nombre'],
      descripcion: data['descripcion'] ?? '',
      fotoPerfil: data['foto_perfil'] ?? '',
    );
  }
}
