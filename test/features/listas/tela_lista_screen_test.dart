import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lista_compras/core/l10n/app_strings.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/auth/providers/auth_providers.dart';
import 'package:lista_compras/features/convites/data/convites_repository.dart';
import 'package:lista_compras/features/convites/data/papel_repository.dart';
import 'package:lista_compras/features/convites/domain/papel.dart';
import 'package:lista_compras/features/convites/providers/convites_providers.dart';
import 'package:lista_compras/features/convites/providers/papel_providers.dart';
import 'package:lista_compras/features/ia/data/parse_lista_client.dart';
import 'package:lista_compras/features/ia/providers/ia_providers.dart';
import 'package:lista_compras/features/listas/data/listas_repository.dart';
import 'package:lista_compras/features/listas/domain/categoria.dart';
import 'package:lista_compras/features/listas/providers/listas_providers.dart';
import 'package:lista_compras/features/listas/ui/minhas_listas_screen.dart';
import 'package:lista_compras/features/listas/domain/unidade.dart';
import 'package:lista_compras/features/listas/ui/tela_lista_screen.dart';
import 'package:lista_compras/features/sync/domain/sync_status.dart';
import 'package:lista_compras/features/sync/providers/sync_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../convites/servidor_fake.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
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
    expect(find.text('Detergente'), findsOneWidget);

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

    await fechar(tester);
  });

  testWidgets('deve_abrir_modal_importar_ia_quando_tocar_botao', (
    tester,
  ) async {
    final repo = ListasRepository(db);
    final lista = await repo.criarLista(
      titulo: 'Compras da Semana',
      donoId: 'user-a',
    );
    final clienteIa = ParseListaClient(
      obterToken: () => 'jwt-teste',
      obterUri: () =>
          Uri.parse('https://projeto.supabase.co/functions/v1/parse-lista'),
      httpClient: MockClient(
        (_) async => http.Response('{"itens": [], "aviso": null}', 200),
      ),
    );
    final sync = StreamController<SyncStatus>();
    sync.add(const Sincronizado());
    addTearDown(sync.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          parseListaClientProvider.overrideWithValue(clienteIa),
          papelRepositoryProvider.overrideWithValue(
            papelRepo(tester, listaId: lista.id, papel: Papel.dono),
          ),
          syncStatusProvider.overrideWith((ref) => sync.stream),
        ],
        child: MaterialApp(home: TelaListaScreen(listaId: lista.id)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppStrings.importarPorIa));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.iaColeOuDigite), findsOneWidget);
    expect(find.text(AppStrings.iaExtrairItens), findsOneWidget);

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
    final lista = await repo.criarLista(titulo: 'Compras', donoId: 'user-a');
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
        child: MaterialApp(home: TelaListaScreen(listaId: lista.id)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.convidar), findsNothing);
    expect(find.text(AppStrings.membros), findsOneWidget);

    await tester.tap(find.text(AppStrings.membros));
    await tester.pumpAndSettle();

    // Tela de membros: próprio usuário destacado, chip de papel e "Sair da
    // lista" (F7-T03).
    expect(find.text(AppStrings.voce), findsOneWidget);
    expect(find.text(AppStrings.convidarPapelLeitor), findsOneWidget);
    expect(
      find.widgetWithText(TextButton, AppStrings.sairDaLista),
      findsOneWidget,
    );
    await fechar(tester);
  });
}
