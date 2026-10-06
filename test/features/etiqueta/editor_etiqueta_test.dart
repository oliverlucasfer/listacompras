import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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

class _FonteFake implements FonteImagem {
  @override
  Future<String?> daCamera() async => '/tmp/a.jpg';
  @override
  Future<String?> daGaleria() async => '/tmp/a.jpg';
}

void main() {
  testWidgets('deve_preencher_preco_quando_le_etiqueta_no_editor', (
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
          ocrTextoProvider.overrideWithValue(_OcrFake('Arroz\nR\$ 5,49')),
          fonteImagemProvider.overrideWithValue(_FonteFake()),
        ],
        child: appTeste(TelaListaScreen(listaId: lista.id)),
      ),
    );
    await tester.pumpAndSettle();

    // Abre o editor tocando no item.
    await tester.tap(find.text('Arroz'));
    await tester.pumpAndSettle();

    // A câmera ao lado do campo de preço lê a etiqueta e preenche.
    await tester.tap(find.byIcon(Icons.photo_camera_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tirar foto'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, '5,49'), findsOneWidget);

    // Desmonta a árvore e drena os timers de encerramento do Drift antes do
    // gate de "Timers still pending" do flutter_test (padrão da suíte).
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    debugDefaultTargetPlatformOverride = null;
  });
}
