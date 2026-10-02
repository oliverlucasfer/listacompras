# 10 — Wireframes das Telas

> Navegação: [← 09 Runbook](09-runbook-operacoes.md) · [11 Usabilidade →](11-usabilidade-fase5.md)

**Este documento é o dono do LAYOUT (visual/posição).** O comportamento de cada tela vive em [05 §6](05-app-flutter.md). Wireframes em ASCII — referência para implementação e para os testes de usabilidade de [11](11-usabilidade-fase5.md). O app é **único e local** ("Minhas Listas"): sem telas de conta, convites, membros, compartilhamento ou indicador de sync.

Convenções: `[ ]` campo de texto · `( )` botão · `(x)` marcado · `[≡]` ícone · `▼/▸` seção aberta/fechada · `(...)` anotação de comportamento.

**Convenções visuais:** espaçamento, raios, cores e tipografia vêm dos tokens do [doc 15](15-design-system.md) — os wireframes são ASCII e não fixam valores visuais. Banners/estados usam `AppBanner`/`AppEstadoVazio`/`AppEstadoErro` do doc 15.

---

## 1. Boas-vindas

### 1.1. Boas-vindas (primeiro acesso — F31/RF-27)
```
┌─────────────────────────────────┐
│             🧺 Logo             │ ← identidade "Minhas Listas" (índigo)
│   Bem-vindo ao Minhas Listas    │
│   Organize suas compras, tudo   │
│   no seu aparelho.              │
│                                 │
│   ☁ Funciona offline            │ ← destaques (ícone + texto);
│     Suas listas ficam no        │   "Importe por texto" e
│     aparelho, sem conta.        │   "Dite um item" (só Android/iOS)
│   ➕ Importe por texto           │
│   🎤 Dite um item                │
│                                 │
│   (        Começar        )     │ ← grava a flag e vai p/ /listas
└─────────────────────────────────┘
```
   (página única, rolável; aparece **uma vez** no primeiro acesso,
    via flag local `onboarding_visto` — RF-27; sem "Pular";
    a saída é só pelo "Começar" — o voltar do sistema não marca visto,
    então a tela reabre no próximo cold start)

---

## 2. Minhas Listas

**Navegação (F10):** barra inferior (NavigationBar) com **2 destinos** — **Minhas** e **Configurações**; em telas largas vira NavigationRail. O painel abaixo é **Minhas Listas**. Abrir uma lista é `push` sobre o shell: a tela é cheia (barra some) e o voltar retorna à aba de origem (doc [05 §4](05-app-flutter.md)).

**Busca (F16):** lupa na AppBar revela um campo no topo do corpo (rótulo "Buscar lista", hint de exemplo "Nome da lista"); a lista filtrada esconde os cards que não casam; sem resultado → vazio "Nenhuma lista encontrada".

**Receber lista (RF-33):** a AppBar do painel ganha a ação `qr_code_scanner` ("Receber lista"), que abre `/receber-lista` por `push` (§7.2).

### 2.1. Estado preenchido
```
┌─────────────────────────────────┐
│  [▣] Minhas Listas   [▤] [≡]    │ ← [▣] marca do app (F13-T02)
│                                 │   [▤] "Mostrar arquivadas" (RF-22)
├─────────────────────────────────┤
│  ┌───────────────────────────┐  │
│  │ Compras da Semana      [⋮] │  │ ← [⋮] (F14-T06): renomear/excluir/
│  │ 3/10 itens concluídos     │  │   comprar de novo/arquivar;
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

**Tour — etapa 1 (RF-27/F46):** nesta tela (home de listas) ficam os spots `TourKeys` da etapa 1 — Fab "Nova lista" (`TourKeys.novaLista`), lupa (`TourKeys.lupa`), a aba **Histórico** (`TourKeys.abaHistorico`) e a aba Configurações (`TourKeys.abaConfiguracoes`), ambas na barra inferior/rail. Os recursos da tela da lista são da **etapa 2** (§3) e o tour da aba Histórico é a **etapa 3** (§8; [05 §6.11](05-app-flutter.md)).

**Marca no cabeçalho (F13-T02):** as telas de **topo** (Minhas Listas, sem botão voltar) mostram a marca do app (`AppLogo`, 28dp) à esquerda do título; telas internas (`push`: lista, configurações) mantêm apenas o texto. Título de tela em **24sp bold** (F13-T03, doc [15 §1](15-design-system.md)).

**Arquivar listas (RF-22, F26):** o card de uma lista arquivada exibe o chip **"Arquivada"** no subtítulo (só aparece com o toggle ligado, pois arquivadas ficam ocultas por padrão). O toggle `[▤]` "Mostrar arquivadas" fica na AppBar; o menu `⋮` mostra "Arquivar" (ativa) ou "Desarquivar" (arquivada visível) — comportamento em [05 §6.2](05-app-flutter.md).

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
│  (       Criar lista      )     │ ← salva local no Drift
└─────────────────────────────────┘
```
Tour (RF-27/F46): o campo de nome é o spot `TourKeys.nomeLista` do 1º passo da etapa 2; como o sheet precisa estar aberto, o passo é pulado se o alvo não estiver montado ([05 §6.11](05-app-flutter.md)).

