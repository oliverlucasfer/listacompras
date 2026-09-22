# Fase 32 — Convite por E-mail (RF-13, fluxo B): Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Entregar o fluxo B do RF-13 — o dono cria um convite por e-mail e o convidado vê/aceita/recusa no app ("Convites pendentes"). Sem envio de e-mail (Edge Function adiada).

**Architecture:** 2 RPCs `security definer` (título da lista + recusa) preservando o RLS de `convites`; o aceite reusa `aceitar_convite`. App: repositório online-only + sheet "Convidar" com e-mail + seção de pendentes no painel.

**Tech Stack:** Postgres/Supabase (RPC, grants) · Flutter · Riverpod · go_router.

**Spec:** `docs/superpowers/specs/2026-09-21-convite-email-design.md`

## Global Constraints

- Toda tarefa termina com `dart format . && flutter analyze && flutter test` verdes; tarefas de banco rodam também `supabase db reset` + o script SQL.
- Uma tarefa = um commit, mensagem `F32-Tnn: <resumo>` em pt-BR.
- **Nenhuma mudança em `docs/03`**; migrations append-only (`0019`).
- Strings de UI **só** em `lib/core/l10n/app_strings.dart`.
- RLS de `convites` **intacto**; convites são **online-only** (não vão ao Drift).
- Sem envio de e-mail; sem nome do convidante (RLS não expõe perfis).
- Docs donos atualizados no mesmo PR; teste nome `deve_<resultado>_quando_<condição>`.
- Push/merge **só** com autorização explícita do dono.

---

### Task 1: Banco — migration `0019` (RPCs) + testes SQL + CI

**Files:**
- Create: `supabase/migrations/0019_convites_email.sql`
- Create: `supabase/tests/convites_email_tests.sql`
- Modify: `.github/workflows/ci.yml` (step novo)
- Modify: `docs/07-qualidade-ci.md` (§3 esqueleto — nova linha)

**Interfaces:**
- Consumes: `public.convites`, `public.listas`, `public.email_autenticado()` (0007).
- Produces: RPC `meus_convites_pendentes()` e `recusar_convite(uuid)`.

- [ ] **Step 1: Escrever a migration**

`supabase/migrations/0019_convites_email.sql`:

```sql
-- 0019_convites_email.sql — convite por e-mail: painel e recusa (doc 08 §4,
-- RF-13, F32). O RLS de `convites` fica intacto: o convidado não é membro e
-- não pode ler `listas` nem fazer UPDATE — o caminho são RPCs security definer.

create or replace function public.meus_convites_pendentes()
returns table (
  id uuid,
  token uuid,
  lista_titulo text,
  papel_oferecido text,
  expira_em timestamptz
)
language sql
security definer
set search_path = public
stable
as $$
  select c.id, c.token, l.titulo, c.papel_oferecido, c.expira_em
  from public.convites c
  join public.listas l on l.id = c.lista_id
  where c.tipo = 'email'
    and c.estado = 'pendente'
    and c.expira_em >= now()
    and lower(c.email) = lower(public.email_autenticado())
  order by c.created_at desc
$$;

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

- [ ] **Step 2: Escrever os testes SQL**

`supabase/tests/convites_email_tests.sql`:

```sql
-- ============================================================================
-- convites_email_tests.sql — RPCs de convite por e-mail (doc 08 §4, RF-13, F32)
-- Casos:
--   CE-01: meus_convites_pendentes() devolve só o convite do meu e-mail.
--   CE-02: recusar_convite(id) revoga só o meu; o alheio → CONVITE_INVALIDO.
--   CE-03: convite expirado não aparece.
-- Transação com ROLLBACK final.
-- ============================================================================

begin;

