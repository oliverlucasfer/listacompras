# Fase 41 — Flavor Lite (uso sem conta) (design)

> **Status:** aprovado em 24/09/2026 (decisões na Seção 8)
> **Fase:** 41 · **Requisito:** RF-31 (novo) — modo Lite sem conta
> **Docs donos:** [05](../05-app-flutter.md) (app/modos), [12](../12-prd.md) (escopo/requisito), [07](../07-qualidade-ci.md) (CI), [09](../09-runbook-operacoes.md) (build/distribuição), [14](../14-tarefas.md)
> **Origem:** pedido direto do dono (24/09/2026): "quero só ter uma versão lite" — sem conta, só no aparelho, **convivendo** com o app colaborativo e **sem remover nada**.

---

## 1. Motivação

1. **Público sem conta.** O app atual é colaborativo: exige conta (Supabase Auth) e oferece compartilhamento, convites e push. Há quem queira usar a lista **só no próprio aparelho**, sem criar conta e sem nuvem.
2. **Decisão do dono: conviver, não substituir.** A versão Lite é um **segundo app**, instalável ao lado do atual (identidade própria). O app colaborativo e seu backend **permanecem intactos**; as rotinas (auth, sync, convites, push) continuam no código e cobertas por teste no flavor `prod`.
3. **A base já favorece.** O Drift é a fonte da verdade local (`lib/drift/database.dart`, `schemaVersion 8`) e o app já é offline-first. Apenas **5 features** tocam o Supabase (`auth`, `sync`, `convites`, `notificacoes`, `configuracoes`); `listas` já é 100% local. O Lite é, portanto, uma **costura** que desliga a camada de nuvem — não uma reescrita.

## 2. Escopo

**Dentro:**
- Flavor **`lite`** com identidade própria (dois apps instaláveis juntos).
- `AppModo`/`AppCapacidades` em tempo de compilação + **dois entrypoints** (`main.dart`, `main_lite.dart`).
- Sessão local (`AuthLocalRepository`), dono local `'local'`, **sem outbox** no Lite.
- Rotas e UI do Lite **sem** conta/convite/notificação/indicador de sync.
- **Backup JSON** (exportar/importar) — obrigatório no Lite, disponível nos dois flavors.
- Docs donos (05/12/07/09/14) + suíte de testes do Lite + CI buildando os dois flavors.

**Fora:**
- Remover ou alterar o comportamento do app colaborativo (nada é deletado; `prod` fica igual).
- Tocar backend/RLS/migrations/sync (`01`/`02`/`03` intactos).
- Login local com senha, múltiplos usuários no aparelho, ou migração automática conta `prod` → `lite`.
- **Build Web do Lite**: o app web continua sendo o colaborativo (§5).
- Backup **em nuvem/agendado** — isso é o C3 server-side ([2026-09-22-backup-alertas-design.md](2026-09-22-backup-alertas-design.md)); aqui o backup é **local do usuário** (arquivo).
- Publicação em loja (gate F5-T06).

## 3. Modo e arranque

**Tipos novos** (`lib/core/config/app_modo.dart`):

```dart
enum AppModo { colaborativo, lite }

class AppCapacidades {
  const AppCapacidades({required this.nuvem, required this.colaboracao,
    required this.notificacoes, required this.backup});
  final bool nuvem;         // Supabase (auth + sync + realtime)
  final bool colaboracao;   // convites, membros, compartilhamento
  final bool notificacoes;  // FCM/push
  final bool backup;        // exportar/importar JSON
}
```

`capacidadesProvider` (`Provider<AppCapacidades>`) é **sobrescrito no container raiz** de cada entrypoint. UI e rotas leem capacidades; **nenhum** widget decide por `AppModo` diretamente.

**Entrypoints** — o `main()` atual é extraído para `lib/bootstrap.dart` (`bootstrap(AppModo, {AppCapacidades})`):

| Passo do arranque | `prod` (colaborativo) | `lite` |
| :--- | :--- | :--- |
| `Supabase.initialize` (`main.dart:31`) | sim | **não** |
| `Firebase.initializeApp` Android (`main.dart:33-35`) | sim | **não** |
| `syncBootstrapProvider` (`main.dart:48`) | sim | **não** |
| `deeplinkConviteProvider` (`main.dart:50`) | sim | **não** |
| `pushNavegacaoProvider` (`main.dart:52`) | sim | **não** |
| Sentry (`SENTRY_DSN`) | sim | sim (opcional, inalterado) |
| `dart_defines` de Supabase | exigidos | **não exigidos** |

