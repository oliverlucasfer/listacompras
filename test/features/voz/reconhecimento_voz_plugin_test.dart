import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/features/voz/data/reconhecimento_voz_plugin.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // `ReconhecimentoVozPlugin` fala com o singleton `SpeechToText`, que usa o
  // method channel abaixo. Mockamos o canal para exercitar o wrapper sem o
  // plugin nativo (que é smoke on-device).
  const canal = MethodChannel('plugin.csdcorp.com/speech_to_text');
  final mensageiro =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    mensageiro.setMockMethodCallHandler(canal, (call) async {
      if (call.method == 'initialize' || call.method == 'listen') return true;
      return null;
    });
  });

  tearDown(() => mensageiro.setMockMethodCallHandler(canal, null));

  test('deve_entregar_erro_permanente_ao_ultimo_iniciar', () async {
    final plugin = ReconhecimentoVozPlugin();
    final indisponivel1 = <bool>[];
    await plugin.iniciar(
      onTexto: (_, _) {},
      onIndisponivel: () => indisponivel1.add(true),
      onEstado: (_) {},
    );

    final indisponivel2 = <bool>[];
    await plugin.iniciar(
      onTexto: (_, _) {},
      onIndisponivel: () => indisponivel2.add(true),
      onEstado: (_) {},
    );

    // Erro permanente vindo da plataforma: precisa chegar à 2ª tela, não à 1ª.
    await mensageiro.handlePlatformMessage(
      canal.name,
      canal.codec.encodeMethodCall(
        MethodCall(
          'notifyError',
          jsonEncode({'errorMsg': 'modelo ausente', 'permanent': true}),
        ),
      ),
      (_) {},
    );

    expect(indisponivel1, isEmpty);
    expect(indisponivel2, [true]);
  });
}
