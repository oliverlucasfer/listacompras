/// Máquina de estados de sync na UI (doc 03 §6).
sealed class SyncStatus {
  const SyncStatus();
}

/// Fila vazia e nada a fazer (ícone check discreto).
class Sincronizado extends SyncStatus {
  const Sincronizado();
}

/// Flush em andamento (spinner pequeno).
class Sincronizando extends SyncStatus {
  const Sincronizando();
}

/// Fila com mutações aguardando envio (badge "N alterações pendentes").
class Pendente extends SyncStatus {
  const Pendente(this.total);

  final int total;
}

/// Sem rede — mutações acumulam na fila (banner discreto).
class Offline extends SyncStatus {
  const Offline();
}

/// Esgotou as 10 tentativas (doc 03 §3) — banner com ação "tentar de novo".
class ErroSync extends SyncStatus {
  const ErroSync();
}
