import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../sync/providers/sync_providers.dart';
import '../domain/convite.dart';
import '../providers/convites_providers.dart';
import '../providers/papel_providers.dart';

/// Confirma e executa "sair da lista" (doc 08 §5, F14-T06): usado pelo menu
/// da tela de membros e pelo menu do card de Compartilhadas.
Future<void> confirmarSairDaLista(
  BuildContext context,
  WidgetRef ref,
  String listaId,
) async {
  final confirmou = await AppDialog.confirmarDestrutivo(
    context,
    titulo: AppStrings.sairListaTitulo,
    mensagem: AppStrings.sairListaMensagem,
    confirmar: AppStrings.sairDaLista,
  );
  if (!confirmou || !context.mounted) return;
  final repoConvites = ref.read(convitesRepositoryProvider);
  final repoPapeis = ref.read(papelRepositoryProvider);
  try {
    await repoConvites.sairDaLista(listaId);
    repoPapeis.remover(listaId);
    // Belt-and-suspenders (doc 08 §5, F7-T07): o Realtime pode filtrar o
    // DELETE do próprio usuário — limpa o cache local explicitamente.
    unawaited(ref.read(syncBootstrapProvider).perderAcessoLocal());
    if (context.mounted) context.go('/compartilhadas');
  } on ErroConvite catch (e) {
    if (context.mounted) mostrarSnackBar(context, e.message);
  } catch (_) {
    if (context.mounted) mostrarSnackBar(context, AppStrings.erroGenerico);
  }
}
