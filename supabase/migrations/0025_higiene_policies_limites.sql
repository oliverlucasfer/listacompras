-- 0025_higiene_policies_limites.sql — higiene de policies, limites e
-- `search_path` dos definers (G-23, G-26, G-27, G-29, G-30 — F43-T08).
-- Docs donos: 01 §2/§4.3/§4.5/§6/§7, 02 §1/§3/§4.3/§4.4/§4.8/§5.
--
-- G-26: `membros_update_papel_dono` (0009) permitia trocar `user_id`/`lista_id`
--       da linha, não só `papel`. O WITH CHECK passa a comparar as duas colunas
--       com a snapshot antiga da própria linha.
-- G-27: `convites_insert_dono` (0007) não restringia `estado`/`expira_em` — dava
--       para inserir convite já aceito ou sem expiração. O WITH CHECK exige
--       `estado = 'pendente'` e `expira_em > now()`, mantendo as demais cláusulas.
-- G-29: CHECK de tamanho em `push_tokens.token` (1..4096) e teto superior de
--       `itens_lista.quantidade` (<= 1000000); espelho no Drift (schemaVersion 9).
-- G-23: recria cada definer com `set search_path = ''` e identificadores
--       qualificados (`public.`, `auth.`, `vault.`, `net.`). Os corpos são
--       idênticos às versões vigentes (0002/0007/0011/0016/0018/0019/0021/0022/
--       0023/0024) — a auditoria confirmou que não havia referência não
--       qualificável, então não foi preciso isolar a G-23.
-- G-30 é coberto pelas suítes de teste (sem DDL).

-- ============================================================================
-- G-26 — UPDATE de lista_membros: só `papel` muda
-- ============================================================================
drop policy "membros_update_papel_dono" on public.lista_membros;

create policy "membros_update_papel_dono"
  on public.lista_membros for update
  using (
    public.is_dono_de(lista_id)
    and user_id <> auth.uid()
  )
  with check (
    public.is_dono_de(lista_id)
    and user_id <> auth.uid()
    and papel in ('editor', 'leitor')
    -- `user_id` e `lista_id` são imutáveis via UPDATE: a subquery lê a snapshot
    -- antiga da própria linha e qualquer tentativa de troca falha o WITH CHECK.
    and user_id = (
      select m.user_id from public.lista_membros m where m.id = lista_membros.id
    )
    and lista_id = (
      select m.lista_id from public.lista_membros m where m.id = lista_membros.id
    )
  );

-- ============================================================================
-- G-27 — INSERT de convite pelo dono: só pendente e não expirado
-- ============================================================================
drop policy "convites_insert_dono" on public.convites;

create policy "convites_insert_dono"
  on public.convites for insert
  with check (
    criado_por = auth.uid()
    and estado = 'pendente'
    and expira_em > now()
    and exists (
      select 1 from public.lista_membros m
      where m.lista_id = convites.lista_id
        and m.user_id = auth.uid()
        and m.papel = 'dono'
    )
  );

-- ============================================================================
-- G-29 — limites de tamanho (push_tokens.token e itens_lista.quantidade)
-- ============================================================================
alter table public.push_tokens
  add constraint push_tokens_token_tamanho
  check (char_length(token) between 1 and 4096) not valid;

alter table public.itens_lista
  add constraint itens_lista_quantidade_teto
  check (quantidade <= 1000000) not valid;

-- ============================================================================
-- G-23 — definers com `search_path = ''` e identificadores qualificados
-- ============================================================================

-- 02 §1 — is_member
create or replace function public.is_member(lista uuid)
returns boolean
language sql
security definer
set search_path = ''
stable
as $$
  select exists (
    select 1 from public.lista_membros lm
    where lm.lista_id = lista
      and lm.user_id = auth.uid()
  );
$$;

