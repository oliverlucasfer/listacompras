import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/importacao/resposta_import.dart';
import 'package:lista_compras/core/l10n/app_strings.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/importacao/ui/modal_importar.dart';
import 'package:lista_compras/features/listas/providers/listas_providers.dart';

void main() {
  FilledButton botaoExtrair(WidgetTester tester) => tester.widget<FilledButton>(
    find.widgetWithText(FilledButton, AppStrings.importExtrairItens),
  );

  Future<void> abrir(
    WidgetTester tester, {
    ValueChanged<RespostaParse?>? onResultado,
  }) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(home: _TelaAbrirModal(onResultado: onResultado)),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('deve_desabilitar_extrair_quando_texto_vazio', (tester) async {
    await abrir(tester);
    expect(botaoExtrair(tester).onPressed, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('deve_exibir_contador_atualizado_quando_digitar', (tester) async {
    await abrir(tester);
    await tester.enterText(find.byType(TextField), 'arroz');
    await tester.pump();
    expect(find.text('5/10000'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('deve_bloquear_extracao_e_vermelho_quando_passa_de_10000', (
    tester,
  ) async {
    await abrir(tester);
    await tester.enterText(find.byType(TextField), 'x' * 10001);
    await tester.pump();
    expect(find.text('10001/10000'), findsOneWidget);
    final contador = tester.widget<Text>(find.text('10001/10000'));
    final contexto = tester.element(find.text('10001/10000'));
    expect(contador.style?.color, Theme.of(contexto).colorScheme.error);
    expect(botaoExtrair(tester).onPressed, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('deve_retornar_itens_quando_extracao_sucesso', (tester) async {
    RespostaParse? recebida;
    await abrir(tester, onResultado: (r) => recebida = r);
    await tester.enterText(find.byType(TextField), '1kg de arroz');
    await tester.pump();
    await tester.tap(
      find.widgetWithText(FilledButton, AppStrings.importExtrairItens),
    );
    await tester.pumpAndSettle();
    expect(recebida, isNotNull);
    expect(recebida!.itens, hasLength(1));
    expect(recebida!.itens.single.nome, 'Arroz');
    expect(recebida!.itens.single.unidade.valor, 'kg');
    expect(find.text(AppStrings.importColeOuDigite), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('deve_extrair_multiplos_itens_localmente', (tester) async {
    RespostaParse? recebida;
    await abrir(tester, onResultado: (r) => recebida = r);
    await tester.enterText(find.byType(TextField), '1kg de arroz, 2 leites');
    await tester.pump();
    await tester.tap(
      find.widgetWithText(FilledButton, AppStrings.importExtrairItens),
    );
    await tester.pumpAndSettle();
    expect(recebida!.itens, hasLength(2));
    expect(recebida!.itens.first.unidade.valor, 'kg');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('deve_exibir_erro_quando_nenhum_item_reconhecido', (
    tester,
  ) async {
    await abrir(tester);
    await tester.enterText(find.byType(TextField), ',,,');
    await tester.pump();
    await tester.tap(
      find.widgetWithText(FilledButton, AppStrings.importExtrairItens),
    );
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.importRespostaInvalida), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('deve_retornar_null_quando_fechar', (tester) async {
    RespostaParse? recebida = const RespostaParse(itens: [], aviso: null);
    await abrir(tester, onResultado: (r) => recebida = r);
    await tester.tap(find.byTooltip(AppStrings.fechar));
    await tester.pumpAndSettle();
    expect(recebida, isNull);
    expect(find.text(AppStrings.importColeOuDigite), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _TelaAbrirModal extends ConsumerWidget {
  const _TelaAbrirModal({this.onResultado});

  final ValueChanged<RespostaParse?>? onResultado;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () async {
            final resposta = await abrirModalImportar(context, ref, 'lista-1');
            onResultado?.call(resposta);
          },
          child: const Text('abrir'),
        ),
      ),
    );
  }
}
