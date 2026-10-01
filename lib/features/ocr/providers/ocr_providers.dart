import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/fonte_imagem_image_picker.dart';
import '../data/ocr_texto_mlkit.dart';
import '../domain/fonte_imagem.dart';
import '../domain/ocr_texto.dart';

/// O OCR só aparece onde o plugin on-device é suportado: Android/iOS.
bool plataformaComOcr() {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}

final ocrTextoProvider = Provider.autoDispose<OcrTexto>((ref) {
  final ocr = OcrTextoMlKit();
  ref.onDispose(ocr.close);
  return ocr;
});
final fonteImagemProvider = Provider<FonteImagem>(
  (ref) => FonteImagemImagePicker(),
);
