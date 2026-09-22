# Frente — Convite por E-mail (RF-13, fluxo B) (design)

> **Status:** aprovado em 21/09/2026 (decisões registradas na Seção 8)
> **Fase:** 32 · **Requisito:** RF-13 (compartilhamento por convite — fluxo B, e-mail)
> **Docs donos:** [01](../01-banco-de-dados.md), [02](../02-seguranca-rls.md), [08 §4](../08-compartilhamento-colaborativo.md),
> [05](../05-app-flutter.md), [10](../10-wireframes-telas.md), [12](../12-prd.md), [14](../14-tarefas.md), [16](../16-roadmap-pos-mvp.md)

---

## 1. Motivação

A rodada link-only entregou o convite por **link**; o fluxo por **e-mail** (doc 08 §4) ficou para depois — o schema (`convites.tipo='email'`, `email`, `email_autenticado()`, policy `convites_select_email_proprio`) e o RPC `aceitar_convite` **já o suportam**, mas o app não cria nem mostra convites por e-mail.

Falta: o dono **criar** o convite por e-mail e o convidado **ver/aceitar/recusar** no app. O **envio de e-mail** (Edge Function transacional) segue adiado (doc 08 §4 — o painel cobre a descoberta).

## 2. Escopo

**Dentro:**
- Criar convite por e-mail no sheet "Convidar" (dono digita o e-mail + papel).
- Painel **"Convites pendentes"** no Minhas Listas (título da lista, papel) com **Aceitar** / **Recusar**.
- 2 RPCs `security definer` novos (título da lista e recusa), reusando o `aceitar_convite` existente.

**Fora:** envio de e-mail (Edge Function `enviar-convite`, provedor adiado), notificação push.

## 3. Banco — migration `0019_convites_email.sql`

O RLS de `convites` fica **intacto** (o convidado não é membro e não pode ler `listas` nem fazer UPDATE). O caminho é `security definer`:

```sql
-- Meus convites por e-mail pendentes (título da lista vem do definer, sem
-- expor a lista ao convidado antes do aceite — doc 02 §1).
create or replace function public.meus_convites_pendentes()
returns table (id uuid, lista_titulo text, papel_oferecido text, expira_em timestamptz)
language sql
security definer
set search_path = public
stable
as $$
  select c.id, l.titulo, c.papel_oferecido, c.expira_em
  from public.convites c
  join public.listas l on l.id = c.lista_id
  where c.tipo = 'email'
    and c.estado = 'pendente'
    and c.expira_em >= now()
    and lower(c.email) = lower(public.email_autenticado())
  order by c.created_at desc
$$;

-- Recusar o próprio convite por e-mail (só o dirigido ao meu e-mail).
create or replace function public.recusar_convite(p_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.convites
  set estado = 'revogado', atualizado_em = now()
  where id = p_id
    and tipo = 'email'
    and estado = 'pendente'
    and expira_em >= now()
    and lower(email) = lower(public.email_autenticado());
  if not found then
    raise exception 'CONVITE_INVALIDO';
  end if;
end;
$$;

revoke execute on function public.meus_convites_pendentes() from public, anon;
revoke execute on function public.recusar_convite(uuid) from public, anon;
grant execute on function public.meus_convites_pendentes() to authenticated;
grant execute on function public.recusar_convite(uuid) to authenticated;
```

- `aceitar_convite` (0007) **não muda**: o aceite reusa o mesmo RPC (idempotente; caminho de e-mail já tratado).
- `email_autenticado()` (0007) reusado.

## 4. Repositório

Em `lib/features/convites/data/convites_repository.dart` (online-only, como `criarLink`/`aceitar`):

```dart
/// Cria um convite por e-mail (doc 08 §4): reusa um convite pendente do mesmo
/// e-mail nesta lista (doc 08 §2) ou insere um novo. Online-only.
Future<Convite> criarConviteEmail({
  required String listaId,
  required String email,
  required Papel papel,
});

/// Meus convites por e-mail pendentes (RPC meus_convites_pendentes).
Future<List<ConvitePendente>> meusConvitesPendentes();

/// Recusa o próprio convite (RPC recusar_convite).
Future<void> recusarConvite(String id);
```

- `ConvitePendente { String id; String listaTitulo; Papel papelOferecido; DateTime expiraEm; }` em `lib/features/convites/domain/`.
- `criarConviteEmail` reusa: SELECT `convites` (dono vê pela policy) `tipo='email'`, `estado='pendente'`, `lower(email)` igual na lista; se existir, `UPDATE papel_oferecido` (se mudou) e devolve; senão `INSERT`.
- Erros mapeados como os demais (`ErroConvite`): e-mail inválido (validação na UI), `lista_nao_sincronizada` (FK/RLS), `sem_conexao`, `inesperado`.

