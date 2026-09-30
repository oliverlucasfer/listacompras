# ListaCompras — "Minhas Listas"

App de lista de compras local e offline-first (Flutter + Drift). **100% no aparelho**: sem conta, sem nuvem, sem sincronização (RF-31).

- **Offline-first**: os dados ficam no Drift/SQLite; nada depende de rede
- **Importação de lista**: parser local determinístico e offline (texto livre, RF-16)
- **Backup local**: exportar/importar `.json` (RF-31)
- **Privacidade**: nada sai do aparelho

## Stack

Flutter · Riverpod · Drift · GitHub Actions

## Documentação

Índice completo em [`planejamento_lista_compras.md`](planejamento_lista_compras.md).
Contexto técnico em uma leitura: [`docs/13-premodelo-tecnico.md`](docs/13-premodelo-tecnico.md).

## Desenvolvimento

```bash
flutter test                        # testes
dart format . && flutter analyze    # estilo e lint (CI exige)
```

### Builds

O app é único ("Minhas Listas", `br.com.oliverlucas.listacompras.lite`), **sem flavors** e **sem `--dart-define`**:

```bash
flutter run
flutter build apk --release
flutter build appbundle --release
```

O CI (`.github/workflows/ci.yml`) roda `dart format --set-exit-if-changed`, `flutter analyze`, `flutter test` e os builds Web (`flutter build web --release`), apk debug, AAB release (com verificação do manifest sem `INTERNET`/Firebase) e desktop (Linux/Windows). Build/distribuição e publicação em [`docs/09`](docs/09-runbook-operacoes.md) §2.9–§2.10.

### Testes

- **Repositórios/Drift, parser local e fluxos críticos** — detalhes em [`docs/07`](docs/07-qualidade-ci.md) §1.
