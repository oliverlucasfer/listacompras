import 'dart:async' show TimeoutException;
import 'dart:io' show SocketException;

import 'package:http/http.dart' show ClientException;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/l10n/app_strings.dart';
import '../domain/convite.dart';
import '../domain/papel.dart';

/// Operações de compartilhamento (doc 08 §2–3.2, RF-13): criacao de link,
/// revogação, gestão de membros e aceitação do convite via RPC
/// `aceitar_convite` (migration 0007). Erros viram `ErroConvite` com
/// mensagem amigável — a UI nunca vê JSON bruto ou exceptions do Supabase.
class ConvitesRepository {
  ConvitesRepository(this._client);

  final SupabaseClient _client;

  /// Cria um convite por link (doc 08 §2): INSERT em `convites`
  /// (`tipo: 'link'`, papel ofertado). Token e `expira_em` vêm do servidor.
  Future<Convite> criarLink({
    required String listaId,
    required Papel papel,
  }) async {
    final criadoPor = _client.auth.currentUser?.id;
    final conteudo = {
      'lista_id': listaId,
      'tipo': 'link',
      'papel_oferecido': papel.valor,
    };
    if (criadoPor != null) conteudo['criado_por'] = criadoPor;
    final linha = await _client
        .from('convites')
        .insert(conteudo)
        .select()
        .single();
    return Convite.fromMap(Map<String, Object?>.from(linha as Map));
  }

  /// Marca o convite como revogado (doc 08 §3.1 — UPDATE direto, RLS de dono).
  Future<void> revogar(String conviteId) async {
    await _client
        .from('convites')
        .update({'estado': 'revogado'})
        .eq('id', conviteId);
  }

  /// Convites pendentes da lista (doc 08 §2).
  Future<List<Convite>> pendentesDaLista(String listaId) async {
    final linhas = await _client
        .from('convites')
        .select()
        .eq('lista_id', listaId)
        .eq('estado', 'pendente');
    return [
      for (final linha in linhas as List)
        Convite.fromMap(Map<String, Object?>.from(linha as Map)),
    ];
  }

  /// Membros da lista em ordem dono → editor → leitor (wireframe 10 §4.3).
  Future<List<MembroLista>> membrosDaLista(String listaId) async {
    final linhas = await _client
        .from('lista_membros')
        .select('user_id, papel')
        .eq('lista_id', listaId);
    final membros = [
      for (final linha in linhas as List)
        MembroLista.fromMap(Map<String, Object?>.from(linha as Map)),
    ]..sort((a, b) => a.papel.index.compareTo(b.papel.index));
    return membros;
  }

  /// Altera o papel de um membro (doc 08 §3.2 — RLS exige dono).
  Future<void> mudarPapel({
    required String listaId,
    required String userId,
    required Papel papel,
  }) async {
    await _client
        .from('lista_membros')
        .update({'papel': papel.valor})
        .eq('lista_id', listaId)
        .eq('user_id', userId);
  }

  /// Remove um membro (doc 08 §3.2 — dono remove; teste SQL de 0002 cobre).
  Future<void> removerMembro({
    required String listaId,
    required String userId,
  }) async {
    await _client
        .from('lista_membros')
        .delete()
        .eq('lista_id', listaId)
        .eq('user_id', userId);
  }

  /// O próprio usuário sai da lista (doc 08 §3.2).
  Future<void> sairDaLista(String listaId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw const ErroConvite('sem_sessao', AppStrings.conviteInesperado);
    }
    await _client
        .from('lista_membros')
        .delete()
        .eq('lista_id', listaId)
        .eq('user_id', userId);
  }

  /// Aceita um convite via RPC `aceitar_convite` (doc 08 §3.1, migration
  /// 0007): sucesso devolve a `lista_id`; códigos `CONVITE_*` e falhas de
  /// rede viram `ErroConvite` com mensagem amigável (doc 04 §2).
  Future<String> aceitar(String token) async {
    try {
      final resultado = await _client.rpc(
        'aceitar_convite',
        params: {'p_token': token},
      );
      if (resultado is String && resultado.isNotEmpty) return resultado;
      throw const ErroConvite('inesperado', AppStrings.conviteInesperado);
    } on PostgrestException catch (e) {
      throw ErroConvite.fromCodigoDoContrato(e.message);
    } on SocketException {
      throw const ErroConvite('sem_conexao', AppStrings.iaSemConexao);
    } on ClientException {
      throw const ErroConvite('sem_conexao', AppStrings.iaSemConexao);
    } on TimeoutException {
      throw const ErroConvite('sem_conexao', AppStrings.iaSemConexao);
    }
  }

  /// Deep link do app (doc 08 §1.1) para compartilhar o token.
  String linkConvite(String token) =>
      'br.com.oliverlucas.listacompras://entrar?token=$token';
}
