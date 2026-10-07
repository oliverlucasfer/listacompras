import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/dominio/categoria.dart';
import 'package:lista_compras/core/dominio/unidade.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/historico/data/historico_compras_repository.dart';
import 'package:lista_compras/features/historico/ui/estatisticas_tab.dart';
import 'package:lista_compras/features/historico/ui/historico_screen.dart';
import 'package:lista_compras/features/listas/data/listas_repository.dart';
import 'package:lista_compras/features/listas/providers/listas_providers.dart';

import '../../support/app_teste.dart';

void main() {
  /// Desmonta a árvore dentro do teste: o dispose do StreamProvider cancela
  /// streams do Drift, que agendam um Timer(0) — o pump seguinte o consome,
  /// evitando "Timer is still pending" no teardown do binding.
  Future<void> fechar(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  Finder scrollEstatisticas() => find
      .descendant(
        of: find.byType(EstatisticasTab),
        matching: find.byType(Scrollable),
      )
      .first;

  testWidgets('deve_mostrar_gasto_por_mercado_quando_ha_idas', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final listas = ListasRepository(db);
    final historico = HistoricoComprasRepository(db);

    Future<void> finalizarIda(
      String titulo,
      String nome,
      int centavos,
      String? mercado,
    ) async {
      final l = await listas.criarLista(titulo: titulo, donoId: 'local');
      final i = await listas.itens.adicionarItem(
        listaId: l.id,
        nome: nome,
        quantidade: 1,
        unidade: Unidade.kg,
        categoria: CategoriaItem.mercearia,
        precoCentavos: centavos,
      );
      await listas.itens.editarItem(i.id, concluido: true);
      await historico.finalizar(l.id, mercado: mercado);
    }

    await finalizarIda('Com mercado', 'Arroz', 500, 'Mercado A');
    await finalizarIda('Sem mercado', 'Leite', 300, null);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: appTeste(const HistoricoScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Estatísticas'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Gasto por mercado'),
      200,
      scrollable: scrollEstatisticas(),
    );
    await tester.pumpAndSettle();

    expect(find.text('Gasto por mercado'), findsOneWidget);

    final tileMercadoA = find.ancestor(
      of: find.text('Mercado A'),
      matching: find.byType(ListTile),
    );
    expect(tileMercadoA, findsOneWidget, reason: 'mercado agrupado');
    expect(
      find.descendant(of: tileMercadoA, matching: find.text(r'R$ 5,00')),
      findsOneWidget,
      reason: 'gasto de R\$ 5,00 associado a Mercado A',
    );

    final tileSemMercado = find.ancestor(
      of: find.text('Sem mercado'),
      matching: find.byType(ListTile),
    );
    expect(tileSemMercado, findsOneWidget, reason: 'grupo sem mercado');
    expect(
      find.descendant(of: tileSemMercado, matching: find.text(r'R$ 3,00')),
      findsOneWidget,
      reason: 'gasto de R\$ 3,00 associado ao grupo sem mercado',
    );

    await fechar(tester);
  });
}
