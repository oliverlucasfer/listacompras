import '../../../core/l10n/app_strings.dart';
import '../../listas/domain/unidade.dart';

/// Limite de entrada do contrato (docs 04 §2/§3, wireframe 10 §4.1).
const int maxCaracteresEntradaIa = 2000;

/// Item extraído pela IA (doc 04 §2): quantidade > 0 e unidade restrita ao
/// enum fechado (doc 01 §3, ADR-005).
class ItemExtraido {
  const ItemExtraido({
    required this.nome,
    required this.quantidade,
    required this.unidade,
  });

  final String nome;
  final double quantidade;
  final Unidade unidade;
}

/// Resposta 200 do contrato `parse-lista` (doc 04 §2). `aviso` é a
/// observação da IA exibida no modal de pré-visualização (F4-T02).
class RespostaParse {
  const RespostaParse({required this.itens, required this.aviso});

  final List<ItemExtraido> itens;
  final String? aviso;
}

/// Erro do contrato de IA (doc 04 §2): `code` para lógica, mensagem
/// amigável pronta para a UI.
class ErroIa implements Exception {
  const ErroIa(this.code, this.mensagem);

  final String code;
  final String mensagem;
}

/// Mensagem amigável por código do contrato (doc 04 §2) — fallback quando
/// o corpo do erro não traz `message`.
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
