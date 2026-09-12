# Spec — Navegação e títulos das telas (Fase 10, F10-T06)

> Navegação: [← Spec do programa](2026-09-11-revisao-visual-ux-design.md) · [← Spec etapa 3](2026-09-11-revisao-visual-ux-etapa3-design.md) · [05 App Flutter](../../05-app-flutter.md) · [10 Wireframes](../../10-wireframes-telas.md) · [14 Tarefas](../../14-tarefas.md)

Data: 2026-09-11 · Status: aprovada

## 1. Objetivo

Refinar a navegação e a titulação das telas após a F10. Hoje:

- abrir uma lista usa `context.go('/lista/:id')` (rota fora do shell) → **sem seta de voltar** e o voltar do Android tende a sair do app;
- a aba diz **"Ajustes"** e o AppBar **"Configurações"**;
- a tela da lista mostra AppBar **sem título** nos estados carregando/erro/não encontrada;
- **Membros** mostra só "Membros", sem o nome da lista.

Muda comportamento → dono é o [doc 05](../../05-app-flutter.md) (rotas/navegação) e [doc 10](../../10-wireframes-telas.md) (layout); este spec apenas decide.

## 2. Decisões (2026-09-11)

| Decisão | Escolha | Justificativa |
| :--- | :--- | :--- |
| Modelo ao abrir lista | **Push sobre o shell** (tela cheia) | Back volta para a aba de origem; roteador simples; menos risco em deep links/testes |
| Back com pilha vazia | Fallback para `/listas` (dono) ou `/compartilhadas` (não-dono) | Aceite de convite/deep link cai no lar certo |
| Barra inferior na lista | Escondida (tela cheia) | Foco na tarefa; mantém a decisão do spec etapa 3 |
| Rótulo da aba Ajustes | **"Configurações"** (igual ao AppBar) | Consistência de wording; alinha com doc 06/wireframes |
| Título de Membros | `Membros · {título da lista}` | Dá contexto de qual lista |
| Estados da lista | Título de fallback `Lista` + seta de voltar | Nunca AppBar vazio |
| "Sair da lista" | Navega a `/compartilhadas` | É onde a lista compartilhada vivia |

### Alternativa descartada

**Aninhar `/lista` e `/membros` dentro de uma branch do `StatefulShellRoute`** (barra visível). Descartada porque cada branch tem seu próprio `Navigator` e uma rota pertence a uma única branch: a mesma lista pode ser aberta de **Minhas** ou de **Compartilhadas**, então ao aninhar só em Minhas a origem se perde (a barra pularia para "Minhas" e o voltar cairia lá). Aninhar uma cópia por aba dobraria rotas/testes e tornaria as URLs dependentes da origem.

## 3. Navegação

| Origem | Hoje | Novo |
| :--- | :--- | :--- |
| Card em **Minhas** | `go('/lista/:id')` | `push('/lista/:id')` |
| Card em **Compartilhadas** | `go('/lista/:id')` | `push('/lista/:id')` |
| Long-press em compartilhada | `push('/membros/:id')` | mantém |
| Menu ⋮ da lista → Membros | `push('/membros/:id')` | mantém |
| Aceite de convite (`/entrar` ou diálogo) | `go('/lista/:id')` | mantém (`go`) + fallback |
| Excluir lista (dono) | `go('/listas')` | mantém |
| Sair da lista (não-dono) | `go('/listas')` | `go('/compartilhadas')` |

- `/lista/:listaId` e `/membros/:listaId` continuam **top-level** (fora do shell).
- **Fallback de voltar:** quando `!context.canPop()`, `TelaListaScreen` e `TelaMembrosScreen` exibem seta própria e tratam o voltar do Android (`PopScope`) indo para `/compartilhadas` se o usuário **não é dono** da lista, senão `/listas`. Helper compartilhado em `lib/core/navigation/`.
- Quando há pilha (`canPop()`), o AppBar usa a seta padrão (pop).

## 4. Títulos

- **Configurações:** aba e AppBar usam `AppStrings.configuracoes` (remove `abaAjustes`).
- **Membros:** `Membros · {título}` via `listaPorIdProvider(listaId)`; fallback `Membros`.
- **Tela da lista:** estados carregando/erro/não encontrada recebem `AppStrings.lista` como título + seta de voltar; a mensagem continua no corpo. Com dados, o título segue sendo o título da lista.
- Login/Registro/Recuperar e `/design` (debug) inalterados.

## 5. Arquivos

- Modificar: `lib/features/listas/ui/painel_listas.dart` (push no tap).
- Modificar: `lib/features/listas/ui/tela_lista_screen.dart` (fallback de voltar + títulos dos estados).
- Modificar: `lib/features/convites/ui/tela_membros_screen.dart` (título contextual + fallback + sair).
- Modificar: `lib/core/navigation/app_shell.dart` (rótulo da aba).
- Modificar: `lib/core/l10n/app_strings.dart` (`lista`; remover `abaAjustes`).
- Criar: `lib/core/navigation/voltar_para_inicio.dart` (helper do fallback).
- Docs: 05 §4/§5, 10 §2/§3, spec etapa 3 (nota), 14 (F10-T06).

## 6. Testes

- `test/core/navigation/app_shell_test.dart`: rótulo "Configurações"; com router real, Minhas→lista→voltar cai em Minhas; Compartilhadas→lista→voltar cai em Compartilhadas.
- `test/features/listas/minhas_listas_screen_test.dart` e `compartilhadas_screen_test.dart`: card navega via push.
- `test/features/convites/tela_membros_screen_test.dart`: título contextual; seta de voltar.
- `test/features/listas/tela_lista_screen_test.dart`: asserções de título de membros; navegação push; fallback.

## 7. Critério de pronto

- Back correto por origem (seta e botão do Android) ao abrir lista/membros; fallback correto vindo de deep link/aceite.
- Aba e AppBar de Configurações iguais; Membros com nome da lista; estados da lista com título.
- `dart format --set-exit-if-changed .` / `flutter analyze` / `flutter test` verdes.
- Docs 05/10/spec etapa 3/14 atualizados; F10-T06 marcada.
