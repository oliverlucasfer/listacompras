import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/l10n/app_strings.dart';
import 'package:lista_compras/core/theme/app_theme.dart';
import 'package:lista_compras/core/widgets/app_estado_erro.dart';
import 'package:lista_compras/core/widgets/app_estado_vazio.dart';

Widget _app(Widget child) => MaterialApp(
  theme: AppTheme.claro,
  home: Scaffold(body: child),
);

void main() {
  testWidgets('deve_exibir_titulo_e_acao_quando_vazio', (tester) async {
    await tester.pumpWidget(
      _app(
        AppEstadoVazio(
          titulo: 'Nada aqui',
          acao: FilledButton(onPressed: () {}, child: const Text('Criar')),
        ),
      ),
    );
    expect(find.text('Nada aqui'), findsOneWidget);
    expect(find.text('Criar'), findsOneWidget);
  });

  testWidgets('deve_disparar_retry_quando_erro', (tester) async {
    var retentou = false;
    await tester.pumpWidget(
      _app(
        AppEstadoErro(mensagem: 'Falhou', onRetentar: () => retentou = true),
      ),
    );
    await tester.tap(find.text(AppStrings.tentarNovamente));
    expect(retentou, isTrue);
  });
}
