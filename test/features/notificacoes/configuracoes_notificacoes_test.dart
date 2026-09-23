import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lista_compras/features/auth/providers/auth_providers.dart';
import 'package:lista_compras/features/configuracoes/ui/configuracoes_screen.dart';
import 'package:lista_compras/features/notificacoes/providers/notificacoes_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_notificacoes_push.dart';
import 'repositorio_tokens_fake.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('deve_mostrar_toggle_e_ativar_quando_tocado', (tester) async {
    final push = NotificacoesPushFake();
    final repo = RepositorioTokensFake();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          emailUsuarioProvider.overrideWithValue('oliveira@exemplo.com'),
          notificacoesPushProvider.overrideWithValue(push),
          pushTokensRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(home: ConfiguracoesScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SwitchListTile), findsOneWidget);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(repo.registrados, isNotEmpty);
  });
}