insert into auth.users (id, email, encrypted_password, aud, role, email_confirmed_at, instance_id, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token, recovery_token, email_change, email_change_token_new, email_change_token_current)
values
  ('a0000000-0000-0000-0000-000000000000', 'dono@test.com', 'x', 'authenticated', 'authenticated', now(), '00000000-0000-0000-0000-000000000000', '{}', '{}', now(), now(), '', '', '', '', ''),
  ('a1000000-0000-0000-0000-000000000000', 'convidado@test.com', 'x', 'authenticated', 'authenticated', now(), '00000000-0000-0000-0000-000000000000', '{}', '{}', now(), now(), '', '', '', '', ''),
  ('a2000000-0000-0000-0000-000000000000', 'outro@test.com', 'x', 'authenticated', 'authenticated', now(), '00000000-0000-0000-0000-000000000000', '{}', '{}', now(), now(), '', '', '', '', '')
on conflict (id) do nothing;

insert into public.listas (id, titulo, dono_id)
values ('a9000000-0000-0000-0000-000000000000', 'Compras da Semana', 'a0000000-0000-0000-0000-000000000000');

insert into public.convites (lista_id, criado_por, token, tipo, email, papel_oferecido, expira_em)
values
  ('a9000000-0000-0000-0000-000000000000', 'a0000000-0000-0000-0000-000000000000', 'b1111111-1111-1111-1111-111111111111', 'email', 'convidado@test.com', 'editor', now() + interval '7 days'),
  ('a9000000-0000-0000-0000-000000000000', 'a0000000-0000-0000-0000-000000000000', 'b2222222-2222-2222-2222-222222222222', 'email', 'convidado@test.com', 'leitor', now() - interval '1 day');

-- ===== CE-01: convidado vê só o pendente não expirado =====
do $$
declare v_qtd int; v_titulo text; v_token uuid;
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{"sub":"a1000000-0000-0000-0000-000000000000","role":"authenticated"}', true);
  select count(*), max(lista_titulo), max(token) into v_qtd, v_titulo, v_token from public.meus_convites_pendentes();
  perform set_config('role', 'postgres', true);
  if v_qtd <> 1 then raise exception 'FALHOU CE-01: % linhas', v_qtd; end if;
  if v_titulo <> 'Compras da Semana' then raise exception 'FALHOU CE-01: titulo %', v_titulo; end if;
  if v_token is null then raise exception 'FALHOU CE-01: token nulo'; end if;
  raise notice 'OK CE-01: convidado ve o proprio convite (com titulo e token)';
end $$;

-- ===== CE-03: outro e-mail não vê nada =====
do $$
declare v_qtd int;
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{"sub":"a2000000-0000-0000-0000-000000000000","role":"authenticated"}', true);
  select count(*) into v_qtd from public.meus_convites_pendentes();
  perform set_config('role', 'postgres', true);
  if v_qtd <> 0 then raise exception 'FALHOU CE-03: % linhas alheias', v_qtd; end if;
  raise notice 'OK CE-03: outro e-mail nao ve convites';
end $$;

-- ===== CE-02: recusar o próprio; recusar alheio falha =====
do $$
declare v_msg text;
begin
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', '{"sub":"a1000000-0000-0000-0000-000000000000","role":"authenticated"}', true);
  perform public.recusar_convite('b1111111-1111-1111-1111-111111111111');
  begin
    perform public.recusar_convite('b2222222-2222-2222-2222-222222222222');
    perform set_config('role', 'postgres', true);
    raise exception 'FALHOU CE-02: recusou convite expirado/alheio';
  exception when others then
    get stacked diagnostics v_msg = message_text;
    perform set_config('role', 'postgres', true);
    if v_msg not like '%CONVITE_INVALIDO%' then
      raise exception 'FALHOU CE-02: erro inesperado %', v_msg;
    end if;
  end;
  if (select estado from public.convites where token = 'b1111111-1111-1111-1111-111111111111') <> 'revogado' then
    raise exception 'FALHOU CE-02: nao revogou o proprio';
  end if;
  raise notice 'OK CE-02: recusa o proprio e rejeita o alheio/expirado';
end $$;

rollback;
```

- [ ] **Step 3: Rodar `db reset` e o script**

Run:
```powershell
supabase db reset
Get-Content supabase/tests/convites_email_tests.sql -Raw | docker exec -i supabase_db_ListaCompras psql -U postgres -d postgres -v ON_ERROR_STOP=1
```
Expected: `OK CE-01`, `OK CE-03`, `OK CE-02` e `ROLLBACK`; nenhum `FALHOU`.

- [ ] **Step 4: CI e doc 07**

Em `.github/workflows/ci.yml`, após o step de `arquivar_listas_tests`:

```yaml
      - name: Testes de convite por e-mail (08 §4)
        run: psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" -v ON_ERROR_STOP=1 -f supabase/tests/convites_email_tests.sql
