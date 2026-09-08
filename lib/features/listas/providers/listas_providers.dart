import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/categorias/sugestao_categorias.dart';
import '../../../drift/database.dart';
import '../data/listas_repository.dart';
import '../domain/item.dart';
import '../domain/lista.dart';
import '../domain/lista_com_contagem.dart';

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
