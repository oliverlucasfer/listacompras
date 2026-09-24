# Flavor Lite (uso sem conta) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Entregar um segundo app instalável ("Lista de Compras Lite") que roda 100% no aparelho, sem conta e sem Supabase, **convivendo** com o app colaborativo — que permanece intacto.

**Architecture:** Costura mínima por capacidades em tempo de compilação (`AppModo`/`AppCapacidades`) e dois entrypoints sobre um `bootstrap` compartilhado. O Lite não inicializa Supabase nem Firebase, sobrescreve **só** a sessão (`AuthLocalRepository`) e usa **guardas de capacidade** onde o app leria providers do Supabase. Nada é removido do código colaborativo.

**Tech Stack:** Flutter 3.44.5 · Riverpod 3 · Drift (schemaVersion 8) · go_router 18 · share_plus 12 · `file_picker` (novo) · Gradle `productFlavors`.

**Spec:** [docs/superpowers/specs/2026-09-24-flavor-lite-sem-conta-design.md](../specs/2026-09-24-flavor-lite-sem-conta-design.md)

## Global Constraints

- **Nenhum segredo** em código, commit ou log. `dart_defines_prod.json` segue fora do git.
- **Backend intacto:** nenhuma alteração em `supabase/` (migrations, RLS, RPCs, Edge Function, testes SQL).
- **Enum de unidades fechado**, idêntico em Postgres/Dart: `un, kg, g, l, ml, caixa, pacote, pct, dz`.
- **Offline-first:** o Lite **nunca** toca a rede (nem tenta).
- Comentários só quando indispensável; pt-BR na UI/docs; `snake_case` (SQL) / `camelCase` (Dart).
- Testes: `deve_<resultado>_quando_<condição>`.
- CI verde obrigatório antes de fechar a fase: `dart format .`, `flutter analyze`, `flutter test`.
- **Com flavors, todo build exige `--flavor`:** `flutter build apk --flavor prod` / `--flavor lite`.
- O flavor `prod` **não muda de comportamento**; a suíte existente (659 testes) deve continuar verde a cada task.
- Gate F5-T05/F5-T06 (usabilidade/publicação) **não** é acionado por esta fase.

## Pré-requisitos (ações do dono — bloqueiam a Task 12)

1. No console do Firebase (projeto `lista-compras-34f93`), **registrar um segundo app Android** com pacote `br.com.oliverlucas.listacompras.lite`, nome "Lista de Compras Lite".
2. Baixar o `google-services.json` atualizado (contendo os **dois** apps) para `android/app/google-services.json`.
3. Sem isso o flavor `lite` **não compila**: o plugin `com.google.gms.google-services` valida que o `applicationId` existe no `google-services.json`.

> **iOS fica fora desta fase** (dev em Windows, sem runner macOS para verificar). Registrar como follow-up no doc 16 (Task 14).

---

### Task 1: Planejamento — RF-31, Fase 41 e docs donos

**Files:**
- Modify: `docs/12-prd.md`
- Modify: `docs/14-tarefas.md`
- Modify: `docs/05-app-flutter.md`
- Modify: `docs/16-roadmap-pos-mvp.md`

**Interfaces:**
- Consumes: nada.
- Produces: RF-31 e Fase 41 referenciados por todas as tasks seguintes.

- [ ] **Step 1: RF-31 no doc 12 §2 (tabela de requisitos)**

Adicionar a linha ao final da tabela de requisitos (depois de RF-30):

```markdown
| RF-31 | Versão Lite: uso sem conta, 100% no aparelho (sem login, sem convites, sem notificações), com backup local exportar/importar | 05 §2.3 + 05 §6.10 | F41 | [05 §2.3](05-app-flutter.md) |
```

- [ ] **Step 2: RF-31 na rastreabilidade do doc 12 §6**

Adicionar a linha:

```markdown
| RF-31 | US-01 | F41 | F41-T02…F41-T11 | Widget/unit (modo Lite + backup) + smoke em device |
```

- [ ] **Step 3: Fase 41 no doc 14**

Ao final do arquivo, adicionar:

```markdown
## Fase 41 — Flavor Lite (RF-31)

Spec: [superpowers/specs/2026-09-24-flavor-lite-sem-conta-design.md](superpowers/specs/2026-09-24-flavor-lite-sem-conta-design.md) · Plano: [superpowers/plans/2026-09-24-flavor-lite-sem-conta.md](superpowers/plans/2026-09-24-flavor-lite-sem-conta.md) · Requisito: RF-31 (versão Lite sem conta, 100% local, com backup JSON). · Docs donos: 05, 12, 07, 09.

- [ ] **F41-T01** — Planejamento: RF-31, Fase 41 e docs de roadmap
- [ ] **F41-T02** — `AppModo`/`AppCapacidades` e `capacidadesProvider`
- [ ] **F41-T03** — Interface `AuthRepository` e tipos de sessão (prod inalterado)
- [ ] **F41-T04** — `AuthLocalRepository` (sessão local fixa)
- [ ] **F41-T05** — `bootstrap(AppModo)` e os dois entrypoints
- [ ] **F41-T06** — Outbox desligada no Lite
- [ ] **F41-T07** — Rotas do Lite (sem conta/convite/membros)
- [ ] **F41-T08** — UI do Lite (abas, convites, sync, configurações)
- [ ] **F41-T09** — Backup: exportar JSON
- [ ] **F41-T10** — Backup: importar JSON (merge/LWW)
- [ ] **F41-T11** — UI de backup em Configurações
- [ ] **F41-T12** — Nativo: flavors `prod`/`lite` (nome e ícone)
- [ ] **F41-T13** — CI: build dos dois flavors
- [ ] **F41-T14** — Fechamento: docs donos e distribuição

| Fase | Tarefas | Concluídas |
| :--- | :--- | :--- |
| F41 Flavor Lite | 14 | 0 |
```

- [ ] **Step 4: doc 05 §2.3 e §6.10**

Adicionar ao doc 05:

```markdown
### 2.3. Modos do app: colaborativo e Lite (RF-31, F41)

O app tem dois flavors, com identidade própria e instaláveis ao mesmo tempo:

| | `prod` (colaborativo) | `lite` |
| :--- | :--- | :--- |
| Conta (Supabase Auth) | sim | **não** |
| Sync/Realtime | sim | **não** |
| Convites/compartilhamento | sim | **não** |
| Push (FCM) | sim | **não** |
| Backup JSON (exportar/importar) | sim | **sim** |

O Lite usa o dono local `'local'` e nunca toca a rede. Decisões e costura completas em
[superpowers/specs/2026-09-24-flavor-lite-sem-conta-design.md](superpowers/specs/2026-09-24-flavor-lite-sem-conta-design.md).
Builds: `flutter build apk --flavor prod` / `--flavor lite` (com flavors, `--flavor` é obrigatório).

### 6.10. Backup local (RF-31, F41)

Em Configurações → "Backup": **Exportar backup** gera um `.json` (versão + listas + itens + histórico de preços)
e **Importar backup** restaura com merge por `id` e LWW por `updated_at`. Disponível nos dois modos.
```

- [ ] **Step 5: doc 16 — follow-up iOS**

Na seção de follow-ups, adicionar:

```markdown
- **Lite no iOS (RF-31):** configurar flavor/bundle id `.lite` e ícone — requer macOS para verificar (F41 deixou fora).
```

- [ ] **Step 6: Commit**

```bash
git add docs/12-prd.md docs/14-tarefas.md docs/05-app-flutter.md docs/16-roadmap-pos-mvp.md
git commit -m "F41-T01: RF-31, Fase 41 e docs de roadmap (RF-31)"
```

