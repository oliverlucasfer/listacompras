import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/importacao/parser_lista_local.dart';
import '../../../core/importacao/resposta_import.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/tokens/app_spacing.dart';
import '../../../core/widgets/app_banner.dart';
import '../../../core/widgets/app_botao.dart';
import '../../ia/domain/contrato_ia.dart';
import '../../ia/providers/ia_providers.dart';
import '../../listas/providers/listas_providers.dart';

/// Modo de importação (RF-16): Rápido = parser local offline; IA = Edge Function.
enum ModoImportacao { rapido, ia }

/// Abre o modal de entrada da importação de lista (doc 05 §6.4, RF-06/RF-16).
/// Retorna os itens extraídos, ou null se cancelado.
Future<RespostaParse?> abrirModalImportar(
  BuildContext context,
  WidgetRef ref,
  String listaId, {
  ModoImportacao modoInicial = ModoImportacao.rapido,
}) {
  return showDialog<RespostaParse>(
    context: context,
    builder: (_) => ModalImportar(listaId: listaId, modoInicial: modoInicial),
  );
}

class ModalImportar extends ConsumerStatefulWidget {
  const ModalImportar({
    super.key,
    required this.listaId,
    this.modoInicial = ModoImportacao.rapido,
  });

  final String listaId;
  final ModoImportacao modoInicial;

  @override
  ConsumerState<ModalImportar> createState() => _ModalImportarState();
}

class _ModalImportarState extends ConsumerState<ModalImportar> {
  final _controller = TextEditingController();
  late ModoImportacao _modo = widget.modoInicial;
  bool _carregando = false;
  String? _erro;

  int get _limite => _modo == ModoImportacao.rapido
      ? maxCaracteresImportLocal
      : maxCaracteresEntradaIa;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() => _erro = null));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int get _caracteres => _controller.text.length;

  bool get _podeExtrair =>
      !_carregando &&
      _controller.text.trim().isNotEmpty &&
      _caracteres <= _limite;

  Future<void> _extrair() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final resposta = _modo == ModoImportacao.rapido
          ? await _extrairLocal(_controller.text)
          : await ref.read(parseListaClientProvider).parse(_controller.text);
      if (mounted) Navigator.pop(context, resposta);
    } on ErroIa catch (e) {
      if (mounted) {
        setState(() {
          _carregando = false;
          _erro = e.mensagem;
        });
      }
    }
  }

  /// Parser local + categoria pela cadeia do app (memória → dicionário).
  Future<RespostaParse> _extrairLocal(String texto) async {
    final parse = analisarListaLocal(texto);
    if (parse.itens.isEmpty) {
      throw const ErroIa('resposta_invalida', AppStrings.iaRespostaInvalida);
    }
    final sugestao = ref.read(sugestaoCategoriasProvider);
    final enriquecidos = <ItemExtraido>[];
    for (final item in parse.itens) {
      final categoria = await sugestao.sugerirCategoria(item.nome);
      enriquecidos.add(
        ItemExtraido(
          nome: item.nome,
          quantidade: item.quantidade,
          unidade: item.unidade,
          categoria: categoria,
        ),
      );
    }
    return RespostaParse(itens: enriquecidos, aviso: parse.aviso);
  }

  @override
  Widget build(BuildContext context) {
    final excedeu = _caracteres > _limite;
    return AlertDialog(
      title: Row(
        children: [
          const Expanded(child: Text(AppStrings.importarLista)),
          IconButton(
            tooltip: AppStrings.fechar,
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<ModoImportacao>(
            segments: const [
              ButtonSegment(
                value: ModoImportacao.rapido,
                label: Text(AppStrings.modoRapido),
                icon: Icon(Icons.bolt_outlined),
              ),
              ButtonSegment(
                value: ModoImportacao.ia,
                label: Text(AppStrings.modoIa),
                icon: Icon(Icons.auto_awesome),
              ),
            ],
            selected: {_modo},
            onSelectionChanged: (s) => setState(() {
              _modo = s.first;
              _erro = null;
            }),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(AppStrings.iaColeOuDigite),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _controller,
            minLines: 5,
            maxLines: 5,
            keyboardType: TextInputType.multiline,
            decoration: const InputDecoration(hintText: AppStrings.iaExemplo),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '$_caracteres/$_limite',
              style: excedeu
                  ? TextStyle(color: Theme.of(context).colorScheme.error)
                  : null,
            ),
          ),
          if (_erro != null) ...[
            const SizedBox(height: AppSpacing.sm),
            AppBanner(tipo: AppBannerTipo.erro, mensagem: _erro!),
          ],
          const SizedBox(height: AppSpacing.md),
          AppBotao(
            rotulo: _carregando
                ? AppStrings.iaLendo
                : AppStrings.iaExtrairItens,
            icone: _modo == ModoImportacao.ia
                ? Icons.auto_awesome
                : Icons.bolt_outlined,
            carregando: _carregando,
            onPressed: _podeExtrair ? _extrair : null,
          ),
        ],
      ),
    );
  }
}
