# 13 — Pré-modelo Técnico (Contexto Condensado)

> Navegação: [← 12 PRD](12-prd.md) · [14 Tarefas →](14-tarefas.md)

**Leia este arquivo ANTES de implementar qualquer coisa.** É o modelo técnico condensado — uma leitura única dá o contexto completo. Cada seção aponta o **doc dono** com o detalhe normativo; este arquivo nunca sobrepõe o dono.

---

## 1. Regras para o agente/implementador

1. **Ordem de leitura:** este arquivo → [14 Tarefas](14-tarefas.md) → **doc dono** da tarefa → código.
2. **Doc dono é autoridade:** se este resumo divergir do doc dono, vale o doc dono.
3. **Proibido alterar comportamento** documentado (dados locais, parser, rotas) **sem atualizar o doc dono no mesmo PR**.
4. Requisitos têm ID (`RF-xx`, [12 §2](12-prd.md)) — mencione o ID no commit/PR.
5. Toda tarefa tem critério de pronto em [14](14-tarefas.md) — não marque concluído sem ele.
6. Nenhuma chave/segredo em código; CI verde obrigatório ([07](07-qualidade-ci.md)).

## 2. Stack (uma leitura)

| Camada | Tecnologia | Papel |
| :--- | :--- | :--- |
| App | Flutter + Riverpod + go_router | UI reativa; sem rede |
| Persistência | Drift/SQLite | **Fonte de verdade local**; leitura via Streams |
| Ops | GitHub Actions | CI obrigatório |

> O app é **único e local** ("Minhas Listas", RF-31/ADR-015): sem Supabase, conta, sync, colaboração ou push.

## 3. Entidades e relacionamentos

```
App local (Drift): ListaLocal 1───N ItemLocal
                                 └───N HistoricoPrecoLocal (local, por nome)
```

**Campos-chave (mínimo para raciocinar):**

| Entidade | Campos essenciais | Detalhe |
| :--- | :--- | :--- |
| `listas` (local) | id (uuid, cliente), titulo, arquivada_em, orcamento_centavos, updated_at, deletado_em | [05 §6.2](05-app-flutter.md) |
| `itens_lista` (local) | id (uuid, cliente), lista_id, nome, quantidade>0, unidade (enum), categoria (enum), concluido, ordem, preco_centavos, updated_at, deletado_em | índice único parcial `uq_item_ativo` |
| `historico_precos` (local) | nome, unidade, preco_centavos, registrado_em | local por dispositivo (RF-29) |

**Enum de unidades (fechado):** `un, kg, g, l, ml, caixa, pacote, pct, pt, dz` — fonte única `lib/core/dominio/unidade.dart` (usada pelo app e pelo parser local).

**Enum de categorias (fechado, ADR-011):** `hortifruti, mercearia, frios, laticinios, congelados, padaria, bebidas, pet, limpeza, higiene, outros` — fonte única `lib/core/dominio/categoria.dart`; a ordem do enum define a ordem dos grupos na UI. Sugestão **local em camadas** (memória por nome → dicionário estático → `outros`).

## 4. Fluxos essenciais

### F1 — Escrita local (sempre)
UI → Repositório → **Drift** grava. Leitura: Stream do Drift → UI. A UI nunca bloqueia. [05 §2](05-app-flutter.md)

### F3 — Importação de lista (parser local)
App → parser local determinístico (`lib/core/importacao/parser_lista_local.dart`, offline) sobre o texto colado (≤ `maxCaracteresImportLocal`) → sugestão de categoria local em camadas (memória → dicionário → `outros`) → `{itens:[{nome,quantidade,unidade,categoria}], aviso}` → **pré-visualização editável** → grava local no Drift. Erros amigáveis ([04 §2](04-importacao-lista.md)). Item sem `categoria` → `outros`.

### F6 — Backup local
Configurações → **Exportar backup** (`.json` fiel ao banco) → **Importar backup** (merge por `id` + LWW por `updated_at`). [05 §6.10](05-app-flutter.md)

## 5. Contratos rápidos

**Importação local (resumo — [04 §2](04-importacao-lista.md)):**
```
parser local determinístico — offline, sem rede
entrada: texto colado, até maxCaracteresImportLocal (10.000)
saída: { "itens": [...], "aviso": null }
```

**Dono e sessão:** não há conta. O dono de toda lista é a constante `idLocal = 'local'` ([05 §2.3](05-app-flutter.md)).

## 6. Decisões vinculantes (ADR — 1 linha cada, detalhe em [00 §5](00-visao-geral.md))

| ADR | Decisão |
| :--- | :--- |
| 001 | MVP = Android/iOS/Web; **Desktop suportado (F18)**; **Web de uso local (ADR-013)** |
| 002 | Riverpod |
| 003 | Drift/SQLite local |
| 005 | Enum fechado de unidades |
| 006 | IDs UUID v4 gerados no cliente |
| 010 | GitHub Actions desde a F1 |
| 011 | Categoria do item: enum fechado (11 valores) + sugestão local em camadas (memória → dicionário → outros) |
| 012 | Suporte a Web (Drift/WASM) e Desktop (F18); banco por fábrica com import condicional |
| 013 | Web: **uso local** (publicação suspensa em 18/09/2026) |
| **015** | **App único local "Minhas Listas" (F48): sem Supabase/conta/sync/colaboração/push** |
| ~~004~~ | ~~LWW de sync~~ — superada (não há sync) |
| ~~007~~ | ~~Free tier Supabase~~ — superada (não há backend) |
| ~~008~~ | ~~Exclusão de conta~~ — superada (não há conta) |
| ~~009~~ | ~~Sentry~~ — superada (nada sai do aparelho) |
| ~~014~~ | ~~Notificações push~~ — superada (push removido) |

## 7. Comandos essenciais

```bash
flutter test                          # testes (obrigatório verde)
dart format . && flutter analyze      # estilo e lint
```

## 8. Design System (doc 15)

Material 3 Expressive, seed índigo `#4F46E5` (identidade "Minhas Listas"), fonte Plus Jakarta Sans bundlada, claro/escuro com paridade, modo Claro/Escuro/Sistema (SharedPreferences) e a biblioteca `App*` em `lib/core/widgets/`. Tokens em `lib/core/theme/tokens/`. Detalhes: [15](15-design-system.md).

---

## Documentos relacionados
- [12 PRD](12-prd.md) — requisitos com IDs
- [14 Tarefas](14-tarefas.md) — o que fazer, em ordem
- [AGENTS.md](../AGENTS.md) — instruções operacionais para agentes