---

### Task 2: `AppModo`/`AppCapacidades` e `capacidadesProvider`

**Files:**
- Create: `lib/core/config/app_modo.dart`
- Test: `test/core/config/app_modo_test.dart`

**Interfaces:**
- Consumes: nada.
- Produces: `enum AppModo { colaborativo, lite }`; `class AppCapacidades` com campos `nuvem`, `colaboracao`, `notificacoes`, `backup` e constantes `AppCapacidades.colaborativo` / `AppCapacidades.lite`; `final capacidadesProvider = Provider<AppCapacidades>` (default **colaborativo**, para não quebrar os testes existentes).

- [ ] **Step 1: Escrever o teste**

`test/core/config/app_modo_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/config/app_modo.dart';

void main() {
  test('deve_ligar_nuvem_colaboracao_e_notificacoes_no_modo_colaborativo', () {
    const c = AppCapacidades.colaborativo;
    expect(c.nuvem, isTrue);
    expect(c.colaboracao, isTrue);
    expect(c.notificacoes, isTrue);
    expect(c.backup, isTrue);
  });

  test('deve_desligar_nuvem_colaboracao_e_notificacoes_no_modo_lite', () {
    const c = AppCapacidades.lite;
    expect(c.nuvem, isFalse);
    expect(c.colaboracao, isFalse);
    expect(c.notificacoes, isFalse);
    expect(c.backup, isTrue);
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/core/config/app_modo_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:lista_compras/core/config/app_modo.dart'`.

- [ ] **Step 3: Implementar**

`lib/core/config/app_modo.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Modo de build do app (RF-31, F41): o flavor `prod` é colaborativo (conta +
/// Supabase); o flavor `lite` roda 100% no aparelho, sem conta nem rede.
enum AppModo { colaborativo, lite }

/// Capacidades ligadas em cada modo. A UI e as rotas decidem por estas flags —
/// **nunca** por [AppModo] diretamente.
class AppCapacidades {
  const AppCapacidades({
    required this.nuvem,
    required this.colaboracao,
    required this.notificacoes,
    required this.backup,
  });

  /// Supabase (auth + sync + realtime).
  final bool nuvem;

  /// Convites, membros e listas compartilhadas.
  final bool colaboracao;

  /// FCM/push.
  final bool notificacoes;

  /// Exportar/importar backup local.
  final bool backup;

  static const colaborativo = AppCapacidades(
    nuvem: true,
    colaboracao: true,
    notificacoes: true,
    backup: true,
  );

  static const lite = AppCapacidades(
    nuvem: false,
    colaboracao: false,
    notificacoes: false,
    backup: true,
  );
}

/// Sobrescrito no container raiz de cada entrypoint (`main.dart` /
/// `main_lite.dart`). O default é o modo colaborativo para que testes e o app
/// atual sigam sem override.
final capacidadesProvider = Provider<AppCapacidades>(
  (ref) => AppCapacidades.colaborativo,
);
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/core/config/app_modo_test.dart`
Expected: PASS (2 testes).

- [ ] **Step 5: Commit**

```bash
git add lib/core/config/app_modo.dart test/core/config/app_modo_test.dart
git commit -m "F41-T02: AppModo, AppCapacidades e capacidadesProvider (RF-31)"
```

---

### Task 3: Interface `AuthRepository` e tipos de sessão

Extrai o que hoje vaza do Supabase (`Session`, `AuthState`, `AuthChangeEvent`) para tipos do domínio, **sem mudar o comportamento do `prod`**.

**Files:**
- Create: `lib/features/auth/domain/sessao.dart`
- Create: `lib/features/auth/data/auth_repository.dart`
- Modify: `lib/features/auth/data/supabase_auth_repository.dart`
- Modify: `lib/features/auth/providers/auth_providers.dart`
- Modify: `test/features/auth/fakes.dart`
- Test: `test/features/auth/auth_providers_test.dart`

**Interfaces:**
- Consumes: `capacidadesProvider` (Task 2).
- Produces: `UsuarioAtual({required String id, String? email})`; `EventoSessao({UsuarioAtual? usuario, bool recuperacaoDeSenha})`; `abstract class AuthRepository` com `redirectUrl`, `onAuthStateChange` (`Stream<EventoSessao>`), `sessaoAtual` (`UsuarioAtual?`), `registrar`, `entrar`, `sair`, `enviarRecuperacaoSenha`, `atualizarSenha`, `reenviarVerificacao`, `excluirConta` (todos `Future<void>`, exceto os getters). `authRepositoryProvider` passa a ser `Provider<AuthRepository>`.

- [ ] **Step 1: Escrever o teste**

`test/features/auth/auth_providers_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/features/auth/domain/sessao.dart';
import 'package:lista_compras/features/auth/providers/auth_providers.dart';

import 'fakes.dart';

void main() {
  test('deve_derivar_id_e_email_da_sessao_atual', () {
    final repo = FakeAuthRepository()
      ..sessaoFake = const UsuarioAtual(id: 'user-a', email: 'a@b.com');
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    expect(container.read(autenticadoProvider), isTrue);
    expect(container.read(donoAtualIdProvider), 'user-a');
    expect(container.read(emailUsuarioProvider), 'a@b.com');
  });

  test('deve_ficar_desautenticado_quando_sem_sessao', () {
    final repo = FakeAuthRepository();
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    expect(container.read(autenticadoProvider), isFalse);
    expect(container.read(donoAtualIdProvider), '');
    expect(container.read(emailUsuarioProvider), isNull);
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/features/auth/auth_providers_test.dart`
Expected: FAIL — `sessaoFake` não existe / `autenticadoProvider` não lê `sessaoAtual`.

- [ ] **Step 3: Criar os tipos de domínio**

`lib/features/auth/domain/sessao.dart`:

```dart
/// Usuário da sessão corrente (RF-01). Abstrai `Session` do Supabase para que
/// o modo Lite (RF-31) funcione sem o SDK.
class UsuarioAtual {
  const UsuarioAtual({required this.id, this.email});

  final String id;
  final String? email;
}

/// Evento de mudança de sessão (login/logout/refresh/recuperação de senha).
class EventoSessao {
  const EventoSessao({this.usuario, this.recuperacaoDeSenha = false});

  final UsuarioAtual? usuario;
  final bool recuperacaoDeSenha;
}
```

- [ ] **Step 4: Criar a interface**

`lib/features/auth/data/auth_repository.dart`:

```dart
import '../domain/sessao.dart';

/// Contrato de autenticação (doc 05 §2, RF-01). O modo colaborativo usa
/// [SupabaseAuthRepository]; o modo Lite usa [AuthLocalRepository] (RF-31).
abstract class AuthRepository {
  String get redirectUrl;
  Stream<EventoSessao> get onAuthStateChange;
  UsuarioAtual? get sessaoAtual;

  Future<void> registrar({required String email, required String senha});
  Future<void> entrar({required String email, required String senha});
  Future<void> sair();
  Future<void> enviarRecuperacaoSenha(String email);
  Future<void> atualizarSenha(String novaSenha);
  Future<void> reenviarVerificacao(String email);
  Future<void> excluirConta();
}
```

- [ ] **Step 5: Adaptar `SupabaseAuthRepository`**

Em `lib/features/auth/data/supabase_auth_repository.dart`: importar `auth_repository.dart` e `../domain/sessao.dart`; declarar `class SupabaseAuthRepository implements AuthRepository`; substituir os dois getters por:

