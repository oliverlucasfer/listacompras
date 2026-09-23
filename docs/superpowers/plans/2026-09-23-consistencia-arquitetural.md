# Consistência arquitetural (Fase 39) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fechar os desvios da auditoria de consistência arquitetural de 23/09/2026 — shared kernel em `core/dominio/`, providers de rede fora da UI, deduplicação de validação, barreiras locais do Drift espelhando o Postgres e docs donos atualizados — **sem mudança de comportamento**.

**Architecture:** Três blocos independentes. (1) Mover o vocabulário fechado (`CategoriaItem`, `Unidade`, helpers de quantidade) para `lib/core/dominio/`, eliminando a inversão `core → features`. (2) Reforçar o Drift (`schemaVersion 7 → 8`) com `CHECK`s e o índice único parcial `uq_item_ativo`, espelhando `supabase/migrations/0001_init.sql`, `0006`, `0017` e `0020`. (3) Higiene de camada aparentada: providers para `providers/` e duplicações para um único lugar. Docs donos acompanham no mesmo PR (regra do `AGENTS.md`).

**Tech Stack:** Flutter, Riverpod, Drift (SQLite), Dart 3; testes `flutter test`; CI GitHub Actions ([07](docs/07-qualidade-ci.md)).

**Spec:** [docs/superpowers/specs/2026-09-23-consistencia-arquitetural-design.md](docs/superpowers/specs/2026-09-23-consistencia-arquitetural-design.md)

## Global Constraints

- **Sem mudança de comportamento** observável: nenhum contrato de UI, sync, RLS ou schema Postgres muda.
- **Nenhuma migration Postgres nova**; nada em `supabase/` é tocado nesta fase.
- **`quantidade` continua `real`** no Drift (SQLite não tem `DECIMAL`); paridade com `numeric` é documentada, não migrada.
- **`google-services.json` permanece rastreado**; a decisão é apenas registrada no doc 09.
- **`AppMotion` não é código morto** (usado em `test/core/theme/tokens_test.dart`); não tocar.
- **Nomes de teste:** `deve_<resultado>_quando_<condição>`.
- **Sem comentários supérfluos**; comentários só onde explicam uma decisão não óbvia.
- **Dois comandos obrigatórios verdes** antes de cada commit: `dart format .` e `flutter analyze`; e `flutter test` ao fim de cada task.
- **Sem segredos** em código, commit ou log.
- Commits em pt-BR, referenciando o ID da task (ex.: `F39-T02: ...`) e o RNF-08.

---

## File Structure

**Criados:**
- `lib/core/dominio/categoria.dart` — `enum CategoriaItem` (movido de `features/listas/domain/`).
- `lib/core/dominio/unidade.dart` — `enum Unidade` (movido).
- `lib/core/dominio/quantidade.dart` — helpers (movido).
- `lib/core/texto/validacao.dart` — `emailValido(String)`.
- `test/core/dominio/categoria_test.dart`, `test/core/dominio/quantidade_test.dart` — movidos.
- `test/core/texto/validacao_test.dart` — testes de `emailValido`.
- `test/features/convites/papel_rotulo_test.dart` — teste do getter `Papel.rotulo`.

**Removidos:**
- `lib/features/listas/domain/categoria.dart`, `unidade.dart`, `quantidade.dart`.
- `test/features/listas/categoria_test.dart`, `test/features/listas/quantidade_test.dart`.

**Modificados:**
- `lib/drift/database.dart` — `schemaVersion 8`, `onCreate` com índice, passo `de < 8`, `_dedupItensAtivos`.
- `lib/drift/tables/item_local.dart`, `lib/drift/tables/lista_local.dart` — `customConstraints`.
- `lib/features/convites/providers/convites_providers.dart` — recebe 2 providers.
- `lib/features/convites/ui/tela_membros_screen.dart`, `convites/ui/convites_pendentes_secao.dart` — perdem os providers.
- `lib/features/convites/domain/papel.dart` — getter `rotulo`.
- `lib/features/auth/ui/{login,registro,recuperar_senha}_screen.dart`, `lib/features/convites/ui/sheet_convidar.dart` — usam `emailValido`.
- `.gitignore` — corrige o padrão com espaço inicial.
- **45 linhas de `import`** em 31 arquivos (lista na Task 2).
- `docs/05-app-flutter.md`, `docs/02-seguranca-rls.md`, `docs/09-runbook-operacoes.md`, `docs/03-sincronizacao-offline.md`, `docs/14-tarefas.md`.

---

## Task 1: Planejamento — Fase 39 em `docs/14-tarefas.md`

**Files:**
- Modify: `docs/14-tarefas.md` (nova Fase 39 após a F38, ~linha 829; tabela de progresso ~linha 832-870)

**Interfaces:**
- Consumes: nada.
- Produces: IDs `F39-T01…T07` usados nas mensagens de commit e nos documentos das tasks seguintes.

- [ ] **Step 1: Inserir a Fase 39 após o bloco da F38 (antes de `## Progresso por fase`)**

