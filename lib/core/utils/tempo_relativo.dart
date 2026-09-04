/// Tempo relativo pt-BR para cards (wireframe 10 §2: "atualizada há 5 min").
String tempoRelativo(DateTime de, {required DateTime agora}) {
  final diferenca = agora.difference(de);
  if (diferenca.inSeconds < 60) return 'agora';
  if (diferenca.inMinutes < 60) return 'há ${diferenca.inMinutes} min';
  if (diferenca.inHours < 24) return 'há ${diferenca.inHours} h';
  if (diferenca.inDays < 2) return 'ontem';
  if (diferenca.inDays < 30) return 'há ${diferenca.inDays} dias';
  if (diferenca.inDays < 365) return 'há ${diferenca.inDays ~/ 30} meses';
  return 'há ${diferenca.inDays ~/ 365} anos';
}
