import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/widgets/erro_inline.dart';
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
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(mensagem)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final convite = _convite;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
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
              if (_erro != null) ErroInline(mensagem: _erro!),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _gerando ? null : _gerar,
                child: _gerando
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(AppStrings.gerarLink),
              ),
            ] else ...[
              const SizedBox(height: 16),
              TextField(
                readOnly: true,
                controller: _linkController!,
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.copy_outlined),
                      label: const Text(AppStrings.copiarLink),
                      onPressed: () => _copiar(
                        ref
                            .read(convitesRepositoryProvider)
                            .linkConvite(convite.token),
                        AppStrings.linkCopiado,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.copy_outlined),
                      label: const Text(AppStrings.copiarToken),
                      onPressed: () =>
                          _copiar(convite.token, AppStrings.tokenCopiado),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.share_outlined),
                label: const Text(AppStrings.compartilhar),
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
      ),
    );
  }
}

Future<void> abrirSheetConvidar(
  BuildContext context,
  WidgetRef ref,
  String listaId,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => SheetConvidar(listaId: listaId),
  );
}