```

E no esqueleto do `docs/07-qualidade-ci.md` §3, após a linha do `arquivar_listas_tests.sql`:

```
      - run: psql "$DB" -v ON_ERROR_STOP=1 -f supabase/tests/convites_email_tests.sql
```

- [ ] **Step 5: Gate Flutter e commit**

Run: `dart format . && flutter analyze && flutter test`
Expected: verde.

```bash
git add supabase/migrations/0019_convites_email.sql supabase/tests/convites_email_tests.sql .github/workflows/ci.yml docs/07-qualidade-ci.md
git commit -m "F32-T01: RPCs de convite por e-mail e testes SQL (RF-13)"
```

---

### Task 2: Repositório — criar/reusar, listar e recusar

**Files:**
- Create: `lib/features/convites/domain/convite_pendente.dart`
- Modify: `lib/features/convites/data/convites_repository.dart`
- Modify: `test/features/convites/convites_repository_test.dart`

**Interfaces:**
- Consumes: RPCs (Task 1); `Convite`/`Papel`/`ErroConvite`.
- Produces: `ConvitePendente`; `criarConviteEmail({listaId,email,papel})`; `meusConvitesPendentes()`; `recusarConvite(id)`.

- [ ] **Step 1: Escrever os testes que falham**

Em `test/features/convites/convites_repository_test.dart`, acrescentar um grupo `convite_email` (reuse o `ServidorFake` e o padrão de montagem do arquivo):

```dart
  group('convite_email', () {
    ConvitesRepository repoCom(ServidorFake servidor) => ConvitesRepository(
      SupabaseClient(
        'http://127.0.0.1:54321',
        'test-key',
        httpClient: servidor,
      ),
    );

    test('deve_criar_convite_email_quando_nao_existe', () async {
      final servidor = ServidorFake((req) {
        if (req.method == 'GET' && req.url.path.contains('/convites')) {
          return (200, const <Object?>[]);
        }
        if (req.method == 'POST' && req.url.path.contains('/convites')) {
          return (200, {
            'id': 'c1',
            'lista_id': _listaId,
            'criado_por': 'U1',
            'token': 't1',
            'tipo': 'email',
            'email': 'a@b.com',
            'papel_oferecido': 'editor',
            'estado': 'pendente',
            'expira_em': '2026-09-28T12:00:00.000Z',
            'created_at': '2026-09-21T12:00:00.000Z',
            'atualizado_em': '2026-09-21T12:00:00.000Z',
          });
        }
        return (500, {'message': 'inesperada: ${req.url.path}'});
      });
      addTearDown(servidor.close);

      await repoCom(servidor).criarConviteEmail(
        listaId: _listaId,
        email: 'a@b.com',
        papel: Papel.editor,
      );

      final corpo =
          jsonDecode(servidor.corpoDe(servidor.pedidos.indexWhere((p) => p.method == 'POST')))
              as Map<String, Object?>;
      expect(corpo['tipo'], 'email');
      expect(corpo['email'], 'a@b.com');
      expect(corpo['papel_oferecido'], 'editor');
    });

    test('deve_reusar_convite_email_quando_ja_pendente', () async {
      var inseriu = false;
      final servidor = ServidorFake((req) {
        if (req.method == 'GET' && req.url.path.contains('/convites')) {
          return (200, [
            {
              'id': 'c1',
              'lista_id': _listaId,
              'criado_por': 'U1',
              'token': 't1',
              'tipo': 'email',
              'email': 'a@b.com',
              'papel_oferecido': 'editor',
              'estado': 'pendente',
              'expira_em': '2026-09-28T12:00:00.000Z',
              'created_at': '2026-09-21T12:00:00.000Z',
              'atualizado_em': '2026-09-21T12:00:00.000Z',
            },
          ]);
        }
        if (req.method == 'POST' && req.url.path.contains('/convites')) {
          inseriu = true;
          return (500, {'message': 'nao deveria inserir'});
        }
        return (200, const <Object?>[]);
      });
      addTearDown(servidor.close);

      final convite = await repoCom(servidor).criarConviteEmail(
        listaId: _listaId,
        email: 'A@B.com',
        papel: Papel.editor,
      );

      expect(inseriu, isFalse);
      expect(convite.id, 'c1');
    });

    test('deve_listar_meus_convites_pendentes', () async {
      final servidor = ServidorFake((req) {
        if (req.method == 'POST' &&
            req.url.path.contains('meus_convites_pendentes')) {
          return (200, [
            {
              'id': 'c1',
              'token': 't1',
              'lista_titulo': 'Compras',
              'papel_oferecido': 'editor',
              'expira_em': '2026-09-28T12:00:00.000Z',
            },
          ]);
        }
        return (500, {'message': 'inesperada: ${req.url.path}'});
      });
      addTearDown(servidor.close);

      final pendentes = await repoCom(servidor).meusConvitesPendentes();

      expect(pendentes, hasLength(1));
      expect(pendentes.single.listaTitulo, 'Compras');
      expect(pendentes.single.token, 't1');
    });

    test('deve_recusar_convite', () async {
      final servidor = ServidorFake((req) {
        if (req.method == 'POST' && req.url.path.contains('recusar_convite')) {
          return (200, null);
        }
        return (500, {'message': 'inesperada: ${req.url.path}'});
      });
      addTearDown(servidor.close);

      await repoCom(servidor).recusarConvite('c1');

      final corpo =
          jsonDecode(servidor.corpoDe(0)) as Map<String, Object?>;
      expect(corpo['p_id'], 'c1');
    });

    test('deve_mapear_convite_invalido_quando_recusar_falha', () async {
      final servidor = ServidorFake((req) {
        if (req.method == 'POST' && req.url.path.contains('recusar_convite')) {
          return (
            400,
            {
              'code': 'P0001',
              'message': 'CONVITE_INVALIDO',
              'details': null,
              'hint': null,
            },
          );
        }
        return (500, {'message': 'inesperada: ${req.url.path}'});
      });
      addTearDown(servidor.close);

      await expectLater(
        repoCom(servidor).recusarConvite('c1'),
        throwsA(
          isA<ErroConvite>().having(
            (e) => e.message,
            'message',
            AppStrings.conviteInvalido,
          ),
        ),
      );
    });
  });
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/features/convites/convites_repository_test.dart`
Expected: FAIL na compilação — `The method 'criarConviteEmail' isn't defined` e `Member not found: 'ConvitePendente'`.

