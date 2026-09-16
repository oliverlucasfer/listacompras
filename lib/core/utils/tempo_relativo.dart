import '../l10n/app_strings.dart';

/// Tempo relativo pt-BR para cards (wireframe 10 §2: "atualizada há 5 min").
String tempoRelativo(DateTime de, {required DateTime agora}) {
  final diferenca = agora.difference(de);
  if (diferenca.inSeconds < 60) return AppStrings.tempoAgora;
  if (diferenca.inMinutes < 60) {
    return AppStrings.tempoMinutos(diferenca.inMinutes);
  }
  if (diferenca.inHours < 24) return AppStrings.tempoHoras(diferenca.inHours);
  if (diferenca.inDays < 2) return AppStrings.tempoOntem;
  if (diferenca.inDays < 30) return AppStrings.tempoDias(diferenca.inDays);
  if (diferenca.inDays < 365) {
    return AppStrings.tempoMeses(diferenca.inDays ~/ 30);
  }
  return AppStrings.tempoAnos(diferenca.inDays ~/ 365);
}
