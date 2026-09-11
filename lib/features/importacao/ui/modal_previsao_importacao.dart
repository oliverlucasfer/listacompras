import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/importacao/resposta_import.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/tokens/app_spacing.dart';
import '../../../core/widgets/app_banner.dart';
import '../../../core/widgets/app_botao.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../listas/domain/categoria.dart';
import '../../listas/domain/unidade.dart';
import '../../listas/providers/listas_providers.dart';

/// Abre o modal de pré-visualização (doc 05 §6.4, wireframe 10 §4.2, RF-06)
/// e grava os itens confirmados via repositório local (fila de INSERTs).
/// Cancelar não grava nada.
Future<void> confirmarItensImportados(
  BuildContext context,
  WidgetRef ref,
  String listaId,
  RespostaParse resposta,
) async {
  final selecionados = await showDialog<List<ItemExtraido>>(
    context: context,
    builder: (_) => ModalPrevisaoImportacao(resposta: resposta),
  );
  if (selecionados == null || selecionados.isEmpty || !context.mounted) return;
  final repo = ref.read(listasRepositoryProvider);
  for (final item in selecionados) {
    await repo.adicionarItem(
      listaId: listaId,
      nome: item.nome,
      quantidade: item.quantidade,
      unidade: item.unidade,
      categoria: item.categoria,
    );
  }
  if (context.mounted) {
    mostrarSnackBar(context, AppStrings.itensExtraidos(selecionados.length));
  }
}

class ModalPrevisaoImportacao extends StatefulWidget {
  const ModalPrevisaoImportacao({super.key, required this.resposta});

  final RespostaParse resposta;

  @override
  State<ModalPrevisaoImportacao> createState() =>
      _ModalPrevisaoImportacaoState();
}

class _Linha {
  _Linha(ItemExtraido item)
    : nome = item.nome,
      quantidade = item.quantidade,
      unidade = item.unidade,
      categoria = item.categoria;

  String nome;
  double quantidade;
  Unidade unidade;
  CategoriaItem categoria;
  bool incluir = true;
  bool editando = false;
}

class _ModalPrevisaoImportacaoState extends State<ModalPrevisaoImportacao> {
  late final List<_Linha> _linhas = [
    for (final item in widget.resposta.itens) _Linha(item),
  ];

  List<ItemExtraido> get _selecionados => [
    for (final linha in _linhas)
      if (linha.incluir && linha.nome.trim().isNotEmpty)
        ItemExtraido(
          nome: linha.nome.trim(),
          quantidade: linha.quantidade,
          unidade: linha.unidade,
          categoria: linha.categoria,
        ),
  ];

  @override
  Widget build(BuildContext context) {
    final selecionados = _selecionados;
    return AlertDialog(
      title: Row(
        children: [
          const Expanded(child: Text(AppStrings.iaConfirmeItens)),
          IconButton(
            tooltip: AppStrings.fechar,
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.resposta.aviso != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: AppBanner(
                  tipo: AppBannerTipo.aviso,
                  mensagem: widget.resposta.aviso!,
                ),
              ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (var i = 0; i < _linhas.length; i++) ...[
                    _LinhaItem(
                      linha: _linhas[i],
                      onIncluir: (v) =>
                          setState(() => _linhas[i].incluir = v ?? false),
                      onAlternarEdicao: () => setState(
                        () => _linhas[i].editando = !_linhas[i].editando,
                      ),
                    ),
                    if (_linhas[i].editando)
                      _PainelEdicao(
                        linha: _linhas[i],
                        onAlterar: (nome, quantidade, unidade, categoria) =>
                            setState(() {
                              _linhas[i]
                                ..nome = nome
                                ..quantidade = quantidade
                                ..unidade = unidade
                                ..categoria = categoria;
                            }),
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              AppStrings.iaSeraoAdicionados(
                selecionados.length,
                _linhas.length,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(AppStrings.cancelar),
        ),
        AppBotao(
          rotulo: AppStrings.iaAdicionarN(selecionados.length),
          expandido: false,
          onPressed: selecionados.isEmpty
              ? null
              : () => Navigator.pop(context, selecionados),
        ),
      ],
    );
  }
}

class _LinhaItem extends StatelessWidget {
  const _LinhaItem({
    required this.linha,
    required this.onIncluir,
    required this.onAlternarEdicao,
  });

  final _Linha linha;
  final ValueChanged<bool?> onIncluir;
  final VoidCallback onAlternarEdicao;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Checkbox(value: linha.incluir, onChanged: onIncluir),
      title: Text(linha.nome),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${_formatarQuantidade(linha.quantidade)} ${linha.unidade.valor}',
          ),
          IconButton(
            tooltip: AppStrings.editarItem,
            icon: Icon(linha.editando ? Icons.expand_less : Icons.expand_more),
            onPressed: onAlternarEdicao,
          ),
        ],
      ),
    );
  }
}

