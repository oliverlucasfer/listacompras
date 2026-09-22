import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/auth/data/supabase_auth_repository.dart';
import 'package:lista_compras/features/auth/providers/auth_providers.dart';
import 'package:lista_compras/features/convites/data/convites_repository.dart';
import 'package:lista_compras/features/convites/domain/convite_pendente.dart';
import 'package:lista_compras/features/convites/providers/convites_providers.dart';
import 'package:lista_compras/features/convites/ui/convites_pendentes_secao.dart';
import 'package:lista_compras/features/listas/providers/listas_providers.dart';
import 'package:lista_compras/features/sync/domain/sync_status.dart';
import 'package:lista_compras/features/sync/providers/sync_providers.dart';
import 'package:lista_compras/router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Sessão autenticada fake (padrão do `app_shell_test`): o app abre no painel.
class AuthAutenticado extends SupabaseAuthRepository {
  AuthAutenticado() : super(Supabase.instance.client);

  @override
  Stream<AuthState> get onAuthStateChange => const Stream<AuthState>.empty();

  @override
  Session? get sessaoAtual => Session(
    accessToken: 'token',
    tokenType: 'bearer',
    refreshToken: 'refresh',
    expiresIn: 3600,
    user: User(
      id: 'user-a',
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: DateTime.now().toIso8601String(),
    ),
  );
}

class FluxoApp {
  FluxoApp(this.db, this.container);
  final AppDatabase db;
  final ProviderContainer container;
}

/// Monta o app real (router) com Drift in-memory e sessão autenticada fake.
/// [convitesRepo] permite injetar um repositório com `ServidorFake` (ex.: para
/// o fluxo de "entrar com código").
Future<FluxoApp> montarApp(
  WidgetTester tester, {
  Future<void> Function(AppDatabase db)? seed,
  SyncStatus sync = const Sincronizado(),
  Future<List<ConvitePendente>> Function()? convites,
  ConvitesRepository? convitesRepo,
}) async {
  SharedPreferences.setMockInitialValues({'onboarding_visto': true});
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  if (seed != null) await seed(db);
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(AuthAutenticado()),
      appDatabaseProvider.overrideWithValue(db),
      syncStatusProvider.overrideWith((ref) => Stream<SyncStatus>.value(sync)),
      meusConvitesPendentesProvider.overrideWith(
        (ref) async =>
            convites == null ? const <ConvitePendente>[] : await convites(),
      ),
      if (convitesRepo != null)
        convitesRepositoryProvider.overrideWithValue(convitesRepo),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (context, ref, _) =>
            MaterialApp.router(routerConfig: ref.watch(routerProvider)),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return FluxoApp(db, container);
}

Future<void> fechar(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
}
