import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dominio/categoria.dart';
import '../../../core/dominio/quantidade.dart';
import '../../../core/dominio/unidade.dart';
import '../../../core/l10n/categoria_l10n.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/tokens/app_spacing.dart';
import '../../../core/widgets/app_botao.dart';
import '../../../core/widgets/app_campo_texto.dart';
import '../../../core/widgets/app_dropdown.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../listas/domain/item.dart';
import '../../listas/domain/preco.dart';
import '../../listas/providers/listas_providers.dart';
import '../domain/etiqueta.dart';
import 'texto_lido_ocr.dart';

enum _Origem { novo, existente }

/// Preview editável da etiqueta lida (RF-40): cria um item novo com preço ou
/// aplica o preço a um item existente da lista. 100% local.
///
/// [etiqueta] é opcional: quando o OCR não reconhece preço, o preview ainda
/// abre (preço vazio) para mostrar o [textoBruto] lido e permitir corrigir.
class SheetEtiqueta extends ConsumerStatefulWidget {
  const SheetEtiqueta({
    super.key,
    required this.listaId,
    required this.textoBruto,
    this.etiqueta,
  });

  final String listaId;
  final String textoBruto;
  final EtiquetaLida? etiqueta;

  @override
  ConsumerState<SheetEtiqueta> createState() => _SheetEtiquetaState();
}

