# Fase 40 — Margens das telas e editor de item (design)

> **Status:** aprovado em 23/09/2026 (decisões na Seção 9)
> **Fase:** 40 · **Requisito:** RNF-06 (área de respiro / usabilidade) · **Doc dono:** [15](../15-design-system.md), [10](../10-wireframes-telas.md), [05](../05-app-flutter.md)
> **Origem:** pedido direto do dono (23/09/2026): "os elementos do app sempre com margem das bordas" e "melhorar a disposição do modal de edição do item, que fica estranho com o teclado".

---

## 1. Motivação

Duas queixas concretas de uso:

1. **Sem margem padronizada.** Não existe wrap nenhum de página: umas telas usam `AppSpacing.tela`
   (auth/onboarding), outras dependem do `contentPadding` padrão do `ListTile` (16), outras aplicam
   `EdgeInsets` caso a caso, e há um literal (`painel_listas.dart:264` → `EdgeInsets.only(top: 4)`).
   O resultado é alinhamento irregular entre telas e conteúdo encostando na borda em alguns casos.
   (`AppSpacing.horizontalCompacto` existe e **nunca é usado**.)
2. **O editor de item é um `AlertDialog`** (`_DialogoEditarItem`, `tela_lista_screen.dart:1146-1401`),
   aberto por `showDialog` (`:994-1003`), enquanto os outros modais do app usam `AppSheet.mostrar`.
   Com o teclado aberto, o `Dialog` centraliza e soma `viewInsets` (SDK), então o conteúdo — 5 campos
   empilhados — é espremido num viewport pequeno, só ele rola (título e ações ficam fixos) e o
   diálogo "pula"/encolhe. Não há `viewInsets` tratado no app nem campo focado trazido à visão.

## 2. Escopo

**Dentro:**
- Novo `AppPagina` (margem padrão de página) em `lib/core/widgets/`, aplicado nas telas/seções.
- Editor de item convertido em **bottom sheet** (`AppSheet.mostrar`) com os campos em **blocos**.
- Ajustes pontuais: literal `4` → `AppSpacing.xs`; remoção do token sem uso `horizontalCompacto`.
- Docs donos ([15 §1](../15-design-system.md), [10](../10-wireframes-telas.md), [05](../05-app-flutter.md)) e Fase 40 no [14](../14-tarefas.md).

**Fora:**
- Redesenho de cores, tipografia, ícones ou tokens existentes.
- Mudança de AppBar, FAB, bottom nav (`AppShell`), ou de qualquer overlay existente (`AppSheet`, `AppDialog`).
- Novas funcionalidades ou campos no editor (os campos, strings e a lógica de salvar **não** mudam).
- Alterar comportamento observável além da apresentação do editor.

## 3. Arquitetura

Dois componentes, ambos reutilizando o que já existe:

```
lib/core/
├── widgets/
│   ├── app_pagina.dart     ← NOVO: margem padrão das páginas (16dp lateral + SafeArea opcional)
│   └── app_sheet.dart      ← já existe: showModalBottomSheet + viewInsets.bottom
└── theme/tokens/app_spacing.dart   → perde `horizontalCompacto` (sem uso)

lib/features/listas/ui/tela_lista_screen.dart
└── _DialogoEditarItem (AlertDialog)  →  _SheetEditarItem (AppSheet + blocos)
```

A margem é aplicada **no nível do conteúdo**, não no `Scaffold` — AppBar, FAB e bottom nav continuam
intocados (o FAB e a nav bar são posicionados pelo `Scaffold`, e um wrap ali os quebraria).

## 4. `AppPagina` — margem padrão

```dart
/// Margem padrão de uma página (doc 15 §1): `AppSpacing.horizontal` (16dp) nas
/// laterais; `AppSpacing.tela` quando a tela quer respiro também em cima/baixo.
/// Quem rola é o filho (`ListView`/`Column`); o `AppPagina` só garante a margem.
class AppPagina extends StatelessWidget {
  const AppPagina({
    super.key,
    required this.child,
    this.padding = AppSpacing.horizontal,
    this.safeArea = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool safeArea;

  @override
  Widget build(BuildContext context) {
    final conteudo = Padding(padding: padding, child: child);
    return safeArea ? SafeArea(child: conteudo) : conteudo;
  }
}
```

**Regra de uso:** a margem lateral padrão é **16dp**. Telas com rolagem passam o `ListView`/`CustomScrollView`
como filho e usam `padding: EdgeInsets.zero` no scroll (a margem vem do `AppPagina`); telas de
formulário passam `padding: AppSpacing.tela, safeArea: true` (preserva o que já existia).

**Como aplicar — dois casos, para nunca duplicar padding:**