### 2.4. Sheet "Comprar de novo" (F23/RF-20)

**Entrada:** item "Comprar de novo" no menu `⋮` do card, **só quando há pendentes** (doc 10 §2.1).

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

**Navegação (F10):** abre em tela cheia por cima da barra de abas, com seta de voltar (retorna à aba de origem); o AppBar mostra o título da lista (fallback "Lista" em carregando/erro/não encontrada).

### 3.1. Uso normal (agrupamento por categoria, RF-15)
```
┌─────────────────────────────────┐
│  ← Compras da Semana      [⋮]   │ ← [⋮]: desmarcar todos, limpar
│                                 │    concluídos, finalizar compra,
├─────────────────────────────────┤    renomear, adicionar de outra
│  🏬 Mercado A                    │ ← chip do mercado da última ida
│  [Café] [Pão] [Leite] ...       │    lista, orçamento, compartilhar,
│                                 │    arquivar, excluir
│                                 │    (chip da última ida; oculto
│                                 │     quando ela não tem mercado)
│                                 │
│  Adicionar item                 │ ← chips de itens frequentes (RF-19),
│  [____________ un▾   (＋) ]     │    só com o campo vazio; toque adiciona
│                                 │    reconhece "1kg de banana" e a
│                                 │    unidade vem do seletor (F12-T06)
│                                 │
│  HORTIFRÚTI (1)                 │ ← ordem dos grupos = ordem do enum
│  ☐ Banana           1 dz    ≡   │    contagem de pendentes
│  MERCEARIA (2)                  │
│  ☐ Arroz            1 kg    ≡   │ ← tocar: editar; swipe ←/→:
│  ☐ Café             1 pacote ≡  │    editar/remover (undo);
│  LATICÍNIOS (2)                 │    drag restrito ao grupo
│  ☐ Leite            2 un    ≡   │ ← editar: dropdown de categoria
│  ☐ Queijo prato     500 g   ≡   │    + campo Preço (R$) (RF-21/F25)
│                                 │
│  ▼ Itens Concluídos (3)         │ ← seção única, sem categorias
│    ☑ Detergente     2 un        │
│    ☑ Macarrão       500 g       │ ← desmarcar devolve ao seu grupo
│                                 │
│  No carrinho: R$ 17,47 · 1 sem  │ ← faixa do total (RF-21/F25):
│  preço                          │    soma itens marcados com preço;
│                                 │    oculta sem marcados; com
│                                 │    orçamento: "de R$ Y" + barra
│                                 │    progressiva (RF-28/RF-36):
│                                 │    ≥80% "aviso", >100% "acima"
│                                 │
│  ⚠ Acima do limite da categoria │ ← banner de categoria (RF-36/F53):
│    Mercearia                    │    só com limite definido+estouro
│  (Importar lista)               │
└─────────────────────────────────┘
```

**Estados do total do carrinho (RF-28/RF-36):** com orçamento, a faixa do total mostra **"de R$ Y"** + barra de progresso em três estados — **normal** (< 80%, cor padrão), **aviso** (≥ 80% e ≤ 100%, `colorScheme.tertiary`, ícone `notification_important_outlined`, "Perto do orçamento") e **acima** (> 100%, `colorScheme.error`, ícone `warning_amber_rounded`, "Acima do orçamento"). Sem orçamento, a faixa segue a linha simples "No carrinho" (RF-21). Sem itens marcados, some.

**Alerta por categoria (RF-36/F53):** abaixo do total, um `AppBanner` de aviso ("Acima do limite da categoria: <rótulos>") destaca as categorias cujo **subtotal marcado** excede o limite; fica **oculto** quando não há limite definido nem categoria estourada.

**Aviso ao cruzar (RF-36/F53):** ao marcar/desmarcar um item que faz o total **passar** do orçamento, um **SnackBar** ("Você passou do orçamento: R$ X") é mostrado **uma vez** por cruzamento — na tela da lista e no modo mercado (`§3.3`). Permanecer acima (marcar mais itens) **não** re-dispara. Em Android/iOS, o mesmo cruzamento emite uma **notificação local** do SO (§6.15 de [05](05-app-flutter.md)).

