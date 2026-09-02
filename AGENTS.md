# AGENTS.md — Instruções para Agentes de IA

Projeto: app de lista de compras inteligente e colaborativa (Flutter + Supabase + Gemini). Documentação em `docs/` e índice em `planejamento_lista_compras.md`.

## Fluxo de trabalho obrigatório

1. **Leia `docs/13-premodelo-tecnico.md`** antes de qualquer tarefa — contexto técnico completo em uma leitura.
2. **Escolha a tarefa em `docs/14-tarefas.md`** — respeite as dependências (`Dep:`). Não pule tarefas de fases anteriores.
3. **Leia o doc dono indicado pela tarefa** (`Docs:`) — ele é a autoridade normativa.
4. Implemente e valide o **critério de pronto (CP)** da tarefa antes de marcá-la `- [x]` em `14-tarefas.md` e atualizar a tabela de progresso.
5. Mencione o ID da tarefa (ex.: `F4-T03`) e os requisitos ([`docs/12-prd.md`](docs/12-prd.md), ex.: `RF-08`) no commit.

## Regras não negociáveis

- **Doc dono é autoridade:** schema em `01`, RLS em `02`, sync em `03`, IA em `04`, app/UX em `05`, entregas/LGPD em `06`, qualidade em `07`, compartilhamento em `08`, operação em `09`, layout em `10`, usabilidade em `11`, requisitos em `12`. Mudança de comportamento exige atualizar o doc dono **no mesmo PR**. `13` é resumo — nunca sobrepõe o dono.
- **Nenhuma chave/segredo** em código, commit ou log. `GEMINI_API_KEY` só via `supabase secrets set`.
- **RLS é sagrado:** qualquer dado acessado deve passar pelas policies de `02`. Nunca use a service_role key no client.
- **Offline-first:** UI nunca bloqueia em rede; escrita vai sempre ao Drift + fila ([03](docs/03-sincronizacao-offline.md)); IDs UUID v4 gerados no cliente.
- **Enum de unidades fechado:** `un, kg, g, l, ml, caixa, pacote, pct, dz` — mantenha idêntico no Postgres (`01`), Dart e `responseSchema` (`04`).
- **CI verde obrigatório** antes de considerar qualquer tarefa concluída ([07](docs/07-qualidade-ci.md)).

## Comandos

```bash
flutter test                          # testes
dart format . && flutter analyze      # estilo e lint (CI exige)
supabase db reset                     # aplica migrations local
supabase db push                      # aplica em produção (só via CLI)
supabase functions deploy parse-lista # deploy Edge Function
```

## Convenções

- Código: comentários apenas quando indispensável; nomes `snake_case` (SQL) / `camelCase` (Dart) / arquivos de doc `NN-nome.md`.
- Testes: nome `deve_<resultado>_quando_<condição>` ([07 §1](docs/07-qualidade-ci.md)).
- Migrations: `NNNN_descricao.sql` em `supabase/migrations/` — nunca SQL direto no dashboard em produção ([09 §2.4](docs/09-runbook-operacoes.md)).
- Português (pt-BR) em docs e UI; commits concisos em pt-BR.
