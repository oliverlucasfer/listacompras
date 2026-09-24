/// Usuário da sessão corrente (RF-01). Abstrai `Session` do Supabase para que
/// o modo Lite (RF-31) funcione sem o SDK.
class UsuarioAtual {
  const UsuarioAtual({required this.id, this.email});

  final String id;
  final String? email;
}

/// Evento de mudança de sessão (login/logout/refresh/recuperação de senha).
class EventoSessao {
  const EventoSessao({this.usuario, this.recuperacaoDeSenha = false});

  final UsuarioAtual? usuario;
  final bool recuperacaoDeSenha;
}
