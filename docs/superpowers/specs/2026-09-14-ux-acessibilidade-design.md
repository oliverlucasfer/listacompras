# Spec — Acessibilidade, Fluxos e Polimento de UX (Fase 14)

> Navegação: [← 12 PRD](../../12-prd.md) · [15 Design System](../../15-design-system.md) · [05 App Flutter](../../05-app-flutter.md) · [10 Wireframes](../../10-wireframes-telas.md) · [08 Compartilhamento](../../08-compartilhamento-colaborativo.md) · [14 Tarefas](../../14-tarefas.md)

Data: 2026-09-14 · Status: aprovada

## 1. Objetivo

Fechar as lacunas de UX/UI levantadas na auditoria pós-F13 (todas as telas de `lib/features/**/ui` + widgets `App*`), com quatro frentes:

1. **Conformidade com o RNF-06** ([12 §3](../../12-prd.md)) — acessibilidade hoje só nominal: **2 `semanticLabel` em todo o `lib/`** e nenhum teste de acessibilidade.
2. **Fluxos incompletos** — o mais grave: a recuperação de senha (RF-01) **não tem tela de nova senha**; `atualizarSenha` e as strings `definirNovaSenha`/`novaSenha` estão órfãs.
3. **Estados e feedback** — vazios/erros ausentes ou inconsistentes, ações silenciosas, validação invisível, gestos escondidos.
4. **Consistência** — cópias duplicadas, strings fora do `AppStrings`, widgets crus em vez dos `App*`, medidas fora dos tokens.

**Sem mudanças de schema, RLS ou contrato de IA.** Toda a fase é app + docs.

## 2. Contexto (auditoria de 2026-09-14)

Achados que motivam as tarefas (evidência no código atual):

| Achado | Onde |
| :--- | :--- |
| Só 2 `semanticLabel` no `lib/` | `app_logo.dart`, `tela_lista_screen.dart:610` |
| Nenhum teste de a11y (`meetsGuideline`/`textScaler` nunca usados) | `test/` |
| Recuperação de senha sem tela final; strings órfãs | `app_strings.dart:28-29`, `supabase_auth_repository.dart` |
| Tela de membros sem empty state (tela em branco) | `tela_membros_screen.dart:184` |
| Erro da lista sem retry (só texto), divergindo do resto | `tela_lista_screen.dart:165` |
| Sem "nada reconhecido" na pré-visualização com 0 itens | `modal_previsao_importacao.dart` |
| "Reenviar link" sem nenhum retorno visual | `registro_screen.dart:226` |
| Long-press como único caminho para renomear/excluir lista | `painel_listas.dart:150` |
| Swipe para editar/remover sem dica | `tela_lista_screen.dart:618` |
| Editor de item com rótulo errado ("Adicionar item") | `tela_lista_screen.dart:757` |
| Exclusão de lista com 2 cópias diferentes | `painel_listas.dart:235` vs `tela_lista_screen.dart:128-133` |
| `AppBannerTipo.leitura` existe e não é usado | `app_banner.dart` / `tela_lista_screen.dart:284` |
| Validação silenciosa (adicionar, editor, import) | `tela_lista_screen.dart:329,735`, `modal_previsao_importacao.dart:233` |
| Membros identificados por UUID truncado | `tela_membros_screen.dart:250` (fora de escopo — §11) |

## 3. Decisões (2026-09-14)

| Decisão | Escolha | Justificativa |
| :--- | :--- | :--- |
| Escopo | **4 frentes** (a11y, fluxos, estados/feedback, consistência) numa fase única | Mesmo doc dono (`15`/`05`/`10`); evita 4 ciclos de spec |
| Verificação da a11y | **Testes** (`meetsGuideline` + `textScaler`), não só inspeção | RNF-06 é requisito; sem teste ele regride |
| Recuperação de senha | Tratar `AuthChangeEvent.passwordRecovery` → rota pública `/redefinir-senha` | O `deepLink` do reset é o mesmo do cadastro (`login-callback`); hoje o usuário cai logado em `/listas` sem definir a senha |
| Affordance do card | `⋮` passa a ser o caminho principal; **long-press vira atalho** | Descobribilidade sem remover o gesto existente |
| Swipe dos itens | **Mantido como está** (sem onboarding) | Desde a F12-T06 tocar no item já abre o editor com "Remover" — há alternativa visível |
| Cópia de ações destrutivas | **Uma única** copy por ação, em `AppStrings` | Duas cópias divergem com o tempo |
| Skeletons | Placeholder **estático** (sem shimmer/pacote novo) | Ganho de percepção sem dependência nova nem animação a manter |
| Identificação de membros (nome/e-mail) | **Fora da fase** → Fase 15 | Exige RPC `security definer` + policy (docs 01/02) — mudança de segurança |
| Métricas de produto (modo mercado, busca) | **Fora da fase** → Fase 15 | Escopo novo, não lacuna |

