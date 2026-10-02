import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/idioma/idioma_provider.dart';
import 'package:lista_compras/core/l10n/l10n.dart';
import 'package:lista_compras/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('deve_retornar_sistema_quando_sem_preferencia', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(await container.read(idiomaProvider.future), IdiomaApp.sistema);
  });

  test('deve_ler_idioma_salvo_quando_existente', () async {
    SharedPreferences.setMockInitialValues({'idioma_app': 'en'});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(await container.read(idiomaProvider.future), IdiomaApp.en);
  });

  test('deve_persistir_idioma_escolhido_quando_selecionar', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(idiomaProvider.future);
    await container.read(idiomaProvider.notifier).selecionar(IdiomaApp.es);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('idioma_app'), 'es');
  });

  test('deve_mapear_strings_desconhecidas_para_sistema', () {
    expect(idiomaDeString(null), IdiomaApp.sistema);
    expect(idiomaDeString('qualquer'), IdiomaApp.sistema);
    expect(idiomaDeString('pt'), IdiomaApp.pt);
    expect(idiomaDeString('en'), IdiomaApp.en);
    expect(idiomaDeString('es'), IdiomaApp.es);
    expect(idiomaParaString(IdiomaApp.sistema), 'sistema');
    expect(idiomaParaString(IdiomaApp.en), 'en');
  });

  test('deve_mapear_idioma_para_locale_quando_escolhido', () {
    expect(IdiomaApp.sistema.locale, isNull);
    expect(IdiomaApp.pt.locale, const Locale('pt'));
    expect(IdiomaApp.en.locale, const Locale('en'));
    expect(IdiomaApp.es.locale, const Locale('es'));
  });

  test('deve_usar_pt_como_primeiro_locale_quando_fallback', () {
    expect(AppLocalizations.supportedLocales, <Locale>[
      const Locale('pt'),
      const Locale('en'),
      const Locale('es'),
    ]);
  });

  testWidgets('deve_resolver_string_em_ingles_quando_locale_en', (
    tester,
  ) async {
    late String titulo;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(
          builder: (context) {
            titulo = context.l10n.minhasListas;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(titulo, 'My Lists');
  });

  testWidgets('deve_resolver_string_em_espanhol_quando_locale_es', (
    tester,
  ) async {
    late String titulo;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(
          builder: (context) {
            titulo = context.l10n.minhasListas;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(titulo, 'Mis listas');
  });

  testWidgets('deve_resolver_string_em_pt_quando_locale_pt', (tester) async {
    late String titulo;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('pt'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(
          builder: (context) {
            titulo = context.l10n.minhasListas;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(titulo, 'Minhas Listas');
  });
}
