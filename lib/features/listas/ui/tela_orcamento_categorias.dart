import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dominio/categoria.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/tokens/app_spacing.dart';
import '../../../core/widgets/app_botao.dart';
import '../../../core/widgets/app_campo_texto.dart';
import '../../../core/widgets/app_esqueleto.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../domain/preco.dart';
import '../providers/listas_providers.dart';

/// Tela "Orçamento por categoria" (RF-36, F53-T04): define um limite em R\$
/// para cada categoria; campo vazio remove o limite. Acessível de Configurações.
class TelaOrcamentoCategorias extends ConsumerWidget {
  const TelaOrcamentoCategorias({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final limitesAsync = ref.watch(limitesCategoriaProvider);
    final limites = limitesAsync.value;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.l10n.orcamentoPorCategoria,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: limites == null
          ? const AppEsqueleto(linhas: 6)
          : ListView(
              children: [
                for (final categoria in CategoriaItem.values)
                  _LinhaLimiteCategoria(
                    key: ValueKey(categoria.valor),
                    categoria: categoria,
                    inicialCentavos: limites[categoria],
                  ),
              ],
            ),
    );
  }
}

class _LinhaLimiteCategoria extends ConsumerStatefulWidget {
  const _LinhaLimiteCategoria({
    super.key,
    required this.categoria,
    required this.inicialCentavos,
  });

  final CategoriaItem categoria;

  /// Limite salvo ao montar a linha; `null` = categoria sem limite.
  final int? inicialCentavos;

  @override
  ConsumerState<_LinhaLimiteCategoria> createState() =>
      _LinhaLimiteCategoriaState();
}

class _LinhaLimiteCategoriaState extends ConsumerState<_LinhaLimiteCategoria> {
  late final _campo = TextEditingController(
    text: widget.inicialCentavos == null
        ? ''
        : formatarReais(widget.inicialCentavos!),
  );
  String? _erro;
  bool _ocupado = false;

  @override
  void dispose() {
    _campo.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    var texto = _campo.text.trim();
    int? centavos;
    if (texto.isNotEmpty) {
      try {
        centavos = parsePrecoParaCentavos(texto);
      } on ArgumentError {
        setState(() => _erro = context.l10n.erroOrcamentoInvalido);
        return;
      }
    }
    await _gravar(centavos);
  }

  Future<void> _limpar() async {
    _campo.clear();
    await _gravar(null);
  }

  Future<void> _gravar(int? centavos) async {
    setState(() {
      _erro = null;
      _ocupado = true;
    });
    try {
      await ref
          .read(limitesCategoriaRepositoryProvider)
          .definir(widget.categoria, centavos: centavos);
    } catch (_) {
      if (mounted) {
        setState(() {
          _erro = context.l10n.erroGenerico;
          _ocupado = false;
        });
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _ocupado = false;
      if (centavos == null) _campo.clear();
    });
    mostrarSnackBar(context, context.l10n.orcamentosSalvos);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        0,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.categoria.rotulo,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            AppCampoTexto(
              controller: _campo,
              label: context.l10n.limitePorCategoria,
              hint: context.l10n.categoriaSemLimite,
              erro: _erro,
              teclado: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) {
                if (_erro != null) setState(() => _erro = null);
              },
              onSubmitted: _salvar,
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (widget.inicialCentavos != null)
                  TextButton(
                    onPressed: _ocupado ? null : _limpar,
                    child: Text(context.l10n.limpar),
                  ),
                const SizedBox(width: AppSpacing.sm),
                AppBotao(
                  rotulo: context.l10n.salvar,
                  expandido: false,
                  carregando: _ocupado,
                  onPressed: _salvar,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