- [ ] **Step 3: Implementar**

`lib/features/convites/domain/convite_pendente.dart`:

```dart
import 'papel.dart';

/// Convite por e-mail pendente dirigido ao usuário (RF-13, fluxo B, F32).
class ConvitePendente {
  const ConvitePendente({
    required this.id,
    required this.token,
    required this.listaTitulo,
    required this.papelOferecido,
    required this.expiraEm,
  });

  factory ConvitePendente.fromMap(Map<String, Object?> mapa) => ConvitePendente(
    id: mapa['id'] as String,
    token: mapa['token'] as String,
    listaTitulo: mapa['lista_titulo'] as String,
    papelOferecido: Papel.fromValor(mapa['papel_oferecido'] as String),
    expiraEm: DateTime.parse(mapa['expira_em'] as String),
  );

  final String id;
  final String token;
  final String listaTitulo;
  final Papel papelOferecido;
  final DateTime expiraEm;
}
```

Em `lib/features/convites/data/convites_repository.dart`, adicionar (após `criarLink`):

```dart
  /// Cria um convite por e-mail (doc 08 §4): reusa um convite pendente do
  /// mesmo e-mail nesta lista (doc 08 §2) ou insere um novo. Online-only.
  Future<Convite> criarConviteEmail({
    required String listaId,
    required String email,
    required Papel papel,
  }) async {
    try {
      final linhas = await _client
          .from('convites')
          .select()
          .eq('lista_id', listaId)
          .eq('tipo', 'email')
          .eq('estado', 'pendente');
      final alvo = email.trim().toLowerCase();
      for (final linha in linhas as List) {
        final mapa = Map<String, Object?>.from(linha as Map);
        final existente = (mapa['email'] as String?)?.toLowerCase();
        if (existente == alvo) {
          final atual = Convite.fromMap(mapa);
          if (atual.papelOferecido != papel) {
            await _client
                .from('convites')
                .update({'papel_oferecido': papel.valor})
                .eq('id', atual.id);
            return Convite.fromMap({
              ...mapa,
              'papel_oferecido': papel.valor,
            });
          }
          return atual;
        }
      }
      final criadoPor = _client.auth.currentUser?.id;
      final conteudo = {
        'lista_id': listaId,
        'tipo': 'email',
        'email': email.trim(),
        'papel_oferecido': papel.valor,
      };
      if (criadoPor != null) conteudo['criado_por'] = criadoPor;
      final nova = await _client
          .from('convites')
          .insert(conteudo)
          .select()
          .single();
      return Convite.fromMap(Map<String, Object?>.from(nova as Map));
    } on PostgrestException catch (e) {
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

  /// Meus convites por e-mail pendentes (RPC `meus_convites_pendentes`).
  Future<List<ConvitePendente>> meusConvitesPendentes() async {
    final linhas = await _client.rpc('meus_convites_pendentes');
    return [
      for (final linha in linhas as List)
        ConvitePendente.fromMap(Map<String, Object?>.from(linha as Map)),
    ];
  }

  /// Recusa o próprio convite por e-mail (RPC `recusar_convite`).
  Future<void> recusarConvite(String id) async {
    try {
      await _client.rpc('recusar_convite', params: {'p_id': id});
    } on PostgrestException catch (e) {
      throw ErroConvite.fromCodigoDoContrato(e.message);
    } catch (e) {
      if (ehSemConexao(e)) {
        throw const ErroConvite('sem_conexao', AppStrings.erroSemConexao);
      }
      rethrow;
    }
  }
```

