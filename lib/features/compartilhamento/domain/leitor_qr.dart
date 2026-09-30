import 'package:flutter/widgets.dart';

/// Lê um QR/código pela câmera. Devolve o texto lido, ou `null` se cancelado.
abstract interface class LeitorQr {
  Future<String?> escanear(BuildContext context);
}
