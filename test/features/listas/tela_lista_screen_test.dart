import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lista_compras/core/l10n/app_strings.dart';
import 'package:lista_compras/core/categorias/sugestao_categorias.dart';
import 'package:lista_compras/core/widgets/app_banner.dart';
import 'package:lista_compras/core/widgets/app_campo_texto.dart';
import 'package:lista_compras/core/widgets/app_dropdown.dart';
import 'package:lista_compras/core/widgets/app_esqueleto.dart';
import 'package:lista_compras/core/widgets/app_estado_erro.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/auth/providers/auth_providers.dart';
import 'package:lista_compras/features/convites/data/convites_repository.dart';
import 'package:lista_compras/features/convites/data/papel_repository.dart';
import 'package:lista_compras/features/convites/domain/papel.dart';
import 'package:lista_compras/features/convites/providers/convites_providers.dart';
import 'package:lista_compras/features/convites/providers/papel_providers.dart';
import 'package:lista_compras/features/listas/data/listas_repository.dart';
import 'package:lista_compras/features/listas/domain/categoria.dart';
import 'package:lista_compras/features/listas/domain/item.dart';
import 'package:lista_compras/features/listas/domain/lista.dart';
import 'package:lista_compras/features/listas/domain/preco.dart';
import 'package:lista_compras/features/listas/providers/listas_providers.dart';
import 'package:lista_compras/features/listas/ui/minhas_listas_screen.dart';
import 'package:lista_compras/features/convites/ui/tela_membros_screen.dart';
import 'package:lista_compras/features/listas/domain/unidade.dart';
import 'package:lista_compras/features/listas/ui/tela_lista_screen.dart';
import 'package:lista_compras/features/sync/domain/sync_status.dart';
import 'package:lista_compras/features/sync/providers/sync_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../convites/servidor_fake.dart';
import '../auth/fakes.dart';

