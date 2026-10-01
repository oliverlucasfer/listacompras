/// Notificação local do sistema (RF-36, F53-T05). 100% local: sem push nem
/// rede; o app só pede ao SO para exibir um aviso no aparelho.
abstract interface class NotificacaoLocal {
  /// Pede permissão de notificação ao SO. Retorna se foi concedida.
  Future<bool> pedirPermissao();

  /// Exibe uma notificação local. Best-effort: quem chama deve tolerar falhas.
  Future<void> mostrar({required String titulo, required String corpo});
}
