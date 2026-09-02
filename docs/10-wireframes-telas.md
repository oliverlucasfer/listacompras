# 10 — Wireframes das Telas

> Navegação: [← 09 Runbook](09-runbook-operacoes.md) · [11 Usabilidade →](11-usabilidade-fase5.md)

**Este documento é o dono do LAYOUT (visual/posição).** O comportamento de cada tela vive em [05 §6](05-app-flutter.md); os estados de sync em [03 §6](03-sincronizacao-offline.md). Wireframes em ASCII — referência para implementação e para os testes de usabilidade de [11](11-usabilidade-fase5.md).

Convenções: `[ ]` campo de texto · `( )` botão · `(x)` marcado · `[≡]` ícone · `▼/▸` seção aberta/fechada · `(...)` anotação de comportamento.

---

## 1. Autenticação

### 1.1. Login
```
┌─────────────────────────────────┐
│                                 │
│           🛒 Logo               │
│     Lista de Compras IA         │
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
│  (     Criar conta        )     │   Após registro: tela "Verifique
│                                 │   seu e-mail" (reenviar link).
└─────────────────────────────────┘
```

---

## 2. Minhas Listas

### 2.1. Estado preenchido
```
┌─────────────────────────────────┐
│  Minhas Listas           [≡]    │
│  ● Sincronizado            (1)  │ ← [03 §6] sincronizado/pendente/offline
├─────────────────────────────────┤
│  ┌───────────────────────────┐  │
│  │ Compras da Semana         │  │
│  │ 3/10 itens concluídos     │  │ ← long-press: renomear/excluir
│  │ atualizada há 5 min       │  │
│  └───────────────────────────┘  │
│  ┌───────────────────────────┐  │
│  │ Churrasco Sábado          │  │
│  │ 0/6 itens concluídos      │  │
│  │ ontem                     │  │
│  └───────────────────────────┘  │
│                                 │
│                      (＋ Nova)  │ ← FAB
└─────────────────────────────────┘
```

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
│   importe por texto com IA.     │
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

---

## 3. Tela da Lista de Compras

### 3.1. Uso normal
```
┌─────────────────────────────────┐
│  ← Compras da Semana      [⋮]   │ ← [⋮]: desmarcar todos, limpar
│  ● Sincronizado                 │    concluídos, convidar*, renomear,
├─────────────────────────────────┤    excluir lista
│  Adicionar item                 │
│  [____________________ (＋) ]   │ ← Enter salva imediatamente
│                                 │
│  ITENS (7)                      │
│  ☐ Arroz            1 kg    ≡   │ ← swipe ←/→: editar/remover (undo)
│  ☐ Leite            2 un    ≡   │
│  ☐ Queijo prato     500 g   ≡   │ ← long-press: reordenar (drag)
│  ☐ Café             1 pacote ≡  │
│                                 │
│  ▼ Itens Concluídos (3)         │ ← seção dobrável
│    ☑ Detergente     2 un        │
│    ☐ Macarrão       500 g       │ ← desmarcar volta para "Itens"
│                                 │
│  (🤖 Importar por IA)           │
└─────────────────────────────────┘
  (*Convidar: dono apenas, Fase 6 [08 §8](08-compartilhamento-colaborativo.md))
```

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

---

## 4. Importação por IA ([04 §2](04-ia-edge-function.md))

### 4.1. Modal de entrada
```
┌─────────────────────────────────┐
│  Importar por IA             ✕  │
├─────────────────────────────────┤
│  Cole ou digite sua lista:      │
│  ┌───────────────────────────┐  │
│  │ 1kg de arroz, 2 leites,   │ │
│  │ 500g de queijo prato...    │ │
│  │                           │ │
│  └───────────────────────────┘  │
│                        128/2000 │ ← contador; vermelho > 2000
│                                 │
│  (     ✨ Extrair itens    )    │ ← carregando: spinner + "Lendo..."
└─────────────────────────────────┘
   (erro → mensagem amigável do contrato [04 §2], ex.:
    "Texto muito longo. Envie até 2.000 caracteres.")
```

### 4.2. Modal de pré-visualização
```
┌─────────────────────────────────┐
│  Confirme os itens           ✕  │
├─────────────────────────────────┤
│  ⚠ "Interpretei 'pct' como      │ ← aviso da IA ([04 §2])
│     pacote de café"             │
│                                 │
│  ☑ Arroz          1  kg         │ ← desmarcar = não incluir
│  ☑ Leite          2  un    ▾    │ ← ▾ abre edição inline
│      [1] [kg|un|g|l|ml|...]     │
│  ☑ Queijo prato 500  g          │
│  ☐ Café           1  pct        │
│                                 │
│  3 de 4 serão adicionados       │
│  (Cancelar)   (Adicionar 3)     │
└─────────────────────────────────┘
```

---

## 5. Configurações (Fase 5 — [06 §3.3](06-mvp-entregas.md))
```
┌─────────────────────────────────┐
│  ← Configurações                │
├─────────────────────────────────┤
│  Conta                          │
│  oliveira@exemplo.com           │
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

---

## 6. Mapa de estados por tela (transversal)

| Tela | Carregando | Vazio | Erro | Offline |
| :--- | :--- | :--- | :--- | :--- |
| Minhas Listas | Spinner central | 2.2 | Banner "Tentar novamente" | Banner global + lista local (usável) |
| Tela da Lista | Spinner central | "Nenhum item. Adicione acima" | Banner | 3.2 — funcional |
| Importar IA | Botão com spinner | — | Mensagem amigável (4.1) | Botão desabilitado c/ dica |
| Login | Spinner no botão | — | Inline por campo | Banner |

---

## Documentos relacionados
- [05 App Flutter](05-app-flutter.md) — comportamento e interações de cada tela
- [03 Sincronização](03-sincronizacao-offline.md) — estados do indicador de sync
- [08 Compartilhamento](08-compartilhamento-colaborativo.md) — telas de convite/membros
- [06 MVP & Entregas](06-mvp-entregas.md) — exclusão de conta nas Configurações