void main() {
  setUpAll(inicializarSupabaseTeste);

  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    await db.close();
  });

  /// PapelRepository de teste com papel pré-carregado (state em memória;
  /// servidor fake não é consultado pelo estado).
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

  Future<String> listaComItens(
    WidgetTester tester, {
    bool comConcluido = false,
    Papel papel = Papel.dono,
    String donoAtual = '',
  }) async {
    final repo = ListasRepository(db);
    final lista = await repo.criarLista(
      titulo: 'Compras da Semana',
      donoId: 'user-a',
    );
    await repo.adicionarItem(
      listaId: lista.id,
      nome: 'Arroz',
      categoria: CategoriaItem.mercearia,
    );
    await repo.adicionarItem(
      listaId: lista.id,
      nome: 'Leite',
      categoria: CategoriaItem.laticinios,
    );
    if (comConcluido) {
      final detergente = await repo.adicionarItem(
        listaId: lista.id,
        nome: 'Detergente',
        categoria: CategoriaItem.limpeza,
      );
      await repo.editarItem(detergente.id, concluido: true);
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
          donoAtualIdProvider.overrideWithValue(donoAtual),
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

  /// Cria um item frequente fora da lista aberta (peso = 1 por ocorrência).
  Future<void> criarFrequentesEmOutraLista(
    String nome,
    int vezes, {
    CategoriaItem categoria = CategoriaItem.outros,
  }) async {
    final repo = ListasRepository(db);
    final outra = await repo.criarLista(titulo: 'Outra', donoId: 'user-a');
    for (var i = 0; i < vezes; i++) {
      await repo.adicionarItem(
        listaId: outra.id,
        nome: nome,
        quantidade: 1,
        categoria: categoria,
      );
    }
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
    expect(find.text('${AppStrings.itens} (2)'), findsNothing);
    expect(find.text('${AppStrings.itensConcluidos} (1)'), findsOneWidget);

    await tester.tap(find.text('${AppStrings.itensConcluidos} (1)'));
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

  testWidgets('deve_agrupar_pendentes_na_ordem_do_enum_quando_exibir_f6t04', (
    tester,
  ) async {
    final repo = ListasRepository(db);
    final lista = await repo.criarLista(titulo: 'Compras', donoId: 'user-a');
    await repo.adicionarItem(
      listaId: lista.id,
      nome: 'Leite',
      categoria: CategoriaItem.laticinios,
    );
    await repo.adicionarItem(
      listaId: lista.id,
      nome: 'Banana',
      categoria: CategoriaItem.hortifruti,
    );
    await repo.adicionarItem(
      listaId: lista.id,
      nome: 'Arroz',
      categoria: CategoriaItem.mercearia,
    );
    await repo.adicionarItem(
      listaId: lista.id,
      nome: 'Café',
      categoria: CategoriaItem.mercearia,
    );
    final sync = StreamController<SyncStatus>();
    sync.add(const Sincronizado());
    addTearDown(sync.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          papelRepositoryProvider.overrideWithValue(
            papelRepo(tester, listaId: lista.id, papel: Papel.dono),
          ),
          syncStatusProvider.overrideWith((ref) => sync.stream),
        ],
        child: MaterialApp(home: TelaListaScreen(listaId: lista.id)),
      ),
    );
    await tester.pumpAndSettle();

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
    final lista = await repo.criarLista(titulo: 'Compras', donoId: 'user-a');
    await repo.adicionarItem(
      listaId: lista.id,
      nome: 'Arroz',
      categoria: CategoriaItem.mercearia,
    );
    await repo.adicionarItem(
      listaId: lista.id,
      nome: 'Banana',
      categoria: CategoriaItem.hortifruti,
    );
    await repo.adicionarItem(
      listaId: lista.id,
      nome: 'Suco',
      categoria: CategoriaItem.bebidas,
    );
    final sync = StreamController<SyncStatus>();
    sync.add(const Sincronizado());
    addTearDown(sync.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          papelRepositoryProvider.overrideWithValue(
            papelRepo(tester, listaId: lista.id, papel: Papel.dono),
          ),
          syncStatusProvider.overrideWith((ref) => sync.stream),
        ],
        child: MaterialApp(home: TelaListaScreen(listaId: lista.id)),
      ),
    );
    await tester.pumpAndSettle();

    final dyBebidas = tester
        .getTopLeft(find.text('${CategoriaItem.bebidas.rotulo} (1)'))
        .dy;
    final dyMercearia = tester
        .getTopLeft(find.text('${CategoriaItem.mercearia.rotulo} (1)'))
        .dy;
    final dyHortifruti = tester
        .getTopLeft(find.text('${CategoriaItem.hortifruti.rotulo} (1)'))
        .dy;
    expect(dyBebidas, lessThan(dyMercearia));
    expect(dyMercearia, lessThan(dyHortifruti));
    await fechar(tester);
  });

  testWidgets('deve_adicionar_item_quando_enter_no_campo', (tester) async {
    await listaComItens(tester);

    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.adicionarItem),
      'Café',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('Café'), findsOneWidget);
    expect(find.text('Mercearia (2)'), findsOneWidget);
    expect(find.text('1 un'), findsNWidgets(3));

    await fechar(tester);
  });

  testWidgets('deve_mostrar_erro_quando_parser_descarta_texto', (tester) async {
    await listaComItens(tester);

    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.adicionarItem),
      '.',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.naoEntendiItem), findsOneWidget);
    // Nada foi adicionado.
    expect(find.text('Mercearia (1)'), findsOneWidget);

    // O erro some ao digitar de novo.
    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.adicionarItem),
      'Café',
    );
    await tester.pump();
    expect(find.text(AppStrings.naoEntendiItem), findsNothing);

    await fechar(tester);
  });

  testWidgets('deve_aplicar_sugestao_local_quando_adicionar_rapido_f6t04', (
    tester,
  ) async {
    await listaComItens(tester);

    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.adicionarItem),
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
      find.widgetWithText(TextField, AppStrings.adicionarItem),
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
      find.widgetWithText(TextField, AppStrings.adicionarItem),
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
      find.widgetWithText(TextField, AppStrings.adicionarItem),
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
      find.widgetWithText(TextField, AppStrings.adicionarItem),
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
      find.widgetWithText(TextField, AppStrings.adicionarItem),
      '2kg de arroz',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('Arroz'), findsOneWidget);
    expect(find.text('2 kg'), findsOneWidget);
    expect(find.textContaining(AppStrings.itemAtualizado), findsOneWidget);

    await fechar(tester);
  });

  testWidgets('deve_editar_e_remover_quando_tocar_no_item', (tester) async {
    await listaComItens(tester);

    await tester.tap(find.text('Arroz'));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.editarItem), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, AppStrings.removerItem));
    await tester.pumpAndSettle();

    expect(find.text('Arroz'), findsNothing);
    expect(find.text(AppStrings.itemRemovido), findsOneWidget);

    await tester.tap(find.text(AppStrings.desfazer));
    await tester.pumpAndSettle();
    expect(find.text('Arroz'), findsOneWidget);

    await fechar(tester);
  });

  testWidgets('deve_rotular_nome_do_item_quando_abre_editor', (tester) async {
    await listaComItens(tester);

    // Entrada rápida mantém "Adicionar item".
    expect(
      find.widgetWithText(TextField, AppStrings.adicionarItem),
      findsOneWidget,
    );

    await tester.tap(find.text('Arroz'));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.editarItem), findsOneWidget);
    expect(
      find.widgetWithText(TextField, AppStrings.nomeDoItem),
      findsOneWidget,
    );

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
    expect(find.text('${AppStrings.itensConcluidos} (1)'), findsOneWidget);

    await tester.tap(find.text('${AppStrings.itensConcluidos} (1)'));
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
    expect(find.text(AppStrings.itemRemovido), findsOneWidget);

    await tester.tap(find.text(AppStrings.desfazer));
    await tester.pumpAndSettle();

    expect(find.text('Arroz'), findsOneWidget);
    expect(find.text('Mercearia (1)'), findsOneWidget);

    await fechar(tester);
  });

  testWidgets('deve_editar_quantidade_e_unidade_quando_swipe_direita', (
    tester,
  ) async {
    await listaComItens(tester);

    await tester.drag(find.text('Arroz'), const Offset(500, 0));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.editarItem), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.quantidade),
      '3',
    );
    await tester.tap(find.byType(DropdownButtonFormField<Unidade>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('kg').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, AppStrings.salvar));
    await tester.pumpAndSettle();

    expect(find.text('3 kg'), findsOneWidget);
    expect(find.text(AppStrings.editarItem), findsNothing);

    await fechar(tester);
  });

  testWidgets('deve_mostrar_erro_inline_quando_nome_e_quantidade_invalidos', (
    tester,
  ) async {
    await listaComItens(tester);

    await tester.tap(find.text('Arroz'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.nomeDoItem),
      '',
    );
    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.quantidade),
      '0',
    );
    await tester.tap(find.widgetWithText(FilledButton, AppStrings.salvar));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.erroNomeVazio), findsOneWidget);
    expect(find.text(AppStrings.erroQuantidadeInvalida), findsOneWidget);
    // O diálogo permanece aberto (nada foi salvo).
    expect(find.text(AppStrings.editarItem), findsOneWidget);
    expect(find.text('Arroz'), findsOneWidget);

    await fechar(tester);
  });

  testWidgets('deve_limpar_erro_da_quantidade_quando_ajustar_stepper', (
    tester,
  ) async {
    await listaComItens(tester);

    await tester.tap(find.text('Arroz'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.quantidade),
      '0',
    );
    await tester.tap(find.widgetWithText(FilledButton, AppStrings.salvar));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.erroQuantidadeInvalida), findsOneWidget);

    await tester.tap(find.byTooltip(AppStrings.aumentar));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.erroQuantidadeInvalida), findsNothing);

    await fechar(tester);
  });

  testWidgets('deve_desmarcar_todos_quando_menu', (tester) async {
    await listaComItens(tester);
    final repo = ListasRepository(db);
    final itens = (await (db.select(
      db.itemLocal,
    )).get()).where((i) => !i.concluido).toList();
    await repo.editarItem(itens.first.id, concluido: true);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.desmarcarTodos));
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
    await tester.tap(find.text(AppStrings.limparConcluidos));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.limparConcluidosMensagem), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, AppStrings.limpar));
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
    await tester.tap(find.text(AppStrings.limparConcluidos));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, AppStrings.limpar));
    await tester.pumpAndSettle();

    expect(find.text('Detergente'), findsNothing);
    expect(find.text(AppStrings.concluidosRemovidos), findsOneWidget);

    await tester.tap(find.text(AppStrings.desfazer));
    await tester.pumpAndSettle();

    expect(find.text('${AppStrings.itensConcluidos} (1)'), findsOneWidget);

    await fechar(tester);
  });

  testWidgets('deve_mostrar_erro_quando_limpar_concluidos_falha', (
    tester,
  ) async {
    final repo = ListasRepository(db);
    final lista = await repo.criarLista(
      titulo: 'Compras da Semana',
      donoId: 'user-a',
    );
    await repo.adicionarItem(
      listaId: lista.id,
      nome: 'Arroz',
      categoria: CategoriaItem.mercearia,
    );
    final detergente = await repo.adicionarItem(
      listaId: lista.id,
      nome: 'Detergente',
      categoria: CategoriaItem.limpeza,
    );
    await repo.editarItem(detergente.id, concluido: true);
    final sync = StreamController<SyncStatus>();
    sync.add(const Sincronizado());
    addTearDown(sync.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          listasRepositoryProvider.overrideWithValue(_RepoLimparFalha(db)),
          papelRepositoryProvider.overrideWithValue(
            papelRepo(tester, listaId: lista.id, papel: Papel.dono),
          ),
          donoAtualIdProvider.overrideWithValue('user-a'),
          syncStatusProvider.overrideWith((ref) => sync.stream),
        ],
        child: MaterialApp(home: TelaListaScreen(listaId: lista.id)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.limparConcluidos));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, AppStrings.limpar));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.erroGenerico), findsOneWidget);

    await fechar(tester);
  });

  testWidgets('deve_excluir_lista_e_voltar_ao_painel_quando_confirmar', (
    tester,
  ) async {
    final repo = ListasRepository(db);
    final lista = await repo.criarLista(
      titulo: 'Compras da Semana',
      donoId: 'user-a',
    );
    await repo.adicionarItem(listaId: lista.id, nome: 'Arroz');

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
    final sync = StreamController<SyncStatus>();
    sync.add(const Sincronizado());
    addTearDown(sync.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          papelRepositoryProvider.overrideWithValue(
            papelRepo(tester, listaId: lista.id, papel: Papel.dono),
          ),
          donoAtualIdProvider.overrideWithValue('user-a'),
          syncStatusProvider.overrideWith((ref) => sync.stream),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.excluirLista));
    await tester.pumpAndSettle();
    expect(find.text('Excluir "Compras da Semana"?'), findsOneWidget);
    expect(find.text('O item será removido.'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, AppStrings.excluir));
    await tester.pumpAndSettle();

    final local = await (db.select(
      db.listaLocal,
    )..where((l) => l.id.equals(lista.id))).getSingle();
    expect(local.deletadoEm, isNotNull);
    expect(find.text(AppStrings.minhasListas), findsOneWidget);
    expect(find.text(AppStrings.nenhumaLista), findsOneWidget);

    await fechar(tester);
  });

  testWidgets('deve_renomear_lista_quando_menu', (tester) async {
    await listaComItens(tester);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.renomearLista));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.nomeDaLista),
      'Churrasco',
    );
    await tester.tap(find.widgetWithText(FilledButton, AppStrings.salvar));
    await tester.pumpAndSettle();

    expect(find.text('Churrasco'), findsOneWidget);
    expect(find.text('Compras da Semana'), findsNothing);
    expect(find.text(AppStrings.listaRenomeada), findsOneWidget);

    await fechar(tester);
  });

  testWidgets('deve_abrir_modal_importar_quando_tocar_botao', (tester) async {
    final repo = ListasRepository(db);
    final lista = await repo.criarLista(
      titulo: 'Compras da Semana',
      donoId: 'user-a',
    );
    final sync = StreamController<SyncStatus>();
    sync.add(const Sincronizado());
    addTearDown(sync.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          papelRepositoryProvider.overrideWithValue(
            papelRepo(tester, listaId: lista.id, papel: Papel.dono),
          ),
          syncStatusProvider.overrideWith((ref) => sync.stream),
        ],
        child: MaterialApp(home: TelaListaScreen(listaId: lista.id)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppStrings.importarLista));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.importColeOuDigite), findsOneWidget);
    expect(find.text(AppStrings.importExtrairItens), findsOneWidget);

    await fechar(tester);
  });

  testWidgets('deve_reordenar_dentro_do_grupo_quando_arrastar_alca_f6t04', (
    tester,
  ) async {
    final repo = ListasRepository(db);
    final lista = await repo.criarLista(titulo: 'Compras', donoId: 'user-a');
    await repo.adicionarItem(
      listaId: lista.id,
      nome: 'Arroz',
      categoria: CategoriaItem.mercearia,
    ); // mercearia
    await repo.adicionarItem(
      listaId: lista.id,
      nome: 'Feijão',
      categoria: CategoriaItem.mercearia,
    ); // mercearia
    await repo.adicionarItem(
      listaId: lista.id,
      nome: 'Leite',
      categoria: CategoriaItem.laticinios,
    ); // laticinios
    final sync = StreamController<SyncStatus>();
    sync.add(const Sincronizado());
    addTearDown(sync.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          papelRepositoryProvider.overrideWithValue(
            papelRepo(tester, listaId: lista.id, papel: Papel.dono),
          ),
          syncStatusProvider.overrideWith((ref) => sync.stream),
        ],
        child: MaterialApp(home: TelaListaScreen(listaId: lista.id)),
      ),
    );
    await tester.pumpAndSettle();

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

    final mutacoes = await (db.select(db.mutacaoPendente)).get();
    final idsComUpdate = mutacoes
        .where((m) => m.operacao == 'UPDATE' && m.tabela == 'itens_lista')
        .map((m) => m.registroId)
        .toSet();
    expect(idsComUpdate, {arroz.id, feijao.id});

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

      final mutacoes = await (db.select(db.mutacaoPendente)).get();
      expect(
        mutacoes.where(
          (m) => m.operacao == 'UPDATE' && m.tabela == 'itens_lista',
        ),
        isEmpty,
      );

      await fechar(tester);
    },
  );

  testWidgets('deve_editar_categoria_quando_swipe_direita_f6t04', (
    tester,
  ) async {
    await listaComItens(tester);

    await tester.drag(find.text('Arroz'), const Offset(500, 0));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.editarItem), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<CategoriaItem>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Frios').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, AppStrings.salvar));
    await tester.pumpAndSettle();

    // Arroz saiu de Mercearia e entrou em Frios.
    expect(find.text('Frios (1)'), findsOneWidget);
    expect(find.text('Mercearia (1)'), findsNothing);
    expect(find.text('Laticínios (1)'), findsOneWidget);

    final itens = await (db.select(
      db.itemLocal,
    )..where((i) => i.deletadoEm.isNull())).get();
    expect(itens.firstWhere((i) => i.nome == 'Arroz').categoria, 'frios');

    final mutacoes = await (db.select(db.mutacaoPendente)).get();
    final payload = mutacoes
        .where((m) => m.operacao == 'UPDATE' && m.tabela == 'itens_lista')
        .map((m) => m.payload)
        .last;
    expect(payload, contains('"categoria":"frios"'));

    await fechar(tester);
  });

  testWidgets('deve_abrir_sheet_convidar_quando_dono_menu_f7t03', (
    tester,
  ) async {
    await listaComItens(tester);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.membros), findsOneWidget);
    expect(find.text(AppStrings.convidar), findsOneWidget);

    await tester.tap(find.text(AppStrings.convidar));
    await tester.pumpAndSettle();

    // Sheet "Convidar" (F7-T03): radios de papel + botão gerar.
    expect(
      find.widgetWithText(FilledButton, AppStrings.gerarLink),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(RadioListTile<Papel>, AppStrings.convidarPapelEditor),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(RadioListTile<Papel>, AppStrings.convidarPapelLeitor),
      findsOneWidget,
    );

    await fechar(tester);
  });

  testWidgets('deve_abrir_tela_membros_quando_membro_nao_dono_menu_f7t03', (
    tester,
  ) async {
    final repo = ListasRepository(db);
    final lista = await repo.criarLista(titulo: 'Compras', donoId: 'user-c');
    await repo.adicionarItem(listaId: lista.id, nome: 'Arroz');
    final servidor = ServidorFake((req) {
      if (req.method == 'GET' && req.url.path.contains('/lista_membros')) {
        return (
          200,
          [
            {'lista_id': lista.id, 'user_id': 'user-a', 'papel': 'leitor'},
          ],
        );
      }
      return (200, const <Object>[]);
    });
    addTearDown(servidor.close);
    final sync = StreamController<SyncStatus>();
    sync.add(const Sincronizado());
    addTearDown(sync.close);

    final router = GoRouter(
      initialLocation: '/lista/${lista.id}',
      routes: [
        GoRoute(
          path: '/lista/:listaId',
          builder: (_, state) =>
              TelaListaScreen(listaId: state.pathParameters['listaId']!),
        ),
        GoRoute(
          path: '/membros/:listaId',
          builder: (_, state) =>
              TelaMembrosScreen(listaId: state.pathParameters['listaId']!),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          papelRepositoryProvider.overrideWithValue(
            papelRepo(tester, listaId: lista.id, papel: Papel.leitor),
          ),
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
          donoAtualIdProvider.overrideWithValue('user-a'),
          syncStatusProvider.overrideWith((ref) => sync.stream),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.convidar), findsNothing);
    expect(find.text(AppStrings.membros), findsOneWidget);

    await tester.tap(find.text(AppStrings.membros));
    await tester.pumpAndSettle();

    // Navegação via rota /membros/:listaId (F7-T03): tela de membros com
    // próprio usuário destacado, chip de papel e "Sair da lista".
    expect(find.text('${AppStrings.membros} · Compras'), findsOneWidget);
    expect(find.text(AppStrings.voce), findsOneWidget);
    expect(find.text(AppStrings.convidarPapelLeitor), findsOneWidget);
    expect(
      find.widgetWithText(TextButton, AppStrings.sairDaLista),
      findsOneWidget,
    );
    await fechar(tester);
  });

  // ---- Papel na tela da lista (F7-T04, doc 08 §1, RF-13) ----

  testWidgets('deve_mostrar_banner_e_menu_reduzido_quando_leitor_f7t04', (
    tester,
  ) async {
    await listaComItens(tester, papel: Papel.leitor);

    // Banner de leitura pelo componente padrão (F14-T08).
    final bannerApp = tester.widget<AppBanner>(find.byType(AppBanner).first);
    expect(bannerApp.tipo, AppBannerTipo.leitura);
    expect(
      find.text(
        '${AppStrings.somenteLeitura}: ${AppStrings.somenteLeituraDica}',
      ),
      findsOneWidget,
    );

    // Menu do leitor: sem escritas em massa, sem renomear/excluir/convidar.
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.desmarcarTodos), findsNothing);
    expect(find.text(AppStrings.limparConcluidos), findsNothing);
    expect(find.text(AppStrings.renomearLista), findsNothing);
    expect(find.text(AppStrings.excluirLista), findsNothing);
    expect(find.text(AppStrings.convidar), findsNothing);
    expect(find.text(AppStrings.membros), findsOneWidget);

    await fechar(tester);
  });

  testWidgets('deve_bloquear_escritas_quando_leitor_f7t04', (tester) async {
    await listaComItens(tester, papel: Papel.leitor);

    // Sem campo adicionar, sem botão IA, sem checkbox, sem swipe, sem alça.
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(Checkbox), findsNothing);
    expect(find.byIcon(Icons.drag_handle), findsNothing);
    expect(find.text(AppStrings.importarLista), findsNothing);

    // Swipe não abre edição nem remove (Dismissible não existe).
    await tester.drag(find.text('Arroz'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('Arroz'), findsOneWidget);
    expect(find.text(AppStrings.itemRemovido), findsNothing);
    expect(find.byType(SnackBar), findsNothing);

    final itens = await (db.select(
      db.itemLocal,
    )..where((i) => i.deletadoEm.isNull())).get();
    expect(itens.firstWhere((i) => i.nome == 'Arroz').concluido, isFalse);

    await fechar(tester);
  });

  testWidgets('deve_esconder_itens_dono_quando_editor_f7t04', (tester) async {
    await listaComItens(tester, papel: Papel.editor);

    // Editor escreve: campo, IA, checkbox.
    expect(
      find.widgetWithText(TextField, AppStrings.adicionarItem),
      findsOneWidget,
    );
    expect(find.text(AppStrings.importarLista), findsOneWidget);
    expect(find.byType(Checkbox), findsWidgets);

    // Menu: dono-only ausente; demais escritas presentes.
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.excluirLista), findsNothing);
    expect(find.text(AppStrings.convidar), findsNothing);
    expect(find.text(AppStrings.membros), findsOneWidget);
    expect(find.text(AppStrings.desmarcarTodos), findsOneWidget);
    expect(find.text(AppStrings.limparConcluidos), findsOneWidget);
    expect(find.text(AppStrings.renomearLista), findsOneWidget);

    await fechar(tester);
  });

  testWidgets('deve_manter_tudo_quando_dono_f7t04', (tester) async {
    await listaComItens(tester, papel: Papel.dono);

    expect(
      find.widgetWithText(TextField, AppStrings.adicionarItem),
      findsOneWidget,
    );
    expect(find.text(AppStrings.importarLista), findsOneWidget);
    expect(find.byType(Checkbox), findsWidgets);
    expect(find.text(AppStrings.somenteLeitura), findsNothing);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.excluirLista), findsOneWidget);
    expect(find.text(AppStrings.convidar), findsOneWidget);
    expect(find.text(AppStrings.membros), findsOneWidget);
    expect(find.text(AppStrings.desmarcarTodos), findsOneWidget);
    expect(find.text(AppStrings.limparConcluidos), findsOneWidget);
    expect(find.text(AppStrings.renomearLista), findsOneWidget);

    await fechar(tester);
  });

  testWidgets('deve_editar_quando_donoId_e_do_usuario_mesmo_sem_papel', (
    tester,
  ) async {
    // Correção: dono derivado da lista local, mesmo sem papel do servidor
    // (ex.: após reiniciar o app a associação ainda não carregou).
    await listaComItens(tester, papel: Papel.leitor, donoAtual: 'user-a');

    expect(find.text(AppStrings.somenteLeitura), findsNothing);
    expect(
      find.widgetWithText(TextField, AppStrings.adicionarItem),
      findsOneWidget,
    );

    await fechar(tester);
  });

  // ---- Feedback "membro entrou" (F7-T07, doc 08 §7) ----

  Future<(PapelRepository, String)> abrirListaF7t07(
    WidgetTester tester, {
    String? listaId,
  }) async {
    final repo = ListasRepository(db);
    final id =
        listaId ??
        (await repo.criarLista(titulo: 'Compras', donoId: 'user-a')).id;
    await repo.adicionarItem(listaId: id, nome: 'Arroz');
    final servidor = ServidorFake((req) => (200, const <Object>[]));
    addTearDown(servidor.close);
    final papelRepo = PapelRepository(
      SupabaseClient(
        'http://127.0.0.1:54321',
        'test-key',
        httpClient: servidor,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      ),
    );
    papelRepo.atualizar(id, Papel.dono);
    final sync = StreamController<SyncStatus>();
    sync.add(const Sincronizado());
    addTearDown(sync.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          papelRepositoryProvider.overrideWithValue(papelRepo),
          syncStatusProvider.overrideWith((ref) => sync.stream),
        ],
        child: MaterialApp(home: TelaListaScreen(listaId: id)),
      ),
    );
    await tester.pumpAndSettle();
    return (papelRepo, id);
  }

  testWidgets('deve_mostrar_membro_entrou_quando_outro_entrar_f7t07', (
    tester,
  ) async {
    final (papelRepo, listaId) = await abrirListaF7t07(tester);
    expect(find.text(AppStrings.membroEntrou), findsNothing);

    papelRepo.notificarEntrada(listaId);
    await tester.pump();

    expect(find.text(AppStrings.membroEntrou), findsOneWidget);
    expect(papelRepo.membroEntrou.value, isNull); // consumido pela tela

    await fechar(tester);
  });

  testWidgets('deve_ignorar_entrada_de_outra_lista_quando_notificar_f7t07', (
    tester,
  ) async {
    final (papelRepo, _) = await abrirListaF7t07(tester);

    papelRepo.notificarEntrada('outra-lista');
    await tester.pump();

    expect(find.text(AppStrings.membroEntrou), findsNothing);
    expect(papelRepo.membroEntrou.value, 'outra-lista'); // não consumido

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
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            donoAtualIdProvider.overrideWithValue('user-a'),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.lista), findsOneWidget);
      expect(find.text(AppStrings.listaNaoEncontrada), findsOneWidget);

      // CTA do estado vazio (F14-T04): volta ao painel sem precisar da seta.
      await tester.tap(find.text(AppStrings.voltarParaListas));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.minhasListas), findsOneWidget);

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
          donoAtualIdProvider.overrideWithValue('user-a'),
          listaPorIdProvider('falhou').overrideWith(
            (ref) => Stream<Lista?>.error(Exception('cache corrompido')),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppEstadoErro), findsOneWidget);
    expect(find.text(AppStrings.tentarNovamente), findsOneWidget);
  });

  testWidgets('deve_mostrar_esqueleto_quando_itens_carregando', (tester) async {
    final repo = ListasRepository(db);
    final lista = await repo.criarLista(titulo: 'Compras', donoId: 'user-a');
    final itens = StreamController<List<Item>>();
    addTearDown(itens.close);
    final sync = StreamController<SyncStatus>();
    sync.add(const Sincronizado());
    addTearDown(sync.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          itensDaListaProvider(lista.id).overrideWith((ref) => itens.stream),
          papelRepositoryProvider.overrideWithValue(
            papelRepo(tester, listaId: lista.id, papel: Papel.dono),
          ),
          syncStatusProvider.overrideWith((ref) => sync.stream),
        ],
        child: MaterialApp(home: TelaListaScreen(listaId: lista.id)),
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
    final lista = await repo.criarLista(titulo: 'Compras', donoId: 'user-a');
    final itens = StreamController<List<Item>>();
    addTearDown(itens.close);
    final sync = StreamController<SyncStatus>();
    sync.add(const Sincronizado());
    addTearDown(sync.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          itensDaListaProvider(lista.id).overrideWith((ref) => itens.stream),
          papelRepositoryProvider.overrideWithValue(
            papelRepo(tester, listaId: lista.id, papel: Papel.dono),
          ),
          syncStatusProvider.overrideWith((ref) => sync.stream),
        ],
        child: MaterialApp(home: TelaListaScreen(listaId: lista.id)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppEsqueleto), findsOneWidget);
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

    await tester.tap(find.byTooltip(AppStrings.buscar));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.buscarItem),
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

    await tester.tap(find.byTooltip(AppStrings.buscar));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.buscarItem),
      'zzz',
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.nenhumItemEncontrado), findsOneWidget);
    expect(find.text(AppStrings.limparBusca), findsOneWidget);

    await fechar(tester);
  });

  testWidgets('deve_limpar_busca_quando_adicionar_item', (tester) async {
    await listaComItens(tester);

    await tester.tap(find.byTooltip(AppStrings.buscar));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.buscarItem),
      'arr',
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.adicionarItem),
      'Café',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    // Busca fechada e itens todos visíveis de novo.
    expect(find.text('Leite'), findsOneWidget);
    expect(find.text('Café'), findsOneWidget);
    expect(find.widgetWithText(TextField, AppStrings.buscarItem), findsNothing);

    await fechar(tester);
  });

  testWidgets('deve_manter_edicao_quando_filtrando_item', (tester) async {
    await listaComItens(tester);

    await tester.tap(find.byTooltip(AppStrings.buscar));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.buscarItem),
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

    await tester.tap(find.byTooltip(AppStrings.buscar));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.buscarItem),
      'zzz',
    );
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.nenhumItemEncontrado), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, AppStrings.limparBusca));
    await tester.pumpAndSettle();

    // Campo segue aberto e a lista volta ao normal.
    expect(
      find.widgetWithText(TextField, AppStrings.buscarItem),
      findsOneWidget,
    );
    expect(find.text('Arroz'), findsOneWidget);
    expect(find.text(AppStrings.nenhumItemEncontrado), findsNothing);

    await fechar(tester);
  });

  testWidgets('deve_filtrar_concluidos_quando_buscar', (tester) async {
    await listaComItens(tester, comConcluido: true); // Detergente concluído

    await tester.tap(find.byTooltip(AppStrings.buscar));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.buscarItem),
      'deter',
    );
    await tester.pumpAndSettle();

    expect(find.text('${AppStrings.itensConcluidos} (1)'), findsOneWidget);
    expect(find.text('Arroz'), findsNothing);

    await fechar(tester);
  });

  testWidgets('deve_abrir_editor_quando_tocar_item_filtrado', (tester) async {
    await listaComItens(tester);

    await tester.tap(find.byTooltip(AppStrings.buscar));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.buscarItem),
      'arr',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Arroz'));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.editarItem), findsOneWidget);

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
    await listaComItens(tester, papel: Papel.dono);
    expect(find.byTooltip(AppStrings.modoMercado), findsOneWidget);
    await fechar(tester);
  });

  testWidgets('nao_deve_mostrar_botao_de_mercado_para_leitor', (tester) async {
    await listaComItens(tester, papel: Papel.leitor);
    expect(find.byTooltip(AppStrings.modoMercado), findsNothing);
    await fechar(tester);
  });

  testWidgets('deve_mostrar_botao_de_mercado_quando_editor', (tester) async {
    await listaComItens(tester, papel: Papel.editor);
    expect(find.byTooltip(AppStrings.modoMercado), findsOneWidget);
    await fechar(tester);
  });

  testWidgets('deve_mostrar_voce_agora_dono_quando_papel_vira_dono', (
    tester,
  ) async {
    final (papelRepo, listaId) = await abrirListaF7t07(tester);
    expect(find.text(AppStrings.voceAgoraDono), findsNothing);

    papelRepo.notificarDono(listaId);
    await tester.pump();

    expect(find.text(AppStrings.voceAgoraDono), findsOneWidget);
    expect(papelRepo.donoTransferido.value, isNull); // consumido pela tela

    await fechar(tester);
  });

  testWidgets('deve_ignorar_dono_de_outra_lista_quando_notificar', (
    tester,
  ) async {
    final (papelRepo, _) = await abrirListaF7t07(tester);

    papelRepo.notificarDono('outra-lista');
    await tester.pump();

    expect(find.text(AppStrings.voceAgoraDono), findsNothing);
    expect(papelRepo.donoTransferido.value, 'outra-lista'); // não consumido

    await fechar(tester);
  });

  // ---- Faixa do total no rodapé (F25-T04, RF-21) ----

  Future<String> abrirListaComPreco(
    WidgetTester tester, {
    required bool marcado,
  }) async {
    final repo = ListasRepository(db);
    final lista = await repo.criarLista(titulo: 'Compras', donoId: 'user-a');
    final item = await repo.adicionarItem(
      listaId: lista.id,
      nome: 'Arroz',
      precoCentavos: 549,
    );
    if (marcado) await repo.editarItem(item.id, concluido: true);
    final sync = StreamController<SyncStatus>();
    sync.add(const Sincronizado());
    addTearDown(sync.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          papelRepositoryProvider.overrideWithValue(
            papelRepo(tester, listaId: lista.id, papel: Papel.dono),
          ),
          syncStatusProvider.overrideWith((ref) => sync.stream),
        ],
        child: MaterialApp(home: TelaListaScreen(listaId: lista.id)),
      ),
    );
    await tester.pumpAndSettle();
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
    final lista = await repo.criarLista(titulo: 'Compras', donoId: 'user-a');
    // Marcado COM preço (R$ 5,49) + marcado SEM preço (R$ 999,00 no nome):
    // o total soma só o primeiro e conta o segundo como "1 sem preço".
    final comPreco = await repo.adicionarItem(
      listaId: lista.id,
      nome: 'Arroz',
      precoCentavos: 549,
    );
    final semPreco = await repo.adicionarItem(
      listaId: lista.id,
      nome: 'Item caro',
      precoCentavos: 99900,
    );
    await repo.editarItem(comPreco.id, concluido: true);
    await repo.editarItem(semPreco.id, concluido: true, limparPreco: true);
    final sync = StreamController<SyncStatus>();
    sync.add(const Sincronizado());
    addTearDown(sync.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          papelRepositoryProvider.overrideWithValue(
            papelRepo(tester, listaId: lista.id, papel: Papel.dono),
          ),
          syncStatusProvider.overrideWith((ref) => sync.stream),
        ],
        child: MaterialApp(home: TelaListaScreen(listaId: lista.id)),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(AppStrings.totalNoCarrinho(formatarReais(549), 1)),
      findsOneWidget,
    );
    expect(find.textContaining(r'R$ 999,00'), findsNothing);
    await fechar(tester);
  });

  // ---- Preço no editor de item (F25-T04, RF-21) ----

  testWidgets('deve_salvar_preco_quando_editor_preenchido', (tester) async {
    await abrirListaComPreco(tester, marcado: false);

    await tester.tap(find.text('Arroz'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.preco),
      '12,34',
    );
    await tester.tap(find.widgetWithText(FilledButton, AppStrings.salvar));
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
      find.widgetWithText(TextField, AppStrings.preco),
      'abc',
    );
    await tester.tap(find.widgetWithText(FilledButton, AppStrings.salvar));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.erroPrecoInvalido), findsOneWidget);
    expect(find.text(AppStrings.editarItem), findsOneWidget); // segue aberto
    final item = (await db.select(db.itemLocal).get()).single;
    expect(item.precoCentavos, 549); // inalterado
    await fechar(tester);
  });

  // ---- Adicionar de outra lista (F27-T02, RF-23) ----

  testWidgets('deve_abrir_modal_de_outra_lista_quando_toca_menu', (
    tester,
  ) async {
    final repo = ListasRepository(db);
    final atual = await repo.criarLista(titulo: 'Atual', donoId: 'user-a');
    await repo.criarLista(titulo: 'Outra', donoId: 'user-a');
    await abrirListaF7t07(tester, listaId: atual.id);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.adicionarDeOutraLista), findsOneWidget);
    await tester.tap(find.text(AppStrings.adicionarDeOutraLista));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.escolherListaOrigem), findsOneWidget);

    await fechar(tester);
  });

  testWidgets('deve_adicionar_selecionados_quando_confirma', (tester) async {
    final repo = ListasRepository(db);
    final atual = await repo.criarLista(titulo: 'Atual', donoId: 'user-a');
    final origem = await repo.criarLista(titulo: 'Outra', donoId: 'user-a');
    await repo.adicionarItem(listaId: origem.id, nome: 'Arroz', quantidade: 2);
    await repo.adicionarItem(listaId: origem.id, nome: 'Feijão');
    await abrirListaF7t07(tester, listaId: atual.id);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.adicionarDeOutraLista));
    await tester.pumpAndSettle();
    // Quantidade inteira é exibida sem casa decimal (2, não "2.0").
    expect(find.text('2 un'), findsOneWidget);
    expect(find.text('2.0 un'), findsNothing);
    await tester.tap(find.text(AppStrings.selecionarTodos));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FilledButton, AppStrings.adicionarSelecionados),
    );
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
    expect(find.text(AppStrings.itensAdicionadosDeOutra(2)), findsOneWidget);

    await fechar(tester);
  });

  testWidgets('nao_deve_mostrar_adicionar_de_outra_lista_para_leitor', (
    tester,
  ) async {
    await listaComItens(tester, papel: Papel.leitor);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.adicionarDeOutraLista), findsNothing);
    // O menu do leitor segue com o que lhe cabe (navegação a membros).
    expect(find.text(AppStrings.membros), findsOneWidget);

    await fechar(tester);
  });

  testWidgets('deve_selecionar_todos_quando_toca', (tester) async {
    final repo = ListasRepository(db);
    final atual = await repo.criarLista(titulo: 'Atual', donoId: 'user-a');
    final origem = await repo.criarLista(titulo: 'Outra', donoId: 'user-a');
    await repo.adicionarItem(listaId: origem.id, nome: 'Arroz', quantidade: 2);
    await repo.adicionarItem(listaId: origem.id, nome: 'Feijão');
    await abrirListaF7t07(tester, listaId: atual.id);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.adicionarDeOutraLista));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.selecionarTodos));
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
      find.widgetWithText(FilledButton, AppStrings.adicionarSelecionados),
    );
    expect(confirmar.onPressed, isNotNull);

    await fechar(tester);
  });

  testWidgets('deve_desabilitar_confirmar_quando_nada_selecionado', (
    tester,
  ) async {
    final repo = ListasRepository(db);
    final atual = await repo.criarLista(titulo: 'Atual', donoId: 'user-a');
    final origem = await repo.criarLista(titulo: 'Outra', donoId: 'user-a');
    await repo.adicionarItem(listaId: origem.id, nome: 'Feijão');
    await abrirListaF7t07(tester, listaId: atual.id);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.adicionarDeOutraLista));
    await tester.pumpAndSettle();

    final confirmar = find.widgetWithText(
      FilledButton,
      AppStrings.adicionarSelecionados,
    );
    expect(tester.widget<FilledButton>(confirmar).onPressed, isNull);

    await tester.tap(confirmar);
    await tester.pumpAndSettle();

    // Nada foi adicionado e o modal segue aberto.
    expect(find.text(AppStrings.escolherListaOrigem), findsOneWidget);
    final itens = await (db.select(
      db.itemLocal,
    )..where((i) => i.listaId.equals(atual.id))).get();
    expect(itens.where((i) => i.nome == 'Feijão'), isEmpty);

    await fechar(tester);
  });

  testWidgets('nao_de_listar_a_propria_lista_como_origem', (tester) async {
    final repo = ListasRepository(db);
    final atual = await repo.criarLista(titulo: 'Atual', donoId: 'user-a');
    final origem = await repo.criarLista(titulo: 'Outra', donoId: 'user-a');
    await repo.adicionarItem(listaId: origem.id, nome: 'Feijão');
    await abrirListaF7t07(tester, listaId: atual.id);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.adicionarDeOutraLista));
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
    final atual = await repo.criarLista(titulo: 'Atual', donoId: 'user-a');
    final origem = await repo.criarLista(titulo: 'Outra', donoId: 'user-a');
    await repo.adicionarItem(listaId: origem.id, nome: 'Arroz', quantidade: 2);
    await repo.adicionarItem(listaId: origem.id, nome: 'Feijão');
    await abrirListaF7t07(tester, listaId: atual.id);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.adicionarDeOutraLista));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    await fechar(tester);
  });

  testWidgets('deve_rotular_origem_arquivada_quando_escolhe', (tester) async {
    final repo = ListasRepository(db);
    final atual = await repo.criarLista(titulo: 'Atual', donoId: 'user-a');
    final origem = await repo.criarLista(titulo: 'Outra', donoId: 'user-a');
    await repo.definirArquivada(origem.id, arquivada: true);
    await abrirListaF7t07(tester, listaId: atual.id);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.adicionarDeOutraLista));
    await tester.pumpAndSettle();

    // O rótulo combina título + "Arquivada" (AppStrings.arquivada).
    final rotulo = AppStrings.tituloListaArquivada('Outra');
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
    final atual = await repo.criarLista(titulo: 'Atual', donoId: 'user-a');
    final origem = await repo.criarLista(titulo: 'Outra', donoId: 'user-a');
    await repo.adicionarItem(listaId: origem.id, nome: 'Feijão');
    final detergente = await repo.adicionarItem(
      listaId: origem.id,
      nome: 'Detergente',
    );
    await repo.editarItem(detergente.id, concluido: true);
    await abrirListaF7t07(tester, listaId: atual.id);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.adicionarDeOutraLista));
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
    final atual = await repo.criarLista(titulo: 'Atual', donoId: 'user-a');
    final primeira = await repo.criarLista(
      titulo: 'Primeira',
      donoId: 'user-a',
    );
    await repo.adicionarItem(listaId: primeira.id, nome: 'Feijão');
    final segunda = await repo.criarLista(titulo: 'Segunda', donoId: 'user-a');
    await repo.adicionarItem(listaId: segunda.id, nome: 'Leite');
    await abrirListaF7t07(tester, listaId: atual.id);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.adicionarDeOutraLista));
    await tester.pumpAndSettle();

    final confirmar = find.widgetWithText(
      FilledButton,
      AppStrings.adicionarSelecionados,
    );
    await tester.tap(find.text(AppStrings.selecionarTodos));
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
}

class _RepoLimparFalha extends ListasRepository {
  _RepoLimparFalha(super.db);

  @override
  Future<List<Item>> limparConcluidos(String listaId) async =>
      throw Exception('falha simulada');
}
