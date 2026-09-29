# Fase 47 — Publicação do Lite ("Minhas Listas") na Google Play (design)

> **Status:** proposto em 29/09/2026 (decisões na Seção 10)
> **Fase:** 47 · **Requisito:** RF-32 (novo) — Lite publicável na Play (produção pública)
> **Docs donos:** [06](../06-mvp-entregas.md) (publicação/LGPD), [09](../09-runbook-operacoes.md) (build/Play), [12](../12-prd.md) (requisito), [14](../14-tarefas.md) (tarefas); [05](../05-app-flutter.md)/[07](../07-qualidade-ci.md) se tocar app/CI.
> **Origem:** pedido do dono (29/09/2026): "quero revisar o app lite, pois quero colocar ele na play store".
> **Base:** os achados `L-01…L-21` estão no [relatório de revisão](relatorio-revisao-lite-play.md) (em `docs/`).

---

## 1. Motivação

O flavor `lite` ("Minhas Listas") já existe e é funcional (F41/F44), mas foi criado com **"Publicação em loja (gate F5-T06)" fora de escopo**. A F5-T06 e o checklist do [06 §1](../06-mvp-entregas.md) foram redigidos para o app **colaborativo** e para **teste interno** — não cobrem o Lite nem produção pública.

A revisão (`L-01…L-21`) mostra que publicar o Lite em produção esbarra em lacunas de **configuração nativa** (AAB, assinatura, Firebase/permissões herdadas, backup), **privacy/compliance** (política sem URL pública, Declaração de Dados, ficha) e **processo** (conta pessoal nova exige 12 testadores/14 dias). Esta fase resolve essas lacunas deixando o Lite **de fato "100% local"** (exceto pela voz, mantida por decisão), sem alterar o comportamento do app colaborativo.

## 2. Escopo

**Dentro:**
- Endurecer o Lite para "100% local de verdade": Sentry desligado por capacidades; Firebase/permissões de rede removidos do artefato Lite; Auto Backup desligado; **voz mantida** com divulgação.
- Build **AAB release assinado** e verificação no CI (build + manifest mergeado).
- Política de privacidade própria do Lite (texto in-app + **URL pública** no GitHub Pages) e contato pelo e-mail da conta de desenvolvedor.
- Ficha da loja e Declaração de Dados preparadas; runbook de publicação e trilha de testes (internal → closed 12/14 → produção).
- Novo requisito RF-32, checklist de publicação do Lite no [06], runbook no [09], Fase 47 no [14].

**Fora:**
- Alterar o comportamento público do app **colaborativo** (`prod`) e seu backend/RLS/migrations.
- Publicar o `prod` (continua no gate F5-T06) ou o Web/desktop.
- iOS (segue adiado, Onda E).
- Remover dependências Firebase/`firebase_messaging` do `pubspec` (as libs seguem no APK, inertes) — corte de dependências é outra frente.
- Migração/troca de plugin de voz ou reconhecimento 100% on-device.

## 3. Endurecimento do Lite (app)

### 3.1 Sentry (L-03)
`bootstrap.dart` passa a **não inicializar o Sentry quando `!cap.nuvem`**, independentemente de `SENTRY_DSN`. O build de publicação do Lite usa **nenhum `--dart-define`** (não precisa de Supabase nem DSN), o que elimina o risco de vazamento por arquivo de defines. O `prod` permanece inalterado (Sentry opcional por DSN).

### 3.2 Firebase e permissões herdadas (L-04, L-05)
Novo `android/app/src/liteRelease/AndroidManifest.xml` (source set do **variant release do Lite**, para não afetar o debug nem o `prod`) com `xmlns:tools` e `tools:node="remove"`:
- **Permissões removidas:** `INTERNET`, `POST_NOTIFICATIONS`, `com.google.android.c2dm.permission.RECEIVE`, `ACCESS_NETWORK_STATE`, `WAKE_LOCK`.
- **Componentes removidos:** providers/receivers/services do Firebase/Messaging (`FirebaseInitProvider`, `FlutterFirebaseMessagingInitProvider`, `FirebaseInstanceIdReceiver`, `FlutterFirebaseMessagingReceiver`, `FlutterFirebaseMessagingService`, `FlutterFirebaseMessagingBackgroundService`, `ComponentDiscoveryService`, `FirebaseMessagingService`), evitando a auto-inicialização nativa.
- **Mantidas:** `RECORD_AUDIO` (voz).

