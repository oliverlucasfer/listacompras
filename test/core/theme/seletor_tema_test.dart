import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/l10n/app_strings.dart';
import 'package:lista_compras/core/theme/seletor_tema.dart';
import 'package:lista_compras/core/theme/theme_mode_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('deve_definir_modo_escuro_quando_tocar_em_escuro', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: SeletorTema())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppStrings.temaEscuro));
    await tester.pumpAndSettle();

    expect(container.read(temaModoProvider).value, ThemeMode.dark);
  });

  test('deve_usar_segmentado_quando_largura_e_escala_confortaveis', () {
    expect(usarSeletorSegmentado(largura: 400, escalaTexto: 1.0), isTrue);
    expect(usarSeletorSegmentado(largura: 360, escalaTexto: 1.2), isTrue);
  });

  test('deve_usar_dropdown_quando_largura_estreita', () {
    // R-20: em ~360dp (e menos) o SegmentedButton com ícone+rótulo estoura.
    expect(usarSeletorSegmentado(largura: 320, escalaTexto: 1.0), isFalse);
    expect(usarSeletorSegmentado(largura: 359, escalaTexto: 1.0), isFalse);
  });

  test('deve_usar_dropdown_quando_escala_de_texto_grande', () {
    // Fonte ampliada encolhe o espaço útil mesmo numa tela larga.
    expect(usarSeletorSegmentado(largura: 400, escalaTexto: 1.5), isFalse);
    expect(usarSeletorSegmentado(largura: 400, escalaTexto: 2.0), isFalse);
  });

  testWidgets('deve_trocar_para_dropdown_e_nao_estourar_quando_estreito', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: SeletorTema())),
      ),
    );
    // Largura estreita (~320dp) e fonte dobrada: o cenário que estourava.
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(DropdownButtonFormField<ThemeMode>), findsOneWidget);

    // O dropdown também muda o tema.
    await tester.tap(find.byType(DropdownButtonFormField<ThemeMode>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.temaEscuro).last);
    await tester.pumpAndSettle();
    expect(container.read(temaModoProvider).value, ThemeMode.dark);
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
        child: MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: const SeletorTema(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(DropdownButtonFormField<ThemeMode>), findsOneWidget);
  });
}
