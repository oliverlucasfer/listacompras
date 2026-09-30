# 09 — Runbook de Operações

> Navegação: [← 07 Qualidade & CI](07-qualidade-ci.md) · [10 Wireframes →](10-wireframes-telas.md)

**Este documento é o dono dos procedimentos operacionais** do app único local ("Minhas Listas"): builds, distribuição de teste, publicação na Play e hotfix. Guia prático — cada procedimento em passos copiáveis. Não há backend nem banco remoto (F48).

---

## 1. Acessos e localização de credenciais

| Recurso | Onde está | Acesso usado para |
| :--- | :--- | :--- |
| Play Console | https://play.google.com/console | Publicação/rollout Android |
| GitHub | https://github.com | Repositório, CI e GitHub Pages (política de privacidade) |
| Upload key | `android/key.properties` (fora do git) | Assinatura do AAB de produção |

> Nunca colar secrets em issues, chat ou código.

---

## 2. Operação do app local

### 2.2. Backup dos dados do usuário

* **Não há backup de servidor** — os dados vivem no aparelho (Drift). O usuário pode **Exportar backup** (.json) em Configurações → Backup e guardá-lo onde quiser; **Importar backup** restaura por merge (`id` + LWW por `updated_at`).
* Antes de orientar reinstalação/limpeza, **recomende exportar o backup** — desinstalar apaga os dados locais.
* O export é fiel ao banco (inclui listas/itens soft-deletados) para não violar FK na restauração.

### 2.9. Build e distribuição (sem flavors/defines — F48)

O app é **único** ("Minhas Listas", `br.com.oliverlucas.listacompras.lite`), sem flavors e sem `--dart-define`:

```bash
# APK release de teste (assinado via android/key.properties; fallback debug se ausente)
flutter build apk --release
# → build/app/outputs/flutter-apk/app-release.apk

# AAB de publicação — assinado com a upload key (não enviar se cair no fallback debug)
flutter build appbundle --release
# → build/app/outputs/bundle/release/app-release.aab
```

Se `android/key.properties` não existir, o AAB sai assinado com a **debug key** e **não** deve ser enviado à Play.

Distribuição de builds de teste ao grupo `testadores` (canal provisório F5-T05b — Firebase App Distribution é **externo ao app**, não adiciona dependência ao projeto):

```bash
firebase appdistribution:distribute build/app/outputs/flutter-apk/app-release.apk \
  --app "<app-id no console do Firebase>" --groups testadores \
  --release-notes "Minhas Listas (RF-31): app local, sem conta, com backup exportar/importar."
```

**Recursos nativos:** nome "Minhas Listas" (`resValue app_name`), ícone cesta sobre fundo índigo `#4F46E5` e splash índigo vivem em `android/app/src/main/res/` (ícone adaptativo, splash API 31+ e `drawable-*/background.png`/`splash.png` com variantes `-night-*`). O endurecimento de release (`allowBackup="false"`, `dataExtractionRules`, `tools:node="remove"` para permissões/componentes de rede) fica no manifest **release** único (ex.: `android/app/src/release/AndroidManifest.xml`), preservando `RECORD_AUDIO` (voz, RF-26) e `CAMERA` (QR do compartilhamento, RF-33).

**Smoke em device (obrigatório a cada release):**

1. No launcher, conferir a identidade: ícone **cesta sobre fundo índigo** (`#4F46E5`), nome **"Minhas Listas"** e splash **índigo** (`#3730A3` no modo escuro). Abrir o app pelo ícone — deve abrir direto em **Minhas Listas**, sem login. **Se aparecer tela de login, o build está errado** (build antigo/flavor): não distribuir e refazer.
2. Criar uma lista e alguns itens; fechar e reabrir — os dados persistem (100% local).
3. **Configurações → Exportar backup** — o arquivo `backup_<data>.json` deve ser compartilhado/baixado.
4. **Configurações → Importar backup** — escolher um `.json` **real** no seletor do sistema. Confirmar que o seletor **abre** e que o arquivo aparece **selecionável** (sem filtro de tipo, para não esconder backup válido).
5. Importar um arquivo inválido (ex.: um `.txt` renomeado) — deve mostrar a mensagem de backup inválido **sem** alterar os dados.

### 2.10. Publicação do Lite na Play (RF-32, F47)

Publicação do app ("Minhas Listas") em **produção** na Google Play, a partir do AAB do §2.9. O caminho crítico é a trilha de testes (1–4, ~2+ semanas), que roda em paralelo ao código.

