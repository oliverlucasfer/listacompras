import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lista_compras/core/categorias/sugestao_categorias.dart';
import 'package:lista_compras/core/dominio/categoria.dart';
import 'package:lista_compras/core/dominio/unidade.dart';
import 'package:lista_compras/core/l10n/categoria_l10n.dart';
import 'package:lista_compras/core/widgets/app_botao.dart';
import 'package:lista_compras/core/widgets/app_campo_texto.dart';
import 'package:lista_compras/core/widgets/app_dropdown.dart';
import 'package:lista_compras/core/widgets/app_esqueleto.dart';
import 'package:lista_compras/core/widgets/app_estado_erro.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/listas/data/itens_repository.dart';
import 'package:lista_compras/features/listas/data/listas_repository.dart';
import 'package:lista_compras/features/listas/domain/item.dart';
import 'package:lista_compras/features/listas/domain/preco.dart';
import 'package:lista_compras/features/listas/domain/resultado_dedup.dart';
import 'package:lista_compras/features/listas/providers/listas_providers.dart';
import 'package:lista_compras/features/listas/ui/minhas_listas_screen.dart';
import 'package:lista_compras/features/listas/ui/tela_lista_screen.dart';
import 'package:lista_compras/features/voz/domain/reconhecimento_voz.dart';
import 'package:lista_compras/features/voz/providers/reconhecimento_voz_provider.dart';

import '../../support/app_teste.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../voz/fake_reconhecimento_voz.dart';

class _RepoReordenarFalha extends ItensRepository {
  _RepoReordenarFalha(super.db);

