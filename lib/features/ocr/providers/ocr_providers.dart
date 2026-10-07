import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/plataforma.dart';
import '../data/fonte_imagem_image_picker.dart';
import '../data/ocr_texto_mlkit.dart';
import '../domain/fonte_imagem.dart';
import '../domain/ocr_texto.dart';

/// O OCR só aparece onde o plugin on-device é suportado: Android/iOS.
bool plataformaComOcr() => dispositivoMovel();

final ocrTextoProvider = Provider.autoDispose<OcrTexto>((ref) {
  final ocr = OcrTextoMlKit();
  ref.onDispose(ocr.close);
  return ocr;
});
final fonteImagemProvider = Provider<FonteImagem>(
  (ref) => FonteImagemImagePicker(),
);
