# Tour guiado interativo (primeiro uso) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Criar um tour guiado (overlay com spotlight) que ensina a usar o app na primeira vez, em 2 etapas, pulando passos conforme o modo, reabrível em Configurações.

**Architecture:** Motor próprio (sem dependência nova) em `lib/features/tour/`: um `TourStep` (alvo por `GlobalKey` + textos), um `TourController` (Riverpod, sem rede/Drift) com a fila de passos elegíveis, e um `TourOverlay` (Spotlight + bolha `App*`) montado no `Overlay` da tela. Cada etapa roda **dentro de uma tela** — o motor não navega. Conclusão por flags em SharedPreferences (espelho de `OnboardingNotifier`).

**Tech Stack:** Flutter 3.44.x / Dart 3.12, Riverpod, Material 3, SharedPreferences, flutter_test.

**Spec:** `docs/superpowers/specs/2026-09-28-tour-guiado-primeiro-uso-design.md`

## Global Constraints

- **Sem dependência nova**; sem migration/schema/sync (nenhuma mudança em `supabase/`).
- **Enum de unidades fechado:** `un, kg, g, l, ml, caixa, pacote, pct, pt, dz` (o passo de unidade só aponta o seletor; nada a alterar).
- **Sem cor literal:** usar tokens (`AppSpacing`/`AppRadius`/`AppElevation`) e `colorScheme` ([15]). Componentes `App*` ([15]).
- **Modo por `AppCapacidades`, nunca `AppModo`** ([05] §2.3): passos de convites/notificações só no colaborativo.
- **Sem rede/Drift no tour:** estado efêmero + flags em SharedPreferences.
- **Acessibilidade (RNF-06):** alvo de toque ≥48dp, rótulos, sem overflow com `textScaler` 2x, anunciar a bolha.
- Barra de qualidade: `dart format .` + `flutter analyze` limpos; `flutter test` verde; nomes de teste `deve_<resultado>_quando_<condição>`.
- **TDD** onde há lógica (motor/roteiro/flags); UI de overlay coberta por widget test.
- Docs donos no mesmo PR: [05], [15], [10], [12], [14].

## File Structure

- `lib/features/tour/tour_step.dart` — **novo**: modelo `TourStep` + `TourPosicao`.
- `lib/features/tour/tour_keys.dart` — **novo**: `GlobalKey`s dos alvos.
- `lib/features/tour/tour_roteiro.dart` — **novo**: passos da etapa 1 e etapa 2 (filtro por capacidades).
- `lib/features/tour/tour_controller.dart` — **novo**: `TourController`/provider + flags (`TourVistoNotifier`).
- `lib/features/tour/ui/tour_overlay.dart` — **novo**: `Spotlight` + `TourOverlay` (bolha).
- `lib/features/tour/ui/tour_loader.dart` — **novo**: monta o overlay quando a etapa é elegível.
- Telas: `painel_listas.dart`, `tela_lista_screen.dart`, `configuracoes_screen.dart`, `sheet_titulo_lista.dart`, `modal_importar.dart` — recebem `GlobalKey`s e o gatilho.
- Testes: `test/features/tour/*.dart`.

---

### Task 1 (F46-T01): Modelo, chaves, controller e flags

**Files:**
- Create: `lib/features/tour/tour_step.dart`, `lib/features/tour/tour_keys.dart`, `lib/features/tour/tour_controller.dart`
- Test: `test/features/tour/tour_controller_test.dart`

**Interfaces:**
- Produces:
  - `enum TourPosicao { abaixo, acima, centro }`
  - `class TourStep { final String id; final GlobalKey alvo; final String titulo; final String corpo; final TourPosicao posicao; final bool Function(AppCapacidades) elegivel; }`
  - `class TourKeys { static final novaLista = GlobalKey(); static final campoAdicionar = GlobalKey(); static final seletorUnidade = GlobalKey(); static final botaoImportar = GlobalKey(); static final lupa = GlobalKey(); static final abaConfiguracoes = GlobalKey(); static final itemLista = GlobalKey(); static final botaoMercado = GlobalKey(); static final menuMais = GlobalKey(); static final acaoConvite = GlobalKey(); }`
  - `enum TourEtapa { primeira, recursos }`
  - `class TourVistoNotifier` (chaves `tour_etapa1_visto` / `tour_etapa2_visto`), provider `tourEtapaVistaProvider` (`Family<bool, TourEtapa>` async) com `marcarVista(TourEtapa)`.
  - `class TourController` (`Notifier<TourEstado>`), `TourEstado { bool ativo; List<TourStep> passos; int indice; }` com `iniciar(TourEtapa)`, `proximo()`, `anterior()`, `pular()`; provider `tourControllerProvider`.

