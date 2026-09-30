import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/features/historico/domain/estatisticas.dart';
import 'package:lista_compras/features/historico/ui/grafico_gasto_mensal.dart';

void main() {
  testWidgets('deve_renderizar_barras_quando_ha_dados', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GraficoGastoMensal(
            dados: [
              GastoPorMes(mes: DateTime.utc(2026, 8, 1), totalCentavos: 5000),
              GastoPorMes(mes: DateTime.utc(2026, 9, 1), totalCentavos: 7000),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(BarChart), findsOneWidget);
  });

  testWidgets('deve_mostrar_vazio_quando_sem_dados', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: GraficoGastoMensal(dados: [])),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sem dados ainda.'), findsOneWidget);
  });
}
