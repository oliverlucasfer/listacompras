import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/papel.dart';

/// Papéis do usuário corrente por lista, em memória (doc 08 §4 — F7-T02):
/// carregado pelo bootstrap a cada troca de usuário/resync, seguido por
/// realtime na Task 3. Estado interno é um [ValueNotifier] — sem Drift;
/// [watch] reemite o valor corrente a cada mudança.
class PapelRepository {
  PapelRepository(this._client);

  final SupabaseClient _client;

  final ValueNotifier<Map<String, Papel>> _papeis = ValueNotifier(const {});

  /// Última lista onde outro membro entrou (doc 08 §7, F7-T07): sinal
  /// one-shot setado pelo realtime e consumido/resettado pela tela aberta.
  final ValueNotifier<String?> membroEntrou = ValueNotifier(null);

  Map<String, Papel> get valores => _papeis.value;

  /// Papel do usuário corrente na lista; null = desconhecido
  /// (a UI trata como leitor até carregar, doc 08 §4).
  Papel? papelDe(String listaId) => _papeis.value[listaId];

  /// Carrega `lista_membros` do usuário corrente e mescla no estado.
  Future<void> carregar(String usuarioId) async {
    final linhas = await _client
        .from('lista_membros')
        .select('lista_id, papel')
        .eq('user_id', usuarioId);
    final mesclado = Map<String, Papel>.of(_papeis.value);
    for (final linha in linhas as List) {
      final mapa = Map<String, Object?>.from(linha as Map);
      final listaId = mapa['lista_id'] as String?;
      final papel = mapa['papel'];
      if (listaId == null || papel is! String) continue;
      try {
        mesclado[listaId] = Papel.fromValor(papel);
      } on ArgumentError {
        // Papel inesperado (servidor divergiu do enum fechado): ignora a linha.
      }
    }
    _notificar(mesclado);
  }

  /// Stream do estado completo (reemite o valor corrente a cada mudança).
  Stream<Map<String, Papel>> watch() {
    late StreamController<Map<String, Papel>> controlador;
    void reemitir() {
      if (!controlador.isClosed) controlador.add(_papeis.value);
    }

    controlador = StreamController<Map<String, Papel>>(
      onListen: () {
        controlador.add(_papeis.value);
        _papeis.addListener(reemitir);
      },
      onCancel: () => _papeis.removeListener(reemitir),
    );
    return controlador.stream;
  }

  void atualizar(String listaId, Papel papel) =>
      _notificar({..._papeis.value, listaId: papel});

  /// INSERT de outro membro no realtime (doc 08 §7, F7-T07): sem nome —
  /// o RLS não expõe o perfil de outros membros.
  void notificarEntrada(String listaId) => membroEntrou.value = listaId;

  /// A tela da lista aberta consome o sinal após mostrar o feedback.
  void consumirEntrada() => membroEntrou.value = null;

  void remover(String listaId) {
    final copia = {..._papeis.value}..remove(listaId);
    _notificar(copia);
  }

  void limpar() {
    _notificar(const {});
    membroEntrou.value = null;
  }

  void _notificar(Map<String, Papel> novos) {
    if (mapEquals(_papeis.value, novos)) return;
    _papeis.value = novos;
  }
}
