# Spec — Busca e filtro (Fase 16)

> Navegação: [← 12 PRD](../../12-prd.md) · [05 App Flutter](../../05-app-flutter.md) · [10 Wireframes](../../10-wireframes-telas.md) · [14 Tarefas](../../14-tarefas.md)

Data: 2026-09-16 · Status: aprovada

## 1. Objetivo

Permitir encontrar rapidamente **listas** (no painel) e **itens** (na tela da lista) digitando um termo, com filtragem **local e offline** — sem rede, sem schema novo e sem mudança de sincronização.

Requisito novo: **RF-17** ([12](../../12-prd.md)). Fase nova: **F16 — Busca e filtro**.

## 2. Contexto

- O painel (Minhas/Compartilhadas) empilha todos os cards; com muitas listas, achar uma exige rolar (05 §6.2, 10 §2).
- A tela da lista agrupa itens por categoria (RF-15, 05 §6.3); em listas grandes, localizar um item exige rolar.
- Não existe busca/filtro hoje (`grep` em `lib/`). A entrada de texto existente só adiciona item ("Adicionar item").
- O app é offline-first: os dados já estão no Drift e expostos por streams locais (`listasComContagemProvider`, `itensDaListaProvider`) — filtrar em memória é imediato e funciona sem conexão.
- Já existe `normalizarTexto` (`core/texto/normalizar.dart`) — comparação sem acento/caixa, usada na deduplicação de itens.

## 3. Decisões (2026-09-16)

| Decisão | Escolha | Justificativa |
| :--- | :--- | :--- |
| Onde filtrar | **Em memória** sobre os streams locais, com helper puro | Offline, sem schema/RLS/sync; reusa `normalizarTexto`; testável em unidade |
| Escopo da busca no painel | **Só o título da lista** | Simples e previsível; não varre itens de todas as listas |
| Escopo da busca na tela da lista | **Nome do item** | É o que o usuário procura no mercado |
| Layout dos resultados (lista) | **Mantém os grupos de categoria** (ordem do enum), escondendo grupos vazios; concluídos que casam vão para a seção dobrável | Preserva o modelo mental do agrupamento (RF-15) |
| Drag com filtro ativo | **Desabilitado** | Reordenar uma visão filtrada gravaria `ordem` ambígua |
| Entrada | **Lupa na AppBar** revela um campo de busca; ✕ limpa e fecha | Padrão Material; não ocupa espaço permanente |
| Adicionar com busca ativa | **Limpa a busca** ao adicionar | O item recém-adicionado aparece (mesmo que não casasse com o termo) |
| Persistência do termo | **Nenhuma** (estado local da tela) | Busca é tarefa pontual; ao navegar, volta ao normal |
| Acentos/caixa | Normalizados (`normalizarTexto`) | "Café" casa com "cafe" |
| Provider novo | **Não** | Filtro no `build` sobre os streams existentes (volume não justifica indireção) |

## 4. Comportamento

### 4.1 Helper de busca

`contemBusca(String texto, String consulta)` — puro: normaliza ambos com `normalizarTexto` e retorna `true` quando o texto **contém** a consulta (`contains`). Consulta vazia significa "sem filtro" e é tratada pela UI, que nem chama o helper nesse caso.

### 4.2 Painel (Minhas Listas / Compartilhadas)

- Ícone de **lupa** na AppBar (à esquerda das ações existentes; na aba Compartilhadas, antes do `person_add`), com `tooltip` "Buscar".
- Ao tocar, aparece um **campo de busca** (`AppCampoTexto`) no topo do corpo, logo abaixo da AppBar, com `label` "Buscar lista" e `hint` de exemplo "Nome da lista", com foco automático; o ✕ na AppBar ("Limpar busca") limpa e fecha.
- A lista visível é `listasComContagem` filtrada por `contemBusca(titulo, consulta)`.
- **Sem resultados:** `AppEstadoVazio` ("Nenhuma lista encontrada" + "Tente outro termo."), sem CTA.
- **Sem busca:** comportamento atual (vazio real, FAB etc.) inalterado.
- O FAB só existe em Minhas; permanece visível durante a busca (não muda).

### 4.3 Tela da lista de compras

