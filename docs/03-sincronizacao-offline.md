# 03 — Sincronização Offline-First

> Navegação: [← 02 Segurança RLS](02-seguranca-rls.md) · [04 Importação →](04-importacao-lista.md)

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
* **Coalescing:** se houver múltiplas mutações do mesmo registro na fila (ex.: criar + editar + concluir), o flush envia uma só — a **última** mutação (maior `ts_local`) define `id`/operação/ts, e o **payload é a mescla** dos payloads do registro (última vence por chave) — reduz requisições e elimina conflitos intra-dispositivo. A mescla é necessária porque updates de lista que não são de arquivo **omitem** `arquivada_em` (RF-22/F26): sem ela, arquivar e depois renomear offline perderia o arquivo no servidor.
* Retry com **backoff exponencial** (1s → 2s → 4s → ... → máx. 5 min); após 10 tentativas, a mutação entra em estado `erro` visível na UI com ação "tentar de novo".
* **Payload de itens inclui `categoria`** (enum fechado [01 §3.2](01-banco-de-dados.md), Fase 6/ADR-011). Clientes antigos (1.0.0+2) sem a coluna recebem o default no INSERT e o upsert LWW não toca a coluna fora do payload — categoria existente preservada ([01 §4.3](01-banco-de-dados.md)).
* **Payload de itens inclui `preco_centavos`** (preço unitário em centavos [01 §4.3](01-banco-de-dados.md), RF-21/F25). O aplicador trata a coluna com **tolerância**: ausente ou não numérica → `null` (linha gravada por app antigo), como em `categoria`; no merge LWW a coluna só é tocada quando presente no payload.
* **Payload de listas: `arquivada_em` só na mutação de arquivo** (estado de arquivo da lista [01 §4.1](01-banco-de-dados.md), RF-22/F26). A coluna é enviada **apenas** por arquivar/desarquivar; os demais updates (renomear, excluir) **omitem** a chave — o UPDATE deixa o valor do servidor intacto e o LWW segue em `updated_at`, evitando que um payload antigo com `arquivada_em = null` seja rejeitado pelo trigger `protege_arquivo_dono` ([01 §4.1](01-banco-de-dados.md)). O aplicador trata a coluna com **tolerância**: ausente → `null` (linha gravada por app antigo), como em `preco_centavos`; no merge LWW a coluna só é tocada quando presente no payload. A coluna herda o RLS de `listas` (sem policy nova); a autoria da mudança é restrita ao dono pelo trigger ([01 §4.1](01-banco-de-dados.md)).

---

## 4. Fluxo de sincronização

1. **Escrita:** UI chama o repositório → Drift aplica local + enfileira mutação → dispara o Sync Engine (se online).
2. **Flush (online):** o Sync Engine drena a fila enviando ao Supabase (com coalescing por registro — payload **mesclado**, §3):
   * **Sem linha remota → `INSERT`** (F12-T04): o `upsert` do PostgREST avalia a policy de UPDATE e era negado para listas novas; ID client-side é UUID v4, colisão é improvável.
   * **Com linha remota → `UPDATE`** (LWW já decidiu — Seção 5).
3. **Realtime (WebSocket):** mudanças remotas chegam → aplicadas ao Drift **se vencerem no LWW** → UI reage reativamente (Streams do Drift). O canal assina um **callback de status** (F20, R-12): a cada `SUBSCRIBED` — inclusive o primeiro e após uma reconexão — o bootstrap re-sincroniza o cache, cobrindo eventos perdidos em `CHANNEL_ERROR`/`TIMED_OUT` (Seção 7).
4. **Reconexão:** listener de conectividade dispara flush automático da fila.

> **Robustez (F12-T03):** o engine assina a fila **antes** de checar a conexão —
> falha na checagem (plugin/rede) não pode impedir o flush disparado por cada
> escrita, sob risco de a fila ficar presa e o status mascarar como
> "Sincronizado". No bootstrap, a cadeia serializada de trabalhos (`_encadear`)
> descarta o erro de um trabalho para que uma falha de rede não bloqueie os
> re-syncs seguintes.

> **Coalescing e concorrência (R-03):** a remoção pós-envio apaga apenas as
> mutações do registro que estavam no lote enviado (id ≤ id do lote). Uma edição
> feita pelo usuário durante o `await` de rede permanece na fila e sobe no ciclo
> seguinte — nunca é descartada.

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
| **Relógio adiantado + servidor rejeita ts futuro?** | Servidor **aceita** o ts do cliente (não rejeita). Na dúvida, a divergência grosseira é detectada por `ts_local` vs `now()` do servidor no flush (RPC `agora_servidor`, [02 §4.5](02-seguranca-rls.md)) e logada no Sentry ([07](07-qualidade-ci.md)) |
| **Lista removida em A enquanto B adiciona itens offline** | Tombstone da lista vence; itens de B são criados mas a lista `deletado_em IS NOT NULL` some de todas as UIs. Aceitável no domínio |
| **Duplicação de nome** | `UNIQUE (lista_id, lower(nome)) WHERE deletado_em IS NULL` rejeita; o sync converte em "aumento de quantidade" quando unidades coincidem |

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

> **Bootstrap (R-05):** a fila que já chega ao app com todas as mutações em 10 tentativas expõe `Erro` **já no bootstrap** — o engine deriva o estado da fila ao iniciar, em vez de exibir `Sincronizado`/`Offline` mentindo sobre a fila esgotada.

> **Laço, não reentrância (R-04):** o `flush()` drena em laço (`while`) e nunca chama a si mesmo de dentro do próprio trabalho — a chamada reentrante fazia `_flushAtual` apontar para o próprio futuro e fechava um ciclo de espera que só saía com restart do app.

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
- [ ] **Categoria (Fase 6, RF-15):** edição de categoria no dispositivo A aparece em B (LWW); registro remoto de app antigo sem `categoria` aplicado como `outros`.

---

## Documentos relacionados
- [01 Banco de Dados](01-banco-de-dados.md) — colunas `updated_at`/`deletado_em` que sustentam o LWW
- [02 Segurança RLS](02-seguranca-rls.md) — o sync passa pelas mesmas policies
- [05 App Flutter](05-app-flutter.md) — providers e repositórios que implementam este engine
- [07 Qualidade & CI](07-qualidade-ci.md) — testes de sync (prioridade máxima)
