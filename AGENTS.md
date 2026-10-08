# AGENTS.md — Instruções para Agentes de IA

Projeto: app de lista de compras local e offline-first **"Minhas Listas"** (Flutter + Drift), 100% no aparelho. Documentação em `docs/` e índice em `planejamento_lista_compras.md`.

## Fluxo de trabalho obrigatório

1. **Leia `docs/13-premodelo-tecnico.md`** antes de qualquer tarefa — contexto técnico completo em uma leitura.
2. **Escolha a tarefa em `docs/14-tarefas.md`** — respeite as dependências (`Dep:`). Não pule tarefas de fases anteriores.
3. **Leia o doc dono indicado pela tarefa** (`Docs:`) — ele é a autoridade normativa.
4. Implemente e valide o **critério de pronto (CP)** da tarefa antes de marcá-la `- [x]` em `14-tarefas.md` e atualizar a tabela de progresso.
5. Mencione o ID da tarefa (ex.: `F48-T05`) e os requisitos ([`docs/12-prd.md`](docs/12-prd.md), ex.: `RF-16`) no commit.
6. **Respeite o gate do dono:** F5-T05 (usabilidade) e F5-T06 (publicação Play) só executam **sob solicitação explícita do usuário** — não inicie, não proponha nem as trate como bloqueadoras de outras tarefas. Builds de teste seguem a F5-T05b até lá.

## Regras não negociáveis

- **Doc dono é autoridade:** importação em `04`, app/UX em `05`, design system em `15`, entregas/LGPD em `06`, qualidade em `07`, operação em `09`, layout em `10`, usabilidade em `11`, requisitos em `12`. Mudança de comportamento exige atualizar o doc dono **no mesmo PR**. `13` é resumo — nunca sobrepõe o dono.
- **Nenhuma chave/segredo** em código, commit ou log.
- **Offline-first local:** o Drift é a fonte da verdade; não há rede nem sincronização. Escrita vai sempre ao Drift e IDs UUID v4 são gerados no cliente.
- **Enum de unidades fechado:** `un, kg, g, l, ml, caixa, pacote, pct, pt, dz, bdj, sc, fd, grf, ct, cc, mh, pe, cb, mc, rm, lt, vd, sch, rl, br, bsg, gl` — mantenha idêntico em `lib/core/dominio/unidade.dart` e no parser local (`04`).
- **CI verde obrigatório** antes de considerar qualquer tarefa concluída ([07](docs/07-qualidade-ci.md)).
- **Bump de versão:** ao mudar `version:` no `pubspec.yaml`, atualize **`web/version.json`** (`version` e `build_number` iguais) **e rode `flutter test`** — o guard `test/core/config/version_json_test.dart` exige paridade e o CI quebra sem isso.

## Comandos

```bash
flutter test                          # testes
dart format . && flutter analyze      # estilo e lint (CI exige)
```

## Convenções

- Código: comentários apenas quando indispensável; nomes `camelCase` (Dart) / arquivos de doc `NN-nome.md`.
- Testes: nome `deve_<resultado>_quando_<condição>` ([07 §1](docs/07-qualidade-ci.md)).
- Português (pt-BR) em docs e UI; commits concisos em pt-BR.
