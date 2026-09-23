# Fase 39 — Consistência arquitetural (design)

> **Status:** aprovado em 23/09/2026 (decisões na Seção 11)
> **Fase:** 39 · **Requisito:** RNF-08 (qualidade) · **Doc dono:** [05](../05-app-flutter.md), [03](../03-sincronizacao-offline.md), [02](../02-seguranca-rls.md), [09](../09-runbook-operacoes.md), [04](../04-importacao-lista.md)
> **Origem:** auditoria de consistência arquitetural de 23/09/2026 (código real × docs donos).

---

## 1. Motivação

A auditoria de 23/09/2026 confirmou que as camadas não negociáveis estão sólidas (RLS 100% das
tabelas com `enable`+`force`, zero policy permissiva; enum de unidades idêntico em Postgres/Dart/
parser; nenhum `service_role` no cliente; writes de lista/item só via Drift + fila; migrations
`0001`–`0022` contínuas). Restaram desvios de baixo impacto, mas reais, que esta fase fecha:

1. **Inversão de camada `core → features`** em 3 arquivos de `core/` (o vocabulário compartilhado
   `unidade`/`categoria`/`quantidade` mora em `features/listas/domain/`).
2. **Providers de rede dentro de `ui/`**, quebrando o contrato documentado `ui → providers → data`
   ([05 §2](../05-app-flutter.md)).
3. **Barreiras só no Postgres**: o Drift não replica `CHECK`s nem o índice único parcial
   `uq_item_ativo`, então a mesma regra é validada em dois lugares diferentes (Dart × banco).
4. **Duplicação** de validação de e-mail (4 locais) e do rótulo de papel (3 locais).
5. **Docs donos defasados**: árvore de pastas do [05 §2](../05-app-flutter.md) e a lista de
   migrations de RLS do [02 §5](../02-seguranca-rls.md).
6. **Higiene**: padrão inválido no `.gitignore` (espaço inicial) e decisão não registrada sobre o
   `google-services.json` rastreado.

## 2. Escopo

**Dentro:**
- Mover `categoria.dart`, `unidade.dart`, `quantidade.dart` para `lib/core/dominio/` e atualizar
  todos os imports. Mover os testes correspondentes.
- Mover `membrosDaListaProvider` e `meusConvitesPendentesProvider` de `ui/` para
  `convites/providers/convites_providers.dart`.
- Migração Drift `schemaVersion 7 → 8`: `CHECK`s locais + índice único parcial `uq_item_ativo`
  (com dedup defensivo).
- Extrair validação de e-mail e rótulo de papel para um único lugar.
- Atualizar os docs donos (05 §2, 02 §5) e registrar a decisão do `google-services.json` (09).
- Corrigir o `.gitignore`.

**Fora (explícito):**
- **Sem mudança de comportamento** observável: nenhum contrato de sync/RLS/schema Postgres muda.
- **Sem** migração para inteiro de milésimos: `quantidade` continua `real` no Drift (decisão §11.6).
- **`AppMotion` não é código morto** — é usado em `test/core/theme/tokens_test.dart` e documentado
  em [15 §1](../15-design-system.md); a auditoria inicial estava incompleta. **Nada a fazer.**
- **`google-services.json` continua rastreado** (decisão §11.5).
- Sem refatoração de `auth`/`notificacoes`/`voz`/`onboarding` para o formato de 4 camadas: os
  formatos enxutos são intencionais e ficam documentados no 05 (não todo módulo tem entidade local).
- Sem camada de DAO nova nem reescrita de `listas_repository`/`sync_engine`.
- Sem mudança de UI/visual; sem novas dependências.

## 3. Arquitetura da mudança

```
lib/
├── core/
│   ├── dominio/            ← NOVO (shared kernel)
│   │   ├── categoria.dart      (CategoriaItem — ADR-011)
│   │   ├── unidade.dart        (Unidade — ADR-005)
│   │   └── quantidade.dart     (parse/format de quantidade — F29)
│   ├── texto/validacao.dart ← NOVO (emailValido)
│   └── importacao/, categorias/  (passam a importar ../dominio/)
├── features/
│   ├── listas/domain/       (perde os 3 arquivos; mantém item/lista/preco/…)
│   └── convites/
│       ├── domain/papel.dart   (+ getter rotulo)
│       └── providers/convites_providers.dart  (+2 providers)
```

