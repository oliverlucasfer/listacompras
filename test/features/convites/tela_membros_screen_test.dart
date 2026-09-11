import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lista_compras/core/l10n/app_strings.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/auth/providers/auth_providers.dart';
import 'package:lista_compras/features/convites/data/convites_repository.dart';
import 'package:lista_compras/features/convites/providers/convites_providers.dart';
import 'package:lista_compras/features/convites/data/papel_repository.dart';
import 'package:lista_compras/features/convites/providers/papel_providers.dart';
import 'package:lista_compras/features/convites/ui/tela_membros_screen.dart';
import 'package:lista_compras/features/sync/data/supabase_bootstrap.dart';
import 'package:lista_compras/features/sync/data/sync_engine.dart';
import 'package:lista_compras/features/sync/data/sync_remoto.dart';
import 'package:lista_compras/features/sync/data/mutacao_sync.dart';
import 'package:lista_compras/features/sync/providers/sync_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'servidor_fake.dart';

const _listaId = '11111111-1111-2222-3333-444444444444';

class _RemotoNenhum implements SyncRemoto {
  @override
  Future<ResultadoEnvio> enviar(MutacaoSync mutacao) async {
    return const Enviado();
  }
}

/// Espião do bootstrap (F7-T07): registra a chamada de limpeza local que
/// a tela deve fazer após sair da lista (belt-and-suspenders do Realtime).
class _BootstrapEspiao extends SupabaseBootstrap {
  _BootstrapEspiao(SupabaseClient cliente)
    : super(
        db: AppDatabase(NativeDatabase.memory()),
        engine: SyncEngine(
          db: AppDatabase(NativeDatabase.memory()),
          remoto: _RemotoNenhum(),
          checarConexao: () async => true,
        ),
        client: cliente,
      );

  bool chamouPerderAcesso = false;

  @override
  Future<void> perderAcessoLocal() async {
    chamouPerderAcesso = true;
  }
}

List<Map<String, Object?>> _linhasMembros() {
  return [
    {'lista_id': _listaId, 'user_id': 'U1', 'papel': 'dono'},
    {'lista_id': _listaId, 'user_id': 'U2', 'papel': 'editor'},
    {'lista_id': _listaId, 'user_id': 'U3', 'papel': 'leitor'},
  ];
}

