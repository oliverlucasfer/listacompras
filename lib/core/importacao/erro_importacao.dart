/// Erro da importação local (RF-16): mensagem amigável pronta para a UI.
class ErroImportacao implements Exception {
  const ErroImportacao(this.mensagem);

  final String mensagem;
}
