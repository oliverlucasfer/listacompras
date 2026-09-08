# Design: Agrupamento da Lista por Categoria (Fase 6)

> **Status:** aprovado pelo dono em 08/09/2026 (T00 — somente planejamento; implementação em F6-T01…T06 em [docs/14-tarefas.md](../../14-tarefas.md)).
> **Doc dono deste design:** este arquivo é a spec da feature; as regras normativas moram nos docs donos (01 schema, 03 sync, 04 IA, 05 app/UX, 10 layout, 12 PRD) — atualizados no PR de cada tarefa conforme o mapa em §9.

---

## 1. Problema e objetivo

Hoje a lista é uma sequência única ordenada por `ordem` (drag global, RF-05). No mercado, o comprador anda por setores (frios, congelados, mercearia…) e teria que voltar atrás na lista constantemente.

**Objetivo:** itens pendentes agrupados por **categoria**, com preenchimento automático que **não depende de IA** — o app deve ser 100% funcional para o cliente sem plano de IA.

**Não é objetivo (YAGNI):** categorias por usuário (texto livre), reordenação de grupos, subcategorias, agrupamento de concluídos.

## 2. Decisões

| # | Decisão | Alternativa rejeitada |
| :--- | :--- | :--- |
| D1 | Categoria **persistida** no item (sincroniza entre dispositivos) | Agrupamento heurístico só na UI |
| D2 | **Enum fechado** `categoria_item` com 11 valores (mesma filosofia do enum de unidades, ADR-005) | Texto livre |
| D3 | **IA sugere** categoria na importação (`responseSchema` + prompt); editável na pré-visualização | IA fora do fluxo |
| D4 | Grupos com **ordem fixa pela ordem do enum** | Ordem customizável |
| D5 | Drag-and-drop **apenas dentro do grupo**; mudar categoria via swipe → editar | Drag entre grupos |
| D6 | **Cadeia de sugestão em camadas**: memória por nome → dicionário estático local → `outros`; IA apenas refina o import | Sugestão só via IA; tabela de aprendizado sincronizada |
| D7 | Concluídos: **seção única dobrável**, sem categorias | Agrupados também |
| D8 | Item manual rápido (Enter) aplica a sugestão local na hora | Dropdown na adição rápida (atrito) |

## 3. Modelo de dados

### 3.1. Enum (fonte única: [01 §3](../../01-banco-de-dados.md))

```sql
create type public.categoria_item as enum (
  'hortifruti','mercearia','frios','laticinios','congelados',
  'padaria','bebidas','pet','limpeza','higiene','outros'
);
```

A **ordem do enum define a ordem dos grupos** na UI (D4). Labels pt-BR: Hortifrúti, Mercearia, Frios, Laticínios, Congelados, Padaria, Bebidas, Pet, Limpeza, Higiene, Outros.

### 3.2. Coluna (migration `0006_categorias.sql`)

```sql
alter table public.itens_lista
  add column categoria public.categoria_item not null default 'outros';
```

Migration **aditiva**: itens existentes passam a `outros` (nada se perde). Sem índice novo (o volume por lista não justifica; filtro por lista já usa `idx_itens_lista_ordem` + filtro na query).

### 3.3. Drift (schema v3, [05 §2](../../05-app-flutter.md))

`ItemLocal` ganha `categoria` (`text NOT NULL DEFAULT 'outros'`), mapeada ao enum Dart `CategoriaItem` (mesma ordem do enum Postgres — o índice define a ordem dos grupos). Migração local v2→v3.

## 4. Cadeia de sugestão (D6 — zero rede)

Função pura `sugerirCategoria(nome)` em `lib/core/categorias/`:

```
n = btrim(nome).toLowerCase()

1. Memória por nome (Drift):
   categoria do item ativo mais recente com lower(nome) = n
   (qualquer lista do usuário no dispositivo; ordena por updated_at DESC)
2. Dicionário estático:
   entrada multi-palavra casa antes da de uma palavra ("leite condensado" →
   mercearia antes de "leite" → laticinios); empate → ordem alfabética
3. Fallback: 'outros'
```

* **Memória > dicionário:** o usuário já classificou da forma dele; o dicionário cobre o primeiro contato.
* **Dicionário:** ~200–300 termos comuns pt-BR versionados no repo (`dicionario_categorias.dart`), match por palavra(s) do nome. Nomes não cobertos caem em `outros` e passam a ser lembrados (a cadeia "aprende" pelo uso, sem tabela nova).
* **IA:** não entra nesta cadeia — é refinamento do *import* (§5). O cliente sem plano de IA usa só as camadas locais.
* Multi-conta: a memória vive no cache local do usuário logado (limpo no logout/exclusão pelo bootstrap, F4-T06).

## 5. Contratos alterados

### 5.1. Payload de sync ([03 §3](../../03-sincronizacao-offline.md))

`INSERT`/`UPDATE` de `itens_lista` passam a incluir `"categoria"` no payload completo (snake_case), além de existing `nome/quantidade/unidade/ordem/concluido`. Coalescing, LWW e dedup **sem regra nova**: no merge de duplicado, o vencedor por `updated_at` traz a sua categoria.

### 5.2. Edge Function `parse-lista` ([04](../../04-ia-edge-function.md))

Resposta passa a:

```json
{ "itens": [ { "nome": "Arroz", "quantidade": 1, "unidade": "kg", "categoria": "mercearia" } ], "aviso": null }
```

