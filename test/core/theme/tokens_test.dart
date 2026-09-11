import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/theme/tokens/app_elevation.dart';
import 'package:lista_compras/core/theme/tokens/app_motion.dart';
import 'package:lista_compras/core/theme/tokens/app_radius.dart';
import 'package:lista_compras/core/theme/tokens/app_spacing.dart';
import 'package:lista_compras/core/theme/tokens/app_typography.dart';

void main() {
  test('deve_ter_escala_de_espacamento_em_multiplos_de_4', () {
    expect(AppSpacing.xs, 4);
    expect(AppSpacing.sm, 8);
    expect(AppSpacing.md, 12);
    expect(AppSpacing.lg, 16);
    expect(AppSpacing.xl, 24);
    expect(AppSpacing.xxl, 32);
    expect(AppSpacing.xxxl, 48);
  });

  test('deve_ter_escala_de_raios_crescente', () {
    expect(AppRadius.sm, lessThan(AppRadius.md));
    expect(AppRadius.md, lessThan(AppRadius.lg));
    expect(AppRadius.lg, lessThan(AppRadius.xl));
    expect(AppRadius.xl, lessThan(AppRadius.xxl));
    expect(AppRadius.full, greaterThan(AppRadius.xxl));
  });

  test('deve_ter_niveis_de_elevacao_em_ordem', () {
    expect(AppElevation.nivel0, 0);
    expect(AppElevation.nivel0, lessThanOrEqualTo(AppElevation.nivel3));
  });

  test('deve_ter_duracoes_de_motion_com_a_curva_padrao', () {
    expect(
      AppMotion.rapida.inMilliseconds,
      lessThan(AppMotion.media.inMilliseconds),
    );
    expect(
      AppMotion.media.inMilliseconds,
      lessThan(AppMotion.longa.inMilliseconds),
    );
    expect(AppMotion.padrao, isA<Curve>());
  });

  test('deve_usar_fonte_plus_jakarta_sans_no_text_theme', () {
    final estilo = AppTypography.textTheme.bodyLarge;
    expect(estilo?.fontFamily, 'PlusJakartaSans');
  });
}
