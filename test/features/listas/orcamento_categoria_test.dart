import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/dominio/categoria.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/listas/data/orcamento_categoria_repository.dart';
import 'package:lista_compras/features/listas/domain/orcamento.dart';

/// Orçamento por categoria (RF-36, F53-T04): persistência local dos limites e
/// função pura de detecção das categorias estouradas.
void main() {
  late AppDatabase db;
  late LimitesCategoriaRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = LimitesCategoriaRepository(db);
  });

  tearDown(() async => db.close());

  test('deve_gravar_e_ler_limite_quando_definir', () async {
    await repo.definir(CategoriaItem.mercearia, centavos: 15000);

    expect(await repo.limites(), {CategoriaItem.mercearia: 15000});
  });

  test('deve_atualizar_limite_quando_definir_novamente', () async {
    await repo.definir(CategoriaItem.mercearia, centavos: 15000);
    await repo.definir(CategoriaItem.mercearia, centavos: 20000);

    expect(await repo.limites(), {CategoriaItem.mercearia: 20000});
  });

  test('deve_remover_limite_quando_centavos_nulo', () async {
    await repo.definir(CategoriaItem.mercearia, centavos: 15000);
    await repo.definir(CategoriaItem.mercearia, centavos: null);

    expect(await repo.limites(), isEmpty);
  });

  test('deve_emitir_limites_quando_observar', () async {
    await repo.definir(CategoriaItem.bebidas, centavos: 5000);

    expect(await repo.watchLimites().first, {CategoriaItem.bebidas: 5000});
  });

  test('deve_listar_categorias_estouradas_quando_subtotal_excede_limite', () {
    final acima = categoriasAcimaDoLimite(
      subtotais: {
        CategoriaItem.mercearia: 12000,
        CategoriaItem.bebidas: 3000,
        CategoriaItem.frios: 9000,
      },
      limites: {
        CategoriaItem.mercearia: 10000,
        CategoriaItem.bebidas: 3000,
        CategoriaItem.frios: 9000,
      },
    );

    expect(acima, {CategoriaItem.mercearia});
  });

  test('deve_ignorar_categoria_sem_subtotal_quando_com_limite', () {
    final acima = categoriasAcimaDoLimite(
      subtotais: const {},
      limites: {CategoriaItem.limpeza: 1},
    );

    expect(acima, isEmpty);
  });
}