**Finalizar compra (RF-34/F50):** com ≥ 1 item concluído, o rodapé mostra o botão **"Finalizar compra"** (`shopping_bag_outlined`, acima de "Importar lista") e o menu `⋮` ganha o mesmo item; ambos abrem o fluxo de confirmação (§8.4). Sem concluídos, nem botão nem efeito.

**Busca (F16):** lupa na AppBar revela um campo (rótulo "Buscar item", hint de exemplo "Nome do item"); os grupos de categoria permanecem (vazios somem) e o drag fica desabilitado; sem resultado → vazio "Nenhum item encontrado" + "Limpar busca".

**Chips de itens frequentes (F22/RF-19):** faixa horizontal acima do campo "Adicionar item", exibida só quando o campo está vazio e há sugestões; toque adiciona o item (1 `un`, categoria pela cadeia local); o botão do modo mercado (`shopping_cart_checkout`) fica na AppBar.

**Estado vazio da lista (RF-27/F31):** sem itens, o `AppEstadoVazio` mostra "Nenhum item ainda" com a dica **"Adicione no campo acima ou importe uma lista."** (não cita voz, pois o microfone só existe em Android/iOS).

**Quantidades em fração (RF-25/F29):** a linha do item e o editor exibem a quantidade com glifos comuns (`½ kg`, `1½ un`, `1¼`); decimais longos são cortados para ≤ 3 casas. A entrada aceita `1/2`, `½`, `1½` e decimais no editor; a mista espaçada (`1 1/2`) é aceita na entrada rápida e na importação (parser).

**Adicionar por voz (RF-26/F30):** em Android/iOS, o campo "Adicionar item" ganha um ícone de **microfone** à direita que **preenche o campo** com o texto reconhecido on-device (pt-BR); o usuário confirma (Enter). Ouvindo, o ícone muda (`mic`/`mic_none`); indisponível/permissão negada → SnackBar; ao sair da tela o ditado é cancelado. Web/Desktop não mostram o microfone.

**Sufixo do campo de adicionar (G-39):** a área à direita (seletor de unidade + microfone + adicionar) é flexível — o rótulo da unidade cede largura (`Flexible`/elipse) antes de estourar quando a fonte é ampliada (2x) em telas estreitas.

**Carregando da lista (G-07):** enquanto `listaPorIdProvider` carrega, o corpo inteiro vira `AppEsqueleto` (doc [15 §3](15-design-system.md)) — sem spinner cru.

**Tour — etapa 2 (RF-27/F46):** dispara ao abrir a primeira lista com itens **pendentes**. Spots `TourKeys` na tela: campo do sheet de nome (`nomeLista`, 1º passo — pulado se o sheet não estiver aberto), campo "Adicionar item" (`campoAdicionar`), seletor de unidade (`seletorUnidade`), botão "Importar lista" (`botaoImportar`), checkbox/linha do item (`itemLista`), botão do modo mercado (`botaoMercado`) e menu `⋮` da lista (`menuMais`, passo **"Menu da lista"** — orçamento/compartilhar/finalizar/alertas). Passos sem alvo montado são pulados ([05 §6.11](05-app-flutter.md)).

**Sheet do item (F12-T06 + preço RF-21/F25 + última compra RF-29/F37):** aberto por `AppSheet.mostrar` (bottom sheet, [15 §3](15-design-system.md)), com os campos em blocos e rolagem própria; o teclado sobe o rodapé (`viewInsets`).
```
┌─────────────────────────────────┐
│  ▁▁▁▁ (arraste para baixo)      │ ← bottom sheet padrão
├─────────────────────────────────┤
│  Editar item                    │
│  Nome do item                   │
│  [Arroz_____________________ ]  │ ← erro inline se vazio
│  [ − ] [ 1 ]   |  Unidade ▾     │ ← bloco quantidade
│  [ Categoria ▾ |  Preço (R$)  ] │ ← bloco categoria + preço;
│                                 │    opcional; inválido → erro
│  Última compra: R$ 4,99 (12/09) │ ← histórico local por dispositivo
│  ↑ R$ 0,50                      │    (RF-29/F37); ↑/↓ só com a
│                                 │    mesma unidade
│  Por mercado                    │ ← último preço por mercado do item
│  Mercado A: R$ 4,99 (mais       │    + unidade atual (RF-35/F52);
│  barato)                        │    mais barato em destaque; oculto
│  Mercado B: R$ 5,49             │    quando não há histórico com mercado
│  (Remover) (Cancelar) (Salvar)  │ ← empilha quando não cabe
└─────────────────────────────────┘    (fonte ampliada ou tela estreita; RNF-06)
```

