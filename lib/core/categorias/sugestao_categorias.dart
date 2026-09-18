import '../../drift/database.dart';
import '../../features/listas/domain/categoria.dart';
import '../texto/normalizar.dart';
import 'dicionario_categorias.dart';

/// Cadeia de sugestão de categoria em camadas (spec F6 §4, ADR-011):
/// memória por nome (itens ativos do usuário no dispositivo) → dicionário
/// estático local → `outros`. Zero rede — o app categoriza 100% offline,
/// sem depender de plano de IA.
class SugestaoCategorias {
  SugestaoCategorias(this._db);

  final AppDatabase _db;

  /// 1. Memória: categoria do item ativo mais recente com o mesmo nome
  /// (qualquer lista, comparação sem acento/caixa), por `updated_at` DESC.
  /// 2. Dicionário: multi-palavra casa antes de palavra única.
  /// 3. Fallback: `outros`.
  Future<CategoriaItem> sugerirCategoria(String nome) async {
    final chave = normalizarTexto(nome);
    if (chave.isEmpty) return CategoriaItem.outros;

    final candidatos = await (_db.select(
      _db.itemLocal,
    )..where((i) => i.deletadoEm.isNull())).get();
    final memoria =
        candidatos.where((i) => normalizarTexto(i.nome) == chave).toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    if (memoria.isNotEmpty) {
      return CategoriaItem.fromValor(memoria.first.categoria);
    }

    return categoriaPorDicionario(chave);
  }
}

/// Camada pura do dicionário (R-08): entre as entradas cujas palavras todas
/// aparecem no nome, vence na ordem:
/// 1. **mais palavras no termo** — o termo mais específico manda ("leite
///    condensado" → mercearia vence "leite" → laticínios);
/// 2. **termo que aparece primeiro no nome** — o núcleo costuma vir antes do
///    qualificador ("suco de laranja": "suco" (pos. 0) vence "laranja" (pos. 2));
/// 3. **mais palavras do termo casadas com o nome** (empate de posição);
/// 4. **alfabética** (desempate estável);
/// sem match → `outros`.
CategoriaItem categoriaPorDicionario(String nomeNormalizado) {
  final palavrasDoNome = nomeNormalizado.split(RegExp(r'\s+'));
  if (palavrasDoNome.isEmpty) return CategoriaItem.outros;

  final frases = <(String, CategoriaItem, int, int, int)>[];
  for (final entrada in dicionarioCategorias.entries) {
    final termo = normalizarTexto(entrada.key);
    final palavrasDoTermo = termo.split(RegExp(r'\s+'));
    final posicao = _posicaoNoNome(palavrasDoNome, palavrasDoTermo);
    if (posicao == null) continue;
    frases.add((
      termo,
      entrada.value,
      palavrasDoTermo.length,
      posicao,
      termo.length,
    ));
  }
  if (frases.isEmpty) return CategoriaItem.outros;

  frases.sort((a, b) {
    if (a.$3 != b.$3) return b.$3 - a.$3;
    if (a.$4 != b.$4) return a.$4 - b.$4;
    if (a.$5 != b.$5) return b.$5 - a.$5;
    return a.$1.compareTo(b.$1);
  });
  return frases.first.$2;
}

/// Posição (0-based) das palavras do termo **em sequência** dentro do nome,
/// ou `null` quando alguma não aparece. Ex.: termo `"suco"` em
/// `"suco de laranja"` → 0; `"laranja"` → 2; `"banana"` → `null`.
int? _posicaoNoNome(List<String> palavrasDoNome, List<String> palavrasDoTermo) {
  for (
    var inicio = 0;
    inicio + palavrasDoTermo.length <= palavrasDoNome.length;
    inicio++
  ) {
    var casa = true;
    for (var i = 0; i < palavrasDoTermo.length; i++) {
      if (palavrasDoNome[inicio + i] != palavrasDoTermo[i]) {
        casa = false;
        break;
      }
    }
    if (casa) return inicio;
  }
  return null;
}
