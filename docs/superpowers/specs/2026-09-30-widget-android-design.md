# Frente — Widget Android / Quick-add (design)

> **Status:** aprovado em 30/09/2026 (decisões registradas na Seção 9)
> **Fase:** 55 · **Requisito:** RF-38 (widget de tela inicial Android + quick-add)
> **Docs donos:** [05](../05-app-flutter.md) (app/UX), [10](../10-wireframes-telas.md) (layout),
> [12](../12-prd.md) (requisitos), [09](../09-runbook-operacoes.md) (pacote/setup nativo),
> [15](../15-design-system.md) (cores), [14](../14-tarefas.md) (tarefas)

---

## 1. Motivação

A persona **P1 (Comprador solo)** anota itens o tempo todo. Hoje é preciso abrir o app e navegar
até a lista. Um **widget na tela inicial** do Android com a lista mais recente e um botão
**"Adicionar item"** encurta esse caminho (quick-add) — sem nuvem.

**A feature é 100% offline** e **Android-only**. Os dados do widget são locais; nada trafega.

## 2. Escopo

**Dentro:**
- RF-38: **AppWidget** Android com **título da última lista** + **nº de pendentes** + botão
  **"Adicionar item"**; o toque abre o app na rota **`/adicionar`** (última lista, campo focado);
  o widget reflui as mudanças.
- Registro de **`ultima_lista_id`** (SharedPreferences) ao abrir uma lista.

**Fora:** widget iOS (fora de distribuição); Web/Desktop; top-N de itens no widget (RemoteViews
limitado); edição/marcação de itens direto no widget.

## 3. Arquitetura

- **Ponte:** pacote **`home_widget`** (Flutter ↔ widget nativo Android; offline).
- **Nativo Android:** `AppWidgetProvider` (Kotlin) + `res/layout` do widget + `res/xml/appwidget_info`
  + `<receiver>` no `AndroidManifest.xml` + deep link para a `MainActivity` (já `singleTop`).
- **Dart:** um `WidgetService` (contrato injetável) que empurra os dados
  (`saveWidgetData` + `updateWidget`) e resolve o toque do widget → navega para `/adicionar`.
- **"Última lista":** `ultima_lista_id` em `SharedPreferences`, gravado ao abrir a tela de uma lista.
- **Rota `/adicionar`:** resolve a última lista (ou a existente mais recente) e abre a tela da lista
  **com o campo de adicionar focado**; sem lista → painel com convite.

## 4. Widget, atualização e deep link

- **Card (RemoteViews):** rótulo do app + **título da última lista** + "**N pendentes**" + botão
  **"Adicionar item"**. Sem lista → convite ("Crie sua primeira lista"). Cores da marca (índigo),
  fundo neutro do sistema.
- **Atualização:** sempre que o dado muda — ao abrir a lista; ao **adicionar/editar/concluir/remover**
  item; ao **criar/renomear/excluir** a lista; e no **resume** do app. O `WidgetService` observa os
  streams relevantes (com **debounce** curto) e o app usa `WidgetsBindingObserver` para o resume.
- **Deep link:** o toque no widget abre a `MainActivity` com um _extra_/URI que o Flutter lê
  (`initiallyLaunchedFromHomeWidget`/`widgetClicked`) e navega para `/adicionar`.
- **Contagem:** itens **pendentes** (`concluido == false`, `deletado_em IS NULL`).

## 5. Regras e casos-limite

- Sem lista → widget mostra convite; o toque leva ao **painel**.
- `ultima_lista_id` inválido/excluído/arquivado → cai na **lista existente mais recente**; se não
  houver, painel.
- O widget nunca bloqueia a UI: falha ao atualizar o widget é **best-effort** (silenciosa).
- Android-only; no iOS/Web/Desktop nada muda (o widget é nativo do Android).
- Sem rede; nenhuma permissão nova (o widget não precisa de permissões).

## 6. Dependências, riscos e privacidade

- **`home_widget`** (offline). O setup nativo (provider/layout/info + receiver) deve respeitar os
  guards do **manifest de release** (F47/F48/F49: sem `INTERNET`/SDK Firebase; o widget não adiciona
  esses nós).
- Riscos: limitações de **RemoteViews** (layouts simples); timing/limpeza do **debounce**; deep link
  com `singleTop`.
- Privacidade: os dados do widget são locais (título + contagem); nada sai do aparelho.

## 7. Testes

- **Dart** (o widget nativo não é unit-testável):
  - builder do payload (título + pendentes) a partir de uma lista;
  - persistência/leitura de `ultima_lista_id`;
  - resolução da rota `/adicionar` (Drift in-memory) → abre `/lista/:id` com foco; fallback quando
    não há lista;
  - `WidgetService` atrás de um contrato **fake** (registra `saveWidgetData`/`updateWidget`) e os
    gatilhos (escrita/resume) atualizam o widget.
- Sem golden; o widget real é **smoke em device**.

## 8. Governança

- `12`: **RF-38** (tabela + matriz + fora de escopo).
- `05`: serviço/rota "última lista", `/adicionar` e o bridge do widget.
- `10`: wireframe/nota do widget (card + botão) e do estado sem lista.
- `09`: pacote `home_widget` + setup nativo (provider/layout/info/receiver) e o smoke em device.
- `15`: cores do widget conforme a identidade.
- `14`: Fase 55; `16`: frente (D3).

## 9. Decisões registradas (30/09/2026)

1. **AppWidget de tela inicial** (não atalho de lançador).
2. Conteúdo: **lista mais recente + nº de pendentes + botão Adicionar** (dados empurrados pelo Flutter).
3. Toque → rota **`/adicionar`** (última lista com o campo focado); sem lista → painel.
4. Implementação com **`home_widget`** + provider nativo; bridge testado com **fake**; real só smoke.
5. **Android-only**; offline; nenhuma permissão nova.
6. Fase **55**, requisito **RF-38**.

## 10. Documentos relacionados
- [05 App Flutter](../05-app-flutter.md) · [09 Runbook](../09-runbook-operacoes.md) · [10 Wireframes](../10-wireframes-telas.md)
- [12 PRD](../12-prd.md) · [14 Tarefas](../14-tarefas.md) · [16 Roadmap](../16-roadmap-pos-mvp.md)
