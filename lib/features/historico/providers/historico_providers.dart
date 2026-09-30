import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dominio/unidade.dart';
import '../../listas/providers/listas_providers.dart';
import '../data/historico_compras_repository.dart';
import '../domain/estatisticas.dart';
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

final resumoHistoricoProvider = Provider<AsyncValue<ResumoHistorico>>(
  (ref) => ref.watch(idasProvider).whenData(_resumoDeIdas),
);

final gastoPorMesProvider = FutureProvider<List<GastoPorMes>>((ref) {
  ref.watch(idasProvider);
  return ref.watch(historicoComprasRepositoryProvider).gastoPorMes();
});

final gastoPorCategoriaProvider = FutureProvider<List<GastoPorCategoria>>((
  ref,
) {
  ref.watch(idasProvider);
  return ref.watch(historicoComprasRepositoryProvider).gastoPorCategoria();
});

final itensMaisCompradosProvider = FutureProvider<List<ItemFrequente>>((ref) {
  ref.watch(idasProvider);
  return ref.watch(historicoComprasRepositoryProvider).itensMaisComprados();
});

final nomesCompradosProvider = FutureProvider<List<String>>((ref) {
  ref.watch(idasProvider);
  return ref.watch(historicoComprasRepositoryProvider).nomesComprados();
});

final unidadeRecenteProvider = FutureProvider.family<Unidade?, String>((
  ref,
  nome,
) {
  ref.watch(idasProvider);
  return ref
      .watch(historicoComprasRepositoryProvider)
      .unidadeRecenteComprada(nome);
});

final evolucaoPrecoProvider =
    FutureProvider.family<List<PontoPreco>, (String, Unidade)>((ref, args) {
      ref.watch(idasProvider);
      return ref
          .watch(historicoComprasRepositoryProvider)
          .evolucaoPreco(args.$1, args.$2);
    });

ResumoHistorico _resumoDeIdas(List<Ida> idas) {
  final total = idas.fold<int>(0, (s, i) => s + i.totalCentavos);
  final n = idas.length;
  return ResumoHistorico(
    totalGeralCentavos: total,
    ticketMedioCentavos: n == 0 ? 0 : (total / n).round(),
    nIdas: n,
  );
}