void main() {
  Future<void> abrir(
    WidgetTester tester,
    ServidorFake servidor, {
    required String usuarioId,
  }) async {
    final cliente = SupabaseClient(
      'http://127.0.0.1:54321',
      'test-key',
      httpClient: servidor,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    final router = GoRouter(
      initialLocation: '/membros/$_listaId',
      routes: [
        GoRoute(
          path: '/membros/:listaId',
          builder: (_, state) =>
              TelaMembrosScreen(listaId: state.pathParameters['listaId']!),
        ),
        GoRoute(
          path: '/listas',
          builder: (_, _) => const Scaffold(body: Text('painel-listas')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          convitesRepositoryProvider.overrideWithValue(
            ConvitesRepository(cliente),
          ),
          donoAtualIdProvider.overrideWithValue(usuarioId),
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

  testWidgets('deve_listar_membros_com_papeis', (tester) async {
    final servidor = ServidorFake((req) {
      if (req.method == 'GET' && req.url.path.contains('/lista_membros')) {
        return (200, _linhasMembros());
      }
      return (500, {'message': 'requisição inesperada: ${req.url.path}'});
    });
    addTearDown(servidor.close);
    await abrir(tester, servidor, usuarioId: 'U1');

    expect(find.text(AppStrings.membros), findsOneWidget);
    expect(find.text(AppStrings.voce), findsOneWidget);
    expect(find.text('U2'), findsOneWidget);
    expect(find.text('U3'), findsOneWidget);
    expect(find.text(AppStrings.papelDono), findsOneWidget);
    expect(find.text(AppStrings.convidarPapelEditor), findsOneWidget);
    expect(find.text(AppStrings.convidarPapelLeitor), findsOneWidget);

    // Ordem dono → editor → leitor (dono primeiro).
    final dyVoce = tester.getTopLeft(find.text(AppStrings.voce)).dy;
    final dyU2 = tester.getTopLeft(find.text('U2')).dy;
    final dyU3 = tester.getTopLeft(find.text('U3')).dy;
    expect(dyVoce, lessThan(dyU2));
    expect(dyU2, lessThan(dyU3));

    // Dono vê menu de ações nos outros membros, não no próprio:
    expect(find.byType(PopupMenuButton<String>), findsNWidgets(2));
    // Dono não vê "Sair da lista".
    expect(
      find.widgetWithText(TextButton, AppStrings.sairDaLista),
      findsNothing,
    );

    await fechar(tester);
  });

  testWidgets('deve_remover_membro_apos_confirmacao', (tester) async {
    final removido = <String>[];
    final servidor = ServidorFake((req) {
      final caminho = req.url.path;
      if (req.method == 'GET' && caminho.contains('/lista_membros')) {
        // Depois do DELETE, recarrega sem o membro removido.
        if (removido.isEmpty) return (200, _linhasMembros());
        return (
          200,
          [
            {'lista_id': _listaId, 'user_id': 'U1', 'papel': 'dono'},
            {'lista_id': _listaId, 'user_id': 'U3', 'papel': 'leitor'},
          ],
        );
      }
      if (req.method == 'DELETE' && caminho.contains('/lista_membros')) {
        removido.add(req.url.queryParameters['user_id'] ?? '');
        return (200, []);
      }
      return (500, {'message': 'requisição inesperada: $caminho'});
    });
    addTearDown(servidor.close);
    await abrir(tester, servidor, usuarioId: 'U1');

    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.removerMembro));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.removerMembroMensagem), findsOneWidget);
    await tester.tap(
      find.widgetWithText(FilledButton, AppStrings.removerMembro),
    );
    await tester.pumpAndSettle();

    final filtro = servidor.pedidos
        .firstWhere(
          (p) => p.method == 'DELETE' && p.url.path.contains('/lista_membros'),
        )
        .url
        .queryParameters;
    expect(filtro, containsPair('lista_id', 'eq.$_listaId'));
    expect(filtro, containsPair('user_id', 'eq.U2'));
    expect(find.text('U2'), findsNothing);

    await fechar(tester);
  });

  testWidgets('deve_mudar_papel_quando_dono_escolhe', (tester) async {
    final servidor = ServidorFake((req) {
      final caminho = req.url.path;
      if (req.method == 'GET' && caminho.contains('/lista_membros')) {
        return (200, _linhasMembros());
      }
      if (req.method == 'PATCH' && caminho.contains('/lista_membros')) {
        return (200, []);
      }
      return (500, {'message': 'requisição inesperada: $caminho'});
    });
    addTearDown(servidor.close);
    await abrir(tester, servidor, usuarioId: 'U1');

    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    // "Leitor" também aparece na linha do próprio dono (chip) — o item do
    // menu é o último na árvore.
    await tester.tap(find.text(AppStrings.convidarPapelLeitor).last);
    await tester.pumpAndSettle();

    final pedido = servidor.pedidos.firstWhere((p) => p.method == 'PATCH');
    expect(pedido.url.queryParameters, containsPair('user_id', 'eq.U2'));
    final indice = servidor.pedidos.indexWhere((p) => p.method == 'PATCH');
    final corpo = jsonDecode(servidor.corpoDe(indice)) as Map<String, Object?>;
    expect(corpo['papel'], 'leitor');

    await fechar(tester);
  });

  testWidgets('deve_sair_da_lista_quando_seleciona_e_confirma', (tester) async {
    String parte(Map<String, Object?> dados) {
      final codificado = base64Url.encode(utf8.encode(jsonEncode(dados)));
      return codificado.replaceAll('=', '');
    }

    final cabecalho = parte({'alg': 'HS256', 'typ': 'JWT'});
    final carga = parte({
      'sub': 'U2',
      'exp': 9999999999,
      'iat': 0,
      'role': 'authenticated',
    });
    final jwt = '$cabecalho.$carga.c2ln';
    final servidor = ServidorFake((req) {
      final caminho = req.url.path;
      if (req.method == 'DELETE' && caminho.contains('/lista_membros')) {
        return (200, []);
      }
      if (req.method == 'GET' && caminho.contains('/auth/v1/user')) {
        return (
          200,
          {
            'id': 'U2',
            'aud': 'authenticated',
            'email': 'u2@teste.com',
            'created_at': '2026-01-01T00:00:00.000Z',
          },
        );
      }
      if (req.method == 'GET' && caminho.contains('/lista_membros')) {
        return (200, _linhasMembros());
      }
      return (500, {'message': 'requisição inesperada: $caminho'});
    });
    addTearDown(servidor.close);
    final cliente = SupabaseClient(
      'http://127.0.0.1:54321',
      'test-key',
      httpClient: servidor,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    await cliente.auth.setSession('refresh-token-teste', accessToken: jwt);
    final espiao = _BootstrapEspiao(cliente);
    final router = GoRouter(
      initialLocation: '/membros/$_listaId',
      routes: [
        GoRoute(
          path: '/membros/:listaId',
          builder: (_, state) =>
              TelaMembrosScreen(listaId: state.pathParameters['listaId']!),
        ),
        GoRoute(
          path: '/listas',
          builder: (_, _) => const Scaffold(body: Text('painel-listas')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          convitesRepositoryProvider.overrideWithValue(
            ConvitesRepository(cliente),
          ),
          papelRepositoryProvider.overrideWithValue(PapelRepository(cliente)),
          donoAtualIdProvider.overrideWithValue('U2'),
          syncBootstrapProvider.overrideWithValue(espiao),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    final sair = find.widgetWithText(TextButton, AppStrings.sairDaLista);
    expect(sair, findsOneWidget);
    expect(find.byType(PopupMenuButton<String>), findsNothing);
    await tester.tap(sair);
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text(AppStrings.sairListaMensagem), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, AppStrings.sairDaLista));
    await tester.pumpAndSettle();

    final filtro = servidor.pedidos
        .firstWhere(
          (p) => p.method == 'DELETE' && p.url.path.contains('/lista_membros'),
        )
        .url
        .queryParameters;
    expect(filtro, containsPair('lista_id', 'eq.$_listaId'));
    expect(filtro, containsPair('user_id', 'eq.U2'));
    expect(find.text('painel-listas'), findsOneWidget);
    // Belt-and-suspenders (F7-T07): a tela força a limpeza local após sair.
    expect(espiao.chamouPerderAcesso, isTrue);

    await fechar(tester);
  });

  testWidgets('deve_ocultar_botao_sair_enquanto_isLoading_e_quando_dono', (
    tester,
  ) async {
    final servidor = ServidorFake((req) {
      if (req.method == 'GET' && req.url.path.contains('/lista_membros')) {
        return (200, _linhasMembros());
      }
      return (500, {'message': 'requisição inesperada: ${req.url.path}'});
    });
    addTearDown(servidor.close);
    final cliente = SupabaseClient(
      'http://127.0.0.1:54321',
      'test-key',
      httpClient: servidor,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    final router = GoRouter(
      initialLocation: '/membros/$_listaId',
      routes: [
        GoRoute(
          path: '/membros/:listaId',
          builder: (_, state) =>
              TelaMembrosScreen(listaId: state.pathParameters['listaId']!),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          convitesRepositoryProvider.overrideWithValue(
            ConvitesRepository(cliente),
          ),
          donoAtualIdProvider.overrideWithValue('U1'),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    // Durante isLoading (papel desconhecado): "Sair da lista" não aparece.
    expect(
      find.widgetWithText(TextButton, AppStrings.sairDaLista),
      findsNothing,
    );

    await tester.pumpAndSettle();

    // Dono com dados carregados: continua sem o botão.
    expect(find.text(AppStrings.voce), findsOneWidget);
    expect(
      find.widgetWithText(TextButton, AppStrings.sairDaLista),
      findsNothing,
    );

    await fechar(tester);
  });

  testWidgets('deve_ocultar_acoes_dono_quando_nao_e_dono', (tester) async {
    final servidor = ServidorFake((req) {
      if (req.method == 'GET' && req.url.path.contains('/lista_membros')) {
        return (200, _linhasMembros());
      }
      return (500, {'message': 'requisição inesperada: ${req.url.path}'});
    });
    addTearDown(servidor.close);
    await abrir(tester, servidor, usuarioId: 'U3');

    expect(find.byType(PopupMenuButton<String>), findsNothing);
    expect(find.text(AppStrings.voce), findsOneWidget);
    expect(
      find.widgetWithText(TextButton, AppStrings.sairDaLista),
      findsOneWidget,
    );

    await fechar(tester);
  });
}
