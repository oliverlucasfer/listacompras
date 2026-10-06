import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/widgets/app_dropdown.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/listas/data/listas_repository.dart';
import 'package:lista_compras/features/listas/providers/listas_providers.dart';
import 'package:lista_compras/features/listas/ui/mercado_screen.dart';
import 'package:lista_compras/features/ocr/domain/fonte_imagem.dart';
import 'package:lista_compras/features/ocr/domain/ocr_texto.dart';
import 'package:lista_compras/features/ocr/providers/ocr_providers.dart';

import '../../support/app_teste.dart';

class _OcrFake implements OcrTexto {
  _OcrFake(this._texto);
  final String _texto;
  @override
  Future<String> extrair(String caminho) async => _texto;
  @override
  void close() {}
}

class _FonteFake implements FonteImagem {
  _FonteFake({this.caminho = '/tmp/a.jpg'});
  final String? caminho;
  @override
  Future<String?> daCamera() async => caminho;
  @override
  Future<String?> daGaleria() async => caminho;
}

/// Fecha a árvore e deixa o Drift executar seus timers de fechamento de stream
/// antes do fim do corpo do teste (padrão de mercado_screen_test.dart).
Future<void> fechar(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
}

/// Sobe o modo mercado com os fakes e devolve o id da lista criada.
Future<void> _pumpMercado(
  WidgetTester tester,
  AppDatabase db,
  ListasRepository repo, {
  required String texto,
  FonteImagem? fonte,
}) async {
  final lista = await repo.criarLista(titulo: 'Compras', donoId: 'local');
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        ocrTextoProvider.overrideWithValue(_OcrFake(texto)),
        fonteImagemProvider.overrideWithValue(fonte ?? _FonteFake()),
      ],
      child: appTeste(MercadoScreen(listaId: lista.id)),
    ),
  );
  await tester.pumpAndSettle();
}

/// Abre a câmera e confirma "Tirar foto".
Future<void> _lerEtiqueta(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.photo_camera_outlined));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Tirar foto'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('deve_criar_item_com_preco_quando_le_etiqueta', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = ListasRepository(db);

    await _pumpMercado(tester, db, repo, texto: 'Arroz\nR\$ 5,49');
    await _lerEtiqueta(tester);

    // Preview "Etiqueta lida" aberto; confirma a criação do item.
    expect(find.text('Etiqueta lida'), findsOneWidget);
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    final item = (await db.select(db.itemLocal).get()).single;
    expect(item.nome, 'Arroz');
    expect(item.precoCentavos, 549);
    await fechar(tester);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('deve_aplicar_preco_em_item_existente', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = ListasRepository(db);
    final lista = await repo.criarLista(titulo: 'Compras', donoId: 'local');
    await repo.adicionarItem(listaId: lista.id, nome: 'Arroz');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          ocrTextoProvider.overrideWithValue(_OcrFake(r'R$ 5,49')),
          fonteImagemProvider.overrideWithValue(_FonteFake()),
        ],
        child: appTeste(MercadoScreen(listaId: lista.id)),
      ),
    );
    await tester.pumpAndSettle();

    await _lerEtiqueta(tester);

    await tester.tap(find.text('Item existente'));
    await tester.pumpAndSettle();
    // Abre o dropdown (hint "Escolha o item") tocando o próprio campo.
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Arroz').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();

    final item = (await db.select(db.itemLocal).get()).single;
    expect(item.precoCentavos, 549);
    await fechar(tester);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('deve_avisar_quando_sem_preco_na_etiqueta', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = ListasRepository(db);

    await _pumpMercado(tester, db, repo, texto: 'Oferta da semana');
    await _lerEtiqueta(tester);

    expect(find.text('Não reconheci um preço na etiqueta.'), findsOneWidget);
    await fechar(tester);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('deve_ocultar_botao_camera_quando_sem_ocr', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = ListasRepository(db);

    await _pumpMercado(tester, db, repo, texto: 'Arroz\nR\$ 5,49');

    expect(find.byIcon(Icons.photo_camera_outlined), findsNothing);
    await fechar(tester);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('deve_nao_gravar_quando_cancela_a_captura', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = ListasRepository(db);

    await _pumpMercado(
      tester,
      db,
      repo,
      texto: 'Arroz\nR\$ 5,49',
      fonte: _FonteFake(caminho: null),
    );
    await _lerEtiqueta(tester);

    expect(find.text('Etiqueta lida'), findsNothing);
    expect(await db.select(db.itemLocal).get(), isEmpty);
    await fechar(tester);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('deve_desabilitar_aplicar_quando_sem_item_selecionado', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = ListasRepository(db);
    final lista = await repo.criarLista(titulo: 'Compras', donoId: 'local');
    await repo.adicionarItem(listaId: lista.id, nome: 'Arroz');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          ocrTextoProvider.overrideWithValue(_OcrFake(r'R$ 5,49')),
          fonteImagemProvider.overrideWithValue(_FonteFake()),
        ],
        child: appTeste(MercadoScreen(listaId: lista.id)),
      ),
    );
    await tester.pumpAndSettle();

    await _lerEtiqueta(tester);
    await tester.tap(find.text('Item existente'));
    await tester.pumpAndSettle();

    final aplicar = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Aplicar'),
    );
    expect(aplicar.onPressed, isNull);
    await fechar(tester);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('deve_listar_pendentes_primeiro_no_dropdown', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = ListasRepository(db);
    final lista = await repo.criarLista(titulo: 'Compras', donoId: 'local');
    // Concluído criado antes (menor ordem): sem a ordenação viria primeiro.
    final concluido = await repo.adicionarItem(
      listaId: lista.id,
      nome: 'Leite',
    );
    final pendente = await repo.adicionarItem(listaId: lista.id, nome: 'Arroz');
    await repo.editarItem(concluido.id, concluido: true);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          ocrTextoProvider.overrideWithValue(_OcrFake(r'R$ 5,49')),
          fonteImagemProvider.overrideWithValue(_FonteFake()),
        ],
        child: appTeste(MercadoScreen(listaId: lista.id)),
      ),
    );
    await tester.pumpAndSettle();

    await _lerEtiqueta(tester);
    await tester.tap(find.text('Item existente'));
    await tester.pumpAndSettle();

    final dropdown = tester.widget<AppDropdown<String>>(
      find.byType(AppDropdown<String>),
    );
    final ids = dropdown.itens.map((e) => e.value).toList();
    expect(ids.indexOf(pendente.id), lessThan(ids.indexOf(concluido.id)));
    await fechar(tester);
    debugDefaultTargetPlatformOverride = null;
  });
}
