import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/features/ocr/domain/fonte_imagem.dart';
import 'package:lista_compras/features/ocr/domain/ocr_texto.dart';
import 'package:lista_compras/features/ocr/providers/ocr_providers.dart';
import 'package:lista_compras/features/ocr/ui/captura_foto.dart';

import '../../support/app_teste.dart';

class _OcrFake implements OcrTexto {
  _OcrFake(this._texto);
  final String _texto;
  @override
  Future<String> extrair(String caminho) async => _texto;
  @override
  void close() {}
}

class _FonteFake implements FonteImagem {
  _FonteFake({this.caminho = '/tmp/a.jpg'});
  final String? caminho;
  @override
  Future<String?> daCamera() async => caminho;
  @override
  Future<String?> daGaleria() async => caminho;
}

class _Hospedeiro extends ConsumerWidget {
  const _Hospedeiro({required this.onResultado});
  final ValueChanged<ResultadoCaptura> onResultado;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () async {
          final resultado = await capturarTextoDeFoto(context, ref);
          onResultado(resultado);
        },
        child: const Text('capturar'),
      ),
    ),
  );
}

Widget _app({
  required OcrTexto ocr,
  required FonteImagem fonte,
  required ValueChanged<ResultadoCaptura> onResultado,
}) {
  return ProviderScope(
    overrides: [
      ocrTextoProvider.overrideWithValue(ocr),
      fonteImagemProvider.overrideWithValue(fonte),
    ],
    child: appTeste(_Hospedeiro(onResultado: onResultado)),
  );
}

void main() {
  testWidgets('deve_devolver_captura_texto_quando_ocr_le_a_foto', (
    tester,
  ) async {
    ResultadoCaptura? resultado;
    await tester.pumpWidget(
      _app(
        ocr: _OcrFake('Arroz'),
        fonte: _FonteFake(),
        onResultado: (r) => resultado = r,
      ),
    );
    await tester.tap(find.text('capturar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tirar foto'));
    await tester.pumpAndSettle();

    expect(resultado, isA<CapturaTexto>());
    expect((resultado! as CapturaTexto).texto, 'Arroz');
  });

  testWidgets('deve_devolver_captura_vazia_quando_ocr_sem_texto', (
    tester,
  ) async {
    ResultadoCaptura? resultado;
    await tester.pumpWidget(
      _app(
        ocr: _OcrFake(''),
        fonte: _FonteFake(),
        onResultado: (r) => resultado = r,
      ),
    );
    await tester.tap(find.text('capturar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tirar foto'));
    await tester.pumpAndSettle();

    expect(resultado, isA<CapturaVazia>());
  });

  testWidgets('deve_devolver_captura_cancelada_quando_fonte_nula', (
    tester,
  ) async {
    ResultadoCaptura? resultado;
    await tester.pumpWidget(
      _app(
        ocr: _OcrFake('Arroz'),
        fonte: _FonteFake(caminho: null),
        onResultado: (r) => resultado = r,
      ),
    );
    await tester.tap(find.text('capturar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tirar foto'));
    await tester.pumpAndSettle();

    expect(resultado, isA<CapturaCancelada>());
  });
}
