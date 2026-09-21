# Frente — Arquivar e Desarquivar Listas (design)

> **Status:** aprovado em 21/09/2026 (decisões registradas na Seção 8)
> **Fase:** 26 · **Requisito:** RF-22 (arquivar/desarquivar listas)
> **Docs donos:** [01](../01-banco-de-dados.md) (schema/trigger), [03](../03-sincronizacao-offline.md) (payload/sync),
> [05](../05-app-flutter.md) (UI), [10](../10-wireframes-telas.md) (layout), [12](../12-prd.md), [14](../14-tarefas.md)

---

## 1. Motivação

O painel "Minhas Listas" cresce com o tempo e mistura listas ativas com listas velhas que o usuário não quer excluir (perderia o histórico) nem ver no dia a dia. Hoje só há **excluir** (tombstone, irreversível pela UI). Falta um estado intermediário: **arquivar** — some do painel, volta quando quiser, sem perder nada.

A operação é do **dono** (a lista é dele), reversível e 100% offline-first: uma coluna a mais em `listas`, propagada pelo caminho normal (Drift + fila + LWW).

## 2. Escopo

**Dentro:**
- Estado de arquivo **global da lista** (`arquivada_em`), controlado **só pelo dono**.
- Botão "Mostrar arquivadas" no painel; ação "Arquivar"/"Desarquivar" no menu do card (dono).
- Rótulo "Arquivada" no card.

**Fora (cortes seguintes):** arquivo por usuário (um membro esconder a lista só para si), ocultar automaticamente listas antigas, exclusão automática de arquivadas.

## 3. Banco — migration `0018_arquivar_listas.sql`

```sql
alter table public.listas add column arquivada_em timestamptz;

create index idx_listas_dono_ativas
  on public.listas (dono_id)
  where deletado_em is null and arquivada_em is null;

-- Defesa em profundidade: a policy de UPDATE de `listas` permite dono/editor;
-- arquivar/desarquivar é só do dono. O trigger rejeita a mudança da coluna por
-- quem não é o dono (mesmo espírito do `sync_dono`).
create or replace function public.protege_arquivo_dono()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.arquivada_em is distinct from old.arquivada_em
     and old.dono_id <> auth.uid() then
    raise exception 'APENAS_O_DONO_PODE_ARQUIVAR';
  end if;
  return new;
end;
$$;

create trigger trg_listas_arquivo_dono
  before update on public.listas
  for each row execute function public.protege_arquivo_dono();
```

- **Sem policy nova** — a coluna herda o RLS de `listas`; o trigger restringe a **autoria** da mudança ao dono.
- `null` = lista ativa; `timestamptz` = arquivada nesse instante (reversível: volta a `null`).
- Renomear (dono **ou** editor) não muda `arquivada_em` → o trigger não interfere (a comparação é por valor). O payload de updates que não são de arquivo **omite** a coluna (ver §4), então um rename de editor nunca carrega um `arquivada_em` obsoleto.
- `excluir_conta` (delete em cascata) e `transferir_dono` (muda `dono_id`) não tocam `arquivada_em`.

## 4. Drift, domínio e repositório

- `lib/drift/tables/lista_local.dart`: `DateTimeColumn get arquivadaEm => dateTime().nullable()();` (+ regenerar `database.g.dart`).
- `lib/features/listas/domain/lista.dart`: `final DateTime? arquivadaEm;` + mapeamento em `Lista.fromLocal`.
- `lib/features/listas/data/listas_repository.dart`:
  - `_payloadLista(String id, {bool incluirArquivo = false})` **omite** `arquivada_em` por padrão; só inclui a coluna quando `incluirArquivo: true`, usado **exclusivamente** por `definirArquivada`. O INSERT (criar) e os demais updates (renomear/excluir/duplicar) usam o default (omitir): no INSERT vale o default do banco (`null`); no UPDATE o valor do servidor fica intacto. Assim um payload antigo com `arquivada_em = null` não é rejeitado pelo trigger `protege_arquivo_dono` e o LWW segue em `updated_at`;
  - novo `Future<void> definirArquivada(String id, {required bool arquivada})` — grava `arquivada_em` (`agora`/`null`) + `updated_at` e enfileira `UPDATE` (mesmo caminho de `renomearLista`);
  - `duplicarLista` cria a nova lista **sem** arquivo (default `null`).
