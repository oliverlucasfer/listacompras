import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/l10n/l10n.dart';

/// Scanner em tela cheia; `pop` devolve o primeiro código lido (ou `null`).
class TelaEscanearQr extends StatefulWidget {
  const TelaEscanearQr({super.key});

  @override
  State<TelaEscanearQr> createState() => _TelaEscanearQrState();
}

class _TelaEscanearQrState extends State<TelaEscanearQr> {
  final _controller = MobileScannerController();
  bool _lido = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _aoDetectar(BarcodeCapture capture) {
    if (_lido) return;
    final valor = capture.barcodes.isEmpty
        ? null
        : capture.barcodes.first.rawValue;
    if (valor == null || valor.isEmpty) return;
    _lido = true;
    Navigator.pop(context, valor);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.escanearQr)),
      body: MobileScanner(controller: _controller, onDetect: _aoDetectar),
    );
  }
}