O Lite não lê `core/config/supabase_config.dart`; o build lite não precisa de `SUPABASE_URL`/`SUPABASE_ANON_KEY`.

## 4. Costura (sessão, outbox, rotas, UI)

### 4.1 Sessão
Hoje o tipo `Session` do Supabase vaza para o router (`router.dart:41`). Extrair:

- **`AuthRepository`** (interface) — abstrai o que hoje vaza do Supabase (`supabase_auth_repository.dart`, `auth_providers.dart`):
  - `sessaoAtual` → `UsuarioAtual? { String id; String? email; }` (consumido por `autenticadoProvider:16`, `donoAtualIdProvider:22`, `emailUsuarioProvider:27`);
  - `onAuthStateChange` → `Stream<EventoSessao>`, com `EventoSessao { UsuarioAtual? usuario; bool recuperacaoDeSenha; }` (consumido por `authStateProvider:11`, `redefinindoSenhaProvider:41` e `RouterRefreshStream:39`);
  - `entrar`, `registrar`, `sair`, `enviarRecuperacaoSenha`, `atualizarSenha`, `reenviarVerificacao`, `excluirConta`.
- **`SupabaseAuthRepository`** passa a **implementá-la**, traduzindo `Session`/`AuthState`/`AuthChangeEvent` para os tipos acima — comportamento inalterado no `prod`.
- **`AuthLocalRepository`** (novo, `features/auth/data/`): `sessaoAtual` sempre `UsuarioAtual(id: 'local')`; `onAuthStateChange` nunca emite (nem `recuperacaoDeSenha`); entrar/sair/registrar/excluir no-op.

`authRepositoryProvider` é o **único** provider sobrescrito pelo container Lite (Abordagem A, decisão §8.3).

### 4.2 Dono e outbox
- **Dono local:** `donoId` de toda lista no Lite = `'local'` (`lista_local.dart:10`). `donoAtualIdProvider` **não** é sobrescrito — deriva de `sessaoAtual.id` (`auth_providers.dart:22-24`), que o `AuthLocalRepository` fixa em `'local'`.
- **Sem outbox:** as escritas passam por `listas_repository.dart:642` (`_enfileirar`) em ~12 pontos. No Lite, `_enfileirar` **não grava** `mutacao_pendente` (senão a fila cresceria para sempre sem drenar). Guarda por `capacidades.nuvem` dentro do repositório — **um** ponto de decisão, não doze.

### 4.3 Rotas
| Rota | `prod` | `lite` |
| :--- | :--- | :--- |
| `/login`, `/registro`, `/recuperar-senha`, `/redefinir-senha`, `/login-callback`, `/entrar` | sim | **ausente** |
| `/compartilhadas` (`router.dart:117`) | sim | **ausente** |
| membros da lista (`tela_membros_screen`) | sim | **ausente** |
| `/` (raiz) | sessão? `/listas` : `/login` | sempre `/listas` |
| `redirect` global (`router.dart:40-68`) | como hoje | **no-op** |

### 4.4 UI
| Ponto | Hoje | No Lite |
| :--- | :--- | :--- |
| Aba "Compartilhadas" (`app_shell.dart:22`) | visível | escondida |
| `ConvitesPendentesSecao` (`painel_listas.dart:157`) | visível | escondida |
| FAB/estado "compartilhadas" (`painel_listas.dart:192,204`) | visível | escondido |
| Ação convidar (`tela_lista_screen.dart:28`) | visível | escondida |
| `IndicadorSync` (`tela_lista_screen.dart:422`, `mercado_screen.dart:133`, `painel_listas.dart:139`) | visível | escondido |
| Configurações: conta/sair/excluir | visível | escondido |
| Configurações: **Exportar/Importar backup** | visível | visível |
| `voltar_para_inicio` (`voltar_para_inicio.dart:7`) | dono→`/listas`, membro→`/compartilhadas` | sempre `/listas` |

## 5. Nativo, identidade e builds

