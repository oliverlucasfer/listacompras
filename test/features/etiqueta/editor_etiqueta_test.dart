import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/dominio/unidade.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/listas/data/listas_repository.dart';
import 'package:lista_compras/features/listas/providers/listas_providers.dart';
import 'package:lista_compras/features/listas/ui/tela_lista_screen.dart';
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

class _OcrQueFalha implements OcrTexto {
  @override
  Future<String> extrair(String caminho) async =>
      throw StateError('ocr indisponível');
  @override
  void close() {}
}

class _FonteFake implements FonteImagem {
  @override
  Future<String?> daCamera() async => '/tmp/a.jpg';
  @override
  Future<String?> daGaleria() async => '/tmp/a.jpg';
}

/// Cria lista + item e abre o editor tocando no item.
Future<void> _abrirEditor(
  WidgetTester tester,
  AppDatabase db, {
  required String nomeItem,
  required OcrTexto ocr,
}) async {
  final repo = ListasRepository(db);
  final lista = await repo.criarLista(titulo: 'Compras', donoId: 'local');
  await repo.itens.adicionarItem(listaId: lista.id, nome: nomeItem);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        ocrTextoProvider.overrideWithValue(ocr),
        fonteImagemProvider.overrideWithValue(_FonteFake()),
      ],
      child: appTeste(TelaListaScreen(listaId: lista.id)),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(nomeItem));
  await tester.pumpAndSettle();
}

/// Lê a etiqueta pelo ícone de câmera do editor.
Future<void> _lerEtiqueta(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.photo_camera_outlined));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Tirar foto'));
  await tester.pumpAndSettle();
}

/// Desmonta a árvore e drena os timers de encerramento do Drift antes do gate
/// de "Timers still pending" do flutter_test (padrão da suíte).
Future<void> _fechar(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
}

void main() {
  testWidgets('deve_preencher_preco_quando_le_etiqueta_no_editor', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await _abrirEditor(
      tester,
      db,
      nomeItem: 'Arroz',
      ocr: _OcrFake('Arroz\nR\$ 5,49'),
    );
    await _lerEtiqueta(tester);

    expect(find.widgetWithText(TextField, '5,49'), findsOneWidget);
    await _fechar(tester);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('deve_manter_nome_quando_ja_preenchido_ao_ler_etiqueta', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await _abrirEditor(
      tester,
      db,
      nomeItem: 'Arroz',
      ocr: _OcrFake('Feijão\nR\$ 5,49'),
    );
    await _lerEtiqueta(tester);

    expect(find.widgetWithText(TextField, 'Arroz'), findsOneWidget);
    expect(find.text('Feijão'), findsNothing);
    expect(find.widgetWithText(TextField, '5,49'), findsOneWidget);
    await _fechar(tester);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('deve_ajustar_unidade_para_kg_no_fallback_por_kg', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await _abrirEditor(
      tester,
      db,
      nomeItem: 'Queijo',
      ocr: _OcrFake(r'R$ 12,90/kg'),
    );
    await _lerEtiqueta(tester);

    expect(find.widgetWithText(TextField, '12,90'), findsOneWidget);
    expect(
      find.widgetWithText(DropdownButtonFormField<Unidade>, 'kg'),
      findsOneWidget,
    );
    await _fechar(tester);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('deve_avisar_e_manter_campos_quando_ocr_sem_texto', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await _abrirEditor(tester, db, nomeItem: 'Arroz', ocr: _OcrFake(''));
    await tester.enterText(find.byType(TextField).last, '3,00');
    await tester.pump();
    await _lerEtiqueta(tester);

    expect(find.text('Nenhum texto reconhecido na foto.'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Arroz'), findsOneWidget);
    expect(find.widgetWithText(TextField, '3,00'), findsOneWidget);
    await _fechar(tester);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('deve_avisar_e_manter_campos_quando_ocr_falha', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await _abrirEditor(tester, db, nomeItem: 'Arroz', ocr: _OcrQueFalha());
    await tester.enterText(find.byType(TextField).last, '3,00');
    await tester.pump();
    await _lerEtiqueta(tester);

    expect(find.text('Não foi possível ler a foto.'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Arroz'), findsOneWidget);
    expect(find.widgetWithText(TextField, '3,00'), findsOneWidget);
    await _fechar(tester);
    debugDefaultTargetPlatformOverride = null;
  });
}
