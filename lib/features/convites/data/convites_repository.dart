import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/links.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/rede/erro_rede.dart';
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
    try {
      final linha = await _client
          .from('convites')
          .insert(conteudo)
          .select()
          .single();
      return Convite.fromMap(Map<String, Object?>.from(linha as Map));
    } on PostgrestException catch (e) {
      // FK (23503) ou RLS (42501): a lista não existe no servidor para o
      // usuário — só no Drift local (doc 08 §3/§8, F12-T02). Sem isto, o
      // erro bruto viraria "algo deu errado" sem ação possível.
      if (e.code == '23503' || e.code == '42501') {
        throw const ErroConvite(
          'lista_nao_sincronizada',
          AppStrings.conviteListaNaoSincronizada,
        );
      }
      throw const ErroConvite('inesperado', AppStrings.conviteInesperado);
    } catch (e) {
      if (ehSemConexao(e)) {
        throw const ErroConvite('sem_conexao', AppStrings.conviteSemConexao);
      }
      rethrow;
    }
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
    } catch (e) {
      if (ehSemConexao(e)) {
        throw const ErroConvite('sem_conexao', AppStrings.erroSemConexao);
      }
      rethrow;
    }
  }

  /// Transfere a lista para outro membro (doc 08 §6, RF-14, F24):
  /// online-only (papel não vive no Drift). Erros do contrato viram
  /// mensagens amigáveis, como nos demais RPCs.
  Future<void> transferirDono({
    required String listaId,
    required String novoDonoId,
  }) async {
    try {
      await _client.rpc(
        'transferir_dono',
        params: {'p_lista': listaId, 'p_novo_dono': novoDonoId},
      );
    } on PostgrestException catch (e) {
      throw ErroConvite.fromCodigoTransferencia(e.message);
    } catch (e) {
      if (ehSemConexao(e)) {
        throw const ErroConvite('sem_conexao', AppStrings.transferirSemConexao);
      }
      rethrow;
    }
  }

  /// Link compartilhável do convite (web: https; nativo: scheme) — doc 08 §1.1.
  String linkConvite(String token) => linkConviteDe(token);
}
