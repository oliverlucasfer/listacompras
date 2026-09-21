# Frente — Adicionar Itens de Outra Lista (design)

> **Status:** aprovado em 21/09/2026 (decisões registradas na Seção 8)
> **Fase:** 27 · **Requisito:** RF-23 (adicionar itens de outra lista)
> **Docs donos:** [05](../05-app-flutter.md) (UI), [10](../10-wireframes-telas.md) (layout),
> [12](../12-prd.md) (requisitos), [14](../14-tarefas.md) (tarefas), [16](../16-roadmap-pos-mvp.md)

---

## 1. Motivação

Montar uma lista nova a partir de outra é comum (a lista do mês passado, a lista da casa da praia). Hoje o app tem **duplicar a lista toda** (RF-20) e **chips de itens frequentes** (RF-19, um a um), mas não há como **escolher itens de uma lista existente** e trazê-los em lote.

A feature é 100% offline: lê as listas/itens do Drift e escreve pelos caminhos normais (fila + LWW). **Sem schema, sem RLS, sem sync novos.**

## 2. Escopo

**Dentro:**
- Menu ⋮ da tela da lista → "Adicionar de outra lista" (dono/editor).
- Escolher a lista de origem (**todas** as do usuário, exceto a atual, **incluindo arquivadas**).
- Marcar os **pendentes** da origem (multi-seleção, "Selecionar todos") e adicionar à lista atual.
- Dedup pela regra já existente (mesmo nome normalizado → soma/replace).

**Fora:** copiar o preço (RF-21), origem nos itens frequentes (já há chips, RF-19), adicionar de uma lista por link/código.

## 3. Domínio e repositório (sem schema)

Extrair a regra de dedup hoje privada em `_adicionarItemDedup` (`tela_lista_screen.dart`) para o `ListasRepository`, reusada pela entrada rápida, pelo chip e pelo novo fluxo:

```dart
enum ResultadoDedup { adicionado, somado, substituido }

/// Adiciona um item à lista aplicando a dedup do app (RF-10): compara o nome
/// **normalizado** (`normalizarTexto`) com os itens ativos; mesmo nome e mesma
/// unidade → soma a quantidade; unidade diferente → substitui quantidade/unidade.
/// Sem existente → insere. Devolve o que aconteceu (para o feedback da UI).
Future<ResultadoDedup> adicionarItemDedup({
  required String listaId,
  required String nome,
  required double quantidade,
  required Unidade unidade,
  required CategoriaItem categoria,
});

/// Adiciona um lote de itens (origem em outra lista), um a um pela dedup.
/// Copia nome/quantidade/unidade/categoria; **ignora preço e concluído**.
Future<void> adicionarItensDedup(String listaId, Iterable<Item> itens);
```

- A **sugestão de categoria** continua na UI (`sugestaoCategoriasProvider`): o método recebe a categoria pronta. Na entrada rápida/chip, a tela sugere e passa; no lote de outra lista, a categoria vem do item de origem.
- Leitura dos itens ativos direto do Drift (não do provider), para o método ser testável e independente da UI.
- A tela passa a usar o método do repositório (o comportamento visível — SnackBars "somado"/"atualizado" — permanece, decidido pelo `ResultadoDedup`).

## 4. UI

- **Entrada:** item "Adicionar de outra lista" (`AppStrings.adicionarDeOutraLista`) no menu ⋮ da tela da lista, visível só a **dono/editor**.
- **Modal** (`AppSheet`/diálogo) com:
  1. **Seletor da lista de origem** — dropdown com as listas do usuário (Minhas + Compartilhadas) menos a atual; listas arquivadas aparecem com o rótulo "Arquivada". Fonte: `listasComContagemProvider`/Drift (offline).
  2. **Lista de pendentes** da origem — `CheckboxListTile` por item (nome, quantidade/unidade), com **"Selecionar todos"**; itens concluídos da origem não aparecem.
  3. Ação **Adicionar** (estática) — desabilitada com 0 selecionados.
- **Resultado:** ao confirmar, `adicionarItensDedup` roda em sequência e a tela mostra SnackBar com quantos entraram (`AppStrings.itensAdicionadosDeOutra(n)`); o modal fecha.
- **Origem vazia/sem pendentes:** estado vazio no modal ("Nenhum item pendente nesta lista").
- **Acessibilidade:** checkboxes com alvo ≥48dp, `Semantics` no seletor; escala 2.0 sem overflow.

## 5. Detalhes

- Unidade/categoria/quantidade vêm do item de origem; **preço não é copiado** (`null`).
- A lista atual **não** aparece como origem.
- Tudo local: nenhuma operação exige rede; a fila sobe ao reconectar.

## 6. Testes

**Unit — repositório (`listas_repository_test.dart`):**
- `deve_adicionar_quando_nome_nao_existe` (retorna `adicionado`).
- `deve_somar_quando_mesmo_nome_e_unidade` (retorna `somado`; quantidade somada).
- `deve_substituir_quando_mesmo_nome_e_unidade_diferente` (retorna `substituido`).
- `deve_ignorar_preco_e_concluido_quando_adicionar_lote` (`adicionarItensDedup` não copia preço; item entra pendente).
- `deve_aplicar_dedup_por_nome_normalizado_quando_adicionar_lote` (acento/caixa).

**Widget (`tela_lista_screen_test.dart`):**
- `deve_abrir_modal_de_outra_lista_quando_toca_menu` (só dono/editor).
- `nao_deve_mostrar_adicionar_de_outra_lista_para_leitor`.
- `deve_adicionar_selecionados_quando_confirma` (escolhe origem, marca 2, adiciona → itens na lista atual, SnackBar).
- `deve_selecionar_todos_quando_toca` e `deve_desabilitar_confirmar_quando_nada_selecionado`.
- `nao_deve_listar_a_propria_lista_como_origem`.
- escala de texto 2.0 sem overflow no modal.

**Regressão:** os testes atuais da entrada rápida/chip continuam verdes com o método extraído.

## 7. Documentos donos no mesmo PR
- `05 §6.3` (menu e modal), `10 §3` (wireframe do modal), `12` (RF-23 + rastreabilidade), `14` (Fase 27 + progresso), `16` (A3).

## 8. Decisões registradas (21/09/2026)

1. Entrada no **menu ⋮** da tela da lista, só dono/editor.
2. Origem: **todas** as listas do usuário, exceto a atual, **incluindo arquivadas**.
3. Traz **pendentes** escolhidos por **multi-seleção** (+ "Selecionar todos").
4. Dedup pela **regra existente** (soma/replace), extraída para o repositório.
5. **Não copia preço** (RF-21 fica para o editor do item).
6. Sem schema/RLS/sync; **sem ADR novo**. Fase **27**, requisito **RF-23**.

## 9. Documentos relacionados
- [05 App Flutter](../05-app-flutter.md) — tela da lista e modal
- [10 Wireframes](../10-wireframes-telas.md) — layout do modal
- [12 PRD](../12-prd.md) — RF-23
- [14 Tarefas](../14-tarefas.md) — Fase 27
- [16 Roadmap](../16-roadmap-pos-mvp.md) — Onda A (A3)
