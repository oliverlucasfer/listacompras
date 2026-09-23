# Fase 40 — Editor de item em sheet e correções de margem (design)

> **Status:** aprovado em 23/09/2026 (decisões na Seção 8)
> **Fase:** 40 · **Requisito:** RNF-06 (área de respiro / usabilidade) · **Doc dono:** [15](../15-design-system.md), [10](../10-wireframes-telas.md)
> **Origem:** pedido direto do dono (23/09/2026): "os elementos do app sempre com margem das bordas" e "melhorar a disposição do modal de edição do item, que fica estranho com o teclado".

---

## 1. Motivação

1. **Editor de item com o teclado.** `_DialogoEditarItem` (`tela_lista_screen.dart:1146-1401`) é um
   `AlertDialog` aberto por `showDialog` (`:994-1003`), enquanto os outros modais do app usam
   `AppSheet.mostrar`. Com o teclado aberto o `Dialog` centraliza, soma `viewInsets` (SDK) e é
   espremido: só o conteúdo rola, título/ações ficam fixos, e os 5 campos empilhados cabem mal.
   Não há tratamento de `viewInsets` no app nem campo focado trazido à visão. **Este é o problema real.**
2. **Margens.** Auditoria de 23/09/2026: o app **já respeita ≥16dp das bordas em praticamente todos
   os pontos** — `ListTile` traz `contentPadding` 16 por padrão (`app_theme.dart:106` não o altera) e
   as telas que usam `Padding` usam `AppSpacing.lg`/`AppSpacing.tela`. Uma varredura de wrapper em
   massa seria churn sem efeito visual (decisão §8.1). Restam apenas lacunas pontuais e reais,
   listadas em §3.

## 2. Escopo

**Dentro:**
- Editor de item convertido em **bottom sheet** (`AppSheet.mostrar`), com os campos em **blocos**.
- **Margens — só o que muda de fato:**
  - `IndicadorSync` (banner offline/erro) usa `EdgeInsets.all(AppSpacing.sm)` = **8dp**
    (`indicador_sync.dart:44,51`); nos usos **sem wrap** ele fica colado à borda em 8dp — nas 2
    ocorrências (`tela_lista_screen.dart:421`, `mercado_screen.dart:133`) passa a ter 16dp.
  - Literais **verticais** tokenizados: `painel_listas.dart:264` (`4` → `AppSpacing.xs`) e
    `painel_listas.dart:185` (`88` → derivado dos tokens, documentado).
  - Remover o token **sem uso** `AppSpacing.horizontalCompacto` (`app_spacing.dart:15-17`).
- Docs donos ([15 §1](../15-design-system.md), [10](../10-wireframes-telas.md)) e Fase 40 no [14](../14-tarefas.md).

**Fora:**
- Criar um wrapper de página (`AppPagina`) ou migrar as telas: o app já está conforme (§1.2).
- Redesenho de cores, tipografia, ícones ou tokens existentes.
- Mudança de AppBar, FAB, bottom nav, ou de qualquer overlay existente.
- Novas funcionalidades ou campos no editor (campos, strings e lógica de salvar **não** mudam).
- Alterar comportamento observável além da apresentação do editor.

## 3. Margens — correções pontuais

| Ponto | Hoje | Depois | Evidência |
| :--- | :--- | :--- | :--- |
| `IndicadorSync.Offline()` — banner | `EdgeInsets.all(8)` | `fromLTRB(lg, sm, lg, 0)` | `indicador_sync.dart:43-49` |
| `IndicadorSync.ErroSync()` — banner | `EdgeInsets.all(8)` | `fromLTRB(lg, sm, lg, 0)` | `indicador_sync.dart:50-62` |
| Uso do `IndicadorSync` no painel (wrapper externo) | `fromLTRB(lg, sm, lg, 0)` | `only(top: AppSpacing.sm)` (o horizontal passa a vir do próprio widget) | `painel_listas.dart:137-145` |
| Gap vertical do subtítulo (painel) | literal `4` | `AppSpacing.xs` | `painel_listas.dart:264` |
| Base da lista (painel) | literal `88` | `AppSpacing.xxxl + AppSpacing.xxl + AppSpacing.sm` (= 88) | `painel_listas.dart:185` |
| Token sem uso | `horizontalCompacto` (12dp) | removido | `app_spacing.dart:15-17` |

**Por que assim:** o `_LinhaStatus` interno (Sincronizado/Sincronizando/Pendente) já usa
`fromLTRB(lg, xs, lg, 0)` = 16dp (`indicador_sync.dart:75-81`); só os dois banners ficaram em 8dp. Igualar
os banners a `lg` deixa os três estados com a mesma margem. Nos usos **sem wrap**
(`tela_lista_screen.dart:421`, `mercado_screen.dart:133`) isso resolve direto; no uso do painel, o
wrapper externo passa a somar 16+16 = 32 se ficar como está — por isso ele perde o horizontal (vira
`only(top: sm)`) e os três usos terminam em **16dp**.

