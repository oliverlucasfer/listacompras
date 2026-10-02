# Atualização do Tutorial para os Recursos Novos — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Estender o tour guiado (RF-27) com uma 3ª etapa na aba Histórico e atualizar as etapas 1 e 2 para cobrir os recursos F49–F55.

**Architecture:** Reusa o motor da F46 (`TourController`/`TourStep`/`TourLoader`/`TourOverlay`). Só muda conteúdo: novo valor em `TourEtapa`, nova flag `tour_etapa3_visto`, 3 `TourKeys` novas, passos/textos em `tour_roteiro.dart` e chaves ARB em pt/en/es. Nenhuma mudança em `TourStep`/`TourOverlay`/`TourLoader`.

**Tech Stack:** Flutter 3.44.5 · Riverpod · gen_l10n (ARB) · SharedPreferences · `flutter_test`.

**Spec:** [`docs/superpowers/specs/2026-10-02-tour-recursos-design.md`](../specs/2026-10-02-tour-recursos-design.md)

## Global Constraints

- **Offline-first local**: nenhuma rede/Drift/schema/migration nesta fase.
- **Enum/idiomas**: pt é template e fallback; **paridade de chaves** entre `app_pt.arb`, `app_en.arb`, `app_es.arb` é obrigatória (teste existente cobra).
- **Textos nunca no roteiro**: `tour_roteiro.dart` guarda só funções `(l) => l.chave` (RF-39, F56).
- **Sem dependência nova** e **sem cor literal** (design system `App*`).
- **Comandos**: `dart format lib test && flutter analyze && flutter test` (o `dart format .` falha por `build/` no Windows; use `lib test`).
- **CI verde** obrigatório; testes nomeados `deve_<resultado>_quando_<condição>`.
- **Commits** em pt-BR referenciando `RF-27`/`F57`.

---

## File Structure

- `lib/features/tour/tour_controller.dart` — `TourEtapa` ganha `historico`; `_chave` ganha `tour_etapa3_visto`; `_passosDe` passa a devolver `passosEtapa3`.
- `lib/features/tour/tour_roteiro.dart` — etapa 1 ganha o passo do Histórico; etapa 2 tem textos/id do menu atualizados; nova `passosEtapa3`.
- `lib/features/tour/tour_keys.dart` — +`abaHistorico`, +`resumoHistorico`, +`abaEstatisticas`.
- `lib/core/navigation/app_shell.dart` — anexa `TourKeys.abaHistorico` à aba de índice 1 (rail e barra).
- `lib/features/historico/ui/historico_screen.dart` — `_Resumo`/aba "Estatísticas" recebem chaves; monta `TourLoader(etapa: historico)`.
- `lib/l10n/app_pt.arb`, `app_en.arb`, `app_es.arb` — novas/ajustadas chaves `tour*` (regera `app_localizations*.dart`).
- `test/features/tour/tour_roteiro_test.dart`, `tour_controller_test.dart`, `tour_gatilho_test.dart` — cobertura.
- `docs/05-app-flutter.md`, `docs/10-wireframes-telas.md`, `docs/12-prd.md`, `docs/14-tarefas.md` — docs donas.

---

### Task 1: Motor — 3ª etapa + strings da etapa 3

**Files:**
- Modify: `lib/features/tour/tour_controller.dart`
- Modify: `lib/features/tour/tour_keys.dart`
- Modify: `lib/features/tour/tour_roteiro.dart`
- Modify: `lib/l10n/app_pt.arb`, `lib/l10n/app_en.arb`, `lib/l10n/app_es.arb` (+ gerados)
- Test: `test/features/tour/tour_controller_test.dart`, `test/features/tour/tour_roteiro_test.dart`

**Interfaces:**
- Produces: `TourEtapa.historico`; flag `tour_etapa3_visto`; `List<TourStep> get passosEtapa3`; `TourKeys.abaHistorico`, `TourKeys.resumoHistorico`, `TourKeys.abaEstatisticas`; getters `tourResumoTitulo`, `tourResumoCorpo`, `tourEstatisticasTitulo`, `tourEstatisticasCorpo` em `AppLocalizations`.

