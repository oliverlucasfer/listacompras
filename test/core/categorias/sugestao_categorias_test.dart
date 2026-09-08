import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/categorias/sugestao_categorias.dart';
import 'package:lista_compras/features/listas/data/listas_repository.dart';
import 'package:lista_compras/features/listas/domain/categoria.dart';
import 'package:lista_compras/drift/database.dart';

/// F6-T03 (doc 14): cadeia de sugestão em camadas (spec §4) — memória por
/// nome → dicionário estático → `outros`. Zero rede (ADR-011).
void main() {
  late AppDatabase db;
  late ListasRepository repo;
  late SugestaoCategorias sugestao;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ListasRepository(db);
    sugestao = SugestaoCategorias(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('deve_sugerir_pelo_dicionario_quando_nome_comum', () async {
    expect(await sugestao.sugerirCategoria('Leite'), CategoriaItem.laticinios);
    expect(
      await sugestao.sugerirCategoria('Detergente'),
      CategoriaItem.limpeza,
    );
    expect(await sugestao.sugerirCategoria('arroz'), CategoriaItem.mercearia);
    expect(
      await sugestao.sugerirCategoria('pão francês'),
      CategoriaItem.padaria,
    );
  });

  test('deve_priorizar_memoria_quando_nome_ja_classificado', () async {
    // Dicionário diria laticinios; o usuário classificou "Leite" como pet
    // (ração de gato "leite"?). A memória do usuário vence (spec §4).
    final lista = await repo.criarLista(titulo: 'X', donoId: 'user-a');
    await repo.adicionarItem(
      listaId: lista.id,
      nome: 'Leite',
      categoria: CategoriaItem.pet,
    );

    expect(await sugestao.sugerirCategoria('leite'), CategoriaItem.pet);
  });

  test(
    'deve_dar_match_multi_palavra_antes_de_palavra_unica_quando_ambos_casam',
    () async {
      // "leite" → laticinios, mas "leite condensado" → mercearia (spec §4).
      expect(
        await sugestao.sugerirCategoria('leite condensado'),
        CategoriaItem.mercearia,
      );
    },
  );

  test('deve_cair_em_outros_quando_nome_desconhecido', () async {
    expect(
      await sugestao.sugerirCategoria('dispositivo stranges xyz'),
      CategoriaItem.outros,
    );
    expect(await sugestao.sugerirCategoria('   '), CategoriaItem.outros);
  });

  test('deve_ignorar_acentos_e_caixa_quando_comparar', () async {
    expect(
      await sugestao.sugerirCategoria('  CAFÉ  '),
      CategoriaItem.mercearia,
    );
    expect(
      await sugestao.sugerirCategoria('ÁGUA MINERAL'),
      CategoriaItem.bebidas,
    );
  });

  test('deve_lembrar_mesmo_com_variacao_de_acento_quando_memoria', () async {
    final lista = await repo.criarLista(titulo: 'X', donoId: 'user-a');
    await repo.adicionarItem(
      listaId: lista.id,
      nome: 'café',
      categoria: CategoriaItem.mercearia,
    );

    expect(await sugestao.sugerirCategoria('Cafe'), CategoriaItem.mercearia);
  });
}