- [ ] **Step 1: Teste que falha (flags)**

Create `test/features/tour/tour_controller_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/features/tour/tour_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('deve_estar_falso_quando_sem_flag', () async {
    SharedPreferences.setMockInitialValues({});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(await c.read(tourEtapaVistaProvider(TourEtapa.primeira).future), isFalse);
  });

  test('deve_marcar_vista_quando_concluir', () async {
    SharedPreferences.setMockInitialValues({});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await c.read(tourEtapaVistaProvider(TourEtapa.primeira).notifier).marcarVista(TourEtapa.primeira);
    expect(await c.read(tourEtapaVistaProvider(TourEtapa.primeira).future), isTrue);
    expect(await c.read(tourEtapaVistaProvider(TourEtapa.recursos).future), isFalse);
  });
}
```

- [ ] **Step 2: Rodar e ver falhar** — `flutter test test/features/tour/tour_controller_test.dart` → FAIL (arquivo não existe).

- [ ] **Step 3: Criar `tour_step.dart` e `tour_keys.dart`**

`tour_step.dart`:

```dart
import 'package:flutter/widgets.dart';

import '../../core/config/app_modo.dart';

enum TourPosicao { abaixo, acima, centro }

/// Um passo do tour: onde apontar e o que dizer (doc 05 / spec F46).
class TourStep {
  const TourStep({
    required this.id,
    required this.alvo,
    required this.titulo,
    required this.corpo,
    required this.elegivel,
    this.posicao = TourPosicao.abaixo,
  });

  final String id;
  final GlobalKey alvo;
  final String titulo;
  final String corpo;
  final TourPosicao posicao;
  final bool Function(AppCapacidades) elegivel;
}
```

`tour_keys.dart`:

```dart
import 'package:flutter/widgets.dart';

/// Chaves dos alvos do tour (doc 05 / spec F46). As telas anexam estas chaves
/// aos widgets reais; o overlay lê a posição via `currentContext`.
abstract final class TourKeys {
  static final novaLista = GlobalKey();
  static final campoAdicionar = GlobalKey();
  static final seletorUnidade = GlobalKey();
  static final botaoImportar = GlobalKey();
  static final lupa = GlobalKey();
  static final abaConfiguracoes = GlobalKey();
  static final itemLista = GlobalKey();
  static final botaoMercado = GlobalKey();
  static final menuMais = GlobalKey();
  static final acaoConvite = GlobalKey();
}
```

- [ ] **Step 4: Criar `tour_controller.dart`** (flags + estado)

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'tour_roteiro.dart';
import 'tour_step.dart';

enum TourEtapa { primeira, recursos }

String _chave(TourEtapa e) =>
    e == TourEtapa.primeira ? 'tour_etapa1_visto' : 'tour_etapa2_visto';

/// Conclusão de cada etapa (SharedPreferences), espelho de `OnboardingNotifier`.
class TourVistoNotifier extends FamilyAsyncNotifier<bool, TourEtapa> {
  @override
  Future<bool> build(TourEtapa etapa) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_chave(etapa)) ?? false;
  }

  Future<void> marcarVista(TourEtapa etapa) async {
    state = const AsyncData(true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_chave(etapa), true);
  }
}

final tourEtapaVistaProvider =
    AsyncNotifierProvider.family<TourVistoNotifier, bool, TourEtapa>(
  TourVistoNotifier.new,
);

class TourEstado {
  const TourEstado({
    this.ativo = false,
    this.passos = const [],
    this.indice = 0,
    this.etapa,
  });
  final bool ativo;
  final List<TourStep> passos;
  final int indice;
  final TourEtapa? etapa;
  TourStep? get atual => ativo && indice < passos.length ? passos[indice] : null;
  TourEstado copyWith({bool? ativo, List<TourStep>? passos, int? indice}) =>
      TourEstado(
        ativo: ativo ?? this.ativo,
        passos: passos ?? this.passos,
        indice: indice ?? this.indice,
        etapa: etapa,
      );
}

