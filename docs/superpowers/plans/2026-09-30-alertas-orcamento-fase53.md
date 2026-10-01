# Alertas de Orçamento — Fase 53 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Alertar progressivamente sobre o orçamento (normal → aviso ≥80% → acima ≥100%), avisar ao cruzar o limite, permitir **orçamento por categoria** e emitir uma **notificação local** ao ultrapassar — tudo offline.

**Architecture:** Funções puras de estado/cruzamento em `domain/orcamento.dart`; `TotalCarrinho` passa a usar o estado; um `SnackBar` ao cruzar (lista e modo mercado); uma tabela local `orcamento_categoria` (Drift v13→v14) com tela própria; notificação local via `flutter_local_notifications` atrás de um contrato injetável. **Depende da Fase 52** (`mercado` já em `main`).

**Tech Stack:** Flutter, Riverpod, Drift/SQLite, `flutter_local_notifications`.

**Spec:** `docs/superpowers/specs/2026-09-30-preco-mercado-orcamento-design.md` (RF-36 / Fase 53)

## Global Constraints

- App 100% local: **nenhuma** rede; a única dependência nova é **`flutter_local_notifications`** (offline), só na Task 5.
- Limiar de aviso **80%** (constante `limiarAvisoOrcamento = 0.8`); "acima" quando o total **excede** o orçamento.
- Valores monetários: só itens **com preço** (`quantidade × preço` arredondado) — regra do `totalCarrinho`.
- Categorias: enum fechado `CategoriaItem`.
- Notificação é **local** (Android/iOS); Web/Desktop caem só nos alertas in-app; testada com **fake**.
- `App*` componentes/tokens + `AppStrings`; pt-BR; testes `deve_<resultado>_quando_<condição>`.

---

## File Structure

- `lib/features/listas/domain/orcamento.dart` — `EstadoOrcamento`, `estadoOrcamento`, `cruzouLimite`, `subtotalMarcado`.
- `lib/features/listas/ui/total_carrinho.dart` (progressivo) · `tela_lista_screen.dart`/`mercado_screen.dart` (SnackBar ao cruzar).
- `lib/features/listas/data/orcamento_categoria_repository.dart` + `lib/drift/tables/orcamento_categoria.dart` (v14) · provider.
- `lib/features/listas/ui/tela_orcamento_categorias.dart` (rota `/orcamento-categorias`) + alerta por categoria.
- `lib/features/notificacoes/domain/notificacao_local.dart` + `data/notificacao_local_plugin.dart` + provider.
- `lib/core/l10n/app_strings.dart`, `android/app/src/main/AndroidManifest.xml`, `ios/Runner/Info.plist`, docs.

---

## Task 1: Domínio e funções puras do orçamento

**Files:**
- Create: `lib/features/listas/domain/orcamento.dart`
- Test: `test/features/listas/orcamento_domain_test.dart`

**Interfaces:**
- Consumes: `Item` (`lib/features/listas/domain/item.dart`).
- Produces: `enum EstadoOrcamento { semOrcamento, normal, aviso, acima }`; `const double limiarAvisoOrcamento = 0.8;`; `EstadoOrcamento estadoOrcamento(int total, int? orcamento)`; `bool cruzouLimite({required int antes, required int depois, required int? orcamento})`; `int subtotalMarcado(Item item)`.

- [ ] **Step 1: Write the failing test**

