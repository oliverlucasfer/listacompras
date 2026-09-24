/// Formato do backup local (RF-31, F41). `versao` permite evolução futura.
class BackupArquivo {
  const BackupArquivo({
    required this.exportadoEm,
    required this.listas,
    required this.itens,
    required this.historicoPrecos,
  });

  static const versao = 1;

  final DateTime exportadoEm;
  final List<Map<String, Object?>> listas;
  final List<Map<String, Object?>> itens;
  final List<Map<String, Object?>> historicoPrecos;

  Map<String, Object?> toJson() => {
    'versao': versao,
    'exportadoEm': exportadoEm.toUtc().toIso8601String(),
    'listas': listas,
    'itens': itens,
    'historicoPrecos': historicoPrecos,
  };

  factory BackupArquivo.fromJson(Map<String, dynamic> json) => BackupArquivo(
    exportadoEm: DateTime.parse(json['exportadoEm'] as String),
    listas: (json['listas'] as List).cast<Map<String, Object?>>(),
    itens: (json['itens'] as List).cast<Map<String, Object?>>(),
    historicoPrecos: (json['historicoPrecos'] as List)
        .cast<Map<String, Object?>>(),
  );
}
