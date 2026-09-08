import '../../drift/database.dart';
import '../../features/listas/domain/categoria.dart';
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
    final chave = _normalizar(nome);
    if (chave.isEmpty) return CategoriaItem.outros;

    final candidatos = await (_db.select(
      _db.itemLocal,
    )..where((i) => i.deletadoEm.isNull())).get();
    final memoria =
        candidatos.where((i) => _normalizar(i.nome) == chave).toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    if (memoria.isNotEmpty) {
      return CategoriaItem.fromValor(memoria.first.categoria);
    }

    return categoriaPorDicionario(chave);
  }
}

/// Camada pura do dicionário: retorna a categoria da primeira entrada
/// cujas palavras todas aparecem no nome (ordem: mais palavras primeiro,
/// empate por ordem alfabética do termo); sem match → `outros`.
CategoriaItem categoriaPorDicionario(String nomeNormalizado) {
  final tokens = nomeNormalizado.split(RegExp(r'\s+')).toSet();
  if (tokens.isEmpty) return CategoriaItem.outros;

  final entradas = dicionarioCategorias.entries.toList()
    ..sort((a, b) {
      final pa = _normalizar(a.key).split(RegExp(r'\s+')).length;
      final pb = _normalizar(b.key).split(RegExp(r'\s+')).length;
      if (pa != pb) return pb - pa;
      return _normalizar(a.key).compareTo(_normalizar(b.key));
    });

  for (final entrada in entradas) {
    if (tokens.containsAll(_normalizar(entrada.key).split(RegExp(r'\s+')))) {
      return entrada.value;
    }
  }
  return CategoriaItem.outros;
}

/// minúsculas + sem acento (pt-BR) + espaços colapsados nas pontas.
String _normalizar(String texto) {
  const acentos = {
    'á': 'a',
    'à': 'a',
    'â': 'a',
    'ã': 'a',
    'ä': 'a',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'í': 'i',
    'ì': 'i',
    'î': 'i',
    'ï': 'i',
    'ó': 'o',
    'ò': 'o',
    'ô': 'o',
    'õ': 'o',
    'ö': 'o',
    'ú': 'u',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ç': 'c',
    'ñ': 'n',
  };
  final semAcento = texto
      .toLowerCase()
      .split('')
      .map((c) => acentos[c] ?? c)
      .join();
  return semAcento.trim().replaceAll(RegExp(r'\s+'), ' ');
}
