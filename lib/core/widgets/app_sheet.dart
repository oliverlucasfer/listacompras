import 'package:flutter/material.dart';

import '../theme/tokens/app_spacing.dart';

/// Bottom sheet padronizado (doc 15 §3).
abstract final class AppSheet {
  static Future<T?> mostrar<T>(
    BuildContext context, {
    required Widget child,
    bool isScrollControlled = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            top: AppSpacing.sm,
            bottom:
                AppSpacing.lg + MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: child,
        ),
      ),
    );
  }
}