```dart
  @override
  String get redirectUrl => redirectAuth();

  @override
  Stream<EventoSessao> get onAuthStateChange => _client.auth.onAuthStateChange
      .map(
        (estado) => EventoSessao(
          usuario: _paraUsuario(estado.session),
          recuperacaoDeSenha:
              estado.event == AuthChangeEvent.passwordRecovery,
        ),
      );

  @override
  UsuarioAtual? get sessaoAtual => _paraUsuario(_client.auth.currentSession);

  UsuarioAtual? _paraUsuario(Session? s) => s == null
      ? null
      : UsuarioAtual(id: s.user.id, email: s.user.email);
```

Os métodos `registrar`/`entrar` continuam devolvendo `Future<AuthResponse>` e `atualizarSenha` `Future<UserResponse>` — em Dart `Future<AuthResponse>` é subtipo de `Future<void>`, então a interface compila sem mudar as telas.

- [ ] **Step 6: Adaptar `auth_providers.dart`**

Substituir o topo do arquivo por:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';
import '../data/supabase_auth_repository.dart';
import '../domain/sessao.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => SupabaseAuthRepository(Supabase.instance.client),
);

/// Sessão atual (login/logout/refresh) — doc 05 §3.
final authStateProvider = StreamProvider<EventoSessao>(
  (ref) => ref.watch(authRepositoryProvider).onAuthStateChange,
);

/// true quando há usuário autenticado.
final autenticadoProvider = Provider<bool>((ref) {
  final evento = ref.watch(authStateProvider).value;
  return evento?.usuario != null ||
      ref.watch(authRepositoryProvider).sessaoAtual != null;
});

/// ID do usuário autenticado — dono de listas criadas no cliente (ADR-006).
final donoAtualIdProvider = Provider<String>((ref) {
  return ref.watch(authRepositoryProvider).sessaoAtual?.id ?? '';
});

/// E-mail da conta autenticada (null sem sessão) — usado nas Configurações.
final emailUsuarioProvider = Provider<String?>((ref) {
  return ref.watch(authRepositoryProvider).sessaoAtual?.email;
});
```

Manter `redefinindoSenhaProvider` trocando a checagem por `if (estado.recuperacaoDeSenha) state = true;` (o `estado` agora é `EventoSessao`). Manter o `import 'package:supabase_flutter/supabase_flutter.dart';` se `Supabase` ainda for usado, senão remover.

- [ ] **Step 7: Ajustar o fake**

Em `test/features/auth/fakes.dart`, adicionar os campos e overrides em `FakeAuthRepository`:

```dart
  UsuarioAtual? sessaoFake;
  final _eventos = StreamController<EventoSessao>.broadcast();

  @override
  UsuarioAtual? get sessaoAtual => sessaoFake;

  @override
  Stream<EventoSessao> get onAuthStateChange => _eventos.stream;
```

(imports: `dart:async`, `package:lista_compras/features/auth/domain/sessao.dart`.)

- [ ] **Step 8: Rodar e ver passar**

Run: `flutter test test/features/auth/auth_providers_test.dart`
Expected: PASS (2 testes).

- [ ] **Step 9: Rodar a suíte inteira (o prod não pode mudar)**

Run: `flutter test`
Expected: 659 + 2 verdes. Se algum teste referenciar `AuthState`/`Session`, atualizar para `EventoSessao`/`UsuarioAtual` **sem** alterar a intenção do teste.

- [ ] **Step 10: Commit**

```bash
git add lib/features/auth test/features/auth
git commit -m "F41-T03: interface AuthRepository e tipos de sessao (RF-31)"
```

---

### Task 4: `AuthLocalRepository`

**Files:**
- Create: `lib/features/auth/data/auth_local_repository.dart`
- Test: `test/features/auth/auth_local_repository_test.dart`

**Interfaces:**
- Consumes: `AuthRepository`, `UsuarioAtual`, `EventoSessao` (Task 3).
- Produces: `class AuthLocalRepository implements AuthRepository` com `idLocal = 'local'` (const público), sessão fixa e stream vazio.

- [ ] **Step 1: Escrever o teste**

`test/features/auth/auth_local_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/features/auth/data/auth_local_repository.dart';