| Caso | Telas | O que fazer |
| :--- | :--- | :--- |
| **Conteúdo não se auto-padding** | `painel_listas`, `configuracoes`, `tela_membros`, `tela_ordenar_categorias`, auth/onboarding (`AppSpacing.tela` → `AppPagina` com o mesmo valor) | Envolver o corpo em `AppPagina`; o scroll interno usa `padding: EdgeInsets.zero`. |
| **Linhas/tiles já se paddingam** | `tela_lista` (`AppCabecalhoSecao`, `ExpansionTile.tilePadding`, `ListTile`), `mercado` (`_LinhaMercado`) | **Não** envolver (daria padding duplo, 32). Em vez disso, **normalizar** cada `EdgeInsets` ao token (16dp) e adicionar margem onde a linha não tem. O resultado (16dp em tudo) é o mesmo; o mecanismo é diferente. |

O critério do que entra no wrap é: **o conteúdo encosta na borda e não tem padding próprio?** Se sim,
`AppPagina`; se ele já se paddinga, normaliza.

**Não envolver (exceção documentada, mantém full-bleed):**
- Faixa de "marcados" (`mercado_screen.dart:375`) e fundo do swipe (`tela_lista_screen.dart:1019`).
- Divisores intencionais (`configuracoes_screen.dart:142`, `app_shell.dart:46`) e `NavigationBar`.
- Carrossel horizontal de chips (`tela_lista_screen.dart:667`) — scroll lateral intencional.
- Componentes que já se auto-padding: `AppCard`, `AppBanner`, `AppEstadoVazio`, `AppEstadoErro`,
  `AppEsqueleto` (envolver duplicaria o padding).
- `ListTile` de lista dentro de `AppPagina` fica alinhado: a margem de 16 coincide com o
  `contentPadding` padrão, então **não** há duplo padding quando a margem é aplicada no nível da página
  (e não por tile).

## 5. Editor de item → bottom sheet

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
  remover com Desfazer.
- O stepper `−/+` continua em volta do campo de quantidade (como hoje, `:1296-1335`).
- O rodapé substitui o `AlertDialog.actions`: `Remover` (quando `onRemover != null`, em cor de erro) à
  esquerda; `Cancelar` + `Salvar` à direita.
- Em telas muito estreitas, as duas colunas são separadas por `AppSpacing.md` e usam `Expanded` com
  `flex` 1:1; o `TextScaler` 2.0 continua sem estouro (verificado por teste).

## 6. Ajustes pontuais

- `painel_listas.dart:264` — `EdgeInsets.only(top: 4)` → `EdgeInsets.only(top: AppSpacing.xs)`.
- Remover `AppSpacing.horizontalCompacto` (`app_spacing.dart:15-17`): sem uso no repositório (YAGNI) —
  e retirar a menção correspondente do [15 §1](../15-design-system.md).

## 7. Testes

- **Widget do `AppPagina`:** aplica 16dp laterais por padrão; `padding`/`safeArea` configuráveis.
- **Sheet do editor:** abre por `AppSheet.mostrar` (não mais `AlertDialog`); os campos e o rodapé
  existem; salvar grava os mesmos valores (reescrever os testes que hoje buscam `AlertDialog`/`showDialog`);
  remover mantém o Desfazer; erro de nome/quantidade/preço inalterados.
- **Teclado:** teste que injeta `viewInsets` (via `tester.view.viewInsets`) e verifica que o sheet
  permanece com os campos alcançáveis e sem overflow (sem `Exception` de layout).
- **Regressão visual das telas com margem:** testes existentes de tela continuam verdes (o
  alinhamento não muda onde já era 16).

## 8. Docs donos

- **[15 §1](../15-design-system.md):** documentar `AppPagina` como a margem padrão de página e a regra
  (16dp lateral; `AppSpacing.tela` para formulários) e as exceções full-bleed; remover
  `horizontalCompacto` da lista de tokens.
- **[10](../10-wireframes-telas.md):** registrar a margem padrão e o editor de item como bottom sheet
  (hoje descrito como diálogo, se for o caso).
- **[05](../05-app-flutter.md):** acrescentar `AppPagina` à lista de componentes compartilhados (`App*`), com o papel de margem padrão de página.
- **[14](../14-tarefas.md):** Fase 40 com as tarefas e a linha de progresso.

## 9. Decisões registradas (23/09/2026)

1. **Margem de 16dp** (`AppSpacing.lg`, valor já de-facto do app) via wrapper compartilhado — não 24dp.
2. **Wrapper de página** (`AppPagina`), aplicado no conteúdo; **não** um `Scaffold` (não mexe em
   AppBar/FAB/nav).
3. **Editor vira bottom sheet** via `AppSheet.mostrar` (uniformiza com os outros modais e resolve o teclado).
4. **Campos em blocos** (linha dupla onde faz sentido), com rótulos curtos.
5. **Sem mudança de comportamento** no editor além da apresentação; sem novos campos.
6. `horizontalCompacto` **removido** (sem uso).

## 10. Documentos relacionados
- [15 Design System](../15-design-system.md) §1/§4 · [10 Wireframes](../10-wireframes-telas.md)
- [05 App Flutter](../05-app-flutter.md) · [14 Tarefas](../14-tarefas.md) (Fase 40)
- Specs de referência visual: [F8](2026-09-11-revisao-visual-ux-design.md) · [F9](2026-09-11-revisao-visual-ux-etapa2-design.md) · [F10](2026-09-11-revisao-visual-ux-etapa3-design.md)
