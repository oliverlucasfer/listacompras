import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/importacao/parser_lista_local.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/tokens/app_spacing.dart';
import '../../../core/widgets/app_banner.dart';
import '../../../core/widgets/app_botao.dart';
import '../../../core/widgets/app_campo_texto.dart';
import '../../listas/providers/listas_providers.dart';
import '../domain/codec_lista.dart';
import '../domain/lista_compartilhada.dart';
import '../providers/compartilhamento_providers.dart';

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
    return ListaCompartilhada(
      titulo: AppStrings.listaCompartilhada,
      itens: itens,
    );
  }

  Future<void> _confirmar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final entrada = await _lerEntrada();
      final lista = await ref
          .read(compartilhamentoRepositoryProvider)
          .importarLista(entrada, titulo: entrada.titulo);
      if (mounted) context.go('/lista/${lista.id}');
    } on CompartilhamentoInvalidoException {
      if (mounted) setState(() => _erro = AppStrings.receberInvalido);
    } catch (_) {
      if (mounted) setState(() => _erro = AppStrings.erroGenerico);
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
      if (mounted) setState(() => _erro = AppStrings.receberInvalido);
      return;
    } catch (_) {
      if (mounted) setState(() => _erro = AppStrings.erroGenerico);
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
      if (mounted) setState(() => _erro = AppStrings.erroGenerico);
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
      appBar: AppBar(title: const Text(AppStrings.receberLista)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCampoTexto(
              controller: _controller,
              label: AppStrings.receberCodigoOuTexto,
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
              rotulo: AppStrings.receberConfirmar,
              carregando: _carregando,
              onPressed: _confirmar,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppBotao(
              rotulo: AppStrings.receberArquivo,
              variante: AppBotaoVariante.outlined,
              icone: Icons.folder_open,
              onPressed: _arquivo,
            ),
            if (comCamera) ...[
              const SizedBox(height: AppSpacing.sm),
              AppBotao(
                rotulo: AppStrings.escanearQr,
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