`core/dominio/` é o **shared kernel**: vocabulário fechado que o próprio [13 §3](../13-premodelo-tecnico.md)
define como canônico e compartilhado entre Postgres, Dart e parser. Depois do movimento, `core/`
**não importa mais** `features/`, e a inversão desaparece.

## 4. Shared kernel — `lib/core/dominio/`

- Mover os três arquivos (conteúdo inalterado; nenhuma API pública muda de nome).
  - `categoria.dart` → `enum CategoriaItem` (+ `rotulo`).
  - `unidade.dart` → `enum Unidade` (+ `fromValor`).
  - `quantidade.dart` → `glifosFracao`, `parseQuantidade`, `formatarQuantidade`.
- Atualizar **42 pontos de import** (lib + test) para `package:lista_compras/core/dominio/...`
  (test) ou caminho relativo (lib).
- Mover `test/features/listas/{quantidade,categoria}_test.dart` → `test/core/dominio/`.
- O movimento é **puro**: coberto pela suíte existente (`flutter analyze` + `flutter test`)
  como evidência de que nada mudou de comportamento.

## 5. Reforço do Drift — `schemaVersion 7 → 8`

`lib/drift/tables/item_local.dart` e `lib/drift/tables/lista_local.dart` ganham, cada um,
`@override List<String> get customConstraints => [...]` espelhando o Postgres;
`lib/drift/database.dart` sobe a versão e adiciona o passo `de < 8`.

| Regra Postgres | Origem | Espelho no Drift |
| :--- | :--- | :--- |
| `quantidade > 0` | `0001_init.sql:49` | `customConstraints: ['CHECK (quantidade > 0)']` |
| `unidade` no enum | `0001_init.sql:9-11` | `CHECK (unidade IN (…9 valores…))` |
| `categoria` no enum | `0006_categorias.sql` | `CHECK (categoria IN (…11 valores…))` |
| `preco_centavos` 0…99999999 ou null | `0017_preco_item.sql:5` | `CHECK (preco_centavos IS NULL OR preco_centavos BETWEEN 0 AND 99999999)` |
| `orcamento_centavos` ≥ 0 ou null | `0020_orcamento_lista.sql:6` | `CHECK (orcamento_centavos IS NULL OR orcamento_centavos >= 0)` |
| `uq_item_ativo (lista_id, lower(nome)) WHERE deletado_em IS NULL` | `0001_init.sql:57-59` | índice via `customStatement` (parcial não é expressável no `@TableIndex`) |

**Migração (SQLite não faz `ALTER … ADD CHECK`, então há rebuild):**
1. Dedup defensivo de itens ativos duplicados por `(lista_id, lower(nome))`: mantém **1 sobrevivente
   por grupo**, preferindo (a) linhas com mutação pendente, depois (b) `updated_at` mais recente e
   (c) maior `rowid`; remove as demais linhas **e** suas `mutacoes_pendentes`
   (o item some localmente; o remoto reenvia a verdade ativa pela dedup do Postgres).
2. `m.alterTable(TableMigration(itemLocal))` e `m.alterTable(TableMigration(listaLocal))` para
   reconstruir as tabelas com os novos `CHECK`s.
3. `CREATE UNIQUE INDEX IF NOT EXISTS uq_item_ativo ON item_local (lista_id, lower(nome)) WHERE deletado_em IS NULL`.
- Instalação nova: o índice é criado também no `onCreate`
  (`onCreate: (m) async { await m.createAll(); await customStatement('<mesmo CREATE INDEX>'); }`),
  de modo que base limpa e base migrada terminam idênticas.
- Idempotente (`IF NOT EXISTS`) e tolerante a base limpa.
- Cobertura: teste de migração dedicado (v7 → v8) com base suja (inclusive duplicatas com fila
  pendente) + teste de nova instalação.

**Paridade de dados:** `quantidade` segue `real` (SQLite não tem `DECIMAL`); a divergência `real` ×
`numeric` fica **documentada** no 05 com o orçamento de precisão da app (exibição ≤ 3 casas,
tolerância 0,001). Nenhuma migração de valores.

## 6. Camada de apresentação — providers no lugar certo

- Mover `membrosDaListaProvider` (`convites/ui/tela_membros_screen.dart:29`) e
  `meusConvitesPendentesProvider` (`convites/ui/convites_pendentes_secao.dart:19`) para
  `convites/providers/convites_providers.dart`; as telas passam a importar de lá.
