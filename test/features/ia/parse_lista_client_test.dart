import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lista_compras/core/l10n/app_strings.dart';
import 'package:lista_compras/features/ia/data/parse_lista_client.dart';
import 'package:lista_compras/features/ia/domain/resposta_parse.dart';
import 'package:lista_compras/features/listas/domain/categoria.dart';
import 'package:lista_compras/features/listas/domain/unidade.dart';

void main() {
  ParseListaClient cliente({
    http.Client? httpClient,
    String? Function()? token,
    Duration? timeout,
  }) {
    return ParseListaClient(
      obterToken: token ?? () => 'jwt-teste',
      obterUri: () =>
          Uri.parse('https://projeto.supabase.co/functions/v1/parse-lista'),
      httpClient: httpClient,
      timeout: timeout ?? const Duration(seconds: 20),
    );
  }

  test('deve_enviar_jwt_e_texto_no_contrato_quando_parse', () async {
    http.Request? capturada;
    final clienteFalso = cliente(
      httpClient: MockClient((request) async {
        capturada = request;
        return http.Response('{"itens": [], "aviso": null}', 200);
      }),
    );

    await clienteFalso.parse('1kg de arroz');

    expect(capturada!.method, 'POST');
    expect(capturada!.url.path, '/functions/v1/parse-lista');
    expect(capturada!.headers['Authorization'], 'Bearer jwt-teste');
    expect(capturada!.body, '{"texto":"1kg de arroz"}');
  });

  test('deve_retornar_itens_e_aviso_quando_resposta_200', () async {
    final clienteFalso = cliente(
      httpClient: MockClient(
        (_) async => http.Response(
          '{"itens": ['
          '{"nome": "Arroz", "quantidade": 1, "unidade": "kg"},'
          '{"nome": "Queijo prato", "quantidade": 500, "unidade": "g"}],'
          '"aviso": "Interpretei pct como pacote"}',
          200,
        ),
      ),
    );

    final resposta = await clienteFalso.parse('1kg de arroz, 500g de queijo');

    expect(resposta.itens, hasLength(2));
    expect(resposta.itens[0].nome, 'Arroz');
    expect(resposta.itens[0].quantidade, 1.0);
    expect(resposta.itens[0].unidade, Unidade.kg);
    expect(resposta.itens[1].quantidade, 500.0);
    expect(resposta.itens[1].unidade, Unidade.g);
    expect(resposta.aviso, 'Interpretei pct como pacote');
  });

  test(
    'deve_aceitar_quantidade_fracionada_e_aviso_vazio_quando_resposta_200',
    () async {
      final clienteFalso = cliente(
        httpClient: MockClient(
          (_) async => http.Response(
            '{"itens": [{"nome": "Arroz", "quantidade": 0.5, "unidade": "kg"}],'
            '"aviso": null}',
            200,
          ),
        ),
      );

      final resposta = await clienteFalso.parse('meio quilo de arroz');

      expect(resposta.itens.single.quantidade, 0.5);
      expect(resposta.itens.single.unidade, Unidade.kg);
      expect(resposta.aviso, isNull);
    },
  );

  test('deve_mapear_categoria_do_enum_quando_resposta_200_f6t05', () async {
    final clienteFalso = cliente(
      httpClient: MockClient(
        (_) async => http.Response(
          '{"itens": [{"nome": "Queijo prato", "quantidade": 500,'
          ' "unidade": "g", "categoria": "frios"}], "aviso": null}',
          200,
        ),
      ),
    );

    final resposta = await clienteFalso.parse('500g de queijo prato');

    expect(resposta.itens.single.categoria, CategoriaItem.frios);
  });

  test('deve_usar_outros_quando_item_sem_categoria_f6t05', () async {
    // Compat (spec F6 §7): function antiga responde sem categoria.
    final clienteFalso = cliente(
      httpClient: MockClient(
        (_) async => http.Response(
          '{"itens": [{"nome": "Arroz", "quantidade": 1, "unidade": "kg"}],'
          '"aviso": null}',
          200,
        ),
      ),
    );

    final resposta = await clienteFalso.parse('1kg de arroz');

    expect(resposta.itens.single.categoria, CategoriaItem.outros);
  });

  test(
    'deve_rejeitar_categoria_fora_do_enum_quando_resposta_200_f6t05',
    () async {
      final clienteFalso = cliente(
        httpClient: MockClient(
          (_) async => http.Response(
            '{"itens": [{"nome": "Arroz", "quantidade": 1, "unidade": "kg",'
            ' "categoria": "alimentos"}], "aviso": null}',
            200,
          ),
        ),
      );

      await expectLater(
        clienteFalso.parse('1kg de arroz'),
        throwsA(
          isA<ErroIa>().having((e) => e.code, 'code', 'resposta_invalida'),
        ),
      );
    },
  );

  test(
    'deve_exibir_mensagem_do_contrato_quando_servidor_retorna_codigo',
    () async {
      // 8 códigos do contrato (doc 04 §2) sem `message` no corpo.
      final casos = <String, (int, String)>{
        'unauthorized': (401, AppStrings.iaSessaoExpirada),
        'texto_vazio': (400, AppStrings.iaTextoVazio),
        'texto_longo': (400, AppStrings.iaTextoLongo),
        'resposta_invalida': (422, AppStrings.iaRespostaInvalida),
        'rate_limit': (429, AppStrings.iaRateLimit),
        'cota_ia': (429, AppStrings.iaCotaIa),
        'timeout_ia': (504, AppStrings.iaTimeoutIa),
        'erro_interno': (500, AppStrings.iaErroInterno),
      };
      for (final entrada in casos.entries) {
        final code = entrada.key;
        final status = entrada.value.$1;
        final mensagem = entrada.value.$2;
        final clienteFalso = cliente(
          httpClient: MockClient(
            (_) async => http.Response('{"code": "$code"}', status),
          ),
        );

        await expectLater(
          clienteFalso.parse('arroz'),
          throwsA(
            isA<ErroIa>()
                .having((e) => e.code, 'code', code)
                .having((e) => e.mensagem, 'mensagem', mensagem),
          ),
          reason: 'código $code deve exibir a mensagem do contrato',
        );
      }
    },
  );

  test('deve_usar_message_do_servidor_quando_presente', () async {
    final clienteFalso = cliente(
      httpClient: MockClient(
        (_) async => http.Response(
          '{"code": "texto_longo", "message": "${AppStrings.iaTextoLongo}"}',
          400,
        ),
      ),
    );

    await expectLater(
      clienteFalso.parse('x' * 2001),
      throwsA(
        isA<ErroIa>()
            .having((e) => e.code, 'code', 'texto_longo')
            .having((e) => e.mensagem, 'mensagem', AppStrings.iaTextoLongo),
      ),
    );
  });

  test('deve_mapear_gateway_sem_corpo_json_quando_401_ou_504', () async {
    final bloqueado = cliente(
      httpClient: MockClient(
        (_) async => http.Response('<html>401</html>', 401),
      ),
    );
    await expectLater(
      bloqueado.parse('arroz'),
      throwsA(
        isA<ErroIa>()
            .having((e) => e.code, 'code', 'unauthorized')
            .having((e) => e.mensagem, 'mensagem', AppStrings.iaSessaoExpirada),
      ),
    );

    final demorou = cliente(
      httpClient: MockClient(
        (_) async => http.Response('gateway timeout', 504),
      ),
    );
    await expectLater(
      demorou.parse('arroz'),
      throwsA(
        isA<ErroIa>()
            .having((e) => e.code, 'code', 'timeout_ia')
            .having((e) => e.mensagem, 'mensagem', AppStrings.iaTimeoutIa),
      ),
    );
  });

  test('deve_lancar_unauthorized_sem_chamada_quando_sem_sessao', () async {
    var chamou = false;
    final clienteFalso = cliente(
      token: () => null,
      httpClient: MockClient((_) async {
        chamou = true;
        return http.Response('{}', 200);
      }),
    );

    await expectLater(
      clienteFalso.parse('arroz'),
      throwsA(isA<ErroIa>().having((e) => e.code, 'code', 'unauthorized')),
    );
    expect(chamou, isFalse);
  });

  test('deve_mapear_falha_de_rede_para_sem_conexao_quando_offline', () async {
    final clienteFalso = cliente(
      httpClient: MockClient(
        (_) async => throw http.ClientException('offline'),
      ),
    );

    await expectLater(
      clienteFalso.parse('arroz'),
      throwsA(
        isA<ErroIa>()
            .having((e) => e.code, 'code', 'sem_conexao')
            .having((e) => e.mensagem, 'mensagem', AppStrings.iaSemConexao),
      ),
    );
  });

  test(
    'deve_mapear_espera_indefinida_para_timeout_ia_quando_estourar',
    () async {
      final clienteFalso = cliente(
        timeout: const Duration(milliseconds: 10),
        httpClient: MockClient(
          (_) => Future.delayed(
            const Duration(seconds: 1),
            () => http.Response('{}', 200),
          ),
        ),
      );

      await expectLater(
        clienteFalso.parse('arroz'),
        throwsA(
          isA<ErroIa>()
              .having((e) => e.code, 'code', 'timeout_ia')
              .having((e) => e.mensagem, 'mensagem', AppStrings.iaTimeoutIa),
        ),
      );
    },
  );

  test('deve_tratar_resposta_200_fora_do_schema_quando_malformada', () async {
    final jsonInvalido = cliente(
      httpClient: MockClient((_) async => http.Response('nao-json', 200)),
    );
    await expectLater(
      jsonInvalido.parse('arroz'),
      throwsA(isA<ErroIa>().having((e) => e.code, 'code', 'resposta_invalida')),
    );

    final unidadeInvalida = cliente(
      httpClient: MockClient(
        (_) async => http.Response(
          '{"itens": [{"nome": "Arroz", "quantidade": 1,'
          ' "unidade": "quilos"}], "aviso": null}',
          200,
        ),
      ),
    );
    await expectLater(
      unidadeInvalida.parse('arroz'),
      throwsA(isA<ErroIa>().having((e) => e.code, 'code', 'resposta_invalida')),
    );

    final quantidadeInvalida = cliente(
      httpClient: MockClient(
        (_) async => http.Response(
          '{"itens": [{"nome": "Arroz", "quantidade": 0, "unidade": "kg"}],'
          ' "aviso": null}',
          200,
        ),
      ),
    );
    await expectLater(
      quantidadeInvalida.parse('arroz'),
      throwsA(isA<ErroIa>().having((e) => e.code, 'code', 'resposta_invalida')),
    );
  });
}
