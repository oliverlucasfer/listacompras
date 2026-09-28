# Fase 46 — Tour guiado interativo do primeiro uso (design)

> **Status:** aprovado em 28/09/2026 (decisões na Seção 8)
> **Fase:** 46 · **Requisito:** RF-27 (extensão: onboarding interativo)
> **Docs donos:** [05](../05-app-flutter.md) (app/UX), [15](../15-design-system.md) (componente/tokens), [12](../12-prd.md) (PRD), [10](../10-wireframes-telas.md) (layout), [14](../14-tarefas.md) (tarefas)
> **Origem:** pedido do dono (28/09/2026): "um tutorial interativo pra primeira vez que o usuário vai usar".

---

## 1. Motivação

1. **O onboarding atual é passivo.** `BoasVindasScreen` (RF-27) é uma tela de leitura com destaques e um botão "Começar", vista uma vez (`onboarding_visto`). Ela apresenta o produto, mas **não ensina a usar** — o usuário cai numa lista vazia e descobre a interface sozinho.
2. **Há funcionalidades valiosas que passam despercebidas:** importar por texto, modo mercado, orçamento/total, busca/filtros, backup, convites. Nenhuma tem descoberta guiada hoje.
3. **A base já separa modos** (F41): `AppCapacidades` (`nuvem`/`colaboracao`/`notificacoes`/`backup`) permite um tour que **pula o que não existe** no modo Lite. Reusar isso evita um tour que aponta para telas inexistentes.

## 2. Escopo

**Dentro:**
- **Motor próprio de tour** (`TourGuide` + `TourStep`) com overlay/spotlight — **sem dependência nova**.
- **Roteiro em 2 etapas** (§5): etapa 1 sem dados (criar lista/adicionar/importar/busca/configurações); etapa 2 ao abrir uma lista com itens (marcar/editar, mercado, orçamento).
- Disparo: após as boas-vindas na primeira vez; etapa 2 na primeira lista com itens; **reabrível** em Configurações → "Ver tutorial".
- Acessibilidade (RNF-06): foco/semântica, alvo do spotlight, respeitar `textScaler` 2x, movimento reduzido.
- Docs donos (05/15/12/10/14) + testes (widget) + flag de conclusão.

**Fora:**
- Criar dados de exemplo / lista demo (descartado — opção 1).
- Tocar backend/RLS/schema/sync; nenhuma migration.
- Vídeos/GIFs, tour em vídeo, ou serviço externo.
- Mudar o comportamento do app colaborativo (`prod`) além de pular passos — nada é removido.
- iOS do Lite (segue adiado) e build Web do Lite.

## 3. O que já existe (reaproveitar, não duplicar)

- `onboardingVistoProvider` / `marcarVisto()` (`features/onboarding/providers/onboarding_provider.dart`) — flag em SharedPreferences; padrão a espelhar para `tour_etapa1_visto` / `tour_etapa2_visto`.
- `BoasVindasScreen` — continua; o tour **começa depois** dela (`minhas_listas_screen.dart:23-24` já faz `!visto → /boas-vindas`).
- `capacidadesProvider` (`core/config/app_modo.dart`) — decide os passos por modo, **nunca** `AppModo` direto.
- Design system: `AppBotao`, `AppRadius`, `AppSpacing`, `AppElevation`, tokens — o tour é `App*`, **sem cor literal** ([15](../15-design-system.md)).
- Configurações (`configuracoes_screen.dart`) — seção onde entra "Ver tutorial".
- Telas-alvo do roteiro (§5) já existem: `painel_listas`, `tela_lista_screen`, `mercado_screen`, `modal_importar`, sheet de título, editor de item.

## 4. Motor do tour (arquitetura)

**Novo módulo `lib/features/tour/`** (`core/widgets/` é para widgets genéricos; aqui é feature com roteiro e estado):

