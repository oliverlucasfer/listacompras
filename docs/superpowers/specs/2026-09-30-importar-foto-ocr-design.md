# Frente — Importar por Foto (OCR) (design)

> **Status:** aprovado em 30/09/2026 (decisões registradas na Seção 9)
> **Fase:** 54 · **Requisito:** RF-37 (importar lista por foto com OCR on-device)
> **Docs donos:** [05](../05-app-flutter.md) (app/UX), [10](../10-wireframes-telas.md) (layout),
> [12](../12-prd.md) (requisitos), [04](../04-importacao-lista.md) (parser reusado),
> [09](../09-runbook-operacoes.md) (dependências/permissões), [14](../14-tarefas.md) (tarefas)

---

## 1. Motivação

Anotar a lista à mão (no papel, no mercado) é comum entre as personas **P1** e **P2**, e o app já
importa **texto colado** (RF-16) via parser local. Falta reconhecer a **foto** dessa anotação (ou de
uma nota) sem digitar tudo: tirar/escolher uma foto → OCR no dispositivo → o texto cai no mesmo
fluxo de importação.

**A feature é 100% offline.** O OCR roda **no aparelho** (ML Kit, modelo bundled); a imagem **não é
armazenada** nem enviada a lugar algum.

## 2. Escopo

**Dentro:**
- RF-37: **botão "Foto"** no modal de importar (RF-16) que oferece **câmera** ou **galeria**; OCR
  **on-device** (latino/pt-BR) preenche o **campo de texto editável**; o usuário segue o fluxo atual
  (Extrair → pré-visualização → adicionar à lista).
- Reconhece **lista escrita/impressa** e **nota/cupom** (mesma extração de texto + parser).

**Fora:** múltiplas fotos por importação (1 imagem nesta fase); armazenamento/anexo da imagem;
correção de layout de cupom (parse estruturado de nota fiscal); iOS/Web/Desktop além do escopo já
suportado (o botão só aparece onde há OCR).

## 3. Arquitetura (contratos + plugins)

- **`OcrTexto`** (`lib/features/ocr/domain/ocr_texto.dart`): `Future<String> extrair(String caminhoImagem)`.
  Impl. `OcrTextoMlKit` sobre **`google_mlkit_text_recognition`** (script **latino**, on-device).
- **`FonteImagem`** (`lib/features/ocr/domain/fonte_imagem.dart`): `Future<String?> daCamera()` e
  `Future<String?> daGaleria()` (devolvem o caminho ou `null` se cancelado). Impl. com
  **`image_picker`**.
- Providers `ocrTextoProvider` / `fonteImagemProvider` (injáveis; fakes nos testes).
- **Gate de plataforma:** `plataformaComOcr()` (Android/iOS; Web/Desktop escondem o botão), no padrão
  de `plataformaComVoz()`/`plataformaComNotificacao()`.

## 4. Fluxo e UI

No modal **"Importar lista"** (`lib/features/importacao/ui/modal_importar.dart`, RF-16):

1. Botão **"Foto"** (ícone câmera), visível **apenas** quando `plataformaComOcr()`.
2. Toque abre **"Tirar foto" / "Escolher da galeria"**.
3. Após escolher a imagem → **carregando** (OCR rodando) → o texto reconhecido **preenche o campo
   de texto** (editável), substituindo/appendando o conteúdo atual.
4. O usuário corrige (se quiser) e usa **"Extrair itens"** → pré-visualização → **adicionar à lista**
   (fluxo RF-16 inalterado).
5. Erros amigáveis: cancelou a captura → nada; **nenhum texto reconhecido** → aviso e campo vazio;
   falha/permissão do OCR ou da câmera → `AppBanner` com mensagem pt-BR.
6. O contador/limite (`maxCaracteresImportLocal = 10.000`) continua valendo.

## 5. Regras e casos-limite

- **1 imagem** por importação (sem multi-página nesta fase).
- Script **latino** (pt-BR); **manuscrito é best-effort** — o texto vai para o campo **editável**,
  então o usuário corrige antes de extrair.
- A **imagem não é persistida**; só o texto extraído entra no campo.
- Cancelar a captura ou o OCR → sem efeito (não altera o texto existente).
- `image_picker` no Android com a permissão `CAMERA` **declarada** exige a permissão **concedida**
  para a câmera; se negada, mostrar aviso amigável (a **galeria** segue funcionando).
- Sem rede em nenhum passo; sem novas permissões Android (o picker moderno usa o Photo Picker).

## 6. Dependências, permissões e riscos

- **`google_mlkit_text_recognition`** (modelo **bundled**, offline) — aumenta o **tamanho do app**;
  sem `INTERNET`. Pode exigir ajuste de Gradle/minSdk (avaliar na execução).
- **`image_picker`** (time Flutter) — câmera/galeria.
- iOS: `NSCameraUsageDescription` já existe; adicionar **`NSPhotoLibraryUsageDescription`** (pt-BR).
- Android: sem permissão nova; `CAMERA` já declarada (RF-33). O guard de CI do manifest de release
  deve continuar válido (ML Kit é permitido; sem `INTERNET`).
- Ambos os plugins ficam atrás de contratos injetáveis; **os testes nunca tocam os plugins reais**.

## 7. Testes

- **Unit:** `OcrTextoMlKit`/`FonteImagemImagePicker` não são testados com o plugin real (fakes nos
  testes de UI); a costura (provider/gate `plataformaComOcr`) é testável.
- **Widget** (modal de importar, com `FakeOcr`/`FonteImagemFake`):
  - botão "Foto" **visível** onde há OCR e **oculto** onde não há;
  - escolher da câmera/galeria **preenche** o campo com o texto do fake;
  - OCR **vazio** → aviso e campo vazio;
  - erro do OCR → `AppBanner` amigável;
  - **cancelar** (fonte devolve `null`) → campo inalterado;
  - o fluxo **Extrair → pré-visualização → adicionar** continua funcionando com o texto do OCR.
- Sem golden; plugin real só smoke em device.

## 8. Governança

- `12`: **RF-37** (tabela + matriz + fora de escopo).
- `05`: fluxo, contratos/providers, gate de plataforma e o botão no modal.
- `10`: wireframe do botão "Foto" e da escolha câmera/galeria.
- `04`: nota de que o OCR alimenta o parser local (texto → RF-16).
- `09`: dependências (`google_mlkit_text_recognition`, `image_picker`) e a permissão iOS de fotos.
- `15`: se entrar algum componente (ex.: estado de carregando do botão).
- `14`: Fase 54; `16`: frente.

## 9. Decisões registradas (30/09/2026)

1. OCR lê **lista escrita/impressa e nota/cupom** (mesma extração de texto + parser local).
2. **Câmera + galeria** como origem da imagem.
3. Entrada como **botão "Foto" no modal de importar** existente; o OCR **preenche o campo editável**
   e o fluxo RF-16 segue igual.
4. Motor **ML Kit on-device** (bundled) + **`image_picker`**; **Android/iOS** apenas (Web/Desktop
   escondem o botão).
5. **1 imagem** por importação; a imagem **não é armazenada**.
6. Fase **54**, requisito **RF-37**.

## 10. Documentos relacionados
- [04 Importação de lista](../04-importacao-lista.md) · [05 App Flutter](../05-app-flutter.md) · [10 Wireframes](../10-wireframes-telas.md)
- [12 PRD](../12-prd.md) · [14 Tarefas](../14-tarefas.md) · [16 Roadmap](../16-roadmap-pos-mvp.md)