`test/features/listas/orcamento_domain_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/dominio/unidade.dart';
import 'package:lista_compras/features/listas/domain/item.dart';
import 'package:lista_compras/features/listas/domain/orcamento.dart';

Item _item({double qtd = 1, int? preco, bool concluido = true}) => Item(
      id: 'i', listaId: 'l', nome: 'x', quantidade: qtd,
      unidade: Unidade.un, categoria: CategoriaItem.outros,
      concluido: concluido, ordem: 0,
      criadoEm: DateTime.utc(2026), atualizadoEm: DateTime.utc(2026),
      precoCentavos: preco,
    );

void main() {
  test('deve_ser_sem_orcamento_quando_nao_ha_limite', () {
    expect(estadoOrcamento(5000, null), EstadoOrcamento.semOrcamento);
  });

  test('deve_ser_normal_quando_abaixo_do_limiar', () {
    expect(estadoOrcamento(7000, 10000), EstadoOrcamento.normal); // 70%
  });

  test('deve_ser_aviso_quando_atinge_80_por_cento', () {
    expect(estadoOrcamento(8000, 10000), EstadoOrcamento.aviso);
    expect(estadoOrcamento(9999, 10000), EstadoOrcamento.aviso);
  });

  test('deve_ser_acima_quando_excede_o_orcamento', () {
    expect(estadoOrcamento(10001, 10000), EstadoOrcamento.acima);
  });

  test('deve_ser_acima_quando_orcamento_zero_e_total_positivo', () {
    expect(estadoOrcamento(1, 0), EstadoOrcamento.acima);
    expect(estadoOrcamento(0, 0), EstadoOrcamento.normal);
  });

  test('deve_detectar_cruzamento_apenas_ao_passar_o_limite', () {
    expect(cruzouLimite(antes: 9000, depois: 11000, orcamento: 10000), isTrue);
    expect(cruzouLimite(antes: 11000, depois: 12000, orcamento: 10000), isFalse);
    expect(cruzouLimite(antes: 9000, depois: 9500, orcamento: 10000), isFalse);
    expect(cruzouLimite(antes: 9000, depois: 11000, orcamento: null), isFalse);
  });

  test('deve_calcular_subtotal_apenas_com_preco', () {
    expect(subtotalMarcado(_item(qtd: 2, preco: 500)), 1000);
    expect(subtotalMarcado(_item(qtd: 2, preco: null)), 0);
  });
}
```

(Adicionar `import 'package:lista_compras/core/dominio/categoria.dart';`.)

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/listas/orcamento_domain_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

`lib/features/listas/domain/orcamento.dart`:

```dart
import 'item.dart';

enum EstadoOrcamento { semOrcamento, normal, aviso, acima }

/// Fração do orçamento a partir da qual o estado vira "aviso" (RF-36).
const double limiarAvisoOrcamento = 0.8;

EstadoOrcamento estadoOrcamento(int total, int? orcamento) {
  if (orcamento == null) return EstadoOrcamento.semOrcamento;
  if (total > orcamento) return EstadoOrcamento.acima;
  if (orcamento > 0 && total >= (orcamento * limiarAvisoOrcamento).ceil()) {
    return EstadoOrcamento.aviso;
  }
  return EstadoOrcamento.normal;
}

/// Verdadeiro quando o total passa de ≤ orçamento para > orçamento.
bool cruzouLimite({required int antes, required int depois, required int? orcamento}) {
  if (orcamento == null) return false;
  return antes <= orcamento && depois > orcamento;
}

/// Subtotal de um item marcado com preço (0 se sem preço).
int subtotalMarcado(Item item) {
  final preco = item.precoCentavos;
  return preco == null ? 0 : (item.quantidade * preco).round();
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/listas/orcamento_domain_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/listas/domain/orcamento.dart test/features/listas/orcamento_domain_test.dart
git commit -m "feat(orcamento): estado progressivo e cruzamento (RF-36, F53)"
```

---

## Task 2: `TotalCarrinho` progressivo

**Files:**
- Modify: `lib/features/listas/ui/total_carrinho.dart`
- Modify: `lib/core/l10n/app_strings.dart`
- Test: `test/features/listas/total_carrinho_progressivo_test.dart`

**Interfaces:**
- Consumes: `estadoOrcamento`, `EstadoOrcamento`, `formatarReais`, `itensDaListaProvider`, `listaPorIdProvider`.
- Produces: `TotalCarrinho` com estado **normal/aviso/acima** (cor/ícone/barras).

- [ ] **Step 1: Add strings**

```dart
  // Alertas de orçamento (RF-36, F53)
  static const orcamentoAtencao = 'Perto do orçamento';
  static String orcamentoCruzado(String total) =>
      'Você passou do orçamento: $total';
  static const orcamentoPorCategoria = 'Orçamento por categoria';
  static const limitePorCategoria = 'Limite (R\$)';
  static const categoriaSemLimite = 'Sem limite';
  static const orcamentosSalvos = 'Limites por categoria salvos.';
  static const acimaDoLimiteDaCategoria = 'Acima do limite da categoria';
  static const notificacoesOrcamento = 'Notificações de orçamento';
```

- [ ] **Step 2: Write the failing widget test**