-- 02 §1 — papel_na_lista
create or replace function public.papel_na_lista(lista uuid)
returns text
language sql
security definer
set search_path = ''
stable
as $$
  select lm.papel
  from public.lista_membros lm
  where lm.lista_id = lista
    and lm.user_id = auth.uid()
$$;

-- 02 §1 — is_dono_de
create or replace function public.is_dono_de(lista uuid)
returns boolean
language sql
security definer
set search_path = ''
stable
as $$
  select exists (
    select 1 from public.listas l
    where l.id = lista
      and l.dono_id = auth.uid()
  );
$$;

-- 02 §1 / 08 §2 — email_autenticado
create or replace function public.email_autenticado()
returns text
language sql
security definer
set search_path = ''
stable
as $$
  select u.email from auth.users u where u.id = auth.uid()
$$;

-- 01 §6 / 02 §4.3 — criar_membro_dono (trigger de associação do dono)
create or replace function public.criar_membro_dono()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.lista_membros (lista_id, user_id, papel)
  values (new.id, new.dono_id, 'dono')
  on conflict (lista_id, user_id) do nothing;
  return new;
end;
$$;

-- 01 §6 — sync_dono v3 (0016)
create or replace function public.sync_dono()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  qtd_donos int;
begin
  select count(*) into qtd_donos
  from public.lista_membros
  where lista_id = coalesce(new.lista_id, old.lista_id)
    and papel = 'dono';

  if tg_op = 'INSERT' or tg_op = 'UPDATE' then
    if qtd_donos > 1 then
      raise exception 'Lista já possui um dono';
    end if;

    if new.papel = 'dono' then
      update public.listas
      set dono_id = new.user_id
      where id = new.lista_id;
    end if;
  end if;

  if (tg_op = 'DELETE' and old.papel = 'dono')
     or (tg_op = 'UPDATE' and old.papel = 'dono' and new.papel <> 'dono') then
    if coalesce(current_setting('app.excluindo_conta', true), '') <> 'true'
       and coalesce(current_setting('app.transferindo_dono', true), '') <> 'true' then
      raise exception 'Transferência de dono deve ser processo explícito';
    end if;
  end if;

  return coalesce(new, old);
end;
$$;

