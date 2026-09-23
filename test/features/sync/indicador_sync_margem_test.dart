import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/theme/tokens/app_spacing.dart';
import 'package:lista_compras/features/sync/domain/sync_status.dart';
import 'package:lista_compras/features/sync/providers/sync_providers.dart';
import 'package:lista_compras/features/sync/ui/indicador_sync.dart';

Widget _app(SyncStatus status) => ProviderScope(
  overrides: [syncStatusProvider.overrideWith((ref) => Stream.value(status))],
  child: const MaterialApp(
    home: Scaffold(
      body: Align(alignment: Alignment.topLeft, child: IndicadorSync()),
    ),
  ),
);

EdgeInsets _paddingDe(WidgetTester tester) {
  final padding = tester
      .widgetList<Padding>(find.byType(Padding))
      .map((p) => p.padding)
      .whereType<EdgeInsets>()
      .firstWhere((e) => e.top == AppSpacing.sm || e.top == AppSpacing.xs);
  return padding;
}

void main() {
  testWidgets('deve_usar_16dp_laterais_quando_offline', (tester) async {
    await tester.pumpWidget(_app(const Offline()));
    await tester.pump();
    final p = _paddingDe(tester);
    expect(p.left, AppSpacing.lg);
    expect(p.right, AppSpacing.lg);
  });

  testWidgets('deve_usar_16dp_laterais_quando_erro', (tester) async {
    await tester.pumpWidget(_app(const ErroSync()));
    await tester.pump();
    final p = _paddingDe(tester);
    expect(p.left, AppSpacing.lg);
    expect(p.right, AppSpacing.lg);
  });
}