`test/features/listas/total_carrinho_progressivo_test.dart` — com lista + orçamento, monta `TotalCarrinho` em três cenários de total (abaixo, ~80%, acima) e asserta os textos/ícones (`Aparece 'Acima do orçamento'` acima; `'Perto do orçamento'` no aviso; nenhum dos dois abaixo). Reuse o harness dos testes de `total_carrinho` existentes.

- [ ] **Step 3: Implement**

Em `total_carrinho.dart`, derivar `estado = estadoOrcamento(total, orcamento)` e:
- `semOrcamento` → linha atual (`totalNoCarrinho`).
- `normal` → mostra `totalComOrcamento`, barra com cor padrão.
- `aviso` → cor de atenção (ex.: `colorScheme.tertiary`), ícone `Icons.notification_important_outlined`, texto `AppStrings.orcamentoAtencao` (além do `totalComOrcamento`).
- `acima` → comportamento atual (`colorScheme.error`, `Icons.warning_amber_rounded`, `AppStrings.acimaDoOrcamento`).
Mantenha `Semantics(liveRegion: true)`.

- [ ] **Step 4: Run tests, format and analyze**

Run: `flutter test test/features/listas/total_carrinho_progressivo_test.dart && dart format . && flutter analyze && flutter test`
Expected: verde.

- [ ] **Step 5: Commit**

```bash
git add lib/features/listas/ui/total_carrinho.dart lib/core/l10n/app_strings.dart test/features/listas
git commit -m "feat(orcamento): total do carrinho progressivo (RF-36, F53)"
```

---

## Task 3: SnackBar ao cruzar o orçamento (lista e modo mercado)

**Files:**
- Create: `lib/features/listas/ui/aviso_orcamento.dart` (helper)
- Modify: `lib/features/listas/ui/tela_lista_screen.dart`, `lib/features/listas/ui/mercado_screen.dart`
- Test: `test/features/listas/cruzou_orcamento_test.dart`

**Interfaces:**
- Consumes: `cruzouLimite`, `subtotalMarcado`, `totalCarrinho`, `itensDaListaProvider`, `listaPorIdProvider`, `mostrarSnackBar`, `notificacaoLocalProvider` (Task 5).
- Produces: `Future<void> talvezAvisarCruzamento(WidgetRef ref, BuildContext context, String listaId, {required Item item, required bool marcando})`.

- [ ] **Step 1: Write the failing widget test**

`test/features/listas/cruzou_orcamento_test.dart` — lista com orçamento `R$10,00`; item com preço `R$6,00` marcado → total R$6 (≤10, sem aviso); marca um segundo item `R$6,00` → total R$12 (>10) → **SnackBar** `orcamentoCruzado` visível. Verifica também que marcar um terceiro item (já acima) **não** re-dispara. (Harness da tela da lista; `fechar(tester)`.)

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/listas/cruzou_orcamento_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

`lib/features/listas/ui/aviso_orcamento.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../domain/item.dart';
import '../domain/orcamento.dart';
import '../domain/preco.dart';
import '../providers/listas_providers.dart';

/// Mostra o aviso (e dispara a notificação local) quando marcar/desmarcar um
/// item faz o total cruzar o orçamento. Chamar **antes** da escrita, passando
/// a lista de itens atual e o item alvo.
Future<void> talvezAvisarCruzamento(
  BuildContext context,
  WidgetRef ref,
  String listaId, {
  required List<Item> itens,
  required Item item,
  required bool marcando,
}) async {
  final orcamento = ref.read(listaPorIdProvider(listaId)).value?.orcamentoCentavos;
  if (orcamento == null) return;
  final antes = totalCarrinho(itens);
  final subtotal = subtotalMarcado(item);
  final depois = marcando ? antes + subtotal : antes - subtotal;
  if (!cruzouLimite(antes: antes, depois: depois, orcamento: orcamento)) return;
  if (context.mounted) {
    mostrarSnackBar(context, AppStrings.orcamentoCruzado(formatarReais(depois)));
  }
}
```

Em `tela_lista_screen.dart` (`_ItemLinha` checkbox) e `mercado_screen.dart` (`_marcar`/`_desmarcar`): antes de chamar `editarItem`, chame `talvezAvisarCruzamento(context, ref, listaId, itens: <itens atuais>, item: item, marcando: <bool>)`. Na lista, os itens atuais vêm de `ref.read(itensDaListaProvider(listaId)).value ?? const []`; no mercado, de `itens` já disponível.

