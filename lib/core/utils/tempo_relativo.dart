/// Tipo do tempo relativo (wireframe 10 §2: "atualizada há 5 min"). A camada
/// não-UI devolve **dados** — sem texto localizado (RF-39, F56); a UI formata
/// com `context.l10n`.
enum TempoRelativoTipo { agora, minutos, horas, ontem, dias, meses, anos }

/// Descrição neutra de "há quanto tempo" um instante ocorreu. [valor] é a
/// grandeza (minutos/horas/dias/meses/anos); ignorado em `agora`/`ontem`.
class TempoRelativo {
  const TempoRelativo(this.tipo, [this.valor = 0]);

  final TempoRelativoTipo tipo;
  final int valor;
}

TempoRelativo tempoRelativo(DateTime de, {required DateTime agora}) {
  final diferenca = agora.difference(de);
  if (diferenca.inSeconds < 60) {
    return const TempoRelativo(TempoRelativoTipo.agora);
  }
  if (diferenca.inMinutes < 60) {
    return TempoRelativo(TempoRelativoTipo.minutos, diferenca.inMinutes);
  }
  if (diferenca.inHours < 24) {
    return TempoRelativo(TempoRelativoTipo.horas, diferenca.inHours);
  }
  if (diferenca.inDays < 2) {
    return const TempoRelativo(TempoRelativoTipo.ontem);
  }
  if (diferenca.inDays < 30) {
    return TempoRelativo(TempoRelativoTipo.dias, diferenca.inDays);
  }
  if (diferenca.inDays < 365) {
    return TempoRelativo(TempoRelativoTipo.meses, diferenca.inDays ~/ 30);
  }
  return TempoRelativo(TempoRelativoTipo.anos, diferenca.inDays ~/ 365);
}
