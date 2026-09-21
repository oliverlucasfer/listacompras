# 10 — Wireframes das Telas

> Navegação: [← 09 Runbook](09-runbook-operacoes.md) · [11 Usabilidade →](11-usabilidade-fase5.md)

**Este documento é o dono do LAYOUT (visual/posição).** O comportamento de cada tela vive em [05 §6](05-app-flutter.md); os estados de sync em [03 §6](03-sincronizacao-offline.md). Wireframes em ASCII — referência para implementação e para os testes de usabilidade de [11](11-usabilidade-fase5.md).

Convenções: `[ ]` campo de texto · `( )` botão · `(x)` marcado · `[≡]` ícone · `▼/▸` seção aberta/fechada · `(...)` anotação de comportamento.

**Convenções visuais:** espaçamento, raios, cores e tipografia vêm dos tokens do [doc 15](15-design-system.md) — os wireframes são ASCII e não fixam valores visuais. Banners/estados usam `AppBanner`/`AppEstadoVazio`/`AppEstadoErro` do doc 15.

---

## 1. Autenticação

### 1.1. Login
```
┌─────────────────────────────────┐
│                                 │
│           🛒 Logo               │
│     Lista de Compras            │
│                                 │
│  E-mail                         │
│  [________________________ ]    │
│                                 │
│  Senha                          │
│  [____________________ (👁) ]   │
│                                 │
│  (        Entrar          )     │ ← spinner no botão ao carregar
│                                 │
│  (     Criar minha conta   )    │
│  Esqueci minha senha (link)     │
│                                 │
└─────────────────────────────────┘
   (erro: mensagem inline em vermelho sob o campo correspondente)
```

### 1.2. Registro / Recuperar senha
```
┌─────────────────────────────────┐   ┌─────────────────────────────────┐
│  ← Criar conta                  │   │  ← Recuperar senha              │
│                                 │   │                                 │
│  E-mail                         │   │  Informe seu e-mail:            │
│  [________________________ ]    │   │  [________________________ ]    │
│  Senha                          │   │                                 │
│  [________________________ ]    │   │  (  Enviar link por e-mail  )   │
│  Confirmar senha                │   │                                 │
│  [________________________ ]    │   │  (link único, expira — Supabase)│
│                                 │   └─────────────────────────────────┘
│  ☐ Li a Política de Privacidade │
│  (ver política)                 │
│  (     Criar conta        )     │   Após registro: tela "Verifique
│                                 │   seu e-mail" (reenviar link).
└─────────────────────────────────┘
```

### 1.3. Definir nova senha (link de recuperação — F14-T03)
```
┌─────────────────────────────────┐
│  ← Definir nova senha           │
│                                 │
│  Nova senha                     │
│  [____________________ (👁) ]   │
│                                 │
│  Confirmar nova senha           │
│  [____________________ (👁) ]   │
│                                 │
│  (     Salvar nova senha    )   │
└─────────────────────────────────┘
   (sucesso → SnackBar "Senha alterada" e volta às listas;
    link expirado → erro amigável + "Pedir novo link")
```

---

## 2. Minhas Listas

**Navegação (F10):** barra inferior (NavigationBar) com **Minhas**, **Compartilhadas** e **Configurações**; em telas largas vira NavigationRail. O painel abaixo é **Minhas Listas** (listas em que você é dono). A aba **Compartilhadas** usa o mesmo layout, **sem FAB** e com a ação "Entrar com código" no AppBar (o menu `⋮` do card abre Membros e Sair da lista; o long-press abre o mesmo menu). Abrir uma lista/membros é `push` sobre o shell: a tela é cheia (barra some) e o voltar retorna à aba de origem (doc [05 §4](../05-app-flutter.md)).

**Busca (F16):** lupa na AppBar revela um campo no topo do corpo (rótulo "Buscar lista", hint de exemplo "Nome da lista"); campo com rótulo acessível (label) e hint de exemplo; a lista filtrada esconde os cards que não casam; sem resultado → vazio "Nenhuma lista encontrada".

### 2.1. Estado preenchido
```
┌─────────────────────────────────┐
│  [▣] Minhas Listas       [≡]    │ ← [▣] marca do app (F13-T02)
│  ● Sincronizado            (1)  │ ← [03 §6] sincronizado/pendente/offline
├─────────────────────────────────┤
│  ┌───────────────────────────┐  │
│  │ Compras da Semana      [⋮] │  │ ← [⋮] (F14-T06): renomear/excluir
│  │ 3/10 itens concluídos     │  │   (Compartilhadas: membros/sair);
│  │ atualizada há 5 min       │  │   long-press abre o mesmo menu
│  └───────────────────────────┘  │
│  ┌───────────────────────────┐  │
│  │ Churrasco Sábado       [⋮] │  │
│  │ 0/6 itens concluídos      │  │
│  │ ontem                     │  │
│  └───────────────────────────┘  │
│                                 │
│                      (＋ Nova)  │ ← FAB
└─────────────────────────────────┘
```
Os cards são separados verticalmente por **`AppSpacing.sm`** (8px); o `cardTheme` zera a margem do `Card`, então o espaçamento entre cards empilhados é responsabilidade do layout da lista (`ListView.separated`, F12-T05).

