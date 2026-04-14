import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ServicioStorage {
  static Future<String?> subirImagen(File archivo, String carpeta) async {
    final supabase = Supabase.instance.client;

    final nombreArchivo =
        '${DateTime.now().millisecondsSinceEpoch}_${archivo.path.split('/').last}';

    final ruta = '$carpeta/$nombreArchivo';

    try {
      await supabase.storage.from('imagenes').upload(
            ruta,
            archivo,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );

      final urlPublica = supabase.storage.from('imagenes').getPublicUrl(ruta);

      return urlPublica;
    } catch (e) {
      debugPrint("Error subiendo imagen: $e");
      return null;
    }
  }
}
