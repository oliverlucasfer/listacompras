import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/theme/app_theme.dart';
import 'package:lista_compras/features/tour/tour_controller.dart';
import 'package:lista_compras/features/tour/tour_keys.dart';
import 'package:lista_compras/features/tour/ui/tour_overlay.dart';
import 'package:lista_compras/l10n/app_localizations_pt.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/app_teste.dart';

late ProviderContainer _container;

/// Monta dois alvos elegíveis (passos 1 e 2 da etapa 1) e o overlay por cima,
/// então inicia a etapa 1 — a fila fica com exatamente esses dois passos.
Future<void> _montar(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  _container = ProviderContainer();
  addTearDown(_container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: _container,
      child: appTeste(
        Scaffold(
          body: Stack(
            children: [
              Positioned(
                left: 24,
                top: 48,
                child: SizedBox(
                  key: TourKeys.novaLista,
                  width: 120,
                  height: 48,
                ),
              ),
              Positioned(
                left: 24,
                top: 200,
                child: SizedBox(key: TourKeys.lupa, width: 120, height: 48),
              ),
              const Positioned.fill(child: TourOverlay()),
            ],
          ),
        ),
        theme: AppTheme.claro,
      ),
    ),
  );
  _container.read(tourControllerProvider.notifier).iniciar(TourEtapa.primeira);
  await tester.pump();
}

Future<void> _avancarParaUltimo(WidgetTester tester) async {
  await tester.tap(find.text('Próximo'));
  await tester.pumpAndSettle();
}

/// Monta apenas os [alvos] indicados (cada um visível) e o overlay por cima,
/// sem iniciar nenhuma etapa — cada teste escolhe qual etapa iniciar.
Future<void> _montarAlvos(WidgetTester tester, List<GlobalKey> alvos) async {
  SharedPreferences.setMockInitialValues({});
  _container = ProviderContainer();
  addTearDown(_container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: _container,
      child: appTeste(
        Scaffold(
          body: Stack(
            children: [
              for (var i = 0; i < alvos.length; i++)
                Positioned(
                  left: 24,
                  top: 48 + i * 80,
                  child: SizedBox(key: alvos[i], width: 120, height: 48),
                ),
              const Positioned.fill(child: TourOverlay()),
            ],
          ),
        ),
        theme: AppTheme.claro,
      ),
    ),
  );
}

