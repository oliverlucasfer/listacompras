part of 'tela_lista_screen.dart';

class _CampoAdicionar extends ConsumerStatefulWidget {
  const _CampoAdicionar({
    required this.listaId,
    this.autofocus = false,
    this.onItemAdicionado,
  });

  final String listaId;
  final bool autofocus;
  final VoidCallback? onItemAdicionado;

  @override
  ConsumerState<_CampoAdicionar> createState() => _CampoAdicionarState();
}

class _CampoAdicionarState extends ConsumerState<_CampoAdicionar> {
  final _controller = TextEditingController();

  /// Unidade usada quando o texto digitado não traz uma (F12-T06).
  Unidade _unidade = Unidade.un;

  /// Erro inline quando o parser descarta o texto digitado (F14-T07).
  String? _erro;

  /// Estado da captura por voz no campo (RF-26, F30-T02).
  EstadoVoz _estadoVoz = EstadoVoz.parado;

  /// Sessão de voz iniciada e ainda não concluída. Fica `true` **antes** de
  /// aguardar `iniciar` para cobrir a janela em que a tela é desmontada com o
  /// `iniciar` ainda no ar e `_estadoVoz` ainda em `parado` (RF-26).
  bool _sessaoVozAtiva = false;

  /// Reconhecedor capturado no `initState` para poder cancelar no `dispose`
  /// sem tocar no `ref` de um elemento já em desmontagem. Só é resolvido em
  /// Android/iOS — Web/Desktop escondem o botão e não instanciam o plugin.
  ReconhecimentoVoz? _voz;

  @override
  void initState() {
    super.initState();
    if (plataformaComVoz()) _voz = ref.read(reconhecimentoVozProvider);
  }

  @override
  void dispose() {
    // Sair da tela durante o ditado cancela o reconhecimento para não deixar
    // o microfone quente (RF-26). A flag cobre o `iniciar` ainda pendente.
    final voz = _voz;
    if (voz != null && (_sessaoVozAtiva || _estadoVoz == EstadoVoz.ouvindo)) {
      unawaited(voz.cancelar());
    }
    _controller.dispose();
    super.dispose();
  }

  void _aoEstadoVoz(EstadoVoz estado) {
    if (estado == EstadoVoz.indisponivel ||
        (estado == EstadoVoz.parado && _estadoVoz == EstadoVoz.ouvindo)) {
      _sessaoVozAtiva = false;
    }
    if (mounted) setState(() => _estadoVoz = estado);
  }

  Future<void> _ditar() async {
    final voz = _voz;
    if (voz == null) return;
    if (_estadoVoz == EstadoVoz.ouvindo) {
      await voz.parar();
      _sessaoVozAtiva = false;
      return;
    }
    _sessaoVozAtiva = true;
    final iniciou = await voz.iniciar(
      onTexto: (texto, _) {
        if (!mounted) return;
        setState(() {
          _controller.text = texto;
          _erro = null;
        });
      },
      onIndisponivel: () {
        if (mounted) mostrarSnackBar(context, context.l10n.vozIndisponivel);
      },
      onEstado: _aoEstadoVoz,
    );
    if (!iniciou) _sessaoVozAtiva = false;
  }

  Future<void> _adicionar() async {
    final texto = _controller.text.trim();
    if (texto.isEmpty) return;
    // Reconhece "1kg de banana" → Banana, 1 kg (F12-T06); sem unidade no
    // texto, aplica a unidade escolhida no seletor.
    final extra = interpretarItemAvulso(texto, unidadePadrao: _unidade);
    if (extra == null) {
      // Texto só com pontuação/separador: nada foi reconhecido (F14-T07).
      setState(() => _erro = context.l10n.naoEntendiItem);
      return;
    }
    await _adicionarItemDedup(
      nome: extra.nome,
      quantidade: extra.quantidade,
      unidade: extra.unidade,
    );
    _controller.clear();
    if (mounted) widget.onItemAdicionado?.call();
  }

