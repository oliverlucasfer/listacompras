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
    listas: _mapas(json['listas']),
    itens: _mapas(json['itens']),
    historicoPrecos: _mapas(json['historicoPrecos']),
  );

  /// Converte a coleção de forma **eager** (não preguiçosa): um elemento que
  /// não seja um objeto falha já aqui, dentro do parse validado, em vez de
  /// estourar depois ao ler os campos de cada registro.
  static List<Map<String, Object?>> _mapas(Object? valor) =>
      (valor as List).map((e) => Map<String, Object?>.from(e as Map)).toList();
}
