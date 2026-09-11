# Spec — Refresh Visual das Telas (Etapa 2 / Fase 9)

> Navegação: [← Spec do programa](2026-09-11-revisao-visual-ux-design.md) · [15 Design System](../../15-design-system.md) · [10 Wireframes](../../10-wireframes-telas.md) · [14 Tarefas](../../14-tarefas.md)

Data: 2026-09-11 · Status: aprovada (executada na sequência da Etapa 1)

## 1. Objetivo

Aplicar os tokens e os componentes `App*` da Etapa 1 (`docs/15-design-system.md`) a todas as telas, eliminando as inconsistências visuais e de acessibilidade mapeadas na auditoria — **sem alterar comportamento, fluxos, textos visíveis nem contratos**. Comportamento continua no doc 05; layout no doc 10.

## 2. Escopo

Aplicar e corrigir, nas 12 telas/widgets de UI:

1. **Superfícies e spacing** — trocar paddings/raios/cores hardcoded por tokens (`AppSpacing`, `AppRadius`, cores do `Theme`/`AppSemanticColors`).
2. **Botões destrutivos** — usar `AppBotao(variante: destrutivo)` ou `AppDialog.confirmarDestrutivo` (foreground explícito, contraste garantido).
3. **Banners** — usar `AppBanner` (sync offline/erro, aviso da IA, somente leitura), com `on*Container`.
4. **Estados** — `AppEstadoVazio` (inclusive o vazio de itens que hoje é `Text('')` para leitor) e `AppEstadoErro` com retry onde faltava.
5. **Formulários** — `AppCampoTexto` + erro inline; `AppBotao(carregando:)` no lugar de spinners soltos.
6. **Sheets** — `AppSheet.mostrar` como padrão único.
7. **Acessibilidade (RNF-06)** — `tooltip`/`Semantics` nos ícones que faltam, alvos ≥ 48dp (ex.: chip de papel), contraste de banners.
8. **Strings** — mover hardcoded para `AppStrings`.
9. **Doc 10** — atualizar wireframes onde a UI mudou de forma perceptível (ex.: seção "Aparência" em Configurações).

## 3. Fora de escopo

- Mudança de fluxo/navegação/hierarquia (Etapa 3 / Fase 10).
- Alterar textos visíveis (os testes usam `find.text`).
- Backend, sync, IA, schema.

## 4. Restrições de execução

- Manter os **249 testes verdes**; `dart format` + `flutter analyze` limpos a cada tarefa.
- Os testes existentes usam `find.text` e alguns `find.byType`; não remover widgets/strings assertados sem ajustar o teste de forma que preserve a asserção.
- Toda cor/medida nova vem dos tokens ou do `Theme`; nada hardcoded na UI.

## 5. Auditoria → mudanças por tela

| Tela | Mudanças |
| :--- | :--- |
| **Auth** (login/registro/recuperar) | `AppCampoTexto`/`AppBotao(carregando)`/`AppBanner` para erro geral; ícones 64; tokens de spacing; strings hardcoded ("Informe seu e-mail:", dica do link) → `AppStrings`; tooltip no toggle de senha |
| **Minhas Listas** | `AppCard` para o card; `AppEstadoVazio`; `AppEstadoErro` com retry; diálogo destrutivo via `AppDialog`; tokens |
| **Indicador de sync** | `AppBanner` (offline/erro) com cores semânticas; alvos/tokens |
| **Tela da lista** | `AppBanner` (erro/offline/leitura), `AppEstadoVazio`/`AppEstadoErro` (itens), `AppDialog` (excluir/limpar), strings e `Colors.red` hardcoded → tokens/`AppStrings`; `tooltip` já existe no drag |
| **Modais IA** | `AppBanner` (aviso da IA), `AppBotao`, `AppCampoTexto`, tokens; strings hardcoded |
| **Configurações** | `AppCabecalhoSecao`, `AppBotao` destrutivo, `AppDialog`, `AppSheet` para a política; tokens |
| **Convites/membros** | `AppChip` (papel, alvo 48dp), `AppBotao`, `AppSheet`, `AppDialog`; tooltips/copiar; tokens |

## 6. Critério de pronto

Todas as telas usando tokens/componentes; `tooltip`/`Semantics` presentes nos ícones; alvos ≥ 48dp; banners com contraste correto; doc 10 sincronizado; `format`/`analyze`/`test` verdes. Fase 9 marcada em `14-tarefas.md`.
