import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/l10n/app_strings.dart';
import 'package:lista_compras/features/convites/domain/papel.dart';

void main() {
  test('deve_rotular_quando_papel', () {
    expect(Papel.dono.rotulo, AppStrings.papelDono);
    expect(Papel.editor.rotulo, AppStrings.convidarPapelEditor);
    expect(Papel.leitor.rotulo, AppStrings.convidarPapelLeitor);
  });
}
