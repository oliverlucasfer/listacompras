# Frente — Ordem Pessoal das Categorias ("por corredor") (design)

> **Status:** aprovado em 21/09/2026 (decisões registradas na Seção 8)
> **Fase:** 28 · **Requisito:** RF-24 (ordem pessoal das categorias)
> **Docs donos:** [01 §3.2](../01-banco-de-dados.md) (enum/padrão), [05](../05-app-flutter.md) (UI),
> [10](../10-wireframes-telas.md) (layout), [12](../12-prd.md), [14](../14-tarefas.md), [16](../16-roadmap-pos-mvp.md)

---

## 1. Motivação

A lista agrupa os pendentes por categoria na **ordem do enum** ([01 §3.2](../01-banco-de-dados.md)) — a mesma para todo mundo. Mas cada supermercado tem o seu layout de corredores: quem compra sempre no mesmo lugar percorre os setores numa ordem própria. Reordenar as categorias **uma vez** e valer para todas as listas economiza voltas na loja.

É uma **preferência pessoal de exibição**: global (vale para todas as listas) e **local** (como o tema, [15](../15-design-system.md)), sem schema/RLS/sync. O enum não muda — só a ordem de exibição dos grupos.

## 2. Escopo

**Dentro:**
- Ordem **global** das 11 categorias, definida pelo usuário (arrastar-e-soltar).
- Persistência **local** (`SharedPreferences`), por dispositivo.
- Efeito: a tela da lista agrupa os pendentes na ordem salva.
- "Restaurar padrão" (volta à ordem do enum).

**Fora:** ordem por lista, sincronização entre dispositivos, reordenar o dropdown do editor (segue a ordem do enum).

## 3. Domínio (funções puras)

`lib/features/listas/domain/ordem_categorias.dart`:

```dart
/// Ordem completa: começa pela ordem salva (ignorando valores desconhecidos)
/// e anexa as categorias ausentes na ordem do enum — assim uma categoria nova
/// (ou uma ordem antiga) nunca some da UI.
List<CategoriaItem> normalizarOrdem(List<CategoriaItem> salva);

/// Serializa para CSV de `CategoriaItem.valor` (ex.: 'hortifruti,mercearia,...').
String serializarOrdem(List<CategoriaItem> ordem);

/// Desserializa o CSV; valores desconhecidos são ignorados e a ordem é
/// normalizada (anexa ausentes). `null`/vazio → ordem padrão do enum.
List<CategoriaItem> desserializarOrdem(String? csv);
```

- `CategoriaItem` é o enum fechado ([01 §3.2](../01-banco-de-dados.md)) com `.valor` e `.rotulo`; a **ordem do enum** é o padrão.
- Funções puras, sem dependências de UI/armazenamento — testáveis isoladamente.

## 4. Provider (preferência local)

`lib/features/listas/providers/ordem_categorias_provider.dart`, espelhando `temaModoProvider` ([15](../15-design-system.md)):

```dart
class OrdemCategoriasNotifier extends AsyncNotifier<List<CategoriaItem>> {
  @override
  Future<List<CategoriaItem>> build() async {
    final prefs = await SharedPreferences.getInstance();
    return desserializarOrdem(prefs.getString(_chave)); // _chave = 'ordem_categorias'
  }

  Future<void> definir(List<CategoriaItem> ordem) async { /* state + grava CSV */ }
  Future<void> restaurarPadrao() async { /* grava a ordem do enum */ }
}

final ordemCategoriasProvider =
    AsyncNotifierProvider<OrdemCategoriasNotifier, List<CategoriaItem>>(
  OrdemCategoriasNotifier.new,
);
```

- Sem rede, sem Drift: `SharedPreferences`, como o tema.
- Enquanto carrega, a UI usa a ordem do enum (default seguro).

## 5. UI

### 5.1. Configurações
- Novo item **"Ordenar categorias"** (ícone `Icons.reorder`/`Icons.sort`) na seção de Aparência/Preferências de Configurações ([05 §6](05-app-flutter.md), [10 §5](10-wireframes-telas.md)), abaixo do `SeletorTema`.
- Abre a tela/sheet `TelaOrdenarCategorias`.

### 5.2. Tela "Ordenar categorias"
- `ReorderableListView` com as 11 categorias (rótulo + alça de arrastar; alvo ≥48dp, `Semantics` de reordenação — RNF-06).
- Ação **"Restaurar padrão"** (volta à ordem do enum) com confirmação simples.
- Cada reordenação chama `definir(...)` (persiste na hora).
- Estado vazio não se aplica (sempre 11 categorias).

### 5.3. Efeito na lista
- `_ListaItens` (`tela_lista_screen.dart`) passa a iterar a **ordem salva** (`ordemCategoriasProvider`) em vez de `CategoriaItem.values`; a exibição segue `(categoria na ordem, ordem, id)`.
- O dropdown do **editor do item** mantém a ordem do enum (é um seletor; decisão registrada).

## 6. Testes

**Unit — `ordem_categorias.dart`:**
- `deve_normalizar_quando_faltam_categorias` (anexa ausentes na ordem do enum).
- `deve_ignorar_desconhecidas_quando_desserializar`.
- `deve_serializar_e_desserializar_round_trip_quando_ordem_valida`.
- `deve_retornar_padrao_quando_csv_nulo_ou_vazio`.

**Provider:**
- `deve_carregar_ordem_salva_quando_build` (`SharedPreferences.setMockInitialValues`).
- `deve_gravar_ordem_quando_definir`; `deve_voltar_ao_enum_quando_restaurar_padrao`.

**Widget:**
- `deve_abrir_ordenar_categorias_quando_toca_em_configuracoes`.
- `deve_persistir_quando_reordena` (mover uma categoria e conferir a ordem salva/estado).
- `deve_agrupar_na_ordem_custom_quando_lista` (a tela da lista mostra os grupos na ordem definida, não na do enum).
- `deve_restaurar_padrao_quando_confirma`.

## 7. Documentos donos no mesmo PR
- `01 §3.2`: a ordem do enum passa a ser o **padrão** (o usuário pode reordenar — RF-24).
- `05` (Configurações + agrupamento), `10` (item em Configurações + wireframe da tela), `12` (RF-24 + rastreabilidade), `14` (Fase 28 + progresso), `16` (A4).

## 8. Decisões registradas (21/09/2026)

1. Ordem **global** (todas as listas) e **local** (por dispositivo, `SharedPreferences`), como o tema.
2. Configurada em **Configurações** ("Ordenar categorias"), com arrastar-e-soltar + "Restaurar padrão".
3. O **enum não muda**; a ordem do enum é o **padrão** e o fallback.
4. O dropdown do **editor do item** segue a ordem do enum (não a custom).
5. Sem schema/RLS/sync; **sem ADR novo**. Fase **28**, requisito **RF-24**.

## 9. Documentos relacionados
- [01 Banco de Dados](../01-banco-de-dados.md) — enum de categorias (ordem padrão)
- [05 App Flutter](../05-app-flutter.md) / [10 Wireframes](../10-wireframes-telas.md) — Configurações e agrupamento
- [12 PRD](../12-prd.md) — RF-24
- [14 Tarefas](../14-tarefas.md) — Fase 28
- [16 Roadmap](../16-roadmap-pos-mvp.md) — Onda A (A4)
