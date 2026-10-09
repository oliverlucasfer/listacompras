# Frente — Revisão UX heurística (feedback do add e "Desmarcar todos") (design)

> **Status:** proposta — aguardando revisão do usuário (09/10/2026)
> **Fase:** 62 (a confirmar) · **Requisito:** RF-04 (ações em massa) e RF-03 (adicionar item)
> **Docs donos:** [05](../../05-app-flutter.md) (app/UX), [10](../../10-wireframes-telas.md) (layout),
> [12](../../12-prd.md) (requisitos), [15](../../15-design-system.md) (componentes),
> [13](../../13-premodelo-tecnico.md) (resumo), [14](../../14-tarefas.md) (tarefas),
> [16](../../16-roadmap-pos-mvp.md) (frente)

---

## 1. Motivação

Avaliação heurística por inspeção (NN/g) nas telas do fluxo principal encontrou dois **atritos**
de alto impacto e baixo esforço — ambos previstos ou coerentes com o próprio comportamento do app,
mas hoje inconsistentes:

- **A1 (Visibilidade do status / H1):** ao adicionar um item **novo** pela entrada rápida
  (`Enter` ou `+`), **nada é anunciado**. Duplicado/somado já mostram SnackBar, mas o caso
  `adicionado` cai num `break` mudo (`campo_adicionar_item.dart:135-142`). O item some no grupo da
  categoria (possivelmente fora da tela). É exatamente o risco anotado no plano de usabilidade
  ("não percebe Enter salva", [11 §3 T1](../../11-usabilidade-fase5.md)).
- **A2 (Controle/liberdade H3 + Prevenção de erro H5):** "Desmarcar todos" desmarca a lista inteira
  em um toque pelo menu `⋮`, **sem confirmação e sem undo** (`tela_lista_screen.dart:130-137`) —
  enquanto remover item e limpar concluídos **têm** `Desfazer`. É uma ação em massa sem rede de
  segurança, inconsistente com o restante do app.

## 2. Escopo

**Dentro:**
- **A1:** feedback de confirmação ao adicionar item **novo** pela entrada rápida e pelos chips de
  sugestão (mesma via de escrita).
- **A2:** confirmação antes de "Desmarcar todos" (quando há itens concluídos) + **undo** por
  SnackBar; item de menu **desabilitado** quando não há itens concluídos.
- **i18n (RF-39):** strings novas em pt/en/es.
- **Bump de versão** em `pubspec.yaml` + paridade em `web/version.json` + `flutter test`.

**Fora (registrado como backlog, não neste PR):**
- **A3** — seletor de unidade por sigla em menu de 29 opções (reconhecimento/eficiência).
- **A4** — menu `⋮` heterogêneo e longo (agrupar ações).
- **A5** — "Importar lista" ocupando o CTA fixo do rodapé (hierarquia/minimalismo).
- **A6** — item marcado migra para "Concluídos" sem transição (micro-animação).
- Varredura heurística das telas secundárias (Configurações, Histórico, Compartilhar, OCR).
- Execução do teste de usabilidade F5-T05 (gate do dono, [AGENTS.md](../../../AGENTS.md)).

## 3. A1 — Feedback do item novo

**Onde:** `lib/features/listas/ui/campo_adicionar_item.dart`, método `_adicionarItemDedup`.

Hoje o `switch (resultado)` trata `somado` e `substituido` (SnackBar) e deixa `adicionado` sem
feedback. Passa a exibir, também no caso `adicionado`, o mesmo `mostrarSnackBar` (duração curta
padrão de 2s), com a nova string **`itemAdicionado`** ("Item adicionado.").

- Vale para a entrada rápida (`_adicionar`) **e** para os chips de sugestão (`_adicionarSugerido`),
  que já compartilham `_adicionarItemDedup`.
- É coerente com o padrão atual do app (dedup já dá feedback) e resolve a hesitação do T1 sem
  introduzir componente novo.
- **Trade-off aceito:** adicionar vários itens em sequência mostra um SnackBar por item. Como a
  duração é curta (2s), o gesto continua fluido e a consistência com somado/substituído prevalece.
  Se na prática incomodar, a alternativa futura é um feedback inline junto ao campo (backlog).

## 4. A2 — "Desmarcar todos" com confirmação e undo

**Onde:** `lib/features/listas/ui/tela_lista_screen.dart`, `case 'desmarcar'` de `_acaoMenu`, e o
`PopupMenuButton` do menu `⋮`.

### 4.1. Menu

O item "Desmarcar todos" fica **desabilitado** (`enabled: false`) quando **não há nenhum item
concluído** — evita uma ação inútil. Com ≥ 1 concluído, fica ativo.