* `responseSchema`: `categoria` com `enum` dos 11 valores, **required** — a IA não inventa categoria.
* Prompt: regra de classificação (produto típico → setor; desconhecido → `outros`).
* **Tolerância do cliente Dart:** item sem `categoria` → `outros`; campo desconhecido extra ignorado.
* **Ordem de rollout:** deploy da function **antes** do APK novo aos testadores (app antigo ignora campo extra; function nova alimenta app antigo sem quebrar).

## 6. UI ([05 §6.3](../../05-app-flutter.md), [10 §3](../../10-wireframes-telas.md))

| Elemento | Comportamento |
| :--- | :--- |
| Itens pendentes | Agrupados por categoria (ordem do enum), header por grupo: `Frios (3)`, com contagem de itens pendentes do grupo |
| Exibição | Ordenação: `(categoria, ordem, id)` — determinística entre dispositivos |
| Drag-and-drop | Reordena **só dentro do grupo**; `reordenarItens` continua gravando `ordem` (linhas afetadas) |
| Mudar categoria | Swipe direita → editar: dropdown de categoria no diálogo (ao lado das unidades) |
| Adição rápida (Enter/＋) | Salva imediatamente com `sugerirCategoria(nome)` (§4) |
| Import IA | Pré-visualização: painel ▾ edita nome/quantidade/unidade/**categoria** (dropdown) |
| Concluídos | Seção única dobrável atual, sem divisão por categoria (D7) |
| Ações em massa | "Desmarcar todos" restaura itens na seção pendente por sua categoria; "limpar concluídos" inalterado |

Grupos vazios não renderizam header. Item único em grupo = grupo com 1 item (mesmo visual).

## 7. Compatibilidade e rollout

| Cenário | Comportamento |
| :--- | :--- |
| App antigo (1.0.0+2) escreve sem `categoria` | Postgres aplica default `outros`; upsert LWW **não toca** a coluna (não está no payload) — categoria existente preservada |
| Function nova + app antigo | JSON com `categoria` extra é ignorado pelo parser antigo |
| App novo + function antiga | Resposta sem `categoria` → `outros` |
| Rollback | Coluna removível por migration inversa (dado aditivo; sem dependência de RLS/realtime) |

Rollout: T01 (migration local + `db push`) → T02–T04 (app) → T05 (function, deploy produção) → T06 (validação sync) → nova distribuição ao grupo `testadores` (App Distribution).

## 8. Testes ([07 §1](../../07-qualidade-ci.md); nomes `deve_<resultado>_quando_<condição>`)

| Camada | Cobertura |
| :--- | :--- |
| SQL ([01 §8](../../01-banco-de-dados.md)) | `enum_range` = 11 valores; `categoria` inválida rejeita; INSERT sem categoria → `outros` |
| Drift/Repositório | Migração v2→v3; adicionar/editar grava categoria; payload com `categoria`; fila UPDATE de categoria |
| Sugestão | Memória vence dicionário; match específico vence genérico; fallback `outros`; sem memória primeira vez |
| Widget | Headers com contagem; agrupamento por ordem do enum; drag dentro do grupo; dropdown no editar muda categoria; Enter aplica sugestão; concluídos sem grupos |
| IA (deno + e2e) | Schema exige enum; cliente tolerante (sem categoria → `outros`); cenários com categorias plausíveis |
| Sync (checklist [03 §8](../../03-sincronizacao-offline.md)) | Cenário: 2 dispositivos com servidor fake — edição de categoria em um aparece no outro; LWW com categoria no payload |

## 9. Docs impactados e tarefas (mapa de execução)

| Tarefa | Entrega | Doc(s) dono atualizado(s) no mesmo PR |
| :--- | :--- | :--- |
| F6-T00 ✅ | Esta spec + RF-15 + ADR-011 + campos no 13 + breakdown no 14 | 00, 12, 13, 14 (+ este arquivo) |
| F6-T01 | Migration `0006` | [01](../../01-banco-de-dados.md) |
| F6-T02 | Drift v3 + repositório com categoria | [05 §2–3](../../05-app-flutter.md), [03 §3](../../03-sincronizacao-offline.md) |
| F6-T03 | Cadeia de sugestão (memória + dicionário) | [05 §3](../../05-app-flutter.md) |
| F6-T04 | UI de grupos + drag interno + dropdown | [05 §6.3](../../05-app-flutter.md), [10 §3](../../10-wireframes-telas.md) |
| F6-T05 | IA com categoria + deploy | [04](../../04-ia-edge-function.md) |
| F6-T06 | Checklist sync com categoria + distribuição | [03 §8](../../03-sincronizacao-offline.md) |

Sem mudança: [02](../../02-seguranca-rls.md) (coluna aditiva não afeta policies), [06](../../06-mvp-entregas.md) (pós-MVP), [07](../../07-qualidade-ci.md) (padrões existentes), [08](../../08-compartilhamento-colaborativo.md), [09](../../09-runbook-operacoes.md) (deploy segue §3.2).

## 10. Riscos e limitações

| Risco | Mitigação |
| :--- | :--- |
| Dicionário não cobre produto incomum | Cai em `outros` + memória aprende; categorizável a qualquer momento |
| IA classifica errado | Sugestão editável na pré-visualização; nunca bloqueia |
| Drag interno conflita com `ordem` global legado | Ordenação de exibição por `(categoria, ordem, id)`; `ordem` só reordenada dentro do grupo — sem nova coluna |
| Usuário muda categoria offline | Escrita local + fila (fluxo padrão); LWW resolve conflito |
