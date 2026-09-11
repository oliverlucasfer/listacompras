import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/tokens/app_spacing.dart';
import '../../../core/widgets/app_banner.dart';
import '../../../core/widgets/app_botao.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../domain/convite.dart';
import '../domain/papel.dart';
import '../providers/convites_providers.dart';

/// Sheet "Convidar" (doc 08 §8, F7-T03, RF-13): o dono escolhe o papel
/// ofertado (editor/leitor), gera o convite por link e copia/compartilha.
/// Apenas dono — acesso controlado pelo menu da tela da lista (doc 08 §1).
class SheetConvidar extends ConsumerStatefulWidget {
  const SheetConvidar({super.key, required this.listaId});

  final String listaId;

  @override
  ConsumerState<SheetConvidar> createState() => _SheetConvidarState();
}

class _SheetConvidarState extends ConsumerState<SheetConvidar> {
  Papel _papel = Papel.editor;
  bool _gerando = false;
  String? _erro;
  Convite? _convite;
  TextEditingController? _linkController;

  @override
  void dispose() {
    _linkController?.dispose();
    super.dispose();
  }

  Future<void> _gerar() async {
    setState(() {
      _erro = null;
      _gerando = true;
    });
    final repo = ref.read(convitesRepositoryProvider);
    try {
      final convite = await repo.criarLink(
        listaId: widget.listaId,
        papel: _papel,
      );
      if (mounted) {
        setState(() {
          _convite = convite;
          _linkController = TextEditingController(
            text: repo.linkConvite(convite.token),
          );
        });
      }
    } on ErroConvite catch (e) {
      if (mounted) setState(() => _erro = e.message);
    } catch (_) {
      if (mounted) setState(() => _erro = AppStrings.erroGenerico);
    }
    if (mounted) setState(() => _gerando = false);
  }

  Future<void> _copiar(String valor, String mensagem) async {
    await Clipboard.setData(ClipboardData(text: valor));
    if (mounted) {
      mostrarSnackBar(context, mensagem);
    }
  }

  @override
  Widget build(BuildContext context) {
    final convite = _convite;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  AppStrings.convidar,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: AppStrings.cancelar,
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          if (convite == null) ...[
            RadioGroup<Papel>(
              groupValue: _papel,
              onChanged: (papel) {
                if (papel != null) setState(() => _papel = papel);
              },
              child: Column(
                children: [
                  RadioListTile<Papel>(
                    title: const Text(AppStrings.convidarPapelEditor),
                    value: Papel.editor,
                  ),
                  RadioListTile<Papel>(
                    title: const Text(AppStrings.convidarPapelLeitor),
                    value: Papel.leitor,
                  ),
                ],
              ),
            ),
            if (_erro != null) ...[
              const SizedBox(height: AppSpacing.sm),
              AppBanner(tipo: AppBannerTipo.erro, mensagem: _erro!),
            ],
            const SizedBox(height: AppSpacing.lg),
            AppBotao(
              rotulo: AppStrings.gerarLink,
              carregando: _gerando,
              onPressed: _gerar,
            ),
          ] else ...[
            const SizedBox(height: AppSpacing.lg),
            TextField(readOnly: true, controller: _linkController!),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: AppBotao(
                    rotulo: AppStrings.copiarLink,
                    variante: AppBotaoVariante.outlined,
                    icone: Icons.copy_outlined,
                    onPressed: () => _copiar(
                      ref
                          .read(convitesRepositoryProvider)
                          .linkConvite(convite.token),
                      AppStrings.linkCopiado,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppBotao(
                    rotulo: AppStrings.copiarToken,
                    variante: AppBotaoVariante.outlined,
                    icone: Icons.copy_outlined,
                    onPressed: () =>
                        _copiar(convite.token, AppStrings.tokenCopiado),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            AppBotao(
              rotulo: AppStrings.compartilhar,
              variante: AppBotaoVariante.outlined,
              icone: Icons.share_outlined,
              onPressed: () => SharePlus.instance.share(
                ShareParams(
                  text: ref
                      .read(convitesRepositoryProvider)
                      .linkConvite(convite.token),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

Future<void> abrirSheetConvidar(
  BuildContext context,
  WidgetRef ref,
  String listaId,
) {
  return AppSheet.mostrar<void>(
    context,
    child: SheetConvidar(listaId: listaId),
  );
}
