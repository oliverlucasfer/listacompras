# Ficha da loja — Minhas Listas (Lite)

Textos e especificação de arte da ficha da Google Play para o flavor **Lite** ("Minhas Listas"). O Lite é o app **100% local, sem conta**: os dados ficam só no aparelho e o backup é manual (exportar/importar). Requisito [RF-32](../docs/12-prd.md); passos de publicação no runbook [09 §2.10](../docs/09-runbook-operacoes.md).

- **Título (≤30):** Minhas Listas
- **Descrição curta (≤80):** Lista de compras simples, sem conta e 100% no seu aparelho.
- **Descrição completa:** ver abaixo (pt-BR).
- **Categoria:** Compras
- **Ícone da loja:** `store/icone-512.png` (512×512, gerado de `assets/branding/logo_lite.png`)
- **Feature graphic:** `store/feature-graphic-1024x500.png`
- **Screenshots:** `store/screenshots/` (mínimo 2, telefone)

## Descrição completa

Organize suas compras sem criar conta: o **Minhas Listas** guarda tudo **no seu aparelho**, sem nuvem e sem login.

- Crie quantas listas quiser e adicione itens com quantidade e unidade.
- Marque o que já foi comprado e acompanhe o total do carrinho.
- Use o **modo mercado** para marcar itens direto na loja.
- Adicione itens **por voz**, em português.
- Importe uma lista colando um texto simples.
- Funciona **offline**: sempre disponível, mesmo sem internet.
- Faça **backup** das suas listas exportando e importando um arquivo.

Sem conta, sem anúncios e **sem rastreamento**. Seus dados ficam com você.

## Contato e privacidade

- **Política de privacidade:** `site/privacidade.html`, publicada em `https://<usuario>.github.io/ListaCompras/privacidade.html` ([06 §3.3.2](../docs/06-mvp-entregas.md)).
- **Contato:** `oliverlucasfer@gmail.com` (`contatoPrivacidadeEmail`, interpolado nas duas versões da política e no HTML público).
- **Segurança de dados:** nenhum dado coletado, exceto **Áudio** (recurso de voz, processado pelo reconhecedor do sistema); sem conta, sem analytics, sem crash logs, sem anúncios ([09 §2.10](../docs/09-runbook-operacoes.md)).
- **Classificação de conteúdo / público-alvo:** 16+ (não direcionado a menores). **Anúncios: não.**

## Artefatos (binários da ficha)

Os textos acima já estão versionados; a **arte** é gerada em passo manual (mesmo processo Playwright da F44, a partir de `assets/branding/logo_lite.png`) e as **screenshots** exigem um device/emulador com o app Lite release.

- `store/icone-512.png` — **512×512** (PNG), derivado de `assets/branding/logo_lite.png` (1024×1024).
- `store/feature-graphic-1024x500.png` — **1024×500** (PNG), marca sobre índigo `#4F46E5`.
- `store/screenshots/` — **mínimo 2** capturas de telefone do Lite release (ex.: Minhas listas, lista aberta, modo mercado, backup).

> **Status:** os três itens binários ainda **não** foram gerados (sem Playwright/imagem e sem device nesta sessão). Gerar antes do envio à Play; os caminhos e dimensões acima são os esperados pela ficha.
