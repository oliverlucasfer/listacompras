/// Strings pt-BR centralizadas do app local "Minhas Listas" (doc 05 §7).
/// Hardcoded no MVP; centralizadas aqui para facilitar futura tradução.
abstract final class AppStrings {
  // App
  static const appNome = 'Minhas Listas';

  // Erros genéricos
  static const erroGenerico = 'Não foi possível concluir. Tente novamente.';

  // Listas
  static const minhasListas = 'Minhas Listas';
  static const abaMinhas = 'Minhas';
  static const novaLista = 'Nova lista';
  static const salvar = 'Salvar';
  static const cancelar = 'Cancelar';
  static const renomear = 'Renomear';
  static const excluir = 'Excluir';
  static const mostrarArquivadas = 'Mostrar arquivadas';
  static const arquivar = 'Arquivar';
  static const desarquivar = 'Desarquivar';
  static const arquivada = 'Arquivada';
  static const listaArquivada = 'Lista arquivada.';
  static const listaDesarquivada = 'Lista desarquivada.';

  // Itens
  static const adicionarItem = 'Adicionar item';
  static const itensConcluidos = 'Itens concluídos';
  static const reordenar = 'Reordenar';
  static const sugestoes = 'Sugestões';

  // Adicionar por voz (RF-26)
  static const ditarItem = 'Ditar item';
  static const vozIndisponivel =
      'Reconhecimento de voz indisponível neste aparelho.';

  static String adicionarSugerido(String nome) => 'Adicionar $nome';

  // Modo mercado (RF-18, wireframe 10 §3.5)
  static const modoMercado = 'Modo mercado';
  static String mercadoProgresso(int marcados, int total) =>
      '$marcados de $total';
  static const mercadoMarcados = 'Marcados';
  static const mercadoTudoComprado = 'Tudo comprado!';
  static const voltarParaLista = 'Voltar para a lista';

  // Painel Minhas Listas (wireframe 10 §2)
  static const nenhumaLista = 'Nenhuma lista por aqui';
  static const criePrimeiraLista =
      'Crie sua primeira lista ou importe por texto.';
  static const criarPrimeiraLista = 'Criar primeira lista';
  static const nomeDaLista = 'Nome da lista';
  static const criarLista = 'Criar lista';
  static const renomearLista = 'Renomear lista';
  static const listaCriada = 'Lista criada.';
  static const listaRenomeada = 'Lista renomeada.';
  static const comprarDeNovo = 'Comprar de novo';

  static String duplicarDescricao(int n) => n == 1
      ? '1 item pendente será copiado.'
      : '$n itens pendentes serão copiados.';

  static const excluirLista = 'Excluir lista';

  static String excluirListaTitulo(String titulo) => 'Excluir "$titulo"?';

  static String excluirListaMensagem(int nItens, {required bool temMembros}) {
    final sufixo = temMembros ? ' para todos os participantes' : '';
    if (nItens == 0) return 'A lista será excluída$sufixo.';
    if (nItens == 1) return 'O item será removido$sufixo.';
    return 'Os $nItens itens serão removidos$sufixo.';
  }

  static const atualizada = 'atualizada';
  static const erroNomeVazio = 'Informe um nome.';
  static const erroQuantidadeInvalida =
      'Informe uma quantidade maior que zero.';

  // Tela da Lista (wireframe 10 §3, doc 05 §6.3)
  static const itens = 'Itens';
  static const desfazer = 'Desfazer';
  static const itemRemovido = 'Item removido';
  static const itemDuplicadoSomado = 'já está na lista. Quantidade aumentada.';
  static const itemAtualizado = 'Item atualizado.';
  static const naoEntendiItem = 'Não entendi o item';
  static const removerItem = 'Remover';
  static const editarItem = 'Editar item';
  static const nomeDoItem = 'Nome do item';
  static const quantidade = 'Quantidade';
  static const unidade = 'Unidade';
  static const categoria = 'Categoria';
  static const preco = 'Preço (R\$)';
  static const erroPrecoInvalido = 'Preço inválido.';

