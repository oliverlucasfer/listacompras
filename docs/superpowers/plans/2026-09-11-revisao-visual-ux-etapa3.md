# Redesign de Navegação (Etapa 3 / Fase 10) — Implementation Plan

> **For agentic workers:** Steps use checkbox. Manter `dart format`, `flutter analyze` e `flutter test` verdes por tarefa.

**Goal:** NavigationBar inferior (Minhas Listas / Compartilhadas / Configurações) com NavigationRail em telas largas, AppBars limpas, logout em Configurações e "entrar com código" em Compartilhadas.

**Architecture:** `StatefulShellRoute.indexedStack` (go_router 18) + widget `AppShell`; `PainelListas` reutilizável filtra por `donoAtualIdProvider`.

**Tech Stack:** Flutter 3.44.5 · go_router 18 · Riverpod 3.4.2.

**Spec:** `docs/superpowers/specs/2026-09-11-revisao-visual-ux-etapa3-design.md`

## Global Constraints

- Preservar textos/asserções dos testes; ajustes de teste só para refletir a nova navegação.
- Nada hardcoded: tokens/componentes do doc 15.
- CI verde por tarefa.

---

## Task F10-T00: Spec, plano e fase 10 nos docs

- [ ] Criar spec + plano; adicionar Fase 10 em `14-tarefas.md`; commit.

## Task F10-T01: Split Minhas × Compartilhadas

**Files:** `lib/features/listas/ui/painel_listas.dart` (novo), `minhas_listas_screen.dart`, `lib/features/listas/ui/compartilhadas_screen.dart` (novo), `lib/core/l10n/app_strings.dart`, `test/features/listas/minhas_listas_screen_test.dart`, `test/features/listas/compartilhadas_screen_test.dart` (novo)

- [ ] Strings `compartilhadas`, `nenhumaCompartilhada`, `nenhumaCompartilhadaDica`.
- [ ] Extrair `PainelListas({FiltroListas filtro})` com o corpo atual (card/estados/dialogs/entrar-com-código), filtrando por dono; FAB só em Minhas; person_add em Compartilhadas.
- [ ] `MinhasListasScreen`→`PainelListas(minhas)`; criar `CompartilhadasScreen`→`PainelListas(compartilhadas)`.
- [ ] `_CardLista`: long-press por papel (dono → renomear/excluir; compartilhada → membros).
- [ ] Ajustar `minhas_listas_screen_test` (override `donoAtualIdProvider='user-a'`) e criar `compartilhadas_screen_test` (lista de outro dono + entrar com código).
- [ ] `flutter test test/features/listas` verde; commit.

## Task F10-T02: AppShell e rotas

**Files:** `lib/core/navigation/app_shell.dart` (novo), `lib/router.dart`, `lib/features/configuracoes/ui/configuracoes_screen.dart`, `lib/core/l10n/app_strings.dart`

- [ ] `AppShell(navigationShell)`: `NavigationBar` (largura < 600) / `NavigationRail` (≥ 600) com 3 destinos; `goBranch`.
- [ ] `router.dart`: `StatefulShellRoute.indexedStack` com branches `/listas`, `/compartilhadas`, `/configuracoes`; demais rotas fora do shell; `/compartilhadas` protegida.
- [ ] Configurações: adicionar "Sair" (logout → `/login`); remover ícone de engrenagem do painel (via PainelListas sem a ação).
- [ ] `flutter analyze` + `flutter test test/widget_test.dart`; commit.

## Task F10-T03: Testes de navegação, doc 10 e fechamento

- [ ] Teste de widget do `AppShell` (NavigationBar presente; troca de aba muda o destino) com fakes.
- [ ] Atualizar `docs/10-wireframes-telas.md` (§2 painel com as 3 abas; §5 Configurações com "Sair").
- [ ] `dart format --set-exit-if-changed .` + `flutter analyze` + `flutter test`.
- [ ] Marcar Fase 10 em `14-tarefas.md` + progresso; commit.
