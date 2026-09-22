import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/l10n/app_strings.dart';
import 'package:lista_compras/features/convites/data/convites_repository.dart';
import 'package:lista_compras/features/convites/providers/convites_providers.dart';
import 'package:lista_compras/features/convites/ui/convites_pendentes_secao.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'servidor_fake.dart';

void main() {
  testWidgets('deve_mostrar_convite_pendente_quando_ha', (tester) async {
    final servidor = ServidorFake((req) {
      if (req.method == 'POST' &&
          req.url.path.contains('meus_convites_pendentes')) {
        return (
          200,
          [
            {
              'id': 'c1',
              'token': 't1',
              'lista_titulo': 'Compras',
              'papel_oferecido': 'editor',
              'expira_em': '2026-09-28T12:00:00.000Z',
            },
          ],
        );
      }
      return (500, {'message': 'inesperada: ${req.url.path}'});
    });
    addTearDown(servidor.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          convitesRepositoryProvider.overrideWithValue(
            ConvitesRepository(
              SupabaseClient(
                'http://127.0.0.1:54321',
                'test-key',
                httpClient: servidor,
                authOptions: const AuthClientOptions(autoRefreshToken: false),
              ),
            ),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: ConvitesPendentesSecao()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.convitesPendentes), findsOneWidget);
    expect(find.text(AppStrings.convitePara('Compras')), findsOneWidget);
    expect(find.text(AppStrings.aceitar), findsOneWidget);
    expect(find.text(AppStrings.recusar), findsOneWidget);
  });

  testWidgets('nao_deve_mostrar_secao_quando_sem_pendentes', (tester) async {
    final servidor = ServidorFake((req) {
      if (req.method == 'POST' &&
          req.url.path.contains('meus_convites_pendentes')) {
        return (200, const <Object?>[]);
      }
      return (500, {'message': 'inesperada: ${req.url.path}'});
    });
    addTearDown(servidor.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          convitesRepositoryProvider.overrideWithValue(
            ConvitesRepository(
              SupabaseClient(
                'http://127.0.0.1:54321',
                'test-key',
                httpClient: servidor,
                authOptions: const AuthClientOptions(autoRefreshToken: false),
              ),
            ),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: ConvitesPendentesSecao()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.convitesPendentes), findsNothing);
  });
}