```markdown
## Fase 39 — Consistência arquitetural (RNF-08)

Spec: [superpowers/specs/2026-09-23-consistencia-arquitetural-design.md](superpowers/specs/2026-09-23-consistencia-arquitetural-design.md) · Plano: [superpowers/plans/2026-09-23-consistencia-arquitetural.md](superpowers/plans/2026-09-23-consistencia-arquitetural.md) · Requisito: RNF-08 (qualidade — consistência de camadas e paridade de barreiras). · Docs donos: 05, 03, 02, 09, 04.

- [ ] **F39-T01** — Planejamento: Fase 39 e rastreabilidade no RNF-08
  Dep: — · Docs: [14](14-tarefas.md), [12 §4](12-prd.md)
  CP: Fase 39 no 14 com as 7 tarefas e a linha de progresso (203/194); RNF-08 do 12 aponta a consistência arquitetural como evidência.
- [ ] **F39-T02** — Shared kernel: `lib/core/dominio/`
  Dep: F39-T01 · Docs: [05 §2](05-app-flutter.md), [13 §3](13-premodelo-tecnico.md)
  CP: `categoria.dart`/`unidade.dart`/`quantidade.dart` em `lib/core/dominio/`; `core/` não importa mais `features/`; 45 imports atualizados; testes movidos para `test/core/dominio/`; `flutter analyze`/`flutter test` verdes.
- [ ] **F39-T03** — Providers de rede para `providers/`
  Dep: F39-T02 · Docs: [05 §2](05-app-flutter.md)
  CP: `membrosDaListaProvider` e `meusConvitesPendentesProvider` em `convites/providers/convites_providers.dart`; nenhum provider definido em `ui/`; testes de membros/convites pendentes verdes.
- [ ] **F39-T04** — Deduplicação: `emailValido` e `Papel.rotulo`
  Dep: F39-T02 · Docs: [05 §2](05-app-flutter.md)
  CP: `lib/core/texto/validacao.dart` com `emailValido`; getter `Papel.rotulo`; 4 usos de regex e 3 `_rotuloPapel` eliminados; testes novos verdes.
- [ ] **F39-T05** — Drift: barreiras locais espelhando o Postgres (v7→v8)
  Dep: F39-T02 · Docs: [05 §2](05-app-flutter.md), [03 §3](03-sincronizacao-offline.md)
  CP: `customConstraints` em `ItemLocal`/`ListaLocal`; `schemaVersion = 8`; migração com dedup defensivo + `alterTable` + índice único parcial `uq_item_ativo`; `onCreate` cria o índice; testes de migração v7→v8 e de negativos dos CHECK verdes.
- [ ] **F39-T06** — Docs donos e higiene
  Dep: F39-T05 · Docs: [05 §2](05-app-flutter.md), [02 §5](02-seguranca-rls.md), [09 §2](09-runbook-operacoes.md), [03 §3](03-sincronizacao-offline.md)
  CP: 05 §2 com a árvore real e a paridade de barreiras Drift × Postgres (incluindo a nota `real` × `numeric`); 02 §5 corrige a lista de migrations de RLS; 09 §2 registra a decisão do `google-services.json`; 03 §3 aponta para a seção de barreiras locais; `.gitignore` corrigido.
- [ ] **F39-T07** — Fechamento: verificação e distribuição
  Dep: F39-T06 · Docs: [14](14-tarefas.md)
  CP: F39-T01…T07 marcadas e tabela de progresso (203/203); `dart format .`, `flutter analyze`, `flutter test` e SQL/Deno inalterados verdes; CI verde; (opcional, sob pedido) build `1.5.0+9` redistribuído — o comportamento não mudou, então o app distribuído continua válido.
```

- [ ] **Step 2: Adicionar a linha na tabela de progresso**

Inserir após `| F38 Notificações push | 9 | 9 |`:

```markdown
| F39 Consistência arquitetural | 7 | 0 |
```

E trocar a linha do total:

```markdown
| **Total** | **203** | **194** |
```

- [ ] **Step 3: Confirmar o RNF-08 no doc 12**

Ler `docs/12-prd.md` na tabela de RNF-08 e, se necessário, acrescentar à coluna de evidência: "consistência de camadas e paridade de barreiras local/remoto (F39)". Não alterar outros campos.

- [ ] **Step 4: Commit**

```bash
git add docs/14-tarefas.md docs/12-prd.md
git commit -m "F39-T01: Fase 39 e rastreabilidade no RNF-08 (RNF-08)"
```

---

## Task 2: Shared kernel — `lib/core/dominio/`

**Files:**
- Create: `lib/core/dominio/categoria.dart`, `lib/core/dominio/unidade.dart`, `lib/core/dominio/quantidade.dart`
- Delete: `lib/features/listas/domain/categoria.dart`, `lib/features/listas/domain/unidade.dart`, `lib/features/listas/domain/quantidade.dart`
- Create: `test/core/dominio/categoria_test.dart`, `test/core/dominio/quantidade_test.dart`
- Delete: `test/features/listas/categoria_test.dart`, `test/features/listas/quantidade_test.dart`
- Modify: 31 arquivos (45 linhas de import) — lista no Step 4

**Interfaces:**
- Consumes: nada.
- Produces: `package:lista_compras/core/dominio/categoria.dart` (`CategoriaItem`), `.../unidade.dart` (`Unidade` com `Unidade.fromValor(String)`), `.../quantidade.dart` (`parseQuantidade(String) → double?`, `formatarQuantidade(double) → String`, `glifosFracao`). **Nomes inalterados** — Tasks 3-5 dependem deles por esses nomes.

- [ ] **Step 1: Mover os três arquivos de `lib/` (conteúdo idêntico)**

```bash
git mv lib/features/listas/domain/categoria.dart lib/core/dominio/categoria.dart
git mv lib/features/listas/domain/unidade.dart lib/core/dominio/unidade.dart
git mv lib/features/listas/domain/quantidade.dart lib/core/dominio/quantidade.dart
```

Nenhum ajuste de conteúdo é necessário (os três não têm imports). O destino `lib/core/dominio/` já é criado pelo `git mv`.

- [ ] **Step 2: Mover os dois testes e ajustar o import**

```bash
git mv test/features/listas/categoria_test.dart test/core/dominio/categoria_test.dart
git mv test/features/listas/quantidade_test.dart test/core/dominio/quantidade_test.dart
```

Em `test/core/dominio/categoria_test.dart`, trocar:

```dart
import 'package:lista_compras/features/listas/domain/categoria.dart';
```

por:

```dart
import 'package:lista_compras/core/dominio/categoria.dart';
```

Em `test/core/dominio/quantidade_test.dart`, trocar:

```dart
import 'package:lista_compras/features/listas/domain/quantidade.dart';
```

por:

```dart
import 'package:lista_compras/core/dominio/quantidade.dart';
```

- [ ] **Step 3: Reescrever os imports em `lib/` (15 arquivos)**

