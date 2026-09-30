# 06 — MVP, Entregas, LGPD e Métricas

> Navegação: [← 05 App Flutter](05-app-flutter.md) · [07 Qualidade & CI →](07-qualidade-ci.md)

**Este documento é o dono dos critérios de aceite, da Definition of Done por fase e do compliance (LGPD/privacidade).** Cronograma detalhado em [00 §6](00-visao-geral.md). O app é **único e local** ("Minhas Listas", RF-31): sem conta, sem nuvem.

---

## 1. Critérios de aceite do MVP (checklist final)

> Cada critério rastreia requisitos de [12 PRD](12-prd.md) e tarefas de [14](14-tarefas.md).

- [ ] App abre direto em **Minhas Listas**, sem conta e sem rotas de login. *(RF-31)*
- [ ] Criar, renomear e excluir listas. *(RF-02)*
- [ ] Adicionar, editar, marcar como concluído, reordenar e remover itens com quantidade e unidade. *(RF-03, RF-04, RF-05)*
- [ ] Importar lista via texto livre com pré-visualização e confirmação. *(RF-16)*
- [ ] App funciona **100% offline** (leitura, escrita, marcação de itens) — o Drift é a fonte da verdade e nada depende de rede. *(RNF-02)*
- [ ] **Backup local** exportar/importar `.json`. *(RF-31)*
- [ ] Publicado: **APK/AAB disponível para teste interno** na Play Console (F5-T06, gate do dono).

---

## 2. Definition of Done por fase

Uma fase só está "pronta" quando:

| Fase | Definition of Done |
| :--- | :--- |
| **App Core** | CRUD manual funciona 100% local; widget tests do core no CI ([07](07-qualidade-ci.md)) |
| **Importação** | Contrato do parser local ([04](04-importacao-lista.md)) verde; modal e pré-visualização com testes |
| **Publicação** | Critérios de aceite da Seção 1 deste doc 100%; **testes de usabilidade aprovados** (roteiro e critério em [11](11-usabilidade-fase5.md)); política de privacidade publicada |
| **App único (F48)** | Remoção do Supabase (cliente + backend) com um único `main.dart`; docs donos atualizados; CI verde |

---

## 3. LGPD / Privacidade

### 3.1. Dados tratados

| Dado | Finalidade | Onde fica |
| :--- | :--- | :--- |
| Conteúdo das listas/itens | Funcionalidade central | **No aparelho** (Drift) |
| Histórico de preços | Comparação entre idas | **No aparelho** (Drift) |
| Áudio do microfone (voz) | Ditado de item, quando o usuário pede | Processado pelo reconhecedor do sistema; **não persiste no app** |

**Nada sai do aparelho por ação do app.** Não há conta, telemetria, analytics nem envio de erros. O app não coleta dados pessoais identificáveis.

### 3.2. Processadores de dados (subprocessadores)

| Serviço | Dado exposto | Observação |
| :--- | :--- | :--- |
| Reconhecedor de voz do sistema (Android/iOS) | Áudio do ditado | Acionado só quando o usuário toca o microfone; pode usar a nuvem do fabricante (limitação do SO) — declarado na ficha da loja |

### 3.3. Direitos do titular — implementação

| Direito | Como atendemos |
| :--- | :--- |
| Acesso aos dados | O app **é** a visão dos dados (listas/itens no aparelho) |
| Correção | Edição direta no app |
| **Exclusão** | Apagar a lista ou os dados do app (desinstalar); não há conta a excluir |
| Portabilidade | **Exportar backup** em `.json` (Configurações → Backup) |

### 3.3.2. Política de privacidade

* Texto simples (1 página) cobrindo: dados tratados (tudo local), ausência de conta/nuvem, voz do dispositivo, backup local, retenção e contato do encarregado.
* **Versão única (Lite):** o app exibe a política do Lite (sem conta/nuvem, com voz e backup local).
* **Onde:** texto in-app (Configurações) e página estática versionada em `site/privacidade.html`, publicada via GitHub Pages (workflow `.github/workflows/pages.yml`) em **https://oliverlucasfer.github.io/listacompras/privacidade.html**.
* **Contato do encarregado:** `contatoPrivacidadeEmail` = **`oliverlucasfer@gmail.com`**, interpolado no app e no HTML público. Um teste de paridade (`test/site/privacidade_html_test.dart`) garante que a página contém as frases-chave do texto Lite (`no seu aparelho`, `voz`) e o mesmo contato.
* **Requisito externo:** a URL pública só existe depois de habilitar Pages em *Settings → Pages → Source: GitHub Actions*.
* **Obrigatória para publicação** na Play Store (seção "Segurança de dados" do Play Console exige declaração de coleta).

### 3.4. Menores e consentimento

* Não direcionado a menores de 16 (texto na política). Sem rastreamento publicitário; sem consentimento de cookies no Web (sem cookies de marketing).