/// Edição inline de nome/quantidade/unidade/categoria (doc 05 §6.4).
class _PainelEdicao extends StatefulWidget {
  const _PainelEdicao({required this.linha, required this.onAlterar});

  final _Linha linha;
  final void Function(
    String nome,
    double quantidade,
    Unidade unidade,
    CategoriaItem categoria,
  )
  onAlterar;

  @override
  State<_PainelEdicao> createState() => _PainelEdicaoState();
}

class _PainelEdicaoState extends State<_PainelEdicao> {
  late final _nome = TextEditingController(text: widget.linha.nome);
  late final _quantidade = TextEditingController(
    text: _formatarQuantidade(widget.linha.quantidade),
  );
  late Unidade _unidade = widget.linha.unidade;
  late CategoriaItem _categoria = widget.linha.categoria;

  @override
  void dispose() {
    _nome.dispose();
    _quantidade.dispose();
    super.dispose();
  }

  double? _quantidadeLida() {
    final valor = double.tryParse(_quantidade.text.trim().replaceAll(',', '.'));
    if (valor == null || valor <= 0) return null;
    return valor;
  }

  void _notificar({double? quantidade}) {
    widget.onAlterar(
      _nome.text,
      quantidade ?? _quantidadeLida() ?? widget.linha.quantidade,
      _unidade,
      _categoria,
    );
  }

  void _passo(int delta) {
    final novo = (_quantidadeLida() ?? 1) + delta;
    if (novo <= 0) return;
    setState(() => _quantidade.text = _formatarQuantidade(novo));
    _notificar(quantidade: novo);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(48, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _nome,
            onChanged: (_) => _notificar(),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                tooltip: AppStrings.diminuir,
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () => _passo(-1),
              ),
              Expanded(
                child: TextField(
                  controller: _quantidade,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textAlign: TextAlign.center,
                  onChanged: (_) => _notificar(),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              IconButton(
                tooltip: AppStrings.aumentar,
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => _passo(1),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<Unidade>(
                  initialValue: _unidade,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    for (final u in Unidade.values)
                      DropdownMenuItem(value: u, child: Text(u.valor)),
                  ],
                  onChanged: (u) {
                    if (u == null) return;
                    setState(() => _unidade = u);
                    _notificar();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Categoria (F6-T05, spec §5.2): sugestão da IA editável antes
          // de gravar na lista.
          DropdownButtonFormField<CategoriaItem>(
            initialValue: _categoria,
            decoration: const InputDecoration(
              labelText: AppStrings.categoria,
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              for (final c in CategoriaItem.values)
                DropdownMenuItem(value: c, child: Text(c.rotulo)),
            ],
            onChanged: (c) {
              if (c == null) return;
              setState(() => _categoria = c);
              _notificar();
            },
          ),
        ],
      ),
    );
  }
}

String _formatarQuantidade(double q) =>
    q == q.roundToDouble() ? q.toInt().toString() : q.toString();