(import de `convite_pendente.dart`.)

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/features/convites/convites_repository_test.dart`
Expected: PASS.

- [ ] **Step 5: Gate e commit**

Run: `dart format . && flutter analyze && flutter test`
Expected: verde.

```bash
git add lib/features/convites/domain/convite_pendente.dart lib/features/convites/data/convites_repository.dart test/features/convites/convites_repository_test.dart
git commit -m "F32-T02: repositorio de convite por e-mail (RF-13)"
```

---

### Task 3: UI — e-mail no sheet "Convidar" e painel de pendentes

**Files:**
- Modify: `lib/core/l10n/app_strings.dart`
- Modify: `lib/features/convites/ui/sheet_convidar.dart`
- Create: `lib/features/convites/ui/convites_pendentes_secao.dart`
- Modify: `lib/features/listas/ui/painel_listas.dart` (seção)
- Modify: `test/features/convites/sheet_convidar_test.dart`
- Create: `test/features/convites/convites_pendentes_secao_test.dart`

**Interfaces:**
- Consumes: `criarConviteEmail`, `meusConvitesPendentes`, `recusarConvite`, `aceitar`, `ConvitePendente`.
- Produces: provider `meusConvitesPendentesProvider`; strings novas; seção de pendentes.

- [ ] **Step 1: Strings**

Em `lib/core/l10n/app_strings.dart`:

```dart
  static const convidarPorEmail = 'Convidar por e-mail';
  static const emailDoConvidado = 'E-mail do convidado';
  static const enviarConvite = 'Enviar convite';
  static const conviteCriado =
      'Convite criado. A pessoa verá no app ao entrar.';
  static const convitesPendentes = 'Convites pendentes';
  static const aceitar = 'Aceitar';
  static const recusar = 'Recusar';

  static String convitePara(String titulo) => 'Convite para $titulo';
```

- [ ] **Step 2: Provider e seção de pendentes**

`lib/features/convites/ui/convites_pendentes_secao.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/tokens/app_spacing.dart';
import '../../../core/widgets/app_botao.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../domain/convite.dart';
import '../domain/convite_pendente.dart';
import '../providers/convites_providers.dart';