**Marca no cabeçalho (F13-T02):** as telas de **topo** (Minhas Listas / Compartilhadas, sem botão voltar) mostram a marca do app (`AppLogo`, 28dp) à esquerda do título; telas internas (`push`: lista, membros, configurações, auth) mantêm apenas o texto. Título de tela em **24sp bold** (F13-T03, doc [15 §1](15-design-system.md)).

### 2.2. Estado vazio
```
┌─────────────────────────────────┐
│  Minhas Listas                  │
├─────────────────────────────────┤
│                                 │
│           📝                    │
│   Nenhuma lista por aqui        │
│                                 │
│   Crie sua primeira lista ou    │
│   importe por texto.            │
│                                 │
│   (  ＋ Criar primeira lista )  │
│                                 │
└─────────────────────────────────┘
```

### 2.3. Sheet "Nova lista"
```
┌─────────────────────────────────┐
│  Nova lista                  ✕  │
├─────────────────────────────────┤
│  Nome da lista                  │
│  [________________________ ]    │
│                                 │
│  (       Criar lista      )     │ ← salva local + fila [03 §4]
└─────────────────────────────────┘
```

### 2.4. Convites pendentes (Fase 6 — [08 §7](08-compartilhamento-colaborativo.md))
```
┌─────────────────────────────────┐
│  Minhas Listas                  │
├─────────────────────────────────┤
│  ── Convites pendentes ──       │
│  ┌───────────────────────────┐  │
│  │ João convidou você para   │  │
│  │ "Compras da Semana"       │  │
│  │ (Aceitar)   (Recusar)     │  │
│  └───────────────────────────┘  │
│  ── Minhas listas ──            │
│  ...                            │
└─────────────────────────────────┘
```

### 2.5. Sheet "Comprar de novo" (F23/RF-20)

**Entrada:** item "Comprar de novo" no menu `⋮` do card (dono e membro), **só quando há pendentes** (doc 10 §2.1).

```
┌─────────────────────────────────┐
│  Comprar de novo             ✕  │
├─────────────────────────────────┤
│  3 itens pendentes serão        │
│  copiados.                      │
│                                 │
│  Nome da lista                  │
│  [ Compras da Semana         ]  │ ← pré-preenchido, editável
│                                 │
│  (       Criar lista      )     │ ← cria + abre a lista nova (RF-20)
└─────────────────────────────────┘
```

---

## 3. Tela da Lista de Compras

**Navegação (F10):** abre em tela cheia por cima da barra de abas, com seta de voltar (retorna à aba de origem); o AppBar mostra o título da lista (fallback "Lista" em carregando/erro/não encontrada). A tela de **Membros** usa `Membros · {título}` no AppBar.

### 3.1. Uso normal (Fase 6: agrupamento por categoria, RF-15)
```
┌─────────────────────────────────┐
│  ← Compras da Semana      [⋮]   │ ← [⋮]: desmarcar todos, limpar
│  ● Sincronizado                 │    concluídos, renomear, excluir lista
├─────────────────────────────────┤
│  [Café] [Pão] [Leite] ...       │ ← chips de itens frequentes (RF-19),
│                                 │    só com o campo vazio; toque adiciona
│  Adicionar item                 │
│  [____________ un▾   (＋) ]     │ ← Enter salva já categorizado (§3 05);
│                                 │    reconhece "1kg de banana" e a
│                                 │    unidade vem do seletor (F12-T06)
│                                 │
│  HORTIFRÚTI (1)                 │ ← ordem dos grupos = ordem do enum
│  ☐ Banana           1 dz    ≡   │    [01 §3.2]; contagem de pendentes
│  MERCEARIA (2)                  │
│  ☐ Arroz            1 kg    ≡   │ ← tocar: editar; swipe ←/→:
│  ☐ Café             1 pacote ≡  │    editar/remover (undo);
│  LATICÍNIOS (2)                 │    drag restrito ao grupo
│  ☐ Leite            2 un    ≡   │ ← editar: dropdown de categoria
│  ☐ Queijo prato     500 g   ≡   │
│                                 │
│  ▼ Itens Concluídos (3)         │ ← seção única, sem categorias
│    ☑ Detergente     2 un        │
│    ☑ Macarrão       500 g       │ ← desmarcar devolve ao seu grupo
│                                 │
│  (Importar lista)               │
└─────────────────────────────────┘
```

