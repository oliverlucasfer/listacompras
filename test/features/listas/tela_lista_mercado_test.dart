import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/historico/data/historico_compras_repository.dart';
import 'package:lista_compras/features/listas/data/listas_repository.dart';
import 'package:lista_compras/features/listas/domain/preco.dart';
import 'package:lista_compras/features/listas/providers/listas_providers.dart';
import 'package:lista_compras/features/listas/ui/tela_lista_screen.dart';

import '../../support/app_teste.dart';

void main() {
  late AppDatabase db;
  late ListasRepository listas;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    listas = ListasRepository(db);
  });

  tearDown(() => db.close());

  Future<void> fechar(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  /// Finaliza a lista (com 1 item concluído) com o mercado informado e monta a
  /// tela da lista para checar o chip do topo.
  Future<void> listaFinalizada(WidgetTester tester, {String? mercado}) async {
    final lista = await listas.criarLista(titulo: 'Compras', donoId: 'local');
    final item = await listas.adicionarItem(
      listaId: lista.id,
      nome: 'Arroz',
      precoCentavos: 549,
    );
    await listas.editarItem(item.id, concluido: true);
    await HistoricoComprasRepository(db).finalizar(lista.id, mercado: mercado);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: appTeste(TelaListaScreen(listaId: lista.id)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('deve_mostrar_chip_do_mercado_quando_ultima_ida_tem_mercado', (
    tester,
  ) async {
    await listaFinalizada(tester, mercado: 'Mercado A');

    expect(find.widgetWithText(Chip, 'Mercado A'), findsOneWidget);

    await fechar(tester);
  });

  testWidgets('nao_deve_mostrar_chip_quando_ultima_ida_sem_mercado', (
    tester,
  ) async {
    await listaFinalizada(tester);

    expect(find.byType(Chip), findsNothing);

    await fechar(tester);
  });

  testWidgets('deve_mostrar_por_mercado_no_editor_quando_ha_historico', (
    tester,
  ) async {
    Future<void> idaEm(String mercado, int preco) async {
      final l = await listas.criarLista(titulo: 'Antiga', donoId: 'local');
      final i = await listas.adicionarItem(
        listaId: l.id,
        nome: 'Arroz',
        precoCentavos: preco,
      );
      await listas.editarItem(i.id, concluido: true);
      await HistoricoComprasRepository(db).finalizar(l.id, mercado: mercado);
    }

    await idaEm('Mercado A', 700);
    await idaEm('Mercado B', 500);

    final lista = await listas.criarLista(titulo: 'Compras', donoId: 'local');
    await listas.adicionarItem(listaId: lista.id, nome: 'Arroz');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: appTeste(TelaListaScreen(listaId: lista.id)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Arroz'));
    await tester.pumpAndSettle();

    expect(find.text('Por mercado'), findsOneWidget);
    expect(find.text('Mercado A: ${formatarReais(700)}'), findsOneWidget);
    // O mais barato (Mercado B) aparece com o destaque.
    expect(
      find.text('Mercado B: ${formatarReais(500)} (mais barato)'),
      findsOneWidget,
    );

    await fechar(tester);
  });
}
