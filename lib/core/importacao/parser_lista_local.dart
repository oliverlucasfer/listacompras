import '../../core/l10n/app_strings.dart';
import '../../features/listas/domain/quantidade.dart';
import '../../features/listas/domain/unidade.dart';
import '../texto/normalizar.dart';
import 'resposta_import.dart';

const Map<String, Unidade> _unidades = {
  'un': Unidade.un,
  'unidade': Unidade.un,
  'unidades': Unidade.un,
  'kg': Unidade.kg,
  'quilo': Unidade.kg,
  'quilos': Unidade.kg,
  'quilograma': Unidade.kg,
  'quilogramas': Unidade.kg,
  'g': Unidade.g,
  'grama': Unidade.g,
  'gramas': Unidade.g,
  'l': Unidade.l,
  'litro': Unidade.l,
  'litros': Unidade.l,
  'ml': Unidade.ml,
  'mililitro': Unidade.ml,
  'mililitros': Unidade.ml,
  'caixa': Unidade.caixa,
  'caixas': Unidade.caixa,
  'cx': Unidade.caixa,
  'pacote': Unidade.pacote,
  'pacotes': Unidade.pacote,
  'pct': Unidade.pct,
  'dz': Unidade.dz,
  'duzia': Unidade.dz,
  'duzias': Unidade.dz,
};

const _conectivos = {'de', 'do', 'da', 'em', 'dos', 'das'};

final _separadores = RegExp(r'[\n,;]+|\s+e\s+', caseSensitive: false);
const _qtd =
    r'(\d+(?:[.,]\d+)?|\d+\s*/\s*\d+|[' +
    glifosFracao +
    r']|\d+[' +
    glifosFracao +
    r'])';
final _soNumero = RegExp('^$_qtd\$');
final _numeroColado = RegExp('^$_qtd([a-zA-ZÀ-ÿ]+)\$');
final _soFracaoSo = RegExp(r'^(\d+\s*/\s*\d+|[½¼¾⅓⅔])$');
final _soInteiro = RegExp(r'^\d+$');
final _decimalComVirgula = RegExp(r'(\d),(\d)');

/// Vírgula **entre dígitos** é decimal (`1,5`), não separador de itens — o
/// texto é normalizado antes de segmentar (doc 04 §3, R-01).
String _protegerDecimais(String texto) =>
    texto.replaceAllMapped(_decimalComVirgula, (m) => '${m[1]}.${m[2]}');

/// Parser local determinístico (RF-16): extrai itens de texto livre, offline.
/// Devolve itens + `aviso` quando algum item entrou com quantidade padrão.
RespostaParse analisarListaLocal(String texto) {
  final itens = <ItemExtraido>[];
  var algumSemNumero = false;
  for (final parte in _protegerDecimais(texto).split(_separadores)) {
    final lido = _lerSegmento(parte);
    if (lido == null) continue;
    itens.add(lido.item);
    if (!_tinhaNumero(parte)) algumSemNumero = true;
  }
  return RespostaParse(
    itens: itens,
    aviso: algumSemNumero ? AppStrings.importLocalAvisoPadrao : null,
  );
}

/// Interpreta um item avulso digitado no campo "Adicionar item" (F12-T06):
/// quantidade/unidade **explícitas** no texto vencem; quando o texto não traz
/// unidade, usa [unidadePadrao] (a unidade escolhida no seletor da UI). Usa só
/// o primeiro segmento digitado.
ItemExtraido? interpretarItemAvulso(
  String texto, {
  Unidade unidadePadrao = Unidade.un,
}) {
  final partes = _protegerDecimais(texto).split(_separadores);
  final lido = _lerSegmento(partes.first);
  if (lido == null) return null;
  return lido.unidadeExplicita
      ? lido.item
      : ItemExtraido(
          nome: lido.item.nome,
          quantidade: lido.item.quantidade,
          unidade: unidadePadrao,
        );
}

bool _tinhaNumero(String parte) {
  final tokens = parte.trim().split(RegExp(r'\s+'));
  if (tokens.isEmpty) return false;
  final primeiro = _numeroDoToken(tokens.first);
  if (primeiro != null && primeiro > 0) return true;
  final ultimo = _numeroDoToken(tokens.last);
  return ultimo != null && ultimo > 0;
}

/// Quantidade bruta do texto: `≤ 0` é inválida e vira ausente (`1`) — o
/// chamador marca o aviso e o nome perde o número (doc 04 §3, R-02).
double _quantidadeValida(double bruta) => bruta > 0 ? bruta : 1.0;

