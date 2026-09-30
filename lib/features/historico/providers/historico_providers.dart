import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../listas/providers/listas_providers.dart';
import '../data/historico_compras_repository.dart';
import '../domain/ida.dart';

final historicoComprasRepositoryProvider = Provider<HistoricoComprasRepository>(
  (ref) => HistoricoComprasRepository(ref.watch(appDatabaseProvider)),
);

final idasProvider = StreamProvider<List<Ida>>(
  (ref) => ref.watch(historicoComprasRepositoryProvider).watchIdas(),
);

final idaProvider = FutureProvider.family<Ida?, String>(
  (ref, id) => ref.watch(historicoComprasRepositoryProvider).ida(id),
);

final itensDaIdaProvider = FutureProvider.family<List<ItemDaIda>, String>(
  (ref, idaId) =>
      ref.watch(historicoComprasRepositoryProvider).itensDaIda(idaId),
);

final resumoHistoricoProvider = FutureProvider<ResumoHistorico>(
  (ref) => ref.watch(historicoComprasRepositoryProvider).resumo(),
);
