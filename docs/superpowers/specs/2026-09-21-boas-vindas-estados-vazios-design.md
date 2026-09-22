# Frente — Boas-vindas (Onboarding) e Estados Vazios (design)

> **Status:** aprovado em 21/09/2026 (decisões registradas na Seção 8)
> **Fase:** 31 · **Requisito:** RF-27 (boas-vindas + estados vazios)
> **Docs donos:** [05](../05-app-flutter.md) (UI), [10](../10-wireframes-telas.md) (layout),
> [12](../12-prd.md), [14](../14-tarefas.md), [16](../16-roadmap-pos-mvp.md)

---

## 1. Motivação

O app nasce direto no painel, sem apresentar o que sabe fazer — e o usuário novo não descobre offline, compartilhamento, importação por texto ou voz por conta própria. Uma **tela de boas-vindas** curta (uma vez) apresenta o valor; e alguns **estados vazios** podem apontar o próximo passo em vez de só dizer "vazio".

Tudo local: uma flag em `SharedPreferences` (como o tema) e ajustes de copy — **sem schema/RLS/sync**.

## 2. Escopo

**Dentro:**
- Tela **`/boas-vindas`** (1 página) mostrada **uma vez** na primeira vez no app autenticado, com destaques + "Começar".
- Melhorias de copy/ação nos **estados vazios** que não apontam um caminho claro.

**Fora:** onboarding multi-página, tour guiado/interativo, mostrar a cada login.

## 3. Flag local

`lib/features/onboarding/providers/onboarding_provider.dart`, espelhando `temaModoProvider` ([15](../15-design-system.md)):

```dart
class OnboardingNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_chave) ?? false; // _chave = 'onboarding_visto'
  }

  Future<void> marcarVisto() async {
    state = const AsyncData(true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_chave, true);
  }
}

final onboardingVistoProvider = AsyncNotifierProvider<OnboardingNotifier, bool>(
  OnboardingNotifier.new,
);
```

- Sem rede/Drift; a leitura é assíncrona (a home só age quando o valor carrega).

## 4. Tela de boas-vindas

- **Rota:** `/boas-vindas` (top-level, **protegida** — não está na lista de rotas públicas; quem não está autenticado cai no login).
- **Conteúdo** (uma página, rolável, escala de fonte respeitada — RNF-06):
  - marca (`AppLogo`) + título (`AppStrings.boasVindasTitulo`) e subtítulo curto;
  - 3–4 **destaques** com ícone + texto: **funciona offline** (dados no aparelho, sincroniza ao voltar), **compartilhe a lista** com quem quiser, **importe por texto** (cole uma anotação), **dite um item** (voz on-device);
  - botão **"Começar"** (`AppBotao`) → `marcarVisto()` + `context.go('/listas')`.
- Sem botão "Pular" (é uma página só; "Começar" é o único caminho).

## 5. Exibição (uma vez)

- Na **home autenticada** (`MinhasListasScreen`, hoje `StatelessWidget` → passa a `ConsumerStatefulWidget`), um guard no `initState`/post-frame: quando `onboardingVistoProvider` resolve **falso**, faz `context.push('/boas-vindas')` uma única vez; quando verdadeiro (ou após voltar), não faz nada.
- Evita mexer no redirect do `go_router` (que é síncrono e já cuida de auth/senha).
- `MinhasListasScreen` só existe autenticado; a tela `/boas-vindas` é protegida de qualquer forma.

## 6. Estados vazios

Melhorias pontuais (sem telas novas):

| Tela | Estado | Agora | Melhoria |
| :--- | :--- | :--- | :--- |
| Lista | `nenhumItem` | "Adicione o primeiro item no campo acima." | dica aponta os caminhos existentes: adicionar no campo, **importar** (botão no rodapé) ou **ditar** (microfone) |
| Minhas Listas | `nenhumaLista` | "Crie sua primeira lista ou importe por texto." | manter; garantir que cite **importar por texto** (já cita) e o CTA de criação |
| Compartilhadas | `nenhumaCompartilhada` | dica + CTA "Entrar com código" | inalterado (ação clara) |
| Mercado | `mercadoTudoComprado` | CTA "Voltar para a lista" | inalterado |
| Busca | sem resultado | "Tente outro termo." | inalterado |

- Copy **só** em `AppStrings`.

## 7. Testes

**Provider:** `deve_carregar_falso_quando_nunca_visto`; `deve_marcar_visto_quando_chama` (persiste em `SharedPreferences`, com `setMockInitialValues`).

**Widget:**
- `deve_abrir_boas_vindas_quando_nao_visto` (home com a flag falsa → a tela abre; `MinhasListasScreen` precisa de um `GoRouter` de teste com `/boas-vindas`).
- `nao_deve_abrir_boas_vindas_quando_ja_visto`.
- `deve_marcar_visto_e_navegar_quando_comecar` (toca "Começar" → flag gravada + vai para `/listas`).
- `deve_mostrar_destaques_quando_boas_vindas` (os 4 destaques + botão).
- `deve_mostrar_dica_com_caminhos_quando_lista_vazia` (a dica da lista vazia cita importar/ditar).

## 8. Documentos donos no mesmo PR
- `05` (tela de boas-vindas + §6.3 vazio da lista), `10` (wireframe das boas-vindas + nota dos vazios), `12` (RF-27 + rastreabilidade), `14` (Fase 31 + progresso), `16` (A7).

## 9. Decisões registradas (21/09/2026)

1. **Uma** tela de boas-vindas (não multi-página), mostrada **uma vez** (flag local), com "Começar".
2. Exibição via guard na home autenticada (não no redirect do router).
3. Estados vazios: só melhorar os que não apontam caminho claro (lista vazia); os demais ficam.
4. Sem schema/RLS/sync; **sem ADR novo**. Fase **31**, requisito **RF-27**.

## 10. Documentos relacionados
- [05 App Flutter](../05-app-flutter.md) / [10 Wireframes](../10-wireframes-telas.md) — tela e vazios
- [12 PRD](../12-prd.md) — RF-27
- [14 Tarefas](../14-tarefas.md) — Fase 31
- [16 Roadmap](../16-roadmap-pos-mvp.md) — Onda A (A7)