  // Histórico de preços no editor (RF-29, F37)
  static String ultimaCompra(String valor, String data) =>
      'Última compra: $valor ($data)';
  static const mesmoPreco = 'Mesmo preço';
  static String precoSubiu(String diff) => '↑ $diff';
  static String precoBaixou(String diff) => '↓ $diff';

  // Orçamento por lista (RF-28, F36-T03)
  static const orcamento = 'Orçamento';
  static const campoOrcamento = 'Orçamento (R\$)';
  static const removerOrcamento = 'Remover orçamento';
  static const orcamentoDefinido = 'Orçamento salvo.';
  static const orcamentoRemovido = 'Orçamento removido.';
  static const erroOrcamentoInvalido = 'Valor de orçamento inválido.';

  static String totalNoCarrinho(String valor, int semPreco) => semPreco == 0
      ? 'No carrinho: $valor'
      : 'No carrinho: $valor · $semPreco sem preço';

  // Faixa do total com orçamento (RF-28, F36-T04)
  static String totalComOrcamento(
    String valor,
    String orcamento,
    int semPreco,
  ) => semPreco == 0
      ? 'No carrinho: $valor de $orcamento'
      : 'No carrinho: $valor de $orcamento · $semPreco sem preço';

  static const acimaDoOrcamento = 'Acima do orçamento';

  static const diminuir = 'Diminuir';
  static const aumentar = 'Aumentar';
  static const menu = 'Menu';
  static const lista = 'Lista';
  static const listaNaoEncontrada = 'Lista não encontrada.';
  static const voltarParaListas = 'Voltar para as listas';
  static const nenhumItem = 'Nenhum item ainda';
  static const nenhumItemDica = 'Adicione no campo acima ou importe uma lista.';

  // Tempo relativo dos cards (wireframe 10 §2, F14-T08)
  static const tempoAgora = 'agora';
  static String tempoMinutos(int m) => 'há $m min';
  static String tempoHoras(int h) => 'há $h h';
  static const tempoOntem = 'ontem';
  static String tempoDias(int d) => 'há $d dias';
  static String tempoMeses(int m) => 'há $m meses';
  static String tempoAnos(int a) => 'há $a anos';

  static String progressoLista(int concluidos, int total) {
    final palavra = total == 1 ? 'item concluído' : 'itens concluídos';
    return '$concluidos/$total $palavra';
  }

  // Ações em massa (doc 05 §6.3, wireframe 10 §3.4)
  static const desmarcarTodos = 'Desmarcar todos';
  static const limparConcluidos = 'Limpar concluídos';
  static const limpar = 'Limpar';
  static const limparConcluidosMensagem =
      'Os itens concluídos serão removidos da lista.';
  static const concluidosRemovidos = 'Itens concluídos removidos.';

  // Importação de lista (RF-16, doc 04): parser local offline
  static const fechar = 'Fechar';
  static const importColeOuDigite = 'Cole ou digite sua lista:';
  static const importExemplo =
      '1kg de arroz, 2 leites, 500g de queijo prato...';
  static const importExtrairItens = 'Extrair itens';
  static const importLendo = 'Lendo...';
  static const importConfirmeItens = 'Confirme os itens';
  static const importRespostaInvalida =
      'Não consegui entender a lista. Tente reescrever.';
  static const nadaReconhecido = 'Nada foi reconhecido';
  static const separarItensDica =
      'Separe os itens por vírgula ou linha e tente de novo.';
  static const voltarEEditar = 'Voltar e editar';

  static String importAdicionarN(int n) => 'Adicionar $n';
  static String importSeraoAdicionados(int n, int total) =>
      '$n de $total serão adicionados';

  // Importação de lista (RF-16): modo local sem IA
  static const importarLista = 'Importar lista';
  static const importLocalAvisoPadrao =
      'Itens sem quantidade entraram com 1 un.';

  // Adicionar de outra lista (RF-23)
  static const adicionarDeOutraLista = 'Adicionar de outra lista';
  static const escolherListaOrigem = 'Lista de origem';
  static const selecionarTodos = 'Selecionar todos';
  static const adicionarSelecionados = 'Adicionar';
  static const nenhumItemPendenteNaOrigem = 'Nenhum item pendente nesta lista.';

