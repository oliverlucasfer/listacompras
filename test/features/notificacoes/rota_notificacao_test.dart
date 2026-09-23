import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/features/notificacoes/domain/rota_notificacao.dart';

void main() {
  test('deve_abrir_entrar_quando_convite_com_token', () {
    expect(
      rotaDaNotificacao({'tipo': 'convite', 'token': 'abc'}),
      '/entrar?token=abc',
    );
  });

  test('deve_abrir_lista_quando_membro', () {
    expect(
      rotaDaNotificacao({'tipo': 'membro', 'lista_id': 'L1'}),
      '/lista/L1',
    );
  });

  test('deve_devolver_null_quando_dados_incompletos', () {
    expect(rotaDaNotificacao({'tipo': 'convite'}), isNull);
    expect(rotaDaNotificacao({'tipo': 'membro'}), isNull);
    expect(rotaDaNotificacao({'tipo': 'outro'}), isNull);
    expect(rotaDaNotificacao({}), isNull);
  });
}