### 4.2. Confirmação

Com ≥ 1 concluído, o toque abre `AppDialog.confirmarDestrutivo` (mesmo padrão de "Limpar
concluídos" e "Excluir lista"):

- **Título:** `desmarcarTodos` (reuso do rótulo atual).
- **Mensagem:** nova string **`desmarcarTodosMensagem`** (ex.: "N itens marcados voltarão a
  pendente.").
- **Botão de confirmação:** nova string **`desmarcarTodosConfirmar`** (ex.: "Desmarcar").

Cancelar → sem efeito.

### 4.3. Escrita e undo

1. Antes da escrita, capturar os **ids dos itens concluídos** (de `itensDaListaProvider`).
2. `itensRepositoryProvider.desmarcarTodos(idLista)` (assinatura atual, sem mudança de contrato).
3. Sucesso → SnackBar com a nova string **`itensDesmarcados`** e ação **"Desfazer"**
   (`rotuloAcao`/`onAcao`, padrão já usado em `_confirmarLimparConcluidos`): o undo **re-marca**
   cada id capturado via `editarItem(id, concluido: true)`.
4. Falha → `mostrarSnackBar(erroGenerico)`, sem undo (nada mudou).

Reusa `AppDialog.confirmarDestrutivo` e `mostrarSnackBar` — **nenhum componente `App*` novo**.

## 5. Textos (i18n)

Novas chaves no ARB (`app_pt.arb`/`app_en.arb`/`app_es.arb`) e regeração do `app_localizations`:

| Chave | pt | en | es |
| :--- | :--- | :--- | :--- |
| `itemAdicionado` | Item adicionado. | Item added. | Artículo añadido. |
| `desmarcarTodosMensagem` | N item(ns) marcado(s) voltarão a pendente. | N marked item(s) will be unmarked. | N artículo(s) marcado(s) volverán a pendiente. |
| `desmarcarTodosConfirmar` | Desmarcar | Unmark | Desmarcar |
| `itensDesmarcados` | Itens desmarcados. | Items unmarked. | Artículos desmarcados. |

(Quando a mensagem precisar do plural/contagem, usar plural/placeholder do `gen_l10n`.)

## 6. Testes

- **Widget — entrada rápida:** adicionar item novo mostra SnackBar `itemAdicionado`; duplicado
  segue mostrando `itemDuplicadoSomado` (regressão).
- **Widget — chips de sugestão:** adicionar pelo chip também confirma.
- **Widget — desmarcar todos:** com concluídos, abre confirmação; confirmar desmarca e mostra o
  SnackBar com "Desfazer"; **Desfazer re-marca** os itens; cancelar não muda nada; **sem**
  concluídos, o item de menu está desabilitado.
- **Regressão:** `limparConcluidos`, remoção com undo e adição por importação/sheet inalterados.
- **CI:** `dart format .` + `flutter analyze` + `flutter test` verdes (inclui o guard
  `version_json_test` após o bump).

## 7. Governança

- **05 §6.3:** atualizar "Campo Adicionar item" (feedback do item novo) e "Ações em massa"
  ("desmarcar todos" com confirmação + undo; item do menu desabilitado sem concluídos).
- **10 §3.1:** anotar o feedback do add e o comportamento do menu.
- **12:** nota no RF-04 (ações em massa com confirmação/undo para "desmarcar todos").
- **15:** confirmar que **não há** componente novo (reuso de `AppDialog`/`mostrarSnackBar`).
- **13:** resumo do fluxo.
- **14:** Fase 62 com as tarefas e a linha da tabela de progresso.
- **16:** frente correspondente no roadmap pós-MVP.
- **i18n (RF-39):** strings pt/en/es; **bump de versão** com paridade em `web/version.json` e
  `flutter test`.

## 8. Decisões a registrar (pendentes de aprovação)

1. **A1** usa SnackBar curto (não animação/inline) para manter consistência com a dedup.
2. **A2** combina **confirmação + undo** (espelha "Limpar concluídos"), com item de menu
   desabilitado quando não há concluídos.
3. **A3–A6** ficam como backlog, fora deste PR.

## 9. Documentos relacionados
- [11 Plano de usabilidade](../../11-usabilidade-fase5.md) · [05 App Flutter](../../05-app-flutter.md) · [10 Wireframes](../../10-wireframes-telas.md)
- [12 PRD](../../12-prd.md) · [14 Tarefas](../../14-tarefas.md) · [16 Roadmap](../../16-roadmap-pos-mvp.md)