  static String tituloListaArquivada(String titulo) => '$titulo · $arquivada';

  static String itensAdicionadosDeOutra(int n) => n == 1
      ? '1 item adicionado de outra lista.'
      : '$n itens adicionados de outra lista.';

  // Busca/filtro local (RF-17, F16)
  static const buscar = 'Buscar';
  static const buscarLista = 'Buscar lista';
  static const buscarItem = 'Buscar item';
  static const limparBusca = 'Limpar busca';
  static const nenhumaListaEncontrada = 'Nenhuma lista encontrada';
  static const nenhumItemEncontrado = 'Nenhum item encontrado';
  static const buscaSemResultadoDica = 'Tente outro termo.';

  static String itensExtraidos(int n) =>
      n == 1 ? '1 item extraído.' : '$n itens extraídos.';

  // Estados transversais
  static const carregando = 'Carregando...';
  static const tentarNovamente = 'Tentar novamente';
  static const semValor = '—';

  // Configurações (doc 06 §3, wireframe 10 §5)
  static const configuracoes = 'Configurações';
  static const aparencia = 'Aparência';
  static const temaClaro = 'Claro';
  static const temaEscuro = 'Escuro';
  static const temaSistema = 'Sistema';
  static const ordenarCategorias = 'Ordenar categorias';
  static const ordenarCategoriasDica =
      'Arraste para a ordem dos corredores do seu mercado.';
  static const restaurarPadrao = 'Restaurar padrão';
  static const restaurarPadraoTitulo = 'Restaurar a ordem padrão?';
  static const restaurarPadraoMensagem =
      'As categorias voltam à ordem original.';
  static const sobre = 'Sobre';
  static const politicaPrivacidade = 'Política de Privacidade';
  static const versao = 'Versão';

  // Backup local (RF-31, F41)
  static const backup = 'Backup';
  static const backupExportar = 'Exportar backup';
  static const backupImportar = 'Importar backup';
  static const backupExportarAjuda =
      'Compartilha um arquivo com suas listas para guardar ou levar a outro aparelho.';
  static const backupImportarAjuda =
      'Restaura as listas de um arquivo, mesclando com as atuais.';
  static const backupExportado = 'Backup exportado.';
  static const backupImportado = 'Backup importado.';
  static const backupInvalido = 'Arquivo de backup inválido.';
  static const backupRestauracaoErro =
      'Não foi possível restaurar o backup neste aparelho.';
  static const backupLeituraErro = 'Não foi possível ler o arquivo.';
  static const compartilharIndisponivel =
      'Compartilhamento indisponível aqui. Use "Copiar link".';

  // Compartilhar lista (RF-33, F49)
  static const compartilharLista = 'Compartilhar';
  static const compartilharTexto = 'Enviar como texto';
  static const compartilharArquivo = 'Enviar arquivo';
  static const compartilharQr = 'QR code';
  static const copiarCodigo = 'Copiar código';
  static const codigoCopiado = 'Código copiado.';
  static const compartilharQrGrande = 'Lista grande — use texto ou arquivo.';
  static const listaCompartilhada = 'Lista compartilhada';
  static const compartilharIndisponivelLista =
      'Compartilhamento indisponível aqui.';
  static const escanearQr = 'Escanear QR';
  static const receberLista = 'Receber lista';
  static const receberCodigoOuTexto = 'Cole o código ou o texto da lista';
  static const receberArquivo = 'Escolher arquivo';
  static const receberContinuar = 'Continuar';
  static const receberConfirmar = 'Criar lista';
  static const receberInvalido = 'Código ou arquivo inválido.';

