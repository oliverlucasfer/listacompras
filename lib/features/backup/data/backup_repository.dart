import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../drift/database.dart';
import '../../auth/data/auth_local_repository.dart';
import '../../sync/data/outbox_mutacoes.dart';
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
  BackupRepository(
    this._db, {
    this.donoLocal = false,
    this._enfileirar = false,
  });

  final AppDatabase _db;

  /// No modo Lite (RF-31) o app é single-user: ao importar, toda lista passa a
  /// pertencer ao usuário local, descartando qualquer `dono_id` estrangeiro de
  /// um backup colaborativo (que tornaria alcançáveis caminhos "de membro"
  /// dependentes de `Supabase.instance`, não inicializado no Lite).
  final bool donoLocal;

  /// Modo colaborativo: cada registro restaurado alimenta a fila de mutações
  /// (doc 03 §3), para propagar ao Supabase sem esperar a próxima edição. No
  /// Lite permanece desligado (`enfileirar: false`), como o `ListasRepository`.
  final bool _enfileirar;
  late final OutboxMutacoes _outbox = OutboxMutacoes(_db, ativa: _enfileirar);

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

  DateTime? _parseOpt(Object? v) =>
      v == null ? null : DateTime.parse(v as String);

  Future<void> importarJson(String conteudo) async {
    try {
      final mapa = jsonDecode(conteudo) as Map<String, dynamic>;
      if (mapa['versao'] != BackupArquivo.versao) {
        throw BackupInvalidoException(
          'Versão de backup não suportada: ${mapa['versao']}',
        );
      }
      final arquivo = BackupArquivo.fromJson(mapa);

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
                  donoId: donoLocal
                      ? AuthLocalRepository.idLocal
                      : l['dono_id'] as String,
                  deletadoEm: Value(_parseOpt(l['deletado_em'])),
                  arquivadaEm: Value(_parseOpt(l['arquivada_em'])),
                  orcamentoCentavos: Value(l['orcamento_centavos'] as int?),
                ),
              );
          // Alimenta a fila (só no modo colaborativo — ver `enfileirar`): o
          // registro importado passa a subir para o Supabase. `INSERT` porque
          // o envio remoto decide insert × update sozinho e esse caminho mantém
          // o dedup de item por nome (03 §3). Fica **dentro** da transação: um
          // import que falha não enfileira nada. O `ts_local` é agora; quem
          // decide o LWW no servidor é o `updated_at` do payload (o importado).
          await _outbox.enfileirar(
            tabela: 'listas',
            operacao: 'INSERT',
            registroId: id,
            listaId: id,
            tsLocal: DateTime.now().toUtc(),
            payload: await _outbox.payloadLista(id, incluirArquivo: true),
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
          // Mesma regra da lista (03 §3); o `lista_id` agrupa o dreno por lista.
          await _outbox.enfileirar(
            tabela: 'itens_lista',
            operacao: 'INSERT',
            registroId: id,
            listaId: i['lista_id'] as String,
            tsLocal: DateTime.now().toUtc(),
            payload: await _outbox.payloadItem(id),
          );
        }

        // Histórico de preços é local-only (05 §6.3): importa, mas **nunca**
        // entra na fila.
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
      });
    } on FormatException {
      throw const BackupInvalidoException('JSON inválido');
    } on TypeError {
      // Em Dart atual `CastError` é um alias de `TypeError`, então este `on`
      // cobre também falhas de `as`/`Map.from`/`List.cast` na validação e na
      // leitura dos campos de cada registro. A transação reverte o que já
      // tiver sido gravado, então o banco permanece inalterado.
      throw const BackupInvalidoException('JSON inválido');
    }
  }
}
