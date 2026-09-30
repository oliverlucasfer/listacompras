import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/features/historico/domain/estatisticas.dart';
import 'package:lista_compras/features/historico/ui/grafico_gasto_mensal.dart';
import 'package:lista_compras/features/listas/domain/preco.dart';

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

  testWidgets('deve_rotular_somente_a_barra_mais_alta_quando_ha_varias', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GraficoGastoMensal(
            dados: [
              GastoPorMes(mes: DateTime.utc(2026, 8, 1), totalCentavos: 5000),
              GastoPorMes(mes: DateTime.utc(2026, 9, 1), totalCentavos: 7000),
              GastoPorMes(mes: DateTime.utc(2026, 10, 1), totalCentavos: 3000),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final chart = tester.widget<BarChart>(find.byType(BarChart));
    final barras = chart.data.barGroups.map((g) => g.barRods.first).toList();
    expect(barras[0].label.show, isFalse);
    expect(barras[1].label.show, isTrue);
    expect(barras[1].label.text, formatarReais(7000));
    expect(barras[2].label.show, isFalse);
  });

  testWidgets('deve_expor_resumo_de_acessibilidade_do_gasto_mensal', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
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
    expect(find.bySemanticsLabel('Gasto mensal: R\$ 120,00'), findsOneWidget);
    handle.dispose();
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