| Arquivo | De | Para |
| :--- | :--- | :--- |
| `lib/core/importacao/resposta_import.dart` | `../../features/listas/domain/categoria.dart` | `../dominio/categoria.dart` |
| `lib/core/importacao/resposta_import.dart` | `../../features/listas/domain/unidade.dart` | `../dominio/unidade.dart` |
| `lib/core/importacao/parser_lista_local.dart` | `../../features/listas/domain/quantidade.dart` | `../dominio/quantidade.dart` |
| `lib/core/importacao/parser_lista_local.dart` | `../../features/listas/domain/unidade.dart` | `../dominio/unidade.dart` |
| `lib/core/categorias/sugestao_categorias.dart` | `../../features/listas/domain/categoria.dart` | `../dominio/categoria.dart` |
| `lib/core/categorias/dicionario_categorias.dart` | `../../features/listas/domain/categoria.dart` | `../dominio/categoria.dart` |
| `lib/features/sync/data/aplicador_remoto.dart` | `../../listas/domain/unidade.dart` | `../../../core/dominio/unidade.dart` |
| `lib/features/importacao/ui/modal_previsao_importacao.dart` | `../../listas/domain/categoria.dart` | `../../../core/dominio/categoria.dart` |
| `lib/features/importacao/ui/modal_previsao_importacao.dart` | `../../listas/domain/quantidade.dart` | `../../../core/dominio/quantidade.dart` |
| `lib/features/importacao/ui/modal_previsao_importacao.dart` | `../../listas/domain/unidade.dart` | `../../../core/dominio/unidade.dart` |
| `lib/features/listas/providers/ordem_categorias_provider.dart` | `../domain/categoria.dart` | `../../../core/dominio/categoria.dart` |
| `lib/features/listas/ui/tela_ordenar_categorias.dart` | `../domain/categoria.dart` | `../../../core/dominio/categoria.dart` |
| `lib/features/listas/ui/tela_lista_screen.dart` | `../domain/categoria.dart` | `../../../core/dominio/categoria.dart` |
| `lib/features/listas/ui/tela_lista_screen.dart` | `../domain/quantidade.dart` | `../../../core/dominio/quantidade.dart` |
| `lib/features/listas/ui/tela_lista_screen.dart` | `../domain/unidade.dart` | `../../../core/dominio/unidade.dart` |
| `lib/features/listas/ui/modal_adicionar_de_outra_lista.dart` | `../domain/quantidade.dart` | `../../../core/dominio/quantidade.dart` |
| `lib/features/listas/ui/mercado_screen.dart` | `../domain/quantidade.dart` | `../../../core/dominio/quantidade.dart` |
| `lib/features/listas/data/listas_repository.dart` | `../domain/categoria.dart` | `../../../core/dominio/categoria.dart` |
| `lib/features/listas/data/listas_repository.dart` | `../domain/unidade.dart` | `../../../core/dominio/unidade.dart` |
| `lib/features/listas/data/historico_precos_repository.dart` | `../domain/unidade.dart` | `../../../core/dominio/unidade.dart` |
| `lib/features/listas/domain/item.dart` | `categoria.dart` | `../../../core/dominio/categoria.dart` |
| `lib/features/listas/domain/item.dart` | `unidade.dart` | `../../../core/dominio/unidade.dart` |
| `lib/features/listas/domain/ordem_categorias.dart` | `categoria.dart` | `../../../core/dominio/categoria.dart` |

- [ ] **Step 4: Reescrever os imports em `test/` (16 arquivos, import `package:`)**

Em cada arquivo abaixo, substituir **todas** as ocorrências de
`package:lista_compras/features/listas/domain/{categoria,quantidade,unidade}.dart`
por `package:lista_compras/core/dominio/{categoria,quantidade,unidade}.dart` (mesmo nome de arquivo):

`test/features/sync/sync_engine_test.dart`, `test/features/sync/aplicador_remoto_test.dart`,
`test/features/listas/editar_item_historico_test.dart`, `test/features/listas/tela_ordenar_categorias_test.dart`,
`test/features/listas/duplicar_lista_test.dart`, `test/features/listas/tela_lista_screen_test.dart`,
`test/features/listas/preco_test.dart`, `test/features/listas/ordem_categorias_test.dart`,
`test/features/listas/ordem_categorias_provider_test.dart`, `test/features/listas/listas_repository_test.dart`,
`test/features/listas/historico_precos_repository_test.dart`, `test/features/importacao/modal_previsao_importacao_test.dart`,
`test/core/importacao/parser_lista_local_test.dart`, `test/core/categorias/sugestao_categorias_test.dart`,
`test/core/dominio/categoria_test.dart`, `test/core/dominio/quantidade_test.dart`.

Verificação de que nada sobrou (deve retornar **vazio**):

```bash
grep -rn "features/listas/domain/\(categoria\|quantidade\|unidade\)\.dart\|import '\(categoria\|quantidade\|unidade\)\.dart'" lib test
```

- [ ] **Step 5: Rodar o formatador, o analisador e a suíte**

Run: `dart format . && flutter analyze && flutter test`
Expected: `flutter analyze` sem issues; `flutter test` verde (644+ testes), comprovando que o movimento não mudou comportamento.

- [ ] **Step 6: Commit**

```bash
git add -A lib test
git commit -m "F39-T02: shared kernel em core/dominio elimina inversao core->features (RNF-08)"
```

---

## Task 3: Providers de rede para `convites/providers/`

**Files:**
- Modify: `lib/features/convites/providers/convites_providers.dart`
- Modify: `lib/features/convites/ui/tela_membros_screen.dart` (remover `membrosDaListaProvider`, ~linhas 22-42)
- Modify: `lib/features/convites/ui/convites_pendentes_secao.dart` (remover `meusConvitesPendentesProvider`, ~linhas 18-21)

**Interfaces:**
- Consumes: `ConvitesRepository.membrosDaLista(String) → Future<List<MembroLista>>`, `ConvitesRepository.meusConvitesPendentes() → Future<List<ConvitePendente>>`, `listaPorIdProvider(String)`.
- Produces: `membrosDaListaProvider` (`FutureProvider.family<List<MembroLista>, String>`) e `meusConvitesPendentesProvider` (`FutureProvider<List<ConvitePendente>>`) exportados por `convites/providers/convites_providers.dart`. **Nomes e tipos inalterados** — os consumidores só trocam o import.

