import 'tour_keys.dart';
import 'tour_step.dart';

/// Roteiro da etapa 1 (primeiro contato, na home de listas): criar lista,
/// busca/filtros e configurações. Os demais recursos dependem da tela da lista
/// e vivem na etapa 2.
///
/// O roteiro guarda ids/alvos e funções de tradução — o texto localizado é
/// resolvido na UI (`context.l10n`), nunca embutido aqui (RF-39, F56).
List<TourStep> get passosEtapa1 => <TourStep>[
  TourStep(
    id: 'lista.criar',
    alvo: TourKeys.novaLista,
    titulo: (l) => l.tourNovaListaTitulo,
    corpo: (l) => l.tourNovaListaCorpo,
  ),
  TourStep(
    id: 'lista.busca',
    alvo: TourKeys.lupa,
    titulo: (l) => l.tourBuscaTitulo,
    corpo: (l) => l.tourBuscaCorpo,
  ),
  TourStep(
    id: 'lista.config',
    alvo: TourKeys.abaConfiguracoes,
    titulo: (l) => l.tourConfigTitulo,
    corpo: (l) => l.tourConfigCorpo,
  ),
];

/// Roteiro da etapa 2 (ao abrir uma lista com itens pendentes): nome, adicionar,
/// unidade, importar, marcar/editar, modo mercado e orçamento/total.
List<TourStep> get passosEtapa2 => <TourStep>[
  TourStep(
    id: 'recursos.nome',
    alvo: TourKeys.nomeLista,
    titulo: (l) => l.tourNomeTitulo,
    corpo: (l) => l.tourNomeCorpo,
  ),
  TourStep(
    id: 'recursos.adicionar',
    alvo: TourKeys.campoAdicionar,
    titulo: (l) => l.tourAdicionarTitulo,
    corpo: (l) => l.tourAdicionarCorpo,
  ),
  TourStep(
    id: 'recursos.unidade',
    alvo: TourKeys.seletorUnidade,
    titulo: (l) => l.tourUnidadeTitulo,
    corpo: (l) => l.tourUnidadeCorpo,
  ),
  TourStep(
    id: 'recursos.importar',
    alvo: TourKeys.botaoImportar,
    titulo: (l) => l.tourImportarTitulo,
    corpo: (l) => l.tourImportarCorpo,
  ),
  TourStep(
    id: 'recursos.marcar',
    alvo: TourKeys.itemLista,
    titulo: (l) => l.tourMarcarTitulo,
    corpo: (l) => l.tourMarcarCorpo,
  ),
  TourStep(
    id: 'recursos.mercado',
    alvo: TourKeys.botaoMercado,
    titulo: (l) => l.tourMercadoTitulo,
    corpo: (l) => l.tourMercadoCorpo,
  ),
  TourStep(
    id: 'recursos.orcamento',
    alvo: TourKeys.menuMais,
    titulo: (l) => l.tourOrcamentoTitulo,
    corpo: (l) => l.tourOrcamentoCorpo,
  ),
];

/// Roteiro da etapa 3 (ao abrir a aba Histórico): resumo das compras e a aba
/// de estatísticas. Resolve-se na UI via `context.l10n` (RF-39, F56).
List<TourStep> get passosEtapa3 => <TourStep>[
  TourStep(
    id: 'historico.resumo',
    alvo: TourKeys.resumoHistorico,
    titulo: (l) => l.tourResumoTitulo,
    corpo: (l) => l.tourResumoCorpo,
  ),
  TourStep(
    id: 'historico.estatisticas',
    alvo: TourKeys.abaEstatisticas,
    titulo: (l) => l.tourEstatisticasTitulo,
    corpo: (l) => l.tourEstatisticasCorpo,
  ),
];
