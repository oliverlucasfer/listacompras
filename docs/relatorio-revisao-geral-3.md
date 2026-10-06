# Relatório — Revisão geral e aprofundada nº 3

> Data: 06/10/2026 · Base revisada: `main` @ `9ae391f` (e a branch da F59 @ `4686965`)
> Método: 6 revisões independentes **read-only** (dados, domínio/parsing, UI/estado, histórico/orçamento,
> plataforma, qualidade/segurança/docs), com verificação própria dos achados Critical.
> Totais: **2 Critical · 22 Important · 64 Minor**.
> Tarefas derivadas: **Fase 60** em [14-tarefas.md](14-tarefas.md). Relatórios detalhados (scratch): `.superpowers/review/` (não versionado).

---

## 1. Visão geral

O app é maduro e coerente com o offline-first: Drift é a fonte única, migrações corretas/testadas até v16,
CHECKs espelhando o contrato, datas UTC textuais, enums fechados, marcadores de UI consistentes e
679 testes verdes. Segurança/LGPD sólidos (sem segredos, sem rede no release, `allowBackup=false`).
Os problemas concentram-se em **robustez de borda** (backup, tratamento de erro, ciclo de vida) e
**dívidas de desempenho/consistência** no histórico.

## 2. Critical (corrigidos na `fix/revisao-geral-p0`)

- **C1 — Backup não incluía `orcamento_categoria`** (`features/backup/…`). Perda silenciosa dos limites
  por categoria (RF-36) no único mecanismo de recuperação. **Corrigido** (export/import + `BackupArquivo`,
  retrocompatível; doc 05 §6.10).
- **C2 — `parsePrecoParaCentavos` lançava `UnsupportedError`** para `NaN`/`Infinity`/`1e400`
  (`features/listas/domain/preco.dart`), escapando dos `on ArgumentError` de todos os call sites.
  **Corrigido** (guard `isFinite` + teste).

## 3. Important (registrados; ver Fase 60)

**Dados/backup:** `adicionarItemDedup` não atômico (`listas_repository.dart`); export de backup fora de
transação; restauração pode falhar por inteiro em merge de homônimos (`backup_repository.dart`); estatísticas/
preço por mercado varrem `item_ida` e normalizam em Dart (`historico_compras_repository.dart`).

**Domínio/parsing:** parser não reconhece `kilo(s)` (`parser_lista_local.dart`); `parseQuantidade` não
determinístico na web (`quantidade.dart`); etiqueta trata peso decimal `1,5kg` como preço (`etiqueta.dart`);
`formatarQuantidade` usa `.` decimal em pt-BR.

**UI/estado:** providers `family` sem `autoDispose` (`listas_providers.dart`); full-scan do histórico na tela
da lista; query ao banco por tecla no editor (`sheet_editar_item.dart`); escritas sem `try/catch`, incluindo
**importação parcial silenciosa** (`modal_previsao_importacao.dart`).

**Histórico/orçamento:** "Gasto por período" não preenche os 12 meses; "Por gasto" ordena só o top-10 por
frequência; cruzar orçamento editando o preço não alerta; seletor de evolução exibe nome normalizado.

**Plataforma:** `WidgetAtualizador` sem gate (Web/Desktop); voz fixa em `pt_BR`; helper de captura usa `ref`
após `await` sem guarda (`captura_foto.dart` — corrigido no PR da F59).

**Qualidade/docs:** identidade nativa divergente (iOS/Windows/Linux/macOS = "Lista de Compras"); higiene de
testes (`debugDefaultTargetPlatformOverride` sem `addTearDown`); doc 07 desatualizado sobre i18n.

## 4. Temas transversais

1. **Tratamento de erro inconsistente** — só o modo mercado segue o padrão (try/catch + rollback + snackbar).
2. **Ciclo de vida** — providers sem `autoDispose`, `ref` após `await`, plugin sem gate.
3. **Docs↔código** — 07, 05 (contagem ARB), README, nome nativo.
4. **Desempenho O(N)** — full-scans e materialização do histórico.
5. **Marca** — "Minhas Listas" não propagada aos cascos nativos.

## 5. Priorização

- **P0 (corrigido):** C1, C2, dedup atômica, guarda do `captura_foto`.
- **P1:** dados/UX corretos (F60-T04…T07).
- **P2:** robustez/perf/docs (F60-T08) e os 64 Minor (acessibilidade, virtualização, validação de payload
  compartilhado, notificações, etc.).

## 6. Documentos relacionados
- [05 App Flutter](05-app-flutter.md) · [07 Qualidade](07-qualidade-ci.md) · [13 Pré-modelo](13-premodelo-tecnico.md)
- [14 Tarefas](14-tarefas.md) (Fase 60) · [relatório nº 2](relatorio-revisao-geral-2.md)
