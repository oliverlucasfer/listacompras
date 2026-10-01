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
import '../../ocr/providers/ocr_providers.dart';

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
  bool _lendoFoto = false;
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
      !_lendoFoto &&
      _controller.text.trim().isNotEmpty &&
      _caracteres <= _limite;

  /// OCR on-device (RF-37): escolhe câmera/galeria, lê a imagem e preenche o
  /// campo editável. A imagem não é armazenada; só o texto entra no fluxo RF-16.
  Future<void> _lerFoto() async {
    final origem = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text(AppStrings.tirarFoto),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text(AppStrings.escolherDaGaleria),
              onTap: () => Navigator.pop(context, 'galeria'),
            ),
          ],
        ),
      ),
    );
    if (origem == null || !mounted) return;

    final fonte = ref.read(fonteImagemProvider);
    final caminho = origem == 'camera'
        ? await fonte.daCamera()
        : await fonte.daGaleria();
    if (caminho == null || !mounted) return;

    setState(() {
      _lendoFoto = true;
      _erro = null;
    });
    var texto = '';
    try {
      texto = await ref.read(ocrTextoProvider).extrair(caminho);
    } catch (_) {
      if (mounted) setState(() => _erro = AppStrings.ocrFalha);
      return;
    } finally {
      if (mounted) setState(() => _lendoFoto = false);
    }
    if (!mounted) return;

    if (texto.trim().isEmpty) {
      setState(() => _erro = AppStrings.ocrNenhumTexto);
    } else {
      _controller.text = _controller.text.trim().isEmpty
          ? texto
          : '${_controller.text}\n$texto';
    }
  }

  Future<void> _extrair() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final resposta = await _extrairLocal(_controller.text);
      if (mounted) Navigator.pop(context, resposta);
    } on ErroImportacao catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    } catch (_) {
      if (mounted) setState(() => _erro = AppStrings.erroGenerico);
    } finally {
      if (mounted) setState(() => _carregando = false);
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
      content: SingleChildScrollView(
        child: Column(
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
            if (plataformaComOcr()) ...[
              const SizedBox(height: AppSpacing.sm),
              AppBotao(
                rotulo: _lendoFoto ? AppStrings.ocrLendo : AppStrings.foto,
                icone: Icons.photo_camera_outlined,
                variante: AppBotaoVariante.outlined,
                carregando: _lendoFoto,
                onPressed: (_lendoFoto || _carregando) ? null : _lerFoto,
              ),
            ],
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
      ),
    );
  }
}