- `lib/features/sync/data/aplicador_remoto.dart` (`_aplicarLista`): mapear `arquivada_em` com tolerância (ausente → `null`).
- Os streams do painel continuam devolvendo tudo menos `deletado_em` — o filtro (mostrar/ocultar arquivadas) é do painel. A **projeção** do `watchListasComContagem` foi ajustada para carregar `arquivada_em` (o `watchListas` já lê a linha completa), para que o filtro e o rótulo tenham o dado na tela. O aplicador tolera `arquivada_em` ausente → `null`.

## 5. UI (painel de listas)

- **Toggle "Mostrar arquivadas"** na AppBar do `PainelListas` (ícone `Icons.inventory_2_outlined`, `tooltip` acessível). Estado **efêmero** (`setState`) — não persistido. Aplica-se a **Minhas** e **Compartilhadas**.
- **Filtro:** por padrão, `listasComContagemProvider` é filtrado para `arquivadaEm == null`; com o toggle ligado, todas aparecem (arquivadas no fim ou misturadas — o plano decide; recomenda-se manter a ordenação por `updated_at`).
- **Ação no card (`⋮`), só dono:** "Arquivar" (lista ativa) ou "Desarquivar" (lista arquivada e visível). Chama `definirArquivada(...)`, SnackBar `listaArquivada` / `listaDesarquivada`.
- **Rótulo:** card arquivado mostra um `AppChip` "Arquivada" (doc 15) no card (no subtítulo, junto da contagem e da atualização).
- **Busca (F16):** o filtro de texto continua; a lista buscada respeita o toggle.
- Ação **não** aparece para membro (a lista não é dele) nem para `leitor`.

## 6. Itens frequentes (RF-19)

Inalterados: arquivar é organização do painel. O ranking `watchItensFrequentes` continua considerando itens de listas arquivadas (só `deletado_em` exclui) — **decisão registrada**.

## 7. Testes

**SQL (`supabase/tests/arquivar_listas_tests.sql`, no CI):**
- ARQ-01: dono arquiva (UPDATE `arquivada_em`) → sucesso; desarquiva (volta a `null`) → sucesso.
- ARQ-02: editor tenta arquivar → exceção `APENAS_O_DONO_PODE_ARQUIVAR`.
- ARQ-03: editor renomeia (sem tocar `arquivada_em`) → sucesso (trigger não interfere).

**Unit — repositório (`listas_repository_test.dart`):**
- `deve_gravar_e_enfileirar_arquivo_quando_arquivar` (payload `arquivada_em` preenchido).
- `deve_limpar_arquivo_quando_desarquivar` (payload `arquivada_em` nulo).
- `nao_de_enviar_arquivo_quando_renomear` (rename omite a chave; arquivar/desarquivar incluem).
- `nao_deve_arquivar_lista_nova_quando_duplicar` (cópia nasce ativa).

**Unit — sync (`sync_engine_test.dart`):**
- `deve_mesclar_payload_quando_coalescer_arquivo_e_rename` (coalescing mescla os payloads do registro: arquivar + renomear offline mantém `arquivada_em`).

**Unit — aplicador:** `deve_mapear_arquivo_ausente_para_null_quando_linha_antiga` e `deve_mapear_arquivo_quando_presente`.

**Widget (painel):**
- `nao_deve_mostrar_arquivada_por_padrao_quando_painel`.
- `deve_mostrar_arquivada_com_rotulo_quando_toggle_ligado`.
- `deve_arquivar_quando_dono_toca_menu` e `nao_deve_mostrar_arquivar_para_membro`.
- `deve_desarquivar_quando_toca_em_lista_arquivada_visivel`.

**CI:** adicionar `arquivar_listas_tests.sql` ao job `supabase` e ao esqueleto do `07 §3`.

## 8. Decisões registradas (21/09/2026)

1. Arquivo **global da lista** (`arquivada_em`), **só o dono**; sem arquivo por usuário.
2. **Toggle "Mostrar arquivadas"** na AppBar (estado efêmero), aplicado a Minhas e Compartilhadas.
3. Reversível; sem confirmação; SnackBar informa.
4. **Trigger de defesa em profundidade** restringe a autoria da mudança ao dono (RLS permite dono/editor no UPDATE).
5. Listas arquivadas **continuam** no histórico de itens frequentes.
6. Sem ADR novo; Fase **26**, requisito **RF-22**.

## 9. Documentos relacionados
- [01 Banco de Dados](../01-banco-de-dados.md) — coluna, índice e trigger
- [03 Sincronização](../03-sincronizacao-offline.md) — payload de lista
- [05 App Flutter](../05-app-flutter.md) / [10 Wireframes](../10-wireframes-telas.md) — toggle e ação no card
- [12 PRD](../12-prd.md) — RF-22
- [14 Tarefas](../14-tarefas.md) — Fase 26
