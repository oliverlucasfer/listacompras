import 'papel.dart';

/// Convite por e-mail pendente dirigido ao usuário (RF-13, fluxo B, F32).
class ConvitePendente {
  const ConvitePendente({
    required this.id,
    required this.token,
    required this.listaTitulo,
    required this.papelOferecido,
    required this.expiraEm,
  });

  factory ConvitePendente.fromMap(Map<String, Object?> mapa) => ConvitePendente(
    id: mapa['id'] as String,
    token: mapa['token'] as String,
    listaTitulo: mapa['lista_titulo'] as String,
    papelOferecido: Papel.fromValor(mapa['papel_oferecido'] as String),
    expiraEm: DateTime.parse(mapa['expira_em'] as String),
  );

  final String id;
  final String token;
  final String listaTitulo;
  final Papel papelOferecido;
  final DateTime expiraEm;
}
