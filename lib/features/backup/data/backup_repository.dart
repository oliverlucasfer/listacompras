import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/config/usuario_local.dart';
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

/// Backup válido, mas que não pôde ser restaurado (FK/CHECK). O banco é
/// revertido pela transação.
class BackupRestauracaoException implements Exception {
  const BackupRestauracaoException(this.mensagem);
  final String mensagem;
  @override
  String toString() => 'BackupRestauracaoException: $mensagem';
}

class BackupRepository {
  BackupRepository(this._db);

  final AppDatabase _db;

  String _iso(DateTime d) => d.toUtc().toIso8601String();

  Future<String> exportarJson() async {
    final listas = await _db.select(_db.listaLocal).get();
    final itens = await _db.select(_db.itemLocal).get();
    final historico = await _db.select(_db.historicoPrecoLocal).get();
    final idas = await _db.select(_db.idaCompra).get();
    final itensIda = await _db.select(_db.itemIda).get();
    final orcamentoCategoria = await _db.select(_db.orcamentoCategoria).get();

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
      idas: idas
          .map(
            (i) => <String, Object?>{
              'id': i.id,
              'lista_id': i.listaId,
              'titulo': i.titulo,
              'finalizada_em': _iso(i.finalizadaEm),
              'total_centavos': i.totalCentavos,
              'itens_count': i.itensCount,
              'mercado': i.mercado,
            },
          )
          .toList(),
      itensIda: itensIda
          .map(
            (i) => <String, Object?>{
              'id': i.id,
              'ida_id': i.idaId,
              'nome': i.nome,
              'quantidade': i.quantidade,
              'unidade': i.unidade,
              'categoria': i.categoria,
              'preco_centavos': i.precoCentavos,
            },
          )
          .toList(),
      // Orçamento por categoria (RF-36): limites locais; backup sobrescreve o
      // alvo (a tabela não tem `updated_at`), como as idas por `id`.
      orcamentoCategoria: orcamentoCategoria
          .map(
            (o) => <String, Object?>{
              'categoria': o.categoria,
              'limite_centavos': o.limiteCentavos,
            },
          )
          .toList(),
    );
    return jsonEncode(arquivo.toJson());
  }

  DateTime? _parseOpt(Object? v) =>
      v == null ? null : DateTime.parse(v as String);

  Future<void> importarJson(String conteudo) async {
    late final BackupArquivo arquivo;
    try {
      final mapa = jsonDecode(conteudo) as Map<String, dynamic>;
      if (!BackupArquivo.versoesSuportadas.contains(mapa['versao'])) {
        throw BackupInvalidoException(
          'Versão de backup não suportada: ${mapa['versao']}',
        );
      }
      arquivo = BackupArquivo.fromJson(mapa);
    } on BackupInvalidoException {
      rethrow;
    } on FormatException {
      throw const BackupInvalidoException('JSON inválido');
    } on TypeError {
      throw const BackupInvalidoException('JSON inválido');
    }

    try {
      await _db.transaction(() async {
        for (final l in arquivo.listas) {
          final id = l['id'] as String;
          final atualizadoEm = DateTime.parse(l['updated_at'] as String);
          final existente = await (_db.select(
            _db.listaLocal,
          )..where((t) => t.id.equals(id))).getSingleOrNull();
          if (existente != null && !atualizadoEm.isAfter(existente.updatedAt)) {
            continue;
          }
          await _db
              .into(_db.listaLocal)
              .insertOnConflictUpdate(
                ListaLocalCompanion.insert(
                  id: id,
                  createdAt: DateTime.parse(l['created_at'] as String),
                  updatedAt: atualizadoEm,
                  titulo: l['titulo'] as String,
                  donoId: idLocal,
                  deletadoEm: Value(_parseOpt(l['deletado_em'])),
                  arquivadaEm: Value(_parseOpt(l['arquivada_em'])),
                  orcamentoCentavos: Value(l['orcamento_centavos'] as int?),
                ),
              );
        }

        for (final i in arquivo.itens) {
          final id = i['id'] as String;
          final atualizadoEm = DateTime.parse(i['updated_at'] as String);
          final existente = await (_db.select(
            _db.itemLocal,
          )..where((t) => t.id.equals(id))).getSingleOrNull();
          if (existente != null && !atualizadoEm.isAfter(existente.updatedAt)) {
            continue;
          }
          await _db
              .into(_db.itemLocal)
              .insertOnConflictUpdate(
                ItemLocalCompanion.insert(
                  id: id,
                  listaId: i['lista_id'] as String,
                  nome: i['nome'] as String,
                  quantidade: Value((i['quantidade'] as num).toDouble()),
                  unidade: Value(i['unidade'] as String),
                  categoria: Value(i['categoria'] as String),
                  precoCentavos: Value(i['preco_centavos'] as int?),
                  concluido: Value(i['concluido'] as bool),
                  ordem: Value(i['ordem'] as int),
                  createdAt: DateTime.parse(i['created_at'] as String),
                  updatedAt: atualizadoEm,
                  deletadoEm: Value(_parseOpt(i['deletado_em'])),
                ),
              );
        }

        // Histórico de preços é local-only (05 §6.3): importa como está.
        for (final h in arquivo.historicoPrecos) {
          final nome = h['nome_normalizado'] as String;
          final registradoEm = DateTime.parse(h['registrado_em'] as String);
          final existente = await (_db.select(
            _db.historicoPrecoLocal,
          )..where((t) => t.nomeNormalizado.equals(nome))).getSingleOrNull();
          if (existente != null &&
              !registradoEm.isAfter(existente.registradoEm)) {
            continue;
          }
          await _db
              .into(_db.historicoPrecoLocal)
              .insertOnConflictUpdate(
                HistoricoPrecoLocalCompanion.insert(
                  nomeNormalizado: nome,
                  precoCentavos: h['preco_centavos'] as int,
                  unidade: h['unidade'] as String,
                  registradoEm: registradoEm,
                ),
              );
        }
        // Idas de compra (RF-34, F50): snapshots imutáveis — restaura antes
        // dos itens (FK `itens_ida.ida_id`) e faz merge por `id`.
        for (final ida in arquivo.idas) {
          await _db
              .into(_db.idaCompra)
              .insertOnConflictUpdate(
                IdaCompraCompanion.insert(
                  id: ida['id'] as String,
                  listaId: Value(ida['lista_id'] as String?),
                  titulo: ida['titulo'] as String,
                  finalizadaEm: DateTime.parse(ida['finalizada_em'] as String),
                  totalCentavos: Value(ida['total_centavos'] as int? ?? 0),
                  itensCount: Value(ida['itens_count'] as int? ?? 0),
                  mercado: Value(ida['mercado'] as String?),
                ),
              );
        }

        for (final i in arquivo.itensIda) {
          await _db
              .into(_db.itemIda)
              .insertOnConflictUpdate(
                ItemIdaCompanion.insert(
                  id: i['id'] as String,
                  idaId: i['ida_id'] as String,
                  nome: i['nome'] as String,
                  quantidade: Value((i['quantidade'] as num).toDouble()),
                  unidade: Value(i['unidade'] as String),
                  categoria: Value(i['categoria'] as String),
                  precoCentavos: Value(i['preco_centavos'] as int?),
                ),
              );
        }

        // Limites de orçamento por categoria (RF-36): sem FK; sobrescreve pelo
        // backup (merge não-LWW, como as idas).
        for (final o in arquivo.orcamentoCategoria) {
          await _db
              .into(_db.orcamentoCategoria)
              .insertOnConflictUpdate(
                OrcamentoCategoriaCompanion.insert(
                  categoria: o['categoria'] as String,
                  limiteCentavos: Value(o['limite_centavos'] as int?),
                ),
              );
        }
      });
    } on BackupInvalidoException {
      rethrow;
    } on FormatException {
      throw const BackupInvalidoException('JSON inválido');
    } on TypeError {
      // Em Dart atual `CastError` é um alias de `TypeError`, então este `on`
      // cobre também falhas de `as`/`Map.from`/`List.cast` na leitura dos
      // campos de cada registro. A transação reverte o que já tiver sido
      // gravado, então o banco permanece inalterado.
      throw const BackupInvalidoException('JSON inválido');
    } catch (e) {
      // Backup válido, mas o banco recusou a restauração (FK/CHECK): a
      // transação reverte e o erro é distinto de arquivo inválido.
      throw BackupRestauracaoException(e.toString());
    }
  }
}
