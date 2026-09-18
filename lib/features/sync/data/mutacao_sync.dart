/// Mutação pronta para envio (doc 03 §3): payload JSON decodificado com o
/// estado completo do registro.
class MutacaoSync {
  const MutacaoSync({
    required this.tabela,
    required this.operacao,
    required this.registroId,
    required this.listaId,
    required this.tsLocal,
    required this.payload,
    this.tentativas = 0,
    this.id = 0,
  });

  final String tabela;
  final String operacao;
  final String registroId;
  final String listaId;
  final DateTime tsLocal;
  final Map<String, Object?> payload;

  /// Contador de retry da linha (doc 03 §3) — usado nos relatórios 07 §4.
  final int tentativas;

  /// Id da linha em `mutacao_pendente` (0 quando a mutação não veio da fila):
  /// é o corte do coalescing — mutações enfileiradas depois do lote (id maior)
  /// sobrevivem ao flush (doc 03 §4, R-03).
  final int id;
}
