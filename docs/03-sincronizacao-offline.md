# 03 — Sincronização Offline-First

> Navegação: [← 02 Segurança RLS](02-seguranca-rls.md) · [04 IA / Edge Function →](04-ia-edge-function.md)

**Este documento é o dono das regras de sincronização e resolução de conflitos.**

Objetivo: o app funciona 100% offline (leitura, escrita, marcação) e sincroniza pendências ao reconectar, **sem duplicar nem perder itens** — o componente de maior risco técnico do projeto (ADR-004).

---

## 1. Princípios

1. **Drift/SQLite é a fonte de verdade local.** A UI nunca bloqueia esperando rede; toda leitura vem do cache local.
2. **Toda escrita é local primeiro.** A operação é aplicada no Drift e registrada na fila de mutações pendentes.
3. **IDs gerados no cliente** (UUID v4) para listas e itens — sem negociação de chaves na sincronização (ADR-006).
4. **Exclusão offline = soft delete** (tombstone `deletado_em`) — nada "ressuscita" ao sincronizar.
5. **Conflitos: last-write-wins (LWW)** por `updated_at`, com desempate pelo timestamp do servidor.

---

## 2. Arquitetura de sincronização

```
┌───────────────────────────────────────────────────────────┐
│                      APP FLUTTER                          │
│                                                           │
│   UI (Riverpod) ──leitura──► DRIFT/SQLite (fonte local)   │
│        │                          ▲            │          │
│        │ escrita                  │            │          │
│        ▼                          │            ▼          │
│   Fila de Mutações Pendentes ─────┘    Sync Engine        │
│   (operação + payload + ts local)      (flush na fila     │
│                                         + aplica remotos) │
└───────────────────────────────────────────────┬───────────┘
                                                │
                              Supabase (PostgreSQL + Realtime)
```

---

## 3. Fila de Mutações Pendentes

Tabela local Drift (`mutacoes_pendentes`):

| Coluna | Tipo | Descrição |
| :--- | :--- | :--- |
| `id` | `int` (autoincrement local) | Ordem de enfileiramento |
| `tabela` | `text` | `'listas'` \| `'itens_lista'` |
| `operacao` | `text` | `'INSERT'` \| `'UPDATE'` \| `'DELETE_SOFT'` |
| `registro_id` | `text` | UUID da entidade |
| `payload` | `text` (JSON) | Estado completo do registro no momento da operação |
| `ts_local` | `timestamptz` | Timestamp local da operação (vira `updated_at` no flush) |
| `lista_id` | `text` | Para agrupar/drenar por lista |
| `tentativas` | `int` | Contador de retry |

**Regras:**
* Fila **ordenada por lista**, drenada em sequência (mutações da mesma lista são aplicadas em ordem; listas distintas podem paralelizar).
* **Coalescing:** se houver múltiplas mutações do mesmo registro na fila (ex.: criar + editar + concluir), o flush envia apenas a **última** (o payload final + maior `ts_local`) — reduz requisições e elimina conflitos intra-dispositivo.
* Retry com **backoff exponencial** (1s → 2s → 4s → ... → máx. 5 min); após 10 tentativas, a mutação entra em estado `erro` visível na UI com ação "tentar de novo".

---

## 4. Fluxo de sincronização

1. **Escrita:** UI chama o repositório → Drift aplica local + enfileira mutação → dispara o Sync Engine (se online).
2. **Flush (online):** o Sync Engine drena a fila enviando ao Supabase:
   * `INSERT` → insert com `on conflict do nothing` (ID client-side pode já existir se outro dispositivo criou — improvável, UUID v4).
   * `UPDATE` / `DELETE_SOFT` → **upsert com comparação LWW** (Seção 5).
3. **Realtime (WebSocket):** mudanças remotas chegam → aplicadas ao Drift **se vencerem no LWW** → UI reage reativamente (Streams do Drift).
4. **Reconexão:** listener de conectividade dispara flush automático da fila.

### Pseudo-código do loop de flush

```dart
Future<void> flush() async {
  if (!online || _ flushing) return;
  _flushing = true;
  try {
    while (await fila.count() > 0) {
      final lote = await fila.proximasPorLista(); // ordenadas, agrupadas
      for (final m in lote) {
        final remoto = await supabase.upsertComLWW(m.payload);
        if (remoto.venceu) {
          await drift.aplicar(remoto);      // remoto venceu
          await fila.remover(m);
        } else {
          await fila.remover(m);            // local venceu; já foi enviado
        }
      }
    }
    status = Sincronizado;
  } on RateLimitException {
    await aguardar(backoff(++tentativas)); // retry
  } on AuthException {
    status = Reautenticar;                 // sessão expirada
  } catch (e) {
    await aguardar(backoff(++tentativas));
  } finally {
    _flushing = false;
  }
}
```

