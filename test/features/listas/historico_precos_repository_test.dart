import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/listas/data/historico_precos_repository.dart';
import 'package:lista_compras/features/listas/domain/unidade.dart';

void main() {
  late AppDatabase db;
  late HistoricoPrecosRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = HistoricoPrecosRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('deve_gravar_preco_normalizado_quando_registrar', () async {
    await repo.registrar(
      nome: '  Café em Pó  ',
      precoCentavos: 1850,
      unidade: Unidade.pacote,
    );

    final rows = await db.select(db.historicoPrecoLocal).get();
    expect(rows, hasLength(1));
    expect(rows.single.nomeNormalizado, 'cafe em po');
    expect(rows.single.precoCentavos, 1850);
    expect(rows.single.unidade, 'pacote');
  });

  test(
    'deve_atualizar_sem_duplicar_quando_registrar_mesmo_nome_normalizado',
    () async {
      await repo.registrar(
        nome: 'Café',
        precoCentavos: 1000,
        unidade: Unidade.un,
      );
      await repo.registrar(
        nome: 'CAFE',
        precoCentavos: 1200,
        unidade: Unidade.un,
      );

      final rows = await db.select(db.historicoPrecoLocal).get();
      expect(rows, hasLength(1));
      expect(rows.single.precoCentavos, 1200);
    },
  );

  test('deve_encontrar_quando_buscar_por_nome_normalizado', () async {
    await repo.registrar(
      nome: 'Arroz Tio João',
      precoCentavos: 2490,
      unidade: Unidade.kg,
    );

    final achado = await repo.porNome('  ARROZ TIO JOAO ');
    expect(achado, isNotNull);
    expect(achado!.precoCentavos, 2490);
    expect(achado.unidade, 'kg');
  });

  test('deve_retornar_nulo_quando_nome_sem_historico', () async {
    expect(await repo.porNome('Inexistente'), isNull);
  });

  test('deve_gravar_quando_passado_instante_explicito', () async {
    final quando = DateTime.utc(2026, 9, 20, 15, 30);
    await repo.registrar(
      nome: 'Leite',
      precoCentavos: 499,
      unidade: Unidade.l,
      quando: quando,
    );

    final achado = await repo.porNome('Leite');
    expect(achado!.registradoEm.toUtc(), quando);
  });
}
