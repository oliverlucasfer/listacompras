# Frente 1 — Modo Mercado e Itens Frequentes (design)

> **Status:** aprovado em 18/09/2026 (decisões registradas na Seção 7)
> **Fase:** 22 · **Requisitos:** RF-18 (modo mercado), RF-19 (itens frequentes)
> **Docs donos:** [05](../05-app-flutter.md) (app/UX), [10](../10-wireframes-telas.md) (layout),
> [12](../12-prd.md) (requisitos), [15](../15-design-system.md) (componentes), [14](../14-tarefas.md) (tarefas)

---

## 1. Motivação

A persona **P1 (Comprador solo)** — "usa o celular no mercado" — é o caso de uso central do
produto, mas a tela da lista concentra tudo: busca, drag-and-drop, menu, importação,
agrupamento por categoria e seção de concluídos. No corredor, com uma mão ocupada e sinal
ruim, essa densidade é hostil.

Em paralelo, o app nunca sugere o que comprar: toda lista começa do zero, mesmo sendo
recorrente. Itens frequentes atacam isso sem nenhum dado novo — o histórico de listas do
próprio usuário já está no Drift.

**Ambas as features são 100% offline e não tocam schema, RLS ou sync.** O modo mercado é
uma view alternativa sobre o `itensDaListaProvider` existente; itens frequentes é uma
consulta derivada sobre tabelas existentes.

## 2. Escopo

**Dentro:**
- RF-18: Modo mercado — rota dedicada `/mercado/:listaId`.
- RF-19: Itens frequentes — chips de sugestão na tela da lista.
- Limpezas baratas no mesmo ciclo: strings órfãs de IA, parser `pct`, decisão sobre
  `ConvitesRepository.pendentesDaLista()`.

**Fora (frentes seguintes, na ordem combinada):** preço/total por item, histórico de
compras como tela, iOS, convite por e-mail, R-01 (Supabase Pro).

## 3. RF-18 — Modo mercado

### 3.1. Entrada

- Botão na `AppBar` da tela da lista (`IconButton`, ícone `Icons.shopping_cart_checkout`,
  tooltip `AppStrings.modoMercado`), **visível apenas quando o papel efetivo pode escrever**
  (`papel == Papel.dono || papel == Papel.editor`, derivado de `papelEfetivoProvider`).
- Para `leitor` o botão não existe: sem escrita, a tela vira lista passiva que a tela da
  lista já cumpre melhor.
- Navegação: `context.push('/mercado/$listaId')` (fora do shell, como `/lista/:listaId`).

### 3.2. Rota

| Rota | Tela | Guard |
| :--- | :--- | :--- |
| `/mercado/:listaId` | `MercadoScreen` | autenticação + pertencimento (mesmo tratamento de `/lista/:listaId`) |

O voltar retorna à tela da lista (push); sem pilha (deep link), cai em `/listas`
(`botaoVoltarInicio`), seguindo o padrão de `/lista/:listaId`.

### 3.3. Layout

- `AppBar`: título da lista, seta de voltar, sem menu.
- Corpo (`Column`):
  1. `IndicadorSync` no topo (mesmo padrão da tela da lista e do painel).
  2. Contador do topo: `AppStrings.mercadoProgresso(marcados, total)`
     → ex.: `"3 de 12"` (marcados nesta sessão de tela / total de itens ativos da lista).
  3. Lista dos **pendentes** (`!concluido`), em `ListView` com itens de altura generosa
     (`AppSpacing.xl2`), checkbox à esquerda com alvo ≥48dp (RNF-06), nome e
     quantidade/unidade.
  4. Faixa recolhível **"Marcados (n)"** no rodapé, **fechada por padrão**
     (`ExpansionTile`), listando os concluídos com toque para desmarcar.

**Ao marcar um pendente:** `ListasRepository.editarItem(id, concluido: true)` → o item sai
da área principal e entra na faixa "Marcados"; a faixa abre automaticamente por alguns
instantes para o usuário ver para onde o item foi (ver 3.4).

**Ao desmarcar (toque na faixa):** `editarItem(id, concluido: false)` → o item volta ao topo.

**Sem:** grupos de categoria, busca, drag-and-drop, swipe, menu, importação, seção de
concluídos tradicional.

### 3.4. Desfazer o toque acidental

O erro é provável no corredor (celular guardado com a tela aberta). Em vez de SnackBar de
undo, a própria faixa "Marcados (n)" é o undo: o item está visivelmente a um toque de
distância, sem estado extra. A faixa abre automaticamente na primeira marcação de cada
sessão de tela e permanece aberta se o usuário estiver interagindo com ela.

### 3.5. Estados

| Estado | Comportamento |
| :--- | :--- |
| Carregando | `AppEsqueleto` (padrão da lista, F14-T09) |
| Erro | `AppEstadoErro` com retry (`ref.invalidate(itensDaListaProvider(listaId))`) |
| Lista não encontrada | `AppEstadoVazio` + CTA "Voltar para as listas" |
| Tudo comprado (0 pendentes) | `AppEstadoVazio` `AppStrings.mercadoTudoComprado` + CTA `AppStrings.voltarParaLista` |
| Leitor (não deveria chegar) | Enquanto o papel não carrega, o default conservador é leitor — a tela abre somente leitura, sem checkbox ativo |

## 4. RF-19 — Itens frequentes

### 4.1. Ranking

Serviço de consulta puro (`ItensFrequentes`), sem escrita e sem cache próprio:

1. Fonte: `item_local` ativo (`deletado_em IS NULL`) de **todas** as listas ativas do
   usuário no dispositivo (não só a lista aberta).
