/// Strings pt-BR centralizadas do MVP (doc 05 §7). Hardcoded no MVP;
/// centralizadas aqui para facilitar futura tradução.
abstract final class AppStrings {
  // App
  static const appNome = 'Lista de Compras';

  // Autenticação
  static const entrar = 'Entrar';
  static const criarConta = 'Criar conta';
  static const criarMinhaConta = 'Criar minha conta';
  static const recuperarSenha = 'Recuperar senha';
  static const esqueciMinhaSenha = 'Esqueci minha senha';
  static const email = 'E-mail';
  static const senha = 'Senha';
  static const confirmarSenha = 'Confirmar senha';
  static const enviarLinkEmail = 'Enviar link por e-mail';
  static const informeSeuEmail = 'Informe seu e-mail:';
  static const linkUnicoExpira =
      'Link único, expira conforme configuração do serviço.';
  static const mostrarSenha = 'Mostrar senha';
  static const ocultarSenha = 'Ocultar senha';
  static const verificarSeuEmail = 'Verifique seu e-mail';
  static const verificarEmailMensagem =
      'Enviamos um link de confirmação para o seu e-mail. Clique nele para ativar sua conta.';
  static const reenviarLink = 'Reenviar link';
  static const linkReenviado = 'Link reenviado.';
  static const linkEnviado =
      'Se o e-mail estiver cadastrado, o link de recuperação foi enviado.';
  static const definirNovaSenha = 'Definir nova senha';
  static const novaSenha = 'Nova senha';
  static const senhaAlterada = 'Senha alterada.';
  static const pedirNovoLink = 'Pedir novo link';
  static const nadaReconhecido = 'Nada foi reconhecido';
  static const separarItensDica =
      'Separe os itens por vírgula ou linha e tente de novo.';
  static const voltarEEditar = 'Voltar e editar';
  static const erroRedefinirSenha =
      'Não foi possível salvar a senha. O link pode ter expirado.';
  static const liPoliticaPrivacidade = 'Li a Política de Privacidade';
  static const verPolitica = 'Ver política';
  static const sair = 'Sair';
  static const sairContaTitulo = 'Sair da conta?';
  static const sairContaMensagem =
      'Você precisará entrar novamente para acessar suas listas.';

  // Erros de autenticação (inline, wireframe 10 §1)
  static const erroEmailInvalido = 'Informe um e-mail válido.';
  static const erroSenhaCurta = 'A senha precisa ter ao menos 6 caracteres.';
  static const erroSenhasDiferentes = 'As senhas não coincidem.';
  static const erroCamposVazios = 'Preencha os campos acima.';
  static const erroPoliticaPrivacidade = 'É necessário aceitar a política.';
  static const erroAutenticacao = 'E-mail ou senha incorretos.';
  static const erroEmailJaCadastrado = 'E-mail já cadastrado.';
  static const erroGenerico = 'Não foi possível concluir. Tente novamente.';

  // Listas
  static const minhasListas = 'Minhas Listas';
  static const abaMinhas = 'Minhas';
  static const compartilhadas = 'Compartilhadas';
  static const nenhumaCompartilhada = 'Nenhuma lista compartilhada';
  static const nenhumaCompartilhadaDica =
      'Quando alguém compartilhar uma lista com você, ela aparece aqui.';
  static const novaLista = 'Nova lista';
  static const tituloLista = 'Título da lista';
  static const salvar = 'Salvar';
  static const cancelar = 'Cancelar';
  static const renomear = 'Renomear';
  static const excluir = 'Excluir';

  // Itens
  static const adicionarItem = 'Adicionar item';
  static const itensConcluidos = 'Itens concluídos';
  static const reordenar = 'Reordenar';
  static const sugestoes = 'Sugestões';

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
  static const diminuir = 'Diminuir';
  static const aumentar = 'Aumentar';
  static const menu = 'Menu';
  static const lista = 'Lista';
  static const listaNaoEncontrada = 'Lista não encontrada.';
  static const voltarParaListas = 'Voltar para as listas';
  static const nenhumItem = 'Nenhum item ainda';
  static const nenhumItemDica = 'Adicione o primeiro item no campo acima.';
  static const listaVazia = 'Lista vazia';
  static const listaVaziaDica = 'Ainda não há itens nesta lista.';

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

  // Papel do usuário na lista (doc 08 §1, RF-13, F7-T04)
  static const somenteLeitura = 'Somente leitura';
  static const somenteLeituraDica =
      'Você pode visualizar esta lista, mas não editá-la.';

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
  static const erroSemConexao =
      'Sem conexão. Verifique sua internet e tente novamente.';

  static String importAdicionarN(int n) => 'Adicionar $n';
  static String importSeraoAdicionados(int n, int total) =>
      '$n de $total serão adicionados';

  // Importação de lista (RF-16): modo local sem IA
  static const importarLista = 'Importar lista';
  static const importLocalAvisoPadrao =
      'Itens sem quantidade entraram com 1 un.';
  static const importLocalTextoLongo =
      'Texto muito longo. Envie até 10.000 caracteres.';

