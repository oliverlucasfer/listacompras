/// Papéis do membro de uma lista (doc 01 §2, CHECK de `lista_membros`).
/// A ordem do enum é a ordem de exibição: dono → editor → leitor.
enum Papel {
  dono,
  editor,
  leitor;

  String get valor => name;

  static Papel fromValor(String v) {
    final valores = Papel.values;
    for (final papel in valores) {
      if (papel.name == v) return papel;
    }
    throw ArgumentError('papel desconhecido: $v');
  }
}
