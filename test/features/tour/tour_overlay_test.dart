import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/l10n/app_strings.dart';
import 'package:lista_compras/core/theme/app_theme.dart';
import 'package:lista_compras/features/tour/tour_controller.dart';
import 'package:lista_compras/features/tour/tour_keys.dart';
import 'package:lista_compras/features/tour/ui/tour_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';

late ProviderContainer _container;

/// Monta dois alvos elegíveis (passos 1 e 2 da etapa 1) e o overlay por cima,
/// então inicia a etapa 1 — a fila fica com exatamente esses dois passos.
Future<void> _montar(WidgetTester tester) async {
  _container = ProviderContainer();
  addTearDown(_container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: _container,
      child: MaterialApp(
        theme: AppTheme.claro,
        home: Scaffold(
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
                child: SizedBox(
                  key: TourKeys.nomeLista,
                  width: 120,
                  height: 48,
                ),
              ),
              const Positioned.fill(child: TourOverlay()),
            ],
          ),
        ),
      ),
    ),
  );
  _container.read(tourControllerProvider.notifier).iniciar(TourEtapa.primeira);
  await tester.pump();
}

Future<void> _avancarParaUltimo(WidgetTester tester) async {
  await tester.tap(find.text(AppStrings.tourProximo));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('deve_mostrar_bolha_e_avancar_quando_proximo', (tester) async {
    await _montar(tester);

    expect(find.text(AppStrings.tourNovaListaTitulo), findsOneWidget);
    expect(find.text(AppStrings.tourPular), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
    expect(find.text(AppStrings.tourConcluir), findsNothing);

    await _avancarParaUltimo(tester);

    expect(find.text(AppStrings.tourNomeTitulo), findsOneWidget);
    expect(find.text('2/2'), findsOneWidget);
    expect(find.text(AppStrings.tourConcluir), findsOneWidget);
    expect(find.text(AppStrings.tourProximo), findsNothing);
    expect(find.text(AppStrings.tourNovaListaTitulo), findsNothing);
  });

  testWidgets('deve_desabilitar_anterior_no_primeiro_passo', (tester) async {
    await _montar(tester);

    final anterior = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, AppStrings.tourAnterior),
    );
    expect(anterior.onPressed, isNull);

    await _avancarParaUltimo(tester);

    final anteriorDepois = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, AppStrings.tourAnterior),
    );
    expect(anteriorDepois.onPressed, isNotNull);
  });

  testWidgets('deve_encerrar_e_marcar_etapa_vista_quando_concluir', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await _montar(tester);
    await _avancarParaUltimo(tester);

    await tester.tap(find.text(AppStrings.tourConcluir));
    await tester.pumpAndSettle();

    expect(_container.read(tourControllerProvider).ativo, isFalse);
    expect(find.text(AppStrings.tourNomeTitulo), findsNothing);
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

    await tester.tap(find.text(AppStrings.tourPular));
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

    final rotulo = AppStrings.tourPasso(1, 2);
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
    expect(find.text(AppStrings.tourNovaListaTitulo), findsOneWidget);
  });

  testWidgets('deve_nao_renderizar_quando_inativo', (tester) async {
    await _montar(tester);

    _container.read(tourControllerProvider.notifier).pular();
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.tourNovaListaTitulo), findsNothing);
    expect(find.text(AppStrings.tourPular), findsNothing);
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
    expect(find.text(AppStrings.tourNovaListaTitulo), findsOneWidget);
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
    expect(find.text(AppStrings.tourNovaListaTitulo), findsOneWidget);
  });
}
