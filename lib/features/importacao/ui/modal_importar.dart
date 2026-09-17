import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/importacao/erro_importacao.dart';
import '../../../core/importacao/parser_lista_local.dart';
import '../../../core/importacao/resposta_import.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/tokens/app_spacing.dart';
import '../../../core/widgets/app_banner.dart';
import '../../../core/widgets/app_botao.dart';
import '../../../core/widgets/app_campo_texto.dart';
import '../../listas/providers/listas_providers.dart';

/// Abre o modal de entrada da importação de lista (doc 04, wireframe 10 §4.1,
/// RF-16). Retorna os itens extraídos, ou null se cancelado.
Future<RespostaParse?> abrirModalImportar(
  BuildContext context,
  WidgetRef ref,
  String listaId,
) {
  return showDialog<RespostaParse>(
    context: context,
    builder: (_) => ModalImportar(listaId: listaId),
  );
}

class ModalImportar extends ConsumerStatefulWidget {
  const ModalImportar({super.key, required this.listaId});

  final String listaId;

  @override
  ConsumerState<ModalImportar> createState() => _ModalImportarState();
}

class _ModalImportarState extends ConsumerState<ModalImportar> {
  final _controller = TextEditingController();
  bool _carregando = false;
  String? _erro;

  int get _limite => maxCaracteresImportLocal;

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
      final resposta = await _extrairLocal(_controller.text);
      if (mounted) Navigator.pop(context, resposta);
    } on ErroImportacao catch (e) {
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
      throw const ErroImportacao(AppStrings.importRespostaInvalida);
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
          const Text(AppStrings.importColeOuDigite),
          const SizedBox(height: AppSpacing.sm),
          AppCampoTexto(
            controller: _controller,
            hint: AppStrings.importExemplo,
            teclado: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            maxLength: _limite,
            minLines: 5,
            maxLines: 5,
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
                ? AppStrings.importLendo
                : AppStrings.importExtrairItens,
            icone: Icons.bolt_outlined,
            carregando: _carregando,
            onPressed: _podeExtrair ? _extrair : null,
          ),
        ],
      ),
    );
  }
}
