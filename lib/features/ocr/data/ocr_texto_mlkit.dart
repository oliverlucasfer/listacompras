import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../domain/ocr_texto.dart';

class OcrTextoMlKit implements OcrTexto {
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  @override
  Future<String> extrair(String caminhoImagem) async {
    final input = InputImage.fromFilePath(caminhoImagem);
    final resultado = await _recognizer.processImage(input);
    return resultado.text;
  }

  @override
  void close() => _recognizer.close();
}
