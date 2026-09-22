# Frente — Fluxos Críticos (E2E no widget) (design)

> **Status:** aprovado em 21/09/2026 (decisões registradas na Seção 7)
> **Fase:** 33 · **Requisito:** RNF-08 (qualidade/CI)
> **Docs donos:** [07](../07-qualidade-ci.md) (estratégia de testes/CI), [14](../14-tarefas.md), [16](../16-roadmap-pos-mvp.md)

---

## 1. Motivação

A suíte atual cobre unidades e telas isoladas, mas **não encadeia** os caminhos que o usuário realmente percorre (criar lista → adicionar → marcar; importar; entrar por código; operar offline). Um erro de integração entre telas/providers passa despercebido.

Esta frente adiciona **testes de fluxo no nível de widget** — ponta a ponta na camada UI+Drift, com o **router real** e fakes determinísticos — que **rodam no CI** (`flutter test`), sem device. É a fatia de E2E viável no ambiente atual.

## 2. Escopo

**Dentro:**
- Harness compartilhado de fluxo (router real + Drift in-memory + fakes).
- 4 fluxos críticos encadeados (criar/adicionar/marcar/limpar; importar por texto; entrar com código; operar offline).

**Fora / adiado (documentado no [07](../07-qualidade-ci.md)):**
- **Goldens**: adiados — são sensíveis à plataforma (o dev gera no Windows, o CI roda Linux); gerar quando houver um runner Linux dedicado. Decisão registrada.
- **`integration_test` (device/emulador)**: adiado — exige device; fica como smoke em device (como o deep link físico). O CI atual não roda emulador.

## 3. Harness

`test/fluxos/fluxo_harness.dart`, extraído do padrão do `app_shell_test.dart`:

```dart
/// Monta o app real (router) com Drift in-memory, sessão autenticada fake e
/// sync controlável — base dos testes de fluxo. Devolve o banco e o container
/// para inspeção.
Future<FluxoApp> montarApp(
  WidgetTester tester, {
  Future<void> Function(AppDatabase db)? seed,
  SyncStatus sync = const Sincronizado(),
  Future<List<ConvitePendente>> Function()? convites,
});
```

- Sobrepõe `authRepositoryProvider` (sessão autenticada — reusa `_AuthAutenticado` do `app_shell_test`), `appDatabaseProvider` (NativeDatabase.memory), `syncStatusProvider`, `meusConvitesPendentesProvider`.
- `SharedPreferences.setMockInitialValues({'onboarding_visto': true})` no `setUp` (não abrir as boas-vindas).
- `FluxoApp { AppDatabase db; ProviderContainer container; }` para asserts no Drift/fila.

## 4. Fluxos

Arquivos em `test/fluxos/` (um fluxo por `testWidgets`):

1. **`deve_criar_lista_adicionar_marcar_e_limpar_quando_fluxo_completo`** (`fluxo_lista_test.dart`):
   painel → FAB "Nova lista" → título → cria (card aparece) → abre a lista → digita item no campo → Enter (item pendente) → toca o checkbox (vai para "Itens Concluídos") → "Limpar concluídos" (some) → "Desfazer" (volta).
2. **`deve_importar_quando_cola_texto_e_confirma`** (`fluxo_importar_test.dart`):
   abre a lista → botão "Importar lista" → cola `"1kg de arroz, 2 leites"` → pré-visualização com 2 itens/unidades → confirmar → itens aparecem na lista (Arroz 1 kg, Leite 2 un).
3. **`deve_entrar_com_codigo_quando_token_valido`** (`fluxo_entrar_codigo_test.dart`):
   aba Compartilhadas → ação "Entrar com código" → cola um token → RPC `aceitar_convite` (fake) devolve a `lista_id` → navega para `/lista/:id`.
4. **`deve_manter_item_quando_adiciona_offline`** (`fluxo_offline_test.dart`):
   sync `Offline` → abre a lista → adiciona item → o item aparece localmente (Drift) e a fila (`mutacao_pendente`) tem a mutação com `tabela='itens_lista'`/`INSERT`.

## 5. Testes (meta)

- Os fluxos **são** os testes; rodam com `flutter test` no CI (job `flutter`).
- Nenhum mock de comportamento: fakes só de rede/auth (o Drift é real in-memory).

## 6. Documentos donos no mesmo PR
- `07` (nova subseção "Fluxos críticos (E2E no widget)"; registrar goldens/`integration_test` adiados e o motivo), `14` (Fase 33 + progresso), `16` (C2 concluído).

## 7. Decisões registradas (21/09/2026)

1. E2E dos fluxos críticos **no nível de widget** (roda no CI), com o **router real** e Drift in-memory.
2. **Goldens adiados** (divergência Windows×Linux); **`integration_test` adiado** (device) — ambos documentados no [07](../07-qualidade-ci.md).
3. Harness compartilhado em `test/fluxos/`; sem alterar produção.
4. Sem schema/RLS/sync; **sem ADR novo**. Fase **33**, requisito **RNF-08**.

## 8. Documentos relacionados
- [07 Qualidade & CI](../07-qualidade-ci.md) — estratégia de testes e o que fica adiado
- [14 Tarefas](../14-tarefas.md) — Fase 33
- [16 Roadmap](../16-roadmap-pos-mvp.md) — Onda C (C2)
