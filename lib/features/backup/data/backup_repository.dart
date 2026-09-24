import 'dart:convert';

import '../../../drift/database.dart';
import '../domain/backup_arquivo.dart';

/// Backup inválido (JSON malformado ou versão desconhecida). O banco **não** é
/// alterado quando isto é lançado.
class BackupInvalidoException implements Exception {
  const BackupInvalidoException(this.mensagem);
  final String mensagem;
  @override
  String toString() => 'BackupInvalidoException: $mensagem';
}

class BackupRepository {
  BackupRepository(this._db);

  final AppDatabase _db;

  String _iso(DateTime d) => d.toUtc().toIso8601String();

  Future<String> exportarJson() async {
    final listas = await (_db.select(
      _db.listaLocal,
    )..where((l) => l.deletadoEm.isNull())).get();
    final itens = await (_db.select(
      _db.itemLocal,
    )..where((i) => i.deletadoEm.isNull())).get();
    final historico = await _db.select(_db.historicoPrecoLocal).get();

    final arquivo = BackupArquivo(
      exportadoEm: DateTime.now().toUtc(),
      listas: listas
          .map(
            (l) => <String, Object?>{
              'id': l.id,
              'titulo': l.titulo,
              'dono_id': l.donoId,
              'created_at': _iso(l.createdAt),
              'updated_at': _iso(l.updatedAt),
              'arquivada_em': l.arquivadaEm == null
                  ? null
                  : _iso(l.arquivadaEm!),
              'orcamento_centavos': l.orcamentoCentavos,
              'deletado_em': l.deletadoEm == null ? null : _iso(l.deletadoEm!),
            },
          )
          .toList(),
      itens: itens
          .map(
            (i) => <String, Object?>{
              'id': i.id,
              'lista_id': i.listaId,
              'nome': i.nome,
              'quantidade': i.quantidade,
              'unidade': i.unidade,
              'categoria': i.categoria,
              'preco_centavos': i.precoCentavos,
              'concluido': i.concluido,
              'ordem': i.ordem,
              'created_at': _iso(i.createdAt),
              'updated_at': _iso(i.updatedAt),
              'deletado_em': i.deletadoEm == null ? null : _iso(i.deletadoEm!),
            },
          )
          .toList(),
      historicoPrecos: historico
          .map(
            (h) => <String, Object?>{
              'nome_normalizado': h.nomeNormalizado,
              'preco_centavos': h.precoCentavos,
              'unidade': h.unidade,
              'registrado_em': _iso(h.registradoEm),
            },
          )
          .toList(),
    );
    return jsonEncode(arquivo.toJson());
  }

  Future<void> importarJson(String conteudo) =>
      throw UnimplementedError('importação implementada na Task 10');
}
