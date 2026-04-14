import 'package:image_picker/image_picker.dart';

class ServicioImagenes {
  static Future<String?> seleccionarImagen() async {
    final selector = ImagePicker();
    final archivo = await selector.pickImage(source: ImageSource.gallery);
    return archivo?.path;
  }
}
