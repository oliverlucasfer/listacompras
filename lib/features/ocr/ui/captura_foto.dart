import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n.dart';
import '../providers/ocr_providers.dart';

/// Resultado de capturar uma foto e rodar o OCR (RF-37/RF-40).
sealed class ResultadoCaptura {
  const ResultadoCaptura();
}

class CapturaTexto extends ResultadoCaptura {
  const CapturaTexto(this.texto);
  final String texto;
}

class CapturaCancelada extends ResultadoCaptura {
  const CapturaCancelada();
}

/// OCR rodou, mas não reconheceu nenhum texto.
class CapturaVazia extends ResultadoCaptura {
  const CapturaVazia();
}

/// Falha de permissão, do picker ou do OCR.
class CapturaFalha extends ResultadoCaptura {
  const CapturaFalha();
}

/// Abre a escolha câmera/galeria, lê a imagem e devolve o texto reconhecido
/// (trimado). Não grava nada e não persiste a imagem.
///
/// [aoIniciarLeitura] é chamado quando a imagem já foi escolhida e o OCR vai
/// começar — permite ao chamador ligar seu indicador de carregamento apenas
/// durante a leitura (não enquanto o seletor câmera/galeria está aberto).
Future<ResultadoCaptura> capturarTextoDeFoto(
  BuildContext context,
  WidgetRef ref, {
  VoidCallback? aoIniciarLeitura,
}) async {
  final origem = await showModalBottomSheet<String>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: Text(context.l10n.tirarFoto),
            onTap: () => Navigator.pop(context, 'camera'),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(context.l10n.escolherDaGaleria),
            onTap: () => Navigator.pop(context, 'galeria'),
          ),
        ],
      ),
    ),
  );
  if (origem == null) return const CapturaCancelada();

  final fonte = ref.read(fonteImagemProvider);
  String? caminho;
  try {
    caminho = origem == 'camera'
        ? await fonte.daCamera()
        : await fonte.daGaleria();
  } catch (_) {
    return const CapturaFalha();
  }
  if (caminho == null) return const CapturaCancelada();

  aoIniciarLeitura?.call();

  // Mantém o provider (autoDispose) vivo durante o OCR assíncrono.
  final assinatura = ref.listenManual(ocrTextoProvider, (_, _) {});
  String texto;
  try {
    texto = await ref.read(ocrTextoProvider).extrair(caminho);
  } catch (_) {
    return const CapturaFalha();
  } finally {
    assinatura.close();
  }
  final limpo = texto.trim();
  return limpo.isEmpty ? const CapturaVazia() : CapturaTexto(limpo);
}
