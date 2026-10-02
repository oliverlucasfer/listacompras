// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appNome => 'Minhas Listas';

  @override
  String get erroGenerico => 'Não foi possível concluir. Tente novamente.';

  @override
  String get minhasListas => 'Minhas Listas';

  @override
  String get abaMinhas => 'Minhas';

  @override
  String get novaLista => 'Nova lista';

  @override
  String get salvar => 'Salvar';

  @override
  String get cancelar => 'Cancelar';

  @override
  String get renomear => 'Renomear';

  @override
  String get excluir => 'Excluir';

  @override
  String get mostrarArquivadas => 'Mostrar arquivadas';

  @override
  String get arquivar => 'Arquivar';

  @override
  String get desarquivar => 'Desarquivar';

  @override
  String get arquivada => 'Arquivada';

  @override
  String get listaArquivada => 'Lista arquivada.';

  @override
  String get listaDesarquivada => 'Lista desarquivada.';

  @override
  String get adicionarItem => 'Adicionar item';

  @override
  String get itensConcluidos => 'Itens concluídos';

  @override
  String get reordenar => 'Reordenar';

  @override
  String get sugestoes => 'Sugestões';

  @override
  String get ditarItem => 'Ditar item';

  @override
  String get vozIndisponivel =>
      'Reconhecimento de voz indisponível neste aparelho.';

  @override
  String adicionarSugerido(String nome) {
    return 'Adicionar $nome';
  }

  @override
  String get modoMercado => 'Modo mercado';

  @override
  String mercadoProgresso(int marcados, int total) {
    return '$marcados de $total';
  }

  @override
  String get mercadoMarcados => 'Marcados';

  @override
  String get mercadoTudoComprado => 'Tudo comprado!';

  @override
  String get voltarParaLista => 'Voltar para a lista';

  @override
  String get nenhumaLista => 'Nenhuma lista por aqui';

  @override
  String get criePrimeiraLista =>
      'Crie sua primeira lista ou importe por texto.';

  @override
  String get criarPrimeiraLista => 'Criar primeira lista';

  @override
  String get nomeDaLista => 'Nome da lista';

  @override
  String get criarLista => 'Criar lista';

  @override
  String get renomearLista => 'Renomear lista';

  @override
  String get listaCriada => 'Lista criada.';

  @override
  String get listaRenomeada => 'Lista renomeada.';

  @override
  String get comprarDeNovo => 'Comprar de novo';

  @override
  String duplicarDescricao(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n itens pendentes serão copiados.',
      one: '1 item pendente será copiado.',
    );
    return '$_temp0';
  }

  @override
  String get excluirLista => 'Excluir lista';

  @override
  String excluirListaTitulo(String titulo) {
    return 'Excluir \"$titulo\"?';
  }

  @override
  String excluirListaMensagem(int n, String temMembros) {
    String _temp0 = intl.Intl.selectLogic(temMembros, {
      'true': ' para todos os participantes',
      'other': '',
    });
    String _temp1 = intl.Intl.selectLogic(temMembros, {
      'true': ' para todos os participantes',
      'other': '',
    });
    String _temp2 = intl.Intl.selectLogic(temMembros, {
      'true': ' para todos os participantes',
      'other': '',
    });
    String _temp3 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Os $n itens serão removidos$_temp0.',
      one: 'O item será removido$_temp1.',
      zero: 'A lista será excluída$_temp2.',
    );
    return '$_temp3';
  }

  @override
  String get atualizada => 'atualizada';

  @override
  String get erroNomeVazio => 'Informe um nome.';

  @override
  String get erroQuantidadeInvalida => 'Informe uma quantidade maior que zero.';

  @override
  String get itens => 'Itens';

  @override
  String get desfazer => 'Desfazer';

  @override
  String get itemRemovido => 'Item removido';

  @override
  String get itemDuplicadoSomado => 'já está na lista. Quantidade aumentada.';

  @override
  String get itemAtualizado => 'Item atualizado.';

  @override
  String get naoEntendiItem => 'Não entendi o item';

  @override
  String get removerItem => 'Remover';

  @override
  String get editarItem => 'Editar item';

  @override
  String get nomeDoItem => 'Nome do item';

  @override
  String get quantidade => 'Quantidade';

  @override
  String get unidade => 'Unidade';

  @override
  String get categoria => 'Categoria';

  @override
  String get preco => 'Preço (R\$)';

  @override
  String get erroPrecoInvalido => 'Preço inválido.';

  @override
  String ultimaCompra(String valor, String data) {
    return 'Última compra: $valor ($data)';
  }

  @override
  String get mesmoPreco => 'Mesmo preço';

  @override
  String precoSubiu(String diff) {
    return '↑ $diff';
  }

  @override
  String precoBaixou(String diff) {
    return '↓ $diff';
  }

  @override
  String get orcamento => 'Orçamento';

  @override
  String get campoOrcamento => 'Orçamento (R\$)';

  @override
  String get removerOrcamento => 'Remover orçamento';

  @override
  String get orcamentoDefinido => 'Orçamento salvo.';

  @override
  String get orcamentoRemovido => 'Orçamento removido.';

  @override
  String get erroOrcamentoInvalido => 'Valor de orçamento inválido.';

  @override
  String totalNoCarrinho(String valor, int semPreco) {
    String _temp0 = intl.Intl.pluralLogic(
      semPreco,
      locale: localeName,
      other: ' · $semPreco sem preço',
      zero: '',
    );
    return 'No carrinho: $valor$_temp0';
  }

  @override
  String totalComOrcamento(String valor, String orcamento, int semPreco) {
    String _temp0 = intl.Intl.pluralLogic(
      semPreco,
      locale: localeName,
      other: ' · $semPreco sem preço',
      zero: '',
    );
    return 'No carrinho: $valor de $orcamento$_temp0';
  }

  @override
  String get acimaDoOrcamento => 'Acima do orçamento';

  @override
  String get orcamentoAtencao => 'Perto do orçamento';

  @override
  String orcamentoCruzado(String total) {
    return 'Você passou do orçamento: $total';
  }

  @override
  String get orcamentoPorCategoria => 'Orçamento por categoria';

  @override
  String get limitePorCategoria => 'Limite (R\$)';

  @override
  String get categoriaSemLimite => 'Sem limite';

  @override
  String get orcamentosSalvos => 'Limites por categoria salvos.';

  @override
  String get acimaDoLimiteDaCategoria => 'Acima do limite da categoria';

  @override
  String get notificacoesOrcamento => 'Notificações de orçamento';

  @override
  String get diminuir => 'Diminuir';

  @override
  String get aumentar => 'Aumentar';

  @override
  String get menu => 'Menu';

  @override
  String get lista => 'Lista';

  @override
  String get listaNaoEncontrada => 'Lista não encontrada.';

  @override
  String get voltarParaListas => 'Voltar para as listas';

  @override
  String get nenhumItem => 'Nenhum item ainda';

  @override
  String get nenhumItemDica => 'Adicione no campo acima ou importe uma lista.';

  @override
  String get tempoAgora => 'agora';

  @override
  String tempoMinutos(int m) {
    return 'há $m min';
  }

  @override
  String tempoHoras(int h) {
    return 'há $h h';
  }

  @override
  String get tempoOntem => 'ontem';

  @override
  String tempoDias(int d) {
    return 'há $d dias';
  }

  @override
  String tempoMeses(int m) {
    return 'há $m meses';
  }

  @override
  String tempoAnos(int a) {
    return 'há $a anos';
  }

  @override
  String progressoLista(int concluidos, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: 'itens concluídos',
      one: 'item concluído',
    );
    return '$concluidos/$total $_temp0';
  }

  @override
  String get desmarcarTodos => 'Desmarcar todos';

  @override
  String get limparConcluidos => 'Limpar concluídos';

  @override
  String get limpar => 'Limpar';

  @override
  String get limparConcluidosMensagem =>
      'Os itens concluídos serão removidos da lista.';

  @override
  String get concluidosRemovidos => 'Itens concluídos removidos.';

  @override
  String get fechar => 'Fechar';

  @override
  String get importColeOuDigite => 'Cole ou digite sua lista:';

  @override
  String get importExemplo => '1kg de arroz, 2 leites, 500g de queijo prato...';

  @override
  String get importExtrairItens => 'Extrair itens';

  @override
  String get importLendo => 'Lendo...';

  @override
  String get importConfirmeItens => 'Confirme os itens';

  @override
  String get importRespostaInvalida =>
      'Não consegui entender a lista. Tente reescrever.';

  @override
  String get nadaReconhecido => 'Nada foi reconhecido';

  @override
  String get separarItensDica =>
      'Separe os itens por vírgula ou linha e tente de novo.';

  @override
  String get voltarEEditar => 'Voltar e editar';

  @override
  String importAdicionarN(int n) {
    return 'Adicionar $n';
  }

  @override
  String importSeraoAdicionados(int n, int total) {
    return '$n de $total serão adicionados';
  }

  @override
  String get importarLista => 'Importar lista';

  @override
  String get importLocalAvisoPadrao =>
      'Itens sem quantidade entraram com 1 un.';

  @override
  String get foto => 'Foto';

  @override
  String get tirarFoto => 'Tirar foto';

  @override
  String get escolherDaGaleria => 'Escolher da galeria';

  @override
  String get ocrLendo => 'Lendo a foto...';

  @override
  String get ocrNenhumTexto => 'Nenhum texto reconhecido na foto.';

  @override
  String get ocrFalha => 'Não foi possível ler a foto.';

  @override
  String get adicionarDeOutraLista => 'Adicionar de outra lista';

  @override
  String get escolherListaOrigem => 'Lista de origem';

  @override
  String get selecionarTodos => 'Selecionar todos';

  @override
  String get adicionarSelecionados => 'Adicionar';

  @override
  String get nenhumItemPendenteNaOrigem => 'Nenhum item pendente nesta lista.';

  @override
  String tituloListaArquivada(String titulo) {
    return '$titulo · Arquivada';
  }

  @override
  String itensAdicionadosDeOutra(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n itens adicionados de outra lista.',
      one: '1 item adicionado de outra lista.',
    );
    return '$_temp0';
  }

  @override
  String get buscar => 'Buscar';

  @override
  String get buscarLista => 'Buscar lista';

  @override
  String get buscarItem => 'Buscar item';

  @override
  String get limparBusca => 'Limpar busca';

  @override
  String get nenhumaListaEncontrada => 'Nenhuma lista encontrada';

  @override
  String get nenhumItemEncontrado => 'Nenhum item encontrado';

  @override
  String get buscaSemResultadoDica => 'Tente outro termo.';

  @override
  String itensExtraidos(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n itens extraídos.',
      one: '1 item extraído.',
    );
    return '$_temp0';
  }

  @override
  String get carregando => 'Carregando...';

  @override
  String get tentarNovamente => 'Tentar novamente';

  @override
  String get semValor => '—';

  @override
  String get configuracoes => 'Configurações';

  @override
  String get aparencia => 'Aparência';

  @override
  String get temaClaro => 'Claro';

  @override
  String get temaEscuro => 'Escuro';

  @override
  String get temaSistema => 'Sistema';

  @override
  String get ordenarCategorias => 'Ordenar categorias';

  @override
  String get ordenarCategoriasDica =>
      'Arraste para a ordem dos corredores do seu mercado.';

  @override
  String get restaurarPadrao => 'Restaurar padrão';

  @override
  String get restaurarPadraoTitulo => 'Restaurar a ordem padrão?';

  @override
  String get restaurarPadraoMensagem =>
      'As categorias voltam à ordem original.';

  @override
  String get sobre => 'Sobre';

  @override
  String get politicaPrivacidade => 'Política de Privacidade';

  @override
  String get versao => 'Versão';

  @override
  String get backup => 'Backup';

  @override
  String get backupExportar => 'Exportar backup';

  @override
  String get backupImportar => 'Importar backup';

  @override
  String get backupExportarAjuda =>
      'Compartilha um arquivo com suas listas para guardar ou levar a outro aparelho.';

  @override
  String get backupImportarAjuda =>
      'Restaura as listas de um arquivo, mesclando com as atuais.';

  @override
  String get backupExportado => 'Backup exportado.';

  @override
  String get backupImportado => 'Backup importado.';

  @override
  String get backupInvalido => 'Arquivo de backup inválido.';

  @override
  String get backupRestauracaoErro =>
      'Não foi possível restaurar o backup neste aparelho.';

  @override
  String get backupLeituraErro => 'Não foi possível ler o arquivo.';

  @override
  String get compartilharIndisponivel =>
      'Compartilhamento indisponível aqui. Use \"Copiar link\".';

  @override
  String get compartilharLista => 'Compartilhar';

  @override
  String get compartilharTexto => 'Enviar como texto';

  @override
  String get compartilharArquivo => 'Enviar arquivo';

  @override
  String get compartilharQr => 'QR code';

  @override
  String get copiarCodigo => 'Copiar código';

  @override
  String get codigoCopiado => 'Código copiado.';

  @override
  String get compartilharQrGrande => 'Lista grande — use texto ou arquivo.';

  @override
  String get listaCompartilhada => 'Lista compartilhada';

  @override
  String get compartilharIndisponivelLista =>
      'Compartilhamento indisponível aqui.';

  @override
  String get escanearQr => 'Escanear QR';

  @override
  String get receberLista => 'Receber lista';

  @override
  String get receberCodigoOuTexto => 'Cole o código ou o texto da lista';

  @override
  String get receberArquivo => 'Escolher arquivo';

  @override
  String get receberContinuar => 'Continuar';

  @override
  String get receberConfirmar => 'Criar lista';

  @override
  String get receberInvalido => 'Código ou arquivo inválido.';

  @override
  String get finalizarCompra => 'Finalizar compra';

  @override
  String get finalizarConfirmarTitulo => 'Finalizar esta compra?';

  @override
  String finalizarResumo(int n, String total, int semPreco) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n itens',
      one: '1 item',
    );
    String _temp1 = intl.Intl.pluralLogic(
      semPreco,
      locale: localeName,
      other: ' · $semPreco sem preço',
      zero: '',
    );
    return '$_temp0 · $total$_temp1';
  }

  @override
  String get finalizarLimpar => 'Limpar concluídos';

  @override
  String get finalizarManter => 'Manter a lista';

  @override
  String get compraRegistrada => 'Compra registrada no histórico.';

  @override
  String get historico => 'Histórico';

  @override
  String get historicoVazio => 'Nenhuma compra finalizada ainda.';

  @override
  String get historicoVazioDica =>
      'Marque itens e use \"Finalizar compra\" para registrar uma ida.';

  @override
  String get idaNaoEncontrada => 'Compra não encontrada.';

  @override
  String nItens(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n itens',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String get totalGasto => 'Total gasto';

  @override
  String get ticketMedio => 'Ticket médio';

  @override
  String get numeroIdas => 'Idas';

  @override
  String get mercado => 'Mercado';

  @override
  String get mercadoOpcional => 'Mercado (opcional)';

  @override
  String get porMercado => 'Por mercado';

  @override
  String get maisBarato => 'mais barato';

  @override
  String get gastoPorMercado => 'Gasto por mercado';

  @override
  String get semMercado => 'Sem mercado';

  @override
  String get mercadosSugeridos => 'Mercados usados';

  @override
  String get estatisticas => 'Estatísticas';

  @override
  String get abaIdas => 'Idas';

  @override
  String get gastoPorPeriodo => 'Gasto por período';

  @override
  String get gastoPorCategoria => 'Gasto por categoria';

  @override
  String get itensMaisComprados => 'Itens mais comprados';

  @override
  String get evolucaoDePreco => 'Evolução de preço';

  @override
  String get semDadosAinda => 'Sem dados ainda.';

  @override
  String totalNoPeriodo(String v) {
    return 'Total no período: $v';
  }

  @override
  String get porFrequencia => 'Frequência';

  @override
  String get porGasto => 'Gasto';

  @override
  String semanticaGastoMensal(String v) {
    return 'Gasto mensal: $v';
  }

  @override
  String semanticaEvolucaoPreco(String v) {
    return 'Evolução de preço: último $v';
  }

  @override
  String get boasVindasTitulo => 'Bem-vindo(a)';

  @override
  String get boasVindasSubtitulo => 'Organize suas compras no seu aparelho.';

  @override
  String get boasVindasOffline => 'Funciona offline';

  @override
  String get boasVindasOfflineDica => 'Suas listas ficam no aparelho.';

  @override
  String get boasVindasBackup => 'Backup quando quiser';

  @override
  String get boasVindasBackupDica =>
      'Exporte e restaure suas listas num arquivo.';

  @override
  String get boasVindasImportar => 'Importe por texto';

  @override
  String get boasVindasImportarDica =>
      'Cole uma anotação e o app organiza os itens.';

  @override
  String get boasVindasDitar => 'Dite um item';

  @override
  String get boasVindasDitarDica => 'Use o microfone para adicionar falando.';

  @override
  String get comecar => 'Começar';

  @override
  String get tourPular => 'Pular';

  @override
  String get tourAnterior => 'Anterior';

  @override
  String get tourProximo => 'Próximo';

  @override
  String get tourConcluir => 'Concluir';

  @override
  String tourPasso(int numero, int total) {
    return 'Passo $numero de $total';
  }

  @override
  String get tourAbrir => 'Ver tutorial';

  @override
  String get tourNovaListaTitulo => 'Criar sua primeira lista';

  @override
  String get tourNovaListaCorpo =>
      'Toque em \"Nova lista\" para começar. Você pode criar quantas quiser.';

  @override
  String get tourNomeTitulo => 'Dê um nome';

  @override
  String get tourNomeCorpo =>
      'O nome aparece no topo. Opcionalmente, defina um orçamento.';

  @override
  String get tourAdicionarTitulo => 'Adicionar item';

  @override
  String get tourAdicionarCorpo =>
      'Digite aqui. \"1kg de arroz\" já vira nome, quantidade e unidade.';

  @override
  String get tourUnidadeTitulo => 'Unidade';

  @override
  String get tourUnidadeCorpo =>
      'Escolha a medida (un, kg, pacote, pct, pt...). O app tenta adivinhar.';

  @override
  String get tourImportarTitulo => 'Importe por texto';

  @override
  String get tourImportarCorpo =>
      'Cole uma anotação e o app organiza os itens para você.';

  @override
  String get tourBuscaTitulo => 'Busca e filtros';

  @override
  String get tourBuscaCorpo =>
      'Encontre itens por nome e filtre por categoria ou unidade.';

  @override
  String get tourConfigTitulo => 'Configurações';

  @override
  String get tourConfigCorpo =>
      'Tema, categorias, backup e onde rever este tutorial.';

  @override
  String get tourMarcarTitulo => 'Marcar, editar e remover';

  @override
  String get tourMarcarCorpo =>
      'Toque no item para editar; marque no círculo; arraste para remover.';

  @override
  String get tourMercadoTitulo => 'Modo mercado';

  @override
  String get tourMercadoCorpo =>
      'No mercado, marque as compras sem perder o que falta.';

  @override
  String get tourOrcamentoTitulo => 'Orçamento e total';

  @override
  String get tourOrcamentoCorpo =>
      'Defina um teto e acompanhe o total do carrinho.';

  @override
  String politicaPrivacidadeTexto(String email) {
    return 'Política de Privacidade — Minhas Listas\n\n1. Dados que coletamos\nO aplicativo funciona inteiramente no seu aparelho.\n• Suas listas e itens ficam armazenados apenas no seu dispositivo.\n• Não criamos conta, não pedimos e-mail nem senha e não enviamos seus dados para servidores nossos.\n\n2. Voz\n• O recurso de adicionar itens por voz usa o reconhecedor de fala do seu aparelho. Conforme o sistema, o áudio pode ser processado pelo serviço de reconhecimento do dispositivo (que pode usar a internet). Não gravamos nem guardamos o áudio.\n\n3. Backup\n• Você pode exportar um arquivo de backup e reimportá-lo. O arquivo é criado no seu aparelho e só sai dele por uma ação sua (compartilhar/salvar).\n\n4. Com quem compartilhamos\nNão compartilhamos dados com terceiros. Não há publicidade nem rastreamento.\n\n5. Por quanto tempo guardamos\nSeus dados ficam no aparelho até você excluí-los no próprio aplicativo (removendo listas ou o app).\n\n6. Seus direitos\nVocê acessa, corrige e apaga tudo diretamente no aplicativo. O app não é direcionado a menores de 16 anos.\n\n7. Contato\nDúvidas sobre privacidade: $email.';
  }

  @override
  String get idiomaTitulo => 'Idioma';

  @override
  String get idiomaSistema => 'Sistema';

  @override
  String get idiomaPortugues => 'Português';

  @override
  String get idiomaIngles => 'English';

  @override
  String get idiomaEspanhol => 'Español';
}