  // Compartilhamento por convite (doc 08, RF-13)
  static const conviteInvalido = 'Este convite não é mais válido.';
  static const conviteSemConexao =
      'Sem conexão para entrar na lista. Verifique sua internet e tente novamente.';
  static const conviteInesperado =
      'Não foi possível entrar na lista. Tente novamente.';
  static const conviteListaNaoSincronizada =
      'Esta lista ainda não foi sincronizada. Verifique sua internet e tente novamente em instantes.';
  static const conviteConvidadoTitulo = 'Você foi convidado para uma lista';
  static const conviteConvidadoMensagem =
      'Entre na sua conta (ou crie uma) para aceitar o convite e acessar a lista.';
  static const conviteConvidadoEntrar = 'Entrar';
  static const conviteConvidadoRegistrar = 'Criar conta';
  static const conviteComCodigo = 'Entrar com código';
  static const conviteCampoCodigo = 'Cole aqui o código do convite';

  // Sheet "Convidar" e tela de membros (doc 08 §5/§8, F7-T03)
  static const convidar = 'Convidar';
  static const nenhumParticipante = 'Nenhum participante ainda';
  static const nenhumParticipanteDica =
      'Confira se você ainda tem acesso a esta lista.';
  static const convidarPapelEditor = 'Editor';
  static const convidarPapelLeitor = 'Leitor';
  static const gerarLink = 'Gerar link';
  static const copiarLink = 'Copiar link';
  static const copiarCodigo = 'Copiar código';
  static const copiarLinkAjuda =
      'Copia o endereço completo para enviar por onde quiser.';
  static const copiarCodigoAjuda =
      'Copia só o código, para colar em "Entrar com código".';
  static const compartilhar = 'Compartilhar';
  static const linkCopiado = 'Link copiado para a área de transferência.';
  static const codigoCopiado = 'Código copiado para a área de transferência.';
  static const linkCompartilhado = 'Link compartilhado.';
  static const revogarConvite = 'Revogar link';
  static const revogarConvitePendente = 'Revogar';
  static const conviteRevogado = 'Convite revogado. O link não funciona mais.';
  static const convitesPendentes = 'Convites pendentes';
  static const convitePendenteAjuda =
      'Este link ainda dá acesso à lista. Revogue para invalidá-lo.';
  static const compartilharIndisponivel =
      'Compartilhamento indisponível aqui. Use "Copiar link".';
  static const papelAtualizado = 'Papel atualizado.';
  static const membroRemovido = 'Membro removido.';
  static const membros = 'Membros';
  static const voce = 'Você';
  static const papelDono = 'Dono';
  static const mudarPapel = 'Mudar papel';
  static const removerMembro = 'Remover';
  static const removerMembroMensagem = 'Remover este membro da lista?';
  static const sairDaLista = 'Sair da lista';
  static const sairListaTitulo = 'Sair da lista';
  static const sairListaMensagem = 'Você deixará de ter acesso a esta lista.';
  static const membroEntrou = 'Um novo membro entrou na lista';

  static String itensExtraidos(int n) =>
      n == 1 ? '1 item extraído.' : '$n itens extraídos.';

  // Busca/filtro local (RF-17, F16)
  static const buscar = 'Buscar';
  static const buscarLista = 'Buscar lista';
  static const buscarItem = 'Buscar item';
  static const limparBusca = 'Limpar busca';
  static const nenhumaListaEncontrada = 'Nenhuma lista encontrada';
  static const nenhumItemEncontrado = 'Nenhum item encontrado';
  static const buscaSemResultadoDica = 'Tente outro termo.';

  // Estados transversais
  static const carregando = 'Carregando...';
  static const tentarNovamente = 'Tentar novamente';
  static const offline = 'Offline — alterações serão sincronizadas';
  static const semValor = '—';

  // Indicador de sync (doc 03 §6, wireframe 10 §3.2)
  static const syncSincronizado = 'Sincronizado';
  static const syncSincronizando = 'Sincronizando';
  static const syncSemConexao =
      'Sem conexão — alterações serão sincronizadas depois';
  static const syncErro = 'Erro na sincronização.';

  static String syncPendentes(int n) =>
      n == 1 ? '1 alteração pendente' : '$n alterações pendentes';

  // Configurações (doc 06 §3, wireframe 10 §5)
  static const configuracoes = 'Configurações';
  static const aparencia = 'Aparência';
  static const temaClaro = 'Claro';
  static const temaEscuro = 'Escuro';
  static const temaSistema = 'Sistema';
  static const conta = 'Conta';
  static const sobre = 'Sobre';
  static const politicaPrivacidade = 'Política de Privacidade';
  static const versao = 'Versão';
  static const excluirMinhaConta = 'Excluir minha conta';
  static const excluirMinhaContaAviso =
      'Apaga TODAS as suas listas permanentemente.';
  static const excluirContaTitulo = 'Excluir minha conta';
  static const excluirContaSenhaMensagem =
      'Esta ação é permanente e apaga TODAS as suas listas. '
      'Digite sua senha para continuar.';
  static const continuar = 'Continuar';
  static const excluirContaMensagemFinal =
      'Esta ação é permanente e apaga todas as suas listas. Tem certeza?';
  static const excluirConta = 'Excluir conta';
  static const senhaIncorreta = 'Senha incorreta.';
  static const reautenticando = 'Verificando...';
  static const excluindoConta = 'Excluindo conta...';
  static const callbackLoginFalhou = 'Não foi possível concluir a verificação.';
  static const voltarAoLogin = 'Voltar ao login';
}