- [ ] **Step 1: Confirmar onde `MembroLista` é definido**

Run: `grep -rn "class MembroLista" lib`
Expected: um único arquivo (esperado `lib/features/convites/domain/convite.dart`). Usar esse caminho no import do Step 2.

- [ ] **Step 2: Escrever `convites_providers.dart` com os dois providers**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../listas/providers/listas_providers.dart';
import '../data/convites_repository.dart';
import '../domain/convite.dart';
import '../domain/convite_pendente.dart';
import '../domain/papel.dart';

/// Repositório de convites (doc 08 §2–3, RF-13): chamadas diretas ao
/// servidor, sem fila offline (spec §4.1).
final convitesRepositoryProvider = Provider<ConvitesRepository>((ref) {
  return ConvitesRepository(Supabase.instance.client);
});

/// Meus convites por e-mail pendentes (RF-13, fluxo B, F32).
final meusConvitesPendentesProvider = FutureProvider<List<ConvitePendente>>(
  (ref) => ref.watch(convitesRepositoryProvider).meusConvitesPendentes(),
);

/// Membros da lista (doc 08 §5/§8, F7-T03, RF-13): FutureProvider.family por
/// listaId. O dono é mesclado a partir da lista local (`donoId`) quando o
/// servidor não devolve a linha — a tela nunca fica vazia para listas
/// próprias (offline ou associação pendente).
final membrosDaListaProvider = FutureProvider.family<List<MembroLista>, String>(
  (ref, listaId) async {
    final membros = await ref
        .watch(convitesRepositoryProvider)
        .membrosDaLista(listaId);
    final donoId = ref.watch(listaPorIdProvider(listaId)).value?.donoId;
    if (donoId != null &&
        donoId.isNotEmpty &&
        !membros.any((m) => m.papel == Papel.dono)) {
      return [MembroLista(userId: donoId, papel: Papel.dono), ...membros];
    }
    return membros;
  },
);
```

Ajustar o import de `MembroLista` conforme o resultado do Step 1 (se ficar em `convite.dart`, o import acima já serve).

- [ ] **Step 3: Remover as definições das telas**

Em `lib/features/convites/ui/tela_membros_screen.dart`, apagar o bloco (documentação + `final membrosDaListaProvider = ...` até o `);`, ~linhas 22-42). Em `lib/features/convites/ui/convites_pendentes_secao.dart`, apagar o bloco ~linhas 18-21. Ambos já importam `../providers/convites_providers.dart` (manter).

- [ ] **Step 4: Remover imports órfãos que o analisador apontar**

Run: `flutter analyze`
Expected: inicialmente pode acusar `unused_import` (ex.: `listas_providers.dart` em `tela_membros_screen.dart`, se só era usado pelo provider). Remover exatamente os imports apontados; repetir até `No issues found`.

- [ ] **Step 5: Rodar a suíte das telas afetadas e depois a completa**

Run: `flutter test test/features/convites && flutter test`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/convites
git commit -m "F39-T03: providers de rede saem da UI para convites/providers (RNF-08)"
```

---

## Task 4: Deduplicação — `emailValido` e `Papel.rotulo`

**Files:**
- Create: `lib/core/texto/validacao.dart`
- Create: `test/core/texto/validacao_test.dart`
- Create: `test/features/convites/papel_rotulo_test.dart`
- Modify: `lib/features/convites/domain/papel.dart`
- Modify: `lib/features/auth/ui/login_screen.dart` (~42-43), `lib/features/auth/ui/registro_screen.dart` (~57-58), `lib/features/auth/ui/recuperar_senha_screen.dart` (~34), `lib/features/convites/ui/sheet_convidar.dart` (~131 e ~89-93)
- Modify: `lib/features/convites/ui/tela_membros_screen.dart` (~167), `lib/features/convites/ui/convites_pendentes_secao.dart` (~23-27)

**Interfaces:**
- Consumes: `AppStrings.papelDono`, `AppStrings.convidarPapelEditor`, `AppStrings.convidarPapelLeitor`.
- Produces: `emailValido(String) → bool` em `package:lista_compras/core/texto/validacao.dart`; `Papel.rotulo → String`.

- [ ] **Step 1: Escrever o teste de `emailValido` (falhando)**

`test/core/texto/validacao_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/texto/validacao.dart';

void main() {
  test('deve_aceitar_quando_email_valido', () {
    expect(emailValido('a@b.co'), isTrue);
    expect(emailValido('  a@b.co  '), isTrue);
    expect(emailValido('x.y+z@dominio.com.br'), isTrue);
  });

  test('deve_rejeitar_quando_email_invalido', () {
    expect(emailValido(''), isFalse);
    expect(emailValido('sem-arroba'), isFalse);
    expect(emailValido('a@b'), isFalse);
    expect(emailValido('a b@c.com'), isFalse);
    expect(emailValido('@b.com'), isFalse);
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/core/texto/validacao_test.dart`
Expected: FAIL — `validacao.dart` não existe.

- [ ] **Step 3: Criar `lib/core/texto/validacao.dart`**

```dart
/// Validação de e-mail compartilhada (F39): regex única usada em login,
/// registro, recuperação de senha e convite por e-mail (doc 05).
final RegExp _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

bool emailValido(String valor) => _email.hasMatch(valor.trim());
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/core/texto/validacao_test.dart`
Expected: PASS.

- [ ] **Step 5: Adicionar `Papel.rotulo` e escrever o teste (falhando)**

`test/features/convites/papel_rotulo_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/l10n/app_strings.dart';
import 'package:lista_compras/features/convites/domain/papel.dart';

void main() {
  test('deve_rotular_quando_papel', () {
    expect(Papel.dono.rotulo, AppStrings.papelDono);
    expect(Papel.editor.rotulo, AppStrings.convidarPapelEditor);
    expect(Papel.leitor.rotulo, AppStrings.convidarPapelLeitor);
  });
}
```

Run: `flutter test test/features/convites/papel_rotulo_test.dart`
Expected: FAIL — `rotulo` não existe.

- [ ] **Step 6: Implementar o getter em `lib/features/convites/domain/papel.dart`**

