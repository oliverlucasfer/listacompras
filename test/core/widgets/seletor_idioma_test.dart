import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/idioma/idioma_provider.dart';
import 'package:lista_compras/core/widgets/app_dropdown.dart';
import 'package:lista_compras/core/widgets/seletor_idioma.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/app_teste.dart';

void main() {
  test('deve_usar_segmentado_quando_largura_e_escala_confortaveis', () {
    expect(usarSeletorIdiomaSegmentado(largura: 520, escalaTexto: 1.0), isTrue);
    expect(usarSeletorIdiomaSegmentado(largura: 800, escalaTexto: 1.2), isTrue);
    expect(
      usarSeletorIdiomaSegmentado(largura: 1920, escalaTexto: 1.0),
      isTrue,
    );
  });

  test('deve_usar_dropdown_quando_largura_estreita', () {
    // R-20: os quatro segmentos não cabem em telas estreitas.
    expect(
      usarSeletorIdiomaSegmentado(largura: 519, escalaTexto: 1.0),
      isFalse,
    );
    expect(
      usarSeletorIdiomaSegmentado(largura: 360, escalaTexto: 1.0),
      isFalse,
    );
  });

  test('deve_usar_dropdown_quando_escala_de_texto_grande', () {
    // Fonte ampliada encolhe o espaço útil mesmo numa tela larga.
    expect(
      usarSeletorIdiomaSegmentado(largura: 800, escalaTexto: 1.3),
      isFalse,
    );
    expect(
      usarSeletorIdiomaSegmentado(largura: 800, escalaTexto: 2.0),
      isFalse,
    );
  });

  testWidgets('deve_exibir_quatro_idiomas_e_persistir_quando_seleciona', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: appTeste(const Scaffold(body: SeletorIdioma())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sistema'), findsOneWidget);
    expect(find.text('Português'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('Español'), findsOneWidget);

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(container.read(idiomaProvider).value, IdiomaApp.en);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('idioma_app'), 'en');
    expect(find.text('English'), findsOneWidget);
  });

  testWidgets('deve_trocar_para_dropdown_e_persistir_quando_estreito', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: appTeste(const Scaffold(body: SeletorIdioma())),
      ),
    );
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(AppDropdown<IdiomaApp>), findsOneWidget);

    await tester.tap(find.byType(AppDropdown<IdiomaApp>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Español').last);
    await tester.pumpAndSettle();

    expect(container.read(idiomaProvider).value, IdiomaApp.es);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('idioma_app'), 'es');
  });

  testWidgets('deve_trocar_para_dropdown_em_escala_2x_sem_estourar', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: appTeste(
          Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: const SeletorIdioma(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(AppDropdown<IdiomaApp>), findsOneWidget);
  });
}
