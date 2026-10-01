import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/l10n/app_strings.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/listas/data/listas_repository.dart';
import 'package:lista_compras/features/listas/domain/preco.dart';
import 'package:lista_compras/features/listas/providers/listas_providers.dart';
import 'package:lista_compras/features/listas/ui/mercado_screen.dart';
import 'package:lista_compras/features/listas/ui/tela_lista_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Aviso (SnackBar) ao cruzar o orçamento ao marcar/desmarcar (RF-36, F53-T03).
void main() {
  late AppDatabase db;
  late ListasRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ListasRepository(db);
    SharedPreferences.setMockInitialValues({'onboarding_visto': true});
  });

  tearDown(() async => db.close());

  /// Cria a lista com um item por preço (centavos), define o orçamento e abre
  /// a tela pedida; devolve o id da lista.
  Future<String> abrirComItens(
    WidgetTester tester, {
    required List<int> precos,
    required int orcamentoCentavos,
    required Widget Function(String listaId) tela,
  }) async {
    final lista = await repo.criarLista(titulo: 'Compras', donoId: 'local');
    for (var i = 0; i < precos.length; i++) {
      await repo.adicionarItem(
        listaId: lista.id,
        nome: 'Item ${i + 1}',
        precoCentavos: precos[i],
      );
    }
    await repo.definirOrcamento(lista.id, centavos: orcamentoCentavos);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(home: tela(lista.id)),
      ),
    );
    await tester.pumpAndSettle();
    return lista.id;
  }

  Future<void> fechar(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('deve_avisar_quando_marcar_cruza_o_orcamento', (tester) async {
    await abrirComItens(
      tester,
      precos: [600, 600],
      orcamentoCentavos: 1000,
      tela: (id) => TelaListaScreen(listaId: id),
    );

    // 1º item: R$ 6,00 de R$ 10,00 — ainda não cruzou.
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(
      find.text(AppStrings.orcamentoCruzado(formatarReais(1200))),
      findsNothing,
    );

    // 2º item: total R$ 12,00 — cruzou o orçamento.
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(
      find.text(AppStrings.orcamentoCruzado(formatarReais(1200))),
      findsOneWidget,
    );

    await fechar(tester);
  });

  testWidgets('deve_nao_reavisar_quando_ja_acima_do_orcamento', (tester) async {
    await abrirComItens(
      tester,
      precos: [600, 600, 600],
      orcamentoCentavos: 1000,
      tela: (id) => TelaListaScreen(listaId: id),
    );

    // Cruza o orçamento no 2º item (R$ 12,00).
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(
      find.text(AppStrings.orcamentoCruzado(formatarReais(1200))),
      findsOneWidget,
    );

    // Descarta o aviso atual e marca o 3º item (já acima): não re-dispara.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(
      find.text(AppStrings.orcamentoCruzado(formatarReais(1800))),
      findsNothing,
    );

    await fechar(tester);
  });

  testWidgets('deve_avisar_no_mercado_quando_marcar_cruza_o_orcamento', (
    tester,
  ) async {
    await abrirComItens(
      tester,
      precos: [600, 600],
      orcamentoCentavos: 1000,
      tela: (id) => MercadoScreen(listaId: id),
    );

    await tester.tap(find.text('Item 1'));
    await tester.pumpAndSettle();
    expect(
      find.text(AppStrings.orcamentoCruzado(formatarReais(1200))),
      findsNothing,
    );

    await tester.tap(find.text('Item 2'));
    await tester.pumpAndSettle();
    expect(
      find.text(AppStrings.orcamentoCruzado(formatarReais(1200))),
      findsOneWidget,
    );

    await fechar(tester);
  });
}
