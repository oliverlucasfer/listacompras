# Spec — Compartilhamento de Listas por Link (F7)

> Navegação: [← 08 Doc dono](../../08-compartilhamento-colaborativo.md) · [14 Tarefas](../../14-tarefas.md)
> Requisito: RF-13 do [PRD](../../12-prd.md) (RF-14/transferência adiada)

Data: 2026-09-10 · Status: aprovada (abordagem C, link-only, sem transferência de dono)

## 1. Objetivo

Transformar a arquitetura "nasce pronta" (`lista_membros` + papéis + RLS, desde a Fase 1) no produto colaborativo: convidar pessoas por link para participar de uma lista como editor ou leitor, com Realtime garantindo janela de perda de acesso < 5s.

## 2. Decisões de escopo (acordadas em 2026-09-10)

| Decisão | Escolha | Justificativa |
| :--- | :--- | :--- |
| Canais de convite | **Somente link** (Fluxo A) | Edge Function `enviar-convite` + provedor transacional adiados (YAGNI; doc 08 §4 já admite); sem convites por e-mail o painel pendentes não chega a ter entradas nesta fase |
| Formato do link | `listacompras://listas/entrar?token=...` (custom scheme) + botão copiar token cru e colar ("Entrar com código") | Publicação Web/Play (F5-T06) adiada → universal link sem domínio; reusa intent-filter da F3-T03 |
| Transferência de dono | **Adiada** | Toque no trigger sensível `sync_dono`; sem ela o dono não sai da lista (membros comuns saem normalmente) |
| Realtime | **C (híbrida)**: canal para `lista_membros` + `convites` no publication (fidelidade ao 08 §7), mas painel de pendências faz fetch ao abrir (padrão de buscas no bootstrap do app) | Cumpre checklist 08 §9 (remoção < 5s); economiza canal de card |

Fora do escopo desta fase: convite por e-mail transacional, transferência, papéis além de editor/leitor, push notifications.

## 3. Banco de dados (migration `0007_convites.sql`)

- Tabela `convites` conforme doc 08 §2 (é autoridade — SQL lá, não aqui). Colunas `tipo`/`email` mantidas no schema por fidelidade, mas app só cria `tipo='link'` nesta fase; estado `expirado` nunca é gravado (é `pendente` + `expira_em < now()` no RPC).
- RLS conforme doc 08 §2 (dono: SELECT/INSERT/UPDATE(revogar)/DELETE; qualquer autenticado: SELECT somente de convite dirigido a si — irrelevante com link-only, mantido para o fluxo futuro).
- RPC `aceitar_convite(p_token uuid) returns uuid` — security definer, código do doc 08 §3.1; idempotente; erros `CONVITE_INVALIDO` / `CONVITE_NAO_DIRIGIDO_A_VOCE`.
- Sem RPC de revogar: dono faz UPDATE direto (RLS permite).
- Publication: `lista_membros` e `convites` adicionados a `supabase_realtime` (08 §7).
- `sync_dono` não é alterado nesta fase (transferência adiada).

## 4. Aplicativo (Flutter)

### 4.1 Camada de dados
- `ConvitesRepository`: cria convite (`tipo=link`), lista convites pendentes da lista (dono), revoga, e `aceitar(token)` via RPC (mapeia códigos de erro → mensagens pt-BR do contrato, padrão `ParseListaClient`/F4-T01).
- Bootstrap já traz listas do usuário; papel do usuário (`papel_na_lista`) chega junto do bootstrap para consultas de guarda.
- Sem fila offline para `convites` (operação exige conexão por natureza — criar/aceitar convite são chamadas diretas ao servidor; falha de rede = estado de erro com retry manual).

### 4.2 UI (wireframes em [10 §4](../../10-wireframes-telas.md))
| Componente | Comportamento |
| :--- | :--- |
| Sheet "Convidar" (dono) | Escolhe papel (editor/leitor) → gera link → copiar/compartilhar (intent) + copiar token |
| Tela de membros (dono) | Nome, papel; ações: mudar papel editor↔leitor, remover, (transferência adiada) |
| Live de membros | Realtime `lista_membros`: INSERT → "membro entrou" no topo; UPDATE papel → refetch papel local; DELETE → removido da lista |
| Perda de acesso | Dono-remove-me: DELETE de `lista_membros` < 5s → igual ao logout: flush + limpa cache/fila + refetch de listas (padrão do bootstrap de troca de usuário, F4-T06) |
| Banner "Você é leitor" | Lista em modo somente leitura: inputs/checkbox/swipe/menu desabilitados com dica |
| Painel "Convites pendentes" | Não se aplica a link-only nesta fase (não há e-mail dirigido)—card do Fluxo B fica para o futuro |
| Rota `/entrar?token=` (scheme `listacompras`) | Não autenticado → login/registro com contexto "Você foi convidado..." → retoma aceite; autenticado → chamada direta; também aceita entrar com token colado |
| "Sair da lista" | Menu da tela da lista: membro não-dono remove a própria participação (doc 08 §5) |

### 4.3 Nota de papel no sync
O `SyncEngine` não muda: LWW, dedup e fila seguem idênticos — quem pode escrever agora depende do papel; editor e dono já escreviam via RLS. Um leitor nunca gera mutações (UI bloqueia); se mesmo assim a fila tiver mutação órfã de liderança trocada, o erro cai no fluxo `ErroSync` existente (F4-T07) sem swallow silencioso.

## 5. Testes

- SQL: N-11…N-14 (RLS de convites — doc 02 §5) + casos do RPC (válido, expirado, revogado, idempotente, não-membro aceita).
- Dart: unit de `ConvitesRepository` (mock Rest/RPC), widget tests das telas (sheet convidar, membros, banner leitor, rota entrar com/sem sessão, sair da lista) e evento Realtime de remoção → cleanup (fake channel, pattern do `checklist_sincronizacao_test.dart`).
- CI verde ([07 §3](../../07-qualidade-ci.md)).

## 6. Critério de pronto da fase

Checklist de validação doc 08 §9, itens 1-3, 4-6, 8 (item 7/dono-adia e itens de e-mail/transferência removidos do escopo desta rodada; reavaliados na próxima).
