import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/l10n/app_strings.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/compartilhamento/domain/lista_compartilhada.dart';
import 'package:lista_compras/features/compartilhamento/ui/sheet_compartilhar.dart';
import 'package:lista_compras/features/listas/data/listas_repository.dart';
import 'package:lista_compras/features/listas/providers/listas_providers.dart';
import 'package:qr_flutter/qr_flutter.dart';

Future<void> _bombearEAbrir(
  WidgetTester tester,
  AppDatabase db,
  String listaId,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () => abrirSheetCompartilhar(context, ref, listaId),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('deve_mostrar_as_tres_opcoes_quando_abre', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final lista = await ListasRepository(
      db,
    ).criarLista(titulo: 'X', donoId: 'local');

    await _bombearEAbrir(tester, db, lista.id);

    expect(find.text('Enviar como texto'), findsOneWidget);
    expect(find.text('Enviar arquivo'), findsOneWidget);
    expect(find.text('QR code'), findsOneWidget);
  });

  testWidgets('deve_avisar_e_nao_gerar_qr_quando_lista_grande', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = ListasRepository(db);
    final lista = await repo.criarLista(titulo: 'Grande', donoId: 'local');
    for (var i = 0; i < 60; i++) {
      await repo.adicionarItem(listaId: lista.id, nome: 'Item numero $i');
    }

    await _bombearEAbrir(tester, db, lista.id);

    await tester.tap(find.text('QR code'));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.compartilharQrGrande), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
  });

  testWidgets('deve_gerar_qr_e_copiar_codigo_quando_toca', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final lista = await ListasRepository(
      db,
    ).criarLista(titulo: 'X', donoId: 'local');

    final chamadas = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        chamadas.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await _bombearEAbrir(tester, db, lista.id);

    await tester.tap(find.text('QR code'));
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsOneWidget);

    await tester.tap(find.text(AppStrings.copiarCodigo));
    await tester.pumpAndSettle();

    final copia = chamadas.singleWhere((c) => c.method == 'Clipboard.setData');
    final texto = (copia.arguments as Map)['text'] as String;
    expect(texto, startsWith(ListaCompartilhada.prefixo));
    expect(find.text(AppStrings.codigoCopiado), findsOneWidget);
  });
}
