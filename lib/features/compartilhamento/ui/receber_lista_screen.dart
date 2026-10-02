import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/importacao/parser_lista_local.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/tokens/app_spacing.dart';
import '../../../core/widgets/app_banner.dart';
import '../../../core/widgets/app_botao.dart';
import '../../../core/widgets/app_campo_texto.dart';
import '../../listas/providers/listas_providers.dart';
import '../domain/codec_lista.dart';
import '../domain/lista_compartilhada.dart';
import '../providers/compartilhamento_providers.dart';
import 'modal_previsao_receber.dart';

/// Recebe uma lista compartilhada por código, texto, arquivo ou QR (RF-33).
/// Sempre cria uma **nova** lista local — nunca mescla com as existentes.
class ReceberListaScreen extends ConsumerStatefulWidget {
  const ReceberListaScreen({super.key});

  @override
  ConsumerState<ReceberListaScreen> createState() => _ReceberListaScreenState();
}

class _ReceberListaScreenState extends ConsumerState<ReceberListaScreen> {
  final _controller = TextEditingController();
  String? _erro;
  bool _carregando = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<ListaCompartilhada> _lerEntrada() async {
    final texto = _controller.text.trim();
    if (texto.startsWith(ListaCompartilhada.prefixo)) {
      return decodificarLista(texto);
    }
    if (texto.startsWith('{')) {
      try {
        final mapa = jsonDecode(texto);
        return ListaCompartilhada.fromJson(
          (mapa as Map).cast<String, dynamic>(),
        );
      } catch (_) {
        throw const CompartilhamentoInvalidoException('Arquivo inválido.');
      }
    }
    final parse = analisarListaLocal(texto);
    if (parse.itens.isEmpty) {
      throw const CompartilhamentoInvalidoException('');
    }
    final sugestao = ref.read(sugestaoCategoriasProvider);
    final titulo = context.l10n.listaCompartilhada;
    final itens = <ItemCompartilhado>[];
    var ordem = 0;
    for (final i in parse.itens) {
      itens.add(
        ItemCompartilhado(
          nome: i.nome,
          quantidade: i.quantidade,
          unidade: i.unidade,
          categoria: await sugestao.sugerirCategoria(i.nome),
          concluido: false,
          ordem: ordem++,
        ),
      );
    }
    return ListaCompartilhada(titulo: titulo, itens: itens);
  }

  Future<void> _confirmar() async {
    setState(() => _erro = null);
    final ListaCompartilhada entrada;
    try {
      entrada = await _lerEntrada();
    } on CompartilhamentoInvalidoException {
      if (mounted) setState(() => _erro = context.l10n.receberInvalido);
      return;
    } catch (_) {
      if (mounted) setState(() => _erro = context.l10n.erroGenerico);
      return;
    }
    if (!mounted) return;
    final previsao = await abrirPrevisaoReceber(context, entrada);
    if (previsao == null || !mounted) return;
    setState(() => _carregando = true);
    try {
      final lista = await ref
          .read(compartilhamentoRepositoryProvider)
          .importarLista(
            ListaCompartilhada(titulo: previsao.titulo, itens: previsao.itens),
            titulo: previsao.titulo,
          );
      if (mounted) context.go('/lista/${lista.id}');
    } catch (_) {
      if (mounted) setState(() => _erro = context.l10n.erroGenerico);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _arquivo() async {
    final String texto;
    try {
      final arquivo = await openFile();
      if (arquivo == null) return;
      texto = await arquivo.readAsString();
    } on FormatException {
      if (mounted) setState(() => _erro = context.l10n.receberInvalido);
      return;
    } catch (_) {
      if (mounted) setState(() => _erro = context.l10n.erroGenerico);
      return;
    }
    if (!mounted) return;
    _controller.text = texto;
    await _confirmar();
  }

  Future<void> _escanear() async {
    final String? codigo;
    try {
      codigo = await ref.read(leitorQrProvider).escanear(context);
    } catch (_) {
      if (mounted) setState(() => _erro = context.l10n.erroGenerico);
      return;
    }
    if (codigo == null || !mounted) return;
    _controller.text = codigo;
    await _confirmar();
  }

  @override
  Widget build(BuildContext context) {
    final comCamera = plataformaComCamera();
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.receberLista)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCampoTexto(
              controller: _controller,
              label: context.l10n.receberCodigoOuTexto,
              minLines: 5,
              maxLines: 8,
              onChanged: (_) => setState(() => _erro = null),
            ),
            if (_erro != null) ...[
              const SizedBox(height: AppSpacing.sm),
              AppBanner(tipo: AppBannerTipo.erro, mensagem: _erro!),
            ],
            const SizedBox(height: AppSpacing.md),
            AppBotao(
              rotulo: context.l10n.receberContinuar,
              carregando: _carregando,
              onPressed: _confirmar,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppBotao(
              rotulo: context.l10n.receberArquivo,
              variante: AppBotaoVariante.outlined,
              icone: Icons.folder_open,
              onPressed: _arquivo,
            ),
            if (comCamera) ...[
              const SizedBox(height: AppSpacing.sm),
              AppBotao(
                rotulo: context.l10n.escanearQr,
                variante: AppBotaoVariante.outlined,
                icone: Icons.qr_code_scanner,
                onPressed: _escanear,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
