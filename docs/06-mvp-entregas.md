# 06 — MVP, Entregas, LGPD e Métricas

> Navegação: [← 05 App Flutter](05-app-flutter.md) · [07 Qualidade & CI →](07-qualidade-ci.md)

**Este documento é o dono dos critérios de aceite, da Definition of Done por fase e do compliance (LGPD/privacidade).** Cronograma detalhado em [00 §6](00-visao-geral.md).

---

## 1. Critérios de aceite do MVP (checklist final)

> Cada critério rastreia requisitos de [12 PRD](12-prd.md) e tarefas de [14](14-tarefas.md).

- [ ] Usuário consegue registrar, autenticar (com verificação de e-mail) e recuperar senha. *(RF-01)*
- [ ] Criar, renomear e excluir listas. *(RF-02)*
- [ ] Adicionar, editar, marcar como concluído, reordenar e remover itens com quantidade e unidade. *(RF-03, RF-04, RF-05)*
- [ ] Importar lista via texto livre com pré-visualização e confirmação. *(RF-16)*
- [ ] Alterações refletem em tempo real entre Web e Mobile (mesma conta). *(RF-07, RNF-01)*
- [ ] App funciona 100% offline (leitura, escrita, marcação de itens) e sincroniza pendências ao reconectar, sem duplicar nem perder itens. *(RF-08, RNF-02)*
- [ ] RLS validado: um usuário não consegue ler/escrever listas de outro (testes de negação N-01…N-10 de [02 §5](02-seguranca-rls.md)). *(RNF-03)*
- [ ] **Exclusão de conta disponível no app** (ver Seção 3). *(RF-11, RNF-05)*
- [ ] Publicado: **Web acessível por URL pública** (`https://lista-compras-34f93.web.app`, Fase 19 — ADR-013).
- [ ] Publicado: **APK/AAB disponível para teste interno** na Play Console (F5-T06, gate do dono).

---

## 2. Definition of Done por fase

Uma fase só está "pronta" quando:

| Fase | Definition of Done |
| :--- | :--- |
| **1 — Infra & BD** | Migrations aplicam em `supabase db reset` do zero; checklist de [01 §8](01-banco-de-dados.md) e testes de negação de [02 §5](02-seguranca-rls.md) passam; Realtime ativo |
| **3 — App Core** | CRUD manual funciona online; telas de auth completas (login/registro/recuperação/verificação); widget tests do core no CI ([07](07-qualidade-ci.md)) |
| **4 — Sincronização** | Checklists de [03 §8](03-sincronizacao-offline.md) e [05 §8](05-app-flutter.md) passam; sync validado com 2 dispositivos simultâneos |
| **5 — Publicação** | Critérios de aceite da Seção 1 deste doc 100%; **testes de usabilidade aprovados** (roteiro e critério em [11](11-usabilidade-fase5.md)); política de privacidade publicada; exclusão de conta funcionando; Sentry sem erros críticos abertos |
| **6 — Pós-MVP** | Cada item definido com DoD próprio na época (compartilhamento — planejamento em [08](08-compartilhamento-colaborativo.md); iOS, desktop) |

---

## 3. LGPD / Privacidade

### 3.1. Dados tratados

| Dado | Finalidade | Base legal |
| :--- | :--- | :--- |
| E-mail + hash de senha | Autenticação | Execução de contrato (uso do app) |
| Conteúdo das listas | Funcionalidade central | Execução de contrato |
| Timestamps de uso (updated_at) | Sincronização | Legítimo interesse técnico |
| Erros/analytics (Sentry) | Estabilidade | Legítimo interesse — **sem conteúdo das listas em logs** |

**Não há dado pessoal sensível.** Não há venda/compartilhamento com terceiros além dos processadores listados na Seção 3.2.

### 3.2. Processadores de dados (subprocessadores)

| Serviço | Dado exposto | Local |
| :--- | :--- | :--- |
| Supabase (AWS) | Todos os dados do app | A definir na criação do projeto (preferir região `sa-east-1` — São Paulo) |
| Sentry | Stack traces e contexto técnico de erros | Conforme plano |

### 3.3. Direitos do titular — implementação

