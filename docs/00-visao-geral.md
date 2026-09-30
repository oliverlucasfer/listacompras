# 00 — Visão Geral, Stack, Setup, Riscos e Cronograma

> Navegação: [← Índice](../planejamento_lista_compras.md) · [04 Importação →](04-importacao-lista.md)

Este documento concentra a visão do produto, a stack tecnológica, os pré-requisitos de ambiente, os riscos conhecidos, as decisões técnicas (ADRs) e o cronograma por fases.

---

## 1. Visão do Produto

Aplicação multiplataforma **local** para criação, organização e execução de compras de supermercado. Combina gerenciamento manual com importação de listas enviadas em texto livre e backup JSON, **100% no aparelho** — sem conta, sem nuvem e sem sincronização.

> **Escopo:** **Android, iOS, Web e Desktop (Windows/Linux/macOS)**. O Web é o **Lite** (uso local, ADR-013). O Desktop entra a partir da Fase 18 (ADR-012). A Fase 48 consolidou o produto em **um único app** ("Minhas Listas", RF-31), removendo o app colaborativo e o Supabase.

### Funcionalidades-chave (resumo)
| Funcionalidade | Descrição resumida | Documento de referência |
| :--- | :--- | :--- |
| Gerenciamento manual de listas | Adição, quantidade/unidade, checkboxes, edição, ações em massa | [05 App Flutter](05-app-flutter.md) |
| Importação por texto | Parser local determinístico (offline) extrai itens e sugere categoria | [04 Importação](04-importacao-lista.md) |
| Offline-first local | Uso pleno sem conexão: o Drift é a fonte da verdade, no aparelho | [05 App Flutter](05-app-flutter.md) |
| Backup local | Exportar/importar `.json` (listas, itens, histórico de preços) | [05 §6.10](05-app-flutter.md) |

---

## 2. Stack Tecnológica

```
┌─────────────────────────────────────────────────────────────┐
│                    FLUTTER (Frontend)                       │
│       (Android, iOS, Web Lite, Desktop — Fase 18)           │
│         State management: Riverpod                          │
│         Importação: parser local (offline, RF-16)           │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        ▼
┌──────────────────────────────────────────────────────────────┐
│                    DRIFT / SQLITE (local)                    │
│  - Fonte de verdade no aparelho (offline-first)              │
│  - Histórico de preços, listas, itens, categorias            │
└──────────────────────────────────────────────────────────────┘
```

| Camada | Tecnologia | Motivo |
| :--- | :--- | :--- |
| Frontend | **Flutter (Dart)** + **Riverpod** | Base de código única para Mobile/Web/Desktop; Riverpod é compile-safe e testável |
| Persistência local | **Drift (SQLite)** | Banco relacional local com migrações versionadas; fonte de verdade offline |

---

## 3. Setup & Pré-requisitos

