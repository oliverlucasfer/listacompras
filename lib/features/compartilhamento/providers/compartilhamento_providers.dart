import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/plataforma.dart';
import '../../listas/providers/listas_providers.dart';
import '../data/compartilhamento_repository.dart';
import '../data/leitor_qr_plugin.dart';
import '../domain/leitor_qr.dart';

final compartilhamentoRepositoryProvider = Provider<CompartilhamentoRepository>(
  (ref) => CompartilhamentoRepository(ref.watch(appDatabaseProvider)),
);

/// Câmera só onde o scanner é suportado: Android/iOS (spec §7).
bool plataformaComCamera() => dispositivoMovel();

final leitorQrProvider = Provider<LeitorQr>((ref) => LeitorQrPlugin());
