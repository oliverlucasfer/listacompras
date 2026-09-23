import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/texto/validacao.dart';

void main() {
  test('deve_aceitar_quando_email_valido', () {
    expect(emailValido('a@b.co'), isTrue);
    expect(emailValido('  a@b.co  '), isTrue);
    expect(emailValido('x.y+z@dominio.com.br'), isTrue);
  });

  test('deve_rejeitar_quando_email_invalido', () {
    expect(emailValido(''), isFalse);
    expect(emailValido('sem-arroba'), isFalse);
    expect(emailValido('a@b'), isFalse);
    expect(emailValido('a b@c.com'), isFalse);
    expect(emailValido('@b.com'), isFalse);
  });
}