## 5. UI

### 5.1. Sheet "Convidar" (dono)
- Além do bloco de link, um campo **"E-mail"** (`AppCampoTexto`, teclado de e-mail) + o papel escolhido + botão **"Enviar convite"**.
- Validação local de e-mail (mesmo regex do cadastro); sucesso → SnackBar "Convite enviado para <e-mail>." (copy sem prometer e-mail físico: "Convite criado. A pessoa verá no app ao entrar.").
- Aviso curto de que **não há e-mail automático** nesta rodada (doc 08 §4).

### 5.2. Painel "Convites pendentes" (Minhas Listas)
- No topo do `PainelListas` (filtro **Minhas**), uma seção com os cards de `meusConvitesPendentes()` (fetch ao abrir; sem Drift).
- Card: `Convite para <título>` + chip do papel + "expira em …"; ações **Aceitar** e **Recusar**.
  - **Aceitar** → `aceitar(token)` (RPC) → navega para `/lista/:id` (o convite não expõe o token na RPC de pendentes; o aceite precisa do token → ver §6).
  - **Recusar** → `recusarConvite(id)` → remove o card.
- Sem nome do convidante (o RLS não expõe perfis) — copy neutra.
- Vazio: a seção some quando não há pendentes.

## 6. Detalhe do aceite (token)

`meus_convites_pendentes()` devolve o **id**, não o `token`. O aceite usa `aceitar_convite(token)`. Então a RPC deve devolver também o `token` (o convidado já é o destinatário; expor o próprio token a ele é inócuo) — **ajuste**: a função retorna `(id, token, lista_titulo, papel_oferecido, expira_em)`. Assim o card chama `aceitar(token)` direto.

## 7. Testes

**SQL (`supabase/tests/convites_email_tests.sql`, no CI):**
- CE-01: `meus_convites_pendentes()` devolve o convite dirigido ao meu e-mail (com título e token); não devolve o de outro e-mail.
- CE-02: `recusar_convite(id)` marca `revogado` só o meu; o de outro e-mail → `CONVITE_INVALIDO`.
- CE-03: convite expirado não aparece em `meus_convites_pendentes()`.
- CE-04: anon/outro usuário não executa (grant restrito).

**Unit (`convites_repository_test.dart`):**
- `deve_criar_convite_email_quando_nao_existe` (INSERT com `tipo='email'`, `email`, `papel_oferecido`).
- `deve_reusar_convite_email_quando_ja_pendente` (não insere de novo).
- `deve_listar_meus_convites_pendentes` (RPC).
- `deve_recusar_convite` (RPC) e mapear `CONVITE_INVALIDO`.

**Widget:**
- Sheet: `deve_criar_convite_email_quando_email_valido`; `deve_validar_email_quando_invalido`.
- Painel: `deve_mostrar_convite_pendente_quando_ha`; `deve_aceitar_e_navegar_quando_toca`; `deve_recusar_e_remover_quando_toca`; `nao_deve_mostrar_secao_quando_sem_pendentes`.

**CI:** adicionar `convites_email_tests.sql` ao job `supabase` e ao esqueleto do `07 §3`.

## 8. Decisões registradas (21/09/2026)

1. Fluxo B **sem envio de e-mail** nesta rodada (doc 08 §4); o painel cobre a descoberta.
2. RPCs `security definer` (`meus_convites_pendentes` com `token`+título; `recusar_convite`); RLS de `convites` **intacto**.
3. Reuso de convite pendente do mesmo e-mail na lista (doc 08 §2).
4. Aceite reusa `aceitar_convite` (idempotente); recusa via RPC novo.
5. Copy sem nome do convidante (RLS não expõe perfis).
6. Sem ADR novo; Fase **32**, requisito **RF-13** (completa o fluxo B).

## 9. Documentos relacionados
- [08 Compartilhamento](../08-compartilhamento-colaborativo.md) — fluxo B (§4)
- [01](../01-banco-de-dados.md)/[02](../02-seguranca-rls.md) — RPCs e grants
- [05 App Flutter](../05-app-flutter.md) / [10 Wireframes](../10-wireframes-telas.md) — sheet e painel
- [12 PRD](../12-prd.md) — RF-13
- [14 Tarefas](../14-tarefas.md) — Fase 32
