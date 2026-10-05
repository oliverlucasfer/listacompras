import '../dominio/quantidade.dart';
import '../dominio/unidade.dart';

/// Data no formato dd/MM/aaaa.
String formatarData(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/'
    '${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Quantidade formatada + unidade do enum (ex.: '1,5 kg').
String formatarQuantidadeComUnidade(double quantidade, Unidade unidade) =>
    '${formatarQuantidade(quantidade)} ${unidade.valor}';