### 3.1. Contas necessárias
| Conta | Uso | Custo |
| :--- | :--- | :--- |
| [GitHub](https://github.com) | Repositório + CI (GitHub Actions) | Free |
| Play Console | Publicação Android (gate do dono) | Taxa única |

### 3.2. Ferramentas locais (versões mínimas — "stable recente")
| Ferramenta | Versão mínima | Observações |
| :--- | :--- | :--- |
| Flutter SDK | 3.24+ (stable) | Com Web e Android enabled (`flutter doctor`) |
| Dart | incluso no Flutter | — |
| Android Studio | latest stable | SDK + emulador; `adb` |
| VS Code | latest | Extensões Flutter/Dart |

### 3.3. Configuração de ambiente (checklist)
- [x] `flutter doctor` sem pendências para android/web. (aviso de licença Android é falso alarme do novo Android CLI — hash de licença presente no SDK)
- [x] GitHub Actions habilitado (ver [07 Qualidade & CI](07-qualidade-ci.md)). *(pipeline verde em PR + branch protection em `main` exigindo `flutter`)*

### 3.4. Variáveis e segredos
**Nenhum segredo no app.** O app não tem backend nem chaves de serviço; a política é "nada sai do aparelho". Segredos de CI/assinatura (`android/key.properties`) ficam fora do git.

---

## 4. Riscos & Mitigações

| # | Risco | Impacto | Mitigação acordada |
| :--- | :--- | :--- | :--- |
| R-05 | Escopo das plataformas atrasar o MVP | Médio | MVP restrito a Android/iOS/Web (ADR-001); Desktop entra na Fase 18 (ADR-012) |
| R-24 | Migração Drift de quem já tem dados locais | Médio | `onUpgrade` aditivo: passos antigos preservados + `deleteTable('mutacao_pendente')` (F48-T05); testar upgrade v10→v11 |
| R-25 | Perda dos dados locais (sem nuvem) | Alto para o usuário | Backup JSON exportar/importar (RF-31) e aviso na política de privacidade |

---

## 5. Registro de Decisões Técnicas (ADRs)

> ADRs **superadas** pela Fase 48 (remoção do Supabase) permanecem registradas como histórico: a decisão vigente é o **app único local**.

| # | Data | Decisão | Alternativas consideradas | Justificativa |
| :--- | :--- | :--- | :--- | :--- |
| ADR-001 | 02/09/2026 | MVP restrito a **Android, iOS e Web**; **Desktop suportado a partir da Fase 18** (ver ADR-012) | Todas as plataformas na v1 | Onde está o uso real (supermercado + casa); reduz tempo de build/teste |
| ADR-002 | 02/09/2026 | **Riverpod** como state management | Bloc, Provider + ChangeNotifier | Compile-safe, testável |
| ADR-003 | 02/09/2026 | **Drift/SQLite** como banco local | Isar, Hive | Relacional, migrações versionadas; fonte de verdade offline |
| ~~ADR-004~~ | 02/09/2026 | ~~Conflitos de sync via last-write-wins~~ | — | **Superada** (F48): não há sincronização |
| ADR-005 | 02/09/2026 | `unidade` como **enum fechado** | Texto livre | Elimina inconsistências ("kg" × "KG" × "quilos") |
| ADR-006 | 02/09/2026 | IDs gerados no **cliente** (UUID v4) | IDs do servidor | Permite criar dados offline sem negociação de chaves |
| ~~ADR-007~~ | 02/09/2026 | ~~Aceitar limitações do free tier Supabase; upgrade Pro~~ | — | **Superada** (F48): não há backend |
| ~~ADR-008~~ | 02/09/2026 | ~~Delete físico em cascata na exclusão de conta~~ | — | **Superada** (F48): não há conta |
| ~~ADR-009~~ | 02/09/2026 | ~~Sentry como observabilidade~~ | — | **Superada** (F48): nada sai do aparelho |
| ADR-010 | 02/09/2026 | **GitHub Actions** como CI desde a Fase 1 | Nenhum CI, GitLab CI | Já hospedamos no GitHub; pipeline simples (analyze + format + test) |
| ADR-011 | 08/09/2026 | `categoria` do item como **enum fechado** (11 valores) com sugestão local em camadas — memória por nome → dicionário estático → `outros` | Texto livre; sugestão manual | Consistência de dados ("Frios" × "frios"); preserva o offline-first |
| ADR-012 | 17/09/2026 | Suporte a **Web completo** e **Desktop (Windows/Linux/macOS)** (Fase 18): banco local por fábrica com import condicional (`WasmDatabase`/OPFS-IndexedDB no web, `NativeDatabase` no nativo/desktop); CI valida `flutter build web` e builds desktop | Web só SPA/leitura; adiar desktop indefinidamente | A base Flutter já cobre as plataformas; preserva o offline-first com o mesmo Drift |
| ADR-013 | 17/09/2026 *(revisado em 18/09/2026)* | **Publicação do Web cancelada por decisão do dono: o Web fica para uso local.** Rodar local: `flutter run -d chrome` (dev) ou `flutter build web` + servir `build/web`. | ~~Publicar em URL pública~~ — cancelado | Publicar o Web exigia manutenção de um site público sem uso previsto |
| ~~ADR-014~~ | 23/09/2026 | ~~Notificações push via FCM~~ | — | **Superada** (F48): push removido |
| **ADR-015** | 29/09/2026 | **App único local "Minhas Listas" (Lite).** O produto final é o Lite: um único app, 100% no aparelho, sem conta, nuvem, colaboração, sync ou push. Remove-se o Supabase (backend + cliente), Firebase, Sentry e a costura de modos (`AppModo`/`AppCapacidades`); a sessão passa a `idLocal = 'local'` e o backup é fixo local. | Manter os dois apps (colaborativo + Lite) | O dono decidiu que o produto final é o Lite (RF-31); o app colaborativo era peso morto (deps, backend, docs, duas suítes). |

---

## 6. Cronograma de Execução por Fases

> As fases de backend/colaboração (F1, F4, F5, F6, F7, F24, F30, F32, F34, F38 etc.) foram **removidas/superadas** pela Fase 48. Abaixo, o cronograma local vigente. O histórico completo está em [14 Tarefas](14-tarefas.md).

| Fase | Marco / Entrega | Descrição | DoD resumido |
| :--- | :--- | :--- | :--- |
| **Fase 11** | **Importação de lista (parser local)** | Modal de importação com parser local determinístico (RF-16), pré-visualização editável e gravação local. | Importação offline funcional; parser/testes verdes — spec em [superpowers/specs](superpowers/specs/2026-09-11-importacao-local-design.md) |
| **Fase 18** | **Suporte a Web e Desktop** | Banco local por plataforma (fábrica com import condicional: Drift/Wasm no web, nativo no desktop); pastas de desktop; CI validando `flutter build web` e builds desktop. | Web funcional e app abrindo/persistindo no Windows; CI verde — spec em [superpowers/specs](superpowers/specs/2026-09-17-suporte-web-desktop-design.md) |
| **Fase 22** | **Modo mercado e itens frequentes** | Tela focada para comprar no corredor (RF-18) e chips de sugestão derivados do histórico local (RF-19), 100% offline. | Botão/gate, tela do mercado e chips com testes verdes — spec em [superpowers/specs](superpowers/specs/2026-09-18-modo-mercado-frequentes-design.md) |
| **Fases 23–37** | **Features locais** | Duplicar lista, preço/total, orçamento, arquivar, adicionar de outra lista, ordem de categorias, frações, voz, boas-vindas e comparação entre idas. | Cada fase com spec e testes verdes ([14](14-tarefas.md)) |
| **Fase 41** | ~~Flavor Lite~~ **(histórico — superada pela F48)** | Primeira versão Lite (flavor `lite`), ainda convivendo com o app colaborativo. | Revertida pela F48 (ADR-015) |
| **Fase 47** | ~~Publicação do Lite~~ **(histórico — superada pela F48)** | Endurecimento do Lite para publicação na Play (RF-32). | Base reaproveitada no app único (F48) |
| **Fase 48** | **App único "Minhas Listas" (remoção do Supabase)** | Remoção de auth/sync/convites/push/Sentry e de toda a infraestrutura Supabase; app único local com identidade Lite (RF-31). | Um único `main.dart`, sem Supabase; docs donos atualizados; CI verde — spec em [superpowers/specs](superpowers/specs/2026-09-29-app-unico-lite-sem-supabase-design.md) |

---

## Documentos relacionados
- [04 Importação](04-importacao-lista.md) — parser local (RF-16)
- [05 App Flutter](05-app-flutter.md) — arquitetura, telas, UX e design
- [06 MVP & Entregas](06-mvp-entregas.md) — critérios, LGPD, publicação
- [07 Qualidade & CI](07-qualidade-ci.md) — testes e CI
- [09 Runbook de Operações](09-runbook-operacoes.md) — builds, distribuição, publicação
- [10 Wireframes das Telas](10-wireframes-telas.md) — layout de todas as telas
- [11 Usabilidade (Fase 5)](11-usabilidade-fase5.md) — roteiro e critérios de teste
- [15 Design System](15-design-system.md) — tokens, componentes, acessibilidade
