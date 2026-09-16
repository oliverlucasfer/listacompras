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

  test('deve_montar_tempo_relativo_centralizado', () {
    expect(AppStrings.tempoAgora, 'agora');
    expect(AppStrings.tempoMinutos(5), 'há 5 min');
    expect(AppStrings.tempoHoras(3), 'há 3 h');
    expect(AppStrings.tempoOntem, 'ontem');
    expect(AppStrings.tempoDias(5), 'há 5 dias');
    expect(AppStrings.tempoMeses(2), 'há 2 meses');
    expect(AppStrings.tempoAnos(2), 'há 2 anos');
  });

  test('deve_montar_progresso_da_lista', () {
    expect(AppStrings.progressoLista(3, 10), '3/10 itens concluídos');
    expect(AppStrings.progressoLista(0, 1), '0/1 item concluído');
  });
}
