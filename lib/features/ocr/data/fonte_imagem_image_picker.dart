import 'package:image_picker/image_picker.dart';

import '../domain/fonte_imagem.dart';

class FonteImagemImagePicker implements FonteImagem {
  final _picker = ImagePicker();

  @override
  Future<String?> daCamera() async =>
      (await _picker.pickImage(source: ImageSource.camera))?.path;

  @override
  Future<String?> daGaleria() async =>
      (await _picker.pickImage(source: ImageSource.gallery))?.path;
}
