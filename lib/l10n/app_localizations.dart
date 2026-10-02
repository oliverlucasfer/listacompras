import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('pt'),
    Locale('en'),
    Locale('es'),
  ];

  /// No description provided for @appNome.
  ///
  /// In pt, this message translates to:
  /// **'Minhas Listas'**
  String get appNome;

  /// No description provided for @erroGenerico.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível concluir. Tente novamente.'**
  String get erroGenerico;

  /// No description provided for @minhasListas.
  ///
  /// In pt, this message translates to:
  /// **'Minhas Listas'**
  String get minhasListas;

  /// No description provided for @abaMinhas.
  ///
  /// In pt, this message translates to:
  /// **'Minhas'**
  String get abaMinhas;

  /// No description provided for @novaLista.
  ///
  /// In pt, this message translates to:
  /// **'Nova lista'**
  String get novaLista;

  /// No description provided for @salvar.
  ///
  /// In pt, this message translates to:
  /// **'Salvar'**
  String get salvar;

  /// No description provided for @cancelar.
  ///
  /// In pt, this message translates to:
  /// **'Cancelar'**
  String get cancelar;

  /// No description provided for @renomear.
  ///
  /// In pt, this message translates to:
  /// **'Renomear'**
  String get renomear;

  /// No description provided for @excluir.
  ///
  /// In pt, this message translates to:
  /// **'Excluir'**
  String get excluir;

  /// No description provided for @mostrarArquivadas.
  ///
  /// In pt, this message translates to:
  /// **'Mostrar arquivadas'**
  String get mostrarArquivadas;

  /// No description provided for @arquivar.
  ///
  /// In pt, this message translates to:
  /// **'Arquivar'**
  String get arquivar;

  /// No description provided for @desarquivar.
  ///
  /// In pt, this message translates to:
  /// **'Desarquivar'**
  String get desarquivar;

  /// No description provided for @arquivada.
  ///
  /// In pt, this message translates to:
  /// **'Arquivada'**
  String get arquivada;

  /// No description provided for @listaArquivada.
  ///
  /// In pt, this message translates to:
  /// **'Lista arquivada.'**
  String get listaArquivada;

  /// No description provided for @listaDesarquivada.
  ///
  /// In pt, this message translates to:
  /// **'Lista desarquivada.'**
  String get listaDesarquivada;

  /// No description provided for @adicionarItem.
  ///
  /// In pt, this message translates to:
  /// **'Adicionar item'**
  String get adicionarItem;

  /// No description provided for @itensConcluidos.
  ///
  /// In pt, this message translates to:
  /// **'Itens concluídos'**
  String get itensConcluidos;

  /// No description provided for @reordenar.
  ///
  /// In pt, this message translates to:
  /// **'Reordenar'**
  String get reordenar;

  /// No description provided for @sugestoes.
  ///
  /// In pt, this message translates to:
  /// **'Sugestões'**
  String get sugestoes;

  /// No description provided for @ditarItem.
  ///
  /// In pt, this message translates to:
  /// **'Ditar item'**
  String get ditarItem;

  /// No description provided for @vozIndisponivel.
  ///
  /// In pt, this message translates to:
  /// **'Reconhecimento de voz indisponível neste aparelho.'**
  String get vozIndisponivel;

  /// No description provided for @adicionarSugerido.
  ///
  /// In pt, this message translates to:
  /// **'Adicionar {nome}'**
  String adicionarSugerido(String nome);

  /// No description provided for @modoMercado.
  ///
  /// In pt, this message translates to:
  /// **'Modo mercado'**
  String get modoMercado;

  /// No description provided for @mercadoProgresso.
  ///
  /// In pt, this message translates to:
  /// **'{marcados} de {total}'**
  String mercadoProgresso(int marcados, int total);

  /// No description provided for @mercadoMarcados.
  ///
  /// In pt, this message translates to:
  /// **'Marcados'**
  String get mercadoMarcados;

  /// No description provided for @mercadoTudoComprado.
  ///
  /// In pt, this message translates to:
  /// **'Tudo comprado!'**
  String get mercadoTudoComprado;

  /// No description provided for @voltarParaLista.
  ///
  /// In pt, this message translates to:
  /// **'Voltar para a lista'**
  String get voltarParaLista;

  /// No description provided for @nenhumaLista.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma lista por aqui'**
  String get nenhumaLista;

  /// No description provided for @criePrimeiraLista.
  ///
  /// In pt, this message translates to:
  /// **'Crie sua primeira lista ou importe por texto.'**
  String get criePrimeiraLista;

  /// No description provided for @criarPrimeiraLista.
  ///
  /// In pt, this message translates to:
  /// **'Criar primeira lista'**
  String get criarPrimeiraLista;

  /// No description provided for @nomeDaLista.
  ///
  /// In pt, this message translates to:
  /// **'Nome da lista'**
  String get nomeDaLista;

  /// No description provided for @criarLista.
  ///
  /// In pt, this message translates to:
  /// **'Criar lista'**
  String get criarLista;

  /// No description provided for @renomearLista.
  ///
  /// In pt, this message translates to:
  /// **'Renomear lista'**
  String get renomearLista;

  /// No description provided for @listaCriada.
  ///
  /// In pt, this message translates to:
  /// **'Lista criada.'**
  String get listaCriada;

  /// No description provided for @listaRenomeada.
  ///
  /// In pt, this message translates to:
  /// **'Lista renomeada.'**
  String get listaRenomeada;

  /// No description provided for @comprarDeNovo.
  ///
  /// In pt, this message translates to:
  /// **'Comprar de novo'**
  String get comprarDeNovo;

  /// No description provided for @duplicarDescricao.
  ///
  /// In pt, this message translates to:
  /// **'{n, plural, =1{1 item pendente será copiado.} other{{n} itens pendentes serão copiados.}}'**
  String duplicarDescricao(int n);

  /// No description provided for @excluirLista.
  ///
  /// In pt, this message translates to:
  /// **'Excluir lista'**
  String get excluirLista;

  /// No description provided for @excluirListaTitulo.
  ///
  /// In pt, this message translates to:
  /// **'Excluir \"{titulo}\"?'**
  String excluirListaTitulo(String titulo);

  /// No description provided for @excluirListaMensagem.
  ///
  /// In pt, this message translates to:
  /// **'{n, plural, =0{A lista será excluída{temMembros, select, true{ para todos os participantes} other{}}.} =1{O item será removido{temMembros, select, true{ para todos os participantes} other{}}.} other{Os {n} itens serão removidos{temMembros, select, true{ para todos os participantes} other{}}.}}'**
  String excluirListaMensagem(int n, String temMembros);

  /// No description provided for @atualizada.
  ///
  /// In pt, this message translates to:
  /// **'atualizada'**
  String get atualizada;

  /// No description provided for @erroNomeVazio.
  ///
  /// In pt, this message translates to:
  /// **'Informe um nome.'**
  String get erroNomeVazio;

  /// No description provided for @erroQuantidadeInvalida.
  ///
  /// In pt, this message translates to:
  /// **'Informe uma quantidade maior que zero.'**
  String get erroQuantidadeInvalida;

  /// No description provided for @itens.
  ///
  /// In pt, this message translates to:
  /// **'Itens'**
  String get itens;

  /// No description provided for @desfazer.
  ///
  /// In pt, this message translates to:
  /// **'Desfazer'**
  String get desfazer;

  /// No description provided for @itemRemovido.
  ///
  /// In pt, this message translates to:
  /// **'Item removido'**
  String get itemRemovido;

  /// No description provided for @itemDuplicadoSomado.
  ///
  /// In pt, this message translates to:
  /// **'já está na lista. Quantidade aumentada.'**
  String get itemDuplicadoSomado;

  /// No description provided for @itemAtualizado.
  ///
  /// In pt, this message translates to:
  /// **'Item atualizado.'**
  String get itemAtualizado;

  /// No description provided for @naoEntendiItem.
  ///
  /// In pt, this message translates to:
  /// **'Não entendi o item'**
  String get naoEntendiItem;

  /// No description provided for @removerItem.
  ///
  /// In pt, this message translates to:
  /// **'Remover'**
  String get removerItem;

  /// No description provided for @editarItem.
  ///
  /// In pt, this message translates to:
  /// **'Editar item'**
  String get editarItem;

  /// No description provided for @nomeDoItem.
  ///
  /// In pt, this message translates to:
  /// **'Nome do item'**
  String get nomeDoItem;

  /// No description provided for @quantidade.
  ///
  /// In pt, this message translates to:
  /// **'Quantidade'**
  String get quantidade;

  /// No description provided for @unidade.
  ///
  /// In pt, this message translates to:
  /// **'Unidade'**
  String get unidade;

  /// No description provided for @categoria.
  ///
  /// In pt, this message translates to:
  /// **'Categoria'**
  String get categoria;

  /// No description provided for @preco.
  ///
  /// In pt, this message translates to:
  /// **'Preço (R\$)'**
  String get preco;

  /// No description provided for @erroPrecoInvalido.
  ///
  /// In pt, this message translates to:
  /// **'Preço inválido.'**
  String get erroPrecoInvalido;

  /// No description provided for @ultimaCompra.
  ///
  /// In pt, this message translates to:
  /// **'Última compra: {valor} ({data})'**
  String ultimaCompra(String valor, String data);

  /// No description provided for @mesmoPreco.
  ///
  /// In pt, this message translates to:
  /// **'Mesmo preço'**
  String get mesmoPreco;

  /// No description provided for @precoSubiu.
  ///
  /// In pt, this message translates to:
  /// **'↑ {diff}'**
  String precoSubiu(String diff);

  /// No description provided for @precoBaixou.
  ///
  /// In pt, this message translates to:
  /// **'↓ {diff}'**
  String precoBaixou(String diff);

  /// No description provided for @orcamento.
  ///
  /// In pt, this message translates to:
  /// **'Orçamento'**
  String get orcamento;

  /// No description provided for @campoOrcamento.
  ///
  /// In pt, this message translates to:
  /// **'Orçamento (R\$)'**
  String get campoOrcamento;

  /// No description provided for @removerOrcamento.
  ///
  /// In pt, this message translates to:
  /// **'Remover orçamento'**
  String get removerOrcamento;

  /// No description provided for @orcamentoDefinido.
  ///
  /// In pt, this message translates to:
  /// **'Orçamento salvo.'**
  String get orcamentoDefinido;

  /// No description provided for @orcamentoRemovido.
  ///
  /// In pt, this message translates to:
  /// **'Orçamento removido.'**
  String get orcamentoRemovido;

  /// No description provided for @erroOrcamentoInvalido.
  ///
  /// In pt, this message translates to:
  /// **'Valor de orçamento inválido.'**
  String get erroOrcamentoInvalido;

  /// No description provided for @totalNoCarrinho.
  ///
  /// In pt, this message translates to:
  /// **'No carrinho: {valor}{semPreco, plural, =0{} other{ · {semPreco} sem preço}}'**
  String totalNoCarrinho(String valor, int semPreco);

  /// No description provided for @totalComOrcamento.
  ///
  /// In pt, this message translates to:
  /// **'No carrinho: {valor} de {orcamento}{semPreco, plural, =0{} other{ · {semPreco} sem preço}}'**
  String totalComOrcamento(String valor, String orcamento, int semPreco);

  /// No description provided for @acimaDoOrcamento.
  ///
  /// In pt, this message translates to:
  /// **'Acima do orçamento'**
  String get acimaDoOrcamento;

  /// No description provided for @orcamentoAtencao.
  ///
  /// In pt, this message translates to:
  /// **'Perto do orçamento'**
  String get orcamentoAtencao;

  /// No description provided for @orcamentoCruzado.
  ///
  /// In pt, this message translates to:
  /// **'Você passou do orçamento: {total}'**
  String orcamentoCruzado(String total);

  /// No description provided for @orcamentoPorCategoria.
  ///
  /// In pt, this message translates to:
  /// **'Orçamento por categoria'**
  String get orcamentoPorCategoria;

  /// No description provided for @limitePorCategoria.
  ///
  /// In pt, this message translates to:
  /// **'Limite (R\$)'**
  String get limitePorCategoria;

  /// No description provided for @categoriaSemLimite.
  ///
  /// In pt, this message translates to:
  /// **'Sem limite'**
  String get categoriaSemLimite;

  /// No description provided for @orcamentosSalvos.
  ///
  /// In pt, this message translates to:
  /// **'Limites por categoria salvos.'**
  String get orcamentosSalvos;

  /// No description provided for @acimaDoLimiteDaCategoria.
  ///
  /// In pt, this message translates to:
  /// **'Acima do limite da categoria'**
  String get acimaDoLimiteDaCategoria;

  /// No description provided for @notificacoesOrcamento.
  ///
  /// In pt, this message translates to:
  /// **'Notificações de orçamento'**
  String get notificacoesOrcamento;

  /// No description provided for @diminuir.
  ///
  /// In pt, this message translates to:
  /// **'Diminuir'**
  String get diminuir;

  /// No description provided for @aumentar.
  ///
  /// In pt, this message translates to:
  /// **'Aumentar'**
  String get aumentar;

  /// No description provided for @menu.
  ///
  /// In pt, this message translates to:
  /// **'Menu'**
  String get menu;

  /// No description provided for @lista.
  ///
  /// In pt, this message translates to:
  /// **'Lista'**
  String get lista;

  /// No description provided for @listaNaoEncontrada.
  ///
  /// In pt, this message translates to:
  /// **'Lista não encontrada.'**
  String get listaNaoEncontrada;

  /// No description provided for @voltarParaListas.
  ///
  /// In pt, this message translates to:
  /// **'Voltar para as listas'**
  String get voltarParaListas;

  /// No description provided for @nenhumItem.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum item ainda'**
  String get nenhumItem;

  /// No description provided for @nenhumItemDica.
  ///
  /// In pt, this message translates to:
  /// **'Adicione no campo acima ou importe uma lista.'**
  String get nenhumItemDica;

  /// No description provided for @tempoAgora.
  ///
  /// In pt, this message translates to:
  /// **'agora'**
  String get tempoAgora;

  /// No description provided for @tempoMinutos.
  ///
  /// In pt, this message translates to:
  /// **'há {m} min'**
  String tempoMinutos(int m);

  /// No description provided for @tempoHoras.
  ///
  /// In pt, this message translates to:
  /// **'há {h} h'**
  String tempoHoras(int h);

  /// No description provided for @tempoOntem.
  ///
  /// In pt, this message translates to:
  /// **'ontem'**
  String get tempoOntem;

  /// No description provided for @tempoDias.
  ///
  /// In pt, this message translates to:
  /// **'há {d} dias'**
  String tempoDias(int d);

  /// No description provided for @tempoMeses.
  ///
  /// In pt, this message translates to:
  /// **'há {m} meses'**
  String tempoMeses(int m);

  /// No description provided for @tempoAnos.
  ///
  /// In pt, this message translates to:
  /// **'há {a} anos'**
  String tempoAnos(int a);

  /// No description provided for @progressoLista.
  ///
  /// In pt, this message translates to:
  /// **'{concluidos}/{total, plural, =1{item concluído} other{itens concluídos}}'**
  String progressoLista(int concluidos, int total);

  /// No description provided for @desmarcarTodos.
  ///
  /// In pt, this message translates to:
  /// **'Desmarcar todos'**
  String get desmarcarTodos;

  /// No description provided for @limparConcluidos.
  ///
  /// In pt, this message translates to:
  /// **'Limpar concluídos'**
  String get limparConcluidos;

  /// No description provided for @limpar.
  ///
  /// In pt, this message translates to:
  /// **'Limpar'**
  String get limpar;

  /// No description provided for @limparConcluidosMensagem.
  ///
  /// In pt, this message translates to:
  /// **'Os itens concluídos serão removidos da lista.'**
  String get limparConcluidosMensagem;

  /// No description provided for @concluidosRemovidos.
  ///
  /// In pt, this message translates to:
  /// **'Itens concluídos removidos.'**
  String get concluidosRemovidos;

  /// No description provided for @fechar.
  ///
  /// In pt, this message translates to:
  /// **'Fechar'**
  String get fechar;

  /// No description provided for @importColeOuDigite.
  ///
  /// In pt, this message translates to:
  /// **'Cole ou digite sua lista:'**
  String get importColeOuDigite;

  /// No description provided for @importExemplo.
  ///
  /// In pt, this message translates to:
  /// **'1kg de arroz, 2 leites, 500g de queijo prato...'**
  String get importExemplo;

  /// No description provided for @importExtrairItens.
  ///
  /// In pt, this message translates to:
  /// **'Extrair itens'**
  String get importExtrairItens;

  /// No description provided for @importLendo.
  ///
  /// In pt, this message translates to:
  /// **'Lendo...'**
  String get importLendo;

  /// No description provided for @importConfirmeItens.
  ///
  /// In pt, this message translates to:
  /// **'Confirme os itens'**
  String get importConfirmeItens;

  /// No description provided for @importRespostaInvalida.
  ///
  /// In pt, this message translates to:
  /// **'Não consegui entender a lista. Tente reescrever.'**
  String get importRespostaInvalida;

  /// No description provided for @nadaReconhecido.
  ///
  /// In pt, this message translates to:
  /// **'Nada foi reconhecido'**
  String get nadaReconhecido;

  /// No description provided for @separarItensDica.
  ///
  /// In pt, this message translates to:
  /// **'Separe os itens por vírgula ou linha e tente de novo.'**
  String get separarItensDica;

  /// No description provided for @voltarEEditar.
  ///
  /// In pt, this message translates to:
  /// **'Voltar e editar'**
  String get voltarEEditar;

  /// No description provided for @importAdicionarN.
  ///
  /// In pt, this message translates to:
  /// **'Adicionar {n}'**
  String importAdicionarN(int n);

  /// No description provided for @importSeraoAdicionados.
  ///
  /// In pt, this message translates to:
  /// **'{n} de {total} serão adicionados'**
  String importSeraoAdicionados(int n, int total);

  /// No description provided for @importarLista.
  ///
  /// In pt, this message translates to:
  /// **'Importar lista'**
  String get importarLista;

  /// No description provided for @importLocalAvisoPadrao.
  ///
  /// In pt, this message translates to:
  /// **'Itens sem quantidade entraram com 1 un.'**
  String get importLocalAvisoPadrao;

  /// No description provided for @foto.
  ///
  /// In pt, this message translates to:
  /// **'Foto'**
  String get foto;

  /// No description provided for @tirarFoto.
  ///
  /// In pt, this message translates to:
  /// **'Tirar foto'**
  String get tirarFoto;

  /// No description provided for @escolherDaGaleria.
  ///
  /// In pt, this message translates to:
  /// **'Escolher da galeria'**
  String get escolherDaGaleria;

  /// No description provided for @ocrLendo.
  ///
  /// In pt, this message translates to:
  /// **'Lendo a foto...'**
  String get ocrLendo;

  /// No description provided for @ocrNenhumTexto.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum texto reconhecido na foto.'**
  String get ocrNenhumTexto;

  /// No description provided for @ocrFalha.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível ler a foto.'**
  String get ocrFalha;

  /// No description provided for @adicionarDeOutraLista.
  ///
  /// In pt, this message translates to:
  /// **'Adicionar de outra lista'**
  String get adicionarDeOutraLista;

  /// No description provided for @escolherListaOrigem.
  ///
  /// In pt, this message translates to:
  /// **'Lista de origem'**
  String get escolherListaOrigem;

  /// No description provided for @selecionarTodos.
  ///
  /// In pt, this message translates to:
  /// **'Selecionar todos'**
  String get selecionarTodos;

  /// No description provided for @adicionarSelecionados.
  ///
  /// In pt, this message translates to:
  /// **'Adicionar'**
  String get adicionarSelecionados;

  /// No description provided for @nenhumItemPendenteNaOrigem.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum item pendente nesta lista.'**
  String get nenhumItemPendenteNaOrigem;

  /// No description provided for @tituloListaArquivada.
  ///
  /// In pt, this message translates to:
  /// **'{titulo} · Arquivada'**
  String tituloListaArquivada(String titulo);

  /// No description provided for @itensAdicionadosDeOutra.
  ///
  /// In pt, this message translates to:
  /// **'{n, plural, =1{1 item adicionado de outra lista.} other{{n} itens adicionados de outra lista.}}'**
  String itensAdicionadosDeOutra(int n);

  /// No description provided for @buscar.
  ///
  /// In pt, this message translates to:
  /// **'Buscar'**
  String get buscar;

  /// No description provided for @buscarLista.
  ///
  /// In pt, this message translates to:
  /// **'Buscar lista'**
  String get buscarLista;

  /// No description provided for @buscarItem.
  ///
  /// In pt, this message translates to:
  /// **'Buscar item'**
  String get buscarItem;

  /// No description provided for @limparBusca.
  ///
  /// In pt, this message translates to:
  /// **'Limpar busca'**
  String get limparBusca;

  /// No description provided for @nenhumaListaEncontrada.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma lista encontrada'**
  String get nenhumaListaEncontrada;

  /// No description provided for @nenhumItemEncontrado.
  ///
  /// In pt, this message translates to:
  /// **'Nenhum item encontrado'**
  String get nenhumItemEncontrado;

  /// No description provided for @buscaSemResultadoDica.
  ///
  /// In pt, this message translates to:
  /// **'Tente outro termo.'**
  String get buscaSemResultadoDica;

  /// No description provided for @itensExtraidos.
  ///
  /// In pt, this message translates to:
  /// **'{n, plural, =1{1 item extraído.} other{{n} itens extraídos.}}'**
  String itensExtraidos(int n);

  /// No description provided for @carregando.
  ///
  /// In pt, this message translates to:
  /// **'Carregando...'**
  String get carregando;

  /// No description provided for @tentarNovamente.
  ///
  /// In pt, this message translates to:
  /// **'Tentar novamente'**
  String get tentarNovamente;

  /// No description provided for @semValor.
  ///
  /// In pt, this message translates to:
  /// **'—'**
  String get semValor;

  /// No description provided for @configuracoes.
  ///
  /// In pt, this message translates to:
  /// **'Configurações'**
  String get configuracoes;

  /// No description provided for @aparencia.
  ///
  /// In pt, this message translates to:
  /// **'Aparência'**
  String get aparencia;

  /// No description provided for @temaClaro.
  ///
  /// In pt, this message translates to:
  /// **'Claro'**
  String get temaClaro;

  /// No description provided for @temaEscuro.
  ///
  /// In pt, this message translates to:
  /// **'Escuro'**
  String get temaEscuro;

  /// No description provided for @temaSistema.
  ///
  /// In pt, this message translates to:
  /// **'Sistema'**
  String get temaSistema;

  /// No description provided for @ordenarCategorias.
  ///
  /// In pt, this message translates to:
  /// **'Ordenar categorias'**
  String get ordenarCategorias;

  /// No description provided for @ordenarCategoriasDica.
  ///
  /// In pt, this message translates to:
  /// **'Arraste para a ordem dos corredores do seu mercado.'**
  String get ordenarCategoriasDica;

  /// No description provided for @restaurarPadrao.
  ///
  /// In pt, this message translates to:
  /// **'Restaurar padrão'**
  String get restaurarPadrao;

  /// No description provided for @restaurarPadraoTitulo.
  ///
  /// In pt, this message translates to:
  /// **'Restaurar a ordem padrão?'**
  String get restaurarPadraoTitulo;

  /// No description provided for @restaurarPadraoMensagem.
  ///
  /// In pt, this message translates to:
  /// **'As categorias voltam à ordem original.'**
  String get restaurarPadraoMensagem;

  /// No description provided for @sobre.
  ///
  /// In pt, this message translates to:
  /// **'Sobre'**
  String get sobre;

  /// No description provided for @politicaPrivacidade.
  ///
  /// In pt, this message translates to:
  /// **'Política de Privacidade'**
  String get politicaPrivacidade;

  /// No description provided for @versao.
  ///
  /// In pt, this message translates to:
  /// **'Versão'**
  String get versao;

  /// No description provided for @backup.
  ///
  /// In pt, this message translates to:
  /// **'Backup'**
  String get backup;

  /// No description provided for @backupExportar.
  ///
  /// In pt, this message translates to:
  /// **'Exportar backup'**
  String get backupExportar;

  /// No description provided for @backupImportar.
  ///
  /// In pt, this message translates to:
  /// **'Importar backup'**
  String get backupImportar;

  /// No description provided for @backupExportarAjuda.
  ///
  /// In pt, this message translates to:
  /// **'Compartilha um arquivo com suas listas para guardar ou levar a outro aparelho.'**
  String get backupExportarAjuda;

  /// No description provided for @backupImportarAjuda.
  ///
  /// In pt, this message translates to:
  /// **'Restaura as listas de um arquivo, mesclando com as atuais.'**
  String get backupImportarAjuda;

  /// No description provided for @backupExportado.
  ///
  /// In pt, this message translates to:
  /// **'Backup exportado.'**
  String get backupExportado;

  /// No description provided for @backupImportado.
  ///
  /// In pt, this message translates to:
  /// **'Backup importado.'**
  String get backupImportado;

  /// No description provided for @backupInvalido.
  ///
  /// In pt, this message translates to:
  /// **'Arquivo de backup inválido.'**
  String get backupInvalido;

  /// No description provided for @backupRestauracaoErro.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível restaurar o backup neste aparelho.'**
  String get backupRestauracaoErro;

  /// No description provided for @backupLeituraErro.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível ler o arquivo.'**
  String get backupLeituraErro;

  /// No description provided for @compartilharIndisponivel.
  ///
  /// In pt, this message translates to:
  /// **'Compartilhamento indisponível aqui. Use \"Copiar link\".'**
  String get compartilharIndisponivel;

  /// No description provided for @compartilharLista.
  ///
  /// In pt, this message translates to:
  /// **'Compartilhar'**
  String get compartilharLista;

  /// No description provided for @compartilharTexto.
  ///
  /// In pt, this message translates to:
  /// **'Enviar como texto'**
  String get compartilharTexto;

  /// No description provided for @compartilharArquivo.
  ///
  /// In pt, this message translates to:
  /// **'Enviar arquivo'**
  String get compartilharArquivo;

  /// No description provided for @compartilharQr.
  ///
  /// In pt, this message translates to:
  /// **'QR code'**
  String get compartilharQr;

  /// No description provided for @copiarCodigo.
  ///
  /// In pt, this message translates to:
  /// **'Copiar código'**
  String get copiarCodigo;

  /// No description provided for @codigoCopiado.
  ///
  /// In pt, this message translates to:
  /// **'Código copiado.'**
  String get codigoCopiado;

  /// No description provided for @compartilharQrGrande.
  ///
  /// In pt, this message translates to:
  /// **'Lista grande — use texto ou arquivo.'**
  String get compartilharQrGrande;

  /// No description provided for @listaCompartilhada.
  ///
  /// In pt, this message translates to:
  /// **'Lista compartilhada'**
  String get listaCompartilhada;

  /// No description provided for @compartilharIndisponivelLista.
  ///
  /// In pt, this message translates to:
  /// **'Compartilhamento indisponível aqui.'**
  String get compartilharIndisponivelLista;

  /// No description provided for @escanearQr.
  ///
  /// In pt, this message translates to:
  /// **'Escanear QR'**
  String get escanearQr;

  /// No description provided for @receberLista.
  ///
  /// In pt, this message translates to:
  /// **'Receber lista'**
  String get receberLista;

  /// No description provided for @receberCodigoOuTexto.
  ///
  /// In pt, this message translates to:
  /// **'Cole o código ou o texto da lista'**
  String get receberCodigoOuTexto;

  /// No description provided for @receberArquivo.
  ///
  /// In pt, this message translates to:
  /// **'Escolher arquivo'**
  String get receberArquivo;

  /// No description provided for @receberContinuar.
  ///
  /// In pt, this message translates to:
  /// **'Continuar'**
  String get receberContinuar;

  /// No description provided for @receberConfirmar.
  ///
  /// In pt, this message translates to:
  /// **'Criar lista'**
  String get receberConfirmar;

  /// No description provided for @receberInvalido.
  ///
  /// In pt, this message translates to:
  /// **'Código ou arquivo inválido.'**
  String get receberInvalido;

  /// No description provided for @finalizarCompra.
  ///
  /// In pt, this message translates to:
  /// **'Finalizar compra'**
  String get finalizarCompra;

  /// No description provided for @finalizarConfirmarTitulo.
  ///
  /// In pt, this message translates to:
  /// **'Finalizar esta compra?'**
  String get finalizarConfirmarTitulo;

  /// No description provided for @finalizarResumo.
  ///
  /// In pt, this message translates to:
  /// **'{n, plural, =1{1 item} other{{n} itens}} · {total}{semPreco, plural, =0{} other{ · {semPreco} sem preço}}'**
  String finalizarResumo(int n, String total, int semPreco);

  /// No description provided for @finalizarLimpar.
  ///
  /// In pt, this message translates to:
  /// **'Limpar concluídos'**
  String get finalizarLimpar;

  /// No description provided for @finalizarManter.
  ///
  /// In pt, this message translates to:
  /// **'Manter a lista'**
  String get finalizarManter;

  /// No description provided for @compraRegistrada.
  ///
  /// In pt, this message translates to:
  /// **'Compra registrada no histórico.'**
  String get compraRegistrada;

  /// No description provided for @historico.
  ///
  /// In pt, this message translates to:
  /// **'Histórico'**
  String get historico;

  /// No description provided for @historicoVazio.
  ///
  /// In pt, this message translates to:
  /// **'Nenhuma compra finalizada ainda.'**
  String get historicoVazio;

  /// No description provided for @historicoVazioDica.
  ///
  /// In pt, this message translates to:
  /// **'Marque itens e use \"Finalizar compra\" para registrar uma ida.'**
  String get historicoVazioDica;

  /// No description provided for @idaNaoEncontrada.
  ///
  /// In pt, this message translates to:
  /// **'Compra não encontrada.'**
  String get idaNaoEncontrada;

  /// No description provided for @nItens.
  ///
  /// In pt, this message translates to:
  /// **'{n, plural, =1{1 item} other{{n} itens}}'**
  String nItens(int n);

  /// No description provided for @totalGasto.
  ///
  /// In pt, this message translates to:
  /// **'Total gasto'**
  String get totalGasto;

  /// No description provided for @ticketMedio.
  ///
  /// In pt, this message translates to:
  /// **'Ticket médio'**
  String get ticketMedio;

  /// No description provided for @numeroIdas.
  ///
  /// In pt, this message translates to:
  /// **'Idas'**
  String get numeroIdas;

  /// No description provided for @mercado.
  ///
  /// In pt, this message translates to:
  /// **'Mercado'**
  String get mercado;

  /// No description provided for @mercadoOpcional.
  ///
  /// In pt, this message translates to:
  /// **'Mercado (opcional)'**
  String get mercadoOpcional;

  /// No description provided for @porMercado.
  ///
  /// In pt, this message translates to:
  /// **'Por mercado'**
  String get porMercado;

  /// No description provided for @maisBarato.
  ///
  /// In pt, this message translates to:
  /// **'mais barato'**
  String get maisBarato;

  /// No description provided for @gastoPorMercado.
  ///
  /// In pt, this message translates to:
  /// **'Gasto por mercado'**
  String get gastoPorMercado;

  /// No description provided for @semMercado.
  ///
  /// In pt, this message translates to:
  /// **'Sem mercado'**
  String get semMercado;

  /// No description provided for @mercadosSugeridos.
  ///
  /// In pt, this message translates to:
  /// **'Mercados usados'**
  String get mercadosSugeridos;

  /// No description provided for @estatisticas.
  ///
  /// In pt, this message translates to:
  /// **'Estatísticas'**
  String get estatisticas;

  /// No description provided for @abaIdas.
  ///
  /// In pt, this message translates to:
  /// **'Idas'**
  String get abaIdas;

  /// No description provided for @gastoPorPeriodo.
  ///
  /// In pt, this message translates to:
  /// **'Gasto por período'**
  String get gastoPorPeriodo;

  /// No description provided for @gastoPorCategoria.
  ///
  /// In pt, this message translates to:
  /// **'Gasto por categoria'**
  String get gastoPorCategoria;

  /// No description provided for @itensMaisComprados.
  ///
  /// In pt, this message translates to:
  /// **'Itens mais comprados'**
  String get itensMaisComprados;

  /// No description provided for @evolucaoDePreco.
  ///
  /// In pt, this message translates to:
  /// **'Evolução de preço'**
  String get evolucaoDePreco;

  /// No description provided for @semDadosAinda.
  ///
  /// In pt, this message translates to:
  /// **'Sem dados ainda.'**
  String get semDadosAinda;

  /// No description provided for @totalNoPeriodo.
  ///
  /// In pt, this message translates to:
  /// **'Total no período: {v}'**
  String totalNoPeriodo(String v);

  /// No description provided for @porFrequencia.
  ///
  /// In pt, this message translates to:
  /// **'Frequência'**
  String get porFrequencia;

  /// No description provided for @porGasto.
  ///
  /// In pt, this message translates to:
  /// **'Gasto'**
  String get porGasto;

  /// No description provided for @semanticaGastoMensal.
  ///
  /// In pt, this message translates to:
  /// **'Gasto mensal: {v}'**
  String semanticaGastoMensal(String v);

  /// No description provided for @semanticaEvolucaoPreco.
  ///
  /// In pt, this message translates to:
  /// **'Evolução de preço: último {v}'**
  String semanticaEvolucaoPreco(String v);

  /// No description provided for @boasVindasTitulo.
  ///
  /// In pt, this message translates to:
  /// **'Bem-vindo(a)'**
  String get boasVindasTitulo;

  /// No description provided for @boasVindasSubtitulo.
  ///
  /// In pt, this message translates to:
  /// **'Organize suas compras no seu aparelho.'**
  String get boasVindasSubtitulo;

  /// No description provided for @boasVindasOffline.
  ///
  /// In pt, this message translates to:
  /// **'Funciona offline'**
  String get boasVindasOffline;

  /// No description provided for @boasVindasOfflineDica.
  ///
  /// In pt, this message translates to:
  /// **'Suas listas ficam no aparelho.'**
  String get boasVindasOfflineDica;

  /// No description provided for @boasVindasBackup.
  ///
  /// In pt, this message translates to:
  /// **'Backup quando quiser'**
  String get boasVindasBackup;

  /// No description provided for @boasVindasBackupDica.
  ///
  /// In pt, this message translates to:
  /// **'Exporte e restaure suas listas num arquivo.'**
  String get boasVindasBackupDica;

  /// No description provided for @boasVindasImportar.
  ///
  /// In pt, this message translates to:
  /// **'Importe por texto'**
  String get boasVindasImportar;

  /// No description provided for @boasVindasImportarDica.
  ///
  /// In pt, this message translates to:
  /// **'Cole uma anotação e o app organiza os itens.'**
  String get boasVindasImportarDica;

  /// No description provided for @boasVindasDitar.
  ///
  /// In pt, this message translates to:
  /// **'Dite um item'**
  String get boasVindasDitar;

  /// No description provided for @boasVindasDitarDica.
  ///
  /// In pt, this message translates to:
  /// **'Use o microfone para adicionar falando.'**
  String get boasVindasDitarDica;

  /// No description provided for @comecar.
  ///
  /// In pt, this message translates to:
  /// **'Começar'**
  String get comecar;

  /// No description provided for @tourPular.
  ///
  /// In pt, this message translates to:
  /// **'Pular'**
  String get tourPular;

  /// No description provided for @tourAnterior.
  ///
  /// In pt, this message translates to:
  /// **'Anterior'**
  String get tourAnterior;

  /// No description provided for @tourProximo.
  ///
  /// In pt, this message translates to:
  /// **'Próximo'**
  String get tourProximo;

  /// No description provided for @tourConcluir.
  ///
  /// In pt, this message translates to:
  /// **'Concluir'**
  String get tourConcluir;

  /// No description provided for @tourPasso.
  ///
  /// In pt, this message translates to:
  /// **'Passo {numero} de {total}'**
  String tourPasso(int numero, int total);

  /// No description provided for @tourAbrir.
  ///
  /// In pt, this message translates to:
  /// **'Ver tutorial'**
  String get tourAbrir;

  /// No description provided for @tourNovaListaTitulo.
  ///
  /// In pt, this message translates to:
  /// **'Criar sua primeira lista'**
  String get tourNovaListaTitulo;

  /// No description provided for @tourNovaListaCorpo.
  ///
  /// In pt, this message translates to:
  /// **'Toque em \"Nova lista\" para começar. Você pode criar quantas quiser.'**
  String get tourNovaListaCorpo;

  /// No description provided for @tourNomeTitulo.
  ///
  /// In pt, this message translates to:
  /// **'Dê um nome'**
  String get tourNomeTitulo;

  /// No description provided for @tourNomeCorpo.
  ///
  /// In pt, this message translates to:
  /// **'O nome aparece no topo. Opcionalmente, defina um orçamento.'**
  String get tourNomeCorpo;

  /// No description provided for @tourAdicionarTitulo.
  ///
  /// In pt, this message translates to:
  /// **'Adicionar item'**
  String get tourAdicionarTitulo;

  /// No description provided for @tourAdicionarCorpo.
  ///
  /// In pt, this message translates to:
  /// **'Digite aqui. \"1kg de arroz\" já vira nome, quantidade e unidade.'**
  String get tourAdicionarCorpo;

  /// No description provided for @tourUnidadeTitulo.
  ///
  /// In pt, this message translates to:
  /// **'Unidade'**
  String get tourUnidadeTitulo;

  /// No description provided for @tourUnidadeCorpo.
  ///
  /// In pt, this message translates to:
  /// **'Escolha a medida (un, kg, pacote, pct, pt...). O app tenta adivinhar.'**
  String get tourUnidadeCorpo;

  /// No description provided for @tourImportarTitulo.
  ///
  /// In pt, this message translates to:
  /// **'Importe por texto'**
  String get tourImportarTitulo;

  /// No description provided for @tourImportarCorpo.
  ///
  /// In pt, this message translates to:
  /// **'Cole uma anotação e o app organiza os itens para você.'**
  String get tourImportarCorpo;

  /// No description provided for @tourBuscaTitulo.
  ///
  /// In pt, this message translates to:
  /// **'Busca e filtros'**
  String get tourBuscaTitulo;

  /// No description provided for @tourBuscaCorpo.
  ///
  /// In pt, this message translates to:
  /// **'Encontre itens por nome e filtre por categoria ou unidade.'**
  String get tourBuscaCorpo;

  /// No description provided for @tourConfigTitulo.
  ///
  /// In pt, this message translates to:
  /// **'Configurações'**
  String get tourConfigTitulo;

  /// No description provided for @tourConfigCorpo.
  ///
  /// In pt, this message translates to:
  /// **'Tema, categorias, backup e onde rever este tutorial.'**
  String get tourConfigCorpo;

  /// No description provided for @tourMarcarTitulo.
  ///
  /// In pt, this message translates to:
  /// **'Marcar, editar e remover'**
  String get tourMarcarTitulo;

  /// No description provided for @tourMarcarCorpo.
  ///
  /// In pt, this message translates to:
  /// **'Toque no item para editar; marque no círculo; arraste para remover.'**
  String get tourMarcarCorpo;

  /// No description provided for @tourMercadoTitulo.
  ///
  /// In pt, this message translates to:
  /// **'Modo mercado'**
  String get tourMercadoTitulo;

  /// No description provided for @tourMercadoCorpo.
  ///
  /// In pt, this message translates to:
  /// **'No mercado, marque as compras sem perder o que falta.'**
  String get tourMercadoCorpo;

  /// No description provided for @tourOrcamentoTitulo.
  ///
  /// In pt, this message translates to:
  /// **'Orçamento e total'**
  String get tourOrcamentoTitulo;

  /// No description provided for @tourOrcamentoCorpo.
  ///
  /// In pt, this message translates to:
  /// **'Defina um teto e acompanhe o total do carrinho.'**
  String get tourOrcamentoCorpo;

  /// No description provided for @politicaPrivacidadeTexto.
  ///
  /// In pt, this message translates to:
  /// **'Política de Privacidade — Minhas Listas\n\n1. Dados que coletamos\nO aplicativo funciona inteiramente no seu aparelho.\n• Suas listas e itens ficam armazenados apenas no seu dispositivo.\n• Não criamos conta, não pedimos e-mail nem senha e não enviamos seus dados para servidores nossos.\n\n2. Voz\n• O recurso de adicionar itens por voz usa o reconhecedor de fala do seu aparelho. Conforme o sistema, o áudio pode ser processado pelo serviço de reconhecimento do dispositivo (que pode usar a internet). Não gravamos nem guardamos o áudio.\n\n3. Backup\n• Você pode exportar um arquivo de backup e reimportá-lo. O arquivo é criado no seu aparelho e só sai dele por uma ação sua (compartilhar/salvar).\n\n4. Com quem compartilhamos\nNão compartilhamos dados com terceiros. Não há publicidade nem rastreamento.\n\n5. Por quanto tempo guardamos\nSeus dados ficam no aparelho até você excluí-los no próprio aplicativo (removendo listas ou o app).\n\n6. Seus direitos\nVocê acessa, corrige e apaga tudo diretamente no aplicativo. O app não é direcionado a menores de 16 anos.\n\n7. Contato\nDúvidas sobre privacidade: {email}.'**
  String politicaPrivacidadeTexto(String email);

  /// No description provided for @idiomaTitulo.
  ///
  /// In pt, this message translates to:
  /// **'Idioma'**
  String get idiomaTitulo;

  /// No description provided for @idiomaSistema.
  ///
  /// In pt, this message translates to:
  /// **'Sistema'**
  String get idiomaSistema;

  /// No description provided for @idiomaPortugues.
  ///
  /// In pt, this message translates to:
  /// **'Português'**
  String get idiomaPortugues;

  /// No description provided for @idiomaIngles.
  ///
  /// In pt, this message translates to:
  /// **'English'**
  String get idiomaIngles;

  /// No description provided for @idiomaEspanhol.
  ///
  /// In pt, this message translates to:
  /// **'Español'**
  String get idiomaEspanhol;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