**Última compra (RF-29/F37):** abaixo do campo de preço, quando há histórico local para o nome, aparece "Última compra: R$ X (dd/mm)" e — se o preço atual existir **e** a unidade atual for a mesma do registro — a variação (`↑`/`↓ R$diferença` ou "Mesmo preço"); com unidade diferente ou sem preço atual, só a linha do último preço. O histórico é **local por dispositivo**.

**Preço por mercado (RF-35/F52):** abaixo da "Última compra", a linha "Por mercado" lista o **último preço de cada mercado** para o item **na mesma unidade** atual (do mais barato ao mais caro), com o mais barato em destaque ("mais barato"); fica **oculta** quando não há histórico com mercado. Os preços são **derivados das idas** — não há tabela de preços.

### 3.2. Diálogo "Excluir lista"
```
┌─────────────────────────────────┐
│  Excluir "Compras da Semana"?   │
│                                 │
│  Os 10 itens serão removidos    │
│  permanentemente.               │
│                                 │
│  (Cancelar)        (Excluir)    │ ← Excluir em vermelho
└─────────────────────────────────┘
```

### 3.3. Modo mercado (F22/RF-18 — [05 §6.5](05-app-flutter.md))
```
┌─────────────────────────────────┐
│  ← Compras da Semana            │ ← sem menu/busca/drag/importação
├─────────────────────────────────┤
│  3 de 12                        │ ← marcados nesta sessão / total ativo
│  No carrinho: R$ 15,98          │    (live region); faixa do total
│                                 │    (RF-21/F25) logo abaixo; com
│                                 │    orçamento: "de R$ Y" + barra
│                                 │    progressiva (RF-28/RF-36:
│                                 │    aviso ≥80%, acima >100%)
│  ☐ Arroz            1 kg        │ ← lista generosa de pendentes;
│  ☐ Leite            2 un        │    toque na linha marca (alvo ≥48dp)
│  ☐ Café             1 pacote    │
│                                 │
│  ▼ Marcados (3)                 │ ← faixa recolhível = undo: toque
│    ☑ Banana         1 dz        │    desmarca e devolve aos pendentes
│    ☑ Queijo prato   500 g       │
└─────────────────────────────────┘
```
Com 0 pendentes, a área principal dá lugar ao vazio "Tudo comprado" com CTA para voltar à lista. A seta de voltar retorna à tela da lista (push); sem pilha, vai para `/listas`. A faixa "Marcados" fica dentro de `SafeArea(top: false)`, sem encostar na área segura inferior (G-37).

### 3.4. Chips de itens frequentes na lista (F22/RF-19)
Acima do campo de adicionar, uma faixa horizontal rolável de `ActionChip` (alvo ≥48dp, com `Semantics` de ação "Adicionar <nome>") mostra até 8 sugestões quando o campo está vazio; tocar adiciona o item. O ranking vem do histórico local do Drift (peso 2 para a lista aberta, exclui pendentes, limiar ≥2) — nenhum dado de rede.

### 3.5. Modal "Adicionar de outra lista" (F27/RF-23 — [05 §6.3](05-app-flutter.md))
**Entrada:** item "Adicionar de outra lista" no menu `⋮` da tela da lista.

```
┌─────────────────────────────────┐
│  Adicionar de outra lista    ✕  │
├─────────────────────────────────┤
│  Lista de origem                │
│  [ Compras da Semana        ▾ ] │ ← todas menos a atual;
│                                 │   arquivadas rotuladas "Arquivada"
│  ( Selecionar todos )           │ ← TextButton (alterna marcar/desmarcar)
│  ☑ Arroz            1 kg        │ ← só pendentes (alvo ≥48dp)
│  ☐ Leite            2 un        │
│                                 │
│  (Cancelar)   ( Adicionar )     │ ← estático; desabilitado com 0
└─────────────────────────────────┘
   (confirma → adiciona com a dedup do app [05 §6.3], SnackBar com a
    contagem; preço não é copiado)
   (origem sem pendentes → "Nenhum item pendente nesta lista.")
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
│  [  📷 Foto  ]                  │ ← só onde há OCR (Android/iOS, RF-37);
│                                 │   lendo: "Lendo a foto..." + spinner
│  (     ✨ Extrair itens    )    │ ← sem rede; spinner + "Lendo..."
└─────────────────────────────────┘
   (erro → mensagem amigável do parser/OCR [04])
```
O conteúdo do modal é rolável (`SingleChildScrollView`), para caber com fonte ampliada e teclado abertos (G-38).