> A notificação local (Task 5) é adicionada **dentro** de `talvezAvisarCruzamento` quando aquele provider existir; nesta task deixe o SnackBar e um ponto de extensão.

- [ ] **Step 4: Run tests, format and analyze**

Run: `flutter test test/features/listas/cruzou_orcamento_test.dart && dart format . && flutter analyze && flutter test`
Expected: verde.

- [ ] **Step 5: Commit**

```bash
git add lib/features/listas/ui test/features/listas
git commit -m "feat(orcamento): aviso ao cruzar o limite (RF-36, F53)"
```

---

## Task 4: Orçamento por categoria (Drift v14 + tela + alerta)

**Files:**
- Create: `lib/drift/tables/orcamento_categoria.dart`
- Modify: `lib/drift/database.dart` (regen), `lib/router.dart`, `lib/features/configuracoes/ui/configuracoes_screen.dart`
- Create: `lib/features/listas/data/orcamento_categoria_repository.dart`, `lib/features/listas/ui/tela_orcamento_categorias.dart`
- Modify: `lib/features/listas/providers/listas_providers.dart`, `lib/features/listas/ui/tela_lista_screen.dart` (alerta por categoria)
- Test: `test/features/listas/orcamento_categoria_test.dart`

**Interfaces:**
- Produces: tabela `OrcamentoCategoria` (`categoria` PK, `limiteCentavos` int nullable); `LimitesCategoriaRepository.definir(categoria, {int? centavos})`, `Future<Map<CategoriaItem,int>> limites()`, `Stream<Map<CategoriaItem,int>> watchLimites()`; providers; rota `/orcamento-categorias`.

- [ ] **Step 1: Write the failing test**

`test/features/listas/orcamento_categoria_test.dart` — repo: definir limite de `mercearia` e ler; limpar; e a função de alerta: dado o subtotal marcado por categoria `> limite`, retorna as categorias estouradas. (Drift in-memory.)

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/listas/orcamento_categoria_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

- Tabela (v13→v14, `de == 13`):

```dart
class OrcamentoCategoria extends Table {
  TextColumn get categoria => text()();       // enum CategoriaItem (valor)
  IntColumn get limiteCentavos => integer().nullable()();
  @override
  Set<Column> get primaryKey => {categoria};
}
```
Migração: `if (de == 13) { await m.createTable(orcamentoCategoria); }` (mesmo padrão `de == X` da F52) + registre em `@DriftDatabase` + regen.

- Repositório `LimitesCategoriaRepository` (upsert por `categoria`, `limiteCentavos` nulo = sem limite) + provider.
- Função pura `categoriasAcimaDoLimite({required Map<CategoriaItem,int> subtotais, required Map<CategoriaItem,int> limites})` → `Set<CategoriaItem>` (subtotal > limite).
- Tela `TelaOrcamentoCategorias` (rota `/orcamento-categorias`), acessível de Configurações ("Orçamento por categoria"): lista das 11 categorias com campo em R$ e Salvar/limpar.
- Alerta na tela da lista: quando `categoriasAcimaDoLimite(...)` não vazio, mostra um `AppBanner`/linha destacando as categorias estouradas (abaixo do `TotalCarrinho`).

- [ ] **Step 4: Run tests, format and analyze**

Run: `flutter test test/features/listas/orcamento_categoria_test.dart && dart format . && flutter analyze && flutter test`
Expected: verde (inclui regeneração do `database.g.dart`).

- [ ] **Step 5: Commit**

```bash
git add lib/drift lib/features/listas lib/features/configuracoes lib/router.dart test
git commit -m "feat(orcamento): limite por categoria (RF-36, F53)"
```

---

## Task 5: Notificação local ao cruzar o orçamento

**Files:**
- Modify: `pubspec.yaml` (`flutter pub add flutter_local_notifications`), `android/app/src/main/AndroidManifest.xml` (`POST_NOTIFICATIONS`), `ios/Runner/Info.plist` (se necessário)
- Create: `lib/features/notificacoes/domain/notificacao_local.dart`, `lib/features/notificacoes/data/notificacao_local_plugin.dart`, `lib/features/notificacoes/providers/notificacao_providers.dart`
- Modify: `lib/features/listas/ui/aviso_orcamento.dart` (dispara a notificação)
- Test: `test/features/notificacoes/notificacao_orcamento_test.dart`

