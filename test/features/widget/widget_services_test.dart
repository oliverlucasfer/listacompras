import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/features/widget/domain/widget_service.dart';
import 'package:lista_compras/features/widget/data/ultima_lista_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _WidgetFake implements WidgetService {
  final chamadas = <WidgetDados>[];
  @override
  Future<void> atualizar(WidgetDados dados) async => chamadas.add(dados);
  @override
  Future<String?> toqueInicial() async => null;
  @override
  Stream<String> toques() => const Stream.empty();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('deve_gravar_e_ler_ultima_lista', () async {
    SharedPreferences.setMockInitialValues({});
    final s = UltimaListaService();
    await s.registrar('l1');
    expect(await s.ler(), 'l1');
  });

  test('deve_enviar_titulo_e_pendentes_quando_atualiza', () async {
    final f = _WidgetFake();
    await f.atualizar(const WidgetDados(titulo: 'Semana', pendentes: 3));
    expect(f.chamadas.single.titulo, 'Semana');
    expect(f.chamadas.single.pendentes, 3);
  });
}