- Ícone de **lupa** na AppBar (todas as roles — buscar é leitura), com `tooltip` "Buscar"; revela, no topo do corpo, o campo `AppCampoTexto` com `label` "Buscar item" e `hint` de exemplo "Nome do item"; ✕ na AppBar limpa e fecha.
- Itens visíveis = `itensDaLista` filtrados por `contemBusca(nome, consulta)`.
- **Mantém o agrupamento** por categoria (ordem do enum) e **esconde grupos vazios**; a contagem do header `Categoria (n)` reflete os resultados filtrados.
- **Concluídos** que casam aparecem na seção "Itens concluídos (n)" (contagem filtrada).
- **Drag desabilitado** enquanto a busca está ativa (sem alça de reordenar; `SliverList` no lugar do `SliverReorderableList`).
- **Adicionar item** durante a busca: ao salvar, a busca é **limpa** (o item novo aparece).
- **Sem resultados:** `AppEstadoVazio` ("Nenhum item encontrado" + "Tente outro termo.") com ação "Limpar busca" (mantém o campo aberto).
- **Sem busca:** comportamento atual (incl. checkbox, swipe, menus) inalterado.
- Leitor: campo e ✕ funcionam; escrita continua bloqueada como hoje.

### 4.4 Acessibilidade (RNF-06, doc [15 §4](../../15-design-system.md))

- Lupa e ✕ com `tooltip`; o campo de busca tem rótulo acessível (`label`) e `hint` de exemplo.
- Alvos ≥ 48dp (já garantidos pelo `IconButton`/`AppCampoTexto`).
- O estado "sem resultados" usa `AppEstadoVazio` (rótulo único já conforme, F14-T01).

## 5. Arquivos

**Criar**
- `lib/core/texto/busca.dart` — `contemBusca(...)`
- `test/core/texto/busca_test.dart`

**Modificar (app)**
- `lib/core/l10n/app_strings.dart` — strings novas
- `lib/features/listas/ui/painel_listas.dart` — lupa/campo/filtro/vazio no painel
- `lib/features/listas/ui/tela_lista_screen.dart` — lupa/campo/filtro/grupos/drag/vazio na lista

**Modificar (testes)**
- `test/features/listas/minhas_listas_screen_test.dart`
- `test/features/listas/compartilhadas_screen_test.dart`
- `test/features/listas/tela_lista_screen_test.dart`

## 6. Strings novas (`AppStrings`)

`buscar` ("Buscar"), `buscarLista` ("Buscar lista"), `buscarItem` ("Buscar item"), `limparBusca` ("Limpar busca"), `nenhumaListaEncontrada` ("Nenhuma lista encontrada"), `nenhumItemEncontrado` ("Nenhum item encontrado"), `buscaSemResultadoDica` ("Tente outro termo.").

## 7. Testes

- **Helper:** unit de `contemBusca` (case/acento-insensitive, substring, termo que não casa, termo com espaços).
- **Painel:** a lupa revela o campo; digitar filtra os cards; termo sem resultado mostra o vazio de busca; ✕ limpa e volta ao normal.
- **Tela da lista:** a lupa revela o campo; digitar mantém grupos na ordem e esconde vazios; concluído que casa aparece na seção dobrável; drag `findsNothing` com busca ativa; "Adicionar" limpa a busca; sem resultado mostra o vazio com "Limpar busca".
- **A11y:** tooltips da lupa/✕.
- Regressão: suíte verde.

## 8. Documentos donos

| Doc | Mudança |
| :--- | :--- |
| **12 PRD** | Novo **RF-17** + linha na matriz de rastreabilidade |
| **05 §6.2/§6.3** | Busca no painel (título) e na lista (item), com as regras de grupos/drag/adicionar |
| **10 §2/§3** | Lupa/campo na AppBar, estados "sem resultados" (painel e lista) |
| **14** | Fase 16 + tarefas (F16-T00…T04) |
| **00 / índice** | Fase 16 no cronograma (se o 00 listar fases) |

## 9. Fora de escopo

- Busca de listas por **nomes de itens** (título + itens).
- Filtros por categoria/unidade/status (chips) e busca com destaque de termo.
- Busca global (listas + itens juntos), histórico de buscas e persistência do termo.
- Qualquer mudança de schema/RLS/Realtime/sync ou índices no Postgres/Drift.
- Ordenação alternativa dos resultados (mantém a ordem/grupos atuais).

## 10. Critério de pronto

RF-17 no 12; `05 §6.2/§6.3`, `10 §2/§3` e `14` (Fase 16) atualizados; helper + painel + tela da lista implementados com os testes da §7; `dart format` + `flutter analyze` + `flutter test` verdes.

## 11. Breakdown proposto (Fase 16)

- [ ] **F16-T00** — RF-17 + docs de planejamento (12, 05, 10, 14, 00/índice) — sem tocar código de app.
- [ ] **F16-T01** — Helper `contemBusca` (`core/texto/busca.dart`) + unit tests.
- [ ] **F16-T02** — Busca no painel (`painel_listas.dart`): lupa, campo, filtro por título, vazio de busca.
- [ ] **F16-T03** — Busca na tela da lista (`tela_lista_screen.dart`): lupa, campo, filtro por nome, grupos/esconder vazios, drag off, limpar-ao-adicionar, vazio.
- [ ] **F16-T04** — Acessibilidade, docs sincronizados e fechamento (CI verde).