As bibliotecas continuam empacotadas (tamanho), porém inertes; a garantia de "sem rede" vale para o **artefato publicado** (release). O `prod` e o debug do Lite não mudam.

### 3.3 Backup e Auto Backup (L-06)
No mesmo manifest de `liteRelease`: `android:allowBackup="false"` e `android:dataExtractionRules` apontando para um XML que exclui backup em nuvem e transferência entre aparelhos — o banco Drift e `shared_preferences` **não saem do aparelho**. Entregue apenas isso, **sem** `tools:replace` e **sem** `android:fullBackupContent`: não há conflito de merge a resolver e a transferência direta entre aparelhos já é coberta pelas `dataExtractionRules`. O backup JSON manual (exportar/importar, já existente) continua sendo o canal do usuário.

### 3.4 Voz (L-12)
Voz **mantida** (decisão do dono) com `onDevice: true` (já existente). Como o SO pode usar o reconhecedor de rede, o app **divulga** isso (texto informativo no fluxo de voz) e a **política** passa a cobrir áudio. A Declaração de Dados declara **Áudio**.

### 3.5 Trava de release (L-11)
A trava `flavor × modo` (`bootstrap.dart`) deixa de ser só `kDebugMode`: no release, em caso de divergência (pacote `.lite` com modo colaborativo, ou o inverso), o app exibe uma **tela de erro bloqueante** em vez de subir o app errado silenciosamente. O build de publicação sempre usa `-t lib/main_lite.dart` (garantido por CI/runbook).

## 4. Build, assinatura e CI (L-01, L-02, L-10, L-13)

- **AAB de publicação:** `flutter build appbundle --release --flavor lite -t lib/main_lite.dart` — **sem `--dart-define-from-file`**. Comando no [09 §2.9].
- **Assinatura:** validação de que o AAB de publicação foi assinado com a **upload key** (`android/key.properties`), não com a debug key; Play App Signing habilitado no Console. O fallback para debug key continua apenas para builds locais/CI de validação.
- **CI:** novo passo que compila o **AAB release do Lite** (sem keystore, debug-signed, só para validar compilação/R8) e um **teste do manifest mergeado** que falha se `android.permission.INTERNET` ou componentes Firebase aparecerem no `liteRelease`.
- **R8:** validar o AAB release (sem `proguard-rules` extra) e registrar o resultado; adicionar `proguard-rules.pro` só se necessário.

## 5. Privacidade e conformidade Play (L-07, L-08, L-12)

### 5.1 Política de privacidade
- Texto **cobrindo o Lite** (sem conta/nuvem; dados só no aparelho; voz; backup manual; compartilhamento iniciado pelo usuário) com **contato = e-mail da conta de desenvolvedor**. Como `politica_privacidade.dart` é compartilhado, o texto passa a ser **derivado das capacidades** (variante Lite × colaborativa).
- **URL pública:** página estática em `site/privacidade.html` publicada por um workflow de GitHub Pages (pasta `site/`, para não expor `docs/`). A URL entra na ficha e no [06 §3.3.2]. **Ressalva:** GitHub Pages exige repositório público (plano free); se este repo for privado, publicar de um repositório público dedicado à política (o texto continua versionado aqui).

### 5.2 Declaração de Dados / Segurança de dados
- **Dados coletados: nenhum**, exceto **Áudio** (recurso de voz; processado pelo reconhecedor do sistema). Sem conta, sem analytics, sem crash logs (Sentry desligado), sem anúncios.
- Preencher o questionário (coleta, finalidade, criptografia em trânsito para a voz, exclusão).

### 5.3 Ficha da loja
- Título **"Minhas Listas"** (verificar disponibilidade — L-18), descrição curta/longa, **ícone 512×512** (a partir de `logo_lite`), **feature graphic 1024×500**, **screenshots** de telefone, categoria, público-alvo **16+**, anúncios **não**, classificação indicativa.
- Fichas/artefatos documentados no [06] (seção do Lite) e versionados quando possível (texto/arte no repo).

## 6. Operações e gate externo (L-09)