**Importar por foto (RF-37, F54 — [05 §6.16](05-app-flutter.md)):** o botão **"Foto"** (ícone câmera) só aparece quando `plataformaComOcr()` é verdadeiro (Android/iOS); Web/Desktop o ocultam. Ao tocar, abre a escolha da origem:

```
┌─────────────────────────────────┐
│  ─────                          │
│  📷  Tirar foto                 │
│  🖼️  Escolher da galeria        │
└─────────────────────────────────┘
```
O texto reconhecido **preenche o campo editável** (vazio → substitui; com conteúdo → acrescenta em nova linha) e o fluxo "Extrair itens" → pré-visualização (§4.2) segue igual. **Nenhum texto** na foto → aviso "Nenhum texto reconhecido na foto."; falha/cancelamento da câmera ou do OCR → aviso amigável; a **imagem não é armazenada**. 1 imagem por importação.

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

## 5. Configurações (RF-31 — [05 §6.7](05-app-flutter.md))
```
┌─────────────────────────────────┐
│  ← Configurações                │
├─────────────────────────────────┤
│  Aparência                      │
│  [ Claro | Sistema | Escuro ]   │ ← tema manual (doc 15)
│  Idioma                         │
│  [ Sistema | Português |        │ ← seletor de idioma (RF-39, F56)
│    English | Español ]          │   (dropdown em tela estreita)
│  Ordenar categorias      (→)    │ ← corredores; arrastar-e-soltar (RF-24)
│  Orçamento por categoria (→)    │ ← limites em R$ por categoria (RF-36)
│                                 │
│  Dados                          │
│  Backup: exportar / importar    │ ← .json local (RF-31)
│                                 │
│  Sobre                          │
│  Política de Privacidade (link) │
│  Ver tutorial            (→)    │
│  Versão 1.0.0                   │
└─────────────────────────────────┘
```

**Idioma (RF-39/F56):** a seção **"Idioma"** exibe o `SeletorIdioma` (Sistema/Português/English/Español) logo abaixo de **Aparência**; a escolha é persistida (`idioma_app`) e aplicada na hora, sem reiniciar ([05 §6.7/§6.18](05-app-flutter.md), [15 §2](15-design-system.md)).

**Tour (RF-27/F46):** a seção "Sobre" tem o item **"Ver tutorial"** (`context.l10n.tourAbrir`, ícone `school_outlined`): tocar reabre o tour ignorando as flags — **navega para a home de listas** e inicia a etapa 1 lá (os alvos montam no próximo frame). A etapa 2 segue o fluxo normal: volta a disparar sozinha ao abrir uma lista com itens pendentes, **enquanto a flag dela ainda for falsa** ([05 §6.11](05-app-flutter.md)).

### 5.1. Tela "Ordenar categorias" (RF-24, F28)
```
┌─────────────────────────────────┐
│  ← Ordenar categorias           │
├─────────────────────────────────┤
│  Arraste para a ordem dos       │
│  corredores do seu mercado.     │
│  ( Restaurar padrão )           │ ← volta à ordem do enum (confirma)
│  ⠿ Hortifrúti                   │
│  ⠿ Mercearia                    │
│  ⠿ Frios                        │
│  …                              │ ← as 11 categorias, alça ≥48dp
└─────────────────────────────────┘
```

* Cada reordenação persiste na hora (preferência local, global); sem rede/schema.

### 5.2. Tela "Orçamento por categoria" (RF-36, F53)
```
┌─────────────────────────────────┐
│  ← Orçamento por categoria      │
├─────────────────────────────────┤
│  Hortifrúti                     │ ← uma linha por categoria
│  Limite (R$)                    │    (as 11 do enum)
│  [R$ 120,00_____________ ]      │ ← campo em R$; vazio = sem limite
│  (Limpar)              (Salvar) │ ← "Limpar" só com limite definido
│                                 │
│  Mercearia                      │
│  Limite (R$)                    │
│  [_________________________ ]   │ ← inválido → erro inline
│                        (Salvar) │
│  …                              │
└─────────────────────────────────┘
```
Cada limite é salvo na hora (`LimitesCategoriaRepository`, Drift `orcamento_categoria`) e alimenta o alerta da tela da lista (§3.1). Rota `/orcamento-categorias`, fora do shell, acionada em Configurações.

---

