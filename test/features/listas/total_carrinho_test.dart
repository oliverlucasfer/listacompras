import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/l10n/app_strings.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/listas/data/listas_repository.dart';
import 'package:lista_compras/features/listas/domain/preco.dart';
import 'package:lista_compras/features/listas/providers/listas_providers.dart';
import 'package:lista_compras/features/listas/ui/total_carrinho.dart';

/// Faixa do total do carrinho com orçamento (RF-28, F36-T04, doc 05 §6.3/§6.5).
void main() {
  late AppDatabase db;
  late ListasRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ListasRepository(db);
  });

  tearDown(() async => db.close());

  /// Cria uma lista com um item marcado por preço informado (null = sem preço),
  /// opcionalmente com orçamento, e abre o `TotalCarrinho`.
  Future<String> abrir(
    WidgetTester tester, {
    required List<int?> precos,
    bool marcar = true,
    int? orcamentoCentavos,
  }) async {
    final lista = await repo.criarLista(titulo: 'Compras', donoId: 'user-a');
    for (var i = 0; i < precos.length; i++) {
      final item = await repo.adicionarItem(
        listaId: lista.id,
        nome: 'Item $i',
        precoCentavos: precos[i],
      );
      if (marcar) await repo.editarItem(item.id, concluido: true);
    }
    if (orcamentoCentavos != null) {
      await repo.definirOrcamento(lista.id, centavos: orcamentoCentavos);
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: Scaffold(body: TotalCarrinho(listaId: lista.id)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return lista.id;
  }

  Future<void> fechar(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('deve_ocultar_quando_nada_marcado', (tester) async {
    await abrir(tester, precos: const [549, null, 1000], marcar: false);
    expect(find.textContaining('No carrinho:'), findsNothing);
    await fechar(tester);
  });

  testWidgets('deve_mostrar_total_simples_quando_sem_orcamento', (
    tester,
  ) async {
    await abrir(tester, precos: const [549]);
    expect(
      find.text(AppStrings.totalNoCarrinho(formatarReais(549), 0)),
      findsOneWidget,
    );
    expect(find.byType(LinearProgressIndicator), findsNothing);
    await fechar(tester);
  });

  testWidgets('deve_mostrar_progresso_quando_orcamento_maior_que_total', (
    tester,
  ) async {
    await abrir(tester, precos: const [549], orcamentoCentavos: 1000);

    expect(
      find.text(
        AppStrings.totalComOrcamento(
          formatarReais(549),
          formatarReais(1000),
          0,
        ),
      ),
      findsOneWidget,
    );
    final barra = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(barra.value, closeTo(0.549, 0.001));
    expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    expect(find.text(AppStrings.acimaDoOrcamento), findsNothing);
    await fechar(tester);
  });

  testWidgets('deve_alertar_quando_total_ultrapassa_orcamento', (tester) async {
    await abrir(tester, precos: const [549], orcamentoCentavos: 300);

    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    expect(find.text(AppStrings.acimaDoOrcamento), findsOneWidget);
    final barra = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(barra.value, 1.0);
    await fechar(tester);
  });

  testWidgets('deve_alertar_quando_orcamento_zero_e_total_positivo', (
    tester,
  ) async {
    await abrir(tester, precos: const [549], orcamentoCentavos: 0);

    expect(find.text(AppStrings.acimaDoOrcamento), findsOneWidget);
    // Orçamento zero não tem barra de progresso.
    expect(find.byType(LinearProgressIndicator), findsNothing);
    await fechar(tester);
  });

  testWidgets('deve_contar_sem_preco_quando_com_orcamento', (tester) async {
    await abrir(tester, precos: const [549, null], orcamentoCentavos: 1000);

    expect(
      find.text(
        AppStrings.totalComOrcamento(
          formatarReais(549),
          formatarReais(1000),
          1,
        ),
      ),
      findsOneWidget,
    );
    await fechar(tester);
  });
}
