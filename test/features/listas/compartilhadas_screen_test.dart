import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lista_compras/core/l10n/app_strings.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/auth/providers/auth_providers.dart';
import 'package:lista_compras/features/convites/data/convites_repository.dart';
import 'package:lista_compras/features/convites/domain/convite.dart';
import 'package:lista_compras/features/convites/providers/convites_providers.dart';
import 'package:lista_compras/features/listas/data/listas_repository.dart';
import 'package:lista_compras/features/listas/providers/listas_providers.dart';
import 'package:lista_compras/features/listas/ui/compartilhadas_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/fakes.dart';

const _listaIdConvite = '11111111-1111-2222-3333-444444444444';
const _tokenConvite = 'aaaaaaaa-1111-2222-3333-bbbbbbbbbbbb';

class _ConvitesFakeLista extends ConvitesRepository {
  _ConvitesFakeLista() : super(Supabase.instance.client);

  bool aceitarChamado = false;
  String? tokenRecebido;
  String? retorno;
  ErroConvite? erro;
  Object? excecao;

  @override
  Future<String> aceitar(String token) async {
    aceitarChamado = true;
    tokenRecebido = token;
    final ex = excecao;
    if (ex != null) throw ex;
    final e = erro;
    if (e != null) throw e;
    return retorno!;
  }
}

void main() {
  setUpAll(inicializarSupabaseTeste);

  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> abrirTela(
    WidgetTester tester, {
    ConvitesRepository? convites,
  }) async {
    final router = GoRouter(
      initialLocation: '/compartilhadas',
      routes: [
        GoRoute(
          path: '/compartilhadas',
          builder: (_, _) => const CompartilhadasScreen(),
        ),
        GoRoute(
          path: '/lista/:id',
          builder: (_, state) =>
              Scaffold(body: Text('lista-${state.pathParameters['id']}')),
        ),
        GoRoute(
          path: '/membros/:id',
          builder: (_, state) =>
              Scaffold(body: Text('membros-${state.pathParameters['id']}')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          donoAtualIdProvider.overrideWithValue('user-b'),
          if (convites != null)
            convitesRepositoryProvider.overrideWithValue(convites),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> fechar(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('deve_exibir_estado_vazio_quando_nenhuma_compartilhada', (
    tester,
  ) async {
    await abrirTela(tester);
    expect(find.text(AppStrings.nenhumaCompartilhada), findsOneWidget);
    expect(find.text(AppStrings.conviteComCodigo), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    await fechar(tester);
  });

  testWidgets('deve_exibir_lista_de_outro_dono_quando_compartilhada', (
    tester,
  ) async {
    final repo = ListasRepository(db);
    await repo.criarLista(titulo: 'Do parceiro', donoId: 'user-a');
    await repo.criarLista(titulo: 'Minha', donoId: 'user-b');

    await abrirTela(tester);
    expect(find.text('Do parceiro'), findsOneWidget);
    expect(find.text('Minha'), findsNothing);
    await fechar(tester);
  });

  testWidgets('deve_abrir_membros_quando_long_press_em_compartilhada', (
    tester,
  ) async {
    final repo = ListasRepository(db);
    final lista = await repo.criarLista(
      titulo: 'Do parceiro',
      donoId: 'user-a',
    );

    await abrirTela(tester);
    await tester.longPress(find.text('Do parceiro'));
    await tester.pumpAndSettle();

    expect(find.text('membros-${lista.id}'), findsOneWidget);
    await fechar(tester);
  });

  testWidgets('deve_entrar_com_codigo_quando_colado', (tester) async {
    final convites = _ConvitesFakeLista()..retorno = _listaIdConvite;
    await abrirTela(tester, convites: convites);

    await tester.tap(find.byIcon(Icons.person_add).first);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.conviteCampoCodigo),
      _tokenConvite,
    );
    await tester.tap(
      find.widgetWithText(FilledButton, AppStrings.conviteConvidadoEntrar),
    );
    await tester.pumpAndSettle();

    expect(convites.aceitarChamado, isTrue);
    expect(convites.tokenRecebido, _tokenConvite);
    expect(find.text('lista-$_listaIdConvite'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    await fechar(tester);
  });

  testWidgets('deve_exibir_snackbar_quando_codigo_invalido', (tester) async {
    final convites = _ConvitesFakeLista()
      ..erro = const ErroConvite(
        'convite_invalido',
        AppStrings.conviteInvalido,
      );
    await abrirTela(tester, convites: convites);

    await tester.tap(find.byIcon(Icons.person_add).first);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.conviteCampoCodigo),
      'token-mau',
    );
    await tester.tap(
      find.widgetWithText(FilledButton, AppStrings.conviteConvidadoEntrar),
    );
    await tester.pumpAndSettle();

    expect(convites.aceitarChamado, isTrue);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text(AppStrings.conviteInvalido), findsOneWidget);
    expect(find.text('lista-$_listaIdConvite'), findsNothing);
    await fechar(tester);
  });
}
