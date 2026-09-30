import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../listas/providers/listas_providers.dart';
import '../data/compartilhamento_repository.dart';

final compartilhamentoRepositoryProvider = Provider<CompartilhamentoRepository>(
  (ref) => CompartilhamentoRepository(ref.watch(appDatabaseProvider)),
);
