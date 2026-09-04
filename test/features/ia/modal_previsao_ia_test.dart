import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/l10n/app_strings.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/ia/domain/resposta_parse.dart';
import 'package:lista_compras/features/ia/ui/modal_previsao_ia.dart';
import 'package:lista_compras/features/listas/data/listas_repository.dart';
import 'package:lista_compras/features/listas/domain/unidade.dart';
import 'package:lista_compras/features/listas/providers/listas_providers.dart';

void main() {
  final resposta4 = RespostaParse(
    itens: const [
      ItemExtraido(nome: 'Arroz', quantidade: 1, unidade: Unidade.kg),
      ItemExtraido(nome: 'Leite', quantidade: 2, unidade: Unidade.un),
      ItemExtraido(nome: 'Queijo prato', quantidade: 500, unidade: Unidade.g),
      ItemExtraido(nome: 'Café', quantidade: 1, unidade: Unidade.pct),
    ],
    aviso: null,
  );

  List<ItemExtraido>? recebida;

  Future<void> abrir(WidgetTester tester, RespostaParse resposta) async {
    await tester.pumpWidget(
      MaterialApp(
        home: _TelaAbrirPrevisao(
          resposta: resposta,
          onResultado: (r) => recebida = r,
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  Checkbox checkboxDe(WidgetTester tester, String nome) =>
      tester.widget<Checkbox>(
        find.descendant(
          of: find.widgetWithText(ListTile, nome),
          matching: find.byType(Checkbox),
        ),
      );

  Future<void> alternar(WidgetTester tester, String nome) async {
    await tester.tap(
      find.descendant(
        of: find.widgetWithText(ListTile, nome),
        matching: find.byType(Checkbox),
      ),
    );
    await tester.pump();
  }

  testWidgets('deve_exibir_itens_aviso_e_contagem_quando_abrir', (
    tester,
  ) async {
    await abrir(
      tester,
      RespostaParse(
        itens: resposta4.itens,
        aviso: 'Interpretei pct como pacote',
      ),
    );

    expect(find.text('Arroz'), findsOneWidget);
    expect(find.text('Leite'), findsOneWidget);
    expect(find.text('Queijo prato'), findsOneWidget);
    expect(find.text('Café'), findsOneWidget);
    expect(find.text('Interpretei pct como pacote'), findsOneWidget);
    expect(find.text(AppStrings.iaSeraoAdicionados(4, 4)), findsOneWidget);
    expect(find.text(AppStrings.iaAdicionarN(4)), findsOneWidget);
    expect(checkboxDe(tester, 'Arroz').value, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('deve_excluir_item_quando_desmarcar_checkbox', (tester) async {
    recebida = null;
    await abrir(tester, resposta4);

    await alternar(tester, 'Café');
    expect(find.text(AppStrings.iaSeraoAdicionados(3, 4)), findsOneWidget);

    await tester.tap(
      find.widgetWithText(FilledButton, AppStrings.iaAdicionarN(3)),
    );
    await tester.pumpAndSettle();

    expect(recebida, isNotNull);
    expect(recebida, hasLength(3));
    expect(recebida!.any((i) => i.nome == 'Café'), isFalse);
    expect(recebida!.any((i) => i.nome == 'Arroz'), isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('deve_desabilitar_adicionar_quando_todos_desmarcados', (
    tester,
  ) async {
    await abrir(tester, resposta4);

    for (final nome in ['Arroz', 'Leite', 'Queijo prato', 'Café']) {
      await alternar(tester, nome);
    }
    expect(find.text(AppStrings.iaSeraoAdicionados(0, 4)), findsOneWidget);
    final botao = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, AppStrings.iaAdicionarN(0)),
    );
    expect(botao.onPressed, isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('deve_retornar_null_quando_cancelar', (tester) async {
    recebida = null;
    await abrir(tester, resposta4);

    await tester.tap(find.text(AppStrings.cancelar));
    await tester.pumpAndSettle();

    expect(recebida, isNull);
    expect(find.text(AppStrings.iaConfirmeItens), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('deve_editar_nome_quantidade_unidade_quando_expandir', (
    tester,
  ) async {
    recebida = null;
    await abrir(tester, resposta4);

    await tester.tap(find.byIcon(Icons.expand_more).first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Arroz integral');
    await tester.pump();
    await tester.enterText(find.byType(TextField).at(1), '3');
    await tester.pump();
    await tester.tap(find.byType(DropdownButtonFormField<Unidade>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('l').last);
    await tester.pumpAndSettle();

    expect(find.text('3 l'), findsOneWidget);

    await tester.tap(
      find.widgetWithText(FilledButton, AppStrings.iaAdicionarN(4)),
    );
    await tester.pumpAndSettle();

    final arroz = recebida!.first;
    expect(arroz.nome, 'Arroz integral');
    expect(arroz.quantidade, 3.0);
    expect(arroz.unidade, Unidade.l);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('deve_gravar_itens_via_repositorio_quando_confirmar', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = ListasRepository(db);
    final lista = await repo.criarLista(titulo: 'Compras', donoId: 'user-a');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: _TelaConfirmar(listaId: lista.id, resposta: resposta4),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    await alternar(tester, 'Café');
    await tester.tap(
      find.widgetWithText(FilledButton, AppStrings.iaAdicionarN(3)),
    );
    await tester.pumpAndSettle();

    final itens = await (db.select(
      db.itemLocal,
    )..where((i) => i.listaId.equals(lista.id))).get();
    expect(itens, hasLength(3));
    expect(
      itens.map((i) => i.nome),
      containsAll(['Arroz', 'Leite', 'Queijo prato']),
    );
    expect(
      itens.where((i) => i.nome == 'Queijo prato').single.quantidade,
      500.0,
    );
    expect(find.text(AppStrings.itensExtraidos(3)), findsOneWidget);
  });

  testWidgets('deve_nao_gravar_nada_quando_cancelar', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = ListasRepository(db);
    final lista = await repo.criarLista(titulo: 'Compras', donoId: 'user-a');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: _TelaConfirmar(listaId: lista.id, resposta: resposta4),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppStrings.cancelar));
    await tester.pumpAndSettle();

    final itens = await (db.select(
      db.itemLocal,
    )..where((i) => i.listaId.equals(lista.id))).get();
    expect(itens, isEmpty);
    expect(find.byType(SnackBar), findsNothing);
  });
}

class _TelaAbrirPrevisao extends StatelessWidget {
  const _TelaAbrirPrevisao({required this.resposta, this.onResultado});

  final RespostaParse resposta;
  final ValueChanged<List<ItemExtraido>?>? onResultado;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () async {
            final r = await showDialog<List<ItemExtraido>>(
              context: context,
              builder: (_) => ModalPrevisaoIa(resposta: resposta),
            );
            onResultado?.call(r);
          },
          child: const Text('abrir'),
        ),
      ),
    );
  }
}

class _TelaConfirmar extends ConsumerWidget {
  const _TelaConfirmar({required this.listaId, required this.resposta});

  final String listaId;
  final RespostaParse resposta;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () =>
              confirmarItensImportados(context, ref, listaId, resposta),
          child: const Text('abrir'),
        ),
      ),
    );
  }
}
