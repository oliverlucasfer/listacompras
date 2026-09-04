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
  static const verificarSeuEmail = 'Verifique seu e-mail';
  static const verificarEmailMensagem =
      'Enviamos um link de confirmação para o seu e-mail. Clique nele para ativar sua conta.';
  static const reenviarLink = 'Reenviar link';
  static const linkEnviado =
      'Se o e-mail estiver cadastrado, o link de recuperação foi enviado.';
  static const definirNovaSenha = 'Definir nova senha';
  static const novaSenha = 'Nova senha';
  static const liPoliticaPrivacidade = 'Li a Política de Privacidade';
  static const sair = 'Sair';

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
  static const novaLista = 'Nova lista';
  static const tituloLista = 'Título da lista';
  static const salvar = 'Salvar';
  static const cancelar = 'Cancelar';
  static const renomear = 'Renomear';
  static const excluir = 'Excluir';

  // Itens
  static const adicionarItem = 'Adicionar item';
  static const importarPorIa = 'Importar por IA';
  static const itensConcluidos = 'Itens concluídos';
  static const reordenar = 'Reordenar';

  // Painel Minhas Listas (wireframe 10 §2)
  static const nenhumaLista = 'Nenhuma lista por aqui';
  static const criePrimeiraLista =
      'Crie sua primeira lista ou importe por texto com IA.';
  static const criarPrimeiraLista = 'Criar primeira lista';
  static const nomeDaLista = 'Nome da lista';
  static const criarLista = 'Criar lista';
  static const renomearLista = 'Renomear lista';
  static const excluirLista = 'Excluir lista';
  static const excluirListaMensagem =
      'Excluir esta lista? Esta ação não pode ser desfeita.';
  static const atualizada = 'atualizada';
  static const erroNomeVazio = 'Informe um nome.';

  // Tela da Lista (wireframe 10 §3, doc 05 §6.3)
  static const itens = 'Itens';
  static const desfazer = 'Desfazer';
  static const itemRemovido = 'Item removido';
  static const itemDuplicadoSomado = 'já está na lista. Quantidade aumentada.';
  static const editarItem = 'Editar item';
  static const quantidade = 'Quantidade';
  static const unidade = 'Unidade';
  static const listaNaoEncontrada = 'Lista não encontrada.';

  // Ações em massa (doc 05 §6.3, wireframe 10 §3.4)
  static const desmarcarTodos = 'Desmarcar todos';
  static const limparConcluidos = 'Limpar concluídos';
  static const limpar = 'Limpar';
  static const limparConcluidosMensagem =
      'Os itens concluídos serão removidos da lista.';

  // Importação por IA (doc 04 §2, wireframe 10 §4.1)
  static const fechar = 'Fechar';
  static const iaColeOuDigite = 'Cole ou digite sua lista:';
  static const iaExtrairItens = 'Extrair itens';
  static const iaLendo = 'Lendo...';
  static const iaConfirmeItens = 'Confirme os itens';

  static String iaAdicionarN(int n) => 'Adicionar $n';
  static String iaSeraoAdicionados(int n, int total) =>
      '$n de $total serão adicionados';

  // Mensagens amigáveis do contrato de IA (doc 04 §2) — fallback quando o
  // servidor não envia `message` (ex.: rejeição do gateway).
  static const iaSessaoExpirada = 'Sessão expirada. Faça login novamente.';
  static const iaTextoVazio = 'Digite ou cole um texto com os itens.';
  static const iaTextoLongo = 'Texto muito longo. Envie até 2.000 caracteres.';
  static const iaRespostaInvalida =
      'Não consegui entender a lista. Tente reescrever.';
  static const iaRateLimit = 'Muitas solicitações. Aguarde um instante.';
  static const iaCotaIa =
      'Limite diário de importações atingido. Tente amanhã.';
  static const iaTimeoutIa = 'A IA demorou demais. Tente novamente.';
  static const iaErroInterno = 'Erro inesperado. Tente novamente.';
  static const iaSemConexao =
      'Sem conexão. Verifique sua internet e tente novamente.';

  static String itensExtraidos(int n) =>
      n == 1 ? '1 item extraído.' : '$n itens extraídos.';

  // Estados transversais
  static const carregando = 'Carregando...';
  static const tentarNovamente = 'Tentar novamente';
  static const offline = 'Offline — alterações serão sincronizadas';

  // Indicador de sync (doc 03 §6, wireframe 10 §3.2)
  static const syncSincronizado = 'Sincronizado';
  static const syncSincronizando = 'Sincronizando';
  static const syncSemConexao =
      'Sem conexão — alterações serão sincronizadas depois';
  static const syncErro = 'Erro na sincronização.';

  static String syncPendentes(int n) =>
      n == 1 ? '1 alteração pendente' : '$n alterações pendentes';
}
