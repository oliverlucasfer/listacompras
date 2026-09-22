import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lista_compras/core/l10n/app_strings.dart';
import 'package:lista_compras/features/convites/data/convites_repository.dart';
import 'package:lista_compras/features/convites/providers/convites_providers.dart';
import 'package:lista_compras/features/convites/ui/convites_pendentes_secao.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'servidor_fake.dart';

const _listaId = 'lista-1';

Map<String, Object?> _convitePendente({
  String id = 'c1',
  String token = 't1',
  String titulo = 'Compras',
  String papel = 'editor',
  String expiraEm = '2026-09-28T12:00:00.000Z',
}) {
  return {
    'id': id,
    'token': token,
    'lista_titulo': titulo,
    'papel_oferecido': papel,
    'expira_em': expiraEm,
  };
}

ConvitesRepository _repo(ServidorFake servidor) => ConvitesRepository(
  SupabaseClient(
    'http://127.0.0.1:54321',
    'test-key',
    httpClient: servidor,
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  ),
);

Future<GoRouter> _abrir(WidgetTester tester, ServidorFake servidor) async {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: ConvitesPendentesSecao()),
      ),
      GoRoute(
        path: '/lista/:id',
        builder: (_, state) =>
            Scaffold(body: Text('lista-${state.pathParameters['id']}')),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        convitesRepositoryProvider.overrideWithValue(_repo(servidor)),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  testWidgets('deve_mostrar_convite_pendente_quando_ha', (tester) async {
    final servidor = ServidorFake((req) {
      if (req.method == 'POST' &&
          req.url.path.contains('meus_convites_pendentes')) {
        return (200, [_convitePendente()]);
      }
      return (500, {'message': 'inesperada: ${req.url.path}'});
    });
    addTearDown(servidor.close);
    await _abrir(tester, servidor);

    expect(find.text(AppStrings.convitesPendentes), findsOneWidget);
    expect(find.text(AppStrings.convitePara('Compras')), findsOneWidget);
    expect(find.text(AppStrings.convidarPapelEditor), findsOneWidget);
    expect(find.text(AppStrings.aceitar), findsOneWidget);
    expect(find.text(AppStrings.recusar), findsOneWidget);

    final expiraEm = DateTime.parse('2026-09-28T12:00:00.000Z');
    final dias = expiraEm.difference(DateTime.now()).inDays;
    expect(find.text(AppStrings.expiraEmDias(dias)), findsOneWidget);
  });

  testWidgets('deve_aceitar_e_navegar_quando_toca', (tester) async {
    final servidor = ServidorFake((req) {
      if (req.method == 'POST' &&
          req.url.path.contains('meus_convites_pendentes')) {
        return (200, [_convitePendente()]);
      }
      if (req.method == 'POST' && req.url.path.contains('aceitar_convite')) {
        return (200, _listaId);
      }
      return (500, {'message': 'inesperada: ${req.url.path}'});
    });
    addTearDown(servidor.close);
    await _abrir(tester, servidor);

    await tester.tap(find.widgetWithText(FilledButton, AppStrings.aceitar));
    await tester.pumpAndSettle();

    expect(
      servidor.pedidos.any((p) => p.url.path.contains('aceitar_convite')),
      isTrue,
    );
    expect(find.text('lista-$_listaId'), findsOneWidget);
  });

  testWidgets('deve_remover_card_quando_aceitar_e_voltar', (tester) async {
    // O provider não é autoDispose: sem invalidar, o card aceito reapareceria
    // ao voltar para o painel. O fake só devolve o pendente na 1ª chamada.
    var chamadas = 0;
    final servidor = ServidorFake((req) {
      if (req.method == 'POST' &&
          req.url.path.contains('meus_convites_pendentes')) {
        chamadas++;
        return (200, chamadas == 1 ? [_convitePendente()] : const <Object?>[]);
      }
      if (req.method == 'POST' && req.url.path.contains('aceitar_convite')) {
        return (200, _listaId);
      }
      return (500, {'message': 'inesperada: ${req.url.path}'});
    });
    addTearDown(servidor.close);
    final router = await _abrir(tester, servidor);
    expect(find.text(AppStrings.convitesPendentes), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, AppStrings.aceitar));
    await tester.pumpAndSettle();
    expect(find.text('lista-$_listaId'), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.convitesPendentes), findsNothing);
    expect(chamadas, greaterThanOrEqualTo(2));
  });

  testWidgets('deve_recusar_e_remover_quando_toca', (tester) async {
    var chamadas = 0;
    final servidor = ServidorFake((req) {
      if (req.method == 'POST' &&
          req.url.path.contains('meus_convites_pendentes')) {
        chamadas++;
        return (200, chamadas == 1 ? [_convitePendente()] : const <Object?>[]);
      }
      if (req.method == 'POST' && req.url.path.contains('recusar_convite')) {
        return (200, const <Object?>[]);
      }
      return (500, {'message': 'inesperada: ${req.url.path}'});
    });
    addTearDown(servidor.close);
    await _abrir(tester, servidor);
    expect(find.text(AppStrings.convitesPendentes), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, AppStrings.recusar));
    await tester.pumpAndSettle();

    expect(
      servidor.pedidos.any((p) => p.url.path.contains('recusar_convite')),
      isTrue,
    );
    expect(find.text(AppStrings.convitesPendentes), findsNothing);
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
    await _abrir(tester, servidor);

    expect(find.text(AppStrings.convitesPendentes), findsNothing);
  });
}
