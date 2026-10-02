import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/dominio/categoria.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/listas/data/listas_repository.dart';
import 'package:lista_compras/features/listas/data/orcamento_categoria_repository.dart';
import 'package:lista_compras/features/listas/providers/listas_providers.dart';
import 'package:lista_compras/features/listas/ui/tela_lista_screen.dart';
import 'package:lista_compras/features/listas/ui/tela_orcamento_categorias.dart';

import '../../support/app_teste.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Orçamento por categoria na UI (RF-36, F53-T04): tela de limites e banner
/// de categoria estourada na tela da lista.
void main() {
  late AppDatabase db;
  late ListasRepository listasRepo;
  late LimitesCategoriaRepository limitesRepo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    listasRepo = ListasRepository(db);
    limitesRepo = LimitesCategoriaRepository(db);
    SharedPreferences.setMockInitialValues({'onboarding_visto': true});
  });

  tearDown(() async => db.close());

  Future<void> fechar(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  Future<void> abrirTelaLimites(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: appTeste(const TelaOrcamentoCategorias()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder linha(CategoriaItem categoria) =>
      find.byKey(ValueKey(categoria.valor));

  testWidgets('deve_mostrar_erro_inline_quando_limite_invalido', (
    tester,
  ) async {
    await abrirTelaLimites(tester);

    final mercearia = linha(CategoriaItem.mercearia);
    await tester.enterText(
      find.descendant(of: mercearia, matching: find.byType(TextField)),
      'abc',
    );
    await tester.tap(
      find.descendant(
        of: mercearia,
        matching: find.widgetWithText(FilledButton, 'Salvar'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Valor de orçamento inválido.'), findsOneWidget);
    expect(await limitesRepo.limites(), isEmpty);

    await fechar(tester);
  });

  testWidgets('deve_persistir_limite_quando_salvar_valor_valido', (
    tester,
  ) async {
    await abrirTelaLimites(tester);

    final mercearia = linha(CategoriaItem.mercearia);
    await tester.enterText(
      find.descendant(of: mercearia, matching: find.byType(TextField)),
      '150,00',
    );
    await tester.tap(
      find.descendant(
        of: mercearia,
        matching: find.widgetWithText(FilledButton, 'Salvar'),
      ),
    );
    await tester.pumpAndSettle();

    expect(await limitesRepo.limites(), {CategoriaItem.mercearia: 15000});
    expect(find.text('Limites por categoria salvos.'), findsOneWidget);

    await fechar(tester);
  });

  testWidgets('deve_remover_limite_quando_tocar_limpar', (tester) async {
    await limitesRepo.definir(CategoriaItem.mercearia, centavos: 15000);
    await abrirTelaLimites(tester);

    final mercearia = linha(CategoriaItem.mercearia);
    await tester.tap(
      find.descendant(
        of: mercearia,
        matching: find.widgetWithText(TextButton, 'Limpar'),
      ),
    );
    await tester.pumpAndSettle();

    expect(await limitesRepo.limites(), isEmpty);

    await fechar(tester);
  });

  Future<void> abrirListaComItemMarcado(WidgetTester tester) async {
    final lista = await listasRepo.criarLista(
      titulo: 'Compras',
      donoId: 'local',
    );
    final item = await listasRepo.adicionarItem(
      listaId: lista.id,
      nome: 'Arroz',
      categoria: CategoriaItem.mercearia,
      precoCentavos: 12000,
    );
    await listasRepo.editarItem(item.id, concluido: true);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: appTeste(TelaListaScreen(listaId: lista.id)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('deve_mostrar_banner_quando_categoria_excede_limite', (
    tester,
  ) async {
    await limitesRepo.definir(CategoriaItem.mercearia, centavos: 10000);
    await abrirListaComItemMarcado(tester);

    expect(find.textContaining('Acima do limite da categoria'), findsOneWidget);

    await fechar(tester);
  });

  testWidgets('deve_remover_banner_quando_limite_limpo', (tester) async {
    await limitesRepo.definir(CategoriaItem.mercearia, centavos: 10000);
    await abrirListaComItemMarcado(tester);
    expect(find.textContaining('Acima do limite da categoria'), findsOneWidget);

    await limitesRepo.definir(CategoriaItem.mercearia, centavos: null);
    await tester.pumpAndSettle();

    expect(find.textContaining('Acima do limite da categoria'), findsNothing);

    await fechar(tester);
  });
}