| Direito | Como atendemos |
| :--- | :--- |
| Acesso aos dados | O app **é** a visão dos dados (listas/itens do próprio usuário) |
| Correção | Edição direta no app |
| **Exclusão (conta)** | Botão "Excluir minha conta" em Configurações — **escopo da Fase 5, obrigatório para publicar** |
| Portabilidade | Exportar lista em texto (via copiar/compartilhar) — pós-MVP |

### 3.3.1. Exclusão de conta (Fase 5)

* Fluxo: Configurações → "Excluir conta" → confirmação dupla (senha + diálogo) → execução.
* **Estratégia: delete físico em cascata** (ADR-008):
  1. RPC `excluir_conta()` (SECURITY DEFINER) executa: `delete from auth.users where id = auth.uid()`.
  2. Cascades já existentes propagam: `lista_membros` (participações), `listas` onde `dono_id`, e `itens_lista` por CASCADE de lista.
  3. Sessão invalidada; app limpa cache local e fila de pendências.
* Listas compartilhadas onde o usuário era apenas membro: sua participação some; a lista do outro dono permanece (dados do titular removidos das membresias).
* Confirmação final para o usuário: "Esta ação é permanente e apaga todas as suas listas."

### 3.3.2. Política de privacidade

* Texto único e simples (1 página) cobrindo: dados coletados, finalidade, subprocessadores (3.2), retenção (até exclusão da conta), direitos do titular e contato do encarregado.
* **Onde:** página pública em `https://lista-compras-34f93.web.app/privacidade` (Fase 19, ADR-013) + link no cadastro e nas configurações do app.
* **Contato do encarregado:** por decisão do dono (17/09/2026) o texto permanece genérico ("canal informado na página do aplicativo"); preencher com um e-mail dedicado é pendência do lançamento público (F5-T06).
* **Obrigatória para publicação** na Play Store e App Store (seção "Segurança de dados" do Play Console exige declaração de coleta).

### 3.4. Menores e consentimento

* Não direcionado a menores de 16 (texto na política). Sem rastreamento publicitário; sem consentimento de cookies no Web MVP (sem cookies de marketing).

---

## 4. Publicação

| Canal | Requisito | Observação |
| :--- | :--- | :--- |
| Web (Fase 19) | Build `flutter build web` + Firebase Hosting ([ADR-013](00-visao-geral.md)) | Publicação em `https://lista-compras-34f93.web.app` pela F19 (deploy automático no CI); domínio próprio fica pós-MVP |
| Desktop — Windows/Linux/macOS (Fase 18) | Builds `flutter build windows`/`linux`/`macos` | Suportado desde a Fase 18 (ADR-012); builds Windows/Linux validados no CI ([07 §3](07-qualidade-ci.md)); publicação segue o gate do dono (Fase 5 / F5-T06) |
| Android — teste interno (Fase 5) | APK/AAB na Play Console (closed testing) | Política de privacidade + Declaração de Dados preenchidas |
| Android — produção | Publicação pública | Depende de validação do MVP; pode ficar para após Fase 5 |
| iOS (Fase 6) | App Store Connect | Conta Apple Developer; revisão da Apple |

**Antes de lançamento público:** revisar R-01 — avaliar upgrade Supabase Pro (gatilho documentado em [00 §4](00-visao-geral.md)).

**Nota do dono do projeto:** a publicação na Play (teste interno) está **adiada** — será executada apenas sob solicitação explícita, junto com a F5-T05 ([14-tarefas](14-tarefas.md)); a publicação do Web entra na Fase 19. Canal provisório de distribuição de builds de teste: Firebase App Distribution (F5-T05b). Os critérios do DoD (§2) permanecem válidos para o dia do lançamento.

---

## 5. Métricas de sucesso (pós-lançamento, opcional)

* Taxa de sincronização sem conflitos > 99% das sessões.
* Tempo médio de criação de lista via importação por texto < 30s (do paste ao save).
* Retenção semanal (listas criadas por semana por usuário ativo).

---

## Documentos relacionados
- [00 Visão Geral](00-visao-geral.md) — cronograma, riscos (R-01, R-06), ADRs
- [01 Banco de Dados](01-banco-de-dados.md) — CASCADEs que sustentam a exclusão de conta
- [07 Qualidade & CI](07-qualidade-ci.md) — Sentry e validação dos critérios