**Busca (F16):** lupa na AppBar revela um campo (rótulo "Buscar item", hint de exemplo "Nome do item"); campo com rótulo acessível (label) e hint de exemplo; os grupos de categoria permanecem (vazios somem) e o drag fica desabilitado; sem resultado → vazio "Nenhum item encontrado" + "Limpar busca".

**Chips de itens frequentes (F22/RF-19):** faixa horizontal acima do campo "Adicionar item", exibida só quando o campo está vazio e há sugestões; toque adiciona o item (1 `un`, categoria pela cadeia local); o botão do modo mercado (`shopping_cart_checkout`) fica na AppBar, visível a dono/editor.

### 3.2. Estados do indicador de sync (AppBar, [03 §6](03-sincronizacao-offline.md))
```
● Sincronizado   ◌ Sincronizando   ● 3 pendentes   ○ Offline
                                                     │
   offline: banner discreto abaixo do AppBar ────────▼
┌─────────────────────────────────┐
│ ⚠ Sem conexão — alterações      │
│   serão sincronizadas depois    │
├─────────────────────────────────┤
```

### 3.3. Modo leitor (Fase 6, [08 §1](08-compartilhamento-colaborativo.md))
```
┌─────────────────────────────────┐
│  ← Compras da Semana      [⋮]   │
│  👁 Somente leitura              │
├─────────────────────────────────┤
│  ☐ Arroz            1 kg        │ ← sem steppers, sem swipe;
│  ☐ Leite            2 un        │    toques mostram dica
│                                 │    "Apenas o dono/editores editam"
└─────────────────────────────────┘
```
O aviso usa `AppBannerTipo.leitura` ([15 §3](15-design-system.md)), não um `Container` manual (F14-T08).

### 3.4. Diálogo "Excluir lista"
```
┌─────────────────────────────────┐
│  Excluir "Compras da Semana"?   │
│                                 │
│  Os 10 itens serão removidos    │
│  para todos os participantes.   │ ← texto muda se houver membros
│                                 │
│  (Cancelar)        (Excluir)    │ ← Excluir em vermelho
└─────────────────────────────────┘
```

O trecho "para todos os participantes" aparece quando há membros conhecidos (best-effort); o painel assume lista sem membros e a tela da lista usa o que estiver em cache de `membrosDaListaProvider` (F14-T08).

### 3.5. Modo mercado (F22/RF-18 — [05 §6.5](05-app-flutter.md))
```
┌─────────────────────────────────┐
│  ← Compras da Semana            │ ← sem menu/busca/drag/importação
│  ● Sincronizado                 │
├─────────────────────────────────┤
│  3 de 12                        │ ← marcados nesta sessão / total ativo
│                                 │    (live region)
│  ☐ Arroz            1 kg        │ ← lista generosa de pendentes;
│  ☐ Leite            2 un        │    toque na linha marca (alvo ≥48dp)
│  ☐ Café             1 pacote    │
│                                 │
│  ▼ Marcados (3)                 │ ← faixa recolhível = undo: toque
│    ☑ Banana         1 dz        │    desmarca e devolve aos pendentes
│    ☑ Queijo prato   500 g       │
└─────────────────────────────────┘
```
Com 0 pendentes, a área principal dá lugar ao vazio "Tudo comprado" com CTA para voltar à lista. A seta de voltar retorna à tela da lista (push); sem pilha (deep link), vai para `/listas`.

### 3.6. Chips de itens frequentes na lista (F22/RF-19)
Acima do campo de adicionar, uma faixa horizontal rolável de `ActionChip` (alvo ≥48dp, com `Semantics` de ação "Adicionar <nome>") mostra até 8 sugestões quando o campo está vazio; tocar adiciona o item. O ranking vem do histórico local do Drift (peso 2 para a lista aberta, exclui pendentes, limiar ≥2) — nenhum dado de rede.

### 3.7. Tela de Membros (RF-13/RF-14 — [05 §6.6](05-app-flutter.md))
AppBar `Membros · {título}`; cada membro mostra o UUID prefixado, o chip de papel e — para o dono, em membros que **não** são ele — o menu `⋮` (papel editor↔leitor, remover e **transferir dono**).

```
┌─────────────────────────────────┐
│  ← Membros · Compras da Semana  │
├─────────────────────────────────┤
│  d0a1b2c3 (Você)          dono  │
│  e4f5a6b7               editor ⋮│
│  a1b2c3d4               leitor ⋮│
└─────────────────────────────────┘
   (sem menu no próprio usuário; [⋮] só para o dono, alvo ≠ eu:
    Editor / Leitor / Transferir dono / Remover)
```

