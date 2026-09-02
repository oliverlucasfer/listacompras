# 13 — Pré-modelo Técnico (Contexto Condensado)

> Navegação: [← 12 PRD](12-prd.md) · [14 Tarefas →](14-tarefas.md)

**Leia este arquivo ANTES de implementar qualquer coisa.** É o modelo técnico condensado — uma leitura única dá o contexto completo. Cada seção aponta o **doc dono** com o detalhe normativo; este arquivo nunca sobrepõe o dono.

---

## 1. Regras para o agente/implementador

1. **Ordem de leitura:** este arquivo → [14 Tarefas](14-tarefas.md) → **doc dono** da tarefa → código.
2. **Doc dono é autoridade:** se este resumo divergir do doc dono, vale o doc dono.
3. **Proibido alterar comportamento** documentado (schema, sync, RLS, contrato de IA) **sem atualizar o doc dono no mesmo PR**.
4. Requisitos têm ID (`RF-xx`, [12 §2](12-prd.md)) — mencione o ID no commit/PR.
5. Toda tarefa tem critério de pronto em [14](14-tarefas.md) — não marque concluído sem ele.
6. Nenhuma chave/segredo em código; CI verde obrigatório ([07](07-qualidade-ci.md)).

## 2. Stack (uma leitura)

| Camada | Tecnologia | Papel |
| :--- | :--- | :--- |
| App | Flutter + Riverpod + go_router | UI reativa; UI nunca bloqueia em rede |
| Cache local | Drift/SQLite | **Fonte de verdade local**; leitura via Streams |
| Backend | Supabase (Postgres, Auth, Realtime, Edge Functions, RLS) | Persistência, sync, IA intermediada |
| IA | Gemini 2.0 Flash, JSON mode | Extrai itens de texto livre |
| Ops | GitHub Actions + Sentry | CI obrigatório; erros sem conteúdo de listas |

## 3. Entidades e relacionamentos

```
auth.users 1───N lista_membros N───1 listas 1───N itens_lista
                                   │
                                   └───N convites (Fase 6)
App local (Drift): ListaLocal, ItemLocal, MutacaoPendente (fila)
```

**Campos-chave (mínimo para raciocinar):**

| Entidade | Campos essenciais | Detalhe |
| :--- | :--- | :--- |
| `listas` | id (uuid, cliente), titulo, dono_id, updated_at, deletado_em | [01 §4.1](01-banco-de-dados.md) |
| `itens_lista` | id (uuid, cliente), lista_id, nome, quantidade>0, unidade (enum), concluido, ordem, updated_at, deletado_em | unique parcial `(lista_id, lower(nome))` ativos |
| `lista_membros` | lista_id, user_id, papel ∈ {dono, editor, leitor} | **1 dono por lista** (trigger `sync_dono`) |
| `convites` (F6) | token, tipo link/email, papel_oferecido ≠ dono, estado, expira_em | [08 §2](08-compartilhamento-colaborativo.md) |
| `mutacoes_pendentes` (local) | tabela, operacao, registro_id, payload JSON, ts_local, tentativas | [03 §3](03-sincronizacao-offline.md) |

**Enum de unidades (fechado):** `un, kg, g, l, ml, caixa, pacote, pct, dz` — mesma lista no Postgres, no Dart e no `responseSchema` do Gemini.

## 4. Fluxos essenciais

### F1 — Escrita (sempre igual, online ou offline)
UI → Repositório → **Drift aplica + enfileira mutação** → (online?) flush. Leitura: Stream do Drift → UI. [03 §2](03-sincronizacao-offline.md)

### F2 — Flush da fila
Drena por lista, em ordem; **coalescing** (múltiplas mutações do mesmo registro = envia só a última); upsert com comparação **LWW por `updated_at`**; empate → servidor; retry exponencial (máx 10 → estado `Erro` na UI). [03 §4–5](03-sincronizacao-offline.md)

### F3 — Importação IA
App → `POST /functions/v1/parse-lista` (JWT) → rate limit 10/min + ≤2000 chars → Gemini (JSON mode, temp 0.1, timeout 15s) → `{itens:[{nome,quantidade,unidade}], aviso}` → **pré-visualização editável** → grava local. Erros amigáveis por código ([04 §2](04-ia-edge-function.md)).

### F4 — Realtime
WebSocket Supabase → mudanças remotas → aplicar no Drift **se vencerem LWW** → Stream notifica UI (< 1s). RLS filtra o que cada usuário recebe. [03 §4](03-sincronizacao-offline.md)

### F5 — Exclusão de conta
Configurações → confirmação dupla → RPC `excluir_conta()` → `delete from auth.users` → CASCADEs apagam tudo → app limpa cache/fila. [06 §3.3.1](06-mvp-entregas.md)

## 5. Contratos rápidos

**Edge Function (resumo — [04 §2](04-ia-edge-function.md)):**
```
POST parse-lista  Authorization: Bearer <jwt>  { "texto": "..." }
200 → { "itens": [...], "aviso": null }
4xx/5xx → { code: unauthorized|texto_vazio|texto_longo|resposta_invalida|rate_limit|cota_ia|timeout_ia|erro_interno }
```

**Estados de sync (UI):** `Sincronizado → Pendente(n) → Sincronizando → Sincronizado | Offline | Erro` ([03 §6](03-sincronizacao-offline.md)).

**Papéis:** `dono` > `editor` (escreve) > `leitor` (só lê). Policies: [02 §4](02-seguranca-rls.md) · Matrix [02 §3](02-seguranca-rls.md).

## 6. Decisões vinculantes (ADR — 1 linha cada, detalhe em [00 §5](00-visao-geral.md))

| ADR | Decisão |
| :--- | :--- |
| 001 | MVP = Android/iOS/Web; Desktop F6 |
| 002 | Riverpod |
| 003 | Drift/SQLite local |
| 004 | LWW + tombstones (sem modal de conflito) |
| 005 | Enum fechado de unidades |
| 006 | IDs UUID v4 gerados no cliente |
| 007 | Free tier aceito; Supabase Pro = gatilho de lançamento público |
| 008 | Exclusão de conta: delete físico em cascata (F5) |
| 009 | Sentry free |
| 010 | GitHub Actions desde a F1 |

## 7. Comandos essenciais

```bash
flutter test                          # testes (obrigatório verde)
dart format . && flutter analyze      # estilo e lint
supabase db reset                     # aplica migrations local
supabase db push                      # aplica em produção
supabase functions deploy parse-lista # deploy Edge Function
```

---

## Documentos relacionados
- [12 PRD](12-prd.md) — requisitos com IDs
- [14 Tarefas](14-tarefas.md) — o que fazer, em ordem
- [AGENTS.md](../AGENTS.md) — instruções operacionais para agentes