## 6. Mapa de estados por tela (transversal)

| Tela | Carregando | Vazio | Erro |
| :--- | :--- | :--- | :--- |
| Minhas Listas | `AppEsqueleto` (F14-T09) | 2.2 | `AppEstadoErro` com retry |
| Tela da Lista | `AppEsqueleto` (F14-T09) | 3.1 — vazio com caminhos (RF-27/F31) | `AppEstadoErro` com retry (F14-T04) |
| Importar lista | Botão com spinner | "Nada foi reconhecido" (4.2, F14-T04) | Mensagem amigável (4.1) |
| Receber lista (7.2) | `AppBotao(carregando: true)` | — | Banner "Código ou arquivo inválido." |
| Histórico (8.1) | `AppEsqueleto` (4 linhas) | 8.2 — "Nenhuma compra finalizada ainda." | `AppEstadoErro` com retry |
| Detalhe da ida (8.3) | `AppEsqueleto` (4 linhas) | "Compra não encontrada." | `AppEstadoErro` com retry |
| Orçamento por categoria (5.2) | `AppEsqueleto` (6 linhas) | — | — |

---

## 7. Compartilhar lista (RF-33 — [05 §6.12](05-app-flutter.md))

Comportamento em [05 §6.12](05-app-flutter.md). Duas peças: o **sheet "Compartilhar"** (aberto pelo menu `⋮` da lista, §3.1) e a tela **"Receber lista"** (rota `/receber-lista`, fora do shell, acionada no painel §2).

### 7.1. Sheet "Compartilhar"
```
┌─────────────────────────────────┐
│  Compras da Semana              │ ← título da lista (cabeçalho)
├─────────────────────────────────┤
│  💬 Enviar como texto           │ ← share_plus (texto legível, RF-16)
│  📄 Enviar arquivo              │ ← .json via XFile.fromData
│  ▦  QR code                     │ ← gera o QR (qr_flutter)
└─────────────────────────────────┘
   (indisponível → SnackBar; demais falhas → genérica)

Toque em "QR code" → sub-sheet com o código ML1:…:
┌─────────────────────────────────┐
│            █ ▄▄ █ ▄ █           │ ← QrImageView (codificarLista)
│            █▄▀▄▀▄█ ▀█           │   só se couber em 2000 bytes;
│            █ ▀██ ██ ▄           │   acima → aviso "Lista grande -
│                                 │   use texto ou arquivo." e nada abre
│  ( ⧉ Copiar código )            │ ← ML1:… p/ área de transferência
└─────────────────────────────────┘
   (copia → SnackBar "Código copiado.")
```

