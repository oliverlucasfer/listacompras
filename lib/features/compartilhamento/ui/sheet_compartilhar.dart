import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../domain/codec_lista.dart';
import '../domain/lista_compartilhada.dart';
import '../providers/compartilhamento_providers.dart';

/// Teto do código para o QR (spec §4). Acima disso só texto/arquivo.
const int limiteCodigoBytes = 2000;

Future<void> abrirSheetCompartilhar(
  BuildContext context,
  WidgetRef ref,
  String listaId,
) async {
  final lista = await ref
      .read(compartilhamentoRepositoryProvider)
      .exportarLista(listaId);
  if (!context.mounted) return;
  await AppSheet.mostrar<void>(
    context,
    child: _SheetCompartilhar(lista: lista),
  );
}

class _SheetCompartilhar extends StatelessWidget {
  const _SheetCompartilhar({required this.lista});

  final ListaCompartilhada lista;

  Future<void> _texto(BuildContext context) async {
    try {
      await SharePlus.instance.share(ShareParams(text: gerarTextoLista(lista)));
    } on MissingPluginException {
      if (context.mounted) {
        mostrarSnackBar(context, AppStrings.compartilharIndisponivel);
      }
    } on UnimplementedError {
      if (context.mounted) {
        mostrarSnackBar(context, AppStrings.compartilharIndisponivel);
      }
    }
  }

  Future<void> _arquivo(BuildContext context) async {
    try {
      final json = jsonEncode(lista.toJson());
      final nome = '${lista.titulo}.json';
      final arquivo = XFile.fromData(
        utf8.encode(json),
        name: nome,
        mimeType: 'application/json',
      );
      await SharePlus.instance.share(
        ShareParams(files: [arquivo], fileNameOverrides: [nome]),
      );
    } on MissingPluginException {
      if (context.mounted) {
        mostrarSnackBar(context, AppStrings.compartilharIndisponivel);
      }
    } on UnimplementedError {
      if (context.mounted) {
        mostrarSnackBar(context, AppStrings.compartilharIndisponivel);
      }
    }
  }

  Future<void> _qr(BuildContext context) async {
    final codigo = codificarLista(lista);
    if (codigo.length > limiteCodigoBytes) {
      mostrarSnackBar(context, AppStrings.compartilharQrGrande);
      return;
    }
    await AppSheet.mostrar<void>(
      context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          QrImageView(data: codigo, size: 240),
          const SizedBox(height: 12),
          TextButton.icon(
            icon: const Icon(Icons.copy),
            label: const Text(AppStrings.copiarCodigo),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: codigo));
              if (context.mounted) {
                mostrarSnackBar(context, AppStrings.codigoCopiado);
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(lista.titulo, style: Theme.of(context).textTheme.titleMedium),
        ListTile(
          leading: const Icon(Icons.chat_outlined),
          title: const Text(AppStrings.compartilharTexto),
          onTap: () => _texto(context),
        ),
        ListTile(
          leading: const Icon(Icons.upload_file_outlined),
          title: const Text(AppStrings.compartilharArquivo),
          onTap: () => _arquivo(context),
        ),
        ListTile(
          leading: const Icon(Icons.qr_code_2),
          title: const Text(AppStrings.compartilharQr),
          onTap: () => _qr(context),
        ),
      ],
    );
  }
}
