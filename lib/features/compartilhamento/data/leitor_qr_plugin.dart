import 'package:flutter/material.dart';

import '../domain/leitor_qr.dart';
import '../ui/tela_escanear_qr.dart';

class LeitorQrPlugin implements LeitorQr {
  @override
  Future<String?> escanear(BuildContext context) {
    return Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const TelaEscanearQr()));
  }
}
