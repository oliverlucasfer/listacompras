import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/theme/theme_mode_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('deve_retornar_sistema_quando_sem_preferencia', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(await container.read(temaModoProvider.future), ThemeMode.system);
  });

  test('deve_ler_modo_escuro_quando_salvo', () async {
    SharedPreferences.setMockInitialValues({'tema_modo': 'escuro'});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(await container.read(temaModoProvider.future), ThemeMode.dark);
  });

  test('deve_persistir_modo_escolhido_quando_definir', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(temaModoProvider.future);
    await container.read(temaModoProvider.notifier).definir(ThemeMode.light);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('tema_modo'), 'claro');
  });

  test('deve_mapear_strings_desconhecidas_para_sistema', () {
    expect(temaModoDeString(null), ThemeMode.system);
    expect(temaModoDeString('qualquer'), ThemeMode.system);
    expect(temaModoParaString(ThemeMode.dark), 'escuro');
  });
}