```dart
import '../../../core/l10n/app_strings.dart';

/// Papéis do membro de uma lista (doc 01 §2, CHECK de `lista_membros`).
/// A ordem do enum é a ordem de exibição: dono → editor → leitor.
enum Papel {
  dono,
  editor,
  leitor;

  String get valor => name;

  /// Rótulo exibido (doc 05/10) — fonte única (F39).
  String get rotulo => switch (this) {
    dono => AppStrings.papelDono,
    editor => AppStrings.convidarPapelEditor,
    leitor => AppStrings.convidarPapelLeitor,
  };

  static Papel fromValor(String v) {
    final valores = Papel.values;
    for (final papel in valores) {
      if (papel.name == v) return papel;
    }
    throw ArgumentError('papel desconhecido: $v');
  }
}
```

- [ ] **Step 7: Trocar os 4 usos de regex e os 3 `_rotuloPapel`**

- Em `login_screen.dart` e `registro_screen.dart`: apagar o método `_emailValido` e trocar as chamadas `_emailValido(x)` por `emailValido(x)`; acrescentar `import '../../../core/texto/validacao.dart';` e remover o import de `dart:core`/regex se ficar órfão.
- Em `recuperar_senha_screen.dart`: trocar a expressão inline `RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)` por `emailValido(email)` + import.
- Em `sheet_convidar.dart`: trocar a mesma expressão inline (linha ~131) por `emailValido(email)` + import; apagar o método `_rotuloPapel` (89-93) e trocar as chamadas `_rotuloPapel(x)` por `x.rotulo`.
- Em `tela_membros_screen.dart` e `convites_pendentes_secao.dart`: apagar o respectivo `_rotuloPapel` e trocar as chamadas por `x.rotulo` (o import de `papel.dart` já existe).

Verificação de que não sobrou regex duplicada (deve retornar só `validacao.dart`):

```bash
grep -rn "\^\[^@\\\\s\]" lib
```

- [ ] **Step 8: Rodar a suíte completa**

Run: `dart format . && flutter analyze && flutter test`
Expected: `No issues found` e PASS.

- [ ] **Step 9: Commit**

```bash
git add lib test
git commit -m "F39-T04: emailValido e Papel.rotulo eliminam duplicacoes (RNF-08)"
```

---

## Task 5: Drift — barreiras locais espelhando o Postgres (v7 → v8)

**Files:**
- Modify: `lib/drift/tables/item_local.dart`
- Modify: `lib/drift/tables/lista_local.dart`
- Modify: `lib/drift/database.dart`
- Test: `test/drift/database_test.dart` (adicionar casos ao final)

**Interfaces:**
- Consumes: `AppDatabase`, `itemLocal`, `listaLocal` (existentes).
- Produces: `AppDatabase.schemaVersion == 8`; `ItemLocal.customConstraints`, `ListaLocal.customConstraints`; `_dedupItensAtivos()` privado; índice `uq_item_ativo`.

- [ ] **Step 1: Escrever os testes (falhando) no fim de `test/drift/database_test.dart`**

Adicionar, antes do `}` final do `main`:

```dart
  test('deve_rejeitar_quantidade_zero_quando_check_local_v8', () async {
    await db
        .into(db.listaLocal)
        .insert(
          ListaLocalCompanion.insert(
            id: 'aaaaaaaa-0000-0000-0000-000000000001',
            createdAt: agora,
            updatedAt: agora,
            titulo: 'Lista',
            donoId: 'user-a',
          ),
        );
    expect(
      () => db
          .into(db.itemLocal)
          .insert(
            ItemLocalCompanion.insert(
              id: 'aaaaaaaa-0000-0000-0000-000000000002',
              createdAt: agora,
              updatedAt: agora,
              listaId: 'aaaaaaaa-0000-0000-0000-000000000001',
              nome: 'Zero',
              quantidade: const Value(0),
            ),
          ),
      throwsA(isA<Exception>()),
    );
  });

  test('deve_rejeitar_unidade_fora_do_enum_quando_check_local_v8', () async {
    await db
        .into(db.listaLocal)
        .insert(
          ListaLocalCompanion.insert(
            id: 'bbbbbbbb-0000-0000-0000-000000000001',
            createdAt: agora,
            updatedAt: agora,
            titulo: 'Lista',
            donoId: 'user-a',
          ),
        );
    expect(
      () => db
          .into(db.itemLocal)
          .insert(
            ItemLocalCompanion.insert(
              id: 'bbbbbbbb-0000-0000-0000-000000000002',
              createdAt: agora,
              updatedAt: agora,
              listaId: 'bbbbbbbb-0000-0000-0000-000000000001',
              nome: 'Estranho',
              unidade: const Value('litros'),
            ),
          ),
      throwsA(isA<Exception>()),
    );
  });

  test('deve_criar_indice_uq_item_ativo_quando_instalacao_nova', () async {
    final indice = await db
        .customSelect(
          "SELECT name FROM sqlite_master "
          "WHERE type = 'index' AND name = 'uq_item_ativo'",
        )
        .get();
    expect(indice, isNotEmpty);
  });

  test(
    'deve_deduplicar_e_criar_indice_quando_migrar_v7_para_v8',
    () async {
      final arquivo = File(
        '${Directory.systemTemp.path}/v7_para_v8_${DateTime.now().microsecondsSinceEpoch}.sqlite',
      );
      addTearDown(() {
        if (arquivo.existsSync()) arquivo.deleteSync();
      });

      final antigo = sq3.sqlite3.open(arquivo.path);
      antigo.execute('''
        CREATE TABLE lista_local (
          id TEXT NOT NULL PRIMARY KEY,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          titulo TEXT NOT NULL,
          dono_id TEXT NOT NULL,
          deletado_em TEXT NULL,
          arquivada_em TEXT NULL,
          orcamento_centavos INTEGER NULL,
          FOREIGN KEY (dono_id) REFERENCES lista_local (id) ON DELETE CASCADE
        );
        CREATE TABLE item_local (
          id TEXT NOT NULL PRIMARY KEY,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          lista_id TEXT NOT NULL REFERENCES lista_local (id) ON DELETE CASCADE,
          nome TEXT NOT NULL,
          quantidade REAL NOT NULL DEFAULT 1.0,
          unidade TEXT NOT NULL DEFAULT 'un',
          categoria TEXT NOT NULL DEFAULT 'outros',
          concluido INTEGER NOT NULL DEFAULT 0,
          ordem INTEGER NOT NULL DEFAULT 0,
          deletado_em TEXT NULL,
          preco_centavos INTEGER NULL
        );
        CREATE TABLE mutacao_pendente (
          id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
          tabela TEXT NOT NULL,
          operacao TEXT NOT NULL,
          registro_id TEXT NOT NULL,
          payload TEXT NOT NULL,
          ts_local TEXT NOT NULL,
          tentativas INTEGER NOT NULL DEFAULT 0,
          lista_id TEXT NOT NULL
        );
        CREATE TABLE historico_preco_local (
          nome_normalizado TEXT NOT NULL PRIMARY KEY,
          preco_centavos INTEGER NOT NULL,
          unidade TEXT NOT NULL,
          registrado_em TEXT NOT NULL
        );
        PRAGMA user_version = 7;
      ''');
      antigo.execute(
        "INSERT INTO lista_local (id, created_at, updated_at, titulo, dono_id) "
        "VALUES ('cccccccc-0000-0000-0000-000000000001', "
        "'2026-01-01T00:00:00.000000Z', '2026-01-01T00:00:00.000000Z', "
        "'Antiga', 'user-a')",
      );
      // Duplicatas ativas: 'Arroz' duas vezes (mesma lista, mesmo nome).
      antigo.execute(
        "INSERT INTO item_local (id, created_at, updated_at, lista_id, nome, "
        "quantidade, unidade, categoria, concluido, ordem) VALUES "
        "('dddddddd-0000-0000-0000-000000000001', "
        "'2026-01-01T00:00:00.000000Z', '2026-01-02T00:00:00.000000Z', "
        "'cccccccc-0000-0000-0000-000000000001', 'Arroz', 1.0, 'kg', 'mercearia', 0, 0)",
      );
      antigo.execute(
        "INSERT INTO item_local (id, created_at, updated_at, lista_id, nome, "
        "quantidade, unidade, categoria, concluido, ordem) VALUES "
        "('dddddddd-0000-0000-0000-000000000002', "
        "'2026-01-01T00:00:00.000000Z', '2026-01-01T00:00:00.000000Z', "
        "'cccccccc-0000-0000-0000-000000000001', 'arroz', 2.0, 'kg', 'mercearia', 0, 1)",
      );
      // A pendente pertence à duplicata mais ANTIGA — deve sobreviver por ter fila.
      antigo.execute(
        "INSERT INTO mutacao_pendente (tabela, operacao, registro_id, payload, "
        "ts_local, lista_id) VALUES ('itens_lista', 'INSERT', "
        "'dddddddd-0000-0000-0000-000000000002', '{}', "
        "'2026-01-01T00:00:00.000000Z', 'cccccccc-0000-0000-0000-000000000001')",
      );
      antigo.close();

      final migrado = AppDatabase(NativeDatabase(arquivo));
      addTearDown(migrado.close);

      final itens = await migrado.select(migrado.itemLocal).get();
      expect(itens.length, 1);
      expect(itens.single.id, 'dddddddd-0000-0000-0000-000000000002');

      final fila = await migrado.select(migrado.mutacaoPendente).get();
      expect(fila.length, 1);
      expect(fila.single.registroId, 'dddddddd-0000-0000-0000-000000000002');

      final indice = await migrado
          .customSelect(
            "SELECT name FROM sqlite_master "
            "WHERE type = 'index' AND name = 'uq_item_ativo'",
          )
          .get();
      expect(indice, isNotEmpty);
    },
  );
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/drift/database_test.dart`
Expected: FAIL nos 4 casos novos (sem índice/CHECK, sem dedup; `schemaVersion` ainda 7).

- [ ] **Step 3: Adicionar `customConstraints` em `item_local.dart`**

Acrescentar ao fim da classe `ItemLocal`, após `primaryKey`:

```dart
  @override
  List<String> get customConstraints => [
    'CHECK (quantidade > 0)',
    "CHECK (unidade IN ('un','kg','g','l','ml','caixa','pacote','pct','dz'))",
    "CHECK (categoria IN ('hortifruti','mercearia','frios','laticinios',"
        "'congelados','padaria','bebidas','pet','limpeza','higiene','outros'))",
    'CHECK (preco_centavos IS NULL OR '
        '(preco_centavos >= 0 AND preco_centavos <= 99999999))',
  ];
```

Atualizar o comentário da classe para: `unidade` e `categoria` restritas aos enums fechados e `quantidade > 0` — barreiras espelhadas do Postgres (`0001_init.sql`, `0006`, `0017`), F39.

- [ ] **Step 4: Adicionar `customConstraints` em `lista_local.dart`**

Acrescentar ao fim da classe `ListaLocal`, após `primaryKey`:

```dart
  @override
  List<String> get customConstraints => [
    'CHECK (orcamento_centavos IS NULL OR '
        '(orcamento_centavos >= 0 AND orcamento_centavos <= 99999999))',
  ];
```

- [ ] **Step 5: Atualizar `database.dart` (versão, índice, migração, dedup)**

Trocar `int get schemaVersion => 7;` por:

```dart
  @override
  int get schemaVersion => 8;
```

Adicionar, logo após o `schemaVersion`, a constante e o helper:

```dart
  /// Paridade com o índice único parcial `uq_item_ativo` do Postgres
  /// (`0001_init.sql:57-59`): parcial não é expressável no `@TableIndex`.
  static const _criarIndiceItemAtivo =
      'CREATE UNIQUE INDEX IF NOT EXISTS uq_item_ativo '
      'ON item_local (lista_id, lower(nome)) WHERE deletado_em IS NULL';

  /// Dedup defensivo antes de criar `uq_item_ativo` (F39): mantém 1 item ativo
  /// por `(lista_id, lower(nome))`; prefere a linha com mutação pendente,
  /// depois a de `updated_at` mais recente, depois o maior `rowid`. Remove as
  /// perdedoras **e** suas mutações (o remoto reenvia a verdade ativa).
  Future<void> _dedupItensAtivos() async {
    await customStatement('''
      CREATE TEMP TABLE _dups_grupos AS
      SELECT i.lista_id AS lista_id, lower(i.nome) AS nome_lower
      FROM item_local i
      WHERE i.deletado_em IS NULL
      GROUP BY i.lista_id, lower(i.nome)
      HAVING COUNT(*) > 1
    ''');
    await customStatement('''
      CREATE TEMP TABLE _dups_remover AS
      SELECT i.id AS id
      FROM item_local i
      JOIN _dups_grupos g
        ON g.lista_id = i.lista_id AND g.nome_lower = lower(i.nome)
      WHERE i.deletado_em IS NULL
        AND i.id <> (
          SELECT j.id FROM item_local j
          WHERE j.lista_id = i.lista_id
            AND lower(j.nome) = g.nome_lower
            AND j.deletado_em IS NULL
          ORDER BY
            (SELECT COUNT(*) FROM mutacao_pendente mp
              WHERE mp.registro_id = j.id) DESC,
            j.updated_at DESC,
            j.rowid DESC
          LIMIT 1
        )
    ''');
    await customStatement(
      'DELETE FROM mutacao_pendente WHERE registro_id IN '
      '(SELECT id FROM _dups_remover)',
    );
    await customStatement(
      'DELETE FROM item_local WHERE id IN (SELECT id FROM _dups_remover)',
    );
    await customStatement('DROP TABLE _dups_remover');
    await customStatement('DROP TABLE _dups_grupos');
  }
```

Trocar o `onCreate` e acrescentar o passo `de < 8` no `onUpgrade`:

```dart
    onCreate: (m) async {
      await m.createAll();
      await customStatement(_criarIndiceItemAtivo);
    },
    onUpgrade: (m, de, para) async {
      // ... passos de < 2 até < 7 inalterados ...
      if (de < 8) {
        // v7 → v8: barreiras locais espelhadas do Postgres (F39) —
        // dedup antes de recriar as tabelas com CHECK e de criar o índice.
        await _dedupItensAtivos();
        await m.alterTable(TableMigration(itemLocal));
        await m.alterTable(TableMigration(listaLocal));
        await customStatement(_criarIndiceItemAtivo);
      }
    },
```

- [ ] **Step 6: Rodar o teste do Drift e a suíte completa**

Run: `flutter test test/drift/database_test.dart && flutter test`
Expected: PASS (incluindo os testes de migração v1→…→v7 já existentes).

- [ ] **Step 7: Format, analyze e commit**

```bash
dart format . && flutter analyze
git add lib/drift test/drift
git commit -m "F39-T05: Drift v8 espelha barreiras do Postgres + uq_item_ativo (RNF-08)"
```

---

## Task 6: Docs donos e higiene

**Files:**
- Modify: `docs/05-app-flutter.md` (§2 árvore **linhas 25-53**; nova subseção §2.2)
- Modify: `docs/02-seguranca-rls.md:557`
- Modify: `docs/09-runbook-operacoes.md` (§2, junto ao registro da Fase 38)
- Modify: `docs/03-sincronizacao-offline.md` (§3, tabela local)
- Modify: `.gitignore:10`

**Interfaces:**
- Consumes: o código entregue nas Tasks 2-5 (para documentar a realidade).
- Produces: docs donos coerentes com o código.