- [ ] **Step 1: Escrever os testes que falham**

Em `test/features/tour/tour_roteiro_test.dart`, adicione ao `main()`:

```dart
  test('deve_ter_dois_passos_na_etapa3_na_ordem_do_historico', () {
    expect(passosEtapa3.map((p) => p.id).toList(), <String>[
      'historico.resumo',
      'historico.estatisticas',
    ]);
  });
```

Em `test/features/tour/tour_controller_test.dart`, adicione:

```dart
  test('deve_marcar_etapa3_sem_afetar_as_outras', () async {
    SharedPreferences.setMockInitialValues({});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await c
        .read(tourEtapaVistaProvider(TourEtapa.historico).notifier)
        .marcarVista(TourEtapa.historico);
    expect(
      await c.read(tourEtapaVistaProvider(TourEtapa.historico).future),
      isTrue,
    );
    expect(
      await c.read(tourEtapaVistaProvider(TourEtapa.primeira).future),
      isFalse,
    );
  });
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/features/tour/tour_roteiro_test.dart test/features/tour/tour_controller_test.dart`
Expected: FAIL (não existe `passosEtapa3` e `TourEtapa.historico`).

- [ ] **Step 3: Adicionar as chaves ARB (pt/en/es)**

Em `lib/l10n/app_pt.arb`, logo após a linha `"tourOrcamentoCorpo": ...` (linha 426), insira:

```json
  "tourResumoTitulo": "Resumo das compras",
  "tourResumoCorpo": "Total gasto, ticket médio e quantas idas você já finalizou.",
  "tourEstatisticasTitulo": "Estatísticas",
  "tourEstatisticasCorpo": "Veja gráficos de gasto por mês e os itens que você mais compra.",
```

Em `lib/l10n/app_en.arb`, no mesmo bloco do tour, insira:

```json
  "tourResumoTitulo": "Shopping summary",
  "tourResumoCorpo": "Total spent, average ticket and how many trips you have finished.",
  "tourEstatisticasTitulo": "Statistics",
  "tourEstatisticasCorpo": "See spending charts per month and the items you buy most.",
```

Em `lib/l10n/app_es.arb`, no mesmo bloco:

```json
  "tourResumoTitulo": "Resumen de compras",
  "tourResumoCorpo": "Total gastado, ticket medio y cuántas idas ya finalizaste.",
  "tourEstatisticasTitulo": "Estadísticas",
  "tourEstatisticasCorpo": "Mira gráficos de gasto por mes y los artículos que más compras.",
```

Rode `flutter gen-l10n` (ou `flutter pub get`) para regenerar `lib/l10n/app_localizations*.dart`.

- [ ] **Step 4: Implementar o motor, as chaves e o roteiro da etapa 3**

Em `lib/features/tour/tour_keys.dart`, adicione os campos:

```dart
  static final abaHistorico = GlobalKey();
  static final resumoHistorico = GlobalKey();
  static final abaEstatisticas = GlobalKey();
```

Em `lib/features/tour/tour_controller.dart`, troque o enum e o mapa de chaves:

```dart
enum TourEtapa { primeira, recursos, historico }

String _chave(TourEtapa e) => switch (e) {
  TourEtapa.primeira => 'tour_etapa1_visto',
  TourEtapa.recursos => 'tour_etapa2_visto',
  TourEtapa.historico => 'tour_etapa3_visto',
};
```

E `_passosDe`:

```dart
  List<TourStep> _passosDe(TourEtapa etapa) => switch (etapa) {
    TourEtapa.primeira => passosEtapa1,
    TourEtapa.recursos => passosEtapa2,
    TourEtapa.historico => passosEtapa3,
  };
```

Em `lib/features/tour/tour_roteiro.dart`, adicione ao final:

```dart
/// Roteiro da etapa 3 (ao abrir a aba Histórico): resumo das compras e a aba
/// de estatísticas. Resolve-se na UI via `context.l10n` (RF-39, F56).
List<TourStep> get passosEtapa3 => <TourStep>[
  TourStep(
    id: 'historico.resumo',
    alvo: TourKeys.resumoHistorico,
    titulo: (l) => l.tourResumoTitulo,
    corpo: (l) => l.tourResumoCorpo,
  ),
  TourStep(
    id: 'historico.estatisticas',
    alvo: TourKeys.abaEstatisticas,
    titulo: (l) => l.tourEstatisticasTitulo,
    corpo: (l) => l.tourEstatisticasCorpo,
  ),
];
```

