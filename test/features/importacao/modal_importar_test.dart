import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lista_compras/core/importacao/resposta_import.dart';
import 'package:lista_compras/core/l10n/app_strings.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/ia/data/parse_lista_client.dart';
import 'package:lista_compras/features/ia/providers/ia_providers.dart';
import 'package:lista_compras/features/importacao/ui/modal_importar.dart';
import 'package:lista_compras/features/listas/providers/listas_providers.dart';

void main() {
  const corpo200 =
      '{"itens": [{"nome": "Arroz", "quantidade": 1, "unidade": "kg"}],'
      ' "aviso": null}';

  ParseListaClient clienteQue(Future<http.Response> Function() resposta) {
    return ParseListaClient(
      obterToken: () => 'jwt-teste',
      obterUri: () =>
          Uri.parse('https://projeto.supabase.co/functions/v1/parse-lista'),
      httpClient: MockClient((_) => resposta()),
    );
  }

  FilledButton botaoExtrair(WidgetTester tester) => tester.widget<FilledButton>(
    find.widgetWithText(FilledButton, AppStrings.iaExtrairItens),
  );

  Future<void> abrir(
    WidgetTester tester, {
    required ParseListaClient cliente,
    ValueChanged<RespostaParse?>? onResultado,
    ModoImportacao modo = ModoImportacao.ia,
  }) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          parseListaClientProvider.overrideWithValue(cliente),
          appDatabaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp(
          home: _TelaAbrirModal(onResultado: onResultado, modo: modo),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('deve_desabilitar_extrair_quando_texto_vazio', (tester) async {
    await abrir(
      tester,
      cliente: clienteQue(() async => http.Response(corpo200, 200)),
    );

    expect(botaoExtrair(tester).onPressed, isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('deve_exibir_contador_atualizado_quando_digitar', (tester) async {
    await abrir(
      tester,
      cliente: clienteQue(() async => http.Response(corpo200, 200)),
    );

    await tester.enterText(find.byType(TextField), 'arroz');
    await tester.pump();

    expect(find.text('5/2000'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('deve_bloquear_extracao_e_vermelho_quando_passa_de_2000', (
    tester,
  ) async {
    await abrir(
      tester,
      cliente: clienteQue(() async => http.Response(corpo200, 200)),
    );

    await tester.enterText(find.byType(TextField), 'x' * 2001);
    await tester.pump();

    expect(find.text('2001/2000'), findsOneWidget);
    final contador = tester.widget<Text>(find.text('2001/2000'));
    final contexto = tester.element(find.text('2001/2000'));
    expect(contador.style?.color, Theme.of(contexto).colorScheme.error);
    expect(botaoExtrair(tester).onPressed, isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('deve_exibir_carregando_quando_extrair', (tester) async {
    final pendente = Completer<http.Response>();
    await abrir(tester, cliente: clienteQue(() => pendente.future));

    await tester.enterText(find.byType(TextField), 'arroz');
    await tester.pump();
    await tester.tap(
      find.widgetWithText(FilledButton, AppStrings.iaExtrairItens),
    );
    await tester.pump();

    expect(find.text(AppStrings.iaLendo), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text(AppStrings.iaExtrairItens), findsNothing);

    // Completa a chamada para não deixar timer pendente ao descartar.
    pendente.complete(http.Response(corpo200, 200));
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('deve_exibir_erro_amigavel_quando_servidor_retorna_erro', (
    tester,
  ) async {
    await abrir(
      tester,
      cliente: clienteQue(
        () async => http.Response('{"code": "rate_limit"}', 429),
      ),
    );

    await tester.enterText(find.byType(TextField), 'arroz');
    await tester.pump();
    await tester.tap(
      find.widgetWithText(FilledButton, AppStrings.iaExtrairItens),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.iaRateLimit), findsOneWidget);
    expect(find.text(AppStrings.iaExtrairItens), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('deve_limpar_erro_quando_editar_texto_apos_falha', (
    tester,
  ) async {
    await abrir(
      tester,
      cliente: clienteQue(
        () async => http.Response('{"code": "rate_limit"}', 429),
      ),
    );

    await tester.enterText(find.byType(TextField), 'arroz');
    await tester.pump();
    await tester.tap(
      find.widgetWithText(FilledButton, AppStrings.iaExtrairItens),
    );
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.iaRateLimit), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'arroz e feijão');
    await tester.pump();

    expect(find.text(AppStrings.iaRateLimit), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('deve_retornar_itens_quando_extracao_sucesso', (tester) async {
    RespostaParse? recebida;
    await abrir(
      tester,
      cliente: clienteQue(() async => http.Response(corpo200, 200)),
      onResultado: (r) => recebida = r,
    );

    await tester.enterText(find.byType(TextField), '1kg de arroz');
    await tester.pump();
    await tester.tap(
      find.widgetWithText(FilledButton, AppStrings.iaExtrairItens),
    );
    await tester.pumpAndSettle();

    expect(recebida, isNotNull);
    expect(recebida!.itens, hasLength(1));
    expect(recebida!.itens.single.nome, 'Arroz');
    expect(recebida!.itens.single.unidade.valor, 'kg');
    expect(find.text(AppStrings.iaColeOuDigite), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('deve_extrair_localmente_quando_modo_rapido', (tester) async {
    RespostaParse? recebida;
    await abrir(
      tester,
      cliente: clienteQue(() async => http.Response(corpo200, 200)),
      onResultado: (r) => recebida = r,
      modo: ModoImportacao.rapido,
    );

    await tester.enterText(find.byType(TextField), '1kg de arroz, 2 leites');
    await tester.pump();
    await tester.tap(
      find.widgetWithText(FilledButton, AppStrings.iaExtrairItens),
    );
    await tester.pumpAndSettle();

    expect(recebida, isNotNull);
    expect(recebida!.itens, hasLength(2));
    expect(recebida!.itens.first.unidade.valor, 'kg');

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('deve_retornar_null_quando_fechar', (tester) async {
    RespostaParse? recebida = const RespostaParse(itens: [], aviso: null);
    await abrir(
      tester,
      cliente: clienteQue(() async => http.Response(corpo200, 200)),
      onResultado: (r) => recebida = r,
    );

    await tester.tap(find.byTooltip(AppStrings.fechar));
    await tester.pumpAndSettle();

    expect(recebida, isNull);
    expect(find.text(AppStrings.iaColeOuDigite), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _TelaAbrirModal extends ConsumerWidget {
  const _TelaAbrirModal({this.onResultado, this.modo = ModoImportacao.ia});

  final ValueChanged<RespostaParse?>? onResultado;
  final ModoImportacao modo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () async {
            final resposta = await abrirModalImportar(
              context,
              ref,
              'lista-1',
              modoInicial: modo,
            );
            onResultado?.call(resposta);
          },
          child: const Text('abrir'),
        ),
      ),
    );
  }
}