class TourController extends Notifier<TourEstado> {
  @override
  TourEstado build() => const TourEstado();

  /// Inicia uma etapa; retorna false se não houver passos elegíveis/montados.
  bool iniciar(TourEtapa etapa, {bool forcar = false}) {
    final cap = ref.read(capacidadesProvider);
    final lista = (etapa == TourEtapa.primeira ? passosEtapa1 : passosEtapa2)
        .where((p) => p.elegivel(cap))
        .where((p) => p.alvo.currentContext != null)
        .toList();
    if (lista.isEmpty) return false;
    state = TourEstado(ativo: true, passos: lista, indice: 0, etapa: etapa);
    return true;
  }

  void proximo() {
    final i = state.indice + 1;
    if (i >= state.passos.length) return _encerrar();
    state = state.copyWith(indice: i);
  }

  void anterior() {
    if (state.indice == 0) return;
    state = state.copyWith(indice: state.indice - 1);
  }

  Future<void> pular() async {
    final etapa = state.etapa;
    _encerrar();
    if (etapa != null) {
      await ref.read(tourEtapaVistaProvider(etapa).notifier).marcarVista(etapa);
    }
  }

  void _encerrar() => state = const TourEstado();
}

final tourControllerProvider =
    NotifierProvider<TourController, TourEstado>(TourController.new);
```

> Observação: importe `capacidadesProvider` de `../../core/config/app_modo.dart`. A etapa concluída vive no `TourEstado` (nada de inferir pela identidade do passo).

- [ ] **Step 5: Rodar e ver passar** — `flutter test test/features/tour/tour_controller_test.dart` → PASS.

- [ ] **Step 6: Commitar**

```bash
git add lib/features/tour test/features/tour docs/14-tarefas.md
git commit -m "F46-T01: motor do tour - modelo, chaves, controller e flags (RF-27)"
```

---

### Task 2 (F46-T02): Roteiro (2 etapas, filtro por capacidades)

**Files:**
- Create: `lib/features/tour/tour_roteiro.dart`
- Modify: `lib/core/l10n/app_strings.dart` (textos do tour)
- Test: `test/features/tour/tour_roteiro_test.dart`

**Interfaces:**
- Consumes: `TourStep`, `TourKeys`, `AppCapacidades`.
- Produces: `List<TourStep> get passosEtapa1`, `List<TourStep> get passosEtapa2` (top-level, em `tour_roteiro.dart`).

- [ ] **Step 1: Teste que falha (elegibilidade)**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/config/app_modo.dart';
import 'package:lista_compras/features/tour/tour_roteiro.dart';

void main() {
  test('deve_pular_convite_quando_modo_lite', () {
    final elegiveis = passosEtapa2
        .where((p) => p.elegivel(AppCapacidades.lite))
        .map((p) => p.id)
        .toList();
    expect(elegiveis.contains('recursos.convite'), isFalse);
    expect(elegiveis.contains('recursos.mercado'), isTrue);
  });

  test('deve_incluir_convite_quando_colaborativo', () {
    final elegiveis = passosEtapa2
        .where((p) => p.elegivel(AppCapacidades.colaborativo))
        .map((p) => p.id)
        .toList();
    expect(elegiveis.contains('recursos.convite'), isTrue);
  });
}
```

- [ ] **Step 2: Rodar e ver falhar** → FAIL (arquivo não existe).

- [ ] **Step 3: Strings do tour** — acrescente em `AppStrings` (pt-BR, sem acento no código):