- [ ] **Step 5: Rodar e ver passar**

Run: `flutter test test/features/tour/tour_roteiro_test.dart test/features/tour/tour_controller_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/tour lib/l10n test/features/tour
git commit -m "feat(tour): 3a etapa (historico) no motor + strings (RF-27, F57)"
```

---

### Task 2: Âncoras nas telas + disparo da etapa 3

**Files:**
- Modify: `lib/core/navigation/app_shell.dart`
- Modify: `lib/features/historico/ui/historico_screen.dart`
- Test: `test/features/tour/tour_gatilho_test.dart`

**Interfaces:**
- Consumes: `TourEtapa.historico`, `TourKeys.abaHistorico/resumoHistorico/abaEstatisticas` (Task 1).
- Produces: aba Histórico ancorada; `TourLoader(etapa: TourEtapa.historico)` montado em `HistoricoScreen`.

- [ ] **Step 1: Escrever os testes que falham**

Em `test/features/tour/tour_gatilho_test.dart`, adicione o import:

```dart
import 'package:lista_compras/features/historico/ui/historico_screen.dart';
```

E, dentro de `main()`, os testes:

```dart
  testWidgets('deve_iniciar_tour_etapa3_quando_flag_falsa', (tester) async {
    final c = container(
      prefs: {
        'onboarding_visto': true,
        'tour_etapa1_visto': true,
        'tour_etapa2_visto': true,
      },
    );

    await tester.pumpWidget(_app(c, const HistoricoScreen()));
    await tester.pumpAndSettle();

    expect(c.read(tourControllerProvider).ativo, isTrue);
    expect(c.read(tourControllerProvider).etapa, TourEtapa.historico);
    expect(c.read(tourControllerProvider).atual?.id, 'historico.resumo');
  });

  testWidgets('nao_deve_iniciar_tour_etapa3_quando_flag_vista', (tester) async {
    final c = container(
      prefs: {
        'onboarding_visto': true,
        'tour_etapa1_visto': true,
        'tour_etapa2_visto': true,
        'tour_etapa3_visto': true,
      },
    );

    await tester.pumpWidget(_app(c, const HistoricoScreen()));
    await tester.pumpAndSettle();

    expect(c.read(tourControllerProvider).ativo, isFalse);
  });
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/features/tour/tour_gatilho_test.dart`
Expected: FAIL (a etapa 3 não dispara; `HistoricoScreen` não monta loader).

- [ ] **Step 3: Ancorar a aba Histórico no shell**

Em `lib/core/navigation/app_shell.dart`, no `NavigationRail` (ícone do índice 1) e no `NavigationBar` (`NavigationDestination` do índice 1), anexe a chave. Substitua os dois pontos que hoje só tratam `indiceConfig` por um helper local. No início de `build`, após `final indiceConfig = rotulos.length - 1;`, adicione:

```dart
    GlobalKey? chaveAba(int i) => switch (i) {
      1 => TourKeys.abaHistorico,
      _ when i == indiceConfig => TourKeys.abaConfiguracoes,
      _ => null,
    };
```

No rail, troque `key: i == indiceConfig ? TourKeys.abaConfiguracoes : null,` por `key: chaveAba(i),`. Na barra, troque `key: i == indiceConfig ? TourKeys.abaConfiguracoes : null,` por `key: chaveAba(i),`.

- [ ] **Step 4: Ancorar e disparar a etapa 3 no Histórico**

Em `lib/features/historico/ui/historico_screen.dart`:

Adicione os imports:

```dart
import '../../tour/tour_controller.dart';
import '../../tour/tour_keys.dart';
import '../../tour/ui/tour_loader.dart';
```

No `Column` do `body`, adicione como **primeiro** filho:

```dart
            const TourLoader(etapa: TourEtapa.historico),
```

