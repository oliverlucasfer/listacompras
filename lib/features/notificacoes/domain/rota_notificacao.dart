String? rotaDaNotificacao(Map<String, Object?> data) {
  final tipo = data['tipo'];
  if (tipo == 'convite') {
    final token = data['token'];
    if (token is String && token.isNotEmpty) {
      return '/entrar?token=${Uri.encodeComponent(token)}';
    }
    return null;
  }
  if (tipo == 'membro') {
    final listaId = data['lista_id'];
    if (listaId is String && listaId.isNotEmpty) return '/lista/$listaId';
  }
  return null;
}
