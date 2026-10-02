// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appNome => 'Mis listas';

  @override
  String get erroGenerico => 'No se pudo completar. Inténtalo de nuevo.';

  @override
  String get minhasListas => 'Mis listas';

  @override
  String get abaMinhas => 'Mías';

  @override
  String get novaLista => 'Nueva lista';

  @override
  String get salvar => 'Guardar';

  @override
  String get cancelar => 'Cancelar';

  @override
  String get renomear => 'Renombrar';

  @override
  String get excluir => 'Eliminar';

  @override
  String get mostrarArquivadas => 'Mostrar archivadas';

  @override
  String get arquivar => 'Archivar';

  @override
  String get desarquivar => 'Desarchivar';

  @override
  String get arquivada => 'Archivada';

  @override
  String get listaArquivada => 'Lista archivada.';

  @override
  String get listaDesarquivada => 'Lista desarchivada.';

  @override
  String get adicionarItem => 'Añadir artículo';

  @override
  String get itensConcluidos => 'Artículos completados';

  @override
  String get reordenar => 'Reordenar';

  @override
  String get sugestoes => 'Sugerencias';

  @override
  String get ditarItem => 'Dictar artículo';

  @override
  String get vozIndisponivel =>
      'Reconocimiento de voz no disponible en este dispositivo.';

  @override
  String adicionarSugerido(String nome) {
    return 'Añadir $nome';
  }

  @override
  String get modoMercado => 'Modo compra';

  @override
  String mercadoProgresso(int marcados, int total) {
    return '$marcados de $total';
  }

  @override
  String get mercadoMarcados => 'Marcados';

  @override
  String get mercadoTudoComprado => '¡Todo comprado!';

  @override
  String get voltarParaLista => 'Volver a la lista';

  @override
  String get nenhumaLista => 'No hay listas aquí';

  @override
  String get criePrimeiraLista =>
      'Crea tu primera lista o importa desde texto.';

  @override
  String get criarPrimeiraLista => 'Crear primera lista';

  @override
  String get nomeDaLista => 'Nombre de la lista';

  @override
  String get criarLista => 'Crear lista';

  @override
  String get renomearLista => 'Renombrar lista';

  @override
  String get listaCriada => 'Lista creada.';

  @override
  String get listaRenomeada => 'Lista renombrada.';

  @override
  String get comprarDeNovo => 'Comprar de nuevo';

  @override
  String duplicarDescricao(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Se copiarán $n artículos pendientes.',
      one: 'Se copiará 1 artículo pendiente.',
    );
    return '$_temp0';
  }

  @override
  String get excluirLista => 'Eliminar lista';

  @override
  String excluirListaTitulo(String titulo) {
    return '¿Eliminar \"$titulo\"?';
  }

  @override
  String excluirListaMensagem(int n, String temMembros) {
    String _temp0 = intl.Intl.selectLogic(temMembros, {
      'true': ' para todos los participantes',
      'other': '',
    });
    String _temp1 = intl.Intl.selectLogic(temMembros, {
      'true': ' para todos los participantes',
      'other': '',
    });
    String _temp2 = intl.Intl.selectLogic(temMembros, {
      'true': ' para todos los participantes',
      'other': '',
    });
    String _temp3 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Se eliminarán los $n artículos$_temp0.',
      one: 'El artículo se eliminará$_temp1.',
      zero: 'La lista se eliminará$_temp2.',
    );
    return '$_temp3';
  }

  @override
  String get atualizada => 'actualizada';

  @override
  String get erroNomeVazio => 'Escribe un nombre.';

  @override
  String get erroQuantidadeInvalida => 'Escribe una cantidad mayor que cero.';

  @override
  String get itens => 'Artículos';

  @override
  String get desfazer => 'Deshacer';

  @override
  String get itemRemovido => 'Artículo eliminado';

  @override
  String get itemDuplicadoSomado => 'ya está en la lista. Cantidad aumentada.';

  @override
  String get itemAtualizado => 'Artículo actualizado.';

  @override
  String get naoEntendiItem => 'No entendí el artículo';

  @override
  String get removerItem => 'Quitar';

  @override
  String get editarItem => 'Editar artículo';

  @override
  String get nomeDoItem => 'Nombre del artículo';

  @override
  String get quantidade => 'Cantidad';

  @override
  String get unidade => 'Unidad';

  @override
  String get categoria => 'Categoría';

  @override
  String get preco => 'Precio (R\$)';

  @override
  String get erroPrecoInvalido => 'Precio no válido.';

  @override
  String ultimaCompra(String valor, String data) {
    return 'Última compra: $valor ($data)';
  }

  @override
  String get mesmoPreco => 'Mismo precio';

  @override
  String precoSubiu(String diff) {
    return '↑ $diff';
  }

  @override
  String precoBaixou(String diff) {
    return '↓ $diff';
  }

  @override
  String get orcamento => 'Presupuesto';

  @override
  String get campoOrcamento => 'Presupuesto (R\$)';

  @override
  String get removerOrcamento => 'Quitar presupuesto';

  @override
  String get orcamentoDefinido => 'Presupuesto guardado.';

  @override
  String get orcamentoRemovido => 'Presupuesto quitado.';

  @override
  String get erroOrcamentoInvalido => 'Importe de presupuesto no válido.';

  @override
  String totalNoCarrinho(String valor, int semPreco) {
    String _temp0 = intl.Intl.pluralLogic(
      semPreco,
      locale: localeName,
      other: ' · $semPreco sin precio',
      zero: '',
    );
    return 'En el carrito: $valor$_temp0';
  }

  @override
  String totalComOrcamento(String valor, String orcamento, int semPreco) {
    String _temp0 = intl.Intl.pluralLogic(
      semPreco,
      locale: localeName,
      other: ' · $semPreco sin precio',
      zero: '',
    );
    return 'En el carrito: $valor de $orcamento$_temp0';
  }

  @override
  String get acimaDoOrcamento => 'Por encima del presupuesto';

  @override
  String get orcamentoAtencao => 'Cerca del presupuesto';

  @override
  String orcamentoCruzado(String total) {
    return 'Te pasaste del presupuesto: $total';
  }

  @override
  String get orcamentoPorCategoria => 'Presupuesto por categoría';

  @override
  String get limitePorCategoria => 'Límite (R\$)';

  @override
  String get categoriaSemLimite => 'Sin límite';

  @override
  String get orcamentosSalvos => 'Límites por categoría guardados.';

  @override
  String get acimaDoLimiteDaCategoria =>
      'Por encima del límite de la categoría';

  @override
  String get notificacoesOrcamento => 'Notificaciones de presupuesto';

  @override
  String get diminuir => 'Disminuir';

  @override
  String get aumentar => 'Aumentar';

  @override
  String get menu => 'Menú';

  @override
  String get lista => 'Lista';

  @override
  String get listaNaoEncontrada => 'Lista no encontrada.';

  @override
  String get voltarParaListas => 'Volver a las listas';

  @override
  String get nenhumItem => 'Aún no hay artículos';

  @override
  String get nenhumItemDica =>
      'Añade en el campo de arriba o importa una lista.';

  @override
  String get tempoAgora => 'ahora';

  @override
  String tempoMinutos(int m) {
    return 'hace $m min';
  }

  @override
  String tempoHoras(int h) {
    return 'hace $h h';
  }

  @override
  String get tempoOntem => 'ayer';

  @override
  String tempoDias(int d) {
    return 'hace $d días';
  }

  @override
  String tempoMeses(int m) {
    return 'hace $m meses';
  }

  @override
  String tempoAnos(int a) {
    return 'hace $a años';
  }

  @override
  String progressoLista(int concluidos, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: 'artículos completados',
      one: 'artículo completado',
    );
    return '$concluidos/$total $_temp0';
  }

  @override
  String get desmarcarTodos => 'Desmarcar todos';

  @override
  String get limparConcluidos => 'Limpiar completados';

  @override
  String get limpar => 'Limpiar';

  @override
  String get limparConcluidosMensagem =>
      'Los artículos completados se quitarán de la lista.';

  @override
  String get concluidosRemovidos => 'Artículos completados eliminados.';

  @override
  String get fechar => 'Cerrar';

  @override
  String get importColeOuDigite => 'Pega o escribe tu lista:';

  @override
  String get importExemplo =>
      '1kg de arroz, 2 leches, 500g de queso loncheado...';

  @override
  String get importExtrairItens => 'Extraer artículos';

  @override
  String get importLendo => 'Leyendo...';

  @override
  String get importConfirmeItens => 'Confirma los artículos';

  @override
  String get importRespostaInvalida =>
      'No entendí la lista. Intenta reescribirla.';

  @override
  String get nadaReconhecido => 'No se reconoció nada';

  @override
  String get separarItensDica =>
      'Separa los artículos por coma o línea e inténtalo de nuevo.';

  @override
  String get voltarEEditar => 'Volver y editar';

  @override
  String importAdicionarN(int n) {
    return 'Añadir $n';
  }

  @override
  String importSeraoAdicionados(int n, int total) {
    return 'Se añadirán $n de $total';
  }

  @override
  String get importarLista => 'Importar lista';

  @override
  String get importLocalAvisoPadrao =>
      'Los artículos sin cantidad se añadieron como 1 un.';

  @override
  String get foto => 'Foto';

  @override
  String get tirarFoto => 'Tomar foto';

  @override
  String get escolherDaGaleria => 'Elegir de la galería';

  @override
  String get ocrLendo => 'Leyendo la foto...';

  @override
  String get ocrNenhumTexto => 'No se reconoció texto en la foto.';

  @override
  String get ocrFalha => 'No se pudo leer la foto.';

  @override
  String get adicionarDeOutraLista => 'Añadir de otra lista';

  @override
  String get escolherListaOrigem => 'Lista de origen';

  @override
  String get selecionarTodos => 'Seleccionar todo';

  @override
  String get adicionarSelecionados => 'Añadir';

  @override
  String get nenhumItemPendenteNaOrigem =>
      'No hay artículos pendientes en esta lista.';

  @override
  String tituloListaArquivada(String titulo) {
    return '$titulo · Archivada';
  }

  @override
  String itensAdicionadosDeOutra(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Se añadieron $n artículos de otra lista.',
      one: 'Se añadió 1 artículo de otra lista.',
    );
    return '$_temp0';
  }

  @override
  String get buscar => 'Buscar';

  @override
  String get buscarLista => 'Buscar lista';

  @override
  String get buscarItem => 'Buscar artículo';

  @override
  String get limparBusca => 'Limpiar búsqueda';

  @override
  String get nenhumaListaEncontrada => 'No se encontró ninguna lista';

  @override
  String get nenhumItemEncontrado => 'No se encontró ningún artículo';

  @override
  String get buscaSemResultadoDica => 'Prueba otro término.';

  @override
  String itensExtraidos(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n artículos extraídos.',
      one: '1 artículo extraído.',
    );
    return '$_temp0';
  }

  @override
  String get carregando => 'Cargando...';

  @override
  String get tentarNovamente => 'Reintentar';

  @override
  String get semValor => '—';

  @override
  String get configuracoes => 'Ajustes';

  @override
  String get aparencia => 'Apariencia';

  @override
  String get temaClaro => 'Claro';

  @override
  String get temaEscuro => 'Oscuro';

  @override
  String get temaSistema => 'Sistema';

  @override
  String get ordenarCategorias => 'Ordenar categorías';

  @override
  String get ordenarCategoriasDica =>
      'Arrastra para el orden de los pasillos de tu supermercado.';

  @override
  String get restaurarPadrao => 'Restaurar predeterminado';

  @override
  String get restaurarPadraoTitulo => '¿Restaurar el orden predeterminado?';

  @override
  String get restaurarPadraoMensagem =>
      'Las categorías vuelven al orden original.';

  @override
  String get sobre => 'Acerca de';

  @override
  String get politicaPrivacidade => 'Política de Privacidad';

  @override
  String get versao => 'Versión';

  @override
  String get backup => 'Copia de seguridad';

  @override
  String get backupExportar => 'Exportar copia';

  @override
  String get backupImportar => 'Importar copia';

  @override
  String get backupExportarAjuda =>
      'Comparte un archivo con tus listas para guardar o llevar a otro dispositivo.';

  @override
  String get backupImportarAjuda =>
      'Restaura las listas de un archivo, combinándolas con las actuales.';

  @override
  String get backupExportado => 'Copia exportada.';

  @override
  String get backupImportado => 'Copia importada.';

  @override
  String get backupInvalido => 'Archivo de copia no válido.';

  @override
  String get backupRestauracaoErro =>
      'No se pudo restaurar la copia en este dispositivo.';

  @override
  String get backupLeituraErro => 'No se pudo leer el archivo.';

  @override
  String get compartilharIndisponivel =>
      'Compartir no disponible aquí. Usa \"Copiar enlace\".';

  @override
  String get compartilharLista => 'Compartir';

  @override
  String get compartilharTexto => 'Enviar como texto';

  @override
  String get compartilharArquivo => 'Enviar archivo';

  @override
  String get compartilharQr => 'Código QR';

  @override
  String get copiarCodigo => 'Copiar código';

  @override
  String get codigoCopiado => 'Código copiado.';

  @override
  String get compartilharQrGrande => 'Lista grande: usa texto o archivo.';

  @override
  String get listaCompartilhada => 'Lista compartida';

  @override
  String get compartilharIndisponivelLista => 'Compartir no disponible aquí.';

  @override
  String get escanearQr => 'Escanear QR';

  @override
  String get receberLista => 'Recibir lista';

  @override
  String get receberCodigoOuTexto => 'Pega el código o el texto de la lista';

  @override
  String get receberArquivo => 'Elegir archivo';

  @override
  String get receberContinuar => 'Continuar';

  @override
  String get receberConfirmar => 'Crear lista';

  @override
  String get receberInvalido => 'Código o archivo no válido.';

  @override
  String get finalizarCompra => 'Finalizar compra';

  @override
  String get finalizarConfirmarTitulo => '¿Finalizar esta compra?';

  @override
  String finalizarResumo(int n, String total, int semPreco) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n artículos',
      one: '1 artículo',
    );
    String _temp1 = intl.Intl.pluralLogic(
      semPreco,
      locale: localeName,
      other: ' · $semPreco sin precio',
      zero: '',
    );
    return '$_temp0 · $total$_temp1';
  }

  @override
  String get finalizarLimpar => 'Limpiar completados';

  @override
  String get finalizarManter => 'Mantener la lista';

  @override
  String get compraRegistrada => 'Compra registrada en el historial.';

  @override
  String get historico => 'Historial';

  @override
  String get historicoVazio => 'Aún no hay compras finalizadas.';

  @override
  String get historicoVazioDica =>
      'Marca artículos y usa \"Finalizar compra\" para registrar una visita.';

  @override
  String get idaNaoEncontrada => 'Compra no encontrada.';

  @override
  String nItens(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n artículos',
      one: '1 artículo',
    );
    return '$_temp0';
  }

  @override
  String get totalGasto => 'Total gastado';

  @override
  String get ticketMedio => 'Ticket medio';

  @override
  String get numeroIdas => 'Visitas';

  @override
  String get mercado => 'Supermercado';

  @override
  String get mercadoOpcional => 'Supermercado (opcional)';

  @override
  String get porMercado => 'Por supermercado';

  @override
  String get maisBarato => 'más barato';

  @override
  String get gastoPorMercado => 'Gasto por supermercado';

  @override
  String get semMercado => 'Sin supermercado';

  @override
  String get mercadosSugeridos => 'Supermercados usados';

  @override
  String get estatisticas => 'Estadísticas';

  @override
  String get abaIdas => 'Visitas';

  @override
  String get gastoPorPeriodo => 'Gasto por período';

  @override
  String get gastoPorCategoria => 'Gasto por categoría';

  @override
  String get itensMaisComprados => 'Artículos más comprados';

  @override
  String get evolucaoDePreco => 'Evolución de precio';

  @override
  String get semDadosAinda => 'Aún no hay datos.';

  @override
  String totalNoPeriodo(String v) {
    return 'Total del período: $v';
  }

  @override
  String get porFrequencia => 'Frecuencia';

  @override
  String get porGasto => 'Gasto';

  @override
  String semanticaGastoMensal(String v) {
    return 'Gasto mensual: $v';
  }

  @override
  String semanticaEvolucaoPreco(String v) {
    return 'Evolución de precio: último $v';
  }

  @override
  String get boasVindasTitulo => 'Bienvenido(a)';

  @override
  String get boasVindasSubtitulo => 'Organiza tus compras en tu dispositivo.';

  @override
  String get boasVindasOffline => 'Funciona sin conexión';

  @override
  String get boasVindasOfflineDica => 'Tus listas se quedan en el dispositivo.';

  @override
  String get boasVindasBackup => 'Copia cuando quieras';

  @override
  String get boasVindasBackupDica =>
      'Exporta y restaura tus listas en un archivo.';

  @override
  String get boasVindasImportar => 'Importa por texto';

  @override
  String get boasVindasImportarDica =>
      'Pega una nota y la app organiza los artículos.';

  @override
  String get boasVindasDitar => 'Dicta un artículo';

  @override
  String get boasVindasDitarDica => 'Usa el micrófono para añadir hablando.';

  @override
  String get comecar => 'Empezar';

  @override
  String get tourPular => 'Saltar';

  @override
  String get tourAnterior => 'Anterior';

  @override
  String get tourProximo => 'Siguiente';

  @override
  String get tourConcluir => 'Finalizar';

  @override
  String tourPasso(int numero, int total) {
    return 'Paso $numero de $total';
  }

  @override
  String get tourAbrir => 'Ver tutorial';

  @override
  String get tourNovaListaTitulo => 'Crea tu primera lista';

  @override
  String get tourNovaListaCorpo =>
      'Toca \"Nueva lista\" para empezar. Puedes crear todas las que quieras.';

  @override
  String get tourNomeTitulo => 'Ponle un nombre';

  @override
  String get tourNomeCorpo =>
      'El nombre aparece arriba. Opcionalmente, define un presupuesto.';

  @override
  String get tourAdicionarTitulo => 'Añadir artículo';

  @override
  String get tourAdicionarCorpo =>
      'Escribe aquí. \"1kg de arroz\" se convierte en nombre, cantidad y unidad.';

  @override
  String get tourUnidadeTitulo => 'Unidad';

  @override
  String get tourUnidadeCorpo =>
      'Elige la medida (un, kg, paquete, pct, pt...). La app intenta adivinar.';

  @override
  String get tourImportarTitulo => 'Importa por texto';

  @override
  String get tourImportarCorpo =>
      'Pega una nota y la app organiza los artículos por ti.';

  @override
  String get tourBuscaTitulo => 'Búsqueda y filtros';

  @override
  String get tourBuscaCorpo =>
      'Encuentra artículos por nombre y filtra por categoría o unidad.';

  @override
  String get tourConfigTitulo => 'Ajustes';

  @override
  String get tourConfigCorpo =>
      'Tema, categorías, copia y dónde repasar este tutorial.';

  @override
  String get tourMarcarTitulo => 'Marcar, editar y quitar';

  @override
  String get tourMarcarCorpo =>
      'Toca el artículo para editar; marca el círculo; arrastra para quitar.';

  @override
  String get tourMercadoTitulo => 'Modo compra';

  @override
  String get tourMercadoCorpo =>
      'En el supermercado, marca las compras sin perder lo que falta.';

  @override
  String get tourOrcamentoTitulo => 'Presupuesto y total';

  @override
  String get tourOrcamentoCorpo =>
      'Define un tope y sigue el total del carrito.';

  @override
  String get tourResumoTitulo => 'Resumen de compras';

  @override
  String get tourResumoCorpo =>
      'Total gastado, ticket medio y cuántas idas ya finalizaste.';

  @override
  String get tourEstatisticasTitulo => 'Estadísticas';

  @override
  String get tourEstatisticasCorpo =>
      'Mira gráficos de gasto por mes y los artículos que más compras.';

  @override
  String politicaPrivacidadeTexto(String email) {
    return 'Política de Privacidad — Mis listas\n\n1. Datos que recopilamos\nLa aplicación funciona enteramente en tu dispositivo.\n• Tus listas y artículos se guardan solo en tu dispositivo.\n• No creamos cuentas, no pedimos correo ni contraseña y no enviamos tus datos a nuestros servidores.\n\n2. Voz\n• La función de añadir artículos por voz usa el reconocedor de voz de tu dispositivo. Según el sistema, el audio puede ser procesado por el servicio de reconocimiento del dispositivo (que puede usar internet). No grabamos ni guardamos el audio.\n\n3. Copia de seguridad\n• Puedes exportar un archivo de copia y reimportarlo. El archivo se crea en tu dispositivo y solo sale de él por una acción tuya (compartir/guardar).\n\n4. Con quién compartimos\nNo compartimos datos con terceros. No hay publicidad ni rastreo.\n\n5. Cuánto tiempo lo guardamos\nTus datos permanecen en el dispositivo hasta que los elimines en la propia aplicación (eliminando listas o la app).\n\n6. Tus derechos\nAccedes, corriges y borras todo directamente en la aplicación. La app no está dirigida a menores de 16 años.\n\n7. Contacto\nDudas sobre privacidad: $email.';
  }

  @override
  String get idiomaTitulo => 'Idioma';

  @override
  String get idiomaSistema => 'Sistema';

  @override
  String get idiomaPortugues => 'Portugués';

  @override
  String get idiomaIngles => 'Inglés';

  @override
  String get idiomaEspanhol => 'Español';
}
