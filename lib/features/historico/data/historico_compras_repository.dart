import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/dominio/categoria.dart';
import '../../../core/dominio/unidade.dart';
import '../../../core/texto/normalizar.dart';
import '../../../drift/database.dart';
import '../domain/estatisticas.dart';
import '../domain/ida.dart';
import '../domain/mercado.dart';

class HistoricoComprasRepository {
  HistoricoComprasRepository(this._db, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final Uuid _uuid;

  Future<Ida> finalizar(String listaId, {String? mercado}) {
    return _db.transaction(() async {
      final lista = await (_db.select(
        _db.listaLocal,
      )..where((l) => l.id.equals(listaId))).getSingle();
      final concluidos =
          await (_db.select(_db.itemLocal)
                ..where(
                  (i) =>
                      i.listaId.equals(listaId) &
                      i.concluido.equals(true) &
                      i.deletadoEm.isNull(),
                )
                ..orderBy([
                  (i) => OrderingTerm.asc(i.ordem),
                  (i) => OrderingTerm.asc(i.id),
                ]))
              .get();
      if (concluidos.isEmpty) {
        throw StateError('Nenhum item concluído para finalizar');
      }
      final agora = DateTime.now().toUtc();
      final idaId = _uuid.v4();
      var total = 0;
      for (final i in concluidos) {
        final preco = i.precoCentavos;
        if (preco != null) total += (i.quantidade * preco).round();
      }
      final mercadoLimpo = (mercado ?? '').trim();
      await _db
          .into(_db.idaCompra)
          .insert(
            IdaCompraCompanion.insert(
              id: idaId,
              listaId: Value(listaId),
              titulo: lista.titulo,
              finalizadaEm: agora,
              totalCentavos: Value(total),
              itensCount: Value(concluidos.length),
              mercado: Value(mercadoLimpo.isEmpty ? null : mercadoLimpo),
            ),
          );
      await _db.batch((b) {
        for (final i in concluidos) {
          b.insert(
            _db.itemIda,
            ItemIdaCompanion.insert(
              id: _uuid.v4(),
              idaId: idaId,
              nome: i.nome,
              quantidade: Value(i.quantidade),
              unidade: Value(i.unidade),
              categoria: Value(i.categoria),
              precoCentavos: Value(i.precoCentavos),
            ),
          );
        }
      });
      return Ida(
        id: idaId,
        listaId: listaId,
        titulo: lista.titulo,
        finalizadaEm: agora,
        totalCentavos: total,
        itensCount: concluidos.length,
        mercado: mercadoLimpo.isEmpty ? null : mercadoLimpo,
      );
    });
  }

  Stream<List<Ida>> watchIdas() =>
      (_db.select(_db.idaCompra)..orderBy([
            (t) => OrderingTerm.desc(t.finalizadaEm),
            (t) => OrderingTerm.asc(t.id),
          ]))
          .watch()
          .map((rows) => rows.map(Ida.fromLocal).toList());

  Future<Ida?> ida(String id) async {
    final row = await (_db.select(
      _db.idaCompra,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : Ida.fromLocal(row);
  }

  Future<List<ItemDaIda>> itensDaIda(String idaId) async {
    final rows =
        await (_db.select(_db.itemIda)
              ..where((t) => t.idaId.equals(idaId))
              ..orderBy([
                (t) => OrderingTerm.asc(t.nome),
                (t) => OrderingTerm.asc(t.id),
              ]))
            .get();
    return rows.map(ItemDaIda.fromLocal).toList();
  }

  Future<ResumoHistorico> resumo() async {
    final linha = await _db
        .customSelect(
          'SELECT COUNT(*) AS n, COALESCE(SUM(total_centavos), 0) AS total '
          'FROM ida_compra',
        )
        .getSingle();
    final n = linha.read<int>('n');
    final total = linha.read<int>('total');
    return ResumoHistorico(
      totalGeralCentavos: total,
      ticketMedioCentavos: n == 0 ? 0 : (total / n).round(),
      nIdas: n,
    );
  }

  Future<List<GastoPorMes>> gastoPorMes() async {
    // `substr(1,7)` em vez de `strftime`: as datas são texto ISO-8601 do Drift
    // (`storeDateTimeAsText`) e o parsing fica em Dart.
    final linhas = await _db
        .customSelect(
          'SELECT substr(finalizada_em, 1, 7) AS ano_mes, '
          'SUM(total_centavos) AS total FROM ida_compra '
          'GROUP BY ano_mes ORDER BY ano_mes',
        )
        .get();
    return [
      for (final r in linhas)
        GastoPorMes(
          mes: DateTime.utc(
            int.parse(r.read<String>('ano_mes').substring(0, 4)),
            int.parse(r.read<String>('ano_mes').substring(5, 7)),
          ),
          totalCentavos: r.read<int>('total'),
        ),
    ];
  }

  Future<List<GastoPorCategoria>> gastoPorCategoria() async {
    final linhas = await _db
        .customSelect(
          'SELECT categoria, '
          'SUM(CAST(ROUND(quantidade * preco_centavos) AS INTEGER)) AS total '
          'FROM item_ida WHERE preco_centavos IS NOT NULL '
          'GROUP BY categoria',
        )
        .get();
    final lista =
        [
          for (final r in linhas)
            GastoPorCategoria(
              categoria: CategoriaItem.fromValor(r.read<String>('categoria')),
              totalCentavos: r.read<int>('total'),
            ),
        ]..sort((a, b) {
          final c = b.totalCentavos.compareTo(a.totalCentavos);
          return c != 0 ? c : a.categoria.valor.compareTo(b.categoria.valor);
        });
    return lista;
  }

  Future<List<ItemFrequente>> itensMaisComprados({int limite = 10}) async {
    final itens = await _db.select(_db.itemIda).get();
    final vezes = <String, int>{};
    final totais = <String, int>{};
    final nomes = <String, String>{};
    for (final i in itens) {
      final chave = normalizarTexto(i.nome);
      nomes.putIfAbsent(chave, () => i.nome);
      vezes[chave] = (vezes[chave] ?? 0) + 1;
      final preco = i.precoCentavos;
      if (preco != null) {
        totais[chave] = (totais[chave] ?? 0) + (i.quantidade * preco).round();
      }
    }
    final lista =
        [
          for (final chave in vezes.keys)
            ItemFrequente(
              nome: nomes[chave]!,
              vezes: vezes[chave]!,
              totalCentavos: totais[chave] ?? 0,
            ),
        ]..sort((a, b) {
          final c = b.vezes.compareTo(a.vezes);
          return c != 0 ? c : a.nome.compareTo(b.nome);
        });
    return lista.take(limite).toList();
  }

  Future<List<String>> nomesComprados() async {
    final itens = await _db.select(_db.itemIda).get();
    final chaves = {for (final i in itens) normalizarTexto(i.nome)};
    final lista = chaves.toList()..sort();
    return lista;
  }

  Future<List<PontoPreco>> evolucaoPreco(
    String nomeNormalizado,
    Unidade unidade,
  ) async {
    final consulta = _db.select(_db.itemIda).join([
      innerJoin(_db.idaCompra, _db.idaCompra.id.equalsExp(_db.itemIda.idaId)),
    ])..where(_db.itemIda.unidade.equals(unidade.valor));
    final linhas = await consulta.get();
    final pontos = <PontoPreco>[];
    for (final linha in linhas) {
      final i = linha.readTable(_db.itemIda);
      final ida = linha.readTable(_db.idaCompra);
      if (normalizarTexto(i.nome) != nomeNormalizado) continue;
      if (i.unidade != unidade.valor) continue;
      final preco = i.precoCentavos;
      if (preco == null) continue;
      pontos.add(
        PontoPreco(
          data: ida.finalizadaEm,
          precoCentavos: preco,
          unidade: unidade,
        ),
      );
    }
    pontos.sort((a, b) => a.data.compareTo(b.data));
    return pontos;
  }

  Future<Unidade?> unidadeRecenteComprada(String nomeNormalizado) async {
    final consulta = _db.select(_db.itemIda).join([
      innerJoin(_db.idaCompra, _db.idaCompra.id.equalsExp(_db.itemIda.idaId)),
    ])..where(_db.itemIda.precoCentavos.isNotNull());
    final linhas = await consulta.get();
    final pontos = <(DateTime, String)>[];
    for (final linha in linhas) {
      final i = linha.readTable(_db.itemIda);
      if (normalizarTexto(i.nome) != nomeNormalizado) continue;
      if (i.precoCentavos == null) continue;
      pontos.add((linha.readTable(_db.idaCompra).finalizadaEm, i.unidade));
    }
    if (pontos.isEmpty) return null;
    pontos.sort((a, b) => a.$1.compareTo(b.$1));
    return Unidade.fromValor(pontos.last.$2);
  }

  Future<List<String>> mercadosUsados() async {
    final idas = await _db.select(_db.idaCompra).get();
    final vistos = <String, String>{}; // normalizado -> exibição
    for (final i in idas) {
      final m = i.mercado;
      if (m == null || m.trim().isEmpty) continue;
      vistos.putIfAbsent(normalizarTexto(m), () => m);
    }
    final lista = vistos.values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return lista;
  }

  Future<List<PrecoMercado>> precosPorMercado(
    String nomeNormalizado,
    Unidade unidade,
  ) async {
    final consulta =
        _db.select(_db.itemIda).join([
          innerJoin(
            _db.idaCompra,
            _db.idaCompra.id.equalsExp(_db.itemIda.idaId),
          ),
        ])..where(
          _db.itemIda.unidade.equals(unidade.valor) &
              _db.itemIda.precoCentavos.isNotNull(),
        );
    final linhas = await consulta.get();
    // Último preço por mercado (normalizado), só mesma unidade e com preço.
    final porMercado = <String, PrecoMercado>{};
    final exibicao = <String, String>{};
    for (final linha in linhas) {
      final i = linha.readTable(_db.itemIda);
      final ida = linha.readTable(_db.idaCompra);
      final m = ida.mercado;
      if (m == null || m.trim().isEmpty) continue;
      if (normalizarTexto(i.nome) != nomeNormalizado) continue;
      if (i.unidade != unidade.valor) continue;
      final preco = i.precoCentavos;
      if (preco == null) continue;
      final chave = normalizarTexto(m);
      exibicao.putIfAbsent(chave, () => m);
      final atual = porMercado[chave];
      if (atual == null || ida.finalizadaEm.isAfter(atual.data)) {
        porMercado[chave] = PrecoMercado(
          mercado: exibicao[chave]!,
          precoCentavos: preco,
          data: ida.finalizadaEm,
        );
      }
    }
    final lista = porMercado.values.toList()
      ..sort((a, b) => a.precoCentavos.compareTo(b.precoCentavos));
    return lista;
  }

  Future<List<GastoPorMercado>> gastoPorMercado() async {
    final linhas = await _db
        .customSelect(
          'SELECT mercado, SUM(total_centavos) AS total FROM ida_compra '
          'GROUP BY mercado',
        )
        .get();
    final totais = <String?, int>{};
    final exibicao = <String, String>{};
    for (final r in linhas) {
      final m = r.read<String?>('mercado');
      final chave = (m == null || m.trim().isEmpty) ? null : normalizarTexto(m);
      if (chave != null) exibicao.putIfAbsent(chave, () => m!);
      totais[chave] = (totais[chave] ?? 0) + r.read<int>('total');
    }
    final lista =
        [
          for (final e in totais.entries)
            GastoPorMercado(
              mercado: e.key == null ? null : exibicao[e.key]!,
              totalCentavos: e.value,
            ),
        ]..sort((a, b) {
          final c = b.totalCentavos.compareTo(a.totalCentavos);
          if (c != 0) return c;
          if (a.mercado == null) return 1;
          if (b.mercado == null) return -1;
          return a.mercado!.toLowerCase().compareTo(b.mercado!.toLowerCase());
        });
    return lista;
  }
}
