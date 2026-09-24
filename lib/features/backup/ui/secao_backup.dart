import 'dart:convert';

import 'package:file_selector/file_selector.dart';
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
    final ResultadoImportacaoBackup resultado;
    try {
      // Sem filtro de tipo de propósito: no Android o plugin colapsa um
      // XTypeGroup com um único mime (`application/json`) em
      // `intent.setType("application/json")`, e provedores que classificam
      // `.json` como `text/plain`/`application/octet-stream` desabilitam o
      // arquivo — deixando um backup válido não selecionável. A validação fica em
      // `importarJson` (conteúdo inválido → `backupInvalido`). Não re-adicione
      // `acceptedTypeGroups`.
      final arquivo = await openFile();
      resultado = await importarArquivoBackup(
        arquivo,
        ref.read(backupRepositoryProvider),
      );
    } catch (_) {
      // O próprio seletor falhou (plugin indisponível/permissão).
      if (context.mounted) {
        mostrarSnackBar(context, AppStrings.backupLeituraErro);
      }
      return;
    }
    if (!context.mounted) return;
    switch (resultado) {
      case ResultadoImportacaoBackup.cancelado:
        return;
      case ResultadoImportacaoBackup.importado:
        mostrarSnackBar(context, AppStrings.backupImportado);
      case ResultadoImportacaoBackup.invalido:
        mostrarSnackBar(context, AppStrings.backupInvalido);
      case ResultadoImportacaoBackup.leituraErro:
        mostrarSnackBar(context, AppStrings.backupLeituraErro);
    }
  }
}

/// Desfecho da leitura/importação de um backup escolhido pelo usuário.
enum ResultadoImportacaoBackup { cancelado, importado, invalido, leituraErro }

/// Lê o arquivo escolhido (ou `null` = cancelado) e mescla o backup.
///
/// Isola a regra de desfecho testável do diálogo nativo (não injetável).
Future<ResultadoImportacaoBackup> importarArquivoBackup(
  XFile? arquivo,
  BackupRepository repositorio,
) async {
  if (arquivo == null) return ResultadoImportacaoBackup.cancelado;
  try {
    final conteudo = await arquivo.readAsString();
    await repositorio.importarJson(conteudo);
    return ResultadoImportacaoBackup.importado;
  } on BackupInvalidoException {
    return ResultadoImportacaoBackup.invalido;
  } catch (_) {
    return ResultadoImportacaoBackup.leituraErro;
  }
}

/// Carimbo `yyyyMMdd-HHmmss` para o nome do arquivo exportado.
String _carimbo(DateTime d) {
  String dois(int n) => n.toString().padLeft(2, '0');
  return '${d.year}${dois(d.month)}${dois(d.day)}'
      '-${dois(d.hour)}${dois(d.minute)}${dois(d.second)}';
}
