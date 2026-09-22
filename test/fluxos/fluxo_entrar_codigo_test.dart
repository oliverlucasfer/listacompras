import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/l10n/app_strings.dart';
import 'package:lista_compras/features/convites/data/convites_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/fakes.dart';
import '../features/convites/servidor_fake.dart';
import 'fluxo_harness.dart';

void main() {
  setUpAll(inicializarSupabaseTeste);

  testWidgets('deve_entrar_com_codigo_quando_token_valido', (tester) async {
    final servidor = ServidorFake((req) {
      if (req.method == 'POST' && req.url.path.contains('aceitar_convite')) {
        return (200, 'lista-x');
      }
      return (500, {'message': 'inesperada: ${req.url.path}'});
    });
    addTearDown(servidor.close);

    await montarApp(
      tester,
      convitesRepo: ConvitesRepository(
        SupabaseClient(
          'http://127.0.0.1:54321',
          'test-key',
          httpClient: servidor,
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      ),
    );

    // Aba Compartilhadas → "Entrar com código"
    await tester.tap(find.text(AppStrings.compartilhadas));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(AppStrings.conviteComCodigo));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.conviteCampoCodigo),
      'token-cru',
    );
    await tester.tap(
      find.widgetWithText(FilledButton, AppStrings.conviteConvidadoEntrar),
    );
    await tester.pumpAndSettle();

    // Saiu do painel para a rota da lista (id inexistente → estado "não
    // encontrada").
    expect(find.text(AppStrings.listaNaoEncontrada), findsOneWidget);

    await fechar(tester);
  });
}
