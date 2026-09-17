import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/config/links.dart';

void main() {
  final base = Uri.parse('https://app.exemplo.com/algum/caminho');

  test('deve_usar_app_web_url_quando_nativo', () {
    expect(origemWeb(web: false, base: base), 'http://localhost:8080');
    expect(
      redirectAuth(web: false, base: base),
      'br.com.oliverlucas.listacompras://login-callback',
    );
  });

  test('deve_usar_origem_atual_quando_web', () {
    expect(origemWeb(web: true, base: base), 'https://app.exemplo.com');
    expect(
      redirectAuth(web: true, base: base),
      'https://app.exemplo.com/login-callback',
    );
  });

  test('deve_montar_link_de_convite_por_plataforma', () {
    expect(
      linkConviteDe('t1', web: false),
      'br.com.oliverlucas.listacompras://entrar?token=t1',
    );
    expect(
      linkConviteDe('t1', web: true, base: base),
      'https://app.exemplo.com/entrar?token=t1',
    );
  });
}
