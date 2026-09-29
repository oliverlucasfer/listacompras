import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/widgets/tela_build_incorreto.dart';

void main() {
  testWidgets('deve_mostrar_aviso_quando_build_incorreto', (tester) async {
    await tester.pumpWidget(const TelaBuildIncorreto());
    expect(find.text(telaBuildIncorretoTexto), findsOneWidget);
  });
}