Ancore o resumo — troque o `Padding` de `_Resumo` por:

```dart
    return Padding(
      key: TourKeys.resumoHistorico,
      padding: const EdgeInsets.all(AppSpacing.lg),
```

Ancore a aba Estatísticas — troque o `Tab` correspondente por:

```dart
                Tab(key: TourKeys.abaEstatisticas, text: context.l10n.estatisticas),
```

- [ ] **Step 5: Rodar e ver passar**

Run: `flutter test test/features/tour/tour_gatilho_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/core/navigation/app_shell.dart lib/features/historico/ui/historico_screen.dart test/features/tour/tour_gatilho_test.dart
git commit -m "feat(tour): ancora aba Historico e dispara etapa 3 (RF-27, F57)"
```

---

### Task 3: Etapa 1 (passo Histórico) e etapa 2 (textos dos recursos novos)

**Files:**
- Modify: `lib/features/tour/tour_roteiro.dart`
- Modify: `lib/l10n/app_pt.arb`, `lib/l10n/app_en.arb`, `lib/l10n/app_es.arb` (+ gerados)
- Test: `test/features/tour/tour_roteiro_test.dart`, `test/features/tour/tour_gatilho_test.dart`

**Interfaces:**
- Consumes: `TourKeys.abaHistorico` (Task 1/2).
- Produces: getters `tourHistoricoTitulo/Corpo`, `tourMenuTitulo/Corpo`; passo `lista.historico`; passo `recursos.menu` (renomeia `recursos.orcamento`).

- [ ] **Step 1: Atualizar os testes que falham**

Em `test/features/tour/tour_roteiro_test.dart`, troque os dois primeiros testes por:

```dart
  test('deve_ter_quatro_passos_na_etapa1_na_ordem_da_home', () {
    expect(passosEtapa1.map((p) => p.id).toList(), <String>[
      'lista.criar',
      'lista.busca',
      'lista.historico',
      'lista.config',
    ]);
  });

  test('deve_ter_sete_passos_na_etapa2_na_ordem_da_lista', () {
    expect(passosEtapa2.map((p) => p.id).toList(), <String>[
      'recursos.nome',
      'recursos.adicionar',
      'recursos.unidade',
      'recursos.importar',
      'recursos.marcar',
      'recursos.mercado',
      'recursos.menu',
    ]);
  });
```

Em `test/features/tour/tour_gatilho_test.dart`, no teste `deve_navegar_para_home_e_rodar_etapa1_quando_reabrir`, troque `expect(c.read(tourControllerProvider).passos.length, 3);` por `expect(c.read(tourControllerProvider).passos.length, 4);`.

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/features/tour/tour_roteiro_test.dart test/features/tour/tour_gatilho_test.dart`
Expected: FAIL (ainda 3 passos na etapa 1; id `recursos.orcamento`).

- [ ] **Step 3: Atualizar as chaves ARB**

Em `lib/l10n/app_pt.arb`:

- Remova as linhas `"tourOrcamentoTitulo": ...` e `"tourOrcamentoCorpo": ...` (425–426).
- Substitua as linhas `tourImportarTitulo`, `tourImportarCorpo`, `tourConfigCorpo`, `tourMercadoCorpo` por:

```json
  "tourImportarTitulo": "Importe de texto ou foto",
  "tourImportarCorpo": "Digite, cole uma anotação ou fotografe a lista; o app organiza os itens para você.",
  "tourConfigCorpo": "Tema, idioma (português, inglês, espanhol), backup, widget da tela inicial e onde rever este tutorial.",
  "tourMercadoCorpo": "No mercado, marque as compras e registre o preço pago. O app guarda o preço por mercado.",
```

- Adicione, na mesma região:

```json
  "tourHistoricoTitulo": "Histórico de compras",
  "tourHistoricoCorpo": "Suas compras finalizadas e as estatísticas ficam nesta aba.",
  "tourMenuTitulo": "Menu da lista",
  "tourMenuCorpo": "Aqui: orçamento, compartilhar (link/QR) e finalizar a compra — que vai para o Histórico. Se uma categoria estourar o limite, aparece um alerta abaixo do total.",