- **`tour_controller.dart`** — estado do tour (passo atual, ativo/pausado, fila de passos elegíveis). `Notifier` Riverpod, sem rede/Drift; a conclusão persiste via `TourVistoNotifier` (espelho do onboarding).
- **`tour_step.dart`** — modelo `TourStep { String id; GlobalKey alvo; String titulo; String corpo; PosicaoTour posicao; bool Function(AppCapacidades) elegivel; }`.
- **`tour_overlay.dart`** — `Overlay` com:
  - **spotlight**: recorte (`Path`/`CustomPainter`) sobre `alvo.currentContext` via `RenderBox`, com halo (`colorScheme.primary`); o resto escurecido;
  - **bolha**: `App`-estilizada **abaixo** do alvo com seta (fallback acima/lateral se não couber), `titulo`/`corpo`, indicador `n/total`, botões `Pular` / `Anterior` / `Próximo` (`Próximo` vira `Concluir` no último);
  - **sem bloquear toques fora** (avança só pelos botões);
  - respeita `MediaQuery.textScaler` (2x) e `disableAnimations` (sem transição).
- **`tour_keys.dart`** — `GlobalKey`s nomeadas usadas pelos alvos (`chaveNovaLista`, `chaveCampoAdicionar`, `chaveUnidade`, …), importadas pelas telas.
- **`tour_roteiro.dart`** — a lista ordenada de `TourStep` por etapa (dados em §5), filtrando por `AppCapacidades` e por **existência do alvo** (passo sem alvo montado é adiado/pulado).
- **Cada etapa roda dentro de UMA tela** (etapa 1 em `painel_listas`; etapa 2 em `tela_lista_screen`): o motor **não navega** entre rotas — terminada a etapa 1, o usuário segue; a etapa 2 dispara quando ele abrir uma lista com itens. Evita coordenar navegação no meio do overlay.

**Alvo visível é pré-requisito:** cada passo só entra na fila quando `alvo.currentContext != null` e o widget está montado; senão o motor **espera** (etapa 2 nasce na primeira lista com itens) ou **pula** (modo sem o recurso).

## 5. Roteiro (2 etapas)

**Etapa 1 — sem dados (após as boas-vindas, na home de listas):**

| # | Passo | Alvo | Modo |
| :--- | :--- | :--- | :--- |
| 1 | Criar sua primeira lista | botão "Nova lista"/"Criar primeira lista" | ambos |
| 2 | Nome e orçamento | sheet de título (`sheet_titulo_lista`) | ambos |
| 3 | Adicionar item | campo "Adicionar item" | ambos |
| 4 | Unidade (inclui `pt`) | seletor de unidade | ambos |
| 5 | Importar por texto | botão "Importar lista" | ambos |
| 6 | Busca e filtros | lupa na AppBar | ambos |
| 7 | Configurações e backup | aba Configurações | ambos |

**Etapa 2 — na primeira lista com itens (dispara ao abrir):**

| # | Passo | Alvo | Modo |
| :--- | :--- | :--- | :--- |
| 8 | Marcar, editar e remover | checkbox / linha do item | ambos |
| 9 | Modo mercado | ícone carrinho na AppBar | ambos (dono/editor) |
| 10 | Orçamento e total | menu ⋮ / topo da lista | ambos |
| 11 | Compartilhar / convites | ação convidar / menu | **prod** (pulado no Lite) |

- **Conclusão:** `Pular` ou `Concluir` marcam a etapa como vista (flag própria). `Pular` na etapa 1 não impede a etapa 2.
- **Reabrir:** Configurações → "Ver tutorial" **navega para a home de listas e reinicia a etapa 1** (ignora a flag de conclusão; não altera a conclusão já registrada de forma destrutiva). A etapa 2 não é reapresentada dali — os alvos dela vivem na tela da lista; ela só reaparece se ainda não tiver sido vista (flag própria). Motivo: o motor só aponta para alvos **visíveis**, e a tela de Configurações não monta os alvos das etapas.

## 6. Disparo e persistência

