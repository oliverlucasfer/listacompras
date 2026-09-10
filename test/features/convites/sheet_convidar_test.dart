import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/l10n/app_strings.dart';
import 'package:lista_compras/features/convites/data/convites_repository.dart';
import 'package:lista_compras/features/convites/providers/convites_providers.dart';
import 'package:lista_compras/features/convites/ui/sheet_convidar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'servidor_fake.dart';

const _listaId = '11111111-1111-2222-3333-444444444444';
const _token = 'aaaaaaaa-1111-2222-3333-bbbbbbbbbbbb';
final _link = 'br.com.oliverlucas.listacompras://entrar?token=$_token';

Map<String, Object?> _linhaConvite({required String papel}) {
  return {
    'id': _token,
    'lista_id': _listaId,
    'criado_por': 'U1',
    'token': _token,
    'tipo': 'link',
    'email': null,
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

Future<void> abrir(WidgetTester tester, ServidorFake servidor) async {
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
    expect(find.text(AppStrings.gerarLink), findsNothing);

    final corpo = jsonDecode(servidor.corpoDe(0)) as Map<String, Object?>;
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

    expect(find.text(AppStrings.erroGenerico), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, AppStrings.gerarLink),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsNothing);

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

  testWidgets('deve_copiar_token_cru_quando_tocar_copiar_token', (
    tester,
  ) async {
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
      find.widgetWithText(OutlinedButton, AppStrings.copiarToken),
    );
    await tester.pumpAndSettle();

    // Token cru, sem scheme da deep link.
    expect(copiado, _token);
    expect(find.text(AppStrings.tokenCopiado), findsOneWidget);

    await fechar(tester);
  });
}