```

Em `lib/l10n/app_en.arb` (remova `tourOrcamentoTitulo`/`tourOrcamentoCorpo`; ajuste e adicione):

```json
  "tourImportarTitulo": "Import from text or photo",
  "tourImportarCorpo": "Type, paste a note or photograph the list; the app organizes the items for you.",
  "tourConfigCorpo": "Theme, language (Portuguese, English, Spanish), backup, home-screen widget and where to replay this tutorial.",
  "tourMercadoCorpo": "At the store, check items off and record the price paid. The app keeps the price per store.",
  "tourHistoricoTitulo": "Purchase history",
  "tourHistoricoCorpo": "Your finished purchases and the statistics live in this tab.",
  "tourMenuTitulo": "List menu",
  "tourMenuCorpo": "Here: budget, share (link/QR) and finish the purchase — it goes to History. If a category goes over its limit, an alert appears below the total.",
```

Em `lib/l10n/app_es.arb`:

```json
  "tourImportarTitulo": "Importa de texto o foto",
  "tourImportarCorpo": "Escribe, pega una nota o fotografía la lista; la app organiza los artículos por ti.",
  "tourConfigCorpo": "Tema, idioma (portugués, inglés, español), copia de seguridad, widget de la pantalla de inicio y dónde repetir este tutorial.",
  "tourMercadoCorpo": "En el mercado, marca las compras y registra el precio pagado. La app guarda el precio por mercado.",
  "tourHistoricoTitulo": "Historial de compras",
  "tourHistoricoCorpo": "Tus compras finalizadas y las estadísticas están en esta pestaña.",
  "tourMenuTitulo": "Menú de la lista",
  "tourMenuCorpo": "Aquí: presupuesto, compartir (enlace/QR) y finalizar la compra — que pasa al Historial. Si una categoría supera el límite, aparece un aviso bajo el total.",
```

Rode `flutter gen-l10n` para regenerar.

- [ ] **Step 4: Atualizar o roteiro**

Em `lib/features/tour/tour_roteiro.dart`, na `passosEtapa1`, insira o passo do Histórico **entre** `lista.busca` e `lista.config`:

```dart
  TourStep(
    id: 'lista.historico',
    alvo: TourKeys.abaHistorico,
    titulo: (l) => l.tourHistoricoTitulo,
    corpo: (l) => l.tourHistoricoCorpo,
  ),
```

Na `passosEtapa2`, troque o último passo (`recursos.orcamento`) por:

```dart
  TourStep(
    id: 'recursos.menu',
    alvo: TourKeys.menuMais,
    titulo: (l) => l.tourMenuTitulo,
    corpo: (l) => l.tourMenuCorpo,
  ),
```

- [ ] **Step 5: Rodar e ver passar**

Run: `flutter test test/features/tour/`
Expected: PASS (roteiro, gatilho, controller e overlay).

- [ ] **Step 6: Commit**

```bash
git add lib/features/tour/tour_roteiro.dart lib/l10n test/features/tour
git commit -m "feat(tour): etapa 1 com Historico e etapa 2 com recursos novos (RF-27, F57)"
```

---

### Task 4: Docs donas e fechamento

**Files:**
- Modify: `docs/05-app-flutter.md` (§6.11)
- Modify: `docs/10-wireframes-telas.md` (tour: etapa 1/2 e Histórico)
- Modify: `docs/12-prd.md` (RF-27)
- Modify: `docs/14-tarefas.md` (Fase 57 + tabela de progresso)

- [ ] **Step 1: Atualizar o doc 05 §6.11**

Em `docs/05-app-flutter.md` §6.11 (tour guiado), atualize: o roteiro passa a ter **3 etapas** — etapa 1 (home) com 4 passos (criar, busca, **Histórico**, configurações), etapa 2 (lista) com 7 passos (importar de texto/foto; mercado com preço; **menu da lista** com orçamento/compartilhar/finalizar/alertas) e **etapa 3** (aba Histórico) com resumo e estatísticas. Registre a flag `tour_etapa3_visto` e que a etapa 3 dispara ao abrir a aba (sem navegação forçada).

- [ ] **Step 2: Atualizar o doc 10**

Em `docs/10-wireframes-telas.md`: na nota do tour da home, inclua o spot da aba Histórico (`TourKeys.abaHistorico`); na seção da tela da lista, atualize o passo do menu (título "Menu da lista"); e na seção **Histórico**, adicione a nota do **tour etapa 3** (`TourKeys.resumoHistorico` no resumo e `TourKeys.abaEstatisticas` na aba Estatísticas).

- [ ] **Step 3: Atualizar o doc 12 (RF-27)**

Em `docs/12-prd.md`, na linha do RF-27, ajuste a descrição para "**tour guiado interativo do primeiro uso (3 etapas: home, lista e Histórico)**".

- [ ] **Step 4: Registrar a Fase 57 no doc 14**

Em `docs/14-tarefas.md`, ao final (após a Fase 56), adicione a fase:

```markdown
## Fase 57 — Atualização do tutorial para os recursos novos (RF-27)

