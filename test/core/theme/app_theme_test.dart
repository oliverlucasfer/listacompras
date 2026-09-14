import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/theme/app_semantic_colors.dart';
import 'package:lista_compras/core/theme/app_theme.dart';

void main() {
  test('deve_ter_brilho_claro_quando_tema_claro', () {
    expect(AppTheme.claro.brightness, Brightness.light);
  });

  test('deve_ter_brilho_escuro_quando_tema_escuro', () {
    expect(AppTheme.escuro.brightness, Brightness.dark);
  });

  test('deve_expor_extensao_semantica_em_ambos_os_temas', () {
    expect(AppTheme.claro.extension<AppSemanticColors>(), isNotNull);
    expect(AppTheme.escuro.extension<AppSemanticColors>(), isNotNull);
  });

  test('deve_diferir_cor_de_sucesso_entre_claro_e_escuro', () {
    final claro = AppTheme.claro.extension<AppSemanticColors>()!;
    final escuro = AppTheme.escuro.extension<AppSemanticColors>()!;
    expect(claro.success, isNot(equals(escuro.success)));
  });

  test('deve_usar_material_3_e_a_fonte_bundlada', () {
    expect(AppTheme.claro.useMaterial3, isTrue);
    expect(AppTheme.claro.textTheme.bodyLarge?.fontFamily, 'PlusJakartaSans');
  });

  test('deve_usar_texto_claro_quando_tema_escuro', () {
    final cor = AppTheme.escuro.textTheme.bodyMedium!.color!;
    expect(cor.computeLuminance(), greaterThan(0.5));
  });

  test('deve_usar_texto_escuro_quando_tema_claro', () {
    final cor = AppTheme.claro.textTheme.bodyMedium!.color!;
    expect(cor.computeLuminance(), lessThan(0.5));
  });

  test('deve_usar_titulo_de_appbar_24_bold_em_ambos_os_temas', () {
    // F13-T03: títulos das telas maiores (24sp) e em negrito.
    for (final tema in [AppTheme.claro, AppTheme.escuro]) {
      final estilo = tema.appBarTheme.titleTextStyle!;
      expect(estilo.fontSize, 24);
      expect(estilo.fontWeight, FontWeight.bold);
    }
  });
}
