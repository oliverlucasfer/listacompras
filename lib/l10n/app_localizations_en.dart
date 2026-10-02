// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appNome => 'My Lists';

  @override
  String get erroGenerico => 'Could not complete. Please try again.';

  @override
  String get minhasListas => 'My Lists';

  @override
  String get abaMinhas => 'Mine';

  @override
  String get novaLista => 'New list';

  @override
  String get salvar => 'Save';

  @override
  String get cancelar => 'Cancel';

  @override
  String get renomear => 'Rename';

  @override
  String get excluir => 'Delete';

  @override
  String get mostrarArquivadas => 'Show archived';

  @override
  String get arquivar => 'Archive';

  @override
  String get desarquivar => 'Unarchive';

  @override
  String get arquivada => 'Archived';

  @override
  String get listaArquivada => 'List archived.';

  @override
  String get listaDesarquivada => 'List unarchived.';

  @override
  String get adicionarItem => 'Add item';

  @override
  String get itensConcluidos => 'Completed items';

  @override
  String get reordenar => 'Reorder';

  @override
  String get sugestoes => 'Suggestions';

  @override
  String get ditarItem => 'Dictate item';

  @override
  String get vozIndisponivel =>
      'Voice recognition is unavailable on this device.';

  @override
  String adicionarSugerido(String nome) {
    return 'Add $nome';
  }

  @override
  String get modoMercado => 'Shopping mode';

  @override
  String mercadoProgresso(int marcados, int total) {
    return '$marcados of $total';
  }

  @override
  String get mercadoMarcados => 'Checked';

  @override
  String get mercadoTudoComprado => 'All done!';

  @override
  String get voltarParaLista => 'Back to list';

  @override
  String get nenhumaLista => 'No lists here';

  @override
  String get criePrimeiraLista => 'Create your first list or import from text.';

  @override
  String get criarPrimeiraLista => 'Create first list';

  @override
  String get nomeDaLista => 'List name';

  @override
  String get criarLista => 'Create list';

  @override
  String get renomearLista => 'Rename list';

  @override
  String get listaCriada => 'List created.';

  @override
  String get listaRenomeada => 'List renamed.';

  @override
  String get comprarDeNovo => 'Buy again';

  @override
  String duplicarDescricao(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n pending items will be copied.',
      one: '1 pending item will be copied.',
    );
    return '$_temp0';
  }

  @override
  String get excluirLista => 'Delete list';

  @override
  String excluirListaTitulo(String titulo) {
    return 'Delete \"$titulo\"?';
  }

  @override
  String excluirListaMensagem(int n, String temMembros) {
    String _temp0 = intl.Intl.selectLogic(temMembros, {
      'true': ' for all participants',
      'other': '',
    });
    String _temp1 = intl.Intl.selectLogic(temMembros, {
      'true': ' for all participants',
      'other': '',
    });
    String _temp2 = intl.Intl.selectLogic(temMembros, {
      'true': ' for all participants',
      'other': '',
    });
    String _temp3 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'The $n items will be removed$_temp0.',
      one: 'The item will be removed$_temp1.',
      zero: 'The list will be deleted$_temp2.',
    );
    return '$_temp3';
  }

  @override
  String get atualizada => 'updated';

  @override
  String get erroNomeVazio => 'Enter a name.';

  @override
  String get erroQuantidadeInvalida => 'Enter a quantity greater than zero.';

  @override
  String get itens => 'Items';

  @override
  String get desfazer => 'Undo';

  @override
  String get itemRemovido => 'Item removed';

  @override
  String get itemDuplicadoSomado =>
      'is already on the list. Quantity increased.';

  @override
  String get itemAtualizado => 'Item updated.';

  @override
  String get naoEntendiItem => 'I did not understand the item';

  @override
  String get removerItem => 'Remove';

  @override
  String get editarItem => 'Edit item';

  @override
  String get nomeDoItem => 'Item name';

  @override
  String get quantidade => 'Quantity';

  @override
  String get unidade => 'Unit';

  @override
  String get categoria => 'Category';

  @override
  String get preco => 'Price (R\$)';

  @override
  String get erroPrecoInvalido => 'Invalid price.';

  @override
  String ultimaCompra(String valor, String data) {
    return 'Last purchase: $valor ($data)';
  }

  @override
  String get mesmoPreco => 'Same price';

  @override
  String precoSubiu(String diff) {
    return '↑ $diff';
  }

  @override
  String precoBaixou(String diff) {
    return '↓ $diff';
  }

  @override
  String get orcamento => 'Budget';

  @override
  String get campoOrcamento => 'Budget (R\$)';

  @override
  String get removerOrcamento => 'Remove budget';

  @override
  String get orcamentoDefinido => 'Budget saved.';

  @override
  String get orcamentoRemovido => 'Budget removed.';

  @override
  String get erroOrcamentoInvalido => 'Invalid budget amount.';

  @override
  String totalNoCarrinho(String valor, int semPreco) {
    String _temp0 = intl.Intl.pluralLogic(
      semPreco,
      locale: localeName,
      other: ' · $semPreco without price',
      zero: '',
    );
    return 'In cart: $valor$_temp0';
  }

  @override
  String totalComOrcamento(String valor, String orcamento, int semPreco) {
    String _temp0 = intl.Intl.pluralLogic(
      semPreco,
      locale: localeName,
      other: ' · $semPreco without price',
      zero: '',
    );
    return 'In cart: $valor of $orcamento$_temp0';
  }

  @override
  String get acimaDoOrcamento => 'Over budget';

  @override
  String get orcamentoAtencao => 'Near budget';

  @override
  String orcamentoCruzado(String total) {
    return 'You went over budget: $total';
  }

  @override
  String get orcamentoPorCategoria => 'Budget by category';

  @override
  String get limitePorCategoria => 'Limit (R\$)';

  @override
  String get categoriaSemLimite => 'No limit';

  @override
  String get orcamentosSalvos => 'Category limits saved.';

  @override
  String get acimaDoLimiteDaCategoria => 'Over category limit';

  @override
  String get notificacoesOrcamento => 'Budget notifications';

  @override
  String get diminuir => 'Decrease';

  @override
  String get aumentar => 'Increase';

  @override
  String get menu => 'Menu';

  @override
  String get lista => 'List';

  @override
  String get listaNaoEncontrada => 'List not found.';

  @override
  String get voltarParaListas => 'Back to lists';

  @override
  String get nenhumItem => 'No items yet';

  @override
  String get nenhumItemDica => 'Add in the field above or import a list.';

  @override
  String get tempoAgora => 'now';

  @override
  String tempoMinutos(int m) {
    return '$m min ago';
  }

  @override
  String tempoHoras(int h) {
    return '$h h ago';
  }

  @override
  String get tempoOntem => 'yesterday';

  @override
  String tempoDias(int d) {
    return '$d days ago';
  }

  @override
  String tempoMeses(int m) {
    return '$m months ago';
  }

  @override
  String tempoAnos(int a) {
    return '$a years ago';
  }

  @override
  String progressoLista(int concluidos, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: 'items completed',
      one: 'item completed',
    );
    return '$concluidos/$_temp0';
  }

  @override
  String get desmarcarTodos => 'Uncheck all';

  @override
  String get limparConcluidos => 'Clear completed';

  @override
  String get limpar => 'Clear';

  @override
  String get limparConcluidosMensagem =>
      'Completed items will be removed from the list.';

  @override
  String get concluidosRemovidos => 'Completed items removed.';

  @override
  String get fechar => 'Close';

  @override
  String get importColeOuDigite => 'Paste or type your list:';

  @override
  String get importExemplo => '1kg of rice, 2 milks, 500g of sliced cheese...';

  @override
  String get importExtrairItens => 'Extract items';

  @override
  String get importLendo => 'Reading...';

  @override
  String get importConfirmeItens => 'Confirm the items';

  @override
  String get importRespostaInvalida =>
      'I could not understand the list. Try rewriting it.';

  @override
  String get nadaReconhecido => 'Nothing was recognized';

  @override
  String get separarItensDica =>
      'Separate the items by comma or line and try again.';

  @override
  String get voltarEEditar => 'Back and edit';

  @override
  String importAdicionarN(int n) {
    return 'Add $n';
  }

  @override
  String importSeraoAdicionados(int n, int total) {
    return '$n of $total will be added';
  }

  @override
  String get importarLista => 'Import list';

  @override
  String get importLocalAvisoPadrao =>
      'Items without a quantity were added as 1 unit.';

  @override
  String get foto => 'Photo';

  @override
  String get tirarFoto => 'Take photo';

  @override
  String get escolherDaGaleria => 'Choose from gallery';

  @override
  String get ocrLendo => 'Reading the photo...';

  @override
  String get ocrNenhumTexto => 'No text recognized in the photo.';

  @override
  String get ocrFalha => 'Could not read the photo.';

  @override
  String get adicionarDeOutraLista => 'Add from another list';

  @override
  String get escolherListaOrigem => 'Source list';

  @override
  String get selecionarTodos => 'Select all';

  @override
  String get adicionarSelecionados => 'Add';

  @override
  String get nenhumItemPendenteNaOrigem => 'No pending items in this list.';

  @override
  String tituloListaArquivada(String titulo) {
    return '$titulo · Archived';
  }

  @override
  String itensAdicionadosDeOutra(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n items added from another list.',
      one: '1 item added from another list.',
    );
    return '$_temp0';
  }

  @override
  String get buscar => 'Search';

  @override
  String get buscarLista => 'Search list';

  @override
  String get buscarItem => 'Search item';

  @override
  String get limparBusca => 'Clear search';

  @override
  String get nenhumaListaEncontrada => 'No list found';

  @override
  String get nenhumItemEncontrado => 'No item found';

  @override
  String get buscaSemResultadoDica => 'Try another term.';

  @override
  String itensExtraidos(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n items extracted.',
      one: '1 item extracted.',
    );
    return '$_temp0';
  }

  @override
  String get carregando => 'Loading...';

  @override
  String get tentarNovamente => 'Try again';

  @override
  String get semValor => '—';

  @override
  String get configuracoes => 'Settings';

  @override
  String get aparencia => 'Appearance';

  @override
  String get temaClaro => 'Light';

  @override
  String get temaEscuro => 'Dark';

  @override
  String get temaSistema => 'System';

  @override
  String get ordenarCategorias => 'Sort categories';

  @override
  String get ordenarCategoriasDica => 'Drag to match your store aisle order.';

  @override
  String get restaurarPadrao => 'Restore default';

  @override
  String get restaurarPadraoTitulo => 'Restore the default order?';

  @override
  String get restaurarPadraoMensagem =>
      'Categories return to the original order.';

  @override
  String get sobre => 'About';

  @override
  String get politicaPrivacidade => 'Privacy Policy';

  @override
  String get versao => 'Version';

  @override
  String get backup => 'Backup';

  @override
  String get backupExportar => 'Export backup';

  @override
  String get backupImportar => 'Import backup';

  @override
  String get backupExportarAjuda =>
      'Shares a file with your lists to keep or take to another device.';

  @override
  String get backupImportarAjuda =>
      'Restores the lists from a file, merging with the current ones.';

  @override
  String get backupExportado => 'Backup exported.';

  @override
  String get backupImportado => 'Backup imported.';

  @override
  String get backupInvalido => 'Invalid backup file.';

  @override
  String get backupRestauracaoErro =>
      'Could not restore the backup on this device.';

  @override
  String get backupLeituraErro => 'Could not read the file.';

  @override
  String get compartilharIndisponivel =>
      'Sharing unavailable here. Use \"Copy link\".';

  @override
  String get compartilharLista => 'Share';

  @override
  String get compartilharTexto => 'Send as text';

  @override
  String get compartilharArquivo => 'Send file';

  @override
  String get compartilharQr => 'QR code';

  @override
  String get copiarCodigo => 'Copy code';

  @override
  String get codigoCopiado => 'Code copied.';

  @override
  String get compartilharQrGrande => 'Large list — use text or file.';

  @override
  String get listaCompartilhada => 'List shared';

  @override
  String get compartilharIndisponivelLista => 'Sharing unavailable here.';

  @override
  String get escanearQr => 'Scan QR';

  @override
  String get receberLista => 'Receive list';

  @override
  String get receberCodigoOuTexto => 'Paste the list code or text';

  @override
  String get receberArquivo => 'Choose file';

  @override
  String get receberContinuar => 'Continue';

  @override
  String get receberConfirmar => 'Create list';

  @override
  String get receberInvalido => 'Invalid code or file.';

  @override
  String get finalizarCompra => 'Finish shopping';

  @override
  String get finalizarConfirmarTitulo => 'Finish this shopping trip?';

  @override
  String finalizarResumo(int n, String total, int semPreco) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n items',
      one: '1 item',
    );
    String _temp1 = intl.Intl.pluralLogic(
      semPreco,
      locale: localeName,
      other: ' · $semPreco without price',
      zero: '',
    );
    return '$_temp0 · $total$_temp1';
  }

  @override
  String get finalizarLimpar => 'Clear completed';

  @override
  String get finalizarManter => 'Keep the list';

  @override
  String get compraRegistrada => 'Purchase recorded in history.';

  @override
  String get historico => 'History';

  @override
  String get historicoVazio => 'No finished purchases yet.';

  @override
  String get historicoVazioDica =>
      'Check items and use \"Finish shopping\" to record a trip.';

  @override
  String get idaNaoEncontrada => 'Purchase not found.';

  @override
  String nItens(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String get totalGasto => 'Total spent';

  @override
  String get ticketMedio => 'Average ticket';

  @override
  String get numeroIdas => 'Trips';

  @override
  String get mercado => 'Store';

  @override
  String get mercadoOpcional => 'Store (optional)';

  @override
  String get porMercado => 'By store';

  @override
  String get maisBarato => 'cheapest';

  @override
  String get gastoPorMercado => 'Spending by store';

  @override
  String get semMercado => 'No store';

  @override
  String get mercadosSugeridos => 'Stores used';

  @override
  String get estatisticas => 'Statistics';

  @override
  String get abaIdas => 'Trips';

  @override
  String get gastoPorPeriodo => 'Spending by period';

  @override
  String get gastoPorCategoria => 'Spending by category';

  @override
  String get itensMaisComprados => 'Most purchased items';

  @override
  String get evolucaoDePreco => 'Price evolution';

  @override
  String get semDadosAinda => 'No data yet.';

  @override
  String totalNoPeriodo(String v) {
    return 'Total for the period: $v';
  }

  @override
  String get porFrequencia => 'Frequency';

  @override
  String get porGasto => 'Spending';

  @override
  String semanticaGastoMensal(String v) {
    return 'Monthly spending: $v';
  }

  @override
  String semanticaEvolucaoPreco(String v) {
    return 'Price evolution: last $v';
  }

  @override
  String get boasVindasTitulo => 'Welcome';

  @override
  String get boasVindasSubtitulo => 'Organize your shopping on your device.';

  @override
  String get boasVindasOffline => 'Works offline';

  @override
  String get boasVindasOfflineDica => 'Your lists stay on the device.';

  @override
  String get boasVindasBackup => 'Backup whenever you want';

  @override
  String get boasVindasBackupDica => 'Export and restore your lists in a file.';

  @override
  String get boasVindasImportar => 'Import from text';

  @override
  String get boasVindasImportarDica =>
      'Paste a note and the app organizes the items.';

  @override
  String get boasVindasDitar => 'Dictate an item';

  @override
  String get boasVindasDitarDica => 'Use the microphone to add by speaking.';

  @override
  String get comecar => 'Get started';

  @override
  String get tourPular => 'Skip';

  @override
  String get tourAnterior => 'Previous';

  @override
  String get tourProximo => 'Next';

  @override
  String get tourConcluir => 'Finish';

  @override
  String tourPasso(int numero, int total) {
    return 'Step $numero of $total';
  }

  @override
  String get tourAbrir => 'View tutorial';

  @override
  String get tourNovaListaTitulo => 'Create your first list';

  @override
  String get tourNovaListaCorpo =>
      'Tap \"New list\" to start. You can create as many as you want.';

  @override
  String get tourNomeTitulo => 'Give it a name';

  @override
  String get tourNomeCorpo =>
      'The name appears at the top. Optionally, set a budget.';

  @override
  String get tourAdicionarTitulo => 'Add item';

  @override
  String get tourAdicionarCorpo =>
      'Type here. \"1kg of rice\" becomes name, quantity, and unit.';

  @override
  String get tourUnidadeTitulo => 'Unit';

  @override
  String get tourUnidadeCorpo =>
      'Choose the measure (un, kg, package, pct, pt...). The app tries to guess.';

  @override
  String get tourImportarTitulo => 'Import from text';

  @override
  String get tourImportarCorpo =>
      'Paste a note and the app organizes the items for you.';

  @override
  String get tourBuscaTitulo => 'Search and filters';

  @override
  String get tourBuscaCorpo =>
      'Find items by name and filter by category or unit.';

  @override
  String get tourConfigTitulo => 'Settings';

  @override
  String get tourConfigCorpo =>
      'Theme, categories, backup, and where to revisit this tutorial.';

  @override
  String get tourMarcarTitulo => 'Check, edit, and remove';

  @override
  String get tourMarcarCorpo =>
      'Tap the item to edit; check the circle; drag to remove.';

  @override
  String get tourMercadoTitulo => 'Shopping mode';

  @override
  String get tourMercadoCorpo =>
      'At the store, check purchases without losing what is left.';

  @override
  String get tourOrcamentoTitulo => 'Budget and total';

  @override
  String get tourOrcamentoCorpo => 'Set a ceiling and track the cart total.';

  @override
  String politicaPrivacidadeTexto(String email) {
    return 'Privacy Policy — My Lists\n\n1. Data we collect\nThe app works entirely on your device.\n• Your lists and items are stored only on your device.\n• We do not create accounts, do not ask for email or password, and do not send your data to our servers.\n\n2. Voice\n• The add-items-by-voice feature uses the speech recognizer of your device. Depending on the system, audio may be processed by the device recognition service (which may use the internet). We do not record or keep the audio.\n\n3. Backup\n• You can export a backup file and reimport it. The file is created on your device and only leaves it through an action of yours (share/save).\n\n4. With whom we share\nWe do not share data with third parties. There is no advertising or tracking.\n\n5. How long we keep it\nYour data stays on the device until you delete it in the app itself (removing lists or the app).\n\n6. Your rights\nYou access, correct, and delete everything directly in the app. The app is not directed to children under 16.\n\n7. Contact\nPrivacy questions: $email.';
  }

  @override
  String get idiomaTitulo => 'Language';

  @override
  String get idiomaSistema => 'System';

  @override
  String get idiomaPortugues => 'Portuguese';

  @override
  String get idiomaIngles => 'English';

  @override
  String get idiomaEspanhol => 'Spanish';
}