```dart
  // Tour guiado (RF-27, F46)
  static const tourPular = 'Pular';
  static const tourAnterior = 'Anterior';
  static const tourProximo = 'Proximo';
  static const tourConcluir = 'Concluir';
  static const tourAbrir = 'Ver tutorial';
  static const tourNovaListaTitulo = 'Criar sua primeira lista';
  static const tourNovaListaCorpo =
      'Toque em "Nova lista" para comecar. Voce pode criar quantas quiser.';
  static const tourNomeTitulo = 'Dê um nome';
  static const tourNomeCorpo =
      'O nome aparece no topo. Opcionalmente, defina um orcamento.';
  static const tourAdicionarTitulo = 'Adicionar item';
  static const tourAdicionarCorpo =
      'Digite aqui. "1kg de arroz" ja vira nome, quantidade e unidade.';
  static const tourUnidadeTitulo = 'Unidade';
  static const tourUnidadeCorpo =
      'Escolha a medida (un, kg, pacote, pote...). O app tenta adivinhar.';
  static const tourImportarTitulo = 'Importe por texto';
  static const tourImportarCorpo =
      'Cole uma anotacao e o app organiza os itens para voce.';
  static const tourBuscaTitulo = 'Busca e filtros';
  static const tourBuscaCorpo =
      'Encontre itens por nome e filtre por categoria ou unidade.';
  static const tourConfigTitulo = 'Configuracoes';
  static const tourConfigCorpo =
      'Tema, categorias, backup e onde rever este tutorial.';
  static const tourMarcarTitulo = 'Marcar, editar e remover';
  static const tourMarcarCorpo =
      'Toque no item para editar; marque no circulo; arraste para remover.';
  static const tourMercadoTitulo = 'Modo mercado';
  static const tourMercadoCorpo =
      'No mercado, marque as compras sem perder o que falta.';
  static const tourOrcamentoTitulo = 'Orcamento e total';
  static const tourOrcamentoCorpo =
      'Defina um teto e acompanhe o total do carrinho.';
  static const tourConviteTitulo = 'Compartilhe a lista';
  static const tourConviteCorpo =
      'Convide alguem para comprar junto, cada um no seu aparelho.';
```

- [ ] **Step 4: Roteiro** — crie `tour_roteiro.dart` com os 11 passos (etapa 1: 7; etapa 2: 4). `elegivel` é `(cap) => true` em todos, **exceto** `recursos.convite` (`(cap) => cap.colaboracao`). Os passos de mercado/orçamento/marcar/editar são visíveis conforme o papel na lista, que a própria tela já esconde (papel efetivo) — o motor não decide por papel. Use `TourKeys` correspondentes e `AppStrings`.

- [ ] **Step 5: Rodar e ver passar** → PASS.

- [ ] **Step 6: Commitar** — `F46-T02: roteiro do tour em 2 etapas com filtro por capacidades (RF-27)`.

---

### Task 3 (F46-T03): Overlay (spotlight + bolha)

**Files:**
- Create: `lib/features/tour/ui/tour_overlay.dart`
- Test: `test/features/tour/tour_overlay_test.dart`

**Interfaces:**
- Consumes: `TourEstado`/`TourStep`, tokens `App*`, `AppBotao`/`mostrarSnackBar` se preciso.
- Produces: `class TourOverlay extends ConsumerWidget` (renderiza o passo atual sobre um `Stack` + `IgnorePointer` do resto), e `class Spotlight extends StatelessWidget` (recorte via `CustomPainter`).

- [ ] **Step 1: Teste que falha (render + avanço)**

```dart
testWidgets('deve_mostrar_bolha_e_avancar_quando_proximo', (tester) async {
  // monta um alvo com TourKeys.novaLista, inicia o controller e pinta o overlay
  // espera achar o titulo do passo 1 e, apos tocar Proximo, o titulo do passo 2
});
```

- [ ] **Step 2: Rodar e ver falhar** → FAIL.

- [ ] **Step 3: Implementar `Spotlight`** — `CustomPainter` que pinta o scrim (`colorScheme.scrim` com opacidade) e recorta o `Rect` do alvo (`RenderBox.localToGlobal` + `size`), com halo `colorScheme.primary`; `dispose`/`shouldRepaint` corretos.

- [ ] **Step 4: Implementar `TourOverlay`** — `Stack`: scrim+spotlight (`IgnorePointer`), bolha `Positioned` conforme `TourPosicao` (fallback se não couber), com `titulo`, `corpo`, `n/total` e `AppBotao`/botões (`Pular`, `Anterior`, `Próximo`/`Concluir`) ligados ao `tourControllerProvider`. Bolha em `Semantics`/`liveRegion` com rótulo "Passo n de m".

- [ ] **Step 5: Rodar e ver passar** + a11y (`2x` sem overflow, alvo ≥48dp).

- [ ] **Step 6: Commitar** — `F46-T03: overlay do tour - spotlight e bolha (RF-27)`.

