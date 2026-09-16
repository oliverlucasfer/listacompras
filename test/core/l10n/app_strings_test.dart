import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/l10n/app_strings.dart';

void main() {
  test('deve_montar_titulo_de_exclusao_quando_informado_o_nome', () {
    expect(AppStrings.excluirListaTitulo('Compras'), 'Excluir "Compras"?');
  });

  test('deve_variar_mensagem_de_exclusao_por_itens_e_membros', () {
    expect(
      AppStrings.excluirListaMensagem(0, temMembros: false),
      'A lista será excluída.',
    );
    expect(
      AppStrings.excluirListaMensagem(1, temMembros: false),
      'O item será removido.',
    );
    expect(
      AppStrings.excluirListaMensagem(3, temMembros: false),
      'Os 3 itens serão removidos.',
    );
    expect(
      AppStrings.excluirListaMensagem(3, temMembros: true),
      'Os 3 itens serão removidos para todos os participantes.',
    );
  });
}