/// Meus convites por e-mail pendentes (RF-13, fluxo B, F32).
final meusConvitesPendentesProvider = FutureProvider<List<ConvitePendente>>(
  (ref) => ref.watch(convitesRepositoryProvider).meusConvitesPendentes(),
);

/// Seção "Convites pendentes" no topo do painel Minhas Listas.
class ConvitesPendentesSecao extends ConsumerWidget {
  const ConvitesPendentesSecao({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendentes = ref.watch(meusConvitesPendentesProvider).value ?? const [];
    if (pendentes.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            0,
          ),
          child: Text(
            AppStrings.convitesPendentes,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        for (final convite in pendentes)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              0,
            ),
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppStrings.convitePara(convite.listaTitulo)),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: AppBotao(
                          rotulo: AppStrings.aceitar,
                          expandido: false,
                          onPressed: () => _aceitar(context, ref, convite),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: AppBotao(
                          rotulo: AppStrings.recusar,
                          variante: AppBotaoVariante.outlined,
                          expandido: false,
                          onPressed: () => _recusar(context, ref, convite),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _aceitar(
    BuildContext context,
    WidgetRef ref,
    ConvitePendente convite,
  ) async {
    try {
      final listaId = await ref
          .read(convitesRepositoryProvider)
          .aceitar(convite.token);
      if (context.mounted) context.push('/lista/$listaId');
    } on ErroConvite catch (e) {
      if (context.mounted) mostrarSnackBar(context, e.message);
    } catch (_) {
      if (context.mounted) mostrarSnackBar(context, AppStrings.erroGenerico);
    }
  }

  Future<void> _recusar(
    BuildContext context,
    WidgetRef ref,
    ConvitePendente convite,
  ) async {
    try {
      await ref.read(convitesRepositoryProvider).recusarConvite(convite.id);
      ref.invalidate(meusConvitesPendentesProvider);
    } on ErroConvite catch (e) {
      if (context.mounted) mostrarSnackBar(context, e.message);
    } catch (_) {
      if (context.mounted) mostrarSnackBar(context, AppStrings.erroGenerico);
    }
  }
}
```

> Confira os parâmetros reais de `AppCard` e `AppBotao` (variante/`expandido`) no design system; ajuste se necessário.

- [ ] **Step 3: Sheet "Convidar" com e-mail**

Em `lib/features/convites/ui/sheet_convidar.dart`, adicionar ao `_SheetConvidarState`:
- `final _email = TextEditingController();`, `bool _enviandoEmail = false;`, `String? _erroEmail;`
- `dispose` libera `_email`.
- Método:
  ```dart
  Future<void> _enviarConviteEmail() async {
    final email = _email.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() => _erroEmail = AppStrings.erroEmailInvalido);
      return;
    }
    setState(() { _erroEmail = null; _enviandoEmail = true; });
    try {
      await ref.read(convitesRepositoryProvider).criarConviteEmail(
        listaId: widget.listaId, email: email, papel: _papel,
      );
      if (mounted) {
        mostrarSnackBar(context, AppStrings.conviteCriado);
        _email.clear();
      }
    } on ErroConvite catch (e) {
      if (mounted) setState(() => _erroEmail = e.message);
    } catch (_) {
      if (mounted) setState(() => _erroEmail = AppStrings.erroGenerico);
    }
    if (mounted) setState(() => _enviandoEmail = false);
  }
  ```
- No `build`, no ramo `convite == null`, **abaixo** do bloco de link, uma seção "Convidar por e-mail": `AppCampoTexto(controller: _email, label: AppStrings.emailDoConvidado, erro: _erroEmail, teclado: TextInputType.emailAddress)` + `AppBotao(rotulo: AppStrings.enviarConvite, variante: outlined, carregando: _enviandoEmail, onPressed: _enviarConviteEmail)`.

- [ ] **Step 4: Ligar a seção no painel**

Em `lib/features/listas/ui/painel_listas.dart`, no `build` do `PainelListas`, no corpo, **acima** da lista (dentro do `Column`, antes do `Expanded`), quando `!widget._compartilhadas`:

```dart
          if (!_compartilhadas) const ConvitesPendentesSecao(),
```

(import de `../../convites/ui/convites_pendentes_secao.dart`.)

- [ ] **Step 5: Escrever os testes de widget**

Em `test/features/convites/sheet_convidar_test.dart`, acrescentar (reuse o harness `abrir`/`ServidorFake` do arquivo):

```dart
  testWidgets('deve_criar_convite_email_quando_email_valido', (tester) async {
    final servidor = ServidorFake((req) {
      if (req.method == 'GET' && req.url.path.contains('/convites')) {
        return (200, const <Object?>[]);
      }
      if (req.method == 'POST' && req.url.path.contains('/convites')) {
        return (200, _linhaConvite(papel: 'editor')); // ajuste: tipo email
      }
      return (500, {'message': 'inesperada: ${req.url.path}'});
    });
    addTearDown(servidor.close);
    await abrir(tester, servidor);

    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.emailDoConvidado),
      'a@b.com',
    );
    await tester.tap(
      find.widgetWithText(OutlinedButton, AppStrings.enviarConvite),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.conviteCriado), findsOneWidget);
    await fechar(tester);
  });

  testWidgets('deve_validar_email_quando_invalido', (tester) async {
    final servidor = ServidorFake((req) => (500, {'message': 'nao deveria chamar'}));
    addTearDown(servidor.close);
    await abrir(tester, servidor);

    await tester.enterText(
      find.widgetWithText(TextField, AppStrings.emailDoConvidado),
      'invalido',
    );
    await tester.tap(
      find.widgetWithText(OutlinedButton, AppStrings.enviarConvite),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.erroEmailInvalido), findsOneWidget);
    await fechar(tester);
  });