---

## 5. Resolução de conflitos: Last-Write-Wins (LWW)

Cada entidade carrega `updated_at` (timestamptz UTC).

Ao aplicar uma mudança remota sobre um registro local pendente:

| Situação | Resultado |
| :--- | :--- |
| `updated_at` remoto **>** local | Remoto vence: sobrescreve Drift, descarta mutação pendente correspondente |
| `updated_at` remoto **<** local | Local vence: mutação pendente permanece na fila e sobrescreve o servidor no flush |
| **Empate** | **Timestamp do servidor** (definido no insert) vence — regra anti-relógio-errado |

**Tombstones participam do LWW:** um item removido offline tem `deletado_em` + `updated_at` próprios. Se o tombstone for mais novo que uma edição remota, o item **não reaparece**.

### Casos-limite

| Caso | Comportamento |
| :--- | :--- |
| **Item criado e removido offline** | Nenhuma mutação sai da fila: o coalescing mantém apenas o `DELETE_SOFT`, que vira delete físico no servidor (ou tombstone remoto). Item nunca existiu para os outros |
| **Mesmo item marcado como concluído em 2 dispositivos offline** | Ambos geram UPDATE; o maior `updated_at` vence — sem perda além do esperado em LWW |
| **Relógio do dispositivo minutos/anos adiantado** | O dispositivo "vence" injustamente até o flush; após isso o servidor registra seu `updated_at`. Risco aceito (ADR-004); desempate de empates pelo servidor |
| **Relógio adiantado + servidor rejeita ts futuro?** | Servidor **aceita** o ts do cliente (não rejeita). Na dúvida, a divergência grosseira é detectada por `ts_local` vs `now()` do servidor no flush e logada no Sentry ([07](07-qualidade-ci.md)) |
| **Lista removida em A enquanto B adiciona itens offline** | Tombstone da lista vence; itens de B são criados mas a lista `deletado_em IS NOT NULL` some de todas as UIs. Aceitável no domínio |
| **Duplicação de nome** | `UNIQUE (lista_id, lower(nome)) WHERE deletado_em IS NULL` rejeita; o sync converte em "aumento de quantidade" quando unidades coincidem ([04 §Deduplicação](04-ia-edge-function.md)) |

---

## 6. Status de sincronização na UI

Máquina de estados exposta por provider Riverpod (`syncStatusProvider`):

```
[Sincronizado] ──escrita offline──► [Pendente(n)]
      ▲                                   │
      └────────── flush ok ───────────────┘
                                          │ perde rede
                                          ▼
                                     [Offline] ──reconecta──► [Sincronizando] ──► [Sincronizado]
                                          ▲                                          │
                                          └──────────── erro de rede ◄───────────────┘
```

| Estado | UI |
| :--- | :--- |
| `Sincronizado` | Ícone check discreto |
| `Sincronizando` | Spinner pequeno |
| `Pendente(n)` | Badge "N alterações pendentes" |
| `Offline` | Ícone nuvem cortada + banner discreto |
| `Erro` | Banner com ação "Tentar novamente" (após esgotar retries) |

---

## 7. Bootstrap e manutenção do cache local

* **Primeiro login:** baixa todas as listas/membros/itens ativos do usuário (query única por tabela) e popula o Drift.
* **Incremental:** Realtime mantém o cache atualizado; em reconexão longa (gap > X ou erro de stream), re-sync completo das listas do usuário (barato no volume de dados de listas de compras).
* **Multi-conta:** cache por `user_id` (mesmo dispositivo com contas distintas não mistura dados).
* **Logout:** limpa o cache local e a fila de mutações (após tentar flush final).

---

## 8. Checklist de validação (Fase 4)

- [ ] Modo avião: criar/editar/concluir/remover itens funciona; fila acumula.
- [ ] Reconexão: fila esvazia; servidor reflete tudo; sem duplicatas.
- [ ] 2 dispositivos simultâneos: mudanças aparecem < 1s (Realtime).
- [ ] Conflito de edição simultânea resolve por LWW sem erro visível.
- [ ] Item removido offline não reaparece em nenhum dispositivo.
- [ ] Relógio do dispositivo adiantado 1h: sync ainda converge.
- [ ] Kill do app com fila pendente: fila sobrevive ao restart.
- [ ] Status de sync reflete todos os estados da Seção 6.

---

## Documentos relacionados
- [01 Banco de Dados](01-banco-de-dados.md) — colunas `updated_at`/`deletado_em` que sustentam o LWW
- [02 Segurança RLS](02-seguranca-rls.md) — o sync passa pelas mesmas policies
- [05 App Flutter](05-app-flutter.md) — providers e repositórios que implementam este engine
- [07 Qualidade & CI](07-qualidade-ci.md) — testes de sync (prioridade máxima)