double? _numeroDoToken(String token) {
  final colado = _numeroColado.firstMatch(token);
  if (colado != null) return parseQuantidade(colado.group(1)!);
  final numero = _soNumero.firstMatch(token);
  if (numero != null) return parseQuantidade(numero.group(1)!);
  return null;
}

/// Segmento lido + se a unidade veio **explícita** do texto (o `true`) ou é o
/// padrão `un` (`false`) — distinção usada no [interpretarItemAvulso].
typedef _Segmento = ({ItemExtraido item, bool unidadeExplicita});

_Segmento? _lerSegmento(String bruto) {
  final texto = bruto.trim().replaceAll(RegExp(r'[.]$'), '');
  if (texto.isEmpty) return null;
  final tokens = texto.split(RegExp(r'\s+'));

  final inicio = _qtdInicio(tokens);
  final fim = inicio == null ? _qtdFim(tokens) : null;

  late final double qtd;
  late final Unidade unidade;
  late final bool explicita;
  late final List<String> nome;
  if (inicio != null) {
    qtd = inicio.$1;
    unidade = inicio.$2;
    explicita = inicio.$4;
    var i = inicio.$3;
    if (i < tokens.length && _conectivos.contains(normalizarTexto(tokens[i]))) {
      i++;
    }
    nome = tokens.sublist(i);
  } else if (fim != null) {
    qtd = fim.$1;
    unidade = fim.$2;
    explicita = fim.$4;
    var j = fim.$3;
    if (j > 0 && _conectivos.contains(normalizarTexto(tokens[j - 1]))) j--;
    nome = tokens.sublist(0, j);
  } else {
    qtd = 1;
    unidade = Unidade.un;
    explicita = false;
    nome = tokens;
  }

  final limpo = nome.join(' ').trim();
  if (limpo.isEmpty) return null;
  return (
    item: ItemExtraido(
      nome: limpo[0].toUpperCase() + limpo.substring(1),
      quantidade: qtd,
      unidade: unidade,
    ),
    unidadeExplicita: explicita,
  );
}

(double, Unidade, int, bool)? _qtdInicio(List<String> t) {
  final colado = _numeroColado.firstMatch(t.first);
  if (colado != null) {
    final unidade = _unidades[normalizarTexto(colado.group(2)!)];
    if (unidade != null) {
      final q = parseQuantidade(colado.group(1)!)!;
      return (_quantidadeValida(q), unidade, 1, true);
    }
  }
  final numero = _soNumero.firstMatch(t.first);
  if (numero == null) return null;
  var qtd = parseQuantidade(numero.group(1)!)!;
  var consumidos = 1;
  if (t.length > 1 && _soFracaoSo.hasMatch(t[1])) {
    qtd += parseQuantidade(t[1])!;
    consumidos = 2;
  }
  if (t.length > consumidos) {
    final unidade = _unidades[normalizarTexto(t[consumidos])];
    if (unidade != null) {
      return (_quantidadeValida(qtd), unidade, consumidos + 1, true);
    }
  }
  return (_quantidadeValida(qtd), Unidade.un, consumidos, false);
}

(double, Unidade, int, bool)? _qtdFim(List<String> t) {
  final colado = _numeroColado.firstMatch(t.last);
  if (colado != null) {
    final unidade = _unidades[normalizarTexto(colado.group(2)!)];
    if (unidade != null) {
      final q = parseQuantidade(colado.group(1)!)!;
      return (_quantidadeValida(q), unidade, t.length - 1, true);
    }
  }
  final numero = _soNumero.firstMatch(t.last);
  if (numero == null) return null;
  var qtd = parseQuantidade(numero.group(1)!)!;
  var inicioNome = t.length - 1;
  if (t.length >= 2 &&
      _soInteiro.hasMatch(t[t.length - 2]) &&
      _soFracaoSo.hasMatch(t.last)) {
    qtd += parseQuantidade(t[t.length - 2])!;
    inicioNome = t.length - 2;
  }
  final idxUnidade = inicioNome - 1;
  if (idxUnidade >= 0) {
    final unidade = _unidades[normalizarTexto(t[idxUnidade])];
    if (unidade != null) {
      return (_quantidadeValida(qtd), unidade, idxUnidade, true);
    }
  }
  return (_quantidadeValida(qtd), Unidade.un, inicioNome, false);
}