1. **Conta e verificação:** criar a **conta pessoal** no Play Console; concluir a **verificação de identidade** e a **verificação de aparelho**.
2. **App e assinatura:** criar o app `br.com.oliverlucas.listacompras.lite`; habilitar o **Play App Signing** e guardar a **upload key** (`android/key.properties`, fora do git). O AAB de produção tem de estar assinado com a upload key — o fallback para debug key (§2.9) **não** serve para envio.
3. **Trilha de testes:** subir o AAB em **internal testing** para o smoke em device release (§2.9: identidade, modo avião, backup, voz); em seguida, **closed testing** com **≥12 testadores opt-in por 14 dias contínuos**.
4. **Produção:** aplicar para acesso à produção → revisão do Google → rollout **10% → 50% → 100%**.
5. **Segurança de dados:** Declaração de Dados = **nenhum dado** coletado, exceto **Áudio** (voz, processada pelo reconhecedor do sistema). **Classificação de conteúdo** e **público-alvo 16+**; **anúncios: não**.
6. **Ficha:** título **"Minhas Listas"**, descrições, ícone **512×512**, feature graphic **1024×500** e screenshots de telefone — textos e arte versionados em [`store/ficha-lite.md`](../store/ficha-lite.md).

Hotfix de um app já publicado segue o §4 (branch `hotfix/...` → novo AAB → produção/teste interno).

### 2.11. Permissões de câmera e dependências do compartilhamento (RF-33, F49)

O "Compartilhar lista" (RF-33) adiciona o **envio** por texto, arquivo `.json` e QR/código e a **recepção** pelos mesmos caminhos. Nada usa rede — o share sheet do sistema só sai do aparelho por ação explícita do usuário.

* **Permissões nativas (opcionais):** `android.permission.CAMERA` (`android/app/src/main/AndroidManifest.xml`) e `NSCameraUsageDescription` (`ios/Runner/Info.plist`, pt-BR: *"Usar a câmera para ler o código de uma lista compartilhada."*). A câmera é usada **apenas** no toque em "Escanear QR"; negada → aviso amigável, e colar código/texto/arquivo segue funcionando. Web/Desktop não usam câmera.
* **Dependências novas (locais/offline):** `qr_flutter` (gerar o QR — puro Dart, todas as plataformas) e `mobile_scanner` (ler QR por câmera — Android/iOS, com o barcode do MLKit **bundled**; **não** adiciona `INTERNET`). Ficam atrás de `plataformaComCamera()`/`leitorQrProvider` para que Web/Desktop continuem compilando ([05 §6.12](05-app-flutter.md)).
* **Declaração de Dados (Play):** inalterada — nenhum dado coletado; a câmera processa o QR localmente (§2.10, RF-32).

---

## 3. Incidentes comuns

### 3.1. "Meus itens desapareceram"

1. Confirmar se não foi remoção legítima (soft delete local) ou lista arquivada (toggle "Mostrar arquivadas").
2. Verificar se o usuário reinstalou o app sem exportar backup — nesse caso os dados locais foram apagados (não há nuvem).
3. Último recurso: **Importar backup** (.json exportado antes) — a restauração faz merge sem apagar o que já existe.

### 3.2. "O app não abre / trava ao iniciar"

1. Verificar a versão instalada e se é um build recente (rota errada/label de flavor indicam build antigo).
2. Reproduzir localmente com `flutter run` e conferir o log do console.
3. Se for corrupção do banco local, orientar exportar (se abrir) e reinstalar.

---

## 4. Hotfix do app publicado

**Android (Play Store):**
1. Correção em branch `hotfix/...` a partir da tag de release.
2. CI verde ([07](07-qualidade-ci.md)) + bump de versão (`pubspec.yaml`, patch).
3. Build AAB → Play Console → produção (se rollout aberto) ou teste interno.
4. **Rollout gradual** (10% → 50% → 100%) em correções arriscadas.

**Web:** **sem app publicado** (uso local, ADR-013). Rodar local: `flutter run -d chrome` (dev) ou `flutter build web` + servir `build/web`.

**Dados:** o app é local; não há schema/backend a corrigir remotamente.

---

## 5. Checklist mensal de operação

- [ ] CI verde em `main` (format/analyze/test/builds).
- [ ] Issues/dúvidas de usuários triadas.
- [ ] Dependências Flutter com atualizações de segurança avaliadas.
- [ ] Página pública da política de privacidade acessível (GitHub Pages).

---

## Documentos relacionados
- [06 MVP & Entregas](06-mvp-entregas.md) — LGPD e publicação
- [07 Qualidade & CI](07-qualidade-ci.md) — pipeline exigido antes de qualquer hotfix
- [05 App Flutter](05-app-flutter.md) — comportamento e backup local
