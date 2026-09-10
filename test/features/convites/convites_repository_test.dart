import 'dart:async' show TimeoutException;
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/l10n/app_strings.dart';
import 'package:lista_compras/features/convites/data/convites_repository.dart';
import 'package:lista_compras/features/convites/domain/convite.dart';
import 'package:lista_compras/features/convites/domain/papel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'servidor_fake.dart';

const _listaId = '11111111-1111-2222-3333-444444444444';
const _token = 'aaaaaaaa-1111-2222-3333-bbbbbbbbbbbb';
const _usuarioId = 'U1';

String _jwt() {
  String parte(Map<String, Object?> dados) {
    final codificado = base64Url.encode(utf8.encode(jsonEncode(dados)));
    return codificado.replaceAll('=', '');
  }

  final agora = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final cabecalho = parte({'alg': 'HS256', 'typ': 'JWT'});
  final carga = parte({
    'sub': _usuarioId,
    'exp': agora + 3600,
    'iat': agora,
    'role': 'authenticated',
  });
  const assinatura = 'c2ln';
  return '$cabecalho.$carga.$assinatura';
}

Map<String, Object?> _linhaConvite() {
  return {
    'id': _listaId,
    'lista_id': _listaId,
    'criado_por': _usuarioId,
    'token': _token,
    'tipo': 'link',
    'email': null,
    'papel_oferecido': 'leitor',
    'estado': 'pendente',
    'expira_em': '2026-09-17T12:00:00.000Z',
    'created_at': '2026-09-10T12:00:00.000Z',
    'atualizado_em': '2026-09-10T12:00:00.000Z',
  };
}

List<Map<String, Object?>> _linhasMembros() {
  return [
    {'lista_id': _listaId, 'user_id': 'U1', 'papel': 'dono'},
    {'lista_id': _listaId, 'user_id': 'U2', 'papel': 'leitor'},
    {'lista_id': _listaId, 'user_id': 'U3', 'papel': 'editor'},
  ];
}

