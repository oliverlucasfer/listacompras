import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/features/notificacoes/data/notificacoes_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_notificacoes_push.dart';
import 'repositorio_tokens_fake.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('deve_pedir_permissao_uma_vez_quando_chamado_duas_vezes', () async {
    final push = NotificacoesPushFake();
    final repo = RepositorioTokensFake();
    final servico = NotificacoesService(
      push: push,
      repositorio: repo,
      plataforma: 'android',
    );
    expect(await servico.talvezPedirPermissao(), isTrue);
    expect(await servico.talvezPedirPermissao(), isFalse);
    expect(push.pedidos, 1);
    expect(repo.registrados, ['token-fake']);
  });

  test('deve_registrar_token_quando_permissao_concedida', () async {
    final push = NotificacoesPushFake();
    final repo = RepositorioTokensFake();
    final servico = NotificacoesService(
      push: push,
      repositorio: repo,
      plataforma: 'android',
    );
    await servico.definirAtivas(true);
    expect(repo.registrados, ['token-fake']);
  });

  test('deve_remover_token_quando_desativado', () async {
    final push = NotificacoesPushFake();
    final repo = RepositorioTokensFake();
    final servico = NotificacoesService(
      push: push,
      repositorio: repo,
      plataforma: 'android',
    );
    await servico.definirAtivas(false);
    expect(repo.removidos, ['token-fake']);
    expect(push.apagouToken, isTrue);
  });

  test('deve_nao_pedir_quando_plataforma_sem_suporte', () async {
    final push = NotificacoesPushFake(suportado: false);
    final servico = NotificacoesService(
      push: push,
      repositorio: RepositorioTokensFake(),
      plataforma: 'android',
    );
    expect(await servico.talvezPedirPermissao(), isFalse);
    expect(push.pedidos, 0);
  });
}