## 4. Editor de item → bottom sheet

`_abrirDialogoEditar` (`tela_lista_screen.dart:994-1003`) passa a usar `AppSheet.mostrar` com um
`_SheetEditarItem`. `AppSheet` já faz `isScrollControlled`, `showDragHandle`, `SafeArea` e
`Padding(bottom: lg + viewInsets.bottom)` — o teclado deixa de ser problema, e o
`SingleChildScrollView` traz o campo focado à visão.

Layout (blocos; rótulos curtos; validações atuais preservadas):

```
┌─────────────────────────────────────┐
│ (drag handle)                       │
│ Editar item                         │
│ Nome                                │  ← largura total
│ [_______________________________]   │
│                                     │
│ [−  Quantidade  +] [Unidade ▾]      │  ← linha 1 (stepper + dropdown)
│ [Categoria ▾     ] [Preço      ]    │  ← linha 2
│                                     │
│ Último preço: R$ … (histórico)      │  ← quando houver histórico (RF-29)
│                                     │
│ Remover        [Cancelar] [Salvar]  │  ← rodapé
└─────────────────────────────────────┘
```

- **Sem mudança de comportamento:** mesmos campos, mesmos `AppStrings`, mesmas validações
  (`_erroNome`, `_erroQuantidade`, `_erroPreco`), mesma chamada `editarItem(...)`, mesma ação de
  remover com Desfazer (`onRemover`).
- O stepper `−/+` continua em volta do campo de quantidade (`:1296-1335`).
- O rodapé substitui `AlertDialog.actions`: `Remover` (quando `onRemover != null`, em cor de erro) à
  esquerda; `Cancelar` + `Salvar` à direita.
- Em telas estreitas as duas colunas usam `Expanded` com `flex` 1:1 e `AppSpacing.md` entre elas; sem
  estouro com `TextScaler` 2.0.

## 5. Testes

- **Editor (sheet):** abre por `AppSheet.mostrar` (não mais `AlertDialog`); campos e rodapé presentes;
  salvar grava os mesmos valores; `Remover` mantém o Desfazer; erros de nome/quantidade/preço iguais.
  Ajustar os testes que hoje buscam `AlertDialog`/`showDialog` para o editor
  (`tela_lista_screen_test.dart:2080,2219`; `editar_item_historico_test.dart`).
- **Teclado:** teste que injeta `viewInsets` (`tester.view.viewInsets`) e verifica que o sheet
  permanece sem overflow e com os campos alcançáveis.
- **Margem do `IndicadorSync`:** teste que verifica 16dp nos dois usos sem wrap e ausência de padding
  duplo no uso do painel (16 no total).

## 6. Docs donos

- **[15 §1](../15-design-system.md):** remover `horizontalCompacto` da lista de tokens; registrar a
  regra "conteúdo a 16dp da borda" e que o `IndicadorSync` já traz a própria margem.
- **[10](../10-wireframes-telas.md):** o editor de item passa a ser descrito como **bottom sheet**
  (se hoje estiver como diálogo).
- **[14](../14-tarefas.md):** Fase 40 com as tarefas e a linha de progresso.

## 7. Riscos

- **Contagem de testes:** os testes de tela que localizam o editor por `AlertDialog` mudam de seletor
  (comportamento igual, apresentação nova). Ajuste mecânico, coberto pela suíte.
- **Padding duplo no `IndicadorSync`:** mitigado pelo §3 (os três usos terminam em 16dp); travado por teste.
- **Sheet em telas muito baixas:** `AppSheet` é `isScrollControlled` + `SingleChildScrollView`; o
  conteúdo rola dentro do espaço restante (mesmo padrão dos outros sheets já em produção).

## 8. Decisões registradas (23/09/2026)

1. **Margens: só o que muda de fato.** Varredura de wrapper (`AppPagina`) **descartada** — o app já
   está ≥16dp em quase tudo; o refactor seria churn sem efeito visual.
2. **Editor vira bottom sheet** via `AppSheet.mostrar` (uniformiza com os outros modais e resolve o teclado).
3. **Campos em blocos** (linha dupla onde faz sentido), com rótulos curtos.
4. **Sem mudança de comportamento** no editor além da apresentação; sem novos campos.
5. `horizontalCompacto` **removido** (sem uso); literais verticais do painel tokenizados.

## 9. Documentos relacionados
- [15 Design System](../15-design-system.md) §1/§4 · [10 Wireframes](../10-wireframes-telas.md)
- [05 App Flutter](../05-app-flutter.md) · [14 Tarefas](../14-tarefas.md) (Fase 40)
- Specs de referência visual: [F8](2026-09-11-revisao-visual-ux-design.md) · [F9](2026-09-11-revisao-visual-ux-etapa2-design.md) · [F10](2026-09-11-revisao-visual-ux-etapa3-design.md)
