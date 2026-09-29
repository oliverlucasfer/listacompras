import 'package:flutter/material.dart';

/// Texto exibido quando o pacote instalado não casa com o modo do entrypoint
/// (F47/RF-32). Visível em release — evita subir o app colaborativo sob o
/// pacote `.lite` silenciosamente.
const telaBuildIncorretoTexto =
    'Não foi possível iniciar o aplicativo.\n'
    'Instale a versão correta na loja.';

class TelaBuildIncorreto extends StatelessWidget {
  const TelaBuildIncorreto({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(telaBuildIncorretoTexto, textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }
}
