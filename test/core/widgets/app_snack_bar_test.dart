import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/widgets/app_snack_bar.dart';

Future<void> _abrirCom(WidgetTester tester, {required bool comAcao}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => mostrarSnackBar(
              context,
              'Item removido',
              rotuloAcao: comAcao ? 'Desfazer' : null,
              onAcao: comAcao ? () {} : null,
            ),
            child: const Text('mostrar'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('mostrar'));
  await tester.pump();
}

void main() {
  testWidgets('deve_manter_snack_bar_por_2s_quando_sem_acao', (tester) async {
    // F12-T07: mensagens simples somem rápido.
    await _abrirCom(tester, comAcao: false);
    final snack = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snack.duration, const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('deve_manter_snack_bar_por_3s_quando_tem_acao', (tester) async {
    // F12-T07: com "Desfazer" o usuário precisa de um pouco mais de tempo.
    await _abrirCom(tester, comAcao: true);
    final snack = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snack.duration, const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets(
    'deve_usar_messenger_informado_quando_sem_messenger_no_contexto',
    (tester) async {
      final key = GlobalKey<ScaffoldMessengerState>();
      late BuildContext semMessenger;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            semMessenger = context;
            return MaterialApp(
              scaffoldMessengerKey: key,
              home: const Scaffold(body: SizedBox.expand()),
            );
          },
        ),
      );

      mostrarSnackBar(semMessenger, 'Notificação', messenger: key.currentState);
      await tester.pump();

      expect(find.text('Notificação'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    },
  );
}
