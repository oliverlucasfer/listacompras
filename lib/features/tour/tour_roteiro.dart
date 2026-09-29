import '../../core/l10n/app_strings.dart';
import 'tour_keys.dart';
import 'tour_step.dart';

/// Roteiro da etapa 1 (primeiro contato, na home de listas): criar lista,
/// busca/filtros e configurações. Os demais recursos dependem da tela da lista
/// e vivem na etapa 2.
List<TourStep> get passosEtapa1 => <TourStep>[
  TourStep(
    id: 'lista.criar',
    alvo: TourKeys.novaLista,
    titulo: AppStrings.tourNovaListaTitulo,
    corpo: AppStrings.tourNovaListaCorpo,
  ),
  TourStep(
    id: 'lista.busca',
    alvo: TourKeys.lupa,
    titulo: AppStrings.tourBuscaTitulo,
    corpo: AppStrings.tourBuscaCorpo,
  ),
  TourStep(
    id: 'lista.config',
    alvo: TourKeys.abaConfiguracoes,
    titulo: AppStrings.tourConfigTitulo,
    corpo: AppStrings.tourConfigCorpo,
  ),
];

/// Roteiro da etapa 2 (ao abrir uma lista com itens pendentes): nome, adicionar,
/// unidade, importar, marcar/editar, modo mercado e orçamento/total.
List<TourStep> get passosEtapa2 => <TourStep>[
  TourStep(
    id: 'recursos.nome',
    alvo: TourKeys.nomeLista,
    titulo: AppStrings.tourNomeTitulo,
    corpo: AppStrings.tourNomeCorpo,
  ),
  TourStep(
    id: 'recursos.adicionar',
    alvo: TourKeys.campoAdicionar,
    titulo: AppStrings.tourAdicionarTitulo,
    corpo: AppStrings.tourAdicionarCorpo,
  ),
  TourStep(
    id: 'recursos.unidade',
    alvo: TourKeys.seletorUnidade,
    titulo: AppStrings.tourUnidadeTitulo,
    corpo: AppStrings.tourUnidadeCorpo,
  ),
  TourStep(
    id: 'recursos.importar',
    alvo: TourKeys.botaoImportar,
    titulo: AppStrings.tourImportarTitulo,
    corpo: AppStrings.tourImportarCorpo,
  ),
  TourStep(
    id: 'recursos.marcar',
    alvo: TourKeys.itemLista,
    titulo: AppStrings.tourMarcarTitulo,
    corpo: AppStrings.tourMarcarCorpo,
  ),
  TourStep(
    id: 'recursos.mercado',
    alvo: TourKeys.botaoMercado,
    titulo: AppStrings.tourMercadoTitulo,
    corpo: AppStrings.tourMercadoCorpo,
  ),
  TourStep(
    id: 'recursos.orcamento',
    alvo: TourKeys.menuMais,
    titulo: AppStrings.tourOrcamentoTitulo,
    corpo: AppStrings.tourOrcamentoCorpo,
  ),
];
