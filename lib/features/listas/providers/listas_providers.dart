import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../drift/database.dart';
import '../data/listas_repository.dart';
import '../domain/item.dart';
import '../domain/lista.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

final listasRepositoryProvider = Provider<ListasRepository>(
  (ref) => ListasRepository(ref.watch(appDatabaseProvider)),
);

final listasProvider = StreamProvider<List<Lista>>(
  (ref) => ref.watch(listasRepositoryProvider).watchListas(),
);

final itensDaListaProvider = StreamProvider.family<List<Item>, String>((
  ref,
  listaId,
) {
  return ref.watch(listasRepositoryProvider).watchItensDaLista(listaId);
});