```

> `_linhaConvite` do arquivo devolve um convite de link; ajuste o helper para aceitar `tipo`/`email` (ou crie uma linha de e-mail) — o importante é o POST com `tipo: 'email'`.

`test/features/convites/convites_pendentes_secao_test.dart` (novo):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lista_compras/core/l10n/app_strings.dart';
import 'package:lista_compras/features/convites/data/convites_repository.dart';
import 'package:lista_compras/features/convites/providers/convites_providers.dart';
import 'package:lista_compras/features/convites/ui/convites_pendentes_secao.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'servidor_fake.dart';

void main() {
  testWidgets('deve_mostrar_convite_pendente_quando_ha', (tester) async {
    final servidor = ServidorFake((req) {
      if (req.method == 'POST' &&
          req.url.path.contains('meus_convites_pendentes')) {
        return (200, [
          {
            'id': 'c1',
            'token': 't1',
            'lista_titulo': 'Compras',
            'papel_oferecido': 'editor',
            'expira_em': '2026-09-28T12:00:00.000Z',
          },
        ]);
      }
      return (500, {'message': 'inesperada: ${req.url.path}'});
    });
    addTearDown(servidor.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          convitesRepositoryProvider.overrideWithValue(
            ConvitesRepository(
              SupabaseClient(
                'http://127.0.0.1:54321',
                'test-key',
                httpClient: servidor,
              ),
            ),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: ConvitesPendentesSecao()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.convitesPendentes), findsOneWidget);
    expect(find.text(AppStrings.convitePara('Compras')), findsOneWidget);
    expect(find.text(AppStrings.aceitar), findsOneWidget);
    expect(find.text(AppStrings.recusar), findsOneWidget);
  });

  testWidgets('nao_deve_mostrar_secao_quando_sem_pendentes', (tester) async {
    final servidor = ServidorFake((req) {
      if (req.method == 'POST' &&
          req.url.path.contains('meus_convites_pendentes')) {
        return (200, const <Object?>[]);
      }
      return (500, {'message': 'inesperada: ${req.url.path}'});
    });
    addTearDown(servidor.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          convitesRepositoryProvider.overrideWithValue(
            ConvitesRepository(
              SupabaseClient(
                'http://127.0.0.1:54321',
                'test-key',
                httpClient: servidor,
              ),
            ),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: ConvitesPendentesSecao()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.convitesPendentes), findsNothing);
  });
}
```