- [x] **F57-T01** — Motor: 3ª etapa (`historico`) + flag + strings da etapa 3
  Dep: F56-T06 · Docs: [05 §6.11](05-app-flutter.md)
  CP: `TourEtapa.historico`/`tour_etapa3_visto`; `passosEtapa3`; chaves ARB pt/en/es; testes de roteiro/controller verdes.
- [x] **F57-T02** — Âncoras no shell/Histórico + disparo da etapa 3
  Dep: F57-T01 · Docs: [10](10-wireframes-telas.md)
  CP: `TourKeys.abaHistorico/resumoHistorico/abaEstatisticas` ancoradas; `TourLoader(historico)`; testes de gatilho verdes.
- [x] **F57-T03** — Etapa 1 (+Histórico) e etapa 2 (textos novos)
  Dep: F57-T02 · Docs: [05 §6.11](05-app-flutter.md), [10](10-wireframes-telas.md), [12](12-prd.md)
  CP: etapa 1 com 4 passos; etapa 2 com importar/foto, preço por mercado e menu ⋮; ARB atualizado; testes verdes.
- [x] **F57-T04** — Docs donas e fechamento
  Dep: F57-T03 · Docs: 05, 10, 12, 14
  CP: docs sincronizadas; `dart format lib test`/`flutter analyze`/`flutter test` verdes.
```

E atualize a tabela de progresso: adicione `| F57 Atualização do tutorial | 4 | 4 |` e some +4 ao **Total** (linha `| **Total** | ... |`).

- [ ] **Step 5: Verificação final**

Run:
```bash
dart format lib test
flutter analyze
flutter test
flutter build apk --debug
```
Expected: format sem mudanças; analyze "No issues"; todos os testes passam; APK debug compila.

- [ ] **Step 6: Commit**

```bash
git add docs
git commit -m "docs(tour): 3 etapas e recursos novos nas docs donas (RF-27, F57)"
```

---

## Self-Review

**Spec coverage:**
- 3ª etapa no Histórico → Tasks 1–2.
- Etapa 1 com passo Histórico + Config (idioma/widget) → Task 3.
- Etapa 2 enriquecida (OCR, preço por mercado, menu ⋮ com compartilhar/finalizar/alertas) → Task 3.
- Âncoras novas (`abaHistorico`, `resumoHistorico`, `abaEstatisticas`) → Tasks 1–2.
- Flag `tour_etapa3_visto` + disparo sem navegação forçada → Tasks 1–2.
- i18n pt/en/es com paridade → Tasks 1, 3.
- Docs donas 05/10/12/14 → Task 4.
- "Sem motor novo / sem passo dedicado ao widget (menção textual)" → respeitado.

**Placeholder scan:** sem TBD/TODO; todos os passos trazem código/comando.

**Type consistency:** `passosEtapa3`, `TourEtapa.historico`, `tour_etapa3_visto`, `TourKeys.abaHistorico/resumoHistorico/abaEstatisticas`, `tourResumoTitulo/Corpo`, `tourEstatisticasTitulo/Corpo`, `tourHistoricoTitulo/Corpo`, `tourMenuTitulo/Corpo` — usados de forma idêntica entre tasks.
