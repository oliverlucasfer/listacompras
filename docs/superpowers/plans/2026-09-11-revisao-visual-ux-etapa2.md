# Refresh Visual das Telas (Etapa 2 / Fase 9) — Implementation Plan

> **For agentic workers:** Steps use checkbox (`- [ ]`). Executar tarefa a tarefa, mantendo `dart format`, `flutter analyze` e `flutter test` verdes.

**Goal:** Aplicar tokens e componentes `App*` a todas as telas, corrigindo inconsistências visuais e de acessibilidade sem mudar comportamento.

**Architecture:** Cada tela troca widgets/estilos locais pelos componentes de `lib/core/widgets/` e pelos tokens de `lib/core/theme/tokens/`, preservando textos e estrutura assertados nos testes.

**Tech Stack:** Flutter 3.44.5 · Riverpod 3.4.2 · flutter_test.

**Spec:** `docs/superpowers/specs/2026-09-11-revisao-visual-ux-etapa2-design.md` · Design system: `docs/15-design-system.md`

## Global Constraints

- Manter os 249 testes verdes; `dart format` + `flutter analyze` limpos por tarefa.
- Não alterar textos visíveis (testes usam `find.text`); strings novas vão para `AppStrings`.
- Nada de cor/medida hardcoded na UI: usar tokens/`Theme`/`AppSemanticColors`.
- Acessibilidade (RNF-06): alvos ≥ 48dp, contraste AA, `tooltip`/`Semantics` em ícones.

---

## Task F9-T00: Spec, plano e fase 9 nos docs

- [ ] Criar a spec e este plano em `docs/superpowers/{specs,plans}/`.
- [ ] Adicionar a **Fase 9** em `docs/14-tarefas.md` (F9-T00…F9-T08) + linha de progresso.
- [ ] Commit.

## Task F9-T01: Auth (login, registro, recuperar)

**Files:** `lib/features/auth/ui/{login_screen,registro_screen,recuperar_senha_screen}.dart`, `lib/core/l10n/app_strings.dart`

- [ ] Strings novas em `AppStrings`: `informeSeuEmail` (`'Informe seu e-mail:'`), `linkUnicoExpira` (`'Link único, expira conforme configuração do serviço.'`).
- [ ] Login: substituir `TextField` por `AppCampoTexto` (com `label`, `erro`, `senha`, `onChanged`); `ErroInline` do erro geral por `AppBanner(tipo: erro)`; botões por `AppBotao(carregando: _carregando)` e `AppBotao(variante: outlined/texto)`; padding/spacing por tokens; **tooltip** no toggle de senha (`AppStrings.mostrarSenha`/`ocultarSenha`, ou `tooltip: AppStrings.senha`).
- [ ] Registro: mesmo tratamento (campos, botões com spinner, erro geral, checkbox/tooltip), tokens.
- [ ] Recuperar: `AppCampoTexto`, `AppBotao`, strings novas, ícone de sucesso; tokens.
- [ ] Rodar `flutter test test/features/auth` + analyze; ajustar; commit.

## Task F9-T02: Minhas Listas

**Files:** `lib/features/listas/ui/minhas_listas_screen.dart`

- [ ] `_CardLista` usa `AppCard` (mantendo textos: título, contagem, tempo relativo).
- [ ] `_EstadoVazio` vira `AppEstadoVazio` (mesmos textos/CTA).
- [ ] Erro de carga usa `AppEstadoErro` com retry (mesma ação).
- [ ] Diálogos destrutivos (renomear/excluir) usam `AppDialog.confirmarDestrutivo`.
- [ ] Snackbars via `mostrarSnackBar`; tokens de spacing.
- [ ] Rodar `flutter test test/features/listas` + analyze; ajustar; commit.

## Task F9-T03: Indicador de sync

**Files:** `lib/features/sync/ui/indicador_sync.dart`

- [ ] `Offline` e `ErroSync` usam `AppBanner` (`offline`/`erro`) com `on*Container`.
- [ ] `_LinhaStatus` usa tokens de spacing; ícones mantidos (`check_circle`, `cloud_off`, `error_outline`) para não quebrar testes.
- [ ] `reiniciarTentativas` mantido no `AppBanner.acao` (texto `AppStrings.tentarNovamente`).
- [ ] Rodar `flutter test test/features/sync/indicador_sync_test.dart` + analyze; commit.

## Task F9-T04: Tela da lista

**Files:** `lib/features/listas/ui/tela_lista_screen.dart`

- [ ] Banner offline/erro/leitura por `AppBanner` (não duplicar com o `IndicadorSync` — o card de sync continua sendo o `IndicadorSync`).
- [ ] Vazio de itens por `AppEstadoVazio`; erro de carga por `AppEstadoErro` com retry.
- [ ] `Colors.red` hardcoded → `colorScheme.error`; strings hardcoded → `AppStrings`/tokens.
- [ ] Diálogos (excluir/limpar) via `AppDialog.confirmarDestrutivo`; botões destrutivos via `AppBotao`.
- [ ] Snackbars de undo via `mostrarSnackBar`.
- [ ] Rodar `flutter test test/features/listas/tela_lista_screen_test.dart` + analyze; commit.

## Task F9-T05: Modais de IA

**Files:** `lib/features/ia/ui/{modal_importar_ia,modal_previsao_ia}.dart`

- [ ] Aviso da IA (`_AvisoIa`) por `AppBanner(tipo: aviso)`.
- [ ] Botões por `AppBotao`; contador/tokens; `AppCampoTexto` onde couber.
- [ ] Strings hardcoded → `AppStrings`.
- [ ] Rodar `flutter test test/features/ia` + analyze; commit.

## Task F9-T06: Configurações

**Files:** `lib/features/configuracoes/ui/configuracoes_screen.dart`

- [ ] `_CabecalhoSecao` → `AppCabecalhoSecao`.
- [ ] Botão excluir conta → `AppBotao(destrutivo)`; diálogo final → `AppDialog.confirmarDestrutivo`.
- [ ] Política de privacidade via `AppSheet.mostrar`.
- [ ] Tokens de spacing.
- [ ] Rodar `flutter test test/features/configuracoes` + analyze; commit.

## Task F9-T07: Convites e membros

**Files:** `lib/features/convites/ui/{sheet_convidar,tela_membros_screen,entrar_screen}.dart`

- [ ] Chip de papel → `AppChip` (alvo ≥48dp).
- [ ] Botões → `AppBotao`; sheets → `AppSheet`; confirmação destrutiva → `AppDialog`.
- [ ] `tooltip` nos ícones de copiar/compartilhar/fechar; tokens.
- [ ] Rodar `flutter test test/features/convites` + analyze; commit.

## Task F9-T08: Acessibilidade, doc 10 e fechamento

- [ ] Varredura final de `tooltip`/`Semantics` e alvos ≥48dp nas telas restantes.
- [ ] Atualizar `docs/10-wireframes-telas.md` onde a UI mudou (ex.: seção "Aparência" em Configurações).
- [ ] `dart format --set-exit-if-changed .`, `flutter analyze`, `flutter test`.
- [ ] Marcar F9 em `docs/14-tarefas.md` + progresso; commit final.
