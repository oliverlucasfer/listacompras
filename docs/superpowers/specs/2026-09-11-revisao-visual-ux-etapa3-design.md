# Spec — Redesign de Navegação (Etapa 3 / Fase 10)

> Navegação: [← Spec do programa](2026-09-11-revisao-visual-ux-design.md) · [05 App Flutter](../../05-app-flutter.md) · [10 Wireframes](../../10-wireframes-telas.md) · [14 Tarefas](../../14-tarefas.md)

Data: 2026-09-11 · Status: aprovada

## 1. Objetivo

Dar ao app uma navegação de primeira classe com **NavigationBar inferior** (M3), separando **Minhas Listas** (que o usuário é dono) de **Compartilhadas** (onde é membro) e **Configurações**, e limpando as AppBars. Em telas largas (Web/desktop) a barra vira **NavigationRail**. Muda comportamento → dono do comportamento é o doc 05; wireframes no 10.

## 2. Decisões (2026-09-11)

| Decisão | Escolha | Justificativa |
| :--- | :--- | :--- |
| Modelo de navegação | `NavigationBar` inferior com 3 destinos | Padrão M3; separa listas próprias de compartilhadas (F7) |
| Destinos | **Minhas Listas**, **Compartilhadas**, **Configurações** | Aproveita colaboração; Configurações deixa de ser ícone |
| Adaptação por largura | `NavigationRail` a partir de ~600dp | Web/desktop usam a largura |
| Split de listas | `lista.donoId == usuarioId` → Minhas; `!=` → Compartilhadas | `donoAtualIdProvider` já existe; sem consulta extra |
| Logout | move para Configurações | Tira do AppBar; ação destrutiva em lugar próprio |
| "Entrar com código" | move para a tela **Compartilhadas** | Contexto de compartilhamento |
| AppBar | limpa (sem configurações/sair/person_add no painel) | Menos ruído; navegação fica na barra |

> **Nota (F10-T06, 2026-09-11):** o destino "Ajustes" passou a se chamar **Configurações** (igual ao AppBar) e a abertura de `/lista` e `/membros` deixou de ser `go` para ser **`push` sobre o shell** (tela cheia, voltar para a aba de origem; sem pilha, fallback para `/listas`/`/compartilhadas`). Ver [`2026-09-11-navegacao-titulos-design.md`](2026-09-11-navegacao-titulos-design.md).

## 3. Rotas (go_router)

- `StatefulShellRoute.indexedStack` com 3 branches:
  - `/listas` → `MinhasListasScreen`
  - `/compartilhadas` → `CompartilhadasScreen`
  - `/configuracoes` → `ConfiguracoesScreen`
- Fora do shell (tela cheia): `/lista/:id`, `/membros/:id`, `/entrar` e as rotas de auth.
- Redirect: `/compartilhadas` protegida (como `/listas`); `publica` inalterada.
- O shell preserva o estado de cada aba (indexedStack).

## 4. Telas

- **PainelListas** (novo widget reutilizável) parametrizado por `FiltroListas { minhas, compartilhadas }`:
  - filtra `listasComContagemProvider` por `donoId` vs `donoAtualIdProvider`;
  - AppBar com título próprio; em Compartilhadas, ação "Entrar com código";
  - FAB "Nova lista" só em Minhas;
  - estados vazio/erro próprios (`AppEstadoVazio`/`AppEstadoErro`);
  - `_CardLista`: long-press → renomear/excluir quando **dono**; navegar a membros quando **compartilhada** (para "Sair da lista").
- **MinhasListasScreen** e **CompartilhadasScreen**: wrappers finos do `PainelListas`.
- **Configurações**: ganha "Sair" (logout); AppBar sem ícone de engrenagem (é aba).
- **AppShell** (`lib/core/navigation/app_shell.dart`): `NavigationBar`/`NavigationRail` + `navigationShell`.

## 5. Strings novas

`compartilhadas`, `nenhumaCompartilhada`, `nenhumaCompartilhadaDica`, `entrarComCodigo` (reusa `conviteComCodigo`).

## 6. Testes

- `minhas_listas_screen_test`: passa a sobrescrever `donoAtualIdProvider` (`'user-a'`); mantém as demais asserções; testes de "entrar com código" migram.
- Novo `compartilhadas_screen_test`: lista de outro dono aparece em Compartilhadas; vazio; entrar com código.
- `configuracoes`: teste do "Sair" (opcional).
- CI verde (`format`/`analyze`/`test`).

## 7. Critério de pronto

Navegação inferior funcional com os 3 destinos e estado preservado; logout em Configurações; "entrar com código" em Compartilhadas; AppBars limpas; testes e docs atualizados; Fase 10 marcada em `14-tarefas.md`.