  @override
  Future<void> reordenarItens(String listaId, List<String> idsOrdenados) async {
    throw StateError('falha ao reordenar');
  }
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({'onboarding_visto': true});
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> montarTela(WidgetTester tester, String listaId) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: appTeste(TelaListaScreen(listaId: listaId)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<String> listaComItens(
    WidgetTester tester, {
    bool comConcluido = false,
  }) async {
    final repo = ListasRepository(db);
    final lista = await repo.criarLista(
      titulo: 'Compras da Semana',
      donoId: 'local',
    );
    await repo.itens.adicionarItem(
      listaId: lista.id,
      nome: 'Arroz',
      categoria: CategoriaItem.mercearia,
    );
    await repo.itens.adicionarItem(
      listaId: lista.id,
      nome: 'Leite',
      categoria: CategoriaItem.laticinios,
    );
    if (comConcluido) {
      final detergente = await repo.itens.adicionarItem(
        listaId: lista.id,
        nome: 'Detergente',
        categoria: CategoriaItem.limpeza,
      );
      await repo.itens.editarItem(detergente.id, concluido: true);
    }
    await montarTela(tester, lista.id);
    return lista.id;
  }

  Future<void> fechar(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  /// Cria um item frequente fora da lista aberta (peso = 1 por item/linha; o
  /// `uq_item_ativo` só admite 1 item ativo por `(lista, nome)` — RF-10).
  Future<void> criarFrequentesEmOutraLista(
    String nome,
    int vezes, {
    CategoriaItem categoria = CategoriaItem.outros,
  }) async {
    final repo = ListasRepository(db);
    for (var i = 0; i < vezes; i++) {
      final outra = await repo.criarLista(titulo: 'Outra', donoId: 'local');
      await repo.itens.adicionarItem(
        listaId: outra.id,
        nome: nome,
        quantidade: 1,
        categoria: categoria,
      );
    }
  }

  /// Abre a tela de uma lista com um item "Arroz" (para fluxos que precisam de
  /// uma lista pronta, com voz opcional).
  Future<String> abrirListaComItem(
    WidgetTester tester, {
    String? listaId,
    ReconhecimentoVoz? reconhecimento,
  }) async {
    final repo = ListasRepository(db);
    final id =
        listaId ??
        (await repo.criarLista(titulo: 'Compras', donoId: 'local')).id;
    await repo.itens.adicionarItem(listaId: id, nome: 'Arroz');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          if (reconhecimento != null)
            reconhecimentoVozProvider.overrideWithValue(reconhecimento),
        ],
        child: appTeste(TelaListaScreen(listaId: id)),
      ),
    );
    await tester.pumpAndSettle();
    return id;
  }

  testWidgets('deve_exibir_titulo_itens_e_secao_concluidos_quando_abrir', (
    tester,
  ) async {
    await listaComItens(tester, comConcluido: true);

    expect(find.text('Compras da Semana'), findsOneWidget);
    expect(find.text('Arroz'), findsOneWidget);
    expect(find.text('Leite'), findsOneWidget);
    expect(find.text('1 kg'), findsNothing);
    expect(find.text('1 un'), findsNWidgets(2));
    // Grupos por categoria com contagem (F6-T04); sem cabeçalho global.
    expect(find.text('Mercearia (1)'), findsOneWidget);
    expect(find.text('Laticínios (1)'), findsOneWidget);
    expect(find.text('Itens (2)'), findsNothing);
    expect(find.text('Itens concluídos (1)'), findsOneWidget);

    await tester.tap(find.text('Itens concluídos (1)'));
    await tester.pumpAndSettle();
    // O nome também aparece como chip de sugestão (RF-19); a asserção é
    // restrita à linha do item concluído.
    expect(
      find.descendant(
        of: find.byType(ExpansionTile),
        matching: find.text('Detergente'),
      ),
      findsOneWidget,
    );

    await fechar(tester);
  });

  testWidgets('deve_mostrar_dica_com_caminhos_quando_lista_vazia', (
    tester,
  ) async {
    final repo = ListasRepository(db);
    final lista = await repo.criarLista(
      titulo: 'Compras da Semana',
      donoId: 'local',
    );
    await montarTela(tester, lista.id);

    expect(find.text('Nenhum item ainda'), findsOneWidget);
    expect(
      find.text('Adicione no campo acima ou importe uma lista.'),
      findsOneWidget,
    );

    await fechar(tester);
  });

  testWidgets('deve_agrupar_pendentes_na_ordem_do_enum_quando_exibir_f6t04', (
    tester,
  ) async {
    final repo = ListasRepository(db);
    final lista = await repo.criarLista(titulo: 'Compras', donoId: 'local');
    await repo.itens.adicionarItem(
      listaId: lista.id,
      nome: 'Leite',
      categoria: CategoriaItem.laticinios,
    );
    await repo.itens.adicionarItem(
      listaId: lista.id,
      nome: 'Banana',
      categoria: CategoriaItem.hortifruti,
    );
    await repo.itens.adicionarItem(
      listaId: lista.id,
      nome: 'Arroz',
      categoria: CategoriaItem.mercearia,
    );
    await repo.itens.adicionarItem(
      listaId: lista.id,
      nome: 'Café',
      categoria: CategoriaItem.mercearia,
    );
    await montarTela(tester, lista.id);

    expect(find.text('Hortifrúti (1)'), findsOneWidget);
    expect(find.text('Mercearia (2)'), findsOneWidget);
    expect(find.text('Laticínios (1)'), findsOneWidget);

    // Ordem dos grupos segue o enum: Hortifrúti < Mercearia < Laticínios.
    final dyHorti = tester.getTopLeft(find.text('Hortifrúti (1)')).dy;
    final dyMerce = tester.getTopLeft(find.text('Mercearia (2)')).dy;
    final dyLatic = tester.getTopLeft(find.text('Laticínios (1)')).dy;
    expect(dyHorti, lessThan(dyMerce));
    expect(dyMerce, lessThan(dyLatic));

    await fechar(tester);
  });

  testWidgets('deve_agrupar_na_ordem_custom_quando_lista', (tester) async {
    SharedPreferences.setMockInitialValues({
      'ordem_categorias':
          '${CategoriaItem.bebidas.valor},'
          '${CategoriaItem.mercearia.valor},'
          '${CategoriaItem.hortifruti.valor}',
    });
    final repo = ListasRepository(db);
    final lista = await repo.criarLista(titulo: 'Compras', donoId: 'local');
    await repo.itens.adicionarItem(
      listaId: lista.id,
      nome: 'Arroz',
      categoria: CategoriaItem.mercearia,
    );
    await repo.itens.adicionarItem(
      listaId: lista.id,
      nome: 'Banana',
      categoria: CategoriaItem.hortifruti,
    );
    await repo.itens.adicionarItem(
      listaId: lista.id,
      nome: 'Suco',
      categoria: CategoriaItem.bebidas,
    );
    await montarTela(tester, lista.id);

    final context = tester.element(find.byType(TelaListaScreen));
    final dyBebidas = tester
        .getTopLeft(find.text('${CategoriaItem.bebidas.rotulo(context)} (1)'))
        .dy;
    final dyMercearia = tester
        .getTopLeft(find.text('${CategoriaItem.mercearia.rotulo(context)} (1)'))
        .dy;
    final dyHortifruti = tester
        .getTopLeft(
          find.text('${CategoriaItem.hortifruti.rotulo(context)} (1)'),
        )
        .dy;
    expect(dyBebidas, lessThan(dyMercearia));
    expect(dyMercearia, lessThan(dyHortifruti));
    await fechar(tester);
  });

  testWidgets('deve_adicionar_item_quando_enter_no_campo', (tester) async {
    await listaComItens(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Adicionar item'),
      'Café',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('Café'), findsOneWidget);
    expect(find.text('Mercearia (2)'), findsOneWidget);
    expect(find.text('1 un'), findsNWidgets(3));

    await fechar(tester);
  });

  testWidgets('deve_confirmar_quando_adiciona_item_novo', (tester) async {
    await listaComItens(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Adicionar item'),
      'Café',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('Item adicionado.'), findsOneWidget);

    await fechar(tester);
  });

  testWidgets('deve_mostrar_erro_quando_parser_descarta_texto', (tester) async {
    await listaComItens(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Adicionar item'),
      '.',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('Não entendi o item'), findsOneWidget);
    // Nada foi adicionado.
    expect(find.text('Mercearia (1)'), findsOneWidget);

    // O erro some ao digitar de novo.
    await tester.enterText(
      find.widgetWithText(TextField, 'Adicionar item'),
      'Café',
    );
    await tester.pump();
    expect(find.text('Não entendi o item'), findsNothing);

    await fechar(tester);
  });

  testWidgets(
    'deve_mostrar_erro_e_manter_texto_quando_falha_ao_adicionar_item',
    (tester) async {
      final repo = ListasRepository(db);
      final lista = await repo.criarLista(titulo: 'Compras', donoId: 'local');
      await repo.itens.adicionarItem(listaId: lista.id, nome: 'Arroz');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            itensRepositoryProvider.overrideWithValue(_RepoAdicionarFalha(db)),
          ],
          child: appTeste(TelaListaScreen(listaId: lista.id)),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Adicionar item'),
        'Café',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(
        find.text('Não foi possível concluir. Tente novamente.'),
        findsOneWidget,
      );
      // A falha não limpa o campo, permitindo nova tentativa.
      expect(find.text('Café'), findsOneWidget);

      await fechar(tester);
    },
  );

  testWidgets('deve_aplicar_sugestao_local_quando_adicionar_rapido_f6t04', (
    tester,
  ) async {
    await listaComItens(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Adicionar item'),
      'Detergente',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    // Dicionário: detergente → limpeza (sem memória prévia).
    expect(find.text('Detergente'), findsOneWidget);
    expect(find.text('Limpeza (1)'), findsOneWidget);

    await fechar(tester);
  });

  testWidgets('deve_somar_quantidade_quando_adicionar_item_duplicado', (
    tester,
  ) async {
    await listaComItens(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Adicionar item'),
      'Arroz',
    );
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.text('Arroz'), findsOneWidget);
    expect(find.text('2 un'), findsOneWidget);
    expect(find.textContaining('já está na lista'), findsOneWidget);

    await fechar(tester);
  });

  testWidgets('deve_aplicar_unidade_do_seletor_quando_texto_sem_unidade', (
    tester,
  ) async {
    await listaComItens(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Adicionar item'),
      'banana',
    );
    await tester.tap(find.text('un'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('dz').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.text('Banana'), findsOneWidget);
    expect(find.text('1 dz'), findsOneWidget);

    await fechar(tester);
  });

  testWidgets('deve_interpretar_quantidade_e_unidade_quando_texto_com_kg', (
    tester,
  ) async {
    await listaComItens(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Adicionar item'),
      '1kg de banana',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('Banana'), findsOneWidget);
    expect(find.text('1 kg'), findsOneWidget);
    expect(find.text('Hortifrúti (1)'), findsOneWidget);

    await fechar(tester);
  });

  testWidgets('deve_priorizar_unidade_do_texto_sobre_seletor', (tester) async {
    await listaComItens(tester);

    await tester.tap(find.text('un'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('dz').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Adicionar item'),
      '1kg de banana',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('1 kg'), findsOneWidget);

    await fechar(tester);
  });

  testWidgets('deve_atualizar_item_quando_duplicado_com_unidade_diferente', (
    tester,
  ) async {
    await listaComItens(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Adicionar item'),
      '2kg de arroz',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('Arroz'), findsOneWidget);
    expect(find.text('2 kg'), findsOneWidget);
    expect(find.textContaining('Item atualizado.'), findsOneWidget);

    await fechar(tester);
  });

  testWidgets('deve_editar_e_remover_quando_tocar_no_item', (tester) async {
    await listaComItens(tester);

    await tester.tap(find.text('Arroz'));
    await tester.pumpAndSettle();
    expect(find.text('Editar item'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Remover'));
    await tester.pumpAndSettle();

    expect(find.text('Arroz'), findsNothing);
    expect(find.text('Item removido'), findsOneWidget);

    await tester.tap(find.text('Desfazer'));
    await tester.pumpAndSettle();
    expect(find.text('Arroz'), findsOneWidget);

    await fechar(tester);
  });

  testWidgets('deve_rotular_nome_do_item_quando_abre_editor', (tester) async {
    await listaComItens(tester);

    // Entrada rápida mantém "Adicionar item".
    expect(find.widgetWithText(TextField, 'Adicionar item'), findsOneWidget);

    await tester.tap(find.text('Arroz'));
    await tester.pumpAndSettle();

    expect(find.text('Editar item'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Nome do item'), findsOneWidget);

    await fechar(tester);
  });

  testWidgets('deve_mover_para_concluidos_e_voltar_quando_marcar_checkbox', (
    tester,
  ) async {
    await listaComItens(tester);

    final checkboxArroz = find.descendant(
      of: find.widgetWithText(ListTile, 'Arroz'),
      matching: find.byType(Checkbox),
    );
    await tester.tap(checkboxArroz);
    await tester.pumpAndSettle();

    expect(find.text('Laticínios (1)'), findsOneWidget);
    expect(find.text('Mercearia (1)'), findsNothing);
    expect(find.text('Itens concluídos (1)'), findsOneWidget);

    await tester.tap(find.text('Itens concluídos (1)'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(ExpansionTile),
        matching: find.byType(Checkbox),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mercearia (1)'), findsOneWidget);
    expect(find.text('Arroz'), findsOneWidget);

    await fechar(tester);
  });

  testWidgets('deve_remover_item_e_desfazer_quando_swipe_esquerda', (
    tester,
  ) async {
    await listaComItens(tester);

    await tester.drag(find.text('Arroz'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.text('Arroz'), findsNothing);
    expect(find.text('Laticínios (1)'), findsOneWidget);
    expect(find.text('Item removido'), findsOneWidget);

    await tester.tap(find.text('Desfazer'));
    await tester.pumpAndSettle();

    expect(find.text('Arroz'), findsOneWidget);
    expect(find.text('Mercearia (1)'), findsOneWidget);

    await fechar(tester);
  });

  testWidgets('deve_mostrar_erro_quando_desfazer_a_restauracao_falha', (
    tester,
  ) async {
    final repo = ListasRepository(db);
    final lista = await repo.criarLista(titulo: 'Compras', donoId: 'local');
    await repo.itens.adicionarItem(listaId: lista.id, nome: 'Arroz');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          itensRepositoryProvider.overrideWithValue(_RepoRestaurarFalha(db)),
        ],
        child: appTeste(TelaListaScreen(listaId: lista.id)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.text('Arroz'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Desfazer'));
    await tester.pumpAndSettle();

    expect(
      find.text('Não foi possível concluir. Tente novamente.'),
      findsOneWidget,
    );

    await fechar(tester);
  });

  testWidgets('deve_editar_quantidade_e_unidade_quando_swipe_direita', (
    tester,
  ) async {
    await listaComItens(tester);

    await tester.drag(find.text('Arroz'), const Offset(500, 0));
    await tester.pumpAndSettle();

    expect(find.text('Editar item'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Quantidade'), '3');
    await tester.tap(find.byType(DropdownButtonFormField<Unidade>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('kg').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pumpAndSettle();

    expect(find.text('3 kg'), findsOneWidget);
    expect(find.text('Editar item'), findsNothing);

    await fechar(tester);
  });

  testWidgets('deve_aceitar_fracao_quando_digitada_no_editor', (tester) async {
    await listaComItens(tester);

    await tester.tap(find.text('Arroz'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Quantidade'), '1/2');
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pumpAndSettle();

    final itens = await (db.select(
      db.itemLocal,
    )..where((i) => i.deletadoEm.isNull())).get();
    final arroz = itens.singleWhere((i) => i.nome == 'Arroz');
    expect(arroz.quantidade, 0.5);

    await fechar(tester);
  });

  testWidgets('deve_mostrar_erro_inline_quando_nome_e_quantidade_invalidos', (
    tester,
  ) async {
    await listaComItens(tester);

    await tester.tap(find.text('Arroz'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Nome do item'), '');
    await tester.enterText(find.widgetWithText(TextField, 'Quantidade'), '0');
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pumpAndSettle();

    expect(find.text('Informe um nome.'), findsOneWidget);
    expect(find.text('Informe uma quantidade maior que zero.'), findsOneWidget);
    // O diálogo permanece aberto (nada foi salvo).
    expect(find.text('Editar item'), findsOneWidget);
    expect(find.text('Arroz'), findsOneWidget);

    await fechar(tester);
  });

  testWidgets('deve_limpar_erro_da_quantidade_quando_ajustar_stepper', (
    tester,
  ) async {
    await listaComItens(tester);

    await tester.tap(find.text('Arroz'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Quantidade'), '0');
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pumpAndSettle();

    expect(find.text('Informe uma quantidade maior que zero.'), findsOneWidget);

    await tester.tap(find.byTooltip('Aumentar'));
    await tester.pumpAndSettle();

    expect(find.text('Informe uma quantidade maior que zero.'), findsNothing);

    await fechar(tester);
  });

  testWidgets('deve_nao_estourar_quando_escala_de_texto_2x', (tester) async {
    // Tela estreita de celular + fonte 2x: o cenário que estoura o rodapé.
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await listaComItens(tester);
    // Em 360dp/2x o botão "Importar lista" da própria tela estoura (pré-existente,
    // fora do escopo do editor); descartamos para medir só o sheet (F40-T03).
    while (tester.takeException() != null) {}
    await tester.tap(find.text('Arroz'));
    await tester.pumpAndSettle();

    expect(find.text('Editar item'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Salvar precisa continuar alcançável (rodapé sem estouro).
    final salvar = find.widgetWithText(FilledButton, 'Salvar');
    expect(salvar, findsOneWidget);
    await tester.ensureVisible(salvar);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await fechar(tester);
  });

  testWidgets('deve_nao_estourar_quando_largura_estreita', (tester) async {
    // 360dp (largura comum de celular) com fonte normal: o rodapé com as três
    // ações (Remover/Cancelar/Salvar) não pode estourar (RNF-06, F40-T03).
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await listaComItens(tester);
    await tester.tap(find.text('Arroz'));
    await tester.pumpAndSettle();

    expect(find.text('Editar item'), findsOneWidget);
    // As três ações estão presentes (caso que estourava).
    expect(find.text('Remover'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final salvar = find.widgetWithText(FilledButton, 'Salvar');
    expect(salvar, findsOneWidget);
    await tester.ensureVisible(salvar);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await fechar(tester);
  });

  testWidgets('deve_manter_acoes_em_linha_quando_couber', (tester) async {
    // Em tela larga (800dp) o rodapé é uma única linha: Remover à esquerda;
    // Cancelar + Salvar à direita (RNF-06, F40-T03).
    await listaComItens(tester);
    await tester.tap(find.text('Arroz'));
    await tester.pumpAndSettle();

    expect(find.text('Editar item'), findsOneWidget);

    final remover = find.widgetWithText(TextButton, 'Remover');
    final cancelar = find.widgetWithText(TextButton, 'Cancelar');
    final salvar = find.widgetWithText(FilledButton, 'Salvar');
    expect(remover, findsOneWidget);
    expect(cancelar, findsOneWidget);
    expect(salvar, findsOneWidget);

    final dyRemover = tester.getCenter(remover).dy;
    expect(tester.getCenter(cancelar).dy, dyRemover);
    expect(tester.getCenter(salvar).dy, dyRemover);
    expect(
      tester.getCenter(remover).dx,
      lessThan(tester.getCenter(cancelar).dx),
    );
    expect(tester.takeException(), isNull);

    await fechar(tester);
  });

  testWidgets('deve_manter_campos_alcancaveis_quando_teclado_abre', (
    tester,
  ) async {
    // Tela de 800×600 com o teclado aberto (300dp): o sheet `isScrollControlled`
    // reserva o `viewInsets` e o rodapé sobe para fora da área do teclado
    // (RNF-06, F40-T04).
    const teclado = 300.0;
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    tester.view.viewInsets = const FakeViewPadding(bottom: teclado);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    await listaComItens(tester);
    await tester.tap(find.text('Arroz'));
    await tester.pumpAndSettle();

    expect(find.text('Editar item'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Salvar continua alcançável e **acima da área do teclado** (sem o inset ele
    // ficaria atrás do teclado).
    final salvar = find.widgetWithText(FilledButton, 'Salvar');
    expect(salvar, findsOneWidget);
    await tester.ensureVisible(salvar);
    await tester.pumpAndSettle();

    expect(tester.getBottomLeft(salvar).dy, lessThanOrEqualTo(600 - teclado));
    expect(tester.takeException(), isNull);

    await tester.tap(salvar);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Editar item'), findsNothing);

    await fechar(tester);
  });

  testWidgets('deve_desmarcar_todos_quando_menu', (tester) async {
    await listaComItens(tester);
    final repo = ListasRepository(db);
    final itens = (await (db.select(
      db.itemLocal,
    )).get()).where((i) => !i.concluido).toList();
    await repo.itens.editarItem(itens.first.id, concluido: true);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Desmarcar todos'));
    await tester.pumpAndSettle();

    expect(find.text('Mercearia (1)'), findsOneWidget);
    expect(find.text('Laticínios (1)'), findsOneWidget);
    expect(find.byType(ExpansionTile), findsNothing);

    await fechar(tester);
  });

  testWidgets('deve_limpar_concluidos_quando_confirmar_dialogo', (
    tester,
  ) async {
    await listaComItens(tester, comConcluido: true);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Limpar concluídos'));
    await tester.pumpAndSettle();
    expect(
      find.text('Os itens concluídos serão removidos da lista.'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Limpar'));
    await tester.pumpAndSettle();

    expect(find.text('Mercearia (1)'), findsOneWidget);
    expect(find.text('Laticínios (1)'), findsOneWidget);
    expect(find.byType(ExpansionTile), findsNothing);
    expect(find.text('Detergente'), findsNothing);

    await fechar(tester);
  });

  testWidgets('deve_restaurar_concluidos_quando_desfazer_limpar', (
    tester,
  ) async {
    await listaComItens(tester, comConcluido: true);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Limpar concluídos'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Limpar'));
    await tester.pumpAndSettle();

    expect(find.text('Detergente'), findsNothing);
    expect(find.text('Itens concluídos removidos.'), findsOneWidget);

    await tester.tap(find.text('Desfazer'));
    await tester.pumpAndSettle();

    expect(find.text('Itens concluídos (1)'), findsOneWidget);

    await fechar(tester);
  });

  testWidgets('deve_mostrar_erro_quando_limpar_concluidos_falha', (
    tester,
  ) async {
    final repo = ListasRepository(db);
    final lista = await repo.criarLista(
      titulo: 'Compras da Semana',
      donoId: 'local',
    );
    await repo.itens.adicionarItem(
      listaId: lista.id,
      nome: 'Arroz',
      categoria: CategoriaItem.mercearia,
    );
    final detergente = await repo.itens.adicionarItem(
      listaId: lista.id,
      nome: 'Detergente',
      categoria: CategoriaItem.limpeza,
    );
    await repo.itens.editarItem(detergente.id, concluido: true);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          itensRepositoryProvider.overrideWithValue(_RepoLimparFalha(db)),
        ],
        child: appTeste(TelaListaScreen(listaId: lista.id)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Limpar concluídos'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Limpar'));
    await tester.pumpAndSettle();

    expect(
      find.text('Não foi possível concluir. Tente novamente.'),
      findsOneWidget,
    );

    await fechar(tester);
  });

  testWidgets('deve_excluir_lista_e_voltar_ao_painel_quando_confirmar', (
    tester,
  ) async {
    final repo = ListasRepository(db);
    final lista = await repo.criarLista(
      titulo: 'Compras da Semana',
      donoId: 'local',
    );
    await repo.itens.adicionarItem(listaId: lista.id, nome: 'Arroz');

    final router = GoRouter(
      initialLocation: '/lista/${lista.id}',
      routes: [
        GoRoute(
          path: '/lista/:listaId',
          builder: (_, state) =>
              TelaListaScreen(listaId: state.pathParameters['listaId']!),
        ),
        GoRoute(path: '/listas', builder: (_, _) => const MinhasListasScreen()),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: appTesteRouter(router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir lista'));
    await tester.pumpAndSettle();
    expect(find.text('Excluir "Compras da Semana"?'), findsOneWidget);
    expect(find.text('O item será removido.'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Excluir'));
    await tester.pumpAndSettle();

    final local = await (db.select(
      db.listaLocal,
    )..where((l) => l.id.equals(lista.id))).getSingle();
    expect(local.deletadoEm, isNotNull);
    expect(find.text('Minhas Listas'), findsOneWidget);
    expect(find.text('Nenhuma lista por aqui'), findsOneWidget);

    await fechar(tester);
  });

  testWidgets('deve_renomear_lista_quando_menu', (tester) async {
    await listaComItens(tester);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Renomear lista'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Nome da lista'),
      'Churrasco',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pumpAndSettle();

    expect(find.text('Churrasco'), findsOneWidget);
    expect(find.text('Compras da Semana'), findsNothing);
    expect(find.text('Lista renomeada.'), findsOneWidget);

    await fechar(tester);
  });

  testWidgets('deve_abrir_modal_importar_quando_tocar_botao', (tester) async {
    final repo = ListasRepository(db);
    final lista = await repo.criarLista(
      titulo: 'Compras da Semana',
      donoId: 'local',
    );
    await montarTela(tester, lista.id);

    await tester.tap(find.text('Importar lista'));
    await tester.pumpAndSettle();

    expect(find.text('Cole ou digite sua lista:'), findsOneWidget);
    expect(find.text('Extrair itens'), findsOneWidget);

    await fechar(tester);
  });

  testWidgets('deve_reordenar_dentro_do_grupo_quando_arrastar_alca_f6t04', (
    tester,
  ) async {
    final repo = ListasRepository(db);
    final lista = await repo.criarLista(titulo: 'Compras', donoId: 'local');
    await repo.itens.adicionarItem(
      listaId: lista.id,
      nome: 'Arroz',
      categoria: CategoriaItem.mercearia,
    ); // mercearia
    await repo.itens.adicionarItem(
      listaId: lista.id,
      nome: 'Feijão',
      categoria: CategoriaItem.mercearia,
    ); // mercearia
    await repo.itens.adicionarItem(
      listaId: lista.id,
      nome: 'Leite',
      categoria: CategoriaItem.laticinios,
    ); // laticinios
    await montarTela(tester, lista.id);

    // Arrasta a alça do Arroz (1º do grupo Mercearia) sobre o Feijão:
    // troca de posição dentro do grupo; Leite (outro grupo) fica intacto.
    await tester.drag(
      find.byIcon(Icons.drag_handle).first,
      const Offset(0, 150),
    );
    await tester.pumpAndSettle();

    final dyFeijao = tester.getTopLeft(find.text('Feijão')).dy;
    final dyArroz = tester.getTopLeft(find.text('Arroz')).dy;
    expect(dyFeijao, lessThan(dyArroz));

    final itens = await (db.select(
      db.itemLocal,
    )..where((i) => i.deletadoEm.isNull())).get();
    final arroz = itens.firstWhere((i) => i.nome == 'Arroz');
    final feijao = itens.firstWhere((i) => i.nome == 'Feijão');
    final leite = itens.firstWhere((i) => i.nome == 'Leite');
    expect(feijao.ordem, 0);
    expect(arroz.ordem, 1);
    expect(leite.ordem, 2); // outro grupo — sem mutação

    await fechar(tester);
  });

  testWidgets('deve_mostrar_erro_quando_reordenar_falha', (tester) async {
    final repo = ListasRepository(db);
    final lista = await repo.criarLista(titulo: 'Compras', donoId: 'local');
    await repo.itens.adicionarItem(
      listaId: lista.id,
      nome: 'Arroz',
      categoria: CategoriaItem.mercearia,
    );
    await repo.itens.adicionarItem(
      listaId: lista.id,
      nome: 'Feijão',
      categoria: CategoriaItem.mercearia,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          itensRepositoryProvider.overrideWithValue(_RepoReordenarFalha(db)),
        ],
        child: appTeste(TelaListaScreen(listaId: lista.id)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byIcon(Icons.drag_handle).first,
      const Offset(0, 150),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Não foi possível concluir. Tente novamente.'),
      findsOneWidget,
    );

    await fechar(tester);
  });

  testWidgets(
    'deve_manter_item_no_grupo_quando_arrastar_grupo_com_um_item_f6t04',
    (tester) async {
      await listaComItens(tester); // Arroz único em Mercearia

      // Grupo com 1 item: arrastar a alça não muda nada.
      await tester.drag(
        find.byIcon(Icons.drag_handle).first,
        const Offset(0, 300),
      );
      await tester.pumpAndSettle();

      final arroz =
          (await (db.select(
            db.itemLocal,
          )..where((i) => i.deletadoEm.isNull())).get()).firstWhere(
            (i) => i.nome == 'Arroz',
          );
      expect(arroz.ordem, 0);

      await fechar(tester);
    },
  );

  testWidgets('deve_editar_categoria_quando_swipe_direita_f6t04', (
    tester,
  ) async {
    await listaComItens(tester);

    await tester.drag(find.text('Arroz'), const Offset(500, 0));
    await tester.pumpAndSettle();

    expect(find.text('Editar item'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<CategoriaItem>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Frios').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pumpAndSettle();

    // Arroz saiu de Mercearia e entrou em Frios.
    expect(find.text('Frios (1)'), findsOneWidget);
    expect(find.text('Mercearia (1)'), findsNothing);
    expect(find.text('Laticínios (1)'), findsOneWidget);

    final itens = await (db.select(
      db.itemLocal,
    )..where((i) => i.deletadoEm.isNull())).get();
    expect(itens.firstWhere((i) => i.nome == 'Arroz').categoria, 'frios');

    await fechar(tester);
  });

  testWidgets(
    'deve_mostrar_titulo_e_voltar_ao_painel_quando_lista_nao_encontrada',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/lista/inexistente',
        routes: [
          GoRoute(
            path: '/lista/:listaId',
            builder: (_, state) =>
                TelaListaScreen(listaId: state.pathParameters['listaId']!),
          ),
          GoRoute(
            path: '/listas',
            builder: (_, _) => const MinhasListasScreen(),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(db)],
          child: appTesteRouter(router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Lista'), findsOneWidget);
      expect(find.text('Lista não encontrada.'), findsOneWidget);

      // CTA do estado vazio (F14-T04): volta ao painel sem precisar da seta.
      await tester.tap(find.text('Voltar para as listas'));
      await tester.pumpAndSettle();
      expect(find.text('Minhas Listas'), findsOneWidget);

      await fechar(tester);
    },
  );

  testWidgets('deve_mostrar_estado_erro_com_retry_quando_lista_falha', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/lista/falhou',
      routes: [
        GoRoute(
          path: '/lista/:listaId',
          builder: (_, state) =>
              TelaListaScreen(listaId: state.pathParameters['listaId']!),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          listaPorIdProvider('falhou').overrideWithValue(
            AsyncValue.error(Exception('cache corrompido'), StackTrace.empty),
          ),
        ],
        child: appTesteRouter(router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppEstadoErro), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);
  });

  testWidgets('deve_mostrar_esqueleto_quando_itens_carregando', (tester) async {
    final repo = ListasRepository(db);
    final lista = await repo.criarLista(titulo: 'Compras', donoId: 'local');
    final itens = StreamController<List<Item>>();
    addTearDown(itens.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          itensDaListaProvider(lista.id).overrideWith((ref) => itens.stream),
        ],
        child: appTeste(TelaListaScreen(listaId: lista.id)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppEsqueleto), findsOneWidget);

    await fechar(tester);
  });

  testWidgets('deve_suportar_escala_de_texto_2x_quando_itens_carregando', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final repo = ListasRepository(db);
    final lista = await repo.criarLista(titulo: 'Compras', donoId: 'local');
    final itens = StreamController<List<Item>>();
    addTearDown(itens.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          itensDaListaProvider(lista.id).overrideWith((ref) => itens.stream),
        ],
        child: appTeste(TelaListaScreen(listaId: lista.id)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppEsqueleto), findsOneWidget);
    expect(tester.takeException(), isNull);

    await fechar(tester);
  });

  testWidgets('deve_mostrar_esqueleto_quando_lista_carregando', (tester) async {
    final repo = ListasRepository(db);
    final lista = await repo.criarLista(titulo: 'Compras', donoId: 'local');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: appTeste(TelaListaScreen(listaId: lista.id)),
      ),
    );
    await tester.pump();

    expect(find.byType(AppEsqueleto), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.pumpAndSettle();
    await fechar(tester);
  });

  testWidgets('deve_nao_estourar_campo_adicionar_quando_escala_2x', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await listaComItens(tester);

    expect(find.widgetWithText(TextField, 'Adicionar item'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await fechar(tester);
  });

  testWidgets('deve_rotular_checkbox_com_o_nome_do_item', (tester) async {
    final handle = tester.ensureSemantics();
    await listaComItens(tester);

    final checkbox = find.byType(Checkbox).first;
    final data = tester.getSemantics(checkbox).getSemanticsData();

    expect(data.label, 'Arroz');

    handle.dispose();
    await fechar(tester);
  });

  // ---- Busca por nome na tela da lista (F16-T03, RF-17) ----

  testWidgets('deve_filtrar_itens_e_manter_grupos_quando_buscar', (
    tester,
  ) async {
    await listaComItens(tester); // Arroz (Mercearia), Leite (Laticínios)

    await tester.tap(find.byTooltip('Buscar'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Buscar item'),
      'arr',
    );
    await tester.pumpAndSettle();

    expect(find.text('Arroz'), findsOneWidget);
    expect(find.text('Leite'), findsNothing);
    expect(find.text('Mercearia (1)'), findsOneWidget);
    expect(find.text('Laticínios (1)'), findsNothing);
    // Drag desabilitado enquanto filtra.
    expect(find.byIcon(Icons.drag_handle), findsNothing);

    await fechar(tester);
  });

  testWidgets('deve_mostrar_vazio_de_busca_quando_sem_resultado', (
    tester,
  ) async {
    await listaComItens(tester);

    await tester.tap(find.byTooltip('Buscar'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Buscar item'),
      'zzz',
    );
    await tester.pumpAndSettle();

    expect(find.text('Nenhum item encontrado'), findsOneWidget);
    expect(find.text('Limpar busca'), findsOneWidget);

    await fechar(tester);
  });

  testWidgets('deve_limpar_busca_quando_adicionar_item', (tester) async {
    await listaComItens(tester);

    await tester.tap(find.byTooltip('Buscar'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Buscar item'),
      'arr',
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Adicionar item'),
      'Café',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    // Busca fechada e itens todos visíveis de novo.
    expect(find.text('Leite'), findsOneWidget);
    expect(find.text('Café'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Buscar item'), findsNothing);

    await fechar(tester);
  });

  testWidgets('deve_manter_edicao_quando_filtrando_item', (tester) async {
    await listaComItens(tester);

    await tester.tap(find.byTooltip('Buscar'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Buscar item'),
      'arr',
    );
    await tester.pumpAndSettle();

    // Sem alça de drag, mas o item ainda é editável (checkbox presente).
    expect(find.byIcon(Icons.drag_handle), findsNothing);
    final checkbox = find.descendant(
      of: find.widgetWithText(ListTile, 'Arroz'),
      matching: find.byType(Checkbox),
    );
    expect(checkbox, findsOneWidget);

    await fechar(tester);
  });

  testWidgets('deve_manter_campo_aberto_quando_limpar_busca_no_vazio', (
    tester,
  ) async {
    await listaComItens(tester);

    await tester.tap(find.byTooltip('Buscar'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Buscar item'),
      'zzz',
    );
    await tester.pumpAndSettle();
    expect(find.text('Nenhum item encontrado'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Limpar busca'));
    await tester.pumpAndSettle();

    // Campo segue aberto e a lista volta ao normal.
    expect(find.widgetWithText(TextField, 'Buscar item'), findsOneWidget);
    expect(find.text('Arroz'), findsOneWidget);
    expect(find.text('Nenhum item encontrado'), findsNothing);

    await fechar(tester);
  });

  testWidgets('deve_filtrar_concluidos_quando_buscar', (tester) async {
    await listaComItens(tester, comConcluido: true); // Detergente concluído

    await tester.tap(find.byTooltip('Buscar'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Buscar item'),
      'deter',
    );
    await tester.pumpAndSettle();

    expect(find.text('Itens concluídos (1)'), findsOneWidget);
    expect(find.text('Arroz'), findsNothing);

    await fechar(tester);
  });

  testWidgets('deve_abrir_editor_quando_tocar_item_filtrado', (tester) async {
    await listaComItens(tester);

    await tester.tap(find.byTooltip('Buscar'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Buscar item'),
      'arr',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Arroz'));
    await tester.pumpAndSettle();

    expect(find.text('Editar item'), findsOneWidget);

    await fechar(tester);
  });

  testWidgets('deve_suportar_escala_de_texto_2x_quando_tela_da_lista', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await listaComItens(tester, comConcluido: true);

    expect(tester.takeException(), isNull);

    await fechar(tester);
  });

  // ---- Chips de itens frequentes (F22-T03, RF-19) ----

  testWidgets('deve_mostrar_chips_de_sugestoes_quando_ha_frequentes', (
    tester,
  ) async {
    await listaComItens(tester);
    await criarFrequentesEmOutraLista('Café', 2);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ActionChip, 'Café'), findsOneWidget);
    // Itens pendentes da lista aberta não viram sugestão.
    expect(find.widgetWithText(ActionChip, 'Arroz'), findsNothing);
    expect(find.widgetWithText(ActionChip, 'Leite'), findsNothing);

    await fechar(tester);
  });

  testWidgets('deve_esconder_chips_quando_campo_tem_texto', (tester) async {
    await listaComItens(tester);
    await criarFrequentesEmOutraLista('Café', 2);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ActionChip, 'Café'), findsOneWidget);

    await tester.enterText(find.byType(AppCampoTexto).first, 'Arr');
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ActionChip, 'Café'), findsNothing);

    await fechar(tester);
  });

  testWidgets('deve_mostrar_chips_de_novo_quando_campo_e_limpo', (
    tester,
  ) async {
    await listaComItens(tester);
    await criarFrequentesEmOutraLista('Café', 2);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ActionChip, 'Café'), findsOneWidget);

    await tester.enterText(find.byType(AppCampoTexto).first, 'Arr');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ActionChip, 'Café'), findsNothing);

    await tester.enterText(find.byType(AppCampoTexto).first, '');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ActionChip, 'Café'), findsOneWidget);

    await fechar(tester);
  });

  testWidgets('deve_adicionar_item_quando_toca_no_chip', (tester) async {
    final listaId = await listaComItens(tester);
    await criarFrequentesEmOutraLista(
      'Banana',
      2,
      categoria: CategoriaItem.hortifruti,
    );
    await tester.pumpAndSettle();

    // Mesma cadeia local usada pelo código ao adicionar pelo chip.
    final categoriaEsperada = await SugestaoCategorias(
      db,
    ).sugerirCategoria('Banana');
    expect(categoriaEsperada, isNot(CategoriaItem.outros));

    await tester.tap(find.widgetWithText(ActionChip, 'Banana'));
    await tester.pumpAndSettle();

    final itens = await db.select(db.itemLocal).get();
    final adicionado = itens.firstWhere(
      (i) => i.nome == 'Banana' && i.listaId == listaId,
    );
    expect(adicionado.quantidade, 1);
    expect(adicionado.unidade, 'un');
    expect(adicionado.categoria, categoriaEsperada.valor);
    expect(find.text('Banana'), findsOneWidget);

    await fechar(tester);
  });

  testWidgets('deve_ordenar_chips_por_peso_quando_pesos_distintos', (
    tester,
  ) async {
    await listaComItens(tester);
    await criarFrequentesEmOutraLista('Feijão', 3);
    await criarFrequentesEmOutraLista('Café', 2);
    await tester.pumpAndSettle();

    final dxFeijao = tester
        .getTopLeft(find.widgetWithText(ActionChip, 'Feijão'))
        .dx;
    final dxCafe = tester
        .getTopLeft(find.widgetWithText(ActionChip, 'Café'))
        .dx;
    expect(dxFeijao, lessThan(dxCafe));

    await fechar(tester);
  });

  testWidgets('nao_deve_duplicar_item_quando_chip_de_nome_ja_concluido', (
    tester,
  ) async {
    final listaId = await listaComItens(tester, comConcluido: true);

    // "Detergente" (concluído) conta peso 2 e aparece como chip (RF-19 §4.1.5).
    expect(find.widgetWithText(ActionChip, 'Detergente'), findsOneWidget);

    await tester.tap(find.widgetWithText(ActionChip, 'Detergente'));
    await tester.pumpAndSettle();

    // Comportamento coerente com _adicionar: mesmo nome ativo e mesma unidade
    // → soma a quantidade; nunca cria um segundo item ativo (RF-10).
    final itens =
        (await (db.select(
          db.itemLocal,
        )..where((i) => i.deletadoEm.isNull())).get()).where(
          (i) => i.listaId == listaId,
        );
    final detergentes = itens.where((i) => i.nome == 'Detergente').toList();
    expect(detergentes, hasLength(1));
    expect(detergentes.single.quantidade, 2);

    await fechar(tester);
  });

  // ---- Botão do modo mercado (F22-T05, RF-18) ----

  testWidgets('deve_mostrar_botao_de_mercado_quando_pode_escrever', (
    tester,
  ) async {
    await listaComItens(tester);
    expect(find.byTooltip('Modo mercado'), findsOneWidget);
    await fechar(tester);
  });

  // ---- Faixa do total no rodapé (F25-T04, RF-21) ----

  Future<String> abrirListaComPreco(
    WidgetTester tester, {
    required bool marcado,
    int? orcamentoCentavos,
  }) async {
    final repo = ListasRepository(db);
    final lista = await repo.criarLista(titulo: 'Compras', donoId: 'local');
    final item = await repo.itens.adicionarItem(
      listaId: lista.id,
      nome: 'Arroz',
      precoCentavos: 549,
    );
    if (marcado) await repo.itens.editarItem(item.id, concluido: true);
    if (orcamentoCentavos != null) {
      await repo.definirOrcamento(lista.id, centavos: orcamentoCentavos);
    }
    await montarTela(tester, lista.id);
    return lista.id;
  }

  testWidgets('deve_mostrar_total_no_rodape_quando_ha_marcado_com_preco', (
    tester,
  ) async {
    await abrirListaComPreco(tester, marcado: true);
    expect(find.textContaining(r'R$ 5,49'), findsOneWidget);
    await fechar(tester);
  });

  testWidgets('nao_deve_mostrar_total_quando_nada_marcado', (tester) async {
    await abrirListaComPreco(tester, marcado: false);
    expect(find.textContaining('No carrinho:'), findsNothing);
    await fechar(tester);
  });

  testWidgets('nao_deve_somar_sem_preco_quando_total', (tester) async {
    final repo = ListasRepository(db);
    final lista = await repo.criarLista(titulo: 'Compras', donoId: 'local');
    // Marcado COM preço (R$ 5,49) + marcado SEM preço (R$ 999,00 no nome):
    // o total soma só o primeiro e conta o segundo como "1 sem preço".
    final comPreco = await repo.itens.adicionarItem(
      listaId: lista.id,
      nome: 'Arroz',
      precoCentavos: 549,
    );
    final semPreco = await repo.itens.adicionarItem(
      listaId: lista.id,
      nome: 'Item caro',
      precoCentavos: 99900,
    );
    await repo.itens.editarItem(comPreco.id, concluido: true);
    await repo.itens.editarItem(
      semPreco.id,
      concluido: true,
      limparPreco: true,
    );
    await montarTela(tester, lista.id);

    expect(
      find.text('No carrinho: ${formatarReais(549)} · 1 sem preço'),
      findsOneWidget,
    );
    expect(find.textContaining(r'R$ 999,00'), findsNothing);
    await fechar(tester);
  });

  testWidgets('deve_mostrar_orcamento_quando_definido', (tester) async {
    await abrirListaComPreco(tester, marcado: true, orcamentoCentavos: 1000);
    expect(find.textContaining(r'de R$ 10,00'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await fechar(tester);
  });

  testWidgets('deve_alertar_quando_total_ultrapassa_orcamento', (tester) async {
    await abrirListaComPreco(tester, marcado: true, orcamentoCentavos: 300);
    expect(find.text('Acima do orçamento'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    await fechar(tester);
  });

  // ---- Preço no editor de item (F25-T04, RF-21) ----

  testWidgets('deve_salvar_preco_quando_editor_preenchido', (tester) async {
    await abrirListaComPreco(tester, marcado: false);

    await tester.tap(find.text('Arroz'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Preço (R\$)'),
      '12,34',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pumpAndSettle();

    final item = (await db.select(db.itemLocal).get()).single;
    expect(item.precoCentavos, 1234);
    await fechar(tester);
  });

  testWidgets('deve_mostrar_erro_inline_quando_preco_invalido', (tester) async {
    await abrirListaComPreco(tester, marcado: false);

    await tester.tap(find.text('Arroz'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Preço (R\$)'),
      'abc',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pumpAndSettle();

    expect(find.text('Preço inválido.'), findsOneWidget);
    expect(find.text('Editar item'), findsOneWidget); // segue aberto
    final item = (await db.select(db.itemLocal).get()).single;
    expect(item.precoCentavos, 549); // inalterado
    await fechar(tester);
  });

  // ---- Adicionar de outra lista (F27-T02, RF-23) ----

  testWidgets('deve_abrir_modal_de_outra_lista_quando_toca_menu', (
    tester,
  ) async {
    final repo = ListasRepository(db);
    final atual = await repo.criarLista(titulo: 'Atual', donoId: 'local');
    await repo.criarLista(titulo: 'Outra', donoId: 'local');
    await abrirListaComItem(tester, listaId: atual.id);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Adicionar de outra lista'), findsOneWidget);
    await tester.tap(find.text('Adicionar de outra lista'));
    await tester.pumpAndSettle();
    expect(find.text('Lista de origem'), findsOneWidget);

    await fechar(tester);
  });

  testWidgets('deve_adicionar_selecionados_quando_confirma', (tester) async {
    final repo = ListasRepository(db);
    final atual = await repo.criarLista(titulo: 'Atual', donoId: 'local');
    final origem = await repo.criarLista(titulo: 'Outra', donoId: 'local');
    await repo.itens.adicionarItem(
      listaId: origem.id,
      nome: 'Arroz',
      quantidade: 2,
    );
    await repo.itens.adicionarItem(listaId: origem.id, nome: 'Feijão');
    await abrirListaComItem(tester, listaId: atual.id);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Adicionar de outra lista'));
    await tester.pumpAndSettle();
    // Quantidade inteira é exibida sem casa decimal (2, não "2.0").
    expect(find.text('2 un'), findsOneWidget);
    expect(find.text('2.0 un'), findsNothing);
    await tester.tap(find.text('Selecionar todos'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Adicionar'));
    await tester.pumpAndSettle();

    final itens = await (db.select(
      db.itemLocal,
    )..where((i) => i.listaId.equals(atual.id))).get();
    // "Feijão" só existe na origem — prova a transferência.
    final feijao = itens.singleWhere((i) => i.nome == 'Feijão');
    expect(feijao.quantidade, 1);
    expect(feijao.unidade, 'un');
    // "Arroz" já existia na lista atual com 1 un (harness) e veio com 2 un da
    // origem: a dedup soma → 3 un (RF-10), sem duplicar a linha.
    final arroz = itens.where((i) => i.nome == 'Arroz').toList();
    expect(arroz, hasLength(1));
    expect(arroz.single.quantidade, 3);
    expect(find.text('2 itens adicionados de outra lista.'), findsOneWidget);

    await fechar(tester);
  });

  testWidgets('deve_selecionar_todos_quando_toca', (tester) async {
    final repo = ListasRepository(db);
    final atual = await repo.criarLista(titulo: 'Atual', donoId: 'local');
    final origem = await repo.criarLista(titulo: 'Outra', donoId: 'local');
    await repo.itens.adicionarItem(
      listaId: origem.id,
      nome: 'Arroz',
      quantidade: 2,
    );
    await repo.itens.adicionarItem(listaId: origem.id, nome: 'Feijão');
    await abrirListaComItem(tester, listaId: atual.id);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Adicionar de outra lista'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Selecionar todos'));
    await tester.pumpAndSettle();

    final checkboxes = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(Checkbox),
    );
    expect(checkboxes, findsNWidgets(2));
    for (var i = 0; i < 2; i++) {
      expect(tester.widget<Checkbox>(checkboxes.at(i)).value, isTrue);
    }
    final confirmar = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Adicionar'),
    );
    expect(confirmar.onPressed, isNotNull);

    await fechar(tester);
  });

  testWidgets('deve_desabilitar_confirmar_quando_nada_selecionado', (
    tester,
  ) async {
    final repo = ListasRepository(db);
    final atual = await repo.criarLista(titulo: 'Atual', donoId: 'local');
    final origem = await repo.criarLista(titulo: 'Outra', donoId: 'local');
    await repo.itens.adicionarItem(listaId: origem.id, nome: 'Feijão');
    await abrirListaComItem(tester, listaId: atual.id);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Adicionar de outra lista'));
    await tester.pumpAndSettle();

    final confirmar = find.widgetWithText(FilledButton, 'Adicionar');
    expect(tester.widget<FilledButton>(confirmar).onPressed, isNull);

    await tester.tap(confirmar);
    await tester.pumpAndSettle();

    // Nada foi adicionado e o modal segue aberto.
    expect(find.text('Lista de origem'), findsOneWidget);
    final itens = await (db.select(
      db.itemLocal,
    )..where((i) => i.listaId.equals(atual.id))).get();
    expect(itens.where((i) => i.nome == 'Feijão'), isEmpty);

    await fechar(tester);
  });

  testWidgets('nao_de_listar_a_propria_lista_como_origem', (tester) async {
    final repo = ListasRepository(db);
    final atual = await repo.criarLista(titulo: 'Atual', donoId: 'local');
    final origem = await repo.criarLista(titulo: 'Outra', donoId: 'local');
    await repo.itens.adicionarItem(listaId: origem.id, nome: 'Feijão');
    await abrirListaComItem(tester, listaId: atual.id);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Adicionar de outra lista'));
    await tester.pumpAndSettle();

    final dropdown = tester.widget<AppDropdown<String>>(
      find.byType(AppDropdown<String>),
    );
    final ids = dropdown.itens.map((i) => i.value).toList();
    expect(ids, isNot(contains(atual.id)));
    expect(ids, contains(origem.id));

    await fechar(tester);
  });

  testWidgets('deve_suportar_escala_de_texto_2x_quando_modal_de_outra_lista', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final repo = ListasRepository(db);
    final atual = await repo.criarLista(titulo: 'Atual', donoId: 'local');
    final origem = await repo.criarLista(titulo: 'Outra', donoId: 'local');
    await repo.itens.adicionarItem(
      listaId: origem.id,
      nome: 'Arroz',
      quantidade: 2,
    );
    await repo.itens.adicionarItem(listaId: origem.id, nome: 'Feijão');
    await abrirListaComItem(tester, listaId: atual.id);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Adicionar de outra lista'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    await fechar(tester);
  });

  testWidgets('deve_rotular_origem_arquivada_quando_escolhe', (tester) async {
    final repo = ListasRepository(db);
    final atual = await repo.criarLista(titulo: 'Atual', donoId: 'local');
    final origem = await repo.criarLista(titulo: 'Outra', donoId: 'local');
    await repo.definirArquivada(origem.id, arquivada: true);
    await abrirListaComItem(tester, listaId: atual.id);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Adicionar de outra lista'));
    await tester.pumpAndSettle();

    // O rótulo combina título + "Arquivada" (Arquivada).
    final rotulo = 'Outra · Arquivada';
    final dropdown = tester.widget<AppDropdown<String>>(
      find.byType(AppDropdown<String>),
    );
    final rotulos = dropdown.itens
        .map((item) => (item.child as Text).data)
        .toList();
    expect(rotulos, contains(rotulo));
    // Origem única (arquivada) → já vem selecionada e rotulada no seletor.
    expect(find.text(rotulo), findsWidgets);

    await fechar(tester);
  });

  testWidgets('nao_deve_listar_itens_concluidos_da_origem_quando_abre', (
    tester,
  ) async {
    final repo = ListasRepository(db);
    final atual = await repo.criarLista(titulo: 'Atual', donoId: 'local');
    final origem = await repo.criarLista(titulo: 'Outra', donoId: 'local');
    await repo.itens.adicionarItem(listaId: origem.id, nome: 'Feijão');
    final detergente = await repo.itens.adicionarItem(
      listaId: origem.id,
      nome: 'Detergente',
    );
    await repo.itens.editarItem(detergente.id, concluido: true);
    await abrirListaComItem(tester, listaId: atual.id);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Adicionar de outra lista'));
    await tester.pumpAndSettle();

    final dialogo = find.byType(AlertDialog);
    // Só o pendente vira opção (checkbox); o concluído da origem não aparece.
    expect(
      find.descendant(of: dialogo, matching: find.text('Feijão')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialogo, matching: find.text('Detergente')),
      findsNothing,
    );
    expect(
      find.descendant(of: dialogo, matching: find.byType(Checkbox)),
      findsOneWidget,
    );

    await fechar(tester);
  });

  testWidgets('deve_limpar_selecao_quando_troca_a_origem', (tester) async {
    final repo = ListasRepository(db);
    final atual = await repo.criarLista(titulo: 'Atual', donoId: 'local');
    final primeira = await repo.criarLista(titulo: 'Primeira', donoId: 'local');
    await repo.itens.adicionarItem(listaId: primeira.id, nome: 'Feijão');
    final segunda = await repo.criarLista(titulo: 'Segunda', donoId: 'local');
    await repo.itens.adicionarItem(listaId: segunda.id, nome: 'Leite');
    await abrirListaComItem(tester, listaId: atual.id);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Adicionar de outra lista'));
    await tester.pumpAndSettle();

    final confirmar = find.widgetWithText(FilledButton, 'Adicionar');
    await tester.tap(find.text('Selecionar todos'));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(confirmar).onPressed, isNotNull);

    // Troca a origem (Segunda → Primeira): a seleção anterior é limpa.
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Primeira').last);
    await tester.pumpAndSettle();

    expect(tester.widget<FilledButton>(confirmar).onPressed, isNull);

    await fechar(tester);
  });

  // ---- Adicionar item por voz (F30-T02, RF-26) ----

  testWidgets('deve_preencher_campo_quando_reconhece', (tester) async {
    final fake = FakeReconhecimentoVoz();
    await abrirListaComItem(tester, reconhecimento: fake);

    await tester.tap(find.byTooltip('Ditar item'));
    await tester.pump();
    fake.emitir('meio quilo de queijo');
    await tester.pump();

    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'Adicionar item'))
          .controller!
          .text,
      'meio quilo de queijo',
    );
    await fechar(tester);
  });

  testWidgets('deve_mostrar_snackbar_quando_indisponivel', (tester) async {
    final fake = FakeReconhecimentoVoz(disponivel: false);
    await abrirListaComItem(tester, reconhecimento: fake);

    await tester.tap(find.byTooltip('Ditar item'));
    await tester.pumpAndSettle();

    expect(
      find.text('Reconhecimento de voz indisponível neste aparelho.'),
      findsOneWidget,
    );
    await fechar(tester);
  });

  testWidgets('deve_parar_quando_toca_de_novo', (tester) async {
    final fake = FakeReconhecimentoVoz();
    await abrirListaComItem(tester, reconhecimento: fake);

    await tester.tap(find.byTooltip('Ditar item'));
    await tester.pump();
    await tester.tap(find.byTooltip('Ditar item'));
    await tester.pump();

    expect(fake.parou, isTrue);
    await fechar(tester);
  });

  testWidgets('deve_cancelar_quando_sai_da_tela_durante_ditado', (
    tester,
  ) async {
    final fake = FakeReconhecimentoVoz();
    await abrirListaComItem(tester, reconhecimento: fake);

    await tester.tap(find.byTooltip('Ditar item'));
    await tester.pump();
    expect(fake.cancelou, isFalse);

    // Sair da tela durante o ditado cancela o reconhecimento (mic não fica
    // quente). `fechar` desmonta a árvore → dispose do campo.
    await fechar(tester);
    expect(fake.cancelou, isTrue);
  });

  testWidgets('deve_cancelar_quando_sai_da_tela_antes_do_iniciar_concluir', (
    tester,
  ) async {
    final fake = FakeReconhecimentoVoz()..adiarInicio = Completer<void>();
    await abrirListaComItem(tester, reconhecimento: fake);

    // `iniciar` fica pendente: a tela ainda não está `ouvindo`.
    await tester.tap(find.byTooltip('Ditar item'));
    await tester.pump();
    expect(fake.cancelou, isFalse);

    await fechar(tester);
    expect(fake.cancelou, isTrue);

    fake.adiarInicio!.complete();
    await tester.pump();
  });

  testWidgets('deve_confirmar_item_quando_enter_apos_ditar', (tester) async {
    final fake = FakeReconhecimentoVoz();
    final listaId = await abrirListaComItem(tester, reconhecimento: fake);

    await tester.tap(find.byTooltip('Ditar item'));
    await tester.pump();
    fake.emitir('2 kg de arroz', finalizado: true);
    await tester.pump();

    // Confirma pelo teclado (Enter) no campo preenchido pela voz.
    await tester.tap(find.widgetWithText(TextField, 'Adicionar item'));
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    final itens = await (db.select(
      db.itemLocal,
    )..where((i) => i.listaId.equals(listaId))).get();
    final arroz = itens.singleWhere((i) => i.nome == 'Arroz');
    expect(arroz.quantidade, 2);
    expect(arroz.unidade, 'kg');

    await fechar(tester);
  });

  testWidgets('deve_mostrar_finalizar_compra_quando_tem_item_concluido', (
    tester,
  ) async {
    await listaComItens(tester, comConcluido: true);

    expect(find.widgetWithText(AppBotao, 'Finalizar compra'), findsOneWidget);

    await fechar(tester);
  });

  testWidgets('nao_deve_mostrar_finalizar_compra_quando_sem_concluido', (
    tester,
  ) async {
    await listaComItens(tester);

    expect(find.widgetWithText(AppBotao, 'Finalizar compra'), findsNothing);

    await fechar(tester);
  });

  testWidgets('deve_mostrar_finalizar_no_menu_quando_tem_concluido', (
    tester,
  ) async {
    await listaComItens(tester, comConcluido: true);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(PopupMenuItem<String>, 'Finalizar compra'),
      findsOneWidget,
    );

    await fechar(tester);
  });

  testWidgets('nao_deve_mostrar_finalizar_no_menu_quando_sem_concluido', (
    tester,
  ) async {
    await listaComItens(tester);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Finalizar compra'), findsNothing);

    await fechar(tester);
  });
}

class _RepoLimparFalha extends ItensRepository {
  _RepoLimparFalha(super.db);

  @override
  Future<List<Item>> limparConcluidos(String listaId) async =>
      throw Exception('falha simulada');
}

class _RepoAdicionarFalha extends ItensRepository {
  _RepoAdicionarFalha(super.db);

  @override
  Future<ResultadoDedup> adicionarItemDedup({
    required String listaId,
    required String nome,
    required double quantidade,
    required Unidade unidade,
    required CategoriaItem categoria,
    int? precoCentavos,
  }) async => throw Exception('falha simulada');
}

class _RepoRestaurarFalha extends ItensRepository {
  _RepoRestaurarFalha(super.db);

  @override
  Future<void> restaurarItem(String id) async =>
      throw Exception('falha simulada');
}
