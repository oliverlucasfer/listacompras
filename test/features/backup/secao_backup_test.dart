import 'dart:convert';

import 'package:drift/native.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/l10n/app_strings.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/backup/data/backup_repository.dart';
import 'package:lista_compras/features/backup/providers/backup_providers.dart';
import 'package:lista_compras/features/backup/ui/secao_backup.dart';
import 'package:lista_compras/features/listas/providers/listas_providers.dart';

class _BackupRepositoryFake implements BackupRepository {
  bool exportou = false;
  bool importou = false;
  String? conteudoImportado;
  Object? erroImportacao;

  @override
  final bool donoLocal = true;

  @override
  Future<String> exportarJson() async {
    exportou = true;
    return '{"versao":1,"listas":[],"itens":[],"historicoPrecos":[]}';
  }

  @override
  Future<void> importarJson(String conteudo) async {
    if (erroImportacao != null) throw erroImportacao!;
    importou = true;
    conteudoImportado = conteudo;
  }
}

XFile _arquivoJson(String conteudo) => XFile.fromData(
  utf8.encode(conteudo),
  name: 'backup.json',
  mimeType: 'application/json',
);

void main() {
  testWidgets('deve_mostrar_exportar_e_importar_quando_secao_backup', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: Scaffold(body: SecaoBackup())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.backupExportar), findsOneWidget);
    expect(find.text(AppStrings.backupImportar), findsOneWidget);
  });

  testWidgets('deve_exportar_quando_toca_em_exportar_backup', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final fake = _BackupRepositoryFake();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          backupRepositoryProvider.overrideWithValue(fake),
        ],
        child: const MaterialApp(home: Scaffold(body: SecaoBackup())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppStrings.backupExportar));
    await tester.pump();

    expect(fake.exportou, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('deve_cancelar_quando_arquivo_nulo', () async {
    final fake = _BackupRepositoryFake();

    final resultado = await importarArquivoBackup(null, fake);

    expect(resultado, ResultadoImportacaoBackup.cancelado);
    expect(fake.importou, isFalse);
  });

  test('deve_importar_quando_arquivo_valido', () async {
    final fake = _BackupRepositoryFake();

    final resultado = await importarArquivoBackup(
      _arquivoJson('{"versao":1}'),
      fake,
    );

    expect(resultado, ResultadoImportacaoBackup.importado);
    expect(fake.importou, isTrue);
    expect(fake.conteudoImportado, '{"versao":1}');
  });

  test('deve_retornar_invalido_quando_backup_invalido', () async {
    final fake = _BackupRepositoryFake()
      ..erroImportacao = const BackupInvalidoException('versao');

    final resultado = await importarArquivoBackup(_arquivoJson('{}'), fake);

    expect(resultado, ResultadoImportacaoBackup.invalido);
  });

  test('deve_retornar_leitura_erro_quando_erro_inesperado', () async {
    final fake = _BackupRepositoryFake()..erroImportacao = StateError('boom');

    final resultado = await importarArquivoBackup(_arquivoJson('{}'), fake);

    expect(resultado, ResultadoImportacaoBackup.leituraErro);
  });

  test('deve_retornar_leitura_erro_quando_falha_leitura', () async {
    final fake = _BackupRepositoryFake();

    final resultado = await importarArquivoBackup(
      XFile(r'Z:\caminho\inexistente\backup.json'),
      fake,
    );

    expect(resultado, ResultadoImportacaoBackup.leituraErro);
    expect(fake.importou, isFalse);
  });
}