---

### Task 4 (F46-T04): Ligar nas telas + loader e gatilhos

**Files:**
- Create: `lib/features/tour/ui/tour_loader.dart`
- Modify: `lib/features/listas/ui/painel_listas.dart` (chaves + loader etapa 1)
- Modify: `lib/features/listas/ui/tela_lista_screen.dart` (chaves + loader etapa 2)
- Modify: `lib/features/listas/ui/sheet_titulo_lista.dart`, `lib/features/importacao/ui/modal_importar.dart`, `lib/features/configuracoes/ui/configuracoes_screen.dart`
- Test: `test/features/tour/tour_gatilho_test.dart`

**Interfaces:**
- Consumes: `TourKeys`, `TourController`, flags.
- Produces: `TourLoader` (widget que, ao montar, dispara `iniciar(etapa)` quando elegível e não vista; renderiza `TourOverlay` quando `ativo`).

- [ ] **Step 1: Teste que falha (disparo etapa 1)** — monta `PainelListas` (ou `MinhasListasScreen`) com flags falsas e verifica que o alvo aparece; com flags vistas, não aparece.

- [ ] **Step 2: Ancorar chaves nos widgets reais** (usar `key: TourKeys.x`):
  - `painel_listas`: FAB/botão "Criar primeira lista" → `novaLista`; lupa (AppBar) → `lupa`; `AppShell` aba Configurações → `abaConfiguracoes`.
  - `tela_lista_screen`: `_CampoAdicionar` → `campoAdicionar`; `PopupMenuButton<Unidade>` → `seletorUnidade`; botão "Importar lista" → `botaoImportar`; ícone mercado → `botaoMercado`; `PopupMenuButton` ⋮ → `menuMais`; primeira linha de item → `itemLista`.
  - `sheet_titulo_lista`: campo de nome → usar o passo dentro do sheet (etapa 1, passo 2) — se o sheet não estiver montado, o motor pula (já tratado).
  - `configuracoes_screen`: aba / linha "Ver tutorial" → `acaoConvite` (convite) e a própria linha de tutorial.

- [ ] **Step 3: `TourLoader`** — chama `iniciar` no `initState`/`ref.listen` quando `!vista && alvos montados`; renderiza `TourOverlay` num `Overlay` (via `Overlay.of(context).insert` ou dentro do `Scaffold` com `Stack`).

- [ ] **Step 4: Gatilhos**
  - Etapa 1: em `MinhasListasScreen`/`painel_listas`, após `onboarding_visto` (mesmo ponto do `/boas-vindas`).
  - Etapa 2: em `tela_lista_screen`, quando a lista tem ≥1 item ativo e `!tour_etapa2_visto`.
  - Reabrir: `configuracoes_screen` → linha "Ver tutorial" chama `iniciar(forcar: true)` para as duas etapas.

- [ ] **Step 5: Rodar e ver passar**; rodar a suíte completa (prod intacto quando flags vistas).

- [ ] **Step 6: Commitar** — `F46-T04: liga o tour nas telas, loader e gatilhos (RF-27)`.

---

### Task 5 (F46-T05): Docs donos e fechamento

**Files:**
- Modify: `docs/05-app-flutter.md` (UX/onboarding), `docs/15-design-system.md` (componente do tour), `docs/10-wireframes-telas.md` (spots), `docs/12-prd.md` (RF-27), `docs/14-tarefas.md` (Fase 46)
- Test: suíte completa

- [ ] **Step 1: doc 05** — seção de onboarding/tour: 2 etapas, gatilhos, flags, reabrir em Configurações; link para a spec.
- [ ] **Step 2: doc 15** — registrar o `Spotlight`/bolha como componente `App*` (tokens, a11y) e o `TourOverlay`.
- [ ] **Step 3: doc 10** — anotar os spots do tour nas telas de lista/painel/config.
- [ ] **Step 4: doc 12** — RF-27 estendido (tour interativo).
- [ ] **Step 5: doc 14** — Fase 46 (F46-T01…T05 `- [x]`) + tabela de progresso.
- [ ] **Step 6: `dart format . && flutter analyze && flutter test`** verdes; commit `F46-T05: docs donos e fechamento da Fase 46 (RF-27)`.