- **Etapa 1:** em `minhas_listas_screen`, após resolver `onboarding_visto`; se `!tourEtapa1Visto` e há alvos, inicia. Espelha exatamente o padrão atual das boas-vindas.
- **Etapa 2:** em `tela_lista_screen`, quando a lista tem ≥ 1 item ativo e `!tourEtapa2Visto`; inicia uma vez.
- **Flags:** `tour_etapa1_visto` e `tour_etapa2_visto` (SharedPreferences), em `TourVistoNotifier` (espelho de `OnboardingNotifier`). Sem Drift/sem rede.
- **Reabrir (Configurações):** "Ver tutorial" navega para `/listas` e inicia a etapa 1 (`iniciar(TourEtapa.primeira)`), sem reescrever flags. A etapa 2 segue o fluxo normal (dispara na lista, se não vista).

## 7. Acessibilidade, design e testes

- **Design system:** overlay e bolha usam tokens (`AppSpacing`/`AppRadius`/`AppElevation`) e `colorScheme` — **sem cor literal**; componentizar como `App*` se virar reuso.
- **Acessibilidade (RNF-06):** a bolha é anunciada (foco/semântica: "Passo n de m"); botões com alvo ≥48dp e rótulos; o spotlight não rouba o foco do alvo; comportamento correto com `textScaler` 2x (teste de não-estouro) e `disableAnimations`.
- **Testes (widget):**
  - motor: inicia no passo 1; `Próximo` avança; `Pular` encerra e marca flag; passo sem alvo é pulado;
  - capacidades: no Lite os passos de convites/notificações **não** aparecem; no colaborativo aparecem;
  - disparo: etapa 1 só sem flag; etapa 2 só com lista populada e sem flag; reabrir em Configurações funciona;
  - acessibilidade: 2x sem overflow; bolha anunciada.
- **Suíte `prod` continua verde** (nada de comportamento muda quando as flags já estão marcadas).

## 8. Decisões registradas (28/09/2026)

1. **Formato:** tour guiado na **UI real** (overlay/spotlight), não slides.
2. **Escopo:** **tour completo por recursos**.
3. **Disparo:** 1ª vez **e** reabrível em Configurações.
4. **Abordagem:** **motor próprio (A2)** — sem dependência nova.
5. **Apresentação:** **spotlight + bolha abaixo** (opção A).
6. **Etapas:** **tour em 2 etapas** (opção 1) — etapa 1 sem dados; etapa 2 ao abrir lista com itens.
7. **Etapa 2:** dispara ao abrir lista com itens, flag própria (mesmo se a etapa 1 foi pulada).
8. **Reabrir:** Configurações → "Ver tutorial" navega para a home e reinicia a etapa 1 (a etapa 2 segue o fluxo normal na lista).
9. **Sem dados de exemplo:** nada de lista-demo criada/apagada.
10. **Fase 46**; requisito **RF-27** estendido; **sem** dependência, **sem** migration/schema/sync.

## 9. Riscos

- **Multi-tela:** ~~o tour atravessa `painel_listas` e `tela_lista`~~ **Resolvido em §4**: cada etapa roda dentro de uma tela (sem navegação no meio do overlay); a fila espera `currentContext != null` e tem limite de tempo por passo, caindo para o próximo sem travar.
- **Ancoragem frágil:** `GlobalKey` errada = bolha apontando para o nada; mitigação: teste por passo conferindo que a chave resolve, e `fallback` centralizado quando o alvo não resolve.
- **Tour pulado por engano:** como não bloqueia toques, o usuário pode seguir; `Pular` é explícito e a reabertura em Configurações garante que nada se perde.

## 10. Documentos relacionados

- [05 App Flutter](../05-app-flutter.md) — UX e fluxo do usuário
- [15 Design System](../15-design-system.md) — tokens e componentes `App*`
- [10 Wireframes](../10-wireframes-telas.md) — layout das telas
- [12 PRD](../12-prd.md) — RF-27
- [2026-09-24-flavor-lite-sem-conta-design.md](2026-09-24-flavor-lite-sem-conta-design.md) — `AppCapacidades` (modos)
