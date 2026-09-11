import '../../../core/l10n/app_strings.dart';

/// Limite de entrada do contrato da IA (docs 04 §2/§3).
const int maxCaracteresEntradaIa = 2000;

/// Erro do contrato de IA (doc 04 §2): `code` para lógica, mensagem amigável
/// pronta para a UI.
class ErroIa implements Exception {
  const ErroIa(this.code, this.mensagem);

  final String code;
  final String mensagem;
}

/// Mensagem amigável por código do contrato (doc 04 §2) — fallback quando o
/// corpo do erro não traz `message`.
String mensagemContratoIa(String code) => switch (code) {
  'unauthorized' => AppStrings.iaSessaoExpirada,
  'texto_vazio' => AppStrings.iaTextoVazio,
  'texto_longo' => AppStrings.iaTextoLongo,
  'resposta_invalida' => AppStrings.iaRespostaInvalida,
  'rate_limit' => AppStrings.iaRateLimit,
  'cota_ia' => AppStrings.iaCotaIa,
  'timeout_ia' => AppStrings.iaTimeoutIa,
  _ => AppStrings.iaErroInterno,
};