### 7.2. Tela "Receber lista"
```
┌─────────────────────────────────┐
│  ← Receber lista                │ ← fora do shell (push)
├─────────────────────────────────┤
│  Cole o código ou o texto da    │
│  lista                          │
│  ┌───────────────────────────┐  │ ← campo único auto-detecta:
│  │                           │  │    "ML1:" → código; "{"
│  │                           │  │    → JSON de arquivo; senão
│  └───────────────────────────┘  │    texto livre (parser RF-16)
│  ⚠ Código ou arquivo inválido.  │ ← Banner de erro (quando houver)
│                                 │
│  (       Continuar       )      │ ← lê a entrada e abre a prévia
│  (   Escolher arquivo   )       │ ← file_selector (.json)
│  (     Escanear QR      )       │ ← só Android/iOS
└─────────────────────────────────┘    (plataformaComCamera)
   (texto livre → parser local RF-16 + sugestão de categoria local)
   (Escanear QR → preenche o campo com o código lido e continua)

Toque em "Continuar" → pré-visualização editável (modal, §7.2):
┌─────────────────────────────────┐
│  Confirme os itens           ✕  │ ← fechar = cancelar
├─────────────────────────────────┤
│  Nome da lista                  │
│  ┌───────────────────────────┐  │ ← título editável (payload no
│  │ Lista compartilhada       │  │    código/arquivo; padrão no texto)
│  └───────────────────────────┘  │
│  ☑ Arroz                2 kg    │ ← incluir/excluir (todos marcados)
│  ☑ Leite                1 un    │
│  (   Cancelar ) (  Criar lista )│ ← só "Criar lista" grava
└─────────────────────────────────┘
   (confirmar SEMPRE cria uma lista nova com UUIDs v4 novos e navega
     para /lista/<novoId>; título vazio ou nenhum item marcado → desabilitado)

---

## 8. Histórico de compras (RF-34 — [05 §6.13](05-app-flutter.md))

Comportamento em [05 §6.13](05-app-flutter.md). A aba **Histórico** fica no shell entre "Minhas Listas" e "Configurações" e tem **duas abas internas: "Idas" | "Estatísticas"** (§8.1/§8.5); o detalhe e o fluxo de finalizar vivem fora/na tela da lista. A Fase 50 (RF-34) entrega o registro de idas + histórico; a Fase 51 entrega as estatísticas (gráficos `fl_chart`); a Fase 52 (RF-35) acrescenta o **mercado** na ida e as visões de preço/gasto por mercado (§6.14).

### 8.1. Aba "Histórico" (resumo + lista)
```
┌─────────────────────────────────┐
│  Histórico                      │ ← aba do shell (3 destinos:
├─────────────────────────────────┤    Minhas · Histórico · Config.)
│  Total gasto  Ticket médio  Idas│ ← resumo (resumoHistoricoProvider)
│  R$ 128,90    R$ 42,97      3   │
│ ─────────────────────────────── │
│  Compras da Semana              │ ← lista por finalizada_em desc:
│  30/09/2026 · 5 itens   R$ 62,40│    data · N itens · total
│  Churrasco Sábado               │    (toque abre o detalhe, §8.3)
│  21/09/2026 · 3 itens   R$ 44,10│
└─────────────────────────────────┘
```
**Tour — etapa 3 (RF-27/F57):** dispara ao **abrir a aba Histórico** (sem navegação forçada), uma vez, se `tour_etapa3_visto` ainda for falsa — roda mesmo com histórico vazio (`_Resumo` e o `TabBar` sempre montam). O 1º passo aponta o **resumo** (`TourKeys.resumoHistorico`) e o 2º a aba **Estatísticas** (`TourKeys.abaEstatisticas`). Detalhes em [05 §6.11](05-app-flutter.md).

### 8.2. Aba "Histórico" (vazio)
```
┌─────────────────────────────────┐
│  Histórico                      │
├─────────────────────────────────┤
│  Total gasto  Ticket médio  Idas│
│  —            —             0   │
│                                 │
│          ( ícone history )      │ ← AppEstadoVazio explicativo
│   Nenhuma compra finalizada     │
│   ainda.                        │
│   Marque itens e use "Finalizar │
│   compra" para registrar uma    │
│   ida.                          │
└─────────────────────────────────┘
```
Sem idas, o resumo mostra "—" (sem valor) e o vazio orienta como registrar a primeira ida.

### 8.3. Detalhe da ida (`/historico/ida/:idaId`)
```
┌─────────────────────────────────┐
│  ← Compras da Semana            │ ← título = snapshot da ida
├─────────────────────────────────┤
│  Arroz                          │ ← itens (snapshot): nome,
│  2 kg · Mercearia       R$ 10,98│    "quantidade unidade" · categoria
│  Leite                          │    e preço (ou "—" sem preço)
│  2 un · Laticínios      R$ 9,80 │
│  Detergente                     │
│  1 un · Limpeza         —       │
├─────────────────────────────────┤
│  Total gasto        R$ 20,78    │ ← rodapé (SafeArea)
└─────────────────────────────────┘
```
Lista por nome; ida inexistente → vazio "Compra não encontrada."; erro → `AppEstadoErro` com retry.

### 8.4. Fluxo "Finalizar compra" (RF-34; mercado RF-35)
Acionado pelo menu `⋮` ou pelo botão no rodapé da lista (§3.1), só com ≥ 1 item concluído.

```
┌─────────────────────────────────┐
│  Finalizar esta compra?         │ ← confirmação
│                                 │
│  3 itens · R$ 62,40 · 1 sem     │ ← resumo (N itens · total · M
│  preço                          │    sem preço; RF-21)
│  Mercado (opcional)             │ ← campo opcional (RF-35/F52)
│  [________________________ ]    │
│  [Mercado A] [Mercado B]        │ ← chips dos mercados já usados
│  (Cancelar)  (Finalizar compra) │    (mercadosUsados); vazio → sem mercado
└─────────────────────────────────┘
        │ confirma → grava a ida (transação; snapshot dos concluídos)
        ▼
