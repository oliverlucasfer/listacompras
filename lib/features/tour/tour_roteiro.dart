import '../../core/l10n/app_strings.dart';
import 'tour_keys.dart';
import 'tour_step.dart';

/// Roteiro da etapa 1 (primeiro contato, sem dados): criar lista, nome e
/// orçamento, adicionar item, unidade, importar, busca e configurações.
List<TourStep> get passosEtapa1 => <TourStep>[
  TourStep(
    id: 'lista.criar',
    alvo: TourKeys.novaLista,
    titulo: AppStrings.tourNovaListaTitulo,
    corpo: AppStrings.tourNovaListaCorpo,
    elegivel: (cap) => true,
  ),
  TourStep(
    id: 'lista.nome',
    alvo: TourKeys.nomeLista,
    titulo: AppStrings.tourNomeTitulo,
    corpo: AppStrings.tourNomeCorpo,
    elegivel: (cap) => true,
  ),
  TourStep(
    id: 'lista.adicionar',
    alvo: TourKeys.campoAdicionar,
    titulo: AppStrings.tourAdicionarTitulo,
    corpo: AppStrings.tourAdicionarCorpo,
    elegivel: (cap) => true,
  ),
  TourStep(
    id: 'lista.unidade',
    alvo: TourKeys.seletorUnidade,
    titulo: AppStrings.tourUnidadeTitulo,
    corpo: AppStrings.tourUnidadeCorpo,
    elegivel: (cap) => true,
  ),
  TourStep(
    id: 'lista.importar',
    alvo: TourKeys.botaoImportar,
    titulo: AppStrings.tourImportarTitulo,
    corpo: AppStrings.tourImportarCorpo,
    elegivel: (cap) => true,
  ),
  TourStep(
    id: 'lista.busca',
    alvo: TourKeys.lupa,
    titulo: AppStrings.tourBuscaTitulo,
    corpo: AppStrings.tourBuscaCorpo,
    elegivel: (cap) => true,
  ),
  TourStep(
    id: 'lista.config',
    alvo: TourKeys.abaConfiguracoes,
    titulo: AppStrings.tourConfigTitulo,
    corpo: AppStrings.tourConfigCorpo,
    elegivel: (cap) => true,
  ),
];

/// Roteiro da etapa 2 (ao abrir uma lista com itens): marcar/editar, modo
/// mercado, orçamento/total e convite. O convite só existe no colaborativo;
/// mercado/orçamento/marcar são escondidos pela própria tela conforme o papel.
List<TourStep> get passosEtapa2 => <TourStep>[
  TourStep(
    id: 'recursos.marcar',
    alvo: TourKeys.itemLista,
    titulo: AppStrings.tourMarcarTitulo,
    corpo: AppStrings.tourMarcarCorpo,
    elegivel: (cap) => true,
  ),
  TourStep(
    id: 'recursos.mercado',
    alvo: TourKeys.botaoMercado,
    titulo: AppStrings.tourMercadoTitulo,
    corpo: AppStrings.tourMercadoCorpo,
    elegivel: (cap) => true,
  ),
  TourStep(
    id: 'recursos.orcamento',
    alvo: TourKeys.menuMais,
    titulo: AppStrings.tourOrcamentoTitulo,
    corpo: AppStrings.tourOrcamentoCorpo,
    elegivel: (cap) => true,
  ),
  TourStep(
    id: 'recursos.convite',
    alvo: TourKeys.acaoConvite,
    titulo: AppStrings.tourConviteTitulo,
    corpo: AppStrings.tourConviteCorpo,
    elegivel: (cap) => cap.colaboracao,
  ),
];
