import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/categoria.dart';
import '../domain/ordem_categorias.dart';

const _chave = 'ordem_categorias';

/// Ordem pessoal das categorias (RF-24), local no dispositivo — espelha o
/// `temaModoProvider` (doc 15). Sem rede/Drift.
class OrdemCategoriasNotifier extends AsyncNotifier<List<CategoriaItem>> {
  @override
  Future<List<CategoriaItem>> build() async {
    final prefs = await SharedPreferences.getInstance();
    return desserializarOrdem(prefs.getString(_chave));
  }

  Future<void> definir(List<CategoriaItem> ordem) async {
    final normalizada = normalizarOrdem(ordem);
    state = AsyncData(normalizada);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_chave, serializarOrdem(normalizada));
  }

  Future<void> restaurarPadrao() async {
    state = AsyncData(List.of(CategoriaItem.values));
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_chave);
  }
}

final ordemCategoriasProvider =
    AsyncNotifierProvider<OrdemCategoriasNotifier, List<CategoriaItem>>(
      OrdemCategoriasNotifier.new,
    );