Conta **pessoal nova** (criada após 13/11/2023):
1. Criar a conta, verificação de identidade e **verificação de aparelho**.
2. Criar o app `br.com.oliverlucas.listacompras.lite` no Console; upload key/Play App Signing.
3. Publicar na **internal testing** (smoke) → **closed testing** com **≥12 testadores por 14 dias contínuos** (o relógio só conta com testadores opt-in e ativos).
4. Aplicar para **acesso à produção** → revisão → **rollout 10% → 50% → 100%**.
5. Hotfix: branch `hotfix/...` → novo AAB → produção/teste interno ([09 §4]).

Passos, histórico e smoke vão no [09]. A trilha externa começa **em paralelo** ao código (é o caminho crítico de ~2+ semanas).

## 7. Entregáveis

**No repositório (Fase 47):**
- Endurecimento do Lite (Seção 3), build/CI (Seção 4), política + `site/` (Seção 5.1), teste de manifest, tela de erro de release.
- Docs donos: [12] (RF-32 + matriz), [06] (checklist/seção do Lite + política/contato), [09] (AAB/Play do Lite), [14] (Fase 47 + progresso). Atualizar a spec do Lite (L-17) e o [16] (Onda E/bloqueio).
- Ficha: textos e arte de loja versionados; screenshots.

**Externo (ações do dono, roteirizadas no [09]):**
- Conta Play, verificação, app no Console, upload key, Data Safety, ficha, tracks e rollout. E-mail de contato do encarregado.

## 8. Testes e validação

- **Unit/widget:** Sentry não inicializa no Lite; trava de release bloqueia build errado; política por capacidades.
- **Manifest/CI:** `liteRelease` sem `INTERNET` nem componentes Firebase; AAB release compila.
- **Smoke em device (release):** identidade (ícone índigo/cesta, "Minhas Listas", splash), abre em Minhas listas sem login; **modo avião**: CRUD/backup funcionam e não há erro de rede; voz pede microfone e funciona; exportar/importar backup; importar `.txt` inválido → erro sem alterar dados.
- **Privacidade:** revisão do texto publicado × questionário da Play.

## 9. Riscos e mitigações

| Risco | Mitigação |
| :--- | :--- |
| Remover permissões quebrar voz/plugins | Validar no smoke release; escopo em `liteRelease` (debug/prod intactos) |
| R8 remover classes necessárias (L-10) | Compilar AAB release no CI e fazer smoke do AAB assinado |
| Voz usar rede (L-12) | Declarar Áudio + divulgação; aceito por decisão |
| Gate de 12 testadores/14 dias (L-09) | Iniciar a trilha externa cedo, em paralelo; manter testadores ativos |
| Nome "Minhas Listas" indisponível (L-18) | Verificar no Console antes de fixar título/arte |
| GitHub Pages indisponível se o repo for **privado no plano free** | Publicar a página de um repositório público dedicado só à política, ou usar outro host estático (o texto em `site/` continua versionado aqui) |
| Firebase ainda empacotado (tamanho) | Aceito; corte de dependências fica para outra frente |

## 10. Decisões registradas (29/09/2026)

1. **Revisão completa** (app + Play) com meta **produção pública** (dono).
2. **"Lite 100% local de verdade"** (dono): Sentry desligado, Firebase/permissões de rede fora do Lite, Auto Backup desligado.
3. **Voz mantida** no Lite (dono) → Áudio declarado na Play e coberto na política.
4. **Conta pessoal nova** (dono) → gate de 12 testadores/14 dias.
5. **Política via GitHub Pages** deste repo; **contato = e-mail da conta de desenvolvedor** (dono).
6. **AAB assinado** com upload key + Play App Signing; Lite não usa `dart-defines`.
7. **RF-32** (novo) e **Fase 47**; o `prod`/F5-T06 permanecem no gate, inalterados.

## 11. Documentos relacionados

- [relatório de revisão Lite/Play](relatorio-revisao-lite-play.md) — achados `L-01…L-21`
- [06 MVP/Entregas](../06-mvp-entregas.md) — publicação, LGPD e política
- [09 Runbook](../09-runbook-operacoes.md) — build/Play/segredos
- [12 PRD](../12-prd.md) — RF-31 (Lite) e RF-32 (publicação)
- [14 Tarefas](../14-tarefas.md) — Fase 47
- [16 Roadmap pós-MVP](../16-roadmap-pos-mvp.md) — Onda E / gates do dono