  /// Núcleo de escrita compartilhado por `_adicionar` (entrada rápida) e
  /// `_adicionarSugerido` (chip, RF-19): delega a dedup ao repositório (RF-10).
  /// A sugestão de categoria continua aqui, na cadeia local (F6-T03).
  Future<void> _adicionarItemDedup({
    required String nome,
    required double quantidade,
    required Unidade unidade,
  }) async {
    final categoria = await ref
        .read(sugestaoCategoriasProvider)
        .sugerirCategoria(nome);
    final resultado = await ref
        .read(listasRepositoryProvider)
        .adicionarItemDedup(
          listaId: widget.listaId,
          nome: nome,
          quantidade: quantidade,
          unidade: unidade,
          categoria: categoria,
        );
    if (!mounted) return;
    switch (resultado) {
      case ResultadoDedup.somado:
        mostrarSnackBar(context, '$nome ${context.l10n.itemDuplicadoSomado}');
      case ResultadoDedup.substituido:
        mostrarSnackBar(context, '$nome: ${context.l10n.itemAtualizado}');
      case ResultadoDedup.adicionado:
        break;
    }
  }

  /// Adiciona um item a partir do chip de sugestão (RF-19), reaproveitando
  /// a mesma deduplicação da entrada rápida (evita duplicar um nome já
  /// concluído na lista aberta, que também vira sugestão).
  Future<void> _adicionarSugerido(String nome) async {
    await _adicionarItemDedup(nome: nome, quantidade: 1, unidade: Unidade.un);
    _controller.clear();
    if (mounted) {
      setState(() {});
      widget.onItemAdicionado?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_controller.text.trim().isEmpty)
            _ChipsSugestoes(
              listaId: widget.listaId,
              onAdicionar: _adicionarSugerido,
            ),
          AppCampoTexto(
            key: TourKeys.campoAdicionar,
            controller: _controller,
            label: context.l10n.adicionarItem,
            erro: _erro,
            autofocus: widget.autofocus,
            onChanged: (_) => setState(() => _erro = null),
            onSubmitted: _adicionar,
            sufixo: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: PopupMenuButton<Unidade>(
                    key: TourKeys.seletorUnidade,
                    tooltip: context.l10n.unidade,
                    initialValue: _unidade,
                    onSelected: (u) => setState(() => _unidade = u),
                    itemBuilder: (context) => [
                      for (final u in Unidade.values)
                        PopupMenuItem(value: u, child: Text(u.valor)),
                    ],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              _unidade.valor,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down),
                        ],
                      ),
                    ),
                  ),
                ),
                if (plataformaComVoz())
                  IconButton(
                    tooltip: context.l10n.ditarItem,
                    icon: Icon(
                      _estadoVoz == EstadoVoz.ouvindo
                          ? Icons.mic
                          : Icons.mic_none,
                    ),
                    onPressed: _ditar,
                  ),
                IconButton(
                  tooltip: context.l10n.adicionarItem,
                  icon: const Icon(Icons.add),
                  onPressed: _adicionar,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Chips de itens frequentes sugeridos (RF-19). Assina o ranking apenas
/// enquanto montado — `_CampoAdicionar` só o insere com o campo vazio.
class _ChipsSugestoes extends ConsumerWidget {
  const _ChipsSugestoes({required this.listaId, required this.onAdicionar});

  final String listaId;
  final ValueChanged<String> onAdicionar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sugestoes =
        ref.watch(itensFrequentesProvider(listaId)).value ??
        const <SugestaoItem>[];
    if (sugestoes.isEmpty) return const SizedBox.shrink();
    return Semantics(
      label: context.l10n.sugestoes,
      child: SizedBox(
        height: 48,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: sugestoes.length,
          separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
          itemBuilder: (context, i) {
            final s = sugestoes[i];
            return Semantics(
              button: true,
              label: context.l10n.adicionarSugerido(s.nome),
              // Exclui a semântica própria do chip para não anunciar o rótulo
              // duas vezes (nó único com o label "Adicionar <nome>").
              child: ExcludeSemantics(
                child: ActionChip(
                  label: Text(s.nome),
                  onPressed: () => onAdicionar(s.nome),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