2. Agrupa por **nome normalizado** — reusa `normalizarTexto` (`lib/core/texto/normalizar.dart`,
   já usado pela busca do F16): sem acento, sem caixa.
3. **Peso por escopo:** ocorrência na lista aberta conta **2**; nas demais listas conta **1**.
   Hábitos da lista vêm primeiro, mas uma lista nova ainda recebe sugestões do histórico geral.
4. Ordena por peso DESC, depois nome ASC (determinístico).
5. **Exclui** nomes já ativos na lista aberta (comparação normalizada).
6. **Limiar:** apenas nomes com peso ≥ **2**. Consequência: um nome que aparece só na
   lista aberta (peso 2) atinge o limiar, mas é descartado pelo item 5 enquanto estiver
   ativo nela; ao sair da lista, ele passa a ser sugerido pelo histórico.
7. **Limite:** **8** sugestões.

Implementação sugerida: `customSelect` com `GROUP BY` sobre `item_local`, usando
`readsFrom: {_db.itemLocal}` para o stream reagir. O peso é um `SUM(CASE WHEN lista_id = ?
THEN 2 ELSE 1 END)`.

### 4.2. Apresentação

- **Chips horizontais** (rolagem lateral) acima do campo "Adicionar item", na tela da lista.
- **Regra de visibilidade:** os chips aparecem quando há sugestões e o texto do campo está
  **vazio** — independentemente de foco. Assim que o usuário digita o primeiro caractere,
  os chips somem (evita competição com o parser); ao limpar o campo, voltam.
- Tocar num chip: adiciona o item com **quantidade 1**, unidade `un`, categoria pela
  `SugestaoCategorias` (memória → dicionário → `outros`); limpa a busca ativa se houver
  (mesmo comportamento de "adicionar item" do F16-T03).
- Chip usa componente do design system (verificar reuso de `App*`; se não houver, criar
  `AppChipSugestao` em `lib/core/widgets/` seguindo o doc 15).
- Acessibilidade: chip com `Semantics` de ação ("Adicionar <nome>"), alvo ≥48dp.

### 4.3. Providers

Novo provider em `lib/features/listas/providers/listas_providers.dart`:

```dart
final itensFrequentesProvider = StreamProvider.family<List<SugestaoItem>, String>(
  (ref, listaId) => ref.watch(listasRepositoryProvider).watchItensFrequentes(listaId),
);
```

`SugestaoItem { String nome; int peso; }` em `lib/features/listas/domain/`.

## 5. Limpezas do mesmo ciclo

| Item | Ação | Verificação |
| :--- | :--- | :--- |
| `AppStrings.importarPorIa` (`app_strings.dart:71`) | remover (órfã desde a F17) | `grep` sem referências; teste de strings verde |
| Strings "importe por texto com IA" | remover ocorrências restantes | `grep` vazio |
| Parser: `pct` → `pacote` | mapear para o valor de enum `pct` | unit test do parser: `2 pct de X` → unidade `pct` |
| `ConvitesRepository.pendentesDaLista()` | **usar** — é a F21-T03 (revogar pendentes na UI), já planejada | será feita na F21, não na F22 |

> A decisão sobre `pendentesDaLista()` é mantê-lo e consumi-lo na **F21-T03**, que já existe
> no breakdown. Não vira tarefa da F22.

## 6. Testes

**Modo mercado** (`test/features/listas/mercado_screen_test.dart`):
- abre e mostra só pendentes, com contador correto;
- tocar num pendente marca (sai da área principal, entra na faixa) e persiste no Drift;
- tocar na faixa desmarca e o item volta;
- estado vazio "tudo comprado" quando não há pendentes;
- botão não aparece para `leitor`;
- escala de texto 2.0 sem overflow (`textScaleFactorTestValue` + `takeException`).

**Itens frequentes** (`test/features/listas/itens_frequentes_test.dart`, unit):
- agrupa por nome normalizado (acento/caixa);
- ignora tombstones;
- exclui ativos da lista aberta;
- peso 2 para a lista aberta, 1 para as demais (ordenação);
- limiar ≥2 e limite 8;
- desempate alfabético.
- widget test: chips aparecem, tocar adiciona item com quantidade 1 e categoria sugerida.

## 7. Decisões registradas (18/09/2026)

1. Modo mercado = **tela dedicada** (`/mercado/:listaId`), não toggle nem overlay.
2. **Pendentes no topo; marcados somem** para uma faixa recolhível "Marcados (n)" no rodapé.
3. Botão **escondido para leitor**, com gate por capacidade de escrita.
4. **Sem SnackBar de undo**: a faixa "Marcados (n)" é o undo.
5. Itens frequentes: **derivados do Drift**, sem tabela nova.
6. Escopo do ranking: **globais ponderados** (lista aberta peso 2, demais peso 1).
7. Apresentação: **chips** (Opção A) acima do campo, 8 sugestões, limiar ≥2, exclui ativos.
8. Fase **22** com as tarefas; limpezas incluídas.
9. **Sem ADR novo** — não há decisão arquitetural (sem schema/sync/RLS).

## 8. Documentos relacionados
- [05 App Flutter](../05-app-flutter.md) — arquitetura, rotas e telas
- [10 Wireframes](../10-wireframes-telas.md) — layout do modo mercado e dos chips
- [12 PRD](../12-prd.md) — RF-18, RF-19
- [15 Design System](../15-design-system.md) — componentes e a11y
- [14 Tarefas](../14-tarefas.md) — Fase 22
