import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/l10n/app_strings.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/auth/providers/auth_providers.dart';
import 'package:lista_compras/features/convites/data/papel_repository.dart';
import 'package:lista_compras/features/convites/domain/papel.dart';
import 'package:lista_compras/features/convites/providers/papel_providers.dart';
import 'package:lista_compras/features/listas/data/historico_precos_repository.dart';
import 'package:lista_compras/features/listas/data/listas_repository.dart';
import 'package:lista_compras/features/listas/domain/categoria.dart';
import 'package:lista_compras/features/listas/domain/unidade.dart';
import 'package:lista_compras/features/listas/providers/listas_providers.dart';
import 'package:lista_compras/features/listas/ui/tela_lista_screen.dart';
import 'package:lista_compras/features/sync/domain/sync_status.dart';
import 'package:lista_compras/features/sync/providers/sync_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/fakes.dart';
import '../convites/servidor_fake.dart';

/// Histórico de preços no editor do item (RF-29, F37).
void main() {
  setUpAll(inicializarSupabaseTeste);

  late AppDatabase db;
  final quando = DateTime.utc(2026, 9, 20, 12, 0);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({'onboarding_visto': true});
  });

  tearDown(() async {
    await db.close();
  });

  /// Data `dd/mm` esperada, derivada do mesmo `toLocal()` usado pela UI.
  String dataEsperada() {
    final local = quando.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}';
  }

  PapelRepository papelRepo({required String listaId, required Papel papel}) {
    final servidor = ServidorFake((req) => (200, const <Object>[]));
    addTearDown(servidor.close);
    final repo = PapelRepository(
      SupabaseClient(
        'http://127.0.0.1:54321',
        'test-key',
        httpClient: servidor,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      ),
    );
    repo.atualizar(listaId, papel);
    return repo;
  }

  Future<void> abrirLista(WidgetTester tester) async {
    final repo = ListasRepository(db);
    final lista = await repo.criarLista(
      titulo: 'Compras da Semana',
      donoId: 'user-a',
    );
    await repo.adicionarItem(
      listaId: lista.id,
      nome: 'Arroz',
      categoria: CategoriaItem.mercearia,
    );
    final sync = StreamController<SyncStatus>();
    sync.add(const Sincronizado());
    addTearDown(sync.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          papelRepositoryProvider.overrideWithValue(
            papelRepo(listaId: lista.id, papel: Papel.dono),
          ),
          donoAtualIdProvider.overrideWithValue(''),
          syncStatusProvider.overrideWith((ref) => sync.stream),
        ],
        child: MaterialApp(home: TelaListaScreen(listaId: lista.id)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> registrarHistorico({
    required String nome,
    required int precoCentavos,
    required Unidade unidade,
  }) async {
    await HistoricoPrecosRepository(db).registrar(
      nome: nome,
      precoCentavos: precoCentavos,
      unidade: unidade,
      quando: quando,
    );
  }

  Future<void> abrirEditor(WidgetTester tester) async {
    await tester.tap(find.text('Arroz'));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.editarItem), findsOneWidget);
  }

  Future<void> digitarPreco(WidgetTester tester, String texto) async {
    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.preco),
      texto,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('deve_nao_mostrar_historico_quando_item_sem_entrada', (
    tester,
  ) async {
    await abrirLista(tester);
    await abrirEditor(tester);

    expect(find.textContaining('Última compra'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('deve_mostrar_ultima_compra_quando_sem_preco_atual', (
    tester,
  ) async {
    await abrirLista(tester);
    await registrarHistorico(
      nome: 'Arroz',
      precoCentavos: 500,
      unidade: Unidade.un,
    );
    await abrirEditor(tester);

    expect(
      find.text(AppStrings.ultimaCompra('R\$ 5,00', dataEsperada())),
      findsOneWidget,
    );
    expect(find.text(AppStrings.mesmoPreco), findsNothing);
    expect(find.textContaining('↑'), findsNothing);
    expect(find.textContaining('↓'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('deve_mostrar_preco_subiu_quando_preco_digitado_maior', (
    tester,
  ) async {
    await abrirLista(tester);
    await registrarHistorico(
      nome: 'Arroz',
      precoCentavos: 500,
      unidade: Unidade.un,
    );
    await abrirEditor(tester);
    await digitarPreco(tester, '6,00');

    expect(
      find.text(AppStrings.ultimaCompra('R\$ 5,00', dataEsperada())),
      findsOneWidget,
    );
    expect(find.text(AppStrings.precoSubiu('R\$ 1,00')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('deve_mostrar_preco_baixou_quando_preco_digitado_menor', (
    tester,
  ) async {
    await abrirLista(tester);
    await registrarHistorico(
      nome: 'Arroz',
      precoCentavos: 500,
      unidade: Unidade.un,
    );
    await abrirEditor(tester);
    await digitarPreco(tester, '4,00');

    expect(find.text(AppStrings.precoBaixou('R\$ 1,00')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('deve_mostrar_mesmo_preco_quando_preco_digitado_igual', (
    tester,
  ) async {
    await abrirLista(tester);
    await registrarHistorico(
      nome: 'Arroz',
      precoCentavos: 500,
      unidade: Unidade.un,
    );
    await abrirEditor(tester);
    await digitarPreco(tester, '5,00');

    expect(find.text(AppStrings.mesmoPreco), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('deve_recalcular_variacao_quando_preco_muda', (tester) async {
    await abrirLista(tester);
    await registrarHistorico(
      nome: 'Arroz',
      precoCentavos: 500,
      unidade: Unidade.un,
    );
    await abrirEditor(tester);

    await digitarPreco(tester, '6,00');
    expect(find.text(AppStrings.precoSubiu('R\$ 1,00')), findsOneWidget);

    await digitarPreco(tester, '4,00');
    expect(find.text(AppStrings.precoSubiu('R\$ 1,00')), findsNothing);
    expect(find.text(AppStrings.precoBaixou('R\$ 1,00')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('deve_mostrar_apenas_ultimo_preco_quando_unidade_diferente', (
    tester,
  ) async {
    await abrirLista(tester);
    await registrarHistorico(
      nome: 'Arroz',
      precoCentavos: 500,
      unidade: Unidade.kg,
    );
    await abrirEditor(tester);
    await digitarPreco(tester, '6,00');

    expect(
      find.text(AppStrings.ultimaCompra('R\$ 5,00', dataEsperada())),
      findsOneWidget,
    );
    expect(find.text(AppStrings.mesmoPreco), findsNothing);
    expect(find.textContaining('↑'), findsNothing);
    expect(find.textContaining('↓'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('deve_reler_historico_quando_reabre_editor_apos_registro', (
    tester,
  ) async {
    await abrirLista(tester);
    // Primeira abertura: sem histórico (leitura é descartada ao fechar,
    // graças ao autoDispose do provider).
    await abrirEditor(tester);
    expect(find.textContaining('Última compra'), findsNothing);
    await tester.tap(find.widgetWithText(TextButton, AppStrings.cancelar));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.editarItem), findsNothing);

    // Registra o histórico (equivale a concluir a compra com preço).
    await registrarHistorico(
      nome: 'Arroz',
      precoCentavos: 500,
      unidade: Unidade.un,
    );

    // Reabrir deve re-ler o histórico novo.
    await abrirEditor(tester);
    expect(
      find.text(AppStrings.ultimaCompra('R\$ 5,00', dataEsperada())),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
