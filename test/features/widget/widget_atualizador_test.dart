import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/config/usuario_local.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/listas/providers/listas_providers.dart';
import 'package:lista_compras/features/widget/domain/widget_service.dart';
import 'package:lista_compras/features/widget/providers/widget_providers.dart';
import 'package:lista_compras/features/widget/ui/widget_atualizador.dart';
import 'package:lista_compras/router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _WidgetFake implements WidgetService {
  _WidgetFake({this.inicial});

  final String? inicial;
  final chamadas = <WidgetDados>[];
  final _toques = StreamController<String>.broadcast();

  @override
  Future<void> atualizar(WidgetDados dados) async => chamadas.add(dados);

  @override
  Future<String?> toqueInicial() async => inicial;

  @override
  Stream<String> toques() => _toques.stream;

  void emitirToque(String valor) => _toques.add(valor);

  Future<void> fechar() => _toques.close();
}

class _Harness {
  _Harness(this.container, this.fake);
  final ProviderContainer container;
  final _WidgetFake fake;
}

Future<void> _semearLista(
  AppDatabase db, {
  required String listaId,
  required String titulo,
  int pendentes = 0,
  int concluidos = 0,
}) async {
  final agora = DateTime.utc(2026, 1, 1);
  await db
      .into(db.listaLocal)
      .insert(
        ListaLocalCompanion.insert(
          id: listaId,
          createdAt: agora,
          updatedAt: agora,
          titulo: titulo,
          donoId: idLocal,
        ),
      );
  var ordem = 0;
  for (var i = 0; i < pendentes + concluidos; i++) {
    await db
        .into(db.itemLocal)
        .insert(
          ItemLocalCompanion.insert(
            id: '$listaId-i$i',
            createdAt: agora,
            updatedAt: agora,
            listaId: listaId,
            nome: 'Item $i',
            concluido: Value(i >= pendentes),
            ordem: Value(ordem++),
          ),
        );
  }
}

Future<_Harness> _montar(
  WidgetTester tester, {
  String? ultimaListaId,
  String? toqueInicial,
  Future<void> Function(AppDatabase db)? seed,
}) async {
  SharedPreferences.setMockInitialValues({
    'onboarding_visto': true,
    'ultima_lista_id': ?ultimaListaId,
  });
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  if (seed != null) await seed(db);
  final fake = _WidgetFake(inicial: toqueInicial);
  addTearDown(fake.fechar);
  final container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      widgetServiceProvider.overrideWithValue(fake),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (context, ref, _) => MaterialApp.router(
          routerConfig: ref.watch(routerProvider),
          builder: (context, child) => Stack(
            children: [
              if (child != null) child else const SizedBox.shrink(),
              const WidgetAtualizador(),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return _Harness(container, fake);
}

/// Desmonta a árvore dentro do teste: cancela o debounce e consome o Timer(0)
/// que o dispose dos streams do Drift agenda.
Future<void> _fechar(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
}

String _rota(ProviderContainer container) =>
    container.read(routerProvider).routerDelegate.currentConfiguration.uri.path;

void main() {
  testWidgets('deve_enviar_titulo_e_pendentes_quando_houve_lista', (
    tester,
  ) async {
    final h = await _montar(
      tester,
      ultimaListaId: 'l1',
      seed: (db) => _semearLista(
        db,
        listaId: 'l1',
        titulo: 'Minha lista',
        pendentes: 2,
        concluidos: 1,
      ),
    );

    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(h.fake.chamadas, isNotEmpty);
    final dados = h.fake.chamadas.last;
    expect(dados.titulo, 'Minha lista');
    expect(dados.pendentes, 2);

    await _fechar(tester);
  });

  testWidgets('deve_enviar_sem_lista_quando_ultima_lista_inexistente', (
    tester,
  ) async {
    final h = await _montar(tester);

    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(h.fake.chamadas, isNotEmpty);
    final dados = h.fake.chamadas.last;
    expect(dados.titulo, isNull);
    expect(dados.pendentes, 0);

    await _fechar(tester);
  });

  testWidgets('deve_navegar_para_adicionar_quando_houve_toque', (tester) async {
    final h = await _montar(
      tester,
      ultimaListaId: 'l1',
      seed: (db) => _semearLista(db, listaId: 'l1', titulo: 'Minha lista'),
    );

    h.fake.emitirToque('adicionar');
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();

    expect(_rota(h.container), '/lista/l1');

    await _fechar(tester);
  });

  testWidgets('deve_navegar_para_adicionar_quando_toque_inicial', (
    tester,
  ) async {
    final h = await _montar(
      tester,
      ultimaListaId: 'l1',
      toqueInicial: 'adicionar',
      seed: (db) => _semearLista(db, listaId: 'l1', titulo: 'Minha lista'),
    );

    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();

    expect(_rota(h.container), '/lista/l1');

    await _fechar(tester);
  });
}
