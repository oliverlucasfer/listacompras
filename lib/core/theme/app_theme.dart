import 'package:flutter/material.dart';

import 'app_semantic_colors.dart';
import 'tokens/app_colors.dart';
import 'tokens/app_elevation.dart';
import 'tokens/app_radius.dart';
import 'tokens/app_spacing.dart';
import 'tokens/app_typography.dart';

/// Tema do app (doc 15 §2): Material 3 Expressive, claro/escuro com paridade.
abstract final class AppTheme {
  static ThemeData get claro =>
      _base(Brightness.light, AppSemanticColors.claro);

  static ThemeData get escuro =>
      _base(Brightness.dark, AppSemanticColors.escuro);

  static ThemeData _base(Brightness brightness, AppSemanticColors semanticas) {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.seed,
      brightness: brightness,
    );
    final texto = AppTypography.textTheme;
    const botaoShape = RoundedRectangleBorder(
      borderRadius: AppRadius.fullTodos,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: texto,
      scaffoldBackgroundColor: scheme.surface,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      extensions: <ThemeExtension<dynamic>>[semanticas],
      appBarTheme: AppBarThemeData(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: AppElevation.nivel0,
        scrolledUnderElevation: AppElevation.nivel2,
        centerTitle: false,
        titleTextStyle: texto.titleLarge?.copyWith(color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        elevation: AppElevation.nivel1,
        color: scheme.surfaceContainerLow,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgTodos),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        border: const OutlineInputBorder(borderRadius: AppRadius.mdTodos),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdTodos,
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdTodos,
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: botaoShape,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: botaoShape,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgTodos),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xxl),
          ),
        ),
      ),
      dialogTheme: const DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.xxlTodos),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdTodos),
      ),
      listTileTheme: const ListTileThemeData(minVerticalPadding: AppSpacing.sm),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        elevation: AppElevation.nivel2,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        space: AppSpacing.xl,
      ),
      checkboxTheme: CheckboxThemeData(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.smTodos),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
    );
  }
}