**Interfaces:**
- Consumes: `flutter_local_notifications`, `defaultTargetPlatform`/`kIsWeb`.
- Produces: `abstract interface class NotificacaoLocal { Future<bool> pedirPermissao(); Future<void> mostrar({required String titulo, required String corpo}); }`; `NotificacaoLocalPlugin`; `plataformaComNotificacao()` (Android/iOS); `notificacaoLocalProvider`.

- [ ] **Step 1: Add dependency + permission**

Run: `flutter pub add flutter_local_notifications`
Em `AndroidManifest.xml`: `<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>`.
iOS: garantir o pedido de permissão (o plugin cuida; sem chave nova obrigatória no Info.plist para notificação local).

- [ ] **Step 2: Write the failing test**

`test/features/notificacoes/notificacao_orcamento_test.dart` — com um `FakeNotificacaoLocal` (registra chamadas) injetado em `notificacaoLocalProvider`, ao cruzar o orçamento a notificação é chamada **uma vez**; sem cruzar, não é chamada. (Harness da lista; `fechar(tester)`.)

- [ ] **Step 3: Implement**

`notificacao_local.dart` (contrato acima). `notificacao_local_plugin.dart` usando `FlutterLocalNotificationsPlugin` (init + `requestNotificationsPermission` no Android 13+, `mostrar` com um id fixo). `notificacao_providers.dart` com `plataformaComNotificacao()` (mirror de `plataformaComVoz`) e `notificacaoLocalProvider`.

Em `talvezAvisarCruzamento`, após o SnackBar: se `plataformaComNotificacao()`, chamar (best-effort, `try/catch`) `ref.read(notificacaoLocalProvider).mostrar(titulo: AppStrings.orcamento, corpo: AppStrings.orcamentoCruzado(...))`.

- [ ] **Step 4: Run tests + builds**

Run: `flutter test test/features/notificacoes/notificacao_orcamento_test.dart && dart format . && flutter analyze && flutter test`
Also: `flutter build apk --debug` e `flutter build web --release` (garantir que o plugin não quebra Web; se quebrar, isolar o import com conditional import/stub mantendo o contrato).

- [ ] **Step 5: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/features/notificacoes lib/features/listas/ui/aviso_orcamento.dart android/app/src/main/AndroidManifest.xml ios/Runner/Info.plist test
git commit -m "feat(orcamento): notificacao local ao cruzar (RF-36, F53)"
```

---

## Task 6: Docs donos e fechamento da Fase 53

**Files:** `docs/12-prd.md` (RF-36 + matriz), `docs/05-app-flutter.md` (§6.15 alertas; v14; notificação), `docs/10-wireframes-telas.md` (estados do total; orçamento por categoria; tela), `docs/09-runbook-operacoes.md` (dep/permissão), `docs/15-design-system.md` (estado de aviso, se necessário), `docs/14-tarefas.md` (Fase 53 + progresso), `docs/16-roadmap-pos-mvp.md` (frente concluída).

- [ ] **Step 1–3:** add RF-36 (tabela+matriz); doc 05 §6.15 (progressivo 80/100, SnackBar, orçamento por categoria, notificação local, `flutter_local_notifications`, migração v14); doc 10 (estados do total, tela de orçamento por categoria); doc 09 (dep + `POST_NOTIFICATIONS`); doc 14 (Fase 53 T01–T06 + progresso; Total atual 284/282 → 290/288); doc 16 (A11 concluído).

- [ ] **Step 4: Verify**

Run: `dart format . && flutter analyze && flutter test`
Expected: tudo verde.

- [ ] **Step 5: Commit**

```bash
git add docs
git commit -m "docs(orcamento): RF-36, 05, 09, 10, 14 e 16 (F53)"
```

---

## Self-Review (cobertura da spec §2/§6 — Fase 53)

- Progressivo 80%/100% → Tasks 1/2.
- SnackBar ao cruzar → Task 3.
- Orçamento por categoria → Task 4.
- Notificação local → Task 5.
- Deps/permissões (§8) → Task 5; testes §9 (unit/widget/fake) → Tasks 1–5.
- **Fecha a frente RF-35/RF-36** (F52+F53).

## Documentos relacionados
- Spec: `docs/superpowers/specs/2026-09-30-preco-mercado-orcamento-design.md`
- [05 App Flutter](../05-app-flutter.md) · [10 Wireframes](../10-wireframes-telas.md) · [12 PRD](../12-prd.md) · [14 Tarefas](../14-tarefas.md)