-- 02 §4.6 / 08 §6 — transferir_dono (0016)
create or replace function public.transferir_dono(p_lista uuid, p_novo_dono uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  papel_novo text;
begin
  if auth.uid() is null then
    raise exception 'AUTENTICACAO_NECESSARIA';
  end if;

  if not exists (
    select 1 from public.listas
    where id = p_lista and dono_id = auth.uid()
  ) then
    raise exception 'APENAS_O_DONO_PODE_TRANSFERIR';
  end if;

  if p_novo_dono = auth.uid() then
    raise exception 'NAO_PODE_TRANSFERIR_PARA_SI';
  end if;

  select papel into papel_novo
  from public.lista_membros
  where lista_id = p_lista and user_id = p_novo_dono;
  if papel_novo is null then
    raise exception 'NOVO_DONO_PRECISA_SER_MEMBRO';
  end if;

  perform set_config('app.transferindo_dono', 'true', true);

  update public.lista_membros set papel = 'editor'
  where lista_id = p_lista and user_id = auth.uid();

  update public.lista_membros set papel = 'dono'
  where lista_id = p_lista and user_id = p_novo_dono;
end;
$$;

revoke execute on function public.transferir_dono(uuid, uuid) from public, anon;
grant execute on function public.transferir_dono(uuid, uuid) to authenticated;

-- 08 §3.1 — aceitar_convite (0024)
create or replace function public.aceitar_convite(p_token uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  c public.convites%rowtype;
  email_uid text;
begin
  if auth.uid() is null then
    raise exception 'CONVITE_INVALIDO';
  end if;

  select * into c from public.convites
  where token = p_token for update;

  if c.id is null or c.estado not in ('pendente', 'aceito') or c.expira_em < now() then
    raise exception 'CONVITE_INVALIDO';
  end if;

  if c.tipo = 'email' then
    select u.email into email_uid from auth.users u where u.id = auth.uid();
    if c.email is null or lower(c.email) <> lower(email_uid) then
      raise exception 'CONVITE_NAO_DIRIGIDO_A_VOCE';
    end if;
  end if;

  insert into public.lista_membros (lista_id, user_id, papel)
  values (c.lista_id, auth.uid(), c.papel_oferecido)
  on conflict (lista_id, user_id) do nothing;

  update public.convites set estado = 'aceito', atualizado_em = now()
  where id = c.id;

  return c.lista_id;
end;
$$;

revoke execute on function public.aceitar_convite(uuid) from public, anon;
grant execute on function public.aceitar_convite(uuid) to authenticated;

-- 02 §4.7 — meus_convites_pendentes (0019)
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
set search_path = ''
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

-- 02 §4.7 — recusar_convite (0019)
create or replace function public.recusar_convite(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
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

-- 02 §4.8 — registrar_push_token (0021)
create or replace function public.registrar_push_token(p_token text, p_plataforma text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'SEM_SESSAO';
  end if;
  delete from public.push_tokens where token = p_token and user_id <> auth.uid();
  insert into public.push_tokens (user_id, token, plataforma)
  values (auth.uid(), p_token, p_plataforma)
  on conflict (token) do update
    set user_id = auth.uid(),
        plataforma = excluded.plataforma,
        atualizado_em = now();
end;
$$;

revoke execute on function public.registrar_push_token(text, text) from public, anon;
grant execute on function public.registrar_push_token(text, text) to authenticated;

-- 01 §7 — notificar_push (0022)
create or replace function public.notificar_push()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_url text;
  v_segredo text;
  v_dest uuid;
  v_titulo text;
  v_corpo jsonb;
begin
  select decrypted_secret into v_url
  from vault.decrypted_secrets where name = 'push_function_url'
  order by created_at desc limit 1;
  select decrypted_secret into v_segredo
  from vault.decrypted_secrets where name = 'push_webhook_secret'
  order by created_at desc limit 1;
  if v_url is null or v_segredo is null then
    return new;
  end if;

  if tg_argv[0] = 'convite_email_criado' then
    select id into v_dest from auth.users
    where lower(email) = lower(new.email) limit 1;
    if v_dest is null or v_dest = new.criado_por then
      return new;
    end if;
    select titulo into v_titulo from public.listas where id = new.lista_id;
    v_corpo := jsonb_build_object(
      'evento', 'convite_email_criado',
      'destinatario_id', v_dest,
      'lista_id', new.lista_id,
      'token', new.token,
      'titulo_lista', v_titulo
    );
  else
    select dono_id, titulo into v_dest, v_titulo
    from public.listas where id = new.lista_id;
    if v_dest is null or v_dest = new.user_id then
      return new;
    end if;
    v_corpo := jsonb_build_object(
      'evento', 'membro_entrou',
      'destinatario_id', v_dest,
      'lista_id', new.lista_id,
      'titulo_lista', v_titulo
    );
  end if;

  perform net.http_post(
    url := v_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-webhook-secret', v_segredo
    ),
    body := v_corpo
  );
  return new;
end;
$$;

-- 01 §4.1 / 01 §6 — protege_arquivo_dono (0018)
create or replace function public.protege_arquivo_dono()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.arquivada_em is distinct from old.arquivada_em
     and old.dono_id <> auth.uid() then
    raise exception 'APENAS_O_DONO_PODE_ARQUIVAR';
  end if;
  return new;
end;
$$;

-- 01 §4.1 / 02 §4.1 — protege_deletado_em (0023)
create or replace function public.protege_deletado_em()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.deletado_em is distinct from old.deletado_em
     and old.dono_id <> auth.uid() then
    raise exception 'APENAS_O_DONO_PODE_EXCLUIR';
  end if;
  return new;
end;
$$;