- Nomes, tipos (`FutureProvider.family` / `FutureProvider.autoDispose`) e comportamento inalterados.
- Alinha ao contrato documentado (`ui → providers → data`), sem mexer nas chamadas diretas a
  repositórios no restante da UI (fora do escopo desta fase).

## 7. Deduplicação

- **E-mail:** novo `lib/core/texto/validacao.dart` com `emailValido(String)`; passa a ser usado em
  `login_screen`, `registro_screen`, `recuperar_senha_screen` e `sheet_convidar` (4 → 1).
- **Rótulo de papel:** getter `rotulo` em `convites/domain/papel.dart`; os `_rotuloPapel` de
  `tela_membros_screen`, `sheet_convidar` e `convites_pendentes_secao` passam a consumi-lo (3 → 1).
- Comportamento idêntico (mesmo regex, mesmos textos) — coberto pelos testes existentes.

## 8. Docs donos

- **[05 §2](../05-app-flutter.md):** substituir a árvore parcial pela real (10 features + subpastas
  de `core/`, incluindo `core/dominio/`); registrar que módulos sem entidade local podem ser
  enxutos (sem `domain/`/`data/`); documentar a paridade de barreiras Drift × Postgres e a
  divergência `real` × `numeric`.
- **[02 §5](../02-seguranca-rls.md):** corrigir a afirmação de que as policies vivem só na
  `0002_rls_policies.sql` (também em `0007`/`0009`/`0012`/`0015`/`0021`).
- **[09](../09-runbook-operacoes.md):** registrar a decisão do `google-services.json` (rastreado;
  API key Android restrita por package + SHA-1 no console Firebase).
- **[03](../03-sincronizacao-offline.md):** apontar para a nova seção de barreiras locais do 05
  (schema local), sem reescrever semântica.

## 9. Higiene

- Corrigir `.gitignore` (remover o espaço inicial de `' Generated.xcconfig'`).
- Nenhum segredo novo; nada muda em CI além dos testes.

## 10. Testes e CI

- **Movimento (item 4):** suíte existente verde é a evidência (sem testes novos).
- **Drift (item 5):** teste de migração v7 → v8 (base com duplicatas + fila) e teste de criação
  nova; teste negativo dos `CHECK`s (inserir quantidade ≤ 0 / unidade inválida → lança).
- **Providers (item 6):** testes existentes de `tela_membros`/`convites_pendentes` continuam verdes.
- **Dedup (item 7):** testes de e-mail e de rótulo de papel (unit).
- **CI ([07](../07-qualidade-ci.md)):** `dart format .`, `flutter analyze` e `flutter test` verdes;
  sem novos jobs.

## 11. Decisões registradas (23/09/2026)

1. **Escopo:** fechar os desvios da auditoria, incluindo o reforço do Drift (decisão do usuário:
   "completo").
2. **Shared kernel:** vocabulário em `lib/core/dominio/` (não documentar a exceção, não duplicar).
3. **Sem mudança de comportamento:** a fase é de estrutura + barreiras; nenhum contrato muda.
4. **Drift:** `CHECK`s espelhados via rebuild (`alterTable`) + `uq_item_ativo` parcial via
   `customStatement`, com dedup defensivo.
5. **`google-services.json`:** permanece rastreado (a API key Android não é segredo por si;
   o usuário restringe a key no console por package + SHA-1).
6. **`quantidade`:** mantém `real`; paridade com `numeric` é documentada, não migrada.
7. **`AppMotion`:** fora do escopo — usado e documentado (correção da auditoria).
8. Sem novo requisito: a fase é qualidade interna sob **RNF-08**.

## 12. Documentos relacionados
- [05 App Flutter](../05-app-flutter.md) §2 · [03 Sincronização](../03-sincronizacao-offline.md)
- [02 Segurança RLS](../02-seguranca-rls.md) §5 · [01 Banco de Dados](../01-banco-de-dados.md) §4.3
- [04 Importação](../04-importacao-lista.md) §2 · [09 Runbook](../09-runbook-operacoes.md) · [15 Design System](../15-design-system.md) §1
- [07 Qualidade/CI](../07-qualidade-ci.md) · [14 Tarefas](../14-tarefas.md) (Fase 39) · [13 Pré-modelo](../13-premodelo-tecnico.md) §3
