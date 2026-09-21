import '../../../drift/database.dart';

/// Modelo de domínio de lista (doc 05 §2).
class Lista {
  const Lista({
    required this.id,
    required this.titulo,
    required this.donoId,
    required this.criadoEm,
    required this.atualizadoEm,
    this.deletadoEm,
    this.arquivadaEm,
  });

  final String id;
  final String titulo;
  final String donoId;
  final DateTime criadoEm;
  final DateTime atualizadoEm;
  final DateTime? deletadoEm;
  final DateTime? arquivadaEm;

  factory Lista.fromLocal(ListaLocalData d) => Lista(
    id: d.id,
    titulo: d.titulo,
    donoId: d.donoId,
    criadoEm: d.createdAt,
    atualizadoEm: d.updatedAt,
    deletadoEm: d.deletadoEm,
    arquivadaEm: d.arquivadaEm,
  );
}
