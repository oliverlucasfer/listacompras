/// Origem de uma imagem para OCR (RF-37): câmera ou galeria.
/// Devolve o caminho do arquivo, ou `null` se o usuário cancelar.
abstract interface class FonteImagem {
  Future<String?> daCamera();
  Future<String?> daGaleria();
}
