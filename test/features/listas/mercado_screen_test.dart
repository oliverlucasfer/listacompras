import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/l10n/app_strings.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/auth/providers/auth_providers.dart';
import 'package:lista_compras/features/listas/data/listas_repository.dart';
import 'package:lista_compras/features/listas/providers/listas_providers.dart';
import 'package:lista_compras/features/listas/ui/mercado_screen.dart';
import 'package:lista_compras/features/sync/domain/sync_status.dart';
import 'package:lista_compras/features/sync/providers/sync_providers.dart';

void main() {
  late AppDatabase db;
  late ListasRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ListasRepository(db);
  });

  tearDown(() async => db.close());

  Future<void> abrir(WidgetTester tester, String listaId) async {
    final sync = StreamController<SyncStatus>();
    sync.add(const Sincronizado());
    addTearDown(sync.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          donoAtualIdProvider.overrideWithValue('user-a'),
          syncStatusProvider.overrideWith((ref) => sync.stream),
        ],
        child: MaterialApp(home: MercadoScreen(listaId: listaId)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> fechar(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('deve_mostrar_somente_pendentes_quando_abre', (tester) async {
    final lista = await repo.criarLista(titulo: 'Compras', donoId: 'user-a');
    await repo.adicionarItem(listaId: lista.id, nome: 'Arroz', quantidade: 1);
    final feijao = await repo.adicionarItem(
      listaId: lista.id,
      nome: 'Feijao',
      quantidade: 1,
    );
    await repo.editarItem(feijao.id, concluido: true);

    await abrir(tester, lista.id);

    expect(find.text('Arroz'), findsOneWidget);
    expect(find.text('Feijao'), findsOneWidget); // na faixa "Marcados"
    expect(find.text('0 de 2'), findsOneWidget);
    await fechar(tester);
  });

  testWidgets('deve_marcar_item_quando_toca_e_mover_para_faixa', (
    tester,
  ) async {
    final lista = await repo.criarLista(titulo: 'Compras', donoId: 'user-a');
    await repo.adicionarItem(listaId: lista.id, nome: 'Arroz', quantidade: 1);
    await abrir(tester, lista.id);
    await tester.tap(find.text('Arroz'));
    await tester.pumpAndSettle();
    expect(find.text('1 de 1'), findsOneWidget);
    final item = (await db.select(db.itemLocal).get()).single;
    expect(item.concluido, isTrue);
    await fechar(tester);
  });

  testWidgets('deve_mostrar_vazio_quando_tudo_comprado', (tester) async {
    final lista = await repo.criarLista(titulo: 'Compras', donoId: 'user-a');
    final item = await repo.adicionarItem(
      listaId: lista.id,
      nome: 'Arroz',
      quantidade: 1,
    );
    await repo.editarItem(item.id, concluido: true);
    await abrir(tester, lista.id);
    expect(find.text(AppStrings.mercadoTudoComprado), findsOneWidget);
    await fechar(tester);
  });

  testWidgets('nao_deve_estourar_em_escala_2x', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final lista = await repo.criarLista(titulo: 'Compras', donoId: 'user-a');
    await repo.adicionarItem(listaId: lista.id, nome: 'Arroz', quantidade: 1);
    await abrir(tester, lista.id);
    expect(tester.takeException(), isNull);
    await fechar(tester);
  });

  testWidgets('nao_deve_estourar_quando_faixa_abre_com_muitos_marcados', (
    tester,
  ) async {
    final lista = await repo.criarLista(titulo: 'Compras', donoId: 'user-a');
    for (var i = 0; i < 10; i++) {
      final item = await repo.adicionarItem(
        listaId: lista.id,
        nome: 'Item $i',
        quantidade: 1,
      );
      await repo.editarItem(item.id, concluido: true);
    }
    await repo.adicionarItem(
      listaId: lista.id,
      nome: 'Pendente',
      quantidade: 1,
    );
    await abrir(tester, lista.id);

    // Marcar o pendente abre a faixa com os 11 concluídos.
    await tester.tap(find.text('Pendente'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('${AppStrings.mercadoMarcados} (11)'), findsOneWidget);
    await fechar(tester);
  });

  testWidgets('deve_ignorar_marcado_remoto_quando_conta_progresso', (
    tester,
  ) async {
    final lista = await repo.criarLista(titulo: 'Compras', donoId: 'user-a');
    await repo.adicionarItem(listaId: lista.id, nome: 'Arroz', quantidade: 1);
    await abrir(tester, lista.id);

    await tester.tap(find.text('Arroz'));
    await tester.pumpAndSettle();
    expect(find.text('1 de 1'), findsOneWidget);

    // Sync remoto desmarca por baixo (LWW): o stream atualiza e o contador
    // precisa reconciliar — o id não está mais concluído.
    final item = (await db.select(db.itemLocal).get()).single;
    await repo.editarItem(item.id, concluido: false);
    await tester.pumpAndSettle();

    expect(find.text('0 de 1'), findsOneWidget);
    await fechar(tester);
  });

  testWidgets('deve_desmarcar_item_quando_toca_na_faixa_aberta', (
    tester,
  ) async {
    final lista = await repo.criarLista(titulo: 'Compras', donoId: 'user-a');
    await repo.adicionarItem(listaId: lista.id, nome: 'Arroz', quantidade: 1);
    await abrir(tester, lista.id);

    await tester.tap(find.text('Arroz'));
    await tester.pumpAndSettle();
    expect(find.text('1 de 1'), findsOneWidget);
    expect(find.text('${AppStrings.mercadoMarcados} (1)'), findsOneWidget);

    // A faixa abriu sozinha; tocar no item marcado o devolve aos pendentes.
    await tester.tap(find.text('Arroz'));
    await tester.pumpAndSettle();

    expect(find.text('0 de 1'), findsOneWidget);
    expect(find.text(AppStrings.mercadoMarcados), findsNothing);
    expect(find.text('Arroz'), findsOneWidget);
    await fechar(tester);
  });

  testWidgets('deve_mostrar_total_quando_ha_marcado_com_preco', (tester) async {
    final lista = await repo.criarLista(titulo: 'Compras', donoId: 'user-a');
    final item = await repo.adicionarItem(
      listaId: lista.id,
      nome: 'Arroz',
      quantidade: 1,
      precoCentavos: 549,
    );
    await repo.editarItem(item.id, concluido: true);

    await abrir(tester, lista.id);

    expect(find.textContaining(r'R$ 5,49'), findsOneWidget);
    await fechar(tester);
  });

  testWidgets('deve_mostrar_orcamento_quando_definido', (tester) async {
    final lista = await repo.criarLista(titulo: 'Compras', donoId: 'user-a');
    final item = await repo.adicionarItem(
      listaId: lista.id,
      nome: 'Arroz',
      quantidade: 1,
      precoCentavos: 549,
    );
    await repo.editarItem(item.id, concluido: true);
    await repo.definirOrcamento(lista.id, centavos: 1000);

    await abrir(tester, lista.id);

    expect(find.textContaining(r'de R$ 10,00'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await fechar(tester);
  });
}
