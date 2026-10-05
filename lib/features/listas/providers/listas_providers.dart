import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/categorias/sugestao_categorias.dart';
import '../../../core/dominio/categoria.dart';
import '../../../drift/database.dart';
import '../data/historico_precos_repository.dart';
import '../data/listas_repository.dart';
import '../data/orcamento_categoria_repository.dart';
import '../domain/historico_preco.dart';
import '../domain/item.dart';
import '../domain/lista.dart';
import '../domain/lista_com_contagem.dart';
import '../domain/orcamento.dart';
import '../domain/preco.dart';
import '../domain/sugestao_item.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

final listasRepositoryProvider = Provider<ListasRepository>(
  (ref) => ListasRepository(ref.watch(appDatabaseProvider)),
);

final sugestaoCategoriasProvider = Provider<SugestaoCategorias>(
  (ref) => SugestaoCategorias(ref.watch(appDatabaseProvider)),
);

final limitesCategoriaRepositoryProvider = Provider<LimitesCategoriaRepository>(
  (ref) => LimitesCategoriaRepository(ref.watch(appDatabaseProvider)),
);

/// Limites de orçamento por categoria (RF-36, F53). Stream do Drift.
final limitesCategoriaProvider = StreamProvider<Map<CategoriaItem, int>>(
  (ref) => ref.watch(limitesCategoriaRepositoryProvider).watchLimites(),
);

final listasProvider = StreamProvider<List<Lista>>(
  (ref) => ref.watch(listasRepositoryProvider).watchListas(),
);

final listasComContagemProvider = StreamProvider<List<ListaComContagem>>(
  (ref) => ref.watch(listasRepositoryProvider).watchListasComContagem(),
);

final listaPorIdProvider = StreamProvider.family<Lista?, String>((
  ref,
  listaId,
) {
  return ref.watch(listasRepositoryProvider).watchLista(listaId);
});

final itensDaListaProvider = StreamProvider.family<List<Item>, String>((
  ref,
  listaId,
) {
  return ref.watch(listasRepositoryProvider).watchItensDaLista(listaId);
});

/// Total dos itens marcados com preço (RF-21): derivado da lista de itens.
final totalCarrinhoProvider = Provider.family<int, String>((ref, listaId) {
  final itens =
      ref.watch(itensDaListaProvider(listaId)).value ?? const <Item>[];
  return totalCarrinho(itens);
});

/// Subtotal marcado por categoria (RF-36, F53-T04): derivado da lista.
final subtotaisPorCategoriaProvider =
    Provider.family<Map<CategoriaItem, int>, String>((ref, listaId) {
      final itens =
          ref.watch(itensDaListaProvider(listaId)).value ?? const <Item>[];
      final mapa = <CategoriaItem, int>{};
      for (final item in itens) {
        if (!item.concluido) continue;
        mapa[item.categoria] =
            (mapa[item.categoria] ?? 0) + subtotalMarcado(item);
      }
      return mapa;
    });

/// (marcados, semPreço) para a faixa do total (RF-21): derivado da lista.
final resumoCarrinhoProvider =
    Provider.family<({int marcados, int semPreco}), String>((ref, listaId) {
      final itens =
          ref.watch(itensDaListaProvider(listaId)).value ?? const <Item>[];
      var marcados = 0;
      var semPreco = 0;
      for (final item in itens) {
        if (!item.concluido) continue;
        marcados++;
        if (item.precoCentavos == null) semPreco++;
      }
      return (marcados: marcados, semPreco: semPreco);
    });

/// Sugestões de itens frequentes da lista (RF-19).
final itensFrequentesProvider =
    StreamProvider.family<List<SugestaoItem>, String>(
      (ref, listaId) =>
          ref.watch(listasRepositoryProvider).watchItensFrequentes(listaId),
    );

/// Último preço pago pelo item (histórico local, RF-29, F37). Chave: nome.
/// `autoDispose`: o editor descarta a leitura ao fechar, re-lendo ao reabrir.
final historicoPrecoProvider = FutureProvider.autoDispose
    .family<HistoricoPreco?, String>((ref, nome) async {
      return HistoricoPrecosRepository(
        ref.watch(appDatabaseProvider),
      ).porNome(nome);
    });
