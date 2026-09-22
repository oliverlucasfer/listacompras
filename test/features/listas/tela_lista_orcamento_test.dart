import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/l10n/app_strings.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/convites/data/papel_repository.dart';
import 'package:lista_compras/features/convites/domain/papel.dart';
import 'package:lista_compras/features/convites/providers/papel_providers.dart';
import 'package:lista_compras/features/listas/data/listas_repository.dart';
import 'package:lista_compras/features/listas/providers/listas_providers.dart';
import 'package:lista_compras/features/listas/ui/tela_lista_screen.dart';
import 'package:lista_compras/features/sync/domain/sync_status.dart';
import 'package:lista_compras/features/sync/providers/sync_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../convites/servidor_fake.dart';
import '../auth/fakes.dart';

/// Orçamento por lista na tela da lista (RF-28, F36-T03, doc 05 §6.3).
void main() {
  setUpAll(inicializarSupabaseTeste);

  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({'onboarding_visto': true});
  });

  tearDown(() async {
    await db.close();
  });

  PapelRepository papelRepo(
    WidgetTester tester, {
    required String listaId,
    required Papel papel,
  }) {
    final servidor = ServidorFake((req) => (200, const <Object>[]));
    addTearDown(servidor.close);
    final repo = PapelRepository(
      SupabaseClient(
        'http://127.0.0.1:54321',
        'test-key',
        httpClient: servidor,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      ),
    );
    repo.atualizar(listaId, papel);
    return repo;
  }

  /// Abre a tela da lista para o papel informado, opcionalmente já com um
  /// orçamento definido; devolve o id da lista.
  Future<String> abrirLista(
    WidgetTester tester, {
    Papel papel = Papel.dono,
    int? orcamentoCentavos,
  }) async {
    final repo = ListasRepository(db);
    final lista = await repo.criarLista(
      titulo: 'Compras da Semana',
      donoId: 'user-a',
    );
    await repo.adicionarItem(listaId: lista.id, nome: 'Arroz');
    if (orcamentoCentavos != null) {
      await repo.definirOrcamento(lista.id, centavos: orcamentoCentavos);
    }
    final sync = StreamController<SyncStatus>();
    sync.add(const Sincronizado());
    addTearDown(sync.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          papelRepositoryProvider.overrideWithValue(
            papelRepo(tester, listaId: lista.id, papel: papel),
          ),
          syncStatusProvider.overrideWith((ref) => sync.stream),
        ],
        child: MaterialApp(home: TelaListaScreen(listaId: lista.id)),
      ),
    );
    await tester.pumpAndSettle();
    return lista.id;
  }

  Future<void> fechar(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  Future<void> abrirDialogoOrcamento(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.orcamento));
    await tester.pumpAndSettle();
  }

  Future<int?> orcamentoNoBanco(String listaId) async {
    final local = await (db.select(
      db.listaLocal,
    )..where((l) => l.id.equals(listaId))).getSingle();
    return local.orcamentoCentavos;
  }

  testWidgets('deve_definir_orcamento_quando_dono_salvar', (tester) async {
    final listaId = await abrirLista(tester);

    await abrirDialogoOrcamento(tester);
    expect(find.text(AppStrings.campoOrcamento), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.campoOrcamento),
      '150,00',
    );
    await tester.tap(find.widgetWithText(FilledButton, AppStrings.salvar));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.orcamentoDefinido), findsOneWidget);
    expect(await orcamentoNoBanco(listaId), 15000);

    final mutacoes = await (db.select(db.mutacaoPendente)).get();
    final payload = mutacoes
        .where((m) => m.tabela == 'listas' && m.operacao == 'UPDATE')
        .map((m) => m.payload)
        .last;
    expect(payload, contains('"orcamento_centavos":15000'));

    await fechar(tester);
  });

  testWidgets('deve_remover_orcamento_quando_dono_tocar_remover', (
    tester,
  ) async {
    final listaId = await abrirLista(tester, orcamentoCentavos: 3000);

    await abrirDialogoOrcamento(tester);
    // Campo pré-preenchido com o orçamento atual (formatarReais).
    expect(find.text('R\$ 30,00'), findsOneWidget);

    await tester.tap(
      find.widgetWithText(TextButton, AppStrings.removerOrcamento),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.orcamentoRemovido), findsOneWidget);
    expect(await orcamentoNoBanco(listaId), isNull);

    await fechar(tester);
  });

  testWidgets('deve_esconder_orcamento_quando_leitor', (tester) async {
    await abrirLista(tester, papel: Papel.leitor);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.orcamento), findsNothing);
    expect(find.text(AppStrings.membros), findsOneWidget);

    await fechar(tester);
  });

  testWidgets('deve_mostrar_erro_inline_quando_valor_invalido', (tester) async {
    final listaId = await abrirLista(tester);

    await abrirDialogoOrcamento(tester);
    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.campoOrcamento),
      'abc',
    );
    await tester.tap(find.widgetWithText(FilledButton, AppStrings.salvar));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.erroOrcamentoInvalido), findsOneWidget);
    // Diálogo permanece aberto e nada foi persistido.
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text(AppStrings.orcamentoDefinido), findsNothing);
    expect(await orcamentoNoBanco(listaId), isNull);

    await fechar(tester);
  });
}
