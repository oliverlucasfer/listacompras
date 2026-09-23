import '../../../core/l10n/app_strings.dart';

/// Papéis do membro de uma lista (doc 01 §2, CHECK de `lista_membros`).
/// A ordem do enum é a ordem de exibição: dono → editor → leitor.
enum Papel {
  dono,
  editor,
  leitor;

  String get valor => name;

  /// Rótulo exibido (doc 05/10) — fonte única (F39).
  String get rotulo => switch (this) {
    dono => AppStrings.papelDono,
    editor => AppStrings.convidarPapelEditor,
    leitor => AppStrings.convidarPapelLeitor,
  };

  static Papel fromValor(String v) {
    final valores = Papel.values;
    for (final papel in valores) {
      if (papel.name == v) return papel;
    }
    throw ArgumentError('papel desconhecido: $v');
  }
}