## 4. Acessibilidade — RNF-06 (F14-T01, F14-T02)

Regras vinculantes (detalhe no [15 §4](../../15-design-system.md)):

- **Semântica:** `tooltip` em todo `IconButton`/`PopupMenuButton`; nada de rótulo inventado para ícones decorativos (o `Icon` do Flutter já os exclui quando sem `semanticLabel`); coleções (estado vazio/erro) com um rótulo coerente em vez de vários nós de texto.
- **Live regions:** `AppBanner` (erro/offline/aviso) e `IndicadorSync` são anunciados (`Semantics(liveRegion: true)`); o `SnackBar` já é uma live region por padrão no Flutter.
- **Controles:** o `Checkbox` de item tem rótulo = nome do item (`MergeSemantics`); os fundos do `Dismissible` só têm ícones decorativos, que o Flutter já exclui — sem mudança.
- **Alvos ≥ 48dp** e **contraste ≥ AA** (já garantidos por tema, agora verificados).
- **Escala de texto:** as telas-chave (login, painel, lista) não podem estourar com `textScaler` 1.3 e 2.0 — verificado com `textScaleFactor` 2.0 nos testes de tela (a exceção de overflow é capturada por `tester.takeException()`).

Componente a componente:

| Componente | Mudança |
| :--- | :--- |
| `AppEstadoVazio` | rótulo único = título + descrição (ícone decorativo fora da árvore); a ação fica em nó próprio |
| `AppEstadoErro` | **já conforme** — o `Icon` exclui a si mesmo e o retry já é rotulado; sem mudança |
| `AppBanner` | `liveRegion` em erro/aviso/offline (`info`/`leitura` ficam estáticos) |
| `mostrarSnackBar` | **já conforme** — o `SnackBar` do Flutter já é `liveRegion` (`snack_bar.dart`); sem mudança |
| `AppBotao(carregando)` | nó próprio (`container`) com `liveRegion` anunciando "Carregando…", sem poluir o rótulo do botão |
| `IndicadorSync` | `liveRegion` com o estado por extenso; ícones de 14dp → ≥16dp |
| Telas de auth | toggle de senha com rótulo acessível (o toggle nos dois campos do registro é a F14-T07) |

## 5. Recuperação de senha (F14-T03)

1. `resetPasswordForEmail` continua usando o `deepLink` (`...://login-callback`, já registrado no Android/iOS e nas redirect URLs do Supabase).
2. O app passa a reagir a `AuthChangeEvent.passwordRecovery` (via `onAuthStateChange`): um provider expõe o evento e o `redirect` do `go_router` manda o usuário para **`/redefinir-senha`** — rota **pública mesmo autenticado**, com a mesma exceção que `/entrar` já tem.
3. **`RedefinirSenhaScreen`** (mesmo padrão visual de `RegistroScreen`): "Nova senha" + "Confirmar senha" (ambos com toggle), validação de tamanho mínimo (6) e igualdade, botão com `carregando`, erro inline.
4. Sucesso → limpa o flag de recuperação, SnackBar "Senha alterada" e vai para `/listas`.
5. **Link inválido/expirado:** se o callback trouxer erro de auth, a tela mostra mensagem amigável + CTA "Pedir novo link" (→ `/recuperar-senha`), em vez de tela branca.
6. Strings `definirNovaSenha`/`novaSenha` (hoje órfãs) passam a ser usadas.

## 6. Estados vazios, de erro e transições (F14-T04)

| Tela | Comportamento novo |
| :--- | :--- |
| Membros (`tela_membros_screen.dart`) | lista vazia → `AppEstadoVazio` ("Nenhum participante ainda") **instruindo sobre perda de acesso, sem CTA** — o papel não é confiável quando o cache local está vazio (`membrosDaListaProvider` sempre mescla o dono; doc 08 §8) |
| Pré-visualização da importação | 0 itens → `AppEstadoVazio` ("Nada foi reconhecido") + dica (separar por vírgula/linha) + "Voltar e editar"; rodapé e botão de adicionar ocultos |
| Tela da lista | erro de carga → `AppEstadoErro` **com retry**; "Lista não encontrada" ganha CTA "Voltar para as listas" |
| Tela da lista (leitor) | **já conforme** — cópias distintas (`listaVazia`/`listaVaziaDica`) e sem CTA; sem mudança |
| `/entrar` | spinner sem AppBar vira estado de carga dentro do shell padrão; some a tela em branco do estado autenticado sem erro |