**Confirmação dupla do "Transferir dono" (F24/RF-14):**
```
┌─────────────────────────────────┐
│  Transferir dono?               │
│  Você deixará de ser dono e     │ ← 1º passo
│  passará a editor desta lista.  │
│  (Cancelar)        (Continuar)  │
└─────────────────────────────────┘
                ▼
┌─────────────────────────────────┐
│  Transferir dono?               │
│  Confirmar a transferência?     │ ← 2º passo
│  Depois disso você poderá sair  │
│  da lista.                      │
│  (Cancelar)   (Transferir dono) │
└─────────────────────────────────┘
   (sucesso → SnackBar "Dono transferido." e "Sair da lista" aparece;
    o novo dono recebe "Você agora é dono de uma lista" pelo Realtime)
```

---

## 4. Importação de lista (RF-16 — [04](04-importacao-lista.md))

### 4.1. Modal de entrada
```
┌─────────────────────────────────┐
│  Importar lista              ✕  │
├─────────────────────────────────┤
│  Cole ou digite sua lista:      │
│  ┌───────────────────────────┐  │
│  │ 1kg de arroz, 2 leites,   │ │
│  │ 500g de queijo prato...    │ │
│  │                           │ │
│  └───────────────────────────┘  │
│                       128/10000 │ ← contador ≤ 10.000; vermelho > limite
│                                 │
│  (     ✨ Extrair itens    )    │ ← sem rede; spinner + "Lendo..."
└─────────────────────────────────┘
   (erro → mensagem amigável do parser [04])
```

### 4.2. Modal de pré-visualização
```
┌─────────────────────────────────┐
│  Confirme os itens           ✕  │
├─────────────────────────────────┤
│  ⚠ "Interpretei 'pct' como      │ ← aviso do parser ([04])
│     pacote de café"             │
│                                 │
│  ☑ Arroz          1  kg         │ ← desmarcar = não incluir
│  ☑ Leite          2  un    ▾    │ ← ▾ abre edição inline
│      [1] [kg|...]  [Laticínios|…]│ ← categoria editável (F6-T05)
│  ☑ Queijo prato 500  g          │
│  ☐ Café           1  pct        │
│                                 │
│  3 de 4 serão adicionados       │
│  (Cancelar)   (Adicionar 3)     │
└─────────────────────────────────┘
```
Se a extração não reconhecer nada (0 itens), a lista dá lugar a um `AppEstadoVazio` — "Nada foi reconhecido" + dica de separar por vírgula/linha + "Voltar e editar" — e o botão de adicionar some (F14-T04).

---

## 5. Configurações (Fase 5 — [06 §3.3](06-mvp-entregas.md))
```
┌─────────────────────────────────┐
│  ← Configurações                │
├─────────────────────────────────┤
│  Aparência                      │
│  [ Claro | Sistema | Escuro ]   │ ← tema manual (doc 15)
│  Conta                          │
│  oliveira@exemplo.com           │
│  Sair                    (→)    │ ← logout (F10)
│                                 │
│  Sobre                          │
│  Política de Privacidade (link) │
│  Versão 1.0.0                   │
│                                 │
│  ──────────────────────────     │
│  ( Excluir minha conta )        │ ← vermelho; confirmação dupla
│    "Apaga TODAS as suas listas  │    (senha + diálogo); cascade [06 §3.3.1]
│     permanentemente."           │
└─────────────────────────────────┘
```

**Sair** pede confirmação destrutiva antes de encerrar a sessão (F14-T05).

---

## 6. Mapa de estados por tela (transversal)

| Tela | Carregando | Vazio | Erro | Offline |
| :--- | :--- | :--- | :--- | :--- |
| Minhas Listas | `AppEsqueleto` (F14-T09) | 2.2 | `AppEstadoErro` com retry | Banner global + lista local (usável) |
| Tela da Lista | `AppEsqueleto` (F14-T09) | 3.1 — vazio instrui por papel (F14-T04) | `AppEstadoErro` com retry (F14-T04) | 3.2 — funcional |
| Membros | `AppEsqueleto` (F14-T09) | `AppEstadoVazio` com orientação (F14-T04) | `AppEstadoErro` com retry | — |
| Importar lista | Botão com spinner | "Nada foi reconhecido" (4.2, F14-T04) | Mensagem amigável (4.1) | Botão desabilitado c/ dica |
| Login | Spinner no botão | — | Inline por campo | Banner |
| Redefinir senha | Spinner no botão | — | Erro + "Pedir novo link" (1.3) | — |

---

## Documentos relacionados
- [05 App Flutter](05-app-flutter.md) — comportamento e interações de cada tela
- [03 Sincronização](03-sincronizacao-offline.md) — estados do indicador de sync
- [08 Compartilhamento](08-compartilhamento-colaborativo.md) — telas de convite/membros
- [06 MVP & Entregas](06-mvp-entregas.md) — exclusão de conta nas Configurações
