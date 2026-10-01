import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/importacao/resposta_import.dart';
import 'package:lista_compras/core/l10n/app_strings.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/importacao/ui/modal_importar.dart';
import 'package:lista_compras/features/listas/providers/listas_providers.dart';
import 'package:lista_compras/features/ocr/domain/fonte_imagem.dart';
import 'package:lista_compras/features/ocr/domain/ocr_texto.dart';
import 'package:lista_compras/features/ocr/providers/ocr_providers.dart';

class _OcrFake implements OcrTexto {
  _OcrFake(this._texto);
  final String _texto;
  @override
  Future<String> extrair(String caminho) async => _texto;
}

class _OcrQueFalha implements OcrTexto {
  @override
  Future<String> extrair(String caminho) async =>
      throw StateError('ocr indisponível');
}

class _FonteFake implements FonteImagem {
  _FonteFake({this.caminho});
  final String? caminho;
  @override
  Future<String?> daCamera() async => caminho;
  @override
  Future<String?> daGaleria() async => caminho;
}

Widget _app(
  AppDatabase db, {
  required String texto,
  String? caminho,
  OcrTexto? ocr,
  ValueChanged<RespostaParse?>? onResultado,
}) {
  return ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      ocrTextoProvider.overrideWithValue(ocr ?? _OcrFake(texto)),
      fonteImagemProvider.overrideWithValue(_FonteFake(caminho: caminho)),
    ],
    child: MaterialApp(
      home: Scaffold(body: _Abrir(onResultado: onResultado)),
    ),
  );
}

class _Abrir extends ConsumerWidget {
  const _Abrir({this.onResultado});
  final ValueChanged<RespostaParse?>? onResultado;

  @override
  Widget build(BuildContext context, WidgetRef ref) => TextButton(
    onPressed: () async {
      final resposta = await abrirModalImportar(context, ref, 'l');
      onResultado?.call(resposta);
    },
    child: const Text('abrir'),
  );
}

void main() {
  testWidgets('deve_mostrar_botao_foto_quando_ha_ocr', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(_app(db, texto: 'Arroz 2kg'));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.text('Foto'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('deve_preencher_campo_quando_le_a_foto', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(
      _app(db, texto: 'Arroz 2kg', caminho: '/tmp/a.jpg'),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Foto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tirar foto'));
    await tester.pumpAndSettle();
    expect(find.text('Arroz 2kg'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('deve_avisar_quando_ocr_sem_texto', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(_app(db, texto: '', caminho: '/tmp/a.jpg'));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Foto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tirar foto'));
    await tester.pumpAndSettle();
    expect(find.text('Nenhum texto reconhecido na foto.'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('deve_preencher_campo_quando_escolhe_da_galeria', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(
      _app(db, texto: 'Feijão 1kg', caminho: '/tmp/b.jpg'),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Foto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Escolher da galeria'));
    await tester.pumpAndSettle();
    expect(find.text('Feijão 1kg'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('deve_exibir_banner_quando_ocr_falha', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(
      _app(db, texto: '', caminho: '/tmp/a.jpg', ocr: _OcrQueFalha()),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Foto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tirar foto'));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.ocrFalha), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('deve_manter_campo_quando_cancela_a_captura', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(_app(db, texto: 'Arroz 2kg'));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'arroz');
    await tester.pump();
    await tester.tap(find.text('Foto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tirar foto'));
    await tester.pumpAndSettle();
    expect(find.text('arroz'), findsOneWidget);
    expect(find.text(AppStrings.ocrNenhumTexto), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('deve_extrair_itens_do_texto_lido_quando_extrair', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    RespostaParse? recebida;
    await tester.pumpWidget(
      _app(
        db,
        texto: '1kg de arroz',
        caminho: '/tmp/a.jpg',
        onResultado: (r) => recebida = r,
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Foto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tirar foto'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FilledButton, AppStrings.importExtrairItens),
    );
    await tester.pumpAndSettle();
    expect(recebida, isNotNull);
    expect(recebida!.itens, hasLength(1));
    expect(recebida!.itens.single.nome, 'Arroz');
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('deve_ocultar_botao_foto_quando_sem_ocr', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(_app(db, texto: 'Arroz 2kg'));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.text('Foto'), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });
}
