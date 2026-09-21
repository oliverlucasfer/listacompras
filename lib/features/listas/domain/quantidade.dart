/// Formata uma quantidade para exibição: inteiros sem casa decimal
/// (`2.0` → `"2"`), fracionários como estão (`1.5` → `"1.5"`). Fonte única
/// da regra — usada pela linha do item, pelo editor/steppers, pelo modo
/// mercado, pelo modal de importação e pelo modal de adicionar de outra
/// lista (F27-T02).
String formatarQuantidade(double q) =>
    q == q.roundToDouble() ? q.toInt().toString() : q.toString();
