import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lista_compras/core/config/usuario_local.dart';
import 'package:lista_compras/core/theme/tokens/app_spacing.dart';
import 'package:lista_compras/core/widgets/app_card.dart';
import 'package:lista_compras/core/widgets/app_logo.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/listas/data/listas_repository.dart';
import 'package:lista_compras/features/listas/providers/listas_providers.dart';
import 'package:lista_compras/features/listas/ui/minhas_listas_screen.dart';

import '../../support/app_teste.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    SharedPreferences.setMockInitialValues({'onboarding_visto': true});
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> abrirTela(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/listas',
      routes: [
        GoRoute(path: '/listas', builder: (_, _) => const MinhasListasScreen()),
        GoRoute(
          path: '/lista/:id',
          builder: (_, state) => Scaffold(
            appBar: AppBar(),
            body: Text('lista-${state.pathParameters['id']}'),
          ),
        ),
        GoRoute(
          path: '/boas-vindas',
          builder: (_, _) => const Scaffold(body: Text('boas-vindas')),
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
  }

  /// Desmonta a árvore dentro do teste: o dispose do StreamProvider cancela
  /// streams do Drift, que agendam um Timer(0) — o pump seguinte o consome,
  /// evitando "Timer is still pending" no teardown do binding.
  Future<void> fechar(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('deve_abrir_boas_vindas_quando_nao_visto', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_visto': false});
    await abrirTela(tester);
    expect(find.text('boas-vindas'), findsOneWidget);
    await fechar(tester);
  });

  testWidgets('nao_deve_abrir_boas_vindas_quando_ja_visto', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_visto': true});
    await abrirTela(tester);
    expect(find.text('boas-vindas'), findsNothing);
    await fechar(tester);
  });

  testWidgets('deve_exibir_estado_vazio_quando_nenhuma_lista', (tester) async {
    await abrirTela(tester);
    expect(find.text('Nenhuma lista por aqui'), findsOneWidget);
    expect(find.text('Criar primeira lista'), findsOneWidget);
    expect(find.text('Nova lista'), findsOneWidget);
    await fechar(tester);
  });

  testWidgets('deve_exibir_card_com_contagem_quando_tem_listas', (
    tester,
  ) async {
    final repo = ListasRepository(db);
    final lista = await repo.criarLista(
      titulo: 'Compras da Semana',
      donoId: idLocal,
    );
    final arroz = await repo.itens.adicionarItem(
      listaId: lista.id,
      nome: 'Arroz',
    );
    await repo.itens.adicionarItem(listaId: lista.id, nome: 'Feijão');
    await repo.itens.editarItem(arroz.id, concluido: true);

    await abrirTela(tester);
    expect(find.text('Compras da Semana'), findsOneWidget);
    expect(find.text('1/2 itens concluídos'), findsOneWidget);
    expect(find.textContaining('atualizada'), findsOneWidget);
    await fechar(tester);
  });

  testWidgets('deve_separar_cards_com_espaco_vertical_quando_tem_listas', (
    tester,
  ) async {
    // F12-T05: cards empilhados não podem ficar "grudados" (doc 10 §2.1).
    final repo = ListasRepository(db);
    await repo.criarLista(titulo: 'Compras', donoId: idLocal);
    await repo.criarLista(titulo: 'Churrasco', donoId: idLocal);

    await abrirTela(tester);

    final cards = find.byType(AppCard);
    expect(cards, findsNWidgets(2));
    final primeiro = tester.getRect(cards.at(0));
    final segundo = tester.getRect(cards.at(1));
    expect(segundo.top - primeiro.bottom, greaterThanOrEqualTo(AppSpacing.sm));
    await fechar(tester);
  });

  testWidgets('deve_ocultar_lista_de_outro_dono_quando_nao_e_do_aparelho', (
    tester,
  ) async {
    final repo = ListasRepository(db);
    await repo.criarLista(titulo: 'Do parceiro', donoId: 'user-b');

    await abrirTela(tester);
    expect(find.text('Do parceiro'), findsNothing);
    expect(find.text('Nenhuma lista por aqui'), findsOneWidget);
    await fechar(tester);
  });

  testWidgets('deve_criar_lista_quando_sheet_preenchido_e_salvo', (
    tester,
  ) async {
    await abrirTela(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Nome da lista'),
      'Churrasco',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Criar lista'));
    await tester.pumpAndSettle();

    expect(find.text('Churrasco'), findsOneWidget);
    expect(find.text('Nenhuma lista por aqui'), findsNothing);
    expect(find.text('Lista criada.'), findsOneWidget);
    await fechar(tester);
  });

  testWidgets('deve_exibir_erro_inline_quando_sheet_salvo_sem_nome', (
    tester,
  ) async {
    await abrirTela(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Criar lista'));
    await tester.pumpAndSettle();

    expect(find.text('Informe um nome.'), findsOneWidget);
    expect(find.text('Nenhuma lista por aqui'), findsOneWidget);
    await fechar(tester);
  });

  testWidgets('deve_renomear_lista_quando_long_press_e_sheet_salvo', (
    tester,
  ) async {
    final repo = ListasRepository(db);
    await repo.criarLista(titulo: 'Antigo', donoId: idLocal);
    await abrirTela(tester);

    await tester.longPress(find.text('Antigo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Renomear'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Nome da lista'),
      'Novo',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pumpAndSettle();

    expect(find.text('Novo'), findsOneWidget);
    expect(find.text('Antigo'), findsNothing);
    expect(find.text('Lista renomeada.'), findsOneWidget);
    await fechar(tester);
  });

  testWidgets('deve_excluir_lista_quando_confirmar_dialogo', (tester) async {
    final repo = ListasRepository(db);
    await repo.criarLista(titulo: 'Para excluir', donoId: idLocal);
    await abrirTela(tester);

    await tester.longPress(find.text('Para excluir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir').first);
    await tester.pumpAndSettle();
    expect(find.text('A lista será excluída.'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Excluir'));
    await tester.pumpAndSettle();

    expect(find.text('Para excluir'), findsNothing);
    expect(find.text('Nenhuma lista por aqui'), findsOneWidget);
    await fechar(tester);
  });

  testWidgets('deve_empilhar_e_voltar_ao_painel_quando_abrir_lista', (
    tester,
  ) async {
    final repo = ListasRepository(db);
    await repo.criarLista(titulo: 'Compras', donoId: idLocal);
    await abrirTela(tester);

    await tester.tap(find.text('Compras'));
    await tester.pumpAndSettle();
    expect(find.byType(BackButton), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Compras'), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);

    await fechar(tester);
  });

  testWidgets('deve_exibir_logo_no_cabecalho_quando_tela_de_topo', (
    tester,
  ) async {
    // F13-T02: a marca aparece nas telas de topo (sem botão voltar).
    await abrirTela(tester);

    expect(find.byType(AppLogo), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);

    await fechar(tester);
  });

  testWidgets('deve_suportar_escala_de_texto_2x_quando_painel', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await abrirTela(tester);

    expect(tester.takeException(), isNull);

    await fechar(tester);
  });

  testWidgets('deve_renomear_lista_quando_toca_menu_do_card', (tester) async {
    final repo = ListasRepository(db);
    await repo.criarLista(titulo: 'Antigo', donoId: idLocal);
    await abrirTela(tester);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Renomear'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Nome da lista'),
      'Novo',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pumpAndSettle();

    expect(find.text('Novo'), findsOneWidget);
    expect(find.text('Antigo'), findsNothing);
    await fechar(tester);
  });

  testWidgets('deve_exibir_tooltip_no_menu_do_card', (tester) async {
    final repo = ListasRepository(db);
    await repo.criarLista(titulo: 'Compras', donoId: idLocal);
    await abrirTela(tester);

    expect(find.byTooltip('Menu'), findsOneWidget);
    await fechar(tester);
  });

  testWidgets('deve_filtrar_listas_quando_buscar_pelo_titulo', (tester) async {
    final repo = ListasRepository(db);
    await repo.criarLista(titulo: 'Compras da Semana', donoId: idLocal);
    await repo.criarLista(titulo: 'Churrasco', donoId: idLocal);
    await abrirTela(tester);

    await tester.tap(find.byTooltip('Buscar'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Buscar lista'),
      'chur',
    );
    await tester.pumpAndSettle();

    expect(find.text('Churrasco'), findsOneWidget);
    expect(find.text('Compras da Semana'), findsNothing);

    await fechar(tester);
  });

  testWidgets('deve_mostrar_vazio_quando_busca_sem_resultado', (tester) async {
    final repo = ListasRepository(db);
    await repo.criarLista(titulo: 'Compras', donoId: idLocal);
    await abrirTela(tester);

    await tester.tap(find.byTooltip('Buscar'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Buscar lista'),
      'zzz',
    );
    await tester.pumpAndSettle();

    expect(find.text('Nenhuma lista encontrada'), findsOneWidget);

    await fechar(tester);
  });

  testWidgets('deve_limpar_e_restaurar_quando_fechar_busca', (tester) async {
    final repo = ListasRepository(db);
    await repo.criarLista(titulo: 'Compras da Semana', donoId: idLocal);
    await repo.criarLista(titulo: 'Churrasco', donoId: idLocal);
    await abrirTela(tester);

    await tester.tap(find.byTooltip('Buscar'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Buscar lista'),
      'chur',
    );
    await tester.pumpAndSettle();
    expect(find.text('Compras da Semana'), findsNothing);

    await tester.tap(find.byTooltip('Limpar busca'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Buscar lista'), findsNothing);
    expect(find.text('Compras da Semana'), findsOneWidget);

    await fechar(tester);
  });

  testWidgets('deve_mostrar_comprar_de_novo_quando_ha_pendentes', (
    tester,
  ) async {
    final repo = ListasRepository(db);
    final lista = await repo.criarLista(titulo: 'Compras', donoId: idLocal);
    await repo.itens.adicionarItem(listaId: lista.id, nome: 'Arroz');
    await abrirTela(tester);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('Comprar de novo'), findsOneWidget);
    await fechar(tester);
  });

  testWidgets('nao_deve_mostrar_comprar_de_novo_quando_sem_pendentes', (
    tester,
  ) async {
    final repo = ListasRepository(db);
    final lista = await repo.criarLista(titulo: 'Compras', donoId: idLocal);
    final item = await repo.itens.adicionarItem(
      listaId: lista.id,
      nome: 'Arroz',
    );
    await repo.itens.editarItem(item.id, concluido: true);
    await abrirTela(tester);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('Comprar de novo'), findsNothing);
    await fechar(tester);
  });

  testWidgets('deve_criar_e_navegar_quando_confirma_duplicar', (tester) async {
    final repo = ListasRepository(db);
    final lista = await repo.criarLista(titulo: 'Compras', donoId: idLocal);
    await repo.itens.adicionarItem(listaId: lista.id, nome: 'Arroz');
    await abrirTela(tester);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Comprar de novo'));
    await tester.pumpAndSettle();

    expect(find.text('1 item pendente será copiado.'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Nome da lista'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'Nome da lista'))
          .controller
          ?.text,
      'Compras',
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Criar lista'));
    await tester.pumpAndSettle();

    expect(find.textContaining('lista-'), findsOneWidget);
    expect(find.text('Lista criada.'), findsOneWidget);

    final listas = await db.select(db.listaLocal).get();
    expect(listas, hasLength(2));
    await fechar(tester);
  });

  testWidgets('nao_deve_criar_quando_cancela_duplicar', (tester) async {
    final repo = ListasRepository(db);
    final lista = await repo.criarLista(titulo: 'Compras', donoId: idLocal);
    await repo.itens.adicionarItem(listaId: lista.id, nome: 'Arroz');
    await abrirTela(tester);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Comprar de novo'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Cancelar'));
    await tester.pumpAndSettle();

    final listas = await db.select(db.listaLocal).get();
    expect(listas, hasLength(1));
    await fechar(tester);
  });

  testWidgets('nao_deve_mostrar_arquivada_por_padrao_quando_painel', (
    tester,
  ) async {
    final repo = ListasRepository(db);
    final lista = await repo.criarLista(titulo: 'Velha', donoId: idLocal);
    await repo.definirArquivada(lista.id, arquivada: true);
    await abrirTela(tester);

    expect(find.text('Velha'), findsNothing);
    await fechar(tester);
  });

  testWidgets('deve_mostrar_arquivada_com_rotulo_quando_toggle_ligado', (
    tester,
  ) async {
    final repo = ListasRepository(db);
    final lista = await repo.criarLista(titulo: 'Velha', donoId: idLocal);
    await repo.definirArquivada(lista.id, arquivada: true);
    await abrirTela(tester);

    await tester.tap(find.byTooltip('Mostrar arquivadas'));
    await tester.pumpAndSettle();

    expect(find.text('Velha'), findsOneWidget);
    expect(find.text('Arquivada'), findsOneWidget);
    await fechar(tester);
  });

  testWidgets('deve_arquivar_quando_dono_toca_menu', (tester) async {
    final repo = ListasRepository(db);
    await repo.criarLista(titulo: 'Ativa', donoId: idLocal);
    await abrirTela(tester);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Arquivar'));
    await tester.pumpAndSettle();

    expect(find.text('Ativa'), findsNothing);
    expect(find.text('Lista arquivada.'), findsOneWidget);
    await fechar(tester);
  });

  testWidgets('deve_desarquivar_quando_toca_em_lista_arquivada_visivel', (
    tester,
  ) async {
    final repo = ListasRepository(db);
    final lista = await repo.criarLista(titulo: 'Velha', donoId: idLocal);
    await repo.definirArquivada(lista.id, arquivada: true);
    await abrirTela(tester);

    await tester.tap(find.byTooltip('Mostrar arquivadas'));
    await tester.pumpAndSettle();
    expect(find.text('Velha'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Desarquivar'));
    await tester.pumpAndSettle();

    expect(find.text('Lista desarquivada.'), findsOneWidget);

    await tester.tap(find.byTooltip('Mostrar arquivadas'));
    await tester.pumpAndSettle();

    expect(find.text('Velha'), findsOneWidget);
    expect(find.text('Arquivada'), findsNothing);
    await fechar(tester);
  });
}
