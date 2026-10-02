import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/listas/data/listas_repository.dart';
import 'package:lista_compras/features/listas/domain/preco.dart';
import 'package:lista_compras/features/listas/providers/listas_providers.dart';
import 'package:lista_compras/features/listas/ui/total_carrinho.dart';

import '../../support/app_teste.dart';

/// Estados progressivos do total do carrinho (RF-36, F53-T02).
void main() {
  late AppDatabase db;
  late ListasRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ListasRepository(db);
  });

  tearDown(() async => db.close());

  /// Cria uma lista com um item marcado por preço (centavos), define o
  /// orçamento e abre o `TotalCarrinho`.
  Future<String> abrir(
    WidgetTester tester, {
    required int precoCentavos,
    required int orcamentoCentavos,
  }) async {
    final lista = await repo.criarLista(titulo: 'Compras', donoId: 'user-a');
    final item = await repo.adicionarItem(
      listaId: lista.id,
      nome: 'Item',
      precoCentavos: precoCentavos,
    );
    await repo.editarItem(item.id, concluido: true);
    await repo.definirOrcamento(lista.id, centavos: orcamentoCentavos);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: appTeste(Scaffold(body: TotalCarrinho(listaId: lista.id))),
      ),
    );
    await tester.pumpAndSettle();
    return lista.id;
  }

  Future<void> fechar(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('deve_ficar_normal_quando_bem_abaixo_do_orcamento', (
    tester,
  ) async {
    await abrir(tester, precoCentavos: 500, orcamentoCentavos: 1000);

    expect(
      find.text('No carrinho: ${formatarReais(500)} de ${formatarReais(1000)}'),
      findsOneWidget,
    );
    expect(find.text('Perto do orçamento'), findsNothing);
    expect(find.byIcon(Icons.notification_important_outlined), findsNothing);
    expect(find.text('Acima do orçamento'), findsNothing);
    expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    await fechar(tester);
  });

  testWidgets('deve_avisar_quando_proximo_do_orcamento', (tester) async {
    await abrir(tester, precoCentavos: 800, orcamentoCentavos: 1000);

    expect(find.text('Perto do orçamento'), findsOneWidget);
    expect(find.byIcon(Icons.notification_important_outlined), findsOneWidget);
    expect(find.text('Acima do orçamento'), findsNothing);
    expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
    await fechar(tester);
  });

  testWidgets('deve_alertar_quando_acima_do_orcamento', (tester) async {
    await abrir(tester, precoCentavos: 1001, orcamentoCentavos: 1000);

    expect(find.text('Acima do orçamento'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    expect(find.text('Perto do orçamento'), findsNothing);
    expect(find.byIcon(Icons.notification_important_outlined), findsNothing);
    await fechar(tester);
  });
}