void main() {
  testWidgets('deve_mostrar_bolha_e_avancar_quando_proximo', (tester) async {
    await _montar(tester);

    expect(find.text('Criar sua primeira lista'), findsOneWidget);
    expect(find.text('Pular'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
    expect(find.text('Concluir'), findsNothing);

    await _avancarParaUltimo(tester);

    expect(find.text('Busca e filtros'), findsOneWidget);
    expect(find.text('2/2'), findsOneWidget);
    expect(find.text('Concluir'), findsOneWidget);
    expect(find.text('Próximo'), findsNothing);
    expect(find.text('Criar sua primeira lista'), findsNothing);
  });

  testWidgets('deve_desabilitar_anterior_no_primeiro_passo', (tester) async {
    await _montar(tester);

    final anterior = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Anterior'),
    );
    expect(anterior.onPressed, isNull);

    await _avancarParaUltimo(tester);

    final anteriorDepois = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Anterior'),
    );
    expect(anteriorDepois.onPressed, isNotNull);
  });

  testWidgets('deve_encerrar_e_marcar_etapa_vista_quando_concluir', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await _montar(tester);
    await _avancarParaUltimo(tester);

    await tester.tap(find.text('Concluir'));
    await tester.pumpAndSettle();

    expect(_container.read(tourControllerProvider).ativo, isFalse);
    expect(find.text('Busca e filtros'), findsNothing);
    expect(
      await _container.read(tourEtapaVistaProvider(TourEtapa.primeira).future),
      isTrue,
    );
  });

  testWidgets('deve_encerrar_e_marcar_etapa_vista_quando_pular', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await _montar(tester);

    await tester.tap(find.text('Pular'));
    await tester.pumpAndSettle();

    expect(_container.read(tourControllerProvider).ativo, isFalse);
    expect(
      await _container.read(tourEtapaVistaProvider(TourEtapa.primeira).future),
      isTrue,
    );
  });

  testWidgets('deve_anunciar_passo_como_live_region', (tester) async {
    final handle = tester.ensureSemantics();
    await _montar(tester);

    final rotulo = 'Passo 1 de 2';
    expect(find.bySemanticsLabel(rotulo), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel(rotulo)),
      matchesSemantics(label: rotulo, isLiveRegion: true),
    );

    handle.dispose();
  });

  testWidgets('deve_nao_avancar_quando_tocar_fora_dos_botoes', (tester) async {
    await _montar(tester);

    await tester.tapAt(const Offset(200, 600));
    await tester.pump();

    expect(_container.read(tourControllerProvider).indice, 0);
    expect(find.text('Criar sua primeira lista'), findsOneWidget);
  });

  testWidgets('deve_nao_renderizar_quando_inativo', (tester) async {
    await _montar(tester);

    await _container.read(tourControllerProvider.notifier).pular();
    await tester.pumpAndSettle();

    expect(find.text('Criar sua primeira lista'), findsNothing);
    expect(find.text('Pular'), findsNothing);
  });

  testWidgets('deve_nao_estourar_com_escala_2x_e_manter_alvos_acessiveis', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final handle = tester.ensureSemantics();
    await _montar(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Criar sua primeira lista'), findsOneWidget);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

    handle.dispose();
  });

  testWidgets('deve_entrar_sem_transicao_quando_movimento_reduzido', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await _montar(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Criar sua primeira lista'), findsOneWidget);
  });

  testWidgets('deve_manter_etapa_ativa_quando_outra_etapa_tenta_iniciar', (
    tester,
  ) async {
    await _montarAlvos(tester, [TourKeys.novaLista, TourKeys.resumoHistorico]);

    final controlador = _container.read(tourControllerProvider.notifier);
    expect(controlador.iniciar(TourEtapa.primeira), isTrue);
    await tester.pump();

    expect(controlador.iniciar(TourEtapa.historico), isFalse);
    await tester.pump();

    final estado = _container.read(tourControllerProvider);
    expect(estado.ativo, isTrue);
    expect(estado.etapa, TourEtapa.primeira);
    expect(estado.passos.single.id, 'lista.criar');
  });

  testWidgets('deve_mostrar_texto_do_menu_quando_passo_menu', (tester) async {
    await _montarAlvos(tester, [TourKeys.menuMais]);

    final controlador = _container.read(tourControllerProvider.notifier);
    expect(controlador.iniciar(TourEtapa.recursos), isTrue);
    await tester.pumpAndSettle();

    final pt = AppLocalizationsPt();
    expect(find.text(pt.tourMenuTitulo), findsOneWidget);
    expect(find.text(pt.tourMenuCorpo), findsOneWidget);
    expect(pt.tourMenuCorpo.contains('compartilhar'), isTrue);
    expect(pt.tourMenuCorpo.contains('finalizar'), isTrue);
  });

  testWidgets('deve_nao_estourar_com_escala_2x_nas_novas_strings', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await _montarAlvos(tester, [
      TourKeys.menuMais,
      TourKeys.resumoHistorico,
      TourKeys.abaEstatisticas,
    ]);

    final controlador = _container.read(tourControllerProvider.notifier);
    final pt = AppLocalizationsPt();

    expect(controlador.iniciar(TourEtapa.recursos), isTrue);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text(pt.tourMenuTitulo), findsOneWidget);

    await controlador.pular();
    await tester.pumpAndSettle();

    expect(controlador.iniciar(TourEtapa.historico), isTrue);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text(pt.tourResumoTitulo), findsOneWidget);

    await controlador.proximo();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text(pt.tourEstatisticasTitulo), findsOneWidget);
  });
}
