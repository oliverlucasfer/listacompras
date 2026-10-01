/// OCR on-device (RF-37). A UI depende desta interface; os testes usam um fake.
abstract interface class OcrTexto {
  /// Reconhece o texto da imagem no [caminhoImagem]; devolve '' se não houver texto.
  Future<String> extrair(String caminhoImagem);
}