## 7. Feedback de ação (F14-T05)

| Ação | Hoje | Passa a |
| :--- | :--- | :--- |
| Reenviar link (registro) | silencioso | SnackBar "Link reenviado" / erro amigável |
| Compartilhar convite | silencioso | SnackBar "Link compartilhado" |
| Mudar papel de membro | silencioso | SnackBar "Papel atualizado" |
| Remover membro | só em erro | SnackBar "Membro removido" (confirmação destrutiva já existe) |
| Criar/renomear lista | silencioso | SnackBar curto "Lista criada"/"Lista renomeada" (2s) |
| Limpar concluídos | irreversível | mantém confirmação + **undo** (SnackBar 3s) que restaura os itens com `id`/`ordem` originais |
| Sair da conta | sem confirmação | `AppDialog.confirmarDestrutivo` |

`mostrarSnackBar` (2s/3s da F12-T07) é reusado. Critério para escolher: o SnackBar entra quando a ação não tem efeito **imediato sob o dedo** do usuário — criar/renomear lista confirma que a operação terminou depois que o sheet fecha (o card pode estar fora da viewport), enquanto **marcar/desmarcar item** fica de fora, pois a linha já reage visivelmente à interação e o aviso extra vira ruído.

## 8. Affordance e rótulos (F14-T06)

- **Card de lista:** `PopupMenuButton` (`⋮`) no card, com as ações do contexto — "Renomear"/"Excluir" (Minhas) e "Membros"/"Sair da lista" (Compartilhadas); o long-press passa a abrir o **mesmo** menu (atalho, não mais caminho único).
- **Editor de item:** o campo de nome usa o rótulo novo `nomeDoItem` ("Nome do item"), não mais "Adicionar item".
- **Sheet Convidar:** os dois botões ficam distintos — "Copiar link" (link completo) e "Copiar código" (token), com tooltip explicando o que cada um faz.
- Swipe dos itens: sem mudança (há alternativa por toque desde a F12-T06).

## 9. Validação visível (F14-T07)

- **Adicionar item:** texto vazio continua no-op; se o parser descartar **tudo** (ex.: só pontuação), mostrar erro curto ("Não entendi o item").
- **Editor de item:** erro inline (`AppCampoTexto.erro`) para nome vazio e quantidade inválida — hoje o salvar apenas retorna sem feedback.
- **Edição inline da importação:** mesma validação de nome/quantidade.
- **Registro:** toggle de mostrar/ocultar senha nos dois campos (paridade com o login).

## 10. Consistência (F14-T08)

- Exclusão de lista: **uma** copy (`AppStrings.excluirListaTitulo`/`excluirListaMensagem`, com o texto variando se houver membros — [10 §3.4](../../10-wireframes-telas.md)) usada no painel **e** na tela da lista; a cópia hardcoded da tela da lista é removida.
- Strings centralizadas: `tempo_relativo.dart` ("agora", "há X min", "ontem"), as de exclusão e os fallbacks `'—'`/`''` migram para `AppStrings` (ou são resolvidos).
- `AppBannerTipo.leitura` passa a ser usado no banner "Somente leitura" (hoje `Container` manual).
- `AppCampoTexto` ganha `maxLength`, `minLines`/`maxLines`, `textInputAction` e `readOnly`; os `TextField`/`DropdownButtonFormField` crus de `modal_importar.dart`, `modal_previsao_importacao.dart`, `sheet_convidar.dart` e `_DialogoEditarItem` passam a usá-lo.
- Medidas hardcoded (`bottom: 88`, `Divider(height: 32)`, `SizedBox(width: 40)`, ícones 64/72) migram para os tokens de `AppSpacing`/`AppRadius` onde houver token aplicável.

## 11. Skeletons e carregamento (F14-T09)

Placeholder **estático** (blocos com a cor de superfície do tema, sem animação e sem pacote novo) nas listas com maior chance de "piscar": painel de listas, itens da lista e membros. O spinner central continua permitido onde o conteúdo é pequeno (ex.: ações de botão).

## 12. Arquivos