┌─────────────────────────────────┐
│  Compra registrada no histórico.│ ← diálogo pós-finalizar (o SnackBar
│                                 │    já avisou o registro)
│  (Manter a lista) (Limpar       │ ← manter = não mexe na lista;
│                    concluídos)  │    limpar = remove os concluídos
└─────────────────────────────────┘
```
Nada é removido sem a escolha "Limpar concluídos" (reusa `limparConcluidos`); não há "undo" após finalizar.

### 8.5. Aba "Estatísticas" (RF-34, F51; mercado RF-35)
```
┌─────────────────────────────────┐
│  Histórico                      │ ← mesma tela da §8.1
│  Total gasto  Ticket    Idas    │ ← resumo (acima do TabBar,
│  R$ 120,00    R$ 40,00  3       │    visível nas duas abas)
│  [ Idas ] [ Estatísticas ]      │ ← TabBar (F51); aba ativa
├─────────────────────────────────┤
│  Gasto por período              │ ← GraficoGastoMensal (fl_chart):
│  ▁ ▃ ▂ ▅ ▄ ▆ ▃ ▇ ▅ █ ▆ ▅        │    barras dos últimos 12 meses
│  10/25      …        09/26      │    (MM/yy no eixo X)
│  Total no período: R$ 120,00    │    total dos meses exibidos
│ ─────────────────────────────── │
│  Gasto por categoria            │ ← lista: categoria · total · %
│  Mercearia          R$ 68,40 61%│
│  Frios              R$ 30,10 27%│
│  Limpeza            R$ 13,20 12%│
│ ─────────────────────────────── │
│  Gasto por mercado              │ ← soma por mercado (RF-35/F52);
│  Mercado A          R$ 88,40    │    inclui o grupo "Sem mercado";
│  Sem mercado        R$ 31,60    │    maior → menor
│ ─────────────────────────────── │
│  Itens mais comprados           │ ← top 10 (nome normalizado)
│  [ Frequência ] [ Gasto ]       │ ← ordena por frequência ou gasto
│  Arroz              5x   R$ 24,50│   frequência · gasto
│  Leite              4x   R$ 19,60│
│ ─────────────────────────────── │
│  Evolução de preço              │ ← seletor de item (dropdown)
│  [ Arroz                    ▾ ] │
│   ╭─────────────────────────╮   │ ← mini gráfico de linha
│   │      ╱‾╲    ╱            │   │   (≥ 2 pontos; fl_chart)
│   ╰─────────────────────────╯   │
│  21/08/2026 · R$ 5,00           │ ← lista dd/MM/yyyy · R$
│  30/09/2026 · R$ 6,10           │
└─────────────────────────────────┘
```
Cada seção tem estado vazio próprio ("Sem dados ainda.") e usa `AppEsqueleto`/`AppEstadoErro` no carregamento/erro. O **total do período** soma os meses exibidos; a barra mais alta recebe o rótulo `formatarReais` (as demais usam o tooltip de toque). A **evolução** compara **só a mesma unidade** (regra do RF-29): o item é escolhido pelo nome e a unidade vem da compra **com preço** mais recente; item sem compras comparáveis → vazio. Os gráficos expõem um **rótulo de acessibilidade** resumido (RNF-06).

---

## 9. Widget de tela inicial (RF-38 — [05 §6.17](05-app-flutter.md))

Comportamento em [05 §6.17](05-app-flutter.md). É um **AppWidget nativo do Android** (RemoteViews, fora da árvore Flutter) — não é uma tela do app; o toque no card e o botão **"Adicionar item"** abrem a rota `/adicionar`, que resolve a última lista e abre a tela da lista com o campo focado. Cores da identidade em [15 §3/§6](15-design-system.md); setup nativo e smoke em device em [09 §2.15](09-runbook-operacoes.md).

### 9.1. Com lista (última lista + pendentes)
```
┌───────────────────────────┐  ← card do widget na tela inicial (min 180×110dp,
│ Minhas Listas             │     cantos 16dp, fundo neutro; §15)
│ Compras da Semana         │  ← título da última lista aberta
│ 3 pendentes               │  ← plural: "1 pendente" / "N pendentes"
│ (     Adicionar item    ) │  ← botão índigo
└───────────────────────────┘
   (o card inteiro e o botão abrem o app em /adicionar → lista com o campo
    "Adicionar item" focado; a contagem reflui ao mudar itens/listas e no resume)
```

### 9.2. Sem lista (convite)
```
┌───────────────────────────┐
│ Minhas Listas             │
│ Crie sua primeira lista   │  ← widget_sem_lista (título da lista vazio)
│ 0 pendentes               │
│ (     Adicionar item    ) │
└───────────────────────────┘
   (sem lista, /adicionar cai no painel "Minhas Listas" §2)
```

---

## Documentos relacionados
- [05 App Flutter](05-app-flutter.md) — comportamento e interações de cada tela
- [06 MVP & Entregas](06-mvp-entregas.md) — LGPD e publicação
- [15 Design System](15-design-system.md) — tokens e componentes
