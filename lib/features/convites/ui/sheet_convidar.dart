import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/tokens/app_spacing.dart';
import '../../../core/widgets/app_banner.dart';
import '../../../core/widgets/app_botao.dart';
import '../../../core/widgets/app_campo_texto.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../sync/providers/sync_providers.dart';
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
  bool _revogando = false;
  String? _erro;
  Convite? _convite;
  TextEditingController? _linkController;
  List<Convite> _pendentes = const [];
  final _email = TextEditingController();
  bool _enviandoEmail = false;
  String? _erroEmail;

  @override
  void initState() {
    super.initState();
    // Convites criados antes nesta lista continuam válidos (R-07/F21-T03): o
    // dono precisa vê-los para revogar. Falha de rede não bloqueia o sheet —
    // só a ação de revogar sinaliza erro.
    _carregarPendentes();
  }

  @override
  void dispose() {
    _linkController?.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _carregarPendentes() async {
    try {
      final pendentes = await ref
          .read(convitesRepositoryProvider)
          .pendentesDaLista(widget.listaId);
      if (mounted) setState(() => _pendentes = pendentes);
    } on Object {
      // Silencioso: a listagem é auxiliar; gerar/revogar o link segue abaixo.
    }
  }

  Future<void> _revogarPendente(Convite convite) async {
    setState(() {
      _erro = null;
      _revogando = true;
    });
    try {
      await ref.read(convitesRepositoryProvider).revogar(convite.id);
      if (mounted) {
        setState(
          () =>
              _pendentes = _pendentes.where((c) => c.id != convite.id).toList(),
        );
        mostrarSnackBar(context, AppStrings.conviteRevogado);
      }
    } on Object {
      if (mounted) setState(() => _erro = AppStrings.erroGenerico);
    }
    if (mounted) setState(() => _revogando = false);
  }

  String _rotuloPapel(Papel papel) => switch (papel) {
    Papel.dono => AppStrings.papelDono,
    Papel.editor => AppStrings.convidarPapelEditor,
    Papel.leitor => AppStrings.convidarPapelLeitor,
  };

  Future<void> _gerar() async {
    setState(() {
      _erro = null;
      _gerando = true;
    });
    final repo = ref.read(convitesRepositoryProvider);
    try {
      // Pré-condição (F12-T02): flush best-effort para garantir que a lista
      // já exista no servidor antes de criar o convite (que é online-only).
      await ref.read(sincronizarAntesDeOperacaoProvider)();
    } on Object {
      // Falha de sync não impede a tentativa — o erro do INSERT orienta.
    }
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

  Future<void> _enviarConviteEmail() async {
    final email = _email.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() => _erroEmail = AppStrings.erroEmailInvalido);
      return;
    }
    setState(() {
      _erroEmail = null;
      _enviandoEmail = true;
    });
    try {
      await ref
          .read(convitesRepositoryProvider)
          .criarConviteEmail(
            listaId: widget.listaId,
            email: email,
            papel: _papel,
          );
      if (mounted) {
        mostrarSnackBar(context, AppStrings.conviteCriado);
        _email.clear();
      }
    } on ErroConvite catch (e) {
      if (mounted) setState(() => _erroEmail = e.message);
    } catch (_) {
      if (mounted) setState(() => _erroEmail = AppStrings.erroGenerico);
    }
    if (mounted) setState(() => _enviandoEmail = false);
  }

  Future<void> _copiar(String valor, String mensagem) async {
    await Clipboard.setData(ClipboardData(text: valor));
    if (mounted) {
      mostrarSnackBar(context, mensagem);
    }
  }

  /// Revoga o convite gerado (doc 08 §2, R-07): link vazado deixa de valer
  /// na hora; o sheet volta ao estado inicial para o dono gerar outro.
  Future<void> _revogar(Convite convite) async {
    setState(() {
      _erro = null;
      _revogando = true;
    });
    try {
      await ref.read(convitesRepositoryProvider).revogar(convite.id);
      if (mounted) {
        setState(() {
          _convite = null;
          _linkController?.dispose();
          _linkController = null;
        });
        mostrarSnackBar(context, AppStrings.conviteRevogado);
      }
    } on Object {
      if (mounted) setState(() => _erro = AppStrings.erroGenerico);
    }
    if (mounted) setState(() => _revogando = false);
  }

  Future<void> _compartilhar(Convite convite) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: ref.read(convitesRepositoryProvider).linkConvite(convite.token),
        ),
      );
      if (mounted) mostrarSnackBar(context, AppStrings.linkCompartilhado);
    } on MissingPluginException catch (_) {
      // Web Share API indisponível (desktop/alguns navegadores): orienta a
      // usar o botão "Copiar link" que já existe no sheet.
      if (mounted) {
        mostrarSnackBar(context, AppStrings.compartilharIndisponivel);
      }
    } on UnimplementedError catch (_) {
      if (mounted) {
        mostrarSnackBar(context, AppStrings.compartilharIndisponivel);
      }
    } catch (_) {
      if (mounted) {
        mostrarSnackBar(context, AppStrings.erroGenerico);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final convite = _convite;
    // O convite recém-gerado tem a própria área com link/compartilhar; não
    // duplica na lista de pendentes.
    final pendentesAnteriores = _pendentes
        .where((c) => c.id != convite?.id)
        .toList();
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
          if (pendentesAnteriores.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              AppStrings.convitesPendentes,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            for (final pendente in pendentesAnteriores)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.link),
                title: Text(_rotuloPapel(pendente.papelOferecido)),
                subtitle: const Text(AppStrings.convitePendenteAjuda),
                trailing: TextButton(
                  onPressed: _revogando
                      ? null
                      : () => _revogarPendente(pendente),
                  child: const Text(AppStrings.revogarConvitePendente),
                ),
              ),
          ],
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
            const SizedBox(height: AppSpacing.xl),
            Text(
              AppStrings.convidarPorEmail,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppCampoTexto(
              controller: _email,
              label: AppStrings.emailDoConvidado,
              erro: _erroEmail,
              teclado: TextInputType.emailAddress,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppBotao(
              rotulo: AppStrings.enviarConvite,
              variante: AppBotaoVariante.outlined,
              carregando: _enviandoEmail,
              onPressed: _enviarConviteEmail,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              AppStrings.conviteEmailAviso,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ] else ...[
            const SizedBox(height: AppSpacing.lg),
            AppCampoTexto(controller: _linkController, readOnly: true),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: Tooltip(
                    message: AppStrings.copiarLinkAjuda,
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
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Tooltip(
                    message: AppStrings.copiarCodigoAjuda,
                    child: AppBotao(
                      rotulo: AppStrings.copiarCodigo,
                      variante: AppBotaoVariante.outlined,
                      icone: Icons.copy_outlined,
                      onPressed: () =>
                          _copiar(convite.token, AppStrings.codigoCopiado),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            AppBotao(
              rotulo: AppStrings.compartilhar,
              variante: AppBotaoVariante.outlined,
              icone: Icons.share_outlined,
              onPressed: () => _compartilhar(convite),
            ),
            const SizedBox(height: AppSpacing.md),
            AppBotao(
              rotulo: AppStrings.revogarConvite,
              variante: AppBotaoVariante.texto,
              icone: Icons.link_off,
              carregando: _revogando,
              onPressed: () => _revogar(convite),
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
