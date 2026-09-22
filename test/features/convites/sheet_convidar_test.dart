import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/l10n/app_strings.dart';
import 'package:lista_compras/features/convites/data/convites_repository.dart';
import 'package:lista_compras/features/convites/providers/convites_providers.dart';
import 'package:lista_compras/features/convites/ui/sheet_convidar.dart';
import 'package:lista_compras/features/sync/providers/sync_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'servidor_fake.dart';

const _listaId = '11111111-1111-2222-3333-444444444444';
const _token = 'aaaaaaaa-1111-2222-3333-bbbbbbbbbbbb';
final _link = 'br.com.oliverlucas.listacompras://entrar?token=$_token';

Map<String, Object?> _linhaConvite({
  required String papel,
  String tipo = 'link',
  String? email,
}) {
  return {
    'id': _token,
    'lista_id': _listaId,
    'criado_por': 'U1',
    'token': _token,
    'tipo': tipo,
    'email': email,
    'papel_oferecido': papel,
    'estado': 'pendente',
    'expira_em': '2026-09-17T12:00:00.000Z',
    'created_at': '2026-09-10T12:00:00.000Z',
    'atualizado_em': '2026-09-10T12:00:00.000Z',
  };
}

class _TelaAbrirSheet extends ConsumerWidget {
  const _TelaAbrirSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () => abrirSheetConvidar(context, ref, _listaId),
          child: const Text('abrir'),
        ),
      ),
    );
  }
}

