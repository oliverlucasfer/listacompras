import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/categorias/sugestao_categorias.dart';
import '../../../core/dominio/categoria.dart';
import '../../../drift/database.dart';
import '../data/historico_precos_repository.dart';
import '../data/itens_repository.dart';
import '../data/listas_repository.dart';
import '../data/orcamento_categoria_repository.dart';
import '../domain/historico_preco.dart';
import '../domain/item.dart';
import '../domain/lista.dart';
import '../domain/lista_com_contagem.dart';
import '../domain/orcamento.dart';
import '../domain/sugestao_item.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

final listasRepositoryProvider = Provider<ListasRepository>(
  (ref) => ListasRepository(ref.watch(appDatabaseProvider)),
);

final itensRepositoryProvider = Provider<ItensRepository>(
  (ref) => ItensRepository(ref.watch(appDatabaseProvider)),
);

final sugestaoCategoriasProvider = Provider<SugestaoCategorias>(
  (ref) => SugestaoCategorias(ref.watch(appDatabaseProvider)),
);

final limitesCategoriaRepositoryProvider = Provider<LimitesCategoriaRepository>(
  (ref) => LimitesCategoriaRepository(ref.watch(appDatabaseProvider)),
);

final historicoPrecosRepositoryProvider = Provider<HistoricoPrecosRepository>(
  (ref) => HistoricoPrecosRepository(ref.watch(appDatabaseProvider)),
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

final listaPorIdProvider = StreamProvider.autoDispose.family<Lista?, String>((
  ref,
  listaId,
) {
  return ref.watch(listasRepositoryProvider).watchLista(listaId);
});

final itensDaListaProvider = StreamProvider.autoDispose
    .family<List<Item>, String>((ref, listaId) {
      return ref.watch(itensRepositoryProvider).watchItensDaLista(listaId);
    });

/// Total dos itens marcados com preço (RF-21): soma dos subtotais por
/// categoria — reusa a mesma varredura da lista.
final totalCarrinhoProvider = Provider.autoDispose.family<int, String>((
  ref,
  listaId,
) {
  final subtotais = ref.watch(subtotaisPorCategoriaProvider(listaId));
  return subtotais.values.fold(0, (total, valor) => total + valor);
});

/// Subtotal marcado por categoria (RF-36, F53-T04): derivado da lista.
final subtotaisPorCategoriaProvider = Provider.autoDispose
    .family<Map<CategoriaItem, int>, String>((ref, listaId) {
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
final resumoCarrinhoProvider = Provider.autoDispose
    .family<({int marcados, int semPreco}), String>((ref, listaId) {
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

/// Sugestões de itens frequentes da lista (RF-19). `autoDispose`: o ranking
/// só é assinado enquanto os chips estão visíveis (campo vazio), descartando
/// ao sair da tela ou começar a digitar.
final itensFrequentesProvider = StreamProvider.autoDispose
    .family<List<SugestaoItem>, String>(
      (ref, listaId) =>
          ref.watch(itensRepositoryProvider).watchItensFrequentes(listaId),
    );

/// Último preço pago pelo item (histórico local, RF-29, F37). Chave: nome.
/// `autoDispose`: o editor descarta a leitura ao fechar, re-lendo ao reabrir.
final historicoPrecoProvider = FutureProvider.autoDispose
    .family<HistoricoPreco?, String>((ref, nome) {
      return ref.watch(historicoPrecosRepositoryProvider).porNome(nome);
    });
