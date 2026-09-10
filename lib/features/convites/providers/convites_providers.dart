import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/convites_repository.dart';

/// Repositório de convites (doc 08 §2–3, RF-13): chamadas diretas ao
/// servidor, sem fila offline (spec §4.1).
final convitesRepositoryProvider = Provider<ConvitesRepository>((ref) {
  return ConvitesRepository(Supabase.instance.client);
});