**Criar**
- `lib/features/auth/ui/redefinir_senha_screen.dart`
- `lib/core/widgets/app_esqueleto.dart` (placeholder estático)
- Testes: `test/features/auth/redefinir_senha_screen_test.dart`, `test/core/widgets/acessibilidade_test.dart`, `test/core/widgets/app_esqueleto_test.dart`

**Modificar (app)**
- `lib/router.dart` (rota `/redefinir-senha` + exceção no redirect)
- `lib/features/auth/{data/supabase_auth_repository.dart,providers/*}` (evento `passwordRecovery`)
- `lib/core/l10n/app_strings.dart`, `lib/core/widgets/{app_estado_vazio,app_estado_erro,app_banner,app_snack_bar,app_botao,app_campo_texto}.dart`
- `lib/core/utils/tempo_relativo.dart`
- `lib/features/listas/ui/{painel_listas,tela_lista_screen,sheet_titulo_lista}.dart`
- `lib/features/importacao/ui/{modal_importar,modal_previsao_importacao}.dart`
- `lib/features/convites/ui/{sheet_convidar,tela_membros_screen,entrar_screen}.dart`
- `lib/features/{auth/ui/{registro_screen,recuperar_senha_screen},configuracoes/ui/configuracoes_screen,sync/ui/indicador_sync}.dart`

**Modificar (testes existentes)** — `minhas_listas_screen_test.dart`, `tela_lista_screen_test.dart`, `tela_membros_screen_test.dart`, `modal_previsao_importacao_test.dart`, `sheet_convidar_test.dart`, `registro_screen_test.dart`, `app_snack_bar_test.dart`, `design_system_screen.dart` (catálogo).

## 13. Strings novas

`nomeDoItem` ("Nome do item"), `naoEntendiItem` ("Não entendi o item"), `nadaReconhecido` ("Nada foi reconhecido"), `separarItensDica` ("Separe por vírgula ou linha"), `voltarEEditar`, `nenhumParticipante` ("Nenhum participante ainda"), `pedirNovoLink`, `senhaAlterada` ("Senha alterada"), `linkReenviado`, `linkCompartilhado`, `papelAtualizado`, `membroRemovido`, `listaCriada`, `listaRenomeada`, `copiarCodigo`.

## 14. Testes

- **A11y** (`acessibilidade_test.dart` + telas): `meetsGuideline(androidTapTargetGuideline)`, `labeledTapTargetGuideline` e `textContrastGuideline` nos componentes e nas telas-chave; `textScaler` 1.3 e 2.0 sem overflow.
- **Recuperação de senha:** widget tests dos estados (formulário, validação, erro, sucesso) com fake; unit do mapeamento do evento `passwordRecovery` → rota.
- **Estados:** empty/erro das telas alteradas (membros, lista, importação 0 itens).
- **Feedback/validação:** SnackBar e erro de campo em cada caso da §7/§9.
- Regressão: suíte existente (300 testes) verde.

## 15. Documentos donos

| Doc | Mudança |
| :--- | :--- |
| **15 §3/§4** | Regras de semântica/live region por componente; checklist de a11y verificável |
| **05 §4** | Rota `/redefinir-senha` (pública) e tratamento de `passwordRecovery` |
| **05 §6.1/6.2/6.3** | Fluxo de nova senha; feedback/validação/affordance por tela |
| **10** | 1.2 (nova senha), 2.1 (`⋮` no card), 3.1 (rótulo do editor), 3.3 (banner de leitura), 4.2 (vazio), §6 (mapa de estados) |
| **08 §5/§8** | Feedback de membros e do convite |
| **12** | Nota em RF-01 (tela de nova senha) + matriz de rastreabilidade (F14-T03) |
| **14** | Fase 14 completa + backlog da Fase 15 |
| **00 §6 / índice** | Fase 14 no cronograma |

## 16. Fora de escopo

- **Identificação de membros por nome/e-mail** — exige RPC `security definer` + policy nova (docs 01/02) e decisão de privacidade → Fase 15.
- **Novas features de produto**: modo mercado, busca/filtro, atalhos de itens frequentes, avatar, tema por lista → Fase 15.
- Schema, RLS, Realtime, contrato da Edge Function e enums (unidades/categorias) — **intocados**.
- iOS/Desktop, universal links, transferência de dono, convite por e-mail.
- Onboarding/dica explícita de swipe (há alternativa por toque).

## 17. Critério de pronto

Todas as tarefas F14-T00…T09 concluídas; `dart format` + `flutter analyze` + `flutter test` verdes; testes de acessibilidade presentes e passando; docs donos da §15 atualizados no mesmo PR; distribuição opcional aos testadores via F5-T05b.
