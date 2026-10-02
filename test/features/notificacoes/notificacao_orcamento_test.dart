import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/listas/data/listas_repository.dart';
import 'package:lista_compras/features/listas/domain/preco.dart';
import 'package:lista_compras/features/listas/providers/listas_providers.dart';
import 'package:lista_compras/features/listas/ui/tela_lista_screen.dart';
import 'package:lista_compras/features/notificacoes/domain/notificacao_local.dart';
import 'package:lista_compras/features/notificacoes/providers/notificacao_providers.dart';

import '../../support/app_teste.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Notificação local ao cruzar o orçamento (RF-36, F53-T05). O plugin real
/// nunca é tocado: o provider é sobrescrito por um fake que registra chamadas.
class FakeNotificacaoLocal implements NotificacaoLocal {
  int chamadas = 0;
  String? titulo;
  String? corpo;

  @override
  Future<bool> pedirPermissao() async => true;

  @override
  Future<void> mostrar({required String titulo, required String corpo}) async {
    chamadas++;
    this.titulo = titulo;
    this.corpo = corpo;
  }
}

void main() {
  late AppDatabase db;
  late ListasRepository repo;
  late FakeNotificacaoLocal notificacao;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ListasRepository(db);
    notificacao = FakeNotificacaoLocal();
    SharedPreferences.setMockInitialValues({'onboarding_visto': true});
  });

  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    await db.close();
  });

  /// Cria a lista com um item por preço (centavos), define o orçamento e abre a
  /// tela da lista com o fake de notificação injetado; devolve o id da lista.
  Future<String> abrirComItens(
    WidgetTester tester, {
    required List<int> precos,
    required int orcamentoCentavos,
  }) async {
    final lista = await repo.criarLista(titulo: 'Compras', donoId: 'local');
    for (var i = 0; i < precos.length; i++) {
      await repo.adicionarItem(
        listaId: lista.id,
        nome: 'Item ${i + 1}',
        precoCentavos: precos[i],
      );
    }
    await repo.definirOrcamento(lista.id, centavos: orcamentoCentavos);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          notificacaoLocalProvider.overrideWithValue(notificacao),
        ],
        child: appTeste(TelaListaScreen(listaId: lista.id)),
      ),
    );
    await tester.pumpAndSettle();
    return lista.id;
  }

  Future<void> fechar(WidgetTester tester) async {
    debugDefaultTargetPlatformOverride = null;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('deve_notificar_uma_vez_quando_marcar_cruza_o_orcamento', (
    tester,
  ) async {
    await abrirComItens(tester, precos: [600, 600], orcamentoCentavos: 1000);

    // 1º item: R$ 6,00 de R$ 10,00 — ainda não cruzou.
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(notificacao.chamadas, 0);

    // 2º item: total R$ 12,00 — cruzou o orçamento.
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(notificacao.chamadas, 1);
    expect(notificacao.titulo, 'Orçamento');
    expect(
      notificacao.corpo,
      'Você passou do orçamento: ${formatarReais(1200)}',
    );

    await fechar(tester);
  });

  testWidgets('deve_nao_notificar_quando_nao_cruza_o_orcamento', (
    tester,
  ) async {
    await abrirComItens(tester, precos: [600], orcamentoCentavos: 1000);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();

    expect(notificacao.chamadas, 0);

    await fechar(tester);
  });

  test('deve_retornar_true_quando_android', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    expect(plataformaComNotificacao(), isTrue);
  });

  test('deve_retornar_true_quando_ios', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    expect(plataformaComNotificacao(), isTrue);
  });

  test('deve_retornar_false_quando_desktop', () {
    for (final plataforma in [
      TargetPlatform.linux,
      TargetPlatform.windows,
      TargetPlatform.macOS,
    ]) {
      debugDefaultTargetPlatformOverride = plataforma;

      expect(plataformaComNotificacao(), isFalse, reason: '$plataforma');
    }
  });
}