  // Historico de compras (RF-34, F50)
  static const finalizarCompra = 'Finalizar compra';
  static const finalizarConfirmarTitulo = 'Finalizar esta compra?';
  static String finalizarResumo(int n, String total, int semPreco) =>
      semPreco == 0
      ? '$n ${n == 1 ? 'item' : 'itens'} · $total'
      : '$n ${n == 1 ? 'item' : 'itens'} · $total · $semPreco sem preço';
  static const finalizarLimpar = 'Limpar concluídos';
  static const finalizarManter = 'Manter a lista';
  static const compraRegistrada = 'Compra registrada no histórico.';
  static const historico = 'Histórico';
  static const historicoVazio = 'Nenhuma compra finalizada ainda.';
  static const historicoVazioDica =
      'Marque itens e use "Finalizar compra" para registrar uma ida.';
  static const idaNaoEncontrada = 'Compra não encontrada.';
  static String nItens(int n) => n == 1 ? '1 item' : '$n itens';
  static const totalGasto = 'Total gasto';
  static const ticketMedio = 'Ticket médio';
  static const numeroIdas = 'Idas';

  // Estatísticas do histórico (RF-34, F51)
  static const estatisticas = 'Estatísticas';
  static const abaIdas = 'Idas';
  static const gastoPorPeriodo = 'Gasto por período';
  static const gastoPorCategoria = 'Gasto por categoria';
  static const itensMaisComprados = 'Itens mais comprados';
  static const evolucaoDePreco = 'Evolução de preço';
  static const semDadosAinda = 'Sem dados ainda.';

  // Boas-vindas (RF-27, F31-T02)
  static const boasVindasTitulo = 'Bem-vindo(a)';
  static const boasVindasSubtitulo = 'Organize suas compras no seu aparelho.';
  static const boasVindasOffline = 'Funciona offline';
  static const boasVindasOfflineDica = 'Suas listas ficam no aparelho.';
  static const boasVindasBackup = 'Backup quando quiser';
  static const boasVindasBackupDica =
      'Exporte e restaure suas listas num arquivo.';
  static const boasVindasImportar = 'Importe por texto';
  static const boasVindasImportarDica =
      'Cole uma anotação e o app organiza os itens.';
  static const boasVindasDitar = 'Dite um item';
  static const boasVindasDitarDica = 'Use o microfone para adicionar falando.';
  static const comecar = 'Começar';

  // Tour guiado (RF-27, F46)
  static const tourPular = 'Pular';
  static const tourAnterior = 'Anterior';
  static const tourProximo = 'Próximo';
  static const tourConcluir = 'Concluir';
  static String tourPasso(int numero, int total) => 'Passo $numero de $total';
  static const tourAbrir = 'Ver tutorial';
  static const tourNovaListaTitulo = 'Criar sua primeira lista';
  static const tourNovaListaCorpo =
      'Toque em "Nova lista" para começar. Você pode criar quantas quiser.';
  static const tourNomeTitulo = 'Dê um nome';
  static const tourNomeCorpo =
      'O nome aparece no topo. Opcionalmente, defina um orçamento.';
  static const tourAdicionarTitulo = 'Adicionar item';
  static const tourAdicionarCorpo =
      'Digite aqui. "1kg de arroz" já vira nome, quantidade e unidade.';
  static const tourUnidadeTitulo = 'Unidade';
  static const tourUnidadeCorpo =
      'Escolha a medida (un, kg, pacote, pct, pt...). O app tenta adivinhar.';
  static const tourImportarTitulo = 'Importe por texto';
  static const tourImportarCorpo =
      'Cole uma anotação e o app organiza os itens para você.';
  static const tourBuscaTitulo = 'Busca e filtros';
  static const tourBuscaCorpo =
      'Encontre itens por nome e filtre por categoria ou unidade.';
  static const tourConfigTitulo = 'Configurações';
  static const tourConfigCorpo =
      'Tema, categorias, backup e onde rever este tutorial.';
  static const tourMarcarTitulo = 'Marcar, editar e remover';
  static const tourMarcarCorpo =
      'Toque no item para editar; marque no círculo; arraste para remover.';
  static const tourMercadoTitulo = 'Modo mercado';
  static const tourMercadoCorpo =
      'No mercado, marque as compras sem perder o que falta.';
  static const tourOrcamentoTitulo = 'Orçamento e total';
  static const tourOrcamentoCorpo =
      'Defina um teto e acompanhe o total do carrinho.';
}