void main() {
  test('deve_aceitar_convite_quando_rpc_retorna_lista_id', () async {
    final servidor = ServidorFake((req) {
      if (req.url.path.contains('/rpc/aceitar_convite') &&
          req.method == 'POST') {
        return (200, _listaId);
      }
      return (500, {'message': 'requisição inesperada: ${req.url.path}'});
    });
    addTearDown(servidor.close);
    final repo = ConvitesRepository(
      SupabaseClient(
        'http://127.0.0.1:54321',
        'test-key',
        httpClient: servidor,
      ),
    );

    final listaId = await repo.aceitar(_token);

    expect(listaId, _listaId);
  });

  test('deve_mapear_erro_quando_token_invalido', () async {
    final servidor = ServidorFake((req) {
      if (req.url.path.contains('/rpc/aceitar_convite')) {
        return (
          400,
          {
            'code': 'P000000',
            'message': 'CONVITE_INVALIDO',
            'details': null,
            'hint': null,
          },
        );
      }
      return (500, {'message': 'requisição inesperada: ${req.url.path}'});
    });
    addTearDown(servidor.close);
    final repo = ConvitesRepository(
      SupabaseClient(
        'http://127.0.0.1:54321',
        'test-key',
        httpClient: servidor,
      ),
    );

    await expectLater(
      repo.aceitar(_token),
      throwsA(
        isA<ErroConvite>()
            .having((e) => e.code, 'code', 'convite_invalido')
            .having((e) => e.message, 'message', AppStrings.conviteInvalido),
      ),
    );
  });

  test('deve_mapear_erro_quando_sem_conexao', () async {
    final servidor = ServidorFake((req) {
      throw const SocketException('sem rota');
    });
    addTearDown(servidor.close);
    final repo = ConvitesRepository(
      SupabaseClient(
        'http://127.0.0.1:54321',
        'test-key',
        httpClient: servidor,
      ),
    );

    await expectLater(
      repo.aceitar(_token),
      throwsA(
        isA<ErroConvite>()
            .having((e) => e.code, 'code', 'sem_conexao')
            .having((e) => e.message, 'message', AppStrings.iaSemConexao),
      ),
    );
  });

  test('deve_mapear_erro_quando_requisicao_expira', () async {
    final servidor = ServidorFake((req) {
      throw TimeoutException('tempo esgotado');
    });
    addTearDown(servidor.close);
    final repo = ConvitesRepository(
      SupabaseClient(
        'http://127.0.0.1:54321',
        'test-key',
        httpClient: servidor,
      ),
    );

    await expectLater(
      repo.aceitar(_token),
      throwsA(
        isA<ErroConvite>()
            .having((e) => e.code, 'code', 'sem_conexao')
            .having((e) => e.message, 'message', AppStrings.iaSemConexao),
      ),
    );
  });

  test('deve_gerar_link_com_host_entrar', () {
    final servidor = ServidorFake((req) => (200, []));
    addTearDown(servidor.close);
    final repo = ConvitesRepository(
      SupabaseClient(
        'http://127.0.0.1:54321',
        'test-key',
        httpClient: servidor,
      ),
    );

    expect(
      repo.linkConvite(_token),
      'br.com.oliverlucas.listacompras://entrar?token=$_token',
    );
  });

  test('deve_criar_convite_do_tipo_link_quando_dono_pega_link', () async {
    final servidor = ServidorFake((req) {
      if (req.method == 'POST' && req.url.path.contains('/convites')) {
        final aceitaObjeto = (req.headers['Accept'] ?? '').contains(
          'vnd.pgrst.object',
        );
        return (201, aceitaObjeto ? _linhaConvite() : [_linhaConvite()]);
      }
      return (500, {'message': 'requisição inesperada: ${req.url.path}'});
    });
    addTearDown(servidor.close);
    final repo = ConvitesRepository(
      SupabaseClient(
        'http://127.0.0.1:54321',
        'test-key',
        httpClient: servidor,
      ),
    );

    final convite = await repo.criarLink(
      listaId: _listaId,
      papel: Papel.leitor,
    );

    final corpo = jsonDecode(servidor.corpoDe(0)) as Map<String, Object?>;
    expect(corpo['lista_id'], _listaId);
    expect(corpo['tipo'], 'link');
    expect(corpo['papel_oferecido'], 'leitor');
    expect(convite.listaId, _listaId);
    expect(convite.token, _token);
    expect(convite.papelOferecido, Papel.leitor);
    expect(convite.estado, 'pendente');
  });

  test('deve_revogar_convite_quando_dono_revoga', () async {
    final servidor = ServidorFake((req) {
      if (req.method == 'PATCH' && req.url.path.contains('/convites')) {
        return (200, []);
      }
      return (500, {'message': 'requisição inesperada: ${req.url.path}'});
    });
    addTearDown(servidor.close);
    final repo = ConvitesRepository(
      SupabaseClient(
        'http://127.0.0.1:54321',
        'test-key',
        httpClient: servidor,
      ),
    );

    await repo.revogar(_listaId);

    final corpo = jsonDecode(servidor.corpoDe(0)) as Map<String, Object?>;
    expect(corpo['estado'], 'revogado');
    expect(
      servidor.pedidos[0].url.queryParameters,
      containsPair('id', 'eq.$_listaId'),
    );
  });

  test('deve_listar_pendentes_da_lista', () async {
    final servidor = ServidorFake((req) {
      if (req.method == 'GET' && req.url.path.contains('/convites')) {
        return (200, [_linhaConvite()]);
      }
      return (500, {'message': 'requisição inesperada: ${req.url.path}'});
    });
    addTearDown(servidor.close);
    final repo = ConvitesRepository(
      SupabaseClient(
        'http://127.0.0.1:54321',
        'test-key',
        httpClient: servidor,
      ),
    );

    final pendentes = await repo.pendentesDaLista(_listaId);

    expect(pendentes, hasLength(1));
    expect(pendentes.single, isA<Convite>());
    final filtro = servidor.pedidos[0].url.queryParameters;
    expect(filtro, containsPair('lista_id', 'eq.$_listaId'));
    expect(filtro, containsPair('estado', 'eq.pendente'));
  });

  test('deve_listar_membros_ordenados_dono_editor_leitor', () async {
    final servidor = ServidorFake((req) {
      if (req.method == 'GET' && req.url.path.contains('/lista_membros')) {
        return (200, _linhasMembros());
      }
      return (500, {'message': 'requisição inesperada: ${req.url.path}'});
    });
    addTearDown(servidor.close);
    final repo = ConvitesRepository(
      SupabaseClient(
        'http://127.0.0.1:54321',
        'test-key',
        httpClient: servidor,
      ),
    );

    final membros = await repo.membrosDaLista(_listaId);

    expect(membros.map((m) => m.papel).toList(), [
      Papel.dono,
      Papel.editor,
      Papel.leitor,
    ]);
  });

  test('deve_mudar_papel_do_membro_quando_dono_altera', () async {
    final servidor = ServidorFake((req) {
      if (req.method == 'PATCH' && req.url.path.contains('/lista_membros')) {
        return (200, []);
      }
      return (500, {'message': 'requisição inesperada: ${req.url.path}'});
    });
    addTearDown(servidor.close);
    final repo = ConvitesRepository(
      SupabaseClient(
        'http://127.0.0.1:54321',
        'test-key',
        httpClient: servidor,
      ),
    );

    await repo.mudarPapel(listaId: _listaId, userId: 'U2', papel: Papel.editor);

    final corpo = jsonDecode(servidor.corpoDe(0)) as Map<String, Object?>;
    expect(corpo['papel'], 'editor');
    final filtro = servidor.pedidos[0].url.queryParameters;
    expect(filtro, containsPair('lista_id', 'eq.$_listaId'));
    expect(filtro, containsPair('user_id', 'eq.U2'));
  });

  test('deve_remover_membro_quando_dono_exclui', () async {
    final servidor = ServidorFake((req) {
      if (req.method == 'DELETE' && req.url.path.contains('/lista_membros')) {
        return (200, []);
      }
      return (500, {'message': 'requisição inesperada: ${req.url.path}'});
    });
    addTearDown(servidor.close);
    final repo = ConvitesRepository(
      SupabaseClient(
        'http://127.0.0.1:54321',
        'test-key',
        httpClient: servidor,
      ),
    );

    await repo.removerMembro(listaId: _listaId, userId: 'U2');

    final filtro = servidor.pedidos[0].url.queryParameters;
    expect(filtro, containsPair('lista_id', 'eq.$_listaId'));
    expect(filtro, containsPair('user_id', 'eq.U2'));
  });

  test('deve_sair_da_lista_quando_membro_sai', () async {
    final servidor = ServidorFake((req) {
      if (req.method == 'DELETE' && req.url.path.contains('/lista_membros')) {
        return (200, []);
      }
      if (req.method == 'GET' && req.url.path.contains('/auth/v1/user')) {
        return (
          200,
          {
            'id': _usuarioId,
            'aud': 'authenticated',
            'email': 'u1@teste.com',
            'created_at': '2026-01-01T00:00:00.000Z',
          },
        );
      }
      return (500, {'message': 'requisição inesperada: ${req.url.path}'});
    });
    addTearDown(servidor.close);
    final client = SupabaseClient(
      'http://127.0.0.1:54321',
      'test-key',
      httpClient: servidor,
    );
    await client.auth.setSession('refresh-token', accessToken: _jwt());
    final repo = ConvitesRepository(client);

    await repo.sairDaLista(_listaId);

    final filtro = servidor.pedidos[1].url.queryParameters;
    expect(filtro, containsPair('lista_id', 'eq.$_listaId'));
    expect(filtro, containsPair('user_id', 'eq.$_usuarioId'));
  });

  test('deve_aceitar_convite_nao_dirigido_com_mensagem_fallback', () async {
    final servidor = ServidorFake((req) {
      if (req.url.path.contains('/rpc/aceitar_convite')) {
        return (
          400,
          {
            'code': 'P000000',
            'message': 'CONVITE_NAO_DIRIGIDO_A_VOCE',
            'details': null,
            'hint': null,
          },
        );
      }
      return (500, {'message': 'requisição inesperada: ${req.url.path}'});
    });
    addTearDown(servidor.close);
    final repo = ConvitesRepository(
      SupabaseClient(
        'http://127.0.0.1:54321',
        'test-key',
        httpClient: servidor,
      ),
    );

    await expectLater(
      repo.aceitar(_token),
      throwsA(
        isA<ErroConvite>()
            .having((e) => e.code, 'code', 'convite_nao_dirigido_a_voce')
            .having((e) => e.message, 'message', AppStrings.conviteInesperado),
      ),
    );
  });
}
