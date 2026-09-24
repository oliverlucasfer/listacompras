import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/widgets/app_cabecalho_secao.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../data/backup_repository.dart';
import '../providers/backup_providers.dart';

/// Seção "Backup" das Configurações (RF-31, F41): exporta o estado atual para
/// um arquivo `.json` e importa de um arquivo, mesclando com as listas locais
/// (LWW por `updated_at`, `backup_repository.dart`).
class SecaoBackup extends ConsumerWidget {
  const SecaoBackup({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppCabecalhoSecao(AppStrings.backup),
        ListTile(
          leading: const Icon(Icons.upload_file_outlined),
          title: const Text(AppStrings.backupExportar),
          subtitle: const Text(AppStrings.backupExportarAjuda),
          onTap: () => _exportar(context, ref),
        ),
        ListTile(
          leading: const Icon(Icons.download_outlined),
          title: const Text(AppStrings.backupImportar),
          subtitle: const Text(AppStrings.backupImportarAjuda),
          onTap: () => _importar(context, ref),
        ),
      ],
    );
  }

  /// Exporta o estado atual e abre o compartilhamento do arquivo.
  ///
  /// O conteúdo vai como `XFile.fromData` em vez de gravar com `dart:io` +
  /// `path_provider`: o `share_plus` materializa o arquivo temporário no nativo
  /// (com o nome pedido) e usa os bytes no web, mantendo o build web do app
  /// colaborativo compilável (CI).
  Future<void> _exportar(BuildContext context, WidgetRef ref) async {
    try {
      final json = await ref.read(backupRepositoryProvider).exportarJson();
      final nome = 'backup_${_carimbo(DateTime.now())}.json';
      final arquivo = XFile.fromData(
        utf8.encode(json),
        name: nome,
        mimeType: 'application/json',
      );
      await SharePlus.instance.share(
        ShareParams(files: [arquivo], fileNameOverrides: [nome]),
      );
      if (context.mounted) {
        mostrarSnackBar(context, AppStrings.backupExportado);
      }
    } on MissingPluginException {
      // Compartilhamento indisponível (desktop/sem plugin) — mesma orientação
      // usada em `sheet_convidar.dart`.
      if (context.mounted) {
        mostrarSnackBar(context, AppStrings.compartilharIndisponivel);
      }
    } on UnimplementedError {
      if (context.mounted) {
        mostrarSnackBar(context, AppStrings.compartilharIndisponivel);
      }
    } catch (_) {
      if (context.mounted) {
        mostrarSnackBar(context, AppStrings.erroGenerico);
      }
    }
  }

  /// Lê um arquivo escolhido pelo usuário e mescla o backup no banco local.
  Future<void> _importar(BuildContext context, WidgetRef ref) async {
    try {
      final resultado = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
      if (resultado == null || resultado.files.isEmpty) return;
      final conteudo = await resultado.xFiles.first.readAsString();
      await ref.read(backupRepositoryProvider).importarJson(conteudo);
      if (context.mounted) {
        mostrarSnackBar(context, AppStrings.backupImportado);
      }
    } on BackupInvalidoException {
      if (context.mounted) {
        mostrarSnackBar(context, AppStrings.backupInvalido);
      }
    } catch (_) {
      if (context.mounted) {
        mostrarSnackBar(context, AppStrings.backupLeituraErro);
      }
    }
  }
}

/// Carimbo `yyyyMMdd-HHmmss` para o nome do arquivo exportado.
String _carimbo(DateTime d) {
  String dois(int n) => n.toString().padLeft(2, '0');
  return '${d.year}${dois(d.month)}${dois(d.day)}'
      '-${dois(d.hour)}${dois(d.minute)}${dois(d.second)}';
}