class _SheetEtiquetaState extends ConsumerState<SheetEtiqueta> {
  late final _nome = TextEditingController(text: widget.etiqueta?.nome ?? '');
  late final _quantidade = TextEditingController(text: '1');
  late final _preco = TextEditingController(
    text: widget.etiqueta == null
        ? ''
        : centavosParaTexto(widget.etiqueta!.precoCentavos),
  );
  late Unidade _unidade =
      widget.etiqueta?.precoPorKgCentavos != null &&
          widget.etiqueta!.precoPorKgCentavos == widget.etiqueta!.precoCentavos
      ? Unidade.kg
      : Unidade.un;
  CategoriaItem _categoria = CategoriaItem.outros;
  _Origem _origem = _Origem.novo;
  String? _itemId;
  String? _erroNome;
  String? _erroPreco;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _sugerirCategoria();
  }

  Future<void> _sugerirCategoria() async {
    final nome = widget.etiqueta?.nome;
    if (nome == null || nome.trim().isEmpty) return;
    final c = await ref.read(sugestaoCategoriasProvider).sugerirCategoria(nome);
    if (mounted) setState(() => _categoria = c);
  }

  @override
  void dispose() {
    _nome.dispose();
    _quantidade.dispose();
    _preco.dispose();
    super.dispose();
  }

  /// Validação do campo de preço: `valor` nulo com `invalido` falso = campo
  /// **vazio** (permitido no "Novo item"); `invalido` verdadeiro = texto não
  /// numérico (erro inline).
  ({int? valor, bool invalido}) _precoLido() {
    try {
      return (valor: parsePrecoParaCentavos(_preco.text), invalido: false);
    } on ArgumentError {
      return (valor: null, invalido: true);
    }
  }

  Future<void> _salvar() async {
    if (_salvando) return;
    final precoLido = _precoLido();
    final preco = precoLido.valor;
    final nome = _nome.text.trim();
    final quantidade = parseQuantidade(_quantidade.text) ?? 0;
    // "Item existente" precisa de um preço para aplicar; "Novo item" aceita
    // preço vazio e cria o item sem preço (RF-40).
    final exigePreco = _origem == _Origem.existente;
    setState(() {
      _erroNome = (_origem == _Origem.novo && nome.isEmpty)
          ? context.l10n.erroNomeVazio
          : null;
      _erroPreco = precoLido.invalido ? context.l10n.erroPrecoInvalido : null;
    });
    if (precoLido.invalido) return;
    if (exigePreco && preco == null) return;
    if (_origem == _Origem.novo && nome.isEmpty) return;
    if (_origem == _Origem.existente && _itemId == null) return;

    setState(() => _salvando = true);
    final repo = ref.read(itensRepositoryProvider);
    try {
      if (_origem == _Origem.novo) {
        await repo.adicionarItemDedup(
          listaId: widget.listaId,
          nome: nome,
          quantidade: quantidade > 0 ? quantidade : 1,
          unidade: _unidade,
          categoria: _categoria,
          precoCentavos: preco,
        );
      } else {
        await repo.editarItem(_itemId!, precoCentavos: preco);
      }
      if (!mounted) return;
      mostrarSnackBar(context, context.l10n.etiquetaAplicada);
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      setState(() => _salvando = false);
      mostrarSnackBar(context, context.l10n.erroGenerico);
    }
  }

  @override
  Widget build(BuildContext context) {
    final todos =
        ref.watch(itensDaListaProvider(widget.listaId)).value ?? const <Item>[];
    // Spec §4.3: pendentes primeiro (ordem estável dentro de cada grupo).
    final itens = <Item>[
      ...todos.where((i) => !i.concluido),
      ...todos.where((i) => i.concluido),
    ];
    // "Novo item" salva mesmo sem preço; "Item existente" só habilita "Aplicar"
    // quando há um item escolhido e um preço digitado.
    final podeAplicar =
        _origem == _Origem.novo ||
        (_itemId != null && _preco.text.trim().isNotEmpty);
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.etiquetaTitulo,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          SegmentedButton<_Origem>(
            segments: [
              ButtonSegment(
                value: _Origem.novo,
                label: Text(context.l10n.etiquetaNovoItem),
              ),
              ButtonSegment(
                value: _Origem.existente,
                label: Text(context.l10n.etiquetaItemExistente),
              ),
            ],
            selected: {_origem},
            onSelectionChanged: (s) => setState(() => _origem = s.first),
          ),
          const SizedBox(height: AppSpacing.md),
          if (_origem == _Origem.novo) ...[
            AppCampoTexto(
              controller: _nome,
              label: context.l10n.nomeDoItem,
              erro: _erroNome,
              onChanged: (_) => setState(() => _erroNome = null),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppCampoTexto(
                    controller: _quantidade,
                    label: context.l10n.quantidade,
                    teclado: TextInputType.text,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppDropdown<Unidade>(
                    label: context.l10n.unidade,
                    expandido: true,
                    valor: _unidade,
                    itens: [
                      for (final u in Unidade.values)
                        DropdownMenuItem(value: u, child: Text(u.valor)),
                    ],
                    onChanged: (u) {
                      if (u != null) setState(() => _unidade = u);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            AppDropdown<CategoriaItem>(
              label: context.l10n.categoria,
              expandido: true,
              valor: _categoria,
              itens: [
                for (final c in CategoriaItem.values)
                  DropdownMenuItem(value: c, child: Text(c.rotulo(context))),
              ],
              onChanged: (c) {
                if (c != null) setState(() => _categoria = c);
              },
            ),
            const SizedBox(height: AppSpacing.md),
          ] else
            AppDropdown<String>(
              label: context.l10n.etiquetaItemExistente,
              hint: context.l10n.etiquetaEscolherItem,
              expandido: true,
              valor: _itemId,
              itens: [
                for (final i in itens)
                  DropdownMenuItem(value: i.id, child: Text(i.nome)),
              ],
              onChanged: (id) => setState(() => _itemId = id),
            ),
          const SizedBox(height: AppSpacing.md),
          AppCampoTexto(
            controller: _preco,
            label: context.l10n.preco,
            erro: _erroPreco,
            teclado: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() => _erroPreco = null),
          ),
          TextoLidoOcr(texto: widget.textoBruto),
          const SizedBox(height: AppSpacing.lg),
          OverflowBar(
            alignment: MainAxisAlignment.end,
            spacing: AppSpacing.sm,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.l10n.cancelar),
              ),
              AppBotao(
                rotulo: _origem == _Origem.existente
                    ? context.l10n.etiquetaAplicar
                    : context.l10n.salvar,
                expandido: false,
                carregando: _salvando,
                onPressed: podeAplicar ? _salvar : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
