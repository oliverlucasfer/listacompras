import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/l10n/app_strings.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/historico/data/historico_compras_repository.dart';
import 'package:lista_compras/features/historico/ui/modal_finalizar_compra.dart';
import 'package:lista_compras/features/listas/data/listas_repository.dart';
import 'package:lista_compras/features/listas/providers/listas_providers.dart';

import '../../support/app_teste.dart';

void main() {
  /// Cria uma lista com 1 item concluído e monta um botão que abre o modal.
  /// O `ref.watch` imita a tela real (botão de rodapé): sem ele o stream do
  /// Drift não emite sob o pump do teste. `mercadoAnterior` semeia uma ida
  /// finalizada para alimentar as sugestões do campo.
  Future<({AppDatabase db, String listaId})> subir(
    WidgetTester tester, {
    String? mercadoAnterior,
  }) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final listas = ListasRepository(db);
    if (mercadoAnterior != null) {
      final anterior = await listas.criarLista(
        titulo: 'Antiga',
        donoId: 'local',
      );
      final i = await listas.adicionarItem(listaId: anterior.id, nome: 'Leite');
      await listas.editarItem(i.id, concluido: true);
      await HistoricoComprasRepository(
        db,
      ).finalizar(anterior.id, mercado: mercadoAnterior);
    }
    final l = await listas.criarLista(titulo: 'Semana', donoId: 'local');
    final item = await listas.adicionarItem(listaId: l.id, nome: 'Arroz');
    await listas.editarItem(item.id, concluido: true);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: appTeste(
          Builder(
            builder: (context) => Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  ref.watch(itensDaListaProvider(l.id));
                  return TextButton(
                    onPressed: () => abrirFinalizarCompra(context, ref, l.id),
                    child: const Text('abrir'),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    return (db: db, listaId: l.id);
  }

  /// Desmonta para cancelar o timer do snackbar (padrão dos testes da tela).
  Future<void> fechar(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('deve_registrar_mercado_quando_informado_ao_finalizar', (
    tester,
  ) async {
    final r = await subir(tester);

    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.mercadoOpcional),
      'Mercado A',
    );
    await tester.tap(find.text(AppStrings.finalizarCompra));
    await tester.pumpAndSettle();

    // Dialogo pos-finalizar: manter a lista.
    await tester.tap(find.text(AppStrings.finalizarManter));
    await tester.pumpAndSettle();

    final idas = await r.db.select(r.db.idaCompra).get();
    expect(idas, hasLength(1));
    expect(idas.single.mercado, 'Mercado A');
    expect((await r.db.select(r.db.itemIda).get()), hasLength(1));

    await fechar(tester);
  });

  testWidgets('deve_gravar_sem_mercado_quando_campo_vazio', (tester) async {
    final r = await subir(tester);

    await tester.tap(find.text(AppStrings.finalizarCompra));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.finalizarManter));
    await tester.pumpAndSettle();

    final idas = await r.db.select(r.db.idaCompra).get();
    expect(idas.single.mercado, isNull);

    await fechar(tester);
  });

  testWidgets('deve_preencher_campo_quando_tocar_em_mercado_sugerido', (
    tester,
  ) async {
    await subir(tester, mercadoAnterior: 'Mercado A');

    expect(find.widgetWithText(ActionChip, 'Mercado A'), findsOneWidget);
    await tester.tap(find.widgetWithText(ActionChip, 'Mercado A'));
    await tester.pumpAndSettle();

    final campo = tester.widget<TextField>(
      find.widgetWithText(TextField, AppStrings.mercadoOpcional),
    );
    expect(campo.controller!.text, 'Mercado A');

    await fechar(tester);
  });
}