- [ ] **Step 1: Substituir a árvore de pastas do `docs/05-app-flutter.md` (bloco ```` ``` ```` das linhas 25-53)**

````markdown
```
lib/
├── main.dart
├── router.dart                      # go_router (rotas, guards de auth)
├── core/
│   ├── config/                      # links por plataforma (ADR-012)
│   ├── dominio/                     # shared kernel: Unidade, CategoriaItem, quantidade (F39)
│   ├── categorias/                  # dicionário + sugestão local de categoria
│   ├── importacao/                  # parser local de lista (F11)
│   ├── l10n/                        # strings (pt-BR) e política de privacidade
│   ├── navigation/                  # shell de navegação e voltar-ao-início
│   ├── observabilidade/             # privacidade do Sentry
│   ├── rede/                        # tratamento de erro de rede (nativo/web)
│   ├── texto/                       # normalização, busca e validação (F39)
│   ├── theme/                       # tema, tokens (Seção 7)
│   ├── utils/                       # deeplink, utilitários de tempo
│   ├── web/                         # URL strategy (web/nativa)
│   └── widgets/                     # componentes compartilhados (App*)
├── features/
│   ├── auth/                        # data/ providers/ ui/
│   ├── configuracoes/               # ui/
│   ├── convites/                    # domain/ data/ providers/ ui/
│   ├── design_system/               # ui/ (catálogo, só em debug)
│   ├── importacao/                  # ui/ (a lógica vive em core/importacao)
│   ├── listas/                      # domain/ data/ providers/ ui/
│   ├── notificacoes/                # domain/ data/ providers/ (F38)
│   ├── onboarding/                  # providers/ ui/
│   ├── sync/                        # domain/ data/ providers/ ui/
│   └── voz/                         # domain/ data/ providers/ (F30)
└── drift/
    ├── database.dart                # AppDatabase (tabelas locais, schemaVersion 8)
    ├── conexao/                     # abrirBancoLocal (nativa/web, ADR-012)
    └── tables/                      # ListaLocal, ItemLocal, MutacaoPendente, HistoricoPrecoLocal
```
````

- [ ] **Step 2: Acrescentar a subseção §2.2 ao `docs/05-app-flutter.md`**

Inserir imediatamente **antes** de `### 2.1. Banco e links por plataforma (ADR-012)`:

```markdown
### 2.2. Forma dos módulos e paridade de barreiras

* **Shared kernel (`core/dominio/`):** o vocabulário fechado (`Unidade`, `CategoriaItem` e os
  helpers de `quantidade`) é compartilhado por Postgres, Dart e o parser local (ADR-005/ADR-011,
  [13 §3](13-premodelo-tecnico.md)). Ele **não** pertence a uma feature: fica em `core/dominio/`, e
  `core/` nunca importa `features/` (F39).
* **Forma dos módulos:** o padrão é `domain/ data/ providers/ ui/`, mas nem todo módulo tem as
  quatro camadas — módulos sem entidade local (`configuracoes`, `importacao`, `design_system`) são
  só `ui/`, e `onboarding` não tem `domain/`/`data/`. O que é obrigatório é a direção da dependência:
  `ui → providers → data` (§2).
* **Barreiras locais espelhando o Postgres:** o Drift replica os `CHECK`s e o índice único parcial
  `uq_item_ativo` do Postgres (`itens_lista`: `quantidade > 0`, `unidade`/`categoria` no enum,
  `preco_centavos` em faixa; `listas`: `orcamento_centavos` em faixa). Migração `schemaVersion 7 → 8`
  (F39) — a dedup de itens ativos é feita antes de criar o índice.
* **`quantidade` é `real` no Drift e `numeric` no Postgres:** divergência aceita — o SQLite não tem
  `DECIMAL`. A precisão efetiva da app é ≤ 3 casas decimais (tolerância 0,001, [05 §6.3]). Nenhuma
  migração de valores.
```

- [ ] **Step 3: Corrigir a linha 557 do `docs/02-seguranca-rls.md`**

Trocar:

```markdown
- [ ] Policies versionadas na migration `0002_rls_policies.sql`.
```

por:

```markdown
- [ ] Policies versionadas em migrations: `0002_rls_policies.sql` (base) e evoluções em `0007`, `0009`, `0012`, `0015` e `0021`.
```

- [ ] **Step 4: Registrar a decisão do `google-services.json` no `docs/09-runbook-operacoes.md` (§2)**

Acrescentar, ao final do sub-bloco da Fase 38 em `§2.6`:

```markdown
- **`google-services.json` (23/09/2026):** `android/app/google-services.json` **permanece rastreado** —
  a API key Android do Firebase não é segredo por si (é restringível no console por package +
  SHA-1). **Ação de segurança (humana):** no console do Firebase, restringir a API key ao package
  `br.com.oliverlucas.listacompras` e aos SHA-1 de debug/release. Arquivos realmente secretos
  (`dart_defines_prod.json`, `android/key.properties`) seguem fora do git.
```

- [ ] **Step 5: Apontar a paridade local no `docs/03-sincronizacao-offline.md` (§3)**

Na tabela local (`§3`, após a lista de tabelas Drift), acrescentar uma linha:

```markdown
* **Barreiras locais:** o Drift replica os `CHECK`s e o índice único parcial `uq_item_ativo` do Postgres — ver [05 §2.2](05-app-flutter.md).
```

- [ ] **Step 6: Corrigir o `.gitignore` (linha 10)**

Trocar a linha `' Generated.xcconfig'` (com espaço inicial) por:

```
Generated.xcconfig
```

- [ ] **Step 7: Verificação e commit**

Run: `grep -n "Generated.xcconfig" .gitignore && git status --porcelain docs .gitignore`
Expected: a linha sem espaço inicial; só os 4 docs e o `.gitignore` modificados.

```bash
git add docs/05-app-flutter.md docs/02-seguranca-rls.md docs/09-runbook-operacoes.md docs/03-sincronizacao-offline.md .gitignore
git commit -m "F39-T06: docs donos refletem shared kernel e barreiras locais (RNF-08)"
```

---

## Task 7: Fechamento — verificação e progresso

**Files:**
- Modify: `docs/14-tarefas.md` (marcar F39-T01…T07; tabela de progresso)

**Interfaces:**
- Consumes: tudo das Tasks 1-6.
- Produces: fase concluída e verificada.

- [ ] **Step 1: Verificação completa local**

Run: `dart format --output=none --set-exit-if-changed . && flutter analyze && flutter test`
Expected: formatação estável; `No issues found`; `flutter test` verde.

- [ ] **Step 2: Confirmar que nada em `supabase/` mudou**

Run: `git diff --stat 1779301..HEAD -- supabase`
Expected: vazio (a fase não toca backend).

- [ ] **Step 3: Marcar as tarefas e atualizar a tabela de progresso em `docs/14-tarefas.md`**

Trocar todos os `- [ ] **F39-T0x**` por `- [x] **F39-T0x**`; na tabela, trocar `| F39 Consistência arquitetural | 7 | 0 |` por `| F39 Consistência arquitetural | 7 | 7 |` e o total para `| **Total** | **203** | **203** |`.

- [ ] **Step 4: Commit e push**

```bash
git add docs/14-tarefas.md
git commit -m "F39-T07: fase 39 concluida e verificada (RNF-08)"
git push
```

- [ ] **Step 5: Confirmar CI verde**

Run: `gh run list --limit 3`
Expected: o run do push mais recente com conclusão `success` (os jobs de SQL e Deno ficam inalterados; o job Flutter deve passar com os novos testes).

---

## Self-Review

**Cobertura da spec:**
- §4 Shared kernel → Task 2. ✔
- §5 Reforço do Drift → Task 5 (+ documentação em Task 6). ✔
- §6 Providers em `providers/` → Task 3. ✔
- §7 Deduplicação → Task 4. ✔
- §8 Docs donos (05, 02, 09, 03) → Task 6. ✔
- §9 Higiene (`.gitignore`) → Task 6. ✔
- §10 Testes/CI → Tasks 2-5, 7. ✔
- §11 Decisões (sem migrar `quantidade`, `google-services` rastreado, `AppMotion` intocado) → Global Constraints + Tasks 5/6. ✔

**Placeholders:** nenhum "TBD"/"implement later"; todo passo de código tem o código.

**Consistência de tipos:** `emailValido(String) → bool` (Task 4) usado nas 4 telas; `Papel.rotulo → String` (Task 4) usado em 3 telas; `membrosDaListaProvider`/`meusConvitesPendentesProvider` mantêm nomes e tipos (Task 3); `_criarIndiceItemAtivo`/`_dedupItensAtivos` definidos e usados só na Task 5; `AppDatabase.schemaVersion` 8 coerente com o teste de migração.
