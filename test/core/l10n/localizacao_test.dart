import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('deve_declarar_flutter_localizations_quando_app_multilingue', () {
    expect(
      File('pubspec.yaml').readAsStringSync(),
      contains('flutter_localizations:'),
    );
  });

  test('deve_configurar_localizacoes_quando_app_inicia', () {
    final app = File('lib/app.dart').readAsStringSync();
    expect(app, contains('package:flutter_localizations/'));
    expect(app, contains('AppLocalizations.delegate'));
    expect(
      app,
      contains('supportedLocales: AppLocalizations.supportedLocales'),
    );
    expect(app, contains('locale: ref.watch(idiomaProvider).value?.locale'));
    expect(app, contains('localizationsDelegates: const ['));
    expect(app, contains('GlobalMaterialLocalizations.delegate'));
    expect(app, contains('GlobalWidgetsLocalizations.delegate'));
    expect(app, contains('GlobalCupertinoLocalizations.delegate'));
  });

  testWidgets('deve_localizar_material_em_pt_br_quando_configurado', (
    tester,
  ) async {
    late String tooltip;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Builder(
          builder: (context) {
            tooltip = MaterialLocalizations.of(context).backButtonTooltip;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(tooltip, 'Voltar');
  });
}