Future<void> abrir(
  WidgetTester tester,
  ServidorFake servidor, {
  Future<void> Function()? sincronizar,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        convitesRepositoryProvider.overrideWithValue(
          ConvitesRepository(
            SupabaseClient(
              'http://127.0.0.1:54321',
              'test-key',
              httpClient: servidor,
              authOptions: const AuthClientOptions(autoRefreshToken: false),
            ),
          ),
        ),
        sincronizarAntesDeOperacaoProvider.overrideWithValue(
          sincronizar ?? () async {},
        ),
      ],
      child: const MaterialApp(home: _TelaAbrirSheet()),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

Future<void> fechar(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
}

void main() {
  testWidgets('deve_gerar_link_quando_escolhe_papel_e_confirma', (
    tester,
  ) async {
    final servidor = ServidorFake((req) {
      if (req.method == 'POST' && req.url.path.contains('/convites')) {
        return (200, _linhaConvite(papel: 'leitor'));
      }
      return (500, {'message': 'requisição inesperada: ${req.url.path}'});
    });
    addTearDown(servidor.close);
    await abrir(tester, servidor);

    await tester.tap(find.text(AppStrings.convidarPapelLeitor));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, AppStrings.gerarLink));
    await tester.pumpAndSettle();

    expect(find.text(_link), findsOneWidget);
    expect(
      find.widgetWithText(OutlinedButton, AppStrings.copiarLink),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(OutlinedButton, AppStrings.compartilhar),
      findsOneWidget,
    );
    expect(find.byTooltip(AppStrings.copiarLinkAjuda), findsOneWidget);
    expect(find.byTooltip(AppStrings.copiarCodigoAjuda), findsOneWidget);
    expect(find.text(AppStrings.gerarLink), findsNothing);

    final corpo =
        jsonDecode(
              servidor.corpoDe(
                servidor.pedidos.indexWhere((p) => p.method == 'POST'),
              ),
            )
            as Map<String, Object?>;
    expect(corpo['papel_oferecido'], 'leitor');
    expect(corpo['tipo'], 'link');
    expect(corpo['lista_id'], _listaId);

    await fechar(tester);
  });

  testWidgets('deve_mostrar_erro_quando_criar_link_falha', (tester) async {
    final servidor = ServidorFake((req) {
      if (req.method == 'POST' && req.url.path.contains('/convites')) {
        return (
          403,
          {
            'code': '42501',
            'message': 'sem permissão',
            'details': null,
            'hint': null,
          },
        );
      }
      return (500, {'message': 'requisição inesperada: ${req.url.path}'});
    });
    addTearDown(servidor.close);
    await abrir(tester, servidor);

    await tester.tap(find.widgetWithText(FilledButton, AppStrings.gerarLink));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.conviteListaNaoSincronizada), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, AppStrings.gerarLink),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate((w) => w is TextField && w.readOnly),
      findsNothing,
    );

    await fechar(tester);
  });

  testWidgets('deve_sincronizar_antes_de_gerar_link', (tester) async {
    // F12-T02: pré-condição — a fila é drenada antes de criar o convite.
    var sincronizou = false;
    final servidor = ServidorFake((req) {
      if (req.method == 'POST' && req.url.path.contains('/convites')) {
        return (200, _linhaConvite(papel: 'editor'));
      }
      return (500, {'message': 'requisição inesperada: ${req.url.path}'});
    });
    addTearDown(servidor.close);
    await abrir(tester, servidor, sincronizar: () async => sincronizou = true);

    await tester.tap(find.widgetWithText(FilledButton, AppStrings.gerarLink));
    await tester.pumpAndSettle();

    expect(sincronizou, isTrue);
    expect(find.text(_link), findsOneWidget);

    await fechar(tester);
  });

  testWidgets('deve_copiar_link_quando_tocar_copiar', (tester) async {
    String? copiado;
    final canal = SystemChannels.platform;
    tester.binding.defaultBinaryMessenger.setMockMessageHandler(canal.name, (
      data,
    ) async {
      final conteudo = const JSONMessageCodec().decodeMessage(data);
      if (conteudo is Map && conteudo['method'] == 'Clipboard.setData') {
        copiado = conteudo['args']['text'] as String?;
      }
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMessageHandler(
        canal.name,
        null,
      ),
    );

    final servidor = ServidorFake((req) {
      if (req.method == 'POST' && req.url.path.contains('/convites')) {
        return (200, _linhaConvite(papel: 'editor'));
      }
      return (500, {'message': 'requisição inesperada: ${req.url.path}'});
    });
    addTearDown(servidor.close);
    await abrir(tester, servidor);

    await tester.tap(find.widgetWithText(FilledButton, AppStrings.gerarLink));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(OutlinedButton, AppStrings.copiarLink),
    );
    await tester.pumpAndSettle();

    expect(copiado, _link);
    expect(find.text(AppStrings.linkCopiado), findsOneWidget);

    await fechar(tester);
  });

  testWidgets('deve_copiar_codigo_quando_tocar_copiar_codigo', (tester) async {
    String? copiado;
    final canal = SystemChannels.platform;
    tester.binding.defaultBinaryMessenger.setMockMessageHandler(canal.name, (
      data,
    ) async {
      final conteudo = const JSONMessageCodec().decodeMessage(data);
      if (conteudo is Map && conteudo['method'] == 'Clipboard.setData') {
        copiado = conteudo['args']['text'] as String?;
      }
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMessageHandler(
        canal.name,
        null,
      ),
    );

    final servidor = ServidorFake((req) {
      if (req.method == 'POST' && req.url.path.contains('/convites')) {
        return (200, _linhaConvite(papel: 'editor'));
      }
      return (500, {'message': 'requisição inesperada: ${req.url.path}'});
    });
    addTearDown(servidor.close);
    await abrir(tester, servidor);

    await tester.tap(find.widgetWithText(FilledButton, AppStrings.gerarLink));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(OutlinedButton, AppStrings.copiarCodigo),
    );
    await tester.pumpAndSettle();

    // Código cru, sem scheme da deep link.
    expect(copiado, _token);
    expect(find.text(AppStrings.codigoCopiado), findsOneWidget);

    await fechar(tester);
  });

  testWidgets('deve_mostrar_snackbar_ao_compartilhar_link', (tester) async {
    final canal = const MethodChannel('dev.fluttercommunity.plus/share');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      canal,
      (call) async => 'ok',
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        canal,
        null,
      ),
    );

    final servidor = ServidorFake((req) {
      if (req.method == 'POST' && req.url.path.contains('/convites')) {
        return (200, _linhaConvite(papel: 'editor'));
      }
      return (500, {'message': 'requisição inesperada: ${req.url.path}'});
    });
    addTearDown(servidor.close);
    await abrir(tester, servidor);

    await tester.tap(find.widgetWithText(FilledButton, AppStrings.gerarLink));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(OutlinedButton, AppStrings.compartilhar),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.linkCompartilhado), findsOneWidget);

    await fechar(tester);
  });

  testWidgets('deve_revogar_convite_quando_dono_toca_revogar', (tester) async {
    // R-07: o link gerado é uma "capacidade" — o dono precisa poder
    // invalidá-la (o repositório tinha `revogar` sem chamador na UI).
    final servidor = ServidorFake((req) {
      if (req.method == 'POST' && req.url.path.contains('/convites')) {
        return (200, _linhaConvite(papel: 'editor'));
      }
      if (req.method == 'PATCH' && req.url.path.contains('/convites')) {
        return (204, const <Object?>[]);
      }
      return (500, {'message': 'requisição inesperada: ${req.url.path}'});
    });
    addTearDown(servidor.close);
    await abrir(tester, servidor);

    await tester.tap(find.widgetWithText(FilledButton, AppStrings.gerarLink));
    await tester.pumpAndSettle();
    expect(find.text(_link), findsOneWidget);

    await tester.tap(
      find.widgetWithText(TextButton, AppStrings.revogarConvite),
    );
    await tester.pumpAndSettle();

    // Volta ao estado inicial (papel + gerar) e avisa o dono.
    expect(find.text(AppStrings.conviteRevogado), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, AppStrings.gerarLink),
      findsOneWidget,
    );
    expect(find.text(_link), findsNothing);

    final patch = servidor.pedidos.singleWhere((p) => p.method == 'PATCH');
    expect(patch.url.query, contains('id=eq.$_token'));
    expect(jsonDecode(servidor.corpoDe(servidor.pedidos.indexOf(patch))), {
      'estado': 'revogado',
    });

    await fechar(tester);
  });

  testWidgets('deve_listar_convites_pendentes_quando_abre', (tester) async {
    // R-07 (parcial): convites criados antes nesta lista continuam válidos e
    // precisam aparecer para o dono revogar (F21-T03).
    final servidor = ServidorFake((req) {
      if (req.method == 'GET' && req.url.path.contains('/convites')) {
        return (200, [_linhaConvite(papel: 'editor')]);
      }
      return (500, {'message': 'requisição inesperada: ${req.url.path}'});
    });
    addTearDown(servidor.close);
    await abrir(tester, servidor);

    final get = servidor.pedidos.singleWhere((p) => p.method == 'GET');
    expect(get.url.query, contains('estado=eq.pendente'));
    expect(get.url.query, contains('lista_id=eq.$_listaId'));
    expect(find.text(AppStrings.convitesPendentes), findsOneWidget);
    expect(
      find.widgetWithText(TextButton, AppStrings.revogarConvitePendente),
      findsOneWidget,
    );

    await fechar(tester);
  });

  testWidgets('deve_revogar_convite_pendente_anterior_quando_toca_revogar', (
    tester,
  ) async {
    final servidor = ServidorFake((req) {
      if (req.method == 'GET' && req.url.path.contains('/convites')) {
        return (200, [_linhaConvite(papel: 'leitor')]);
      }
      if (req.method == 'PATCH' && req.url.path.contains('/convites')) {
        return (204, const <Object?>[]);
      }
      return (500, {'message': 'requisição inesperada: ${req.url.path}'});
    });
    addTearDown(servidor.close);
    await abrir(tester, servidor);
    expect(find.text(AppStrings.convitesPendentes), findsOneWidget);

    await tester.tap(
      find.widgetWithText(TextButton, AppStrings.revogarConvitePendente),
    );
    await tester.pumpAndSettle();

    // A lista de pendentes esvazia e o dono é avisado; nenhum link é gerado.
    expect(find.text(AppStrings.conviteRevogado), findsOneWidget);
    expect(find.text(AppStrings.convitesPendentes), findsNothing);
    expect(find.text(_link), findsNothing);

    final patch = servidor.pedidos.singleWhere((p) => p.method == 'PATCH');
    expect(patch.url.query, contains('id=eq.$_token'));
    expect(jsonDecode(servidor.corpoDe(servidor.pedidos.indexOf(patch))), {
      'estado': 'revogado',
    });

    await fechar(tester);
  });

  testWidgets('deve_criar_convite_email_quando_email_valido', (tester) async {
    final servidor = ServidorFake((req) {
      if (req.method == 'GET' && req.url.path.contains('/convites')) {
        return (200, const <Object?>[]);
      }
      if (req.method == 'POST' && req.url.path.contains('/convites')) {
        return (200, _linhaConvite(papel: 'editor', tipo: 'email'));
      }
      return (500, {'message': 'inesperada: ${req.url.path}'});
    });
    addTearDown(servidor.close);
    await abrir(tester, servidor);

    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.emailDoConvidado),
      'a@b.com',
    );
    await tester.tap(
      find.widgetWithText(OutlinedButton, AppStrings.enviarConvite),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.conviteCriado), findsOneWidget);

    final postIndex = servidor.pedidos.indexWhere((p) => p.method == 'POST');
    final corpo =
        jsonDecode(servidor.corpoDe(postIndex)) as Map<String, Object?>;
    expect(corpo['tipo'], 'email');
    expect(corpo['email'], 'a@b.com');
    expect(corpo['lista_id'], _listaId);

    await fechar(tester);
  });

  testWidgets('deve_recarregar_pendentes_quando_cria_convite_email', (
    tester,
  ) async {
    // O convite por e-mail recém-criado precisa aparecer na lista de
    // pendentes do sheet (e ficar revogável) sem reabrir.
    var gets = 0;
    final servidor = ServidorFake((req) {
      if (req.method == 'GET' && req.url.path.contains('/convites')) {
        gets++;
        return (
          200,
          gets == 1
              ? const <Object?>[]
              : [
                  _linhaConvite(
                    papel: 'editor',
                    tipo: 'email',
                    email: 'a@b.com',
                  ),
                ],
        );
      }
      if (req.method == 'POST' && req.url.path.contains('/convites')) {
        return (200, _linhaConvite(papel: 'editor', tipo: 'email'));
      }
      return (500, {'message': 'inesperada: ${req.url.path}'});
    });
    addTearDown(servidor.close);
    await abrir(tester, servidor);

    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.emailDoConvidado),
      'a@b.com',
    );
    await tester.tap(
      find.widgetWithText(OutlinedButton, AppStrings.enviarConvite),
    );
    await tester.pumpAndSettle();

    expect(gets, greaterThanOrEqualTo(2));
    expect(find.text(AppStrings.convitesPendentes), findsOneWidget);
    expect(
      find.widgetWithText(TextButton, AppStrings.revogarConvitePendente),
      findsOneWidget,
    );

    await fechar(tester);
  });

  testWidgets('deve_validar_email_quando_invalido', (tester) async {
    final servidor = ServidorFake(
      (req) => (500, {'message': 'nao deveria chamar'}),
    );
    addTearDown(servidor.close);
    await abrir(tester, servidor);

    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.emailDoConvidado),
      'invalido',
    );
    await tester.tap(
      find.widgetWithText(OutlinedButton, AppStrings.enviarConvite),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.erroEmailInvalido), findsOneWidget);
    await fechar(tester);
  });

  testWidgets('deve_mostrar_aviso_de_email_automatico_quando_abre', (
    tester,
  ) async {
    final servidor = ServidorFake(
      (req) => (500, {'message': 'requisicao inesperada'}),
    );
    addTearDown(servidor.close);
    await abrir(tester, servidor);

    expect(find.text(AppStrings.conviteEmailAviso), findsOneWidget);
    await fechar(tester);
  });
}
