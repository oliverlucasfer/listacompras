import '../../core/l10n/app_strings.dart';
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
  'pct': Unidade.pacote,
  'dz': Unidade.dz,
  'duzia': Unidade.dz,
  'duzias': Unidade.dz,
};

const _conectivos = {'de', 'do', 'da', 'em', 'dos', 'das'};

final _separadores = RegExp(r'[\n,;]+|\s+e\s+', caseSensitive: false);
final _soNumero = RegExp(r'^(\d+(?:[.,]\d+)?)$');
final _numeroColado = RegExp(r'^(\d+(?:[.,]\d+)?)([a-zA-ZÀ-ÿ]+)$');

/// Parser local determinístico (RF-16): extrai itens de texto livre, offline.
/// Devolve itens + `aviso` quando algum item entrou com quantidade padrão.
RespostaParse analisarListaLocal(String texto) {
  final itens = <ItemExtraido>[];
  var algumSemNumero = false;
  for (final parte in texto.split(_separadores)) {
    final item = _parseSegmento(parte);
    if (item == null) continue;
    itens.add(item);
    if (!_tinhaNumero(parte)) algumSemNumero = true;
  }
  return RespostaParse(
    itens: itens,
    aviso: algumSemNumero ? AppStrings.importLocalAvisoPadrao : null,
  );
}

bool _tinhaNumero(String parte) {
  final tokens = parte.trim().split(RegExp(r'\s+'));
  if (tokens.isEmpty) return false;
  return _soNumero.hasMatch(tokens.first) ||
      _numeroColado.hasMatch(tokens.first) ||
      _soNumero.hasMatch(tokens.last) ||
      _numeroColado.hasMatch(tokens.last);
}

ItemExtraido? _parseSegmento(String bruto) {
  final texto = bruto.trim().replaceAll(RegExp(r'[.]$'), '');
  if (texto.isEmpty) return null;
  final tokens = texto.split(RegExp(r'\s+'));

  final inicio = _qtdInicio(tokens);
  final fim = inicio == null ? _qtdFim(tokens) : null;

  late final double qtd;
  late final Unidade unidade;
  late final List<String> nome;
  if (inicio != null) {
    qtd = inicio.$1;
    unidade = inicio.$2;
    var i = inicio.$3;
    if (i < tokens.length && _conectivos.contains(normalizarTexto(tokens[i]))) {
      i++;
    }
    nome = tokens.sublist(i);
  } else if (fim != null) {
    qtd = fim.$1;
    unidade = fim.$2;
    var j = fim.$3;
    if (j > 0 && _conectivos.contains(normalizarTexto(tokens[j - 1]))) j--;
    nome = tokens.sublist(0, j);
  } else {
    qtd = 1;
    unidade = Unidade.un;
    nome = tokens;
  }

  final limpo = nome.join(' ').trim();
  if (limpo.isEmpty) return null;
  return ItemExtraido(
    nome: limpo[0].toUpperCase() + limpo.substring(1),
    quantidade: qtd,
    unidade: unidade,
  );
}

(double, Unidade, int)? _qtdInicio(List<String> t) {
  final colado = _numeroColado.firstMatch(t.first);
  if (colado != null) {
    final unidade = _unidades[normalizarTexto(colado.group(2)!)];
    if (unidade != null) return (_paraDouble(colado.group(1)!), unidade, 1);
  }
  final numero = _soNumero.firstMatch(t.first);
  if (numero == null) return null;
  final qtd = _paraDouble(numero.group(1)!);
  if (t.length > 1) {
    final unidade = _unidades[normalizarTexto(t[1])];
    if (unidade != null) return (qtd, unidade, 2);
  }
  return (qtd, Unidade.un, 1);
}

(double, Unidade, int)? _qtdFim(List<String> t) {
  final colado = _numeroColado.firstMatch(t.last);
  if (colado != null) {
    final unidade = _unidades[normalizarTexto(colado.group(2)!)];
    if (unidade != null) {
      return (_paraDouble(colado.group(1)!), unidade, t.length - 1);
    }
  }
  final numero = _soNumero.firstMatch(t.last);
  if (numero == null) return null;
  final qtd = _paraDouble(numero.group(1)!);
  if (t.length > 1) {
    final unidade = _unidades[normalizarTexto(t[t.length - 2])];
    if (unidade != null) return (qtd, unidade, t.length - 2);
  }
  return (qtd, Unidade.un, t.length - 1);
}

double _paraDouble(String valor) => double.parse(valor.replaceAll(',', '.'));
