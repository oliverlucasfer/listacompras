import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
  @override
  Future<String?> daCamera() async => '/tmp/a.jpg';
  @override
  Future<String?> daGaleria() async => '/tmp/a.jpg';
}

void main() {
  // Fecha a árvore e deixa o Drift executar seus timers de fechamento de stream
  // antes do fim do corpo do teste (padrão de mercado_screen_test.dart).
  Future<void> fechar(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('deve_criar_item_com_preco_quando_le_etiqueta', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = ListasRepository(db);
    final lista = await repo.criarLista(titulo: 'Compras', donoId: 'local');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          ocrTextoProvider.overrideWithValue(_OcrFake('Arroz\nR\$ 5,49')),
          fonteImagemProvider.overrideWithValue(_FonteFake()),
        ],
        child: appTeste(MercadoScreen(listaId: lista.id)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.photo_camera_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tirar foto'));
    await tester.pumpAndSettle();

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

    await tester.tap(find.byIcon(Icons.photo_camera_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tirar foto'));
    await tester.pumpAndSettle();

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
    final lista = await repo.criarLista(titulo: 'Compras', donoId: 'local');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          ocrTextoProvider.overrideWithValue(_OcrFake('Oferta da semana')),
          fonteImagemProvider.overrideWithValue(_FonteFake()),
        ],
        child: appTeste(MercadoScreen(listaId: lista.id)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.photo_camera_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tirar foto'));
    await tester.pumpAndSettle();

    expect(find.text('Não reconheci um preço na etiqueta.'), findsOneWidget);
    await fechar(tester);
    debugDefaultTargetPlatformOverride = null;
  });
}
