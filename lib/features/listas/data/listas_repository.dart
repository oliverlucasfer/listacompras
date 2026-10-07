import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../drift/database.dart';
import '../domain/lista.dart';
import '../domain/lista_com_contagem.dart';
import 'itens_repository.dart';
import 'mappers.dart';

/// Repositório de **listas** (RF-02/RF-04, doc 05 §2): toda escrita aplica no
/// Drift (fonte de verdade local); a leitura expõe Streams do Drift — UI
/// reativa, nunca bloqueia em rede.
///
/// As operações de **itens** (RF-03) vivem em [ItensRepository], exposto em
/// [itens] (composição). Código novo consome preferencialmente
/// `itensRepositoryProvider`; a field [itens] mantém o acesso com o mesmo
/// banco/gerador de UUID desta instância.
class ListasRepository {
  ListasRepository(this._db, {Uuid? uuid})
    : itens = ItensRepository(_db, uuid: uuid),
      _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final Uuid _uuid;

  /// Repositório de itens desta instância (composição).
  final ItensRepository itens;

  // ---- Leitura (Streams do Drift) ----

  Stream<List<Lista>> watchListas() {
    return (_db.select(_db.listaLocal)
          ..where((l) => l.deletadoEm.isNull())
          ..orderBy([(l) => OrderingTerm.desc(l.updatedAt)]))
        .watch()
        .map((rows) => rows.map((r) => r.toDomain()).toList());
  }

  Stream<Lista?> watchLista(String id) {
    return (_db.select(_db.listaLocal)..where((l) => l.id.equals(id)))
        .watchSingleOrNull()
        .map((row) => row?.toDomain());
  }

  Stream<List<ListaComContagem>> watchListasComContagem() {
    return _db
        .customSelect(
          '''
    SELECT l.id, l.titulo, l.dono_id, l.created_at, l.updated_at,
           l.arquivada_em, l.orcamento_centavos,
           COUNT(i.id) AS total_itens,
           COUNT(CASE WHEN i.concluido = 1 THEN 1 END) AS itens_concluidos
    FROM lista_local l
    LEFT JOIN item_local i ON i.lista_id = l.id AND i.deletado_em IS NULL
    WHERE l.deletado_em IS NULL
    GROUP BY l.id
    ORDER BY l.updated_at DESC
  ''',
          readsFrom: {_db.listaLocal, _db.itemLocal},
        )
        .watch()
        .map(
          (rows) => rows
              .map(
                (row) => ListaComContagem(
                  lista: Lista(
                    id: row.read<String>('id'),
                    titulo: row.read<String>('titulo'),
                    donoId: row.read<String>('dono_id'),
                    criadoEm: row.read<DateTime>('created_at'),
                    atualizadoEm: row.read<DateTime>('updated_at'),
                    arquivadaEm: row.read<DateTime?>('arquivada_em'),
                    orcamentoCentavos: row.read<int?>('orcamento_centavos'),
                  ),
                  totalItens: row.read<int>('total_itens'),
                  concluidos: row.read<int>('itens_concluidos'),
                ),
              )
              .toList(),
        );
  }

  // ---- Escritas (o Drift local é a fonte de verdade) ----

  Future<Lista> criarLista({required String titulo, required String donoId}) {
    return _db.transaction(() async {
      final agora = DateTime.now().toUtc();
      final id = _uuid.v4();
      await _db
          .into(_db.listaLocal)
          .insert(
            ListaLocalCompanion.insert(
              id: id,
              createdAt: agora,
              updatedAt: agora,
              titulo: titulo,
              donoId: donoId,
            ),
          );
      return Lista(
        id: id,
        titulo: titulo,
        donoId: donoId,
        criadoEm: agora,
        atualizadoEm: agora,
      );
    });
  }

  Future<void> renomearLista({required String id, required String titulo}) {
    return _db.transaction(() async {
      final agora = DateTime.now().toUtc();
      await (_db.update(_db.listaLocal)..where((l) => l.id.equals(id))).write(
        ListaLocalCompanion(titulo: Value(titulo), updatedAt: Value(agora)),
      );
    });
  }

  Future<void> excluirLista(String id) {
    return _db.transaction(() async {
      final agora = DateTime.now().toUtc();
      await (_db.update(_db.listaLocal)..where((l) => l.id.equals(id))).write(
        ListaLocalCompanion(deletadoEm: Value(agora), updatedAt: Value(agora)),
      );
    });
  }

  /// Arquiva/desarquiva a lista (RF-22).
  Future<void> definirArquivada(String id, {required bool arquivada}) {
    return _db.transaction(() async {
      final agora = DateTime.now().toUtc();
      await (_db.update(_db.listaLocal)..where((l) => l.id.equals(id))).write(
        ListaLocalCompanion(
          arquivadaEm: Value(arquivada ? agora : null),
          updatedAt: Value(agora),
        ),
      );
    });
  }

  /// Define/limpa o orçamento da lista (RF-28, F36). `centavos == null`
  /// remove o orçamento; `0` é um orçamento válido.
  Future<void> definirOrcamento(String id, {required int? centavos}) {
    if (centavos != null && (centavos < 0 || centavos > 99999999)) {
      throw ArgumentError.value(centavos, 'centavos');
    }
    return _db.transaction(() async {
      final agora = DateTime.now().toUtc();
      await (_db.update(_db.listaLocal)..where((l) => l.id.equals(id))).write(
        ListaLocalCompanion(
          orcamentoCentavos: Value(centavos),
          updatedAt: Value(agora),
        ),
      );
    });
  }

  /// Duplica uma lista a partir dos itens **pendentes** (RF-20, "comprar de
  /// novo"): cria uma lista nova do `donoId` e copia nome/quantidade/unidade/
  /// categoria de cada pendente, na ordem original; a origem não é tocada.
  /// Insere a lista nova e os itens num único `batch`, com `ordem` 0,1,2,....
  Future<Lista> duplicarLista({
    required String origemId,
    required String titulo,
    required String donoId,
  }) {
    return _db.transaction(() async {
      final pendentes =
          await (_db.select(_db.itemLocal)
                ..where(
                  (i) =>
                      i.listaId.equals(origemId) &
                      i.deletadoEm.isNull() &
                      i.concluido.equals(false),
                )
                ..orderBy([
                  (i) => OrderingTerm.asc(i.ordem),
                  (i) => OrderingTerm.asc(i.id),
                ]))
              .get();
      if (pendentes.isEmpty) {
        throw StateError('não há itens pendentes para duplicar');
      }

      final agora = DateTime.now().toUtc();
      final novaId = _uuid.v4();
      await _db
          .into(_db.listaLocal)
          .insert(
            ListaLocalCompanion.insert(
              id: novaId,
              createdAt: agora,
              updatedAt: agora,
              titulo: titulo,
              donoId: donoId,
            ),
          );
      await _db.batch((b) {
        for (var ordem = 0; ordem < pendentes.length; ordem++) {
          final item = pendentes[ordem];
          b.insert(
            _db.itemLocal,
            ItemLocalCompanion.insert(
              id: _uuid.v4(),
              createdAt: agora,
              updatedAt: agora,
              listaId: novaId,
              nome: item.nome,
              quantidade: Value(item.quantidade),
              unidade: Value(item.unidade),
              categoria: Value(item.categoria),
              precoCentavos: Value(item.precoCentavos),
              ordem: Value(ordem),
            ),
          );
        }
      });
      return Lista(
        id: novaId,
        titulo: titulo,
        donoId: donoId,
        criadoEm: agora,
        atualizadoEm: agora,
      );
    });
  }
}
