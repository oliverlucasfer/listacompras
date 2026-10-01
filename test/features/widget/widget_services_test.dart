import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/features/widget/data/widget_service_home_widget.dart';
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

  group('WidgetServiceHomeWidget (ponte com o canal home_widget)', () {
    const canal = MethodChannel('home_widget');
    late List<MethodCall> chamadas;

    setUp(() {
      chamadas = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(canal, (call) async {
            chamadas.add(call);
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(canal, null);
    });

    MethodCall chamada(String metodo, String id) => chamadas.firstWhere(
      (c) => c.method == metodo && (c.arguments as Map)['id'] == id,
    );

    test('deve_gravar_titulo_pendentes_e_tem_lista_quando_tem_lista', () async {
      await WidgetServiceHomeWidget().atualizar(
        const WidgetDados(titulo: 'Semana', pendentes: 3),
      );

      expect(chamada('saveWidgetData', 'titulo').arguments['data'], 'Semana');
      expect(chamada('saveWidgetData', 'pendentes').arguments['data'], 3);
      expect(chamada('saveWidgetData', 'tem_lista').arguments['data'], isTrue);
    });

    test('deve_gravar_tem_lista_falso_quando_sem_lista', () async {
      await WidgetServiceHomeWidget().atualizar(
        const WidgetDados(titulo: null, pendentes: 0),
      );

      expect(chamada('saveWidgetData', 'titulo').arguments['data'], '');
      expect(chamada('saveWidgetData', 'tem_lista').arguments['data'], isFalse);
    });

    test('deve_atualizar_widget_com_o_nome_totalmente_qualificado', () async {
      await WidgetServiceHomeWidget().atualizar(
        const WidgetDados(titulo: 'Semana', pendentes: 3),
      );

      final atualizacao = chamadas
          .where((c) => c.method == 'updateWidget')
          .single;
      expect(
        atualizacao.arguments['qualifiedAndroidName'],
        nomeAppWidgetQualificado,
      );
    });

    test('deve_extrair_o_host_do_toque_inicial', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(canal, (call) async {
            if (call.method == 'initiallyLaunchedFromHomeWidget') {
              return 'minhas-listas://adicionar';
            }
            return null;
          });

      expect(await WidgetServiceHomeWidget().toqueInicial(), 'adicionar');
    });
  });
}
