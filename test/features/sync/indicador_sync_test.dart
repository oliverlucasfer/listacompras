import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/l10n/app_strings.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/sync/data/mutacao_sync.dart';
import 'package:lista_compras/features/sync/data/sync_engine.dart';
import 'package:lista_compras/features/sync/data/sync_remoto.dart';
import 'package:lista_compras/features/sync/domain/sync_status.dart';
import 'package:lista_compras/features/sync/providers/sync_providers.dart';
import 'package:lista_compras/features/sync/ui/indicador_sync.dart';

class RemotoNulo implements SyncRemoto {
  @override
  Future<ResultadoEnvio> enviar(MutacaoSync mutacao) async => const Enviado();
}

class EngineFake extends SyncEngine {
  EngineFake(AppDatabase db)
    : super(db: db, remoto: RemotoNulo(), checarConexao: () async => true);

  var reiniciou = false;

  @override
  Future<void> reiniciarTentativas() async => reiniciou = true;
}

void main() {
  late AppDatabase db;
  late StreamController<SyncStatus> controller;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    controller = StreamController<SyncStatus>();
  });

  tearDown(() async {
    await controller.close();
    await db.close();
  });

  Future<void> pump(WidgetTester tester, {EngineFake? engine}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          syncStatusProvider.overrideWith((ref) => controller.stream),
          if (engine != null) syncEngineProvider.overrideWithValue(engine),
        ],
        child: const MaterialApp(home: Scaffold(body: IndicadorSync())),
      ),
    );
    await tester.pump();
  }

  testWidgets('deve_exibir_check_quando_sincronizado', (tester) async {
    controller.add(const Sincronizado());
    await pump(tester);

    expect(find.text(AppStrings.syncSincronizado), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('deve_exibir_spinner_quando_sincronizando', (tester) async {
    controller.add(const Sincronizando());
    await pump(tester);

    expect(find.text(AppStrings.syncSincronizando), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('deve_exibir_contagem_no_plural_quando_pendente', (tester) async {
    controller.add(const Pendente(3));
    await pump(tester);

    expect(find.text(AppStrings.syncPendentes(3)), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('deve_exibir_contagem_no_singular_quando_um_pendente', (
    tester,
  ) async {
    controller.add(const Pendente(1));
    await pump(tester);

    expect(find.text(AppStrings.syncPendentes(1)), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('deve_exibir_banner_offline_quando_perder_rede', (tester) async {
    controller.add(const Offline());
    await pump(tester);

    expect(find.text(AppStrings.syncSemConexao), findsOneWidget);
    expect(find.byIcon(Icons.cloud_off), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('deve_exibir_banner_com_tentar_novamente_quando_erro', (
    tester,
  ) async {
    final engine = EngineFake(db);
    controller.add(const ErroSync());
    await pump(tester, engine: engine);

    expect(find.text(AppStrings.syncErro), findsOneWidget);
    expect(find.text(AppStrings.tentarNovamente), findsOneWidget);

    await tester.tap(find.text(AppStrings.tentarNovamente));
    await tester.pump();

    expect(engine.reiniciou, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