### 3.4.1. Cabeçalhos de segurança no Web

* Os cabeçalhos **COOP `same-origin` + COEP `require-corp`** (exigidos pelo Drift/WASM, que usa SharedArrayBuffer) não são aplicados pelo app: quem serve `build/web` (dev server do `flutter run` ou um static server próprio) deve configurá-los se quiser exercitar os caminhos de WASM/OPFS. O `flutter run -d chrome` já funciona sem configuração extra.
* **CSP recomendada (R-21)** — aplicar **quando o Web for servido por um static server**. Prefira **header HTTP**: em `<meta>`, `frame-ancestors`, `report-uri`/`report-to` e `sandbox` são ignorados.

  ```
  Content-Security-Policy:
    default-src 'self';
    script-src 'self' 'wasm-unsafe-eval' https://www.gstatic.com;
    style-src 'self' 'unsafe-inline';
    img-src 'self' data: blob:;
    font-src 'self' data: https://fonts.gstatic.com;
    connect-src 'self' https://www.gstatic.com;
    worker-src 'self' blob:;
    object-src 'none';
    base-uri 'self';
    form-action 'self';
    frame-ancestors 'none'
  ```

  > O app não faz chamadas de rede (`connect-src 'self'`), exceto o carregamento do CanvasKit/`sqlite3.wasm` quando servido do CDN (por isso `https://www.gstatic.com`). Para a política `'self'`-only mais apertada, compile com `flutter build web --no-web-resources-cdn`.

  Cabeçalhos de isolamento (SharedArrayBuffer/OPFS do Drift WASM):

  ```
  Cross-Origin-Opener-Policy: same-origin
  Cross-Origin-Embedder-Policy: require-corp
  ```

  Notas:
  - `script-src 'wasm-unsafe-eval'` cobre o CanvasKit/skwasm; `style-src 'unsafe-inline'` é exigido pelos estilos inline do Flutter.
  - `worker-src 'self' blob:` cobre o `drift_worker.js` (`sqlite3.wasm`/`drift_worker.js` vêm do próprio `build/web`).
  - `font-src` inclui `https://fonts.gstatic.com` para a fonte de fallback que o Flutter baixa.
  - Com COEP `require-corp`, recursos cross-origin exigem CORP; os assets locais do `build/web` são same-origin e o gstatic serve o CanvasKit com CORP.

---

## 4. Publicação

| Canal | Requisito | Observação |
| :--- | :--- | :--- |
| Web — **uso local** | Build `flutter build web` servido localmente | **Sem publicação** (ADR-013): rode com `flutter run -d chrome` ou sirva `build/web` |
| Desktop — Windows/Linux/macOS | Builds `flutter build windows`/`linux`/`macos` | Suportado desde a Fase 18 (ADR-012); builds Windows/Linux validados no CI ([07 §3](07-qualidade-ci.md)) |
| Android — teste interno | APK/AAB na Play Console (closed testing) | Política de privacidade + Declaração de Dados preenchidas |
| Android — produção | Publicação pública | Depende de validação do MVP; gate F5-T06 |
| iOS | App Store Connect | Conta Apple Developer; revisão da Apple |

**Nota do dono do projeto:** a publicação na Play (teste interno) está **adiada** — será executada apenas sob solicitação explícita, junto com a F5-T05. Canal provisório de distribuição de builds de teste: Firebase App Distribution (F5-T05b, externo ao app). Os critérios do DoD (§2) permanecem válidos para o dia do lançamento.

### 4.1. Checklist de publicação do Lite (RF-32, F47)

Publicação do Lite ("Minhas Listas") em produção — app 100% local, sem conta. Passos externos no runbook [09 §2.10](09-runbook-operacoes.md); textos e arte em [`store/ficha-lite.md`](../store/ficha-lite.md).

- [ ] AAB release assinado com a upload key (não debug key)
- [ ] Manifest sem `INTERNET`/push/Firebase; Auto Backup desligado
- [ ] Política de privacidade com URL pública (site/privacidade.html)
- [ ] Declaração de Dados preenchida (nenhum dado, exceto Áudio)
- [ ] Ficha da loja completa (ícone 512, feature graphic, screenshots, descrições)
- [ ] Closed test com 12 testadores por 14 dias
- [ ] Smoke em device release (identidade, offline, backup, voz)

---

## 5. Métricas de sucesso (pós-lançamento, opcional)

* Tempo médio de criação de lista via importação por texto < 30s (do paste ao save).
* Retenção semanal (listas criadas por semana por usuário ativo).

---

## Documentos relacionados
- [00 Visão Geral](00-visao-geral.md) — cronograma, riscos, ADRs
- [07 Qualidade & CI](07-qualidade-ci.md) — validação dos critérios
- [09 Runbook de Operações](09-runbook-operacoes.md) — publicação e build