- [ ] **Step 6: Rodar e ver passar**

Run: `flutter test test/features/convites/sheet_convidar_test.dart test/features/convites/convites_pendentes_secao_test.dart`
Expected: PASS.

- [ ] **Step 7: Gate e commit**

Run: `dart format . && flutter analyze && flutter test`
Expected: verde.

```bash
git add lib/core/l10n/app_strings.dart lib/features/convites/ui/sheet_convidar.dart lib/features/convites/ui/convites_pendentes_secao.dart lib/features/listas/ui/painel_listas.dart test/features/convites/sheet_convidar_test.dart test/features/convites/convites_pendentes_secao_test.dart
git commit -m "F32-T03: email no sheet convidar e painel de pendentes (RF-13)"
```

---

### Task 4: Docs donos e fechamento da Fase 32

**Files:**
- Modify: `docs/01-banco-de-dados.md`, `docs/02-seguranca-rls.md`, `docs/08-compartilhamento-colaborativo.md` (§4), `docs/05-app-flutter.md`, `docs/10-wireframes-telas.md`, `docs/12-prd.md`, `docs/14-tarefas.md`, `docs/16-roadmap-pos-mvp.md`

- [ ] **Step 1: Docs 01/02/08**
  - `01`: registrar as RPCs `meus_convites_pendentes`/`recusar_convite` (migration `0019`) e a árvore de migrations.
  - `02 §4.4/§5`: documentar os RPCs `security definer` + grants (`authenticated`), e citar `convites_email_tests.sql` em §5.
  - `08 §4`: fluxo B **entregue** (criar por e-mail + painel + aceitar/recusar); envio de e-mail segue adiado; remover "o app ainda não as usa" da §1.1.

- [ ] **Step 2: Docs 05/10**
  - `05 §6.2`: painel "Convites pendentes" no Minhas Listas (cards `Convite para <título>`, aceitar/recusar); §6.3/sheet: campo de e-mail + "Enviar convite".
  - `10`: wireframe/nota do painel de pendentes e do campo de e-mail no sheet.

- [ ] **Step 3: Doc 12 e 16**
  - `12 §2`: RF-13 passa a refletir o fluxo B entregue; §6 rastreabilidade `RF-13 | US-05 | F32 | F32-T01…T03 | SQL CE + repo + widgets`.
  - `16`: Onda B linha B2 → `concluído (F32-T01…T04)`.

- [ ] **Step 4: Doc 14 (Fase 32 + progresso)**
  - Fase 32 com F32-T01…T04 `[x]` + CPs; tabela `| F32 Convite por e-mail | 4 | 4 |` e total `| **Total** | **171** | **169** |`.

- [ ] **Step 5: Gate e commit**

Run: `dart format . && flutter analyze && flutter test`
Expected: verde.

```bash
git add docs/01-banco-de-dados.md docs/02-seguranca-rls.md docs/08-compartilhamento-colaborativo.md docs/05-app-flutter.md docs/10-wireframes-telas.md docs/12-prd.md docs/14-tarefas.md docs/16-roadmap-pos-mvp.md
git commit -m "F32-T04: docs donos e fechamento da Fase 32 (RF-13)"
```

---

## Self-review (preenchido pelo autor do plano)

- **Cobertura do spec:** §3 banco → Task 1; §4 repositório → Task 2; §5 UI → Task 3; §6 token na RPC → Task 1; §7 testes → Tasks 1–3; §8 docs → Task 4.
- **Placeholders:** nenhum "TBD"; todo o código novo está completo. Os testes de widget reusam os harnesses reais (o implementador ajusta `_linhaConvite` para e-mail).
- **Consistência de tipos:** `ConvitePendente`, `criarConviteEmail({listaId,email,papel})`, `meusConvitesPendentes()`, `recusarConvite(id)`, `meusConvitesPendentesProvider`, `ConvitesPendentesSecao`, strings; progresso 171/169 — idênticos entre tarefas.
- **YAGNI:** sem envio de e-mail, sem push, sem nome do convidante.
