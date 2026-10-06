/// Formato do backup local (RF-31, F41). `versao` permite evolução futura.
class BackupArquivo {
  const BackupArquivo({
    required this.exportadoEm,
    required this.listas,
    required this.itens,
    required this.historicoPrecos,
    this.idas = const [],
    this.itensIda = const [],
    this.orcamentoCategoria = const [],
  });

  static const versao = 2;

  /// Versão atual (`2`) mais a `1` legada, ainda importável (sem
  /// `idas`/`itensIda`, que passam a ser listas vazias).
  static const versoesSuportadas = {1, 2};

  final DateTime exportadoEm;
  final List<Map<String, Object?>> listas;
  final List<Map<String, Object?>> itens;
  final List<Map<String, Object?>> historicoPrecos;

  /// Idas de compra finalizadas (RF-34): snapshot imutável, merge por `id`.
  final List<Map<String, Object?>> idas;

  /// Itens (snapshot) das idas; restaurados **depois** das idas (FK).
  final List<Map<String, Object?>> itensIda;

  /// Limites de orçamento por categoria (RF-36). Campo **opcional**: backups
  /// v1/v2 não o trazem e são lidos como lista vazia (retrocompatível).
  final List<Map<String, Object?>> orcamentoCategoria;

  Map<String, Object?> toJson() => {
    'versao': versao,
    'exportadoEm': exportadoEm.toUtc().toIso8601String(),
    'listas': listas,
    'itens': itens,
    'historicoPrecos': historicoPrecos,
    'idas': idas,
    'itensIda': itensIda,
    'orcamentoCategoria': orcamentoCategoria,
  };

  factory BackupArquivo.fromJson(Map<String, dynamic> json) => BackupArquivo(
    exportadoEm: DateTime.parse(json['exportadoEm'] as String),
    listas: _mapas(json['listas']),
    itens: _mapas(json['itens']),
    historicoPrecos: _mapas(json['historicoPrecos']),
    idas: _mapas(json['idas'] ?? const []),
    itensIda: _mapas(json['itensIda'] ?? const []),
    orcamentoCategoria: _mapas(json['orcamentoCategoria'] ?? const []),
  );

  /// Converte a coleção de forma **eager** (não preguiçosa): um elemento que
  /// não seja um objeto falha já aqui, dentro do parse validado, em vez de
  /// estourar depois ao ler os campos de cada registro.
  static List<Map<String, Object?>> _mapas(Object? valor) =>
      (valor as List).map((e) => Map<String, Object?>.from(e as Map)).toList();
}
