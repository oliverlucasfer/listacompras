import '../../../core/l10n/app_strings.dart';
import 'papel.dart';

/// Erro amigável do domínio de convites (doc 08 §3): `code` identifica a
/// causa; `message` já vem pronta para a UI — nunca vaza JSON bruto
/// (padrão de `ErroIa`, doc 04 §2).
class ErroConvite implements Exception {
  const ErroConvite(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'ErroConvite($code): $message';

  /// Mapeia os códigos do contrato do RPC `aceitar_convite` (doc 08 §3.1,
  /// migration 0007) para mensagens amigáveis.
  static ErroConvite fromCodigoDoContrato(String mensagemServidor) {
    final maiuscula = mensagemServidor.toUpperCase();
    if (maiuscula.contains('CONVITE_INVALIDO')) {
      return const ErroConvite('convite_invalido', AppStrings.conviteInvalido);
    }
    if (maiuscula.contains('CONVITE_NAO_DIRIGIDO_A_VOCE')) {
      return const ErroConvite(
        'convite_nao_dirigido_a_voce',
        AppStrings.conviteInesperado,
      );
    }
    return const ErroConvite('inesperado', AppStrings.conviteInesperado);
  }
}

/// Convite pendente/ativo de uma lista (doc 08 §2, tabela `convites`).
class Convite {
  const Convite({
    required this.id,
    required this.listaId,
    required this.token,
    required this.papelOferecido,
    required this.estado,
    required this.expiraEm,
  });

  factory Convite.fromMap(Map<String, Object?> mapa) {
    return Convite(
      id: mapa['id'] as String,
      listaId: mapa['lista_id'] as String,
      token: mapa['token'] as String,
      papelOferecido: Papel.fromValor(mapa['papel_oferecido'] as String),
      estado: mapa['estado'] as String,
      expiraEm: DateTime.parse(mapa['expira_em'] as String),
    );
  }

  final String id;
  final String listaId;
  final String token;
  final Papel papelOferecido;
  final String estado;
  final DateTime expiraEm;

  bool get expirado => expiraEm.isBefore(DateTime.now());
}

/// Membro de uma lista (tabela `lista_membros`).
class MembroLista {
  const MembroLista({required this.userId, required this.papel});

  factory MembroLista.fromMap(Map<String, Object?> mapa) {
    return MembroLista(
      userId: mapa['user_id'] as String,
      papel: Papel.fromValor(mapa['papel'] as String),
    );
  }

  final String userId;
  final Papel papel;
}