- **Android** (`android/app/build.gradle.kts`): `productFlavors { prod; lite }`. `prod` mantém `applicationId = "br.com.oliverlucas.listacompras"` (`:31`); `lite` usa `applicationId = "br.com.oliverlucas.listacompras.lite"`, `resValue app_name = "Lista de Compras Lite"` e ícone próprio em `android/app/src/lite/res/`. Ambos assinados (release) como hoje (`:40-58`).
- **iOS:** flavor/scheme equivalente com bundle id `.lite` e nome/ícone distintos.
- **Consequência obrigatória:** com flavors definidos, **todo build passa a exigir `--flavor`** — `flutter build apk --flavor prod` (o caminho do APK vira `app-prod-release.apk`). Comandos de CI e do [09](../09-runbook-operacoes.md) são atualizados no mesmo PR.
- **Web:** o build web continua sendo o do app **colaborativo**; o Lite **não** é publicado na web (§2). Logo, `web/version.json` e o teste de paridade (`version_json_test.dart`) **não mudam**.
- **Ícones/splash:** `flutter_launcher_icons`/`flutter_native_splash` geram o conjunto padrão; o ícone do Lite é um asset distinto colocado no source set `lite` (não regera o do `prod`).

## 6. Backup JSON (cliente, nos dois flavors)

Novo `lib/features/backup/` — **sem** tocar o backend.

- **Arquivo:** `{ "versao": 1, "exportadoEm": <ISO-8601>, "listas": [...], "itens": [...], "historicoPrecos": [...] }`. **Não** inclui `mutacao_pendente` (outbox é transporte, não dado).
- **Exportar:** serializa o **estado atual** — `listas`, `itens` e `historicoPrecos` com `deletado_em IS NULL` (arquivadas **incluídas**; registros deletados ficam de fora). Arquivo `.json` enviado pelo `share_plus` (já é dependência).
- **Importar:** lê o arquivo com **`file_picker`** (nova dependência), valida `versao`, e faz **merge por `id`** com **LWW por `updated_at`** (mesma regra do sync, `03 §5`): mantém o registro de `updated_at` maior; cria o que não existe.
- **Validação/erros:** versão desconhecida, JSON inválido ou campos faltando → mensagem clara, **sem** alterar o banco (transação).
- **Onde fica:** tela de **Configurações**, seção "Backup".
- **Privacidade:** o arquivo é local, sob controle do usuário; no Lite o dono é `'local'` (sem PII de terceiros).

## 7. Testes, CI e distribuição

- **Suíte `prod`**: continua verde — **nada** é removido nem alterado em comportamento. É a garantia de que a costura não regrediu o app colaborativo.
- **Suíte `lite`** (nova): monta o app Lite e verifica — abre em `/listas` (sem `/login`); sem aba "Compartilhadas"; sem `IndicadorSync`; sem ação de convidar; `AuthLocalRepository` devolve `UsuarioAtual('local')`; escritas **não** geram linha em `mutacao_pendente`; round-trip **export→import** do backup (merge/LWW, versão inválida).
- **CI** ([07](../07-qualidade-ci.md)): `dart format`/`flutter analyze`/`flutter test` (ambas as suítes rodam juntas) + build dos **dois** flavors (`--flavor prod` e `--flavor lite`).
- **Distribuição** ([09](../09-runbook-operacoes.md)): o Lite é um **app Firebase separado** (novo registro Android com `applicationId` `.lite`) no mesmo projeto `lista-compras-34f93`, distribuído ao grupo `testadores` via Firebase App Distribution.

## 8. Decisões registradas (24/09/2026)

1. **Conviver:** flavor `lite` separado — dois apps instaláveis juntos (dono).
2. **Não remover nada:** o app colaborativo e o backend ficam intactos (dono).
3. **Abordagem A — costura mínima por capacidades** (dono): `AppCapacidades` em tempo de compilação + não inicializar Supabase/Firebase no Lite + sobrescrever **só** a sessão + guardas na UI/rotas.
4. **UI do Lite esconde tudo de conta/rede** (dono): sem login, convites, notificações nem indicador de sync.
5. **Backup completo JSON exportar/importar** (dono), nos dois flavors, obrigatório no Lite.
6. **Sem outbox no Lite** (§4.2) — evita fila que cresce sem drenar.
7. **Web Lite fora do escopo** (§5) — evita conflito com `web/version.json` e mantém a web colaborativa.
8. Fase **41**; requisito **RF-31** (novo); nova dependência: **`file_picker`**.

## 9. Documentos relacionados
- [05 App Flutter](../05-app-flutter.md) — modos/flavor e rotas do Lite
- [12 PRD](../12-prd.md) — RF-31 (Lite sem conta) e escopo
- [07 Qualidade & CI](../07-qualidade-ci.md) — dois flavors no CI
- [09 Runbook de Operações](../09-runbook-operacoes.md) — builds `--flavor`, app Firebase do Lite
- [14 Tarefas](../14-tarefas.md) — Fase 41
- [2026-09-22-backup-alertas-design.md](2026-09-22-backup-alertas-design.md) — backup server-side (C3), distinto do backup local do Lite