void main() {
  test('deve_ter_sessao_local_fixa_quando_sem_conta', () {
    final repo = AuthLocalRepository();
    expect(repo.sessaoAtual?.id, AuthLocalRepository.idLocal);
    expect(repo.sessaoAtual?.email, isNull);
  });

  test('deve_nunca_emitir_evento_de_sessao', () async {
    final repo = AuthLocalRepository();
    expect(await repo.onAuthStateChange.isEmpty, isTrue);
  });

  test('deve_ignorar_entrar_e_sair', () async {
    final repo = AuthLocalRepository();
    await repo.entrar(email: 'x@y.com', senha: 'z');
    await repo.sair();
    expect(repo.sessaoAtual?.id, AuthLocalRepository.idLocal);
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/features/auth/auth_local_repository_test.dart`
Expected: FAIL — arquivo não existe.

- [ ] **Step 3: Implementar**

`lib/features/auth/data/auth_local_repository.dart`:

```dart
import '../domain/sessao.dart';
import 'auth_repository.dart';

/// Autenticação do modo Lite (RF-31): não há conta — a sessão é sempre o
/// usuário local e nenhuma operação toca a rede.
class AuthLocalRepository implements AuthRepository {
  static const idLocal = 'local';

  @override
  String get redirectUrl => '';

  @override
  Stream<EventoSessao> get onAuthStateChange => const Stream.empty();

  @override
  UsuarioAtual? get sessaoAtual => const UsuarioAtual(id: idLocal);

  @override
  Future<void> registrar({required String email, required String senha}) async {}

  @override
  Future<void> entrar({required String email, required String senha}) async {}

  @override
  Future<void> sair() async {}

  @override
  Future<void> enviarRecuperacaoSenha(String email) async {}

  @override
  Future<void> atualizarSenha(String novaSenha) async {}

  @override
  Future<void> reenviarVerificacao(String email) async {}

  @override
  Future<void> excluirConta() async {}
}
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/features/auth/auth_local_repository_test.dart`
Expected: PASS (3 testes).

- [ ] **Step 5: Commit**

```bash
git add lib/features/auth/data/auth_local_repository.dart test/features/auth/auth_local_repository_test.dart
git commit -m "F41-T04: AuthLocalRepository com sessao local fixa (RF-31)"
```

---

### Task 5: `bootstrap(AppModo)` e os dois entrypoints

**Files:**
- Create: `lib/app.dart` (recebe `ListaComprasApp` e `_messengerKey`, saídos de `main.dart`)
- Create: `lib/bootstrap.dart`
- Modify: `lib/main.dart` (vira entrypoint fino do modo colaborativo)
- Create: `lib/main_lite.dart`
- Test: `test/bootstrap_lite_test.dart`

**Interfaces:**
- Consumes: `AppModo`, `AppCapacidades`, `capacidadesProvider` (Task 2); `AuthLocalRepository` (Task 4); `authRepositoryProvider` (Task 3).
- Produces: `Future<void> bootstrap(AppModo modo)`; `const sentryDsn`.

- [ ] **Step 1: Escrever o teste**

`test/bootstrap_lite_test.dart` — prova que o modo Lite resolve a sessão local **sem** Supabase inicializado:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/config/app_modo.dart';
import 'package:lista_compras/features/auth/data/auth_local_repository.dart';
import 'package:lista_compras/features/auth/providers/auth_providers.dart';

void main() {
  test('deve_autenticar_como_local_quando_modo_lite_sem_supabase', () {
    final container = ProviderContainer(
      overrides: [
        capacidadesProvider.overrideWithValue(AppCapacidades.lite),
        authRepositoryProvider.overrideWithValue(AuthLocalRepository()),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(autenticadoProvider), isTrue);
    expect(container.read(donoAtualIdProvider), 'local');
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/bootstrap_lite_test.dart`
Expected: FAIL enquanto `capacidadesProvider` não estiver disponível/override correto.

- [ ] **Step 3: Extrair `lib/app.dart`**

Mover de `lib/main.dart` para `lib/app.dart`: `final _messengerKey = GlobalKey<ScaffoldMessengerState>();` e `class ListaComprasApp extends ConsumerWidget` (o widget `build` inteiro, incluindo o `ref.listen(notificacoesForegroundProvider, ...)`). Imports correspondentes.

- [ ] **Step 4: Criar `lib/bootstrap.dart`**

```dart
import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/app_modo.dart';
import 'core/config/supabase_config.dart';
import 'core/observabilidade/sentry_privacidade.dart';
import 'core/utils/deeplink_convite.dart';
import 'core/web/url_strategy.dart';
import 'features/auth/data/auth_local_repository.dart';
import 'features/auth/providers/auth_providers.dart';
import 'features/notificacoes/providers/push_navegacao.dart';
import 'features/sync/providers/sync_providers.dart';

/// DSN do Sentry build-time (doc 07 §4, RF-12). Vazio → Sentry desligado.
const sentryDsn = String.fromEnvironment('SENTRY_DSN', defaultValue: '');

/// Arranque comum aos dois modos (RF-31, F41).
Future<void> bootstrap(AppModo modo) async {
  final cap = modo == AppModo.lite
      ? AppCapacidades.lite
      : AppCapacidades.colaborativo;

  WidgetsFlutterBinding.ensureInitialized();
  usarPathUrlStrategy();

  if (cap.nuvem) {
    await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseAnonKey);
  }
  if (cap.notificacoes &&
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android) {
    await Firebase.initializeApp();
  }

  void app() {
    final container = ProviderContainer(
      overrides: [
        capacidadesProvider.overrideWithValue(cap),
        if (!cap.nuvem)
          authRepositoryProvider.overrideWithValue(AuthLocalRepository()),
      ],
    );
    runApp(
      UncontrolledProviderScope(
        container: container,
        child: const ListaComprasApp(),
      ),
    );
    if (cap.nuvem) {
      container.read(syncBootstrapProvider);
      container.read(deeplinkConviteProvider);
    }
    if (cap.notificacoes) {
      container.read(pushNavegacaoProvider);
    }
  }

  if (sentryDsn.isEmpty) {
    app();
  } else {
    await SentryFlutter.init((options) {
      options.dsn = sentryDsn;
      options.sendDefaultPii = false;
      options.beforeSend = limparDadosDoSentry;
    }, appRunner: app);
  }
}
```

- [ ] **Step 5: Enxugar `lib/main.dart`**

```dart
import 'bootstrap.dart';
import 'core/config/app_modo.dart';

Future<void> main() => bootstrap(AppModo.colaborativo);
```

- [ ] **Step 6: Criar `lib/main_lite.dart`**

```dart
import 'bootstrap.dart';
import 'core/config/app_modo.dart';

Future<void> main() => bootstrap(AppModo.lite);
```

- [ ] **Step 7: Rodar e ver passar**

Run: `flutter test test/bootstrap_lite_test.dart`
Expected: PASS.

- [ ] **Step 8: Suíte inteira**

Run: `flutter test`
Expected: tudo verde (o `prod` arranca igual).

- [ ] **Step 9: Commit**

```bash
git add lib/app.dart lib/bootstrap.dart lib/main.dart lib/main_lite.dart test/bootstrap_lite_test.dart
git commit -m "F41-T05: bootstrap por modo e entrypoints main/main_lite (RF-31)"
```

---

### Task 6: Outbox desligada no Lite

**Files:**
- Modify: `lib/features/listas/data/listas_repository.dart` (construtor e `_enfileirar`, `:21-25`, `:642-662`)
- Modify: `lib/features/listas/providers/listas_providers.dart` (`:19-21`)
- Test: `test/features/listas/outbox_lite_test.dart`

**Interfaces:**
- Consumes: `capacidadesProvider` (Task 2).
- Produces: `ListasRepository(this._db, {Uuid? uuid, bool enfileirarMutacoes = true})`.

- [ ] **Step 1: Escrever o teste**

`test/features/listas/outbox_lite_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/listas/data/listas_repository.dart';

void main() {
  test('deve_nao_enfileirar_mutacao_quando_outbox_desligada', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = ListasRepository(db, enfileirarMutacoes: false);

    await repo.criarLista(titulo: 'Mercado', donoId: 'local');

    final pendentes = await db.select(db.mutacaoPendente).get();
    expect(pendentes, isEmpty);
  });

  test('deve_enfileirar_mutacao_quando_outbox_ligada', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = ListasRepository(db);

    await repo.criarLista(titulo: 'Mercado', donoId: 'user-a');

    final pendentes = await db.select(db.mutacaoPendente).get();
    expect(pendentes, isNotEmpty);
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/features/listas/outbox_lite_test.dart`
Expected: FAIL — `enfileirarMutacoes` não existe.

- [ ] **Step 3: Implementar**

Em `listas_repository.dart`, no construtor:

```dart
  ListasRepository(this._db, {Uuid? uuid, bool enfileirarMutacoes = true})
    : _uuid = uuid ?? const Uuid(),
      _enfileirarMutacoes = enfileirarMutacoes;

  final AppDatabase _db;
  final Uuid _uuid;

  /// No modo Lite (RF-31) não há sync: a fila de mutações não é alimentada
  /// (senão cresceria para sempre sem drenar).
  final bool _enfileirarMutacoes;
```

E em `_enfileirar` (`:642`), primeira linha:

```dart
    if (!_enfileirarMutacoes) return Future<void>.value();
```

Em `listas_providers.dart` (`:19-21`):

```dart
final listasRepositoryProvider = Provider<ListasRepository>(
  (ref) => ListasRepository(
    ref.watch(appDatabaseProvider),
    enfileirarMutacoes: ref.watch(capacidadesProvider).nuvem,
  ),
);
```

(import `../../../core/config/app_modo.dart`.)

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/features/listas/outbox_lite_test.dart`
Expected: PASS (2 testes).

- [ ] **Step 5: Commit**

```bash
git add lib/features/listas test/features/listas/outbox_lite_test.dart
git commit -m "F41-T06: outbox desligada no modo Lite (RF-31)"
```

---

### Task 7: Rotas do Lite

**Files:**
- Modify: `lib/router.dart`
- Test: `test/router_lite_test.dart`

**Interfaces:**
- Consumes: `capacidadesProvider` (Task 2).
- Produces: `routerProvider` que monta a tabela conforme as capacidades: no Lite não existem `/login`, `/registro`, `/recuperar-senha`, `/redefinir-senha`, `/entrar`, `/login-callback`, `/compartilhadas`, `/membros/:listaId`; a raiz vai para `/listas` e o `redirect` é no-op.

- [ ] **Step 1: Escrever o teste**

`test/router_lite_test.dart` — no modo Lite a raiz abre `MinhasListasScreen` (sem gate de sessão) e a rota de login não existe:

```dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/config/app_modo.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/auth/data/auth_local_repository.dart';
import 'package:lista_compras/features/auth/providers/auth_providers.dart';
import 'package:lista_compras/features/auth/ui/login_screen.dart';
import 'package:lista_compras/features/listas/providers/listas_providers.dart';
import 'package:lista_compras/features/listas/ui/minhas_listas_screen.dart';
import 'package:lista_compras/router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('deve_abrir_listas_e_nao_ter_login_quando_modo_lite', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'onboarding_visto': true});
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final container = ProviderContainer(
      overrides: [
        capacidadesProvider.overrideWithValue(AppCapacidades.lite),
        authRepositoryProvider.overrideWithValue(AuthLocalRepository()),
        appDatabaseProvider.overrideWithValue(db),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: container.read(routerProvider)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MinhasListasScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/router_lite_test.dart`
Expected: FAIL — a raiz hoje redireciona para `/login` sem sessão e `/login` existe.

- [ ] **Step 3: Implementar**

Em `router.dart`, ler `final cap = ref.watch(capacidadesProvider);` dentro de `routerProvider` e:

1. `redirect` — no Lite, `return null;` no topo (sem gate). No `prod`, manter o código atual.
2. Rotas de conta (`/login`, `/registro`, `/recuperar-senha`, `/redefinir-senha`, `/entrar`, `/login-callback`) — envolver em `if (cap.colaboracao) ...`.
3. `StatefulShellRoute` — no Lite, `branches` só com `/listas` e `/configuracoes`; no `prod`, os três atuais.
4. `/membros/:listaId` — só quando `cap.colaboracao`.
5. Rota `/` — no Lite, `redirect: (_, _) => '/listas'`.
6. `refreshListenable` — manter (no Lite o stream é vazio).

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/router_lite_test.dart`
Expected: PASS.

- [ ] **Step 5: Suíte inteira**

Run: `flutter test`
Expected: verde (rotas do `prod` inalteradas).

- [ ] **Step 6: Commit**

```bash
git add lib/router.dart test/router_lite_test.dart
git commit -m "F41-T07: rotas do modo Lite sem conta nem compartilhamento (RF-31)"
```

---

### Task 8: UI do Lite (abas, convites, sync, configurações)

**Files:**
- Modify: `lib/core/navigation/app_shell.dart`
- Modify: `lib/features/listas/ui/painel_listas.dart`
- Modify: `lib/features/listas/ui/tela_lista_screen.dart`
- Modify: `lib/features/listas/ui/mercado_screen.dart`
- Modify: `lib/features/configuracoes/ui/configuracoes_screen.dart`
- Modify: `lib/features/convites/providers/papel_providers.dart`
- Test: `test/features/listas/lite_ui_test.dart`

**Interfaces:**
- Consumes: `capacidadesProvider` (Task 2); `AuthLocalRepository` (Task 4).
- Produces: UI do Lite sem abas/convites/sync e sem tocar `Supabase.instance`.

- [ ] **Step 1: Escrever o teste**

`test/features/listas/lite_ui_test.dart` — monta o painel no modo Lite e verifica que **nada** de conta/sync aparece e que **não** houve exceção (o Supabase não está inicializado neste teste):

```dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/config/app_modo.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/auth/data/auth_local_repository.dart';
import 'package:lista_compras/features/auth/providers/auth_providers.dart';
import 'package:lista_compras/features/listas/providers/listas_providers.dart';
import 'package:lista_compras/features/listas/ui/minhas_listas_screen.dart';
import 'package:lista_compras/features/sync/ui/indicador_sync.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('deve_esconder_convites_e_sync_quando_modo_lite', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_visto': true});
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          capacidadesProvider.overrideWithValue(AppCapacidades.lite),
          authRepositoryProvider.overrideWithValue(AuthLocalRepository()),
          appDatabaseProvider.overrideWithValue(db),
        ],
        child: const MaterialApp(home: MinhasListasScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(IndicadorSync), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/features/listas/lite_ui_test.dart`
Expected: FAIL — `IndicadorSync` aparece e/ou `Supabase.instance` lança.

- [ ] **Step 3: `app_shell.dart` — abas por capacidade**

Trocar as listas `static const _icones/_rotulos` por listas montadas no `build` conforme `ref.watch(capacidadesProvider).colaboracao` (transformar `AppShell` em `ConsumerWidget`): sem colaboração, apenas "Minhas listas" e "Configurações".

- [ ] **Step 4: `papel_providers.dart` — guardas**

No topo de `papelNaListaStreamProvider`:

```dart
  if (!ref.watch(capacidadesProvider).colaboracao) return Stream.value(null);
```

No topo de `papelEfetivoProvider`:

```dart
  if (!ref.watch(capacidadesProvider).colaboracao) return Papel.dono;
```

- [ ] **Step 5: `painel_listas.dart` — guardas e esconder**

- `:137-140` — `IndicadorSync` só quando `nuvem`.
- `:157` — `ConvitesPendentesSecao` só quando `colaboracao`.
- `:126-131` — ação de código de convite só quando `colaboracao` (já sob `_compartilhadas`).
- `:358` e `:505` — `papelRepositoryProvider.atualizar(...)` só quando `colaboracao`.
- `:506` — `notificacoesServiceProvider.talvezPedirPermissao()` só quando `notificacoes`.

- [ ] **Step 6: `tela_lista_screen.dart` — guardas e esconder**

- `:94` — `_papelRepo = ref.read(capacidadesProvider).colaboracao ? ref.read(papelRepositoryProvider) : null;`
- `:147-150` — casos `'convidar'`/`'membros'` só quando `colaboracao`.
- `:258` — `membrosDaListaProvider` só quando `colaboracao`.
- `:397-403` — itens de menu `membros`/`convidar` só quando `colaboracao`.
- `:422` — `IndicadorSync` só quando `nuvem`.

- [ ] **Step 7: `mercado_screen.dart`**

`:133` — `IndicadorSync` só quando `nuvem`.

- [ ] **Step 8: `configuracoes_screen.dart`**

- Seção `AppStrings.notificacoes` (`:105-115`) só quando `notificacoes`.
- Seção `AppStrings.conta` e o bloco de exclusão (`:116-165`) só quando `colaboracao`.
- Deixar o espaço da seção de backup para a Task 11.

- [ ] **Step 9: Rodar e ver passar**

Run: `flutter test test/features/listas/lite_ui_test.dart`
Expected: PASS.

- [ ] **Step 10: Suíte inteira**

Run: `flutter test`
Expected: verde.

- [ ] **Step 11: Commit**

```bash
git add lib/core/navigation lib/features/listas lib/features/configuracoes lib/features/convites test/features/listas/lite_ui_test.dart
git commit -m "F41-T08: UI do modo Lite sem conta, convites e sync (RF-31)"
```

---

### Task 9: Backup — exportar JSON

**Files:**
- Create: `lib/features/backup/domain/backup_arquivo.dart`
- Create: `lib/features/backup/data/backup_repository.dart`
- Test: `test/features/backup/backup_export_test.dart`

**Interfaces:**
- Consumes: `AppDatabase`.
- Produces: `class BackupArquivo { static const versao = 1; final DateTime exportadoEm; final List<Map<String, Object?>> listas, itens, historicoPrecos; }` com `toJson()`/`fromJson()`; `class BackupRepository { BackupRepository(AppDatabase db); Future<String> exportarJson(); Future<void> importarJson(String conteudo); }`.

- [ ] **Step 1: Escrever o teste**

`test/features/backup/backup_export_test.dart`:

```dart
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/backup/data/backup_repository.dart';
import 'package:lista_compras/features/listas/data/listas_repository.dart';

void main() {
  test('deve_exportar_listas_e_itens_ativos_quando_ha_dados', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final listas = ListasRepository(db);
    final lista = await listas.criarLista(titulo: 'Mercado', donoId: 'local');
    await listas.criarItem(listaId: lista.id, nome: 'Arroz');

    final json = await BackupRepository(db).exportarJson();
    final mapa = jsonDecode(json) as Map<String, dynamic>;

    expect(mapa['versao'], 1);
    expect((mapa['listas'] as List), hasLength(1));
    expect((mapa['itens'] as List), hasLength(1));
    expect((mapa['historicoPrecos'] as List), isEmpty);
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/features/backup/backup_export_test.dart`
Expected: FAIL — arquivos não existem.

- [ ] **Step 3: Implementar o domínio**

`lib/features/backup/domain/backup_arquivo.dart`:

```dart
/// Formato do backup local (RF-31, F41). `versao` permite evolução futura.
class BackupArquivo {
  const BackupArquivo({
    required this.exportadoEm,
    required this.listas,
    required this.itens,
    required this.historicoPrecos,
  });

  static const versao = 1;

  final DateTime exportadoEm;
  final List<Map<String, Object?>> listas;
  final List<Map<String, Object?>> itens;
  final List<Map<String, Object?>> historicoPrecos;

  Map<String, Object?> toJson() => {
    'versao': versao,
    'exportadoEm': exportadoEm.toUtc().toIso8601String(),
    'listas': listas,
    'itens': itens,
    'historicoPrecos': historicoPrecos,
  };

  factory BackupArquivo.fromJson(Map<String, dynamic> json) => BackupArquivo(
    exportadoEm: DateTime.parse(json['exportadoEm'] as String),
    listas: (json['listas'] as List).cast<Map<String, Object?>>(),
    itens: (json['itens'] as List).cast<Map<String, Object?>>(),
    historicoPrecos:
        (json['historicoPrecos'] as List).cast<Map<String, Object?>>(),
  );
}
```

- [ ] **Step 4: Implementar o repositório (export)**

`lib/features/backup/data/backup_repository.dart`:

```dart
import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../drift/database.dart';
import '../domain/backup_arquivo.dart';

/// Backup inválido (JSON malformado ou versão desconhecida). O banco **não** é
/// alterado quando isto é lançado.
class BackupInvalidoException implements Exception {
  const BackupInvalidoException(this.mensagem);
  final String mensagem;
  @override
  String toString() => 'BackupInvalidoException: $mensagem';
}

class BackupRepository {
  BackupRepository(this._db);

  final AppDatabase _db;

  String _iso(DateTime d) => d.toUtc().toIso8601String();

  Future<String> exportarJson() async {
    final listas =
        await (_db.select(_db.listaLocal)..where((l) => l.deletadoEm.isNull()))
            .get();
    final itens =
        await (_db.select(_db.itemLocal)..where((i) => i.deletadoEm.isNull()))
            .get();
    final historico = await _db.select(_db.historicoPrecoLocal).get();

    final arquivo = BackupArquivo(
      exportadoEm: DateTime.now().toUtc(),
      listas: listas
          .map(
            (l) => <String, Object?>{
              'id': l.id,
              'titulo': l.titulo,
              'dono_id': l.donoId,
              'created_at': _iso(l.createdAt),
              'updated_at': _iso(l.updatedAt),
              'arquivada_em':
                  l.arquivadaEm == null ? null : _iso(l.arquivadaEm!),
              'orcamento_centavos': l.orcamentoCentavos,
              'deletado_em': l.deletadoEm == null ? null : _iso(l.deletadoEm!),
            },
          )
          .toList(),
      itens: itens
          .map(
            (i) => <String, Object?>{
              'id': i.id,
              'lista_id': i.listaId,
              'nome': i.nome,
              'quantidade': i.quantidade,
              'unidade': i.unidade,
              'categoria': i.categoria,
              'preco_centavos': i.precoCentavos,
              'concluido': i.concluido,
              'ordem': i.ordem,
              'created_at': _iso(i.createdAt),
              'updated_at': _iso(i.updatedAt),
              'deletado_em': i.deletadoEm == null ? null : _iso(i.deletadoEm!),
            },
          )
          .toList(),
      historicoPrecos: historico
          .map(
            (h) => <String, Object?>{
              'nome_normalizado': h.nomeNormalizado,
              'preco_centavos': h.precoCentavos,
              'unidade': h.unidade,
              'registrado_em': _iso(h.registradoEm),
            },
          )
          .toList(),
    );
    return jsonEncode(arquivo.toJson());
  }

  Future<void> importarJson(String conteudo) =>
      throw UnimplementedError('importação implementada na Task 10');
}
```

- [ ] **Step 5: Rodar e ver passar**

Run: `flutter test test/features/backup/backup_export_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/backup test/features/backup/backup_export_test.dart
git commit -m "F41-T09: backup exportar JSON (RF-31)"
```

---

### Task 10: Backup — importar JSON (merge/LWW)

**Files:**
- Modify: `lib/features/backup/data/backup_repository.dart`
- Modify: `lib/features/backup/domain/backup_arquivo.dart` (se precisar validar versão)
- Test: `test/features/backup/backup_import_test.dart`

**Interfaces:**
- Consumes: `BackupArquivo`, `BackupRepository.exportarJson()` (Task 9).
- Produces: `Future<void> importarJson(String conteudo)` — merge por `id`, **LWW por `updated_at`** (lista/item) e por `registrado_em` (histórico), em **transação**; lança `BackupInvalidoException` para JSON inválido ou `versao` desconhecida **sem** tocar o banco.

- [ ] **Step 1: Escrever o teste**

`test/features/backup/backup_import_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/backup/data/backup_repository.dart';
import 'package:lista_compras/features/listas/data/listas_repository.dart';

void main() {
  test('deve_restaurar_listas_e_itens_quando_backup_valido', () async {
    final origem = AppDatabase(NativeDatabase.memory());
    addTearDown(origem.close);
    final repoOrigem = ListasRepository(origem);
    final lista = await repoOrigem.criarLista(titulo: 'Mercado', donoId: 'local');
    await repoOrigem.criarItem(listaId: lista.id, nome: 'Arroz');
    final json = await BackupRepository(origem).exportarJson();

    final destino = AppDatabase(NativeDatabase.memory());
    addTearDown(destino.close);
    await BackupRepository(destino).importarJson(json);

    final listas = await destino.select(destino.listaLocal).get();
    final itens = await destino.select(destino.itemLocal).get();
    expect(listas, hasLength(1));
    expect(itens, hasLength(1));
    expect(itens.single.nome, 'Arroz');
  });

  test('deve_lancar_erro_sem_alterar_banco_quando_versao_desconhecida', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await expectLater(
      BackupRepository(db).importarJson('{"versao":99,"listas":[],"itens":[],"historicoPrecos":[]}'),
      throwsA(isA<BackupInvalidoException>()),
    );
    expect(await db.select(db.listaLocal).get(), isEmpty);
  });
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `flutter test test/features/backup/backup_import_test.dart`
Expected: FAIL — `importarJson` lança `UnimplementedError`.

- [ ] **Step 3: Implementar**

Substituir o corpo de `importarJson` (a classe `BackupInvalidoException` já existe da Task 9):

```dart
  DateTime? _parseOpt(Object? v) =>
      v == null ? null : DateTime.parse(v as String);

  Future<void> importarJson(String conteudo) async {
    final Map<String, dynamic> mapa;
    try {
      mapa = jsonDecode(conteudo) as Map<String, dynamic>;
    } on FormatException {
      throw const BackupInvalidoException('JSON inválido');
    } on TypeError {
      throw const BackupInvalidoException('JSON inválido');
    }
    if (mapa['versao'] != BackupArquivo.versao) {
      throw BackupInvalidoException(
        'Versão de backup não suportada: ${mapa['versao']}',
      );
    }
    final arquivo = BackupArquivo.fromJson(mapa);

    await _db.transaction(() async {
      for (final l in arquivo.listas) {
        final id = l['id'] as String;
        final atualizadoEm = DateTime.parse(l['updated_at'] as String);
        final existente =
            await (_db.select(_db.listaLocal)..where((t) => t.id.equals(id)))
                .getSingleOrNull();
        if (existente != null && !atualizadoEm.isAfter(existente.updatedAt)) {
          continue;
        }
        await _db
            .into(_db.listaLocal)
            .insertOnConflictUpdate(
              ListaLocalCompanion.insert(
                id: id,
                createdAt: DateTime.parse(l['created_at'] as String),
                updatedAt: atualizadoEm,
                titulo: l['titulo'] as String,
                donoId: l['dono_id'] as String,
                deletadoEm: Value(_parseOpt(l['deletado_em'])),
                arquivadaEm: Value(_parseOpt(l['arquivada_em'])),
                orcamentoCentavos: Value(l['orcamento_centavos'] as int?),
              ),
            );
      }

      for (final i in arquivo.itens) {
        final id = i['id'] as String;
        final atualizadoEm = DateTime.parse(i['updated_at'] as String);
        final existente =
            await (_db.select(_db.itemLocal)..where((t) => t.id.equals(id)))
                .getSingleOrNull();
        if (existente != null && !atualizadoEm.isAfter(existente.updatedAt)) {
          continue;
        }
        await _db
            .into(_db.itemLocal)
            .insertOnConflictUpdate(
              ItemLocalCompanion.insert(
                id: id,
                listaId: i['lista_id'] as String,
                nome: i['nome'] as String,
                quantidade: Value((i['quantidade'] as num).toDouble()),
                unidade: Value(i['unidade'] as String),
                categoria: Value(i['categoria'] as String),
                precoCentavos: Value(i['preco_centavos'] as int?),
                concluido: Value(i['concluido'] as bool),
                ordem: Value(i['ordem'] as int),
                createdAt: DateTime.parse(i['created_at'] as String),
                updatedAt: atualizadoEm,
                deletadoEm: Value(_parseOpt(i['deletado_em'])),
              ),
            );
      }

      for (final h in arquivo.historicoPrecos) {
        final nome = h['nome_normalizado'] as String;
        final registradoEm = DateTime.parse(h['registrado_em'] as String);
        final existente =
            await (_db.select(_db.historicoPrecoLocal)
                  ..where((t) => t.nomeNormalizado.equals(nome)))
                .getSingleOrNull();
        if (existente != null &&
            !registradoEm.isAfter(existente.registradoEm)) {
          continue;
        }
        await _db
            .into(_db.historicoPrecoLocal)
            .insertOnConflictUpdate(
              HistoricoPrecoLocalCompanion.insert(
                nomeNormalizado: nome,
                precoCentavos: h['preco_centavos'] as int,
                unidade: h['unidade'] as String,
                registradoEm: registradoEm,
              ),
            );
      }
    });
  }
```

- [ ] **Step 4: Rodar e ver passar**

Run: `flutter test test/features/backup/backup_import_test.dart`
Expected: PASS (2 testes).

- [ ] **Step 5: Commit**

```bash
git add lib/features/backup test/features/backup/backup_import_test.dart
git commit -m "F41-T10: backup importar JSON com merge LWW (RF-31)"
```

---

### Task 11: UI de backup em Configurações

**Files:**
- Modify: `pubspec.yaml` (nova dependência `file_picker`)
- Create: `lib/features/backup/providers/backup_providers.dart`
- Create: `lib/features/backup/ui/secao_backup.dart`
- Modify: `lib/features/configuracoes/ui/configuracoes_screen.dart`
- Modify: `lib/core/l10n/app_strings.dart`
- Test: `test/features/backup/secao_backup_test.dart`

**Interfaces:**
- Consumes: `BackupRepository` (Tasks 9/10); `capacidadesProvider.backup` (Task 2).
- Produces: `backupRepositoryProvider`; widget `SecaoBackup` (seção "Backup" com "Exportar backup" e "Importar backup"); strings `AppStrings.backup`, `backupExportar`, `backupImportar`, `backupExportado`, `backupImportado`, `backupInvalido`.

- [ ] **Step 1: Adicionar a dependência**

Run: `flutter pub add file_picker`
Expected: `file_picker` adicionado ao `pubspec.yaml` e resolvido.

- [ ] **Step 2: Escrever o teste**

`test/features/backup/secao_backup_test.dart` — verifica que a seção aparece no modo Lite e dispara a exportação (com o repositório fakeado):

```dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/l10n/app_strings.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/backup/ui/secao_backup.dart';
import 'package:lista_compras/features/listas/providers/listas_providers.dart';

void main() {
  testWidgets('deve_mostrar_exportar_e_importar_quando_secao_backup', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: Scaffold(body: SecaoBackup())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.backupExportar), findsOneWidget);
    expect(find.text(AppStrings.backupImportar), findsOneWidget);
  });
}
```

- [ ] **Step 3: Rodar e ver falhar**

Run: `flutter test test/features/backup/secao_backup_test.dart`
Expected: FAIL — `SecaoBackup` não existe.

- [ ] **Step 4: Implementar**

- `backup_providers.dart`: `final backupRepositoryProvider = Provider<BackupRepository>((ref) => BackupRepository(ref.watch(appDatabaseProvider)));`
- `secao_backup.dart`: `SecaoBackup` (ConsumerWidget) com `AppCabecalhoSecao(AppStrings.backup)` + 2 `ListTile`s. **Exportar**: `exportarJson()` → grava `backup_<data>.json` em `getTemporaryDirectory()` → `SharePlus.instance.share(ShareParams(files: [XFile(caminho)]))` → snackbar `backupExportado`. **Importar**: `FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json'])` → lê o arquivo → `importarJson(conteudo)` → snackbar `backupImportado`; `BackupInvalidoException` → `backupInvalido`. Envolver em `try/catch` para `MissingPluginException` (share indisponível), como em `sheet_convidar.dart:195-201`.
- `configuracoes_screen.dart`: inserir `const SecaoBackup()` logo após a seção "Sobre", visível quando `ref.watch(capacidadesProvider).backup`.
- `app_strings.dart`: adicionar as strings.

- [ ] **Step 5: Rodar e ver passar**

Run: `flutter test test/features/backup/secao_backup_test.dart`
Expected: PASS.

- [ ] **Step 6: Suíte inteira**

Run: `flutter test`
Expected: verde.

- [ ] **Step 7: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/features/backup lib/features/configuracoes lib/core/l10n/app_strings.dart test/features/backup/secao_backup_test.dart
git commit -m "F41-T11: exportar e importar backup nas Configuracoes (RF-31)"
```

---

### Task 12: Nativo — flavors `prod`/`lite` (nome e ícone)

**Pré-requisito:** as ações do dono no topo deste plano (app Firebase do Lite + `google-services.json` com os dois apps).

**Files:**
- Modify: `android/app/build.gradle.kts`
- Modify: `android/app/src/main/AndroidManifest.xml`
- Create: `android/app/src/prod/AndroidManifest.xml`
- Create: `android/app/src/lite/res/values/colors.xml`

**Interfaces:**
- Consumes: os dois entrypoints (Task 5).
- Produces: `flutter build apk --flavor prod` (applicationId `br.com.oliverlucas.listacompras`) e `--flavor lite` (`.lite`), ambos instaláveis ao mesmo tempo.

- [ ] **Step 1: Definir os flavors**

Em `android/app/build.gradle.kts`, dentro de `android { }`, após `defaultConfig` (removendo o `applicationId` do `defaultConfig`, que passa a ser por flavor):

```kotlin
    flavorDimensions += "modo"
    productFlavors {
        create("prod") {
            dimension = "modo"
            applicationId = "br.com.oliverlucas.listacompras"
            resValue("string", "app_name", "Lista de Compras")
        }
        create("lite") {
            dimension = "modo"
            applicationId = "br.com.oliverlucas.listacompras.lite"
            resValue("string", "app_name", "Lista de Compras Lite")
        }
    }
```

- [ ] **Step 2: Nome por flavor no manifesto**

Em `android/app/src/main/AndroidManifest.xml:7`, trocar `android:label="Lista de Compras"` por `android:label="@string/app_name"`.

- [ ] **Step 3: Deep links só no `prod`**

Mover os dois `<intent-filter>` de deep link (auth `:31-38` e convite `:39-46`) para `android/app/src/prod/AndroidManifest.xml` (o Lite não tem login nem convites; evita disputar o mesmo scheme com o app colaborativo instalado ao lado):

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application>
        <activity android:name=".MainActivity">
            <intent-filter android:autoVerify="false">
                <action android:name="android.intent.action.VIEW"/>
                <category android:name="android.intent.category.DEFAULT"/>
                <category android:name="android.intent.category.BROWSABLE"/>
                <data android:scheme="br.com.oliverlucas.listacompras" android:host="login-callback"/>
            </intent-filter>
            <intent-filter android:autoVerify="false">
                <action android:name="android.intent.action.VIEW"/>
                <category android:name="android.intent.category.DEFAULT"/>
                <category android:name="android.intent.category.BROWSABLE"/>
                <data android:scheme="br.com.oliverlucas.listacompras" android:host="entrar"/>
            </intent-filter>
        </activity>
    </application>
</manifest>
```

- [ ] **Step 4: Ícone distinto do Lite**

Ler `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml` para confirmar o nome do recurso de cor de fundo (`@color/ic_launcher_background`). Criar `android/app/src/lite/res/values/colors.xml` sobrescrevendo **apenas** essa cor com um valor distinto do verde do prod:

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#1565C0</color>
</resources>
```

- [ ] **Step 5: Verificar os dois builds**

Run: `flutter build apk --debug --flavor prod`
Expected: `app-prod-debug.apk` gerado.
Run: `flutter build apk --debug --flavor lite`
Expected: `app-lite-debug.apk` gerado, sem erro do `google-services`.

- [ ] **Step 6: Commit**

```bash
git add android/app/build.gradle.kts android/app/src
git commit -m "F41-T12: flavors prod e lite com nome e icone proprios (RF-31)"
```

---

### Task 13: CI — build dos dois flavors

**Files:**
- Modify: `.github/workflows/ci.yml`
- Modify: `docs/07-qualidade-ci.md`

**Interfaces:**
- Consumes: Task 12.
- Produces: CI que compila `--flavor prod` e `--flavor lite`.

- [ ] **Step 1: Atualizar o job `flutter`**

Em `.github/workflows/ci.yml:40`, trocar:

```yaml
      - if: steps.check.outputs.flutter == 'enabled'
        run: flutter build apk --debug --flavor prod
      - if: steps.check.outputs.flutter == 'enabled'
        run: flutter build apk --debug --flavor lite
```

- [ ] **Step 2: Atualizar o doc 07 §3**

Em `docs/07-qualidade-ci.md`, na descrição dos builds de plataforma, registrar que o job `flutter` compila os **dois** flavors (`--flavor prod` e `--flavor lite`) e que a suíte de testes roda uma vez (cobre os dois modos).

- [ ] **Step 3: Rodar localmente antes de subir**

Run: `flutter build apk --debug --flavor prod; flutter build apk --debug --flavor lite`
Expected: ambos OK.

- [ ] **Step 4: Commit e push**

```bash
git add .github/workflows/ci.yml docs/07-qualidade-ci.md
git commit -m "F41-T13: CI builda os flavors prod e lite (RF-31)"
git push
```

- [ ] **Step 5: Conferir o CI**

Run: `gh run list --limit 1`
Expected: run do push; todos os jobs verdes (o `supabase` continua sendo o único sensível a infra externa).

---

### Task 14: Fechamento — docs donos e distribuição

**Files:**
- Modify: `docs/14-tarefas.md` (marcar F41-T01…T14 e a tabela de progresso)
- Modify: `docs/09-runbook-operacoes.md` (§2.6 histórico + §builds com `--flavor`)
- Modify: `docs/05-app-flutter.md` (fechar os modos/backup, se algo mudou)
- Modify: `pubspec.yaml` + `web/version.json` (bump `1.5.0+12`)

**Interfaces:**
- Consumes: todas as tasks anteriores.
- Produces: fase fechada, app Lite distribuído.

- [ ] **Step 1: Bump de versão**

`pubspec.yaml` → `version: 1.5.0+12`; `web/version.json` → `"build_number":"12"` (o teste de paridade `version_json_test.dart` exige os dois iguais).

Run: `flutter test test/core/config/version_json_test.dart`
Expected: PASS.

- [ ] **Step 2: Marcar a fase no doc 14**

Marcar F41-T01…T14 como `- [x]`, atualizar a tabela da Fase 41 (`14 | 14`) e a tabela de progresso geral.

- [ ] **Step 3: Runbook**

Em `docs/09-runbook-operacoes.md`: registrar a Fase 41 no §2.6 (o que o Lite desliga, dono local `'local'`, backup JSON) e atualizar os comandos de build/distribuição para `--flavor prod` / `--flavor lite` (o APK passa a ser `app-prod-release.apk`).

- [ ] **Step 4: Suíte completa e formatação**

Run: `dart format . && flutter analyze && flutter test`
Expected: sem alterações de formatação, `analyze` limpo, toda a suíte verde.

- [ ] **Step 5: Build e distribuição do Lite**

Run: `flutter build apk --release --flavor lite --dart-define-from-file=dart_defines_prod.json`
Run: `flutter build apk --release --flavor prod --dart-define-from-file=dart_defines_prod.json`
Run: `firebase appdistribution:distribute build/app/outputs/flutter-apk/app-lite-release.apk --app "<app-id do Lite>" --groups testadores --release-notes "Versao Lite (RF-31): uso sem conta, 100% no aparelho, com backup exportar/importar."`
Expected: distribuição confirmada ao grupo `testadores`.

- [ ] **Step 6: Commit e push**

```bash
git add docs pubspec.yaml web/version.json
git commit -m "F41-T14: fase Lite concluida e distribuida (RF-31)"
git push
```

---

## Notas de risco (para o revisor da fase)

- **`google-services.json`** sem o app Lite faz o build `--flavor lite` falhar — é o único bloqueio externo (ação do dono).
- **Suíte de testes** roda uma vez e cobre os dois modos (não há `flutter test --flavor`); o flavor só entra nos builds.
- **Web** continua sendo o app colaborativo: `web/version.json` só acompanha o bump do `pubspec` (paridade), sem build web do Lite.
- **iOS** fora do escopo (sem macOS) — follow-up no doc 16.
