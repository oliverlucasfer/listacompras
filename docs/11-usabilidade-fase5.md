# 11 — Plano de Testes de Usabilidade (Fase 5)

> Navegação: [← 10 Wireframes](10-wireframes-telas.md) · [← Índice](../planejamento_lista_compras.md)

**Este documento é o dono do roteiro de usabilidade** da Fase 5 ("testes de usabilidade" no cronograma [00 §6](00-visao-geral.md)). Objetivo: validar que um usuário real consegue usar o app sem ajuda antes da publicação do MVP.

---

## 1. Método

* **Formato:** testes moderados presenciais/remotos (chamada + compartilhamento de tela), um participante por vez, ~30 min.
* **Participantes:** 3–5 pessoas, mix:
  * 1–2 que **nunca** viram o app (fresh eyes).
  * 1 usuário Web no computador + 1 no celular (validar o "efeito Google Docs").
  * Pelo menos 1 usuário real de supermercado sem perfil técnico.
* **Material:** 2 dispositivos preparados (Web + Android) com conta de teste criada; cenários e itens pré-definidos.
* **Regra de ouro:** o moderador **não ajuda** — só registra. Perguntar "o que você esperaria que acontecesse?" quando houver hesitação.

## 2. Roteiro de sessão

| # | Minuto | Atividade |
| :--- | :--- | :--- |
| 0 | 0–3 min | Contexto: "vamos ver você usando o app; pense em voz alta; não é você sendo avaliado" |
| 1 | 5 min | Tarefa T1 |
| 2 | 5 min | Tarefa T2 |
| 3 | 8 min | Tarefa T3 (offline — intermediador desliga o wi-fi) |
| 4 | 5 min | Tarefa T4 |
| 5 | 3 min | Impressões finais: "o que te confundiu? o que você mais gostou?" |
| 6 | — | Preencher log de sessão (Seção 5) |

## 3. Tarefas e métricas

Cada tarefa registra: **sucesso (S/F/A-ajudado)**, **tempo**, **erros/hesitações**, **comentários**.

### T1 — Criar lista e adicionar itens manualmente
> "Crie uma lista chamada 'Churrasco' e adicione: 2kg de Picanha e 1 Refrigerante."

| Métrica | Meta |
| :--- | :--- |
| Sucesso sem ajuda | ✔ esperado |
| Tempo | < 2 min |
| Erros típicos a observar | não acha o FAB; não percebe Enter salva |

### T2 — Importação por IA
> "Eu anotei de um amigo: '10 pães, 5 carvão, 2 refri de 2 litros, gelo'. Use o app para transformar isso em itens da sua lista."
* Observar: descobre o botão IA sozinho? Entende a pré-visualização? Corrige um item errado antes de confirmar?
* Meta: sucesso sem ajuda; tempo < 90s do paste ao save (métrica de produto [06 §5](06-mvp-entregas.md) — alvo < 30s em uso maduro).

### T3 — Uso offline e reconexão
> "Agora imagine que está no supermercado sem sinal. Marque a Picanha como comprada e remova o Refrigerante." *(moderador desliga o wi-fi)* → depois: "O sinal voltou." *(religa)*
* Observar: percebe que continua funcionando? Entende o banner/badge? Após reconectar, confere em outro dispositivo se sincronizou.
* **Critério crítico:** 100% das ações offline sobrevivem à reconexão, sem duplicatas — é o critério de aceite do MVP ([06 §1](06-mvp-entregas.md)).

### T4 — Sincronização multi-dispositivo (2º participante/dispositivo)
> "Marque um item no celular; agora veja no computador."
* Meta: mudança visível < 1s sem refresh; usuário percebe o valor ("nossa, apareceu já").

### T5 — Ações em massa (quick win se sobrar tempo)
> "A lista 'Churrasco' vai se repetir semana que vem. Prepare-a para reutilizar."
* Observar: encontra "Desmarcar todos" no menu (wireframe [10 §3.1](10-wireframes-telas.md))?

## 3.1. Critério de aprovação

| Resultado | Decisão |
| :--- | :--- |
| ≥ 80% das tarefas principais (T1–T4) concluídas sem ajuda **e** T3 com 100% de sucesso | **Libera publicação** (critério de aceite [06 §1](06-mvp-entregas.md)) |
| T3 falha em qualquer caso | **Bloqueia** publicação — sync é o coração do produto |
| 2+ participantes travam no mesmo ponto | Entrada obrigatória na lista de ajustes da Fase 5 |
| Ajustes cosméticos | Backlog pós-MVP |

## 4. Perfil de participante (formulário rápido)

- Nome/apelido, faixa etária.
- Frequência de compras de supermercado (semanal/quinzenal/mensal).
- Dispositivo principal: celular Android / iPhone (nota: iOS é Fase 6 — testar apenas o fluxo Web com estes) / computador.
- Já usou app de lista de compras? (sim/não, qual)
- Conforto com tecnologia: 1–5.

## 5. Log de sessão (template)

```markdown
## Sessão #N — [data] — Participante [código, ex. P3]
Perfil: [resumo do formulário] · Dispositivo: [Web/Android]

| Tarefa | Resultado | Tempo | Erros/Observações |
| :--- | :--- | :--- | :--- |
| T1 |  |  |  |
| T2 |  |  |  |
| T3 |  |  |  |
| T4 |  |  |  |
| T5 |  |  |  |

Pior momento: [onde travou]
Melhor momento: [o que elogiou]
Citações relevantes: "[frase literal do participante]"
Gravado? [sim/não]
```

## 6. Consolidação e decisão

1. Consolidação de todos os logs em tabela única (tarefas × participantes).
2. Priorizar problemas: **bloqueadores** (falha de tarefa) → **atritos** (hesitação, comentários) → **sugestões**.
3. Saída da Fase 5: relatório de 1 página com o resultado vs. critério de aprovação (3.1) + lista de ajustes classificada, apensada à publicação ([06 §4](06-mvp-entregas.md)).

---

## Documentos relacionados
- [06 MVP & Entregas](06-mvp-entregas.md) — critérios de aceite que este plano valida
- [10 Wireframes](10-wireframes-telas.md) — fluxos que os participantes percorrerão
- [00 Visão Geral](00-visao-geral.md) — Fase 5 no cronograma
