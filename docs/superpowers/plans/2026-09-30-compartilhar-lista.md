# Compartilhar Lista sem Nuvem — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Permitir enviar uma lista em texto legível, arquivo ou QR/código e recebê-la em outro aparelho (ou via colar código), sempre criando uma lista nova — tudo 100% offline.

**Architecture:** Um modelo puro (`ListaCompartilhada`) com três representações (JSON, código `ML1:`, texto) e um `CompartilhamentoRepository` sobre o Drift existente que exporta a lista e importa criando UUIDs novos numa transação. A UI reusa o parser de texto (RF-16), o `AppSheet`, e o `share_plus`/`file_selector` já presentes; adiciona `qr_flutter` (exibir) e `mobile_scanner` (ler, Android/iOS) atrás de um contrato injetável.

**Tech Stack:** Flutter, Riverpod, Drift/SQLite, go_router, share_plus, file_selector, qr_flutter, mobile_scanner.

**Spec:** `docs/superpowers/specs/2026-09-30-compartilhar-lista-design.md`

## Global Constraints

- App 100% local: **nenhuma** rede na operação normal; não adicionar dependência que faça tráfego.
- `Drift` é a fonte da verdade; IDs são **UUID v4 gerados no cliente** (`Uuid().v4()`).
- Enums fechados: `Unidade` (`lib/core/dominio/unidade.dart`) e `CategoriaItem` (`lib/core/dominio/categoria.dart`) — usar `fromValor`/`valor`, nunca strings soltas.
- Importar **sempre cria lista nova**; **nunca** mesclar (mesclar é papel do backup, RF-31).
- Formato do código: prefixo `ML1:` + `base64Url(utf8(json))`; JSON com `{"tipo":"minhas-listas/lista","versao":1,...}`.
- Dono local fixo: `idLocal = 'local'` (`lib/core/config/usuario_local.dart`).
- Nomes de teste: `deve_<resultado>_quando_<condição>`.
- Comentários só quando indispensáveis; pt-BR em strings/docs.
- Comandos de verificação finais (obrigatórios): `dart format . && flutter analyze && flutter test`.

---

## File Structure

- `lib/features/compartilhamento/domain/lista_compartilhada.dart` — modelo + exceções + validação.
- `lib/features/compartilhamento/domain/codec_lista.dart` — `codificarLista`/`decodificarLista`/`gerarTextoLista`.
- `lib/features/compartilhamento/domain/leitor_qr.dart` — contrato `LeitorQr`.
- `lib/features/compartilhamento/data/compartilhamento_repository.dart` — `exportarLista`/`importarLista`.
- `lib/features/compartilhamento/data/leitor_qr_plugin.dart` — impl. `mobile_scanner`.
- `lib/features/compartilhamento/providers/compartilhamento_providers.dart` — providers + `plataformaComCamera()`.
- `lib/features/compartilhamento/ui/sheet_compartilhar.dart` — sheet "Compartilhar" + QR + copiar código.
- `lib/features/compartilhamento/ui/receber_lista_screen.dart` — tela "Receber lista".
- `lib/features/compartilhamento/ui/tela_escanear_qr.dart` — scanner em tela cheia.
- Modificados: `pubspec.yaml`, `lib/router.dart`, `lib/features/listas/ui/tela_lista_screen.dart`, `lib/features/listas/ui/painel_listas.dart`, `lib/core/l10n/app_strings.dart`, `android/app/src/main/AndroidManifest.xml`, `ios/Runner/Info.plist`, e docs donos.

---

## Task 1: Domínio e codec (puro Dart)

**Files:**
- Create: `lib/features/compartilhamento/domain/lista_compartilhada.dart`
- Create: `lib/features/compartilhamento/domain/codec_lista.dart`
- Test: `test/features/compartilhamento/lista_compartilhada_test.dart`

**Interfaces:**
- Consumes: `Unidade.fromValor`/`.valor`, `CategoriaItem.fromValor`/`.valor`, `formatarQuantidade(double)` (`lib/core/dominio/quantidade.dart`).
- Produces: `ListaCompartilhada({titulo, itens})`, `ItemCompartilhado({nome, quantidade, unidade, categoria, concluido, ordem, precoCentavos})`, `CompartilhamentoInvalidoException(mensagem)`, `codificarLista(ListaCompartilhada) → String`, `decodificarLista(String) → ListaCompartilhada`, `gerarTextoLista(ListaCompartilhada) → String`.

- [ ] **Step 1: Write the failing test**

`test/features/compartilhamento/lista_compartilhada_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/dominio/categoria.dart';
import 'package:lista_compras/core/dominio/unidade.dart';
import 'package:lista_compras/features/compartilhamento/domain/codec_lista.dart';
import 'package:lista_compras/features/compartilhamento/domain/lista_compartilhada.dart';

ListaCompartilhada _exemplo() => const ListaCompartilhada(
      titulo: 'Semana',
      itens: [
        ItemCompartilhado(
          nome: 'arroz',
          quantidade: 2,
          unidade: Unidade.kg,
          categoria: CategoriaItem.mercearia,
          concluido: false,
          ordem: 0,
        ),
        ItemCompartilhado(
          nome: 'Leite',
          quantidade: 1,
          unidade: Unidade.un,
          categoria: CategoriaItem.laticinios,
          concluido: true,
          ordem: 1,
          precoCentavos: 549,
        ),
      ],
    );

void main() {
  test('deve_roundtrip_quando_codifica_e_decodifica', () {
    final original = _exemplo();
    final volta = decodificarLista(codificarLista(original));
    expect(volta.titulo, 'Semana');
    expect(volta.itens, hasLength(2));
    expect(volta.itens[1].nome, 'Leite');
    expect(volta.itens[1].concluido, isTrue);
    expect(volta.itens[1].precoCentavos, 549);
  });

  test('deve_falhar_quando_prefixo_invalido', () {
    expect(
      () => decodificarLista('XPTO:abc'),
      throwsA(isA<CompartilhamentoInvalidoException>()),
    );
  });

  test('deve_falhar_quando_base64_invalido', () {
    expect(
      () => decodificarLista('ML1:***'),
      throwsA(isA<CompartilhamentoInvalidoException>()),
    );
  });

  test('deve_falhar_quando_versao_desconhecida', () {
    final codigo = 'ML1:${_base64('{"tipo":"minhas-listas/lista","versao":9,"titulo":"x","itens":[]}')}';
    expect(
      () => decodificarLista(codigo),
      throwsA(isA<CompartilhamentoInvalidoException>()),
    );
  });

  test('deve_falhar_quando_item_invalido', () {
    expect(
      () => ListaCompartilhada.fromJson({
        'tipo': 'minhas-listas/lista',
        'versao': 1,
        'titulo': 'x',
        'itens': [
          {'nome': '  ', 'quantidade': 1, 'unidade': 'un',
           'categoria': 'outros', 'concluido': false, 'ordem': 0,
           'preco_centavos': null},
        ],
      }),
      throwsA(isA<CompartilhamentoInvalidoException>()),
    );
  });

  test('deve_gerar_texto_uma_linha_por_item_quando_exporta', () {
    expect(gerarTextoLista(_exemplo()), '2 kg arroz\n1 un Leite');
  });
}

String _base64(String s) =>
    base64Url.encode(utf8.encode(s));
```

(add `import 'dart:convert';` at top.)

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/compartilhamento/lista_compartilhada_test.dart`
Expected: FAIL — arquivos/classes inexistentes.

- [ ] **Step 3: Write minimal implementation**

`lib/features/compartilhamento/domain/lista_compartilhada.dart`:

```dart
import '../../../core/dominio/categoria.dart';
import '../../../core/dominio/unidade.dart';

/// Entrada de compartilhamento inválida (prefixo/base64/versão/JSON/campos).
class CompartilhamentoInvalidoException implements Exception {
  const CompartilhamentoInvalidoException(this.mensagem);
  final String mensagem;
  @override
  String toString() => 'CompartilhamentoInvalidoException: $mensagem';
}

class ItemCompartilhado {
  const ItemCompartilhado({
    required this.nome,
    required this.quantidade,
    required this.unidade,
    required this.categoria,
    required this.concluido,
    required this.ordem,
    this.precoCentavos,
  });

  final String nome;
  final double quantidade;
  final Unidade unidade;
  final CategoriaItem categoria;
  final bool concluido;
  final int ordem;
  final int? precoCentavos;

  Map<String, Object?> toJson() => {
        'nome': nome,
        'quantidade': quantidade,
        'unidade': unidade.valor,
        'categoria': categoria.valor,
        'concluido': concluido,
        'ordem': ordem,
        'preco_centavos': precoCentavos,
      };

  factory ItemCompartilhado.fromJson(Map<String, Object?> j) =>
      ItemCompartilhado(
        nome: j['nome'] as String,
        quantidade: (j['quantidade'] as num).toDouble(),
        unidade: Unidade.fromValor(j['unidade'] as String),
        categoria: CategoriaItem.fromValor(j['categoria'] as String),
        concluido: j['concluido'] as bool,
        ordem: j['ordem'] as int,
        precoCentavos: j['preco_centavos'] as int?,
      );
}

class ListaCompartilhada {
  const ListaCompartilhada({required this.titulo, required this.itens});

  static const versao = 1;
  static const tipo = 'minhas-listas/lista';
  static const prefixo = 'ML1:';

  final String titulo;
  final List<ItemCompartilhado> itens;

  Map<String, Object?> toJson() => {
        'tipo': tipo,
        'versao': versao,
        'titulo': titulo,
        'itens': [for (final i in itens) i.toJson()],
      };

  factory ListaCompartilhada.fromJson(Map<String, dynamic> json) {
    if (json['tipo'] != tipo || json['versao'] != versao) {
      throw const CompartilhamentoInvalidoException('Formato não suportado.');
    }
    final titulo = json['titulo'] as String;
    if (titulo.trim().isEmpty) {
      throw const CompartilhamentoInvalidoException('Lista sem título.');
    }
    final itens = [
      for (final e in (json['itens'] as List))
        ItemCompartilhado.fromJson((e as Map).cast<String, Object?>()),
    ];
    for (final i in itens) {
      if (i.nome.trim().isEmpty || i.quantidade <= 0) {
        throw const CompartilhamentoInvalidoException('Item inválido.');
      }
    }
    return ListaCompartilhada(titulo: titulo, itens: itens);
  }
}
```

`lib/features/compartilhamento/domain/codec_lista.dart`:

```dart
import 'dart:convert';

import '../../../core/dominio/quantidade.dart';
import 'lista_compartilhada.dart';

String codificarLista(ListaCompartilhada lista) {
  final json = jsonEncode(lista.toJson());
  return ListaCompartilhada.prefixo + base64Url.encode(utf8.encode(json));
}

ListaCompartilhada decodificarLista(String codigo) {
  final texto = codigo.trim();
  if (!texto.startsWith(ListaCompartilhada.prefixo)) {
    throw const CompartilhamentoInvalidoException('Código inválido.');
  }
  final corpo = texto.substring(ListaCompartilhada.prefixo.length);
  try {
    final mapa = jsonDecode(utf8.decode(base64Url.decode(corpo)));
    return ListaCompartilhada.fromJson((mapa as Map).cast<String, dynamic>());
  } on CompartilhamentoInvalidoException {
    rethrow;
  } catch (_) {
    throw const CompartilhamentoInvalidoException('Código inválido.');
  }
}

String gerarTextoLista(ListaCompartilhada lista) => [
      for (final i in lista.itens)
        '${formatarQuantidade(i.quantidade)} ${i.unidade.valor} ${i.nome}',
    ].join('\n');
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/compartilhamento/lista_compartilhada_test.dart`
Expected: PASS (todos).

- [ ] **Step 5: Commit**

```bash
git add lib/features/compartilhamento/domain test/features/compartilhamento
git commit -m "feat(compartilhar): modelo e codec de lista compartilhada (RF-33)"
```

---

## Task 2: Repositório (exportar/importar no Drift)

**Files:**
- Create: `lib/features/compartilhamento/data/compartilhamento_repository.dart`
- Create: `lib/features/compartilhamento/providers/compartilhamento_providers.dart`
- Test: `test/features/compartilhamento/compartilhamento_repository_test.dart`

**Interfaces:**
- Consumes: `AppDatabase` (`lib/drift/database.dart`), `appDatabaseProvider` (`lib/features/listas/providers/listas_providers.dart:13`), `idLocal`, `Lista`/`Item`, `ListaCompartilhada`/`ItemCompartilhado` (Task 1).
- Produces: `CompartilhamentoRepository(db, {Uuid uuid})`, `exportarLista(String listaId) → Future<ListaCompartilhada>`, `importarLista(ListaCompartilhada, {required String titulo}) → Future<Lista>`, `compartilhamentoRepositoryProvider`.

- [ ] **Step 1: Write the failing test**

`test/features/compartilhamento/compartilhamento_repository_test.dart`:

```dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/dominio/categoria.dart';
import 'package:lista_compras/core/dominio/unidade.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/compartilhamento/data/compartilhamento_repository.dart';
import 'package:lista_compras/features/compartilhamento/domain/lista_compartilhada.dart';
import 'package:lista_compras/features/listas/data/listas_repository.dart';

void main() {
  late AppDatabase db;
  late ListasRepository listas;
  late CompartilhamentoRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    listas = ListasRepository(db);
    repo = CompartilhamentoRepository(db);
  });

  tearDown(() => db.close());

  test('deve_exportar_titulo_e_todos_os_itens_quando_exporta', () async {
    final l = await listas.criarLista(titulo: 'Semana', donoId: 'local');
    await listas.adicionarItem(
      listaId: l.id, nome: 'Arroz', quantidade: 2,
      unidade: Unidade.kg, categoria: CategoriaItem.mercearia,
    );
    final comprado = await listas.adicionarItem(listaId: l.id, nome: 'Leite');
    await listas.editarItem(comprado.id, concluido: true);

    final compartilhada = await repo.exportarLista(l.id);
    expect(compartilhada.titulo, 'Semana');
    expect(compartilhada.itens.map((i) => i.nome), ['Arroz', 'Leite']);
    expect(compartilhada.itens.last.concluido, isTrue);
  });

  test('deve_criar_lista_nova_com_uuids_novos_quando_importa', () async {
    final origem = const ListaCompartilhada(
      titulo: 'Recebida',
      itens: [
        ItemCompartilhado(
          nome: 'Arroz', quantidade: 2, unidade: Unidade.kg,
          categoria: CategoriaItem.mercearia, concluido: false, ordem: 0,
        ),
      ],
    );

    final nova = await repo.importarLista(origem, titulo: 'Recebida');

    final listas0 = await db.select(db.listaLocal).get();
    expect(listas0, hasLength(1));
    expect(nova.id, isNotEmpty);
    final itens = await db.select(db.itemLocal).get();
    expect(itens.single.id, isNotEmpty);
    expect(itens.single.listaId, nova.id);
    expect(itens.single.nome, 'Arroz');
    expect(itens.single.concluido, isFalse);
  });

  test('deve_preservar_concluido_e_preco_quando_importa', () async {
    final origem = const ListaCompartilhada(
      titulo: 'X',
      itens: [
        ItemCompartilhado(
          nome: 'Leite', quantidade: 1, unidade: Unidade.un,
          categoria: CategoriaItem.laticinios, concluido: true, ordem: 0,
          precoCentavos: 549,
        ),
      ],
    );
    final nova = await repo.importarLista(origem, titulo: 'X');
    final item = (await db.select(db.itemLocal)..where((i) => i.listaId.equals(nova.id))).getSingle();
    expect(item.concluido, isTrue);
    expect(item.precoCentavos, 549);
    expect(item.categoria, 'laticinios');
  });

  test('deve_usar_o_dono_local_quando_importa', () async {
    final nova = await repo.importarLista(
      const ListaCompartilhada(titulo: 'X', itens: []),
      titulo: 'X',
    );
    expect(nova.donoId, 'local');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/compartilhamento/compartilhamento_repository_test.dart`
Expected: FAIL — `CompartilhamentoRepository` inexistente.

- [ ] **Step 3: Write minimal implementation**

`lib/features/compartilhamento/data/compartilhamento_repository.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/usuario_local.dart';
import '../../../core/dominio/categoria.dart';
import '../../../core/dominio/unidade.dart';
import '../../../drift/database.dart';
import '../../listas/domain/lista.dart';
import '../domain/lista_compartilhada.dart';

class CompartilhamentoRepository {
  CompartilhamentoRepository(this._db, {Uuid? uuid})
      : _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final Uuid _uuid;

  Future<ListaCompartilhada> exportarLista(String listaId) async {
    final lista = await (_db.select(_db.listaLocal)
          ..where((l) => l.id.equals(listaId)))
        .getSingle();
    final itens = await (_db.select(_db.itemLocal)
          ..where((i) => i.listaId.equals(listaId) & i.deletadoEm.isNull())
          ..orderBy([
            (i) => OrderingTerm.asc(i.ordem),
            (i) => OrderingTerm.asc(i.id),
          ]))
        .get();
    return ListaCompartilhada(
      titulo: lista.titulo,
      itens: [
        for (final i in itens)
          ItemCompartilhado(
            nome: i.nome,
            quantidade: i.quantidade,
            unidade: Unidade.fromValor(i.unidade),
            categoria: CategoriaItem.fromValor(i.categoria),
            concluido: i.concluido,
            ordem: i.ordem,
            precoCentavos: i.precoCentavos,
          ),
      ],
    );
  }

  Future<Lista> importarLista(
    ListaCompartilhada origem, {
    required String titulo,
  }) {
    return _db.transaction(() async {
      final agora = DateTime.now().toUtc();
      final listaId = _uuid.v4();
      await _db.into(_db.listaLocal).insert(
            ListaLocalCompanion.insert(
              id: listaId,
              createdAt: agora,
              updatedAt: agora,
              titulo: titulo,
              donoId: idLocal,
            ),
          );
      var ordem = 0;
      for (final i in origem.itens) {
        await _db.into(_db.itemLocal).insert(
              ItemLocalCompanion.insert(
                id: _uuid.v4(),
                createdAt: agora,
                updatedAt: agora,
                listaId: listaId,
                nome: i.nome,
                quantidade: Value(i.quantidade),
                unidade: Value(i.unidade.valor),
                categoria: Value(i.categoria.valor),
                precoCentavos: Value(i.precoCentavos),
                concluido: Value(i.concluido),
                ordem: Value(ordem++),
              ),
            );
      }
      return Lista(
        id: listaId,
        titulo: titulo,
        donoId: idLocal,
        criadoEm: agora,
        atualizadoEm: agora,
      );
    });
  }
}
```

`lib/features/compartilhamento/providers/compartilhamento_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../listas/providers/listas_providers.dart';
import '../data/compartilhamento_repository.dart';

final compartilhamentoRepositoryProvider =
    Provider<CompartilhamentoRepository>(
  (ref) => CompartilhamentoRepository(ref.watch(appDatabaseProvider)),
);
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/compartilhamento/compartilhamento_repository_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/compartilhamento/data lib/features/compartilhamento/providers test/features/compartilhamento
git commit -m "feat(compartilhar): repositório exportar/importar lista (RF-33)"
```

---

## Task 3: UI "Enviar" (sheet Compartilhar + QR + copiar código)

**Files:**
- Modify: `pubspec.yaml` (adiciona `qr_flutter`)
- Create: `lib/features/compartilhamento/ui/sheet_compartilhar.dart`
- Modify: `lib/core/l10n/app_strings.dart` (novas strings)
- Modify: `lib/features/listas/ui/tela_lista_screen.dart` (item de menu + `_compartilhar`)
- Test: `test/features/compartilhamento/sheet_compartilhar_test.dart`

**Interfaces:**
- Consumes: `compartilhamentoRepositoryProvider`, `codificarLista`/`gerarTextoLista` (Task 1), `AppSheet.mostrar`, `SharePlus` (padrão de `secao_backup.dart`), `mostrarSnackBar`, `AppStrings`.
- Produces: `abrirSheetCompartilhar(BuildContext, WidgetRef, String listaId) → Future<void>`.

- [ ] **Step 1: Add dependency**

Run: `flutter pub add qr_flutter`
Expected: `pubspec.yaml` com `qr_flutter` e `flutter pub get` OK.

- [ ] **Step 2: Add strings**

Em `lib/core/l10n/app_strings.dart`, junto do bloco "Backup local":

```dart
  // Compartilhar lista (RF-33, F49)
  static const compartilharLista = 'Compartilhar';
  static const compartilharTexto = 'Enviar como texto';
  static const compartilharArquivo = 'Enviar arquivo';
  static const compartilharQr = 'QR code';
  static const copiarCodigo = 'Copiar código';
  static const codigoCopiado = 'Código copiado.';
  static const compartilharQrGrande =
      'Lista grande — use texto ou arquivo.';
  static const listaCompartilhada = 'Lista compartilhada';
```

- [ ] **Step 3: Write the failing widget test**

`test/features/compartilhamento/sheet_compartilhar_test.dart`:

```dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/compartilhamento/ui/sheet_compartilhar.dart';
import 'package:lista_compras/features/listas/data/listas_repository.dart';
import 'package:lista_compras/features/listas/providers/listas_providers.dart';

void main() {
  testWidgets('deve_mostrar_as_tres_opcoes_quando_abre', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final lista = await ListasRepository(db)
        .criarLista(titulo: 'X', donoId: 'local');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Consumer(
                builder: (context, ref, _) => TextButton(
                  onPressed: () =>
                      abrirSheetCompartilhar(context, ref, lista.id),
                  child: const Text('abrir'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.text('Enviar como texto'), findsOneWidget);
    expect(find.text('Enviar arquivo'), findsOneWidget);
    expect(find.text('QR code'), findsOneWidget);
  });
}
```

- [ ] **Step 4: Run test to verify it fails**

Run: `flutter test test/features/compartilhamento/sheet_compartilhar_test.dart`
Expected: FAIL — função inexistente.

- [ ] **Step 5: Write the sheet implementation**

`lib/features/compartilhamento/ui/sheet_compartilhar.dart`:

```dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../domain/codec_lista.dart';
import '../domain/lista_compartilhada.dart';
import '../providers/compartilhamento_providers.dart';

/// Teto do código para o QR (spec §4). Acima disso só texto/arquivo.
const int limiteCodigoBytes = 2000;

Future<void> abrirSheetCompartilhar(
  BuildContext context,
  WidgetRef ref,
  String listaId,
) async {
  final lista =
      await ref.read(compartilhamentoRepositoryProvider).exportarLista(listaId);
  if (!context.mounted) return;
  await AppSheet.mostrar<void>(
    context,
    child: _SheetCompartilhar(lista: lista),
  );
}

class _SheetCompartilhar extends StatelessWidget {
  const _SheetCompartilhar({required this.lista});

  final ListaCompartilhada lista;

  Future<void> _texto(BuildContext context) async {
    try {
      await SharePlus.instance.share(
        ShareParams(text: gerarTextoLista(lista)),
      );
    } on MissingPluginException {
      if (context.mounted) {
        mostrarSnackBar(context, AppStrings.compartilharIndisponivel);
      }
    } on UnimplementedError {
      if (context.mounted) {
        mostrarSnackBar(context, AppStrings.compartilharIndisponivel);
      }
    }
  }

  Future<void> _arquivo(BuildContext context) async {
    try {
      final json = jsonEncode(lista.toJson());
      final nome = '${lista.titulo}.json';
      final arquivo = XFile.fromData(
        utf8.encode(json),
        name: nome,
        mimeType: 'application/json',
      );
      await SharePlus.instance.share(
        ShareParams(files: [arquivo], fileNameOverrides: [nome]),
      );
    } on MissingPluginException {
      if (context.mounted) {
        mostrarSnackBar(context, AppStrings.compartilharIndisponivel);
      }
    } on UnimplementedError {
      if (context.mounted) {
        mostrarSnackBar(context, AppStrings.compartilharIndisponivel);
      }
    }
  }

  Future<void> _qr(BuildContext context) async {
    final codigo = codificarLista(lista);
    if (codigo.length > limiteCodigoBytes) {
      mostrarSnackBar(context, AppStrings.compartilharQrGrande);
      return;
    }
    await AppSheet.mostrar<void>(
      context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          QrImageView(data: codigo, size: 240),
          const SizedBox(height: 12),
          TextButton.icon(
            icon: const Icon(Icons.copy),
            label: const Text(AppStrings.copiarCodigo),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: codigo));
              if (context.mounted) {
                mostrarSnackBar(context, AppStrings.codigoCopiado);
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(lista.titulo, style: Theme.of(context).textTheme.titleMedium),
        ListTile(
          leading: const Icon(Icons.chat_outlined),
          title: const Text(AppStrings.compartilharTexto),
          onTap: () => _texto(context),
        ),
        ListTile(
          leading: const Icon(Icons.upload_file_outlined),
          title: const Text(AppStrings.compartilharArquivo),
          onTap: () => _arquivo(context),
        ),
        ListTile(
          leading: const Icon(Icons.qr_code_2),
          title: const Text(AppStrings.compartilharQr),
          onTap: () => _qr(context),
        ),
      ],
    );
  }
}
```

- [ ] **Step 6: Wire the menu**

Em `lib/features/listas/ui/tela_lista_screen.dart`: adicionar import

```dart
import '../../compartilhamento/ui/sheet_compartilhar.dart';
```

No `itemBuilder` do `PopupMenuButton` (após `adicionarDeOutraLista`), adicionar:

```dart
                    const PopupMenuItem(
                      value: 'compartilhar',
                      child: Text(AppStrings.compartilharLista),
                    ),
```

Em `_acaoMenu`, adicionar o caso no `switch`/cadeia existente (mesmo padrão dos demais):

```dart
      case 'compartilhar':
        await abrirSheetCompartilhar(context, ref, listaId);
```

- [ ] **Step 7: Run tests**

Run: `flutter test test/features/compartilhamento/sheet_compartilhar_test.dart && flutter analyze`
Expected: PASS e analyze limpo.

- [ ] **Step 8: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/features/compartilhamento lib/features/listas/ui/tela_lista_screen.dart lib/core/l10n/app_strings.dart test/features/compartilhamento
git commit -m "feat(compartilhar): envio por texto, arquivo e QR (RF-33)"
```

---

## Task 4: Leitura por câmera (contrato + plugin + permissões)

**Files:**
- Modify: `pubspec.yaml` (adiciona `mobile_scanner`)
- Create: `lib/features/compartilhamento/domain/leitor_qr.dart`
- Create: `lib/features/compartilhamento/data/leitor_qr_plugin.dart`
- Create: `lib/features/compartilhamento/ui/tela_escanear_qr.dart`
- Modify: `lib/features/compartilhamento/providers/compartilhamento_providers.dart` (provider + `plataformaComCamera()`)
- Modify: `android/app/src/main/AndroidManifest.xml` (permissão `CAMERA`)
- Modify: `ios/Runner/Info.plist` (`NSCameraUsageDescription`)

**Interfaces:**
- Consumes: `mobile_scanner`, `defaultTargetPlatform`/`kIsWeb`.
- Produces: `LeitorQr` (interface), `LeitorQrPlugin`, `plataformaComCamera() → bool`, `leitorQrProvider`.

- [ ] **Step 1: Add dependency**

Run: `flutter pub add mobile_scanner`
Expected: `mobile_scanner` no `pubspec.yaml`; `flutter pub get` OK.

- [ ] **Step 2: Create the contract and plugin**

`lib/features/compartilhamento/domain/leitor_qr.dart`:

```dart
import 'package:flutter/widgets.dart';

/// Lê um QR/código pela câmera. Devolve o texto lido, ou `null` se cancelado.
abstract interface class LeitorQr {
  Future<String?> escanear(BuildContext context);
}
```

`lib/features/compartilhamento/ui/tela_escanear_qr.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/l10n/app_strings.dart';

/// Scanner em tela cheia; `pop` devolve o primeiro código lido (ou `null`).
class TelaEscanearQr extends StatefulWidget {
  const TelaEscanearQr({super.key});

  @override
  State<TelaEscanearQr> createState() => _TelaEscanearQrState();
}

class _TelaEscanearQrState extends State<TelaEscanearQr> {
  final _controller = MobileScannerController();
  bool _lido = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _aoDetectar(BarcodeCapture capture) {
    if (_lido) return;
    final valor = capture.barcodes.firstOrNull?.rawValue;
    if (valor == null || valor.isEmpty) return;
    _lido = true;
    Navigator.pop(context, valor);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.escanearQr)),
      body: MobileScanner(controller: _controller, onDetect: _aoDetectar),
    );
  }
}
```

`lib/features/compartilhamento/data/leitor_qr_plugin.dart`:

```dart
import 'package:flutter/widgets.dart';

import '../domain/leitor_qr.dart';
import '../ui/tela_escanear_qr.dart';

class LeitorQrPlugin implements LeitorQr {
  @override
  Future<String?> escanear(BuildContext context) {
    return Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const TelaEscanearQr()),
    );
  }
}
```

Em `compartilhamento_providers.dart`, adicionar:

```dart
import 'package:flutter/foundation.dart';
import '../data/leitor_qr_plugin.dart';
import '../domain/leitor_qr.dart';

/// Câmera só onde o scanner é suportado: Android/iOS (spec §7).
bool plataformaComCamera() {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}

final leitorQrProvider = Provider<LeitorQr>((ref) => LeitorQrPlugin());
```

(Adicionar `AppStrings.escanearQr = 'Escanear QR';` em `app_strings.dart`.)

- [ ] **Step 3: Permissões nativas**

Em `android/app/src/main/AndroidManifest.xml`, junto das outras permissões:

```xml
    <!-- Leitura de QR por câmera (RF-33) -->
    <uses-permission android:name="android.permission.CAMERA"/>
```

Em `ios/Runner/Info.plist`, dentro do `<dict>`:

```xml
	<key>NSCameraUsageDescription</key>
	<string>Usar a câmera para ler o código de uma lista compartilhada.</string>
```

- [ ] **Step 4: Verify it compiles on all targets**

Run (cada um deve compilar sem erro):
```bash
flutter build apk --debug
flutter build web --release
flutter build windows --debug
```
Expected: os três compilam. **Se `mobile_scanner` quebrar Web/Desktop**, isolar o import de `mobile_scanner` em `tela_escanear_qr.dart` atrás de import condicional e registrar um stub para Web/Desktop (a UI já esconde o botão via `plataformaComCamera()`).

- [ ] **Step 5: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/features/compartilhamento android/app/src/main/AndroidManifest.xml ios/Runner/Info.plist lib/core/l10n/app_strings.dart
git commit -m "feat(compartilhar): leitura de QR por câmera Android/iOS (RF-33)"
```

---

## Task 5: UI "Receber lista" (rota + tela + entrada no painel)

**Files:**
- Create: `lib/features/compartilhamento/ui/receber_lista_screen.dart`
- Modify: `lib/router.dart` (rota `/receber-lista`)
- Modify: `lib/features/listas/ui/painel_listas.dart` (ação "Receber lista")
- Modify: `lib/core/l10n/app_strings.dart` (strings)
- Test: `test/features/compartilhamento/receber_lista_screen_test.dart`

**Interfaces:**
- Consumes: `compartilhamentoRepositoryProvider`, `decodificarLista`, `analisarListaLocal` (`lib/core/importacao/parser_lista_local.dart`) + `sugestaoCategoriasProvider`, `leitorQrProvider`, `file_selector`, `context.push`.

**Contrato (Task 1):** `analisarListaLocal(String) → RespostaParse` cujos itens têm `nome`, `quantidade`, `unidade`, `categoria` (a categoria vem `outros` do parser; re-enriquecer com `sugestaoCategoriasProvider.sugerirCategoria(nome)` como em `modal_importar.dart:85`).

- [ ] **Step 1: Add strings**

```dart
  static const receberLista = 'Receber lista';
  static const receberCodigoOuTexto = 'Cole o código ou o texto da lista';
  static const receberArquivo = 'Escolher arquivo';
  static const escanearQr = 'Escanear QR';
  static const receberConfirmar = 'Criar lista';
  static const receberInvalido = 'Código ou arquivo inválido.';
```

- [ ] **Step 2: Write the failing widget test**

`test/features/compartilhamento/receber_lista_screen_test.dart`:

```dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/compartilhamento/domain/codec_lista.dart';
import 'package:lista_compras/features/compartilhamento/domain/lista_compartilhada.dart';
import 'package:lista_compras/features/compartilhamento/ui/receber_lista_screen.dart';
import 'package:lista_compras/features/listas/providers/listas_providers.dart';
import 'package:lista_compras/core/dominio/categoria.dart';
import 'package:lista_compras/core/dominio/unidade.dart';

void main() {
  testWidgets('deve_criar_lista_nova_quando_cola_codigo', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final codigo = codificarLista(const ListaCompartilhada(
      titulo: 'Recebida',
      itens: [
        ItemCompartilhado(
          nome: 'Arroz', quantidade: 2, unidade: Unidade.kg,
          categoria: CategoriaItem.mercearia, concluido: false, ordem: 0,
        ),
      ],
    ));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: ReceberListaScreen()),
      ),
    );
    await tester.enterText(find.byType(TextField).first, codigo);
    await tester.tap(find.text('Criar lista'));
    await tester.pumpAndSettle();

    final listas = await db.select(db.listaLocal).get();
    expect(listas, hasLength(1));
    expect(listas.single.titulo, 'Recebida');
  });

  testWidgets('deve_mostrar_erro_quando_codigo_invalido', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: ReceberListaScreen()),
      ),
    );
    await tester.enterText(find.byType(TextField).first, 'ML1:***');
    await tester.tap(find.text('Criar lista'));
    await tester.pumpAndSettle();
    expect(find.text('Código ou arquivo inválido.'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/features/compartilhamento/receber_lista_screen_test.dart`
Expected: FAIL — tela inexistente.

- [ ] **Step 4: Write the screen**

`lib/features/compartilhamento/ui/receber_lista_screen.dart`:

```dart
import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/dominio/categoria.dart';
import '../../../core/importacao/parser_lista_local.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/tokens/app_spacing.dart';
import '../../../core/widgets/app_banner.dart';
import '../../../core/widgets/app_botao.dart';
import '../../../core/widgets/app_campo_texto.dart';
import '../../listas/providers/listas_providers.dart';
import '../domain/codec_lista.dart';
import '../domain/lista_compartilhada.dart';
import '../providers/compartilhamento_providers.dart';

class ReceberListaScreen extends ConsumerStatefulWidget {
  const ReceberListaScreen({super.key});

  @override
  ConsumerState<ReceberListaScreen> createState() => _ReceberListaScreenState();
}

class _ReceberListaScreenState extends ConsumerState<ReceberListaScreen> {
  final _controller = TextEditingController();
  String? _erro;
  bool _carregando = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<ListaCompartilhada?> _lerEntrada() async {
    final texto = _controller.text.trim();
    if (texto.startsWith(ListaCompartilhada.prefixo)) {
      return decodificarLista(texto);
    }
    if (texto.startsWith('{')) {
      try {
        final mapa = jsonDecode(texto);
        return ListaCompartilhada.fromJson(
          (mapa as Map).cast<String, dynamic>(),
        );
      } catch (_) {
        throw const CompartilhamentoInvalidoException('Arquivo inválido.');
      }
    }
    final parse = analisarListaLocal(texto);
    if (parse.itens.isEmpty) {
      throw const CompartilhamentoInvalidoException('');
    }
    final sugestao = ref.read(sugestaoCategoriasProvider);
    final itens = <ItemCompartilhado>[];
    var ordem = 0;
    for (final i in parse.itens) {
      itens.add(ItemCompartilhado(
        nome: i.nome,
        quantidade: i.quantidade,
        unidade: i.unidade,
        categoria: await sugestao.sugerirCategoria(i.nome),
        concluido: false,
        ordem: ordem++,
      ));
    }
    return ListaCompartilhada(titulo: AppStrings.listaCompartilhada, itens: itens);
  }

  Future<void> _confirmar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final entrada = await _lerEntrada();
      if (entrada == null) return;
      final lista = await ref
          .read(compartilhamentoRepositoryProvider)
          .importarLista(entrada, titulo: entrada.titulo);
      if (mounted) context.go('/lista/${lista.id}');
    } on CompartilhamentoInvalidoException {
      if (mounted) setState(() => _erro = AppStrings.receberInvalido);
    } catch (_) {
      if (mounted) setState(() => _erro = AppStrings.erroGenerico);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _arquivo() async {
    final arquivo = await openFile();
    if (arquivo == null) return;
    _controller.text = await arquivo.readAsString();
    await _confirmar();
  }

  Future<void> _escanear() async {
    final codigo = await ref.read(leitorQrProvider).escanear(context);
    if (codigo == null || !mounted) return;
    _controller.text = codigo;
    await _confirmar();
  }

  @override
  Widget build(BuildContext context) {
    final comCamera = plataformaComCamera();
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.receberLista)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCampoTexto(
              controller: _controller,
              label: AppStrings.receberCodigoOuTexto,
              minLines: 5,
              maxLines: 8,
              onChanged: (_) => setState(() => _erro = null),
            ),
            if (_erro != null) ...[
              const SizedBox(height: AppSpacing.sm),
              AppBanner(tipo: AppBannerTipo.erro, mensagem: _erro!),
            ],
            const SizedBox(height: AppSpacing.md),
            AppBotao(
              rotulo: AppStrings.receberConfirmar,
              carregando: _carregando,
              onPressed: _controller.text.trim().isEmpty ? null : _confirmar,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppBotao(
              rotulo: AppStrings.receberArquivo,
              variante: AppBotaoVariante.outlined,
              icone: Icons.folder_open,
              onPressed: _arquivo,
            ),
            if (comCamera) ...[
              const SizedBox(height: AppSpacing.sm),
              AppBotao(
                rotulo: AppStrings.escanearQr,
                variante: AppBotaoVariante.outlined,
                icone: Icons.qr_code_scanner,
                onPressed: _escanear,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

> Nota do executor: confirme a assinatura exata de `AppCampoTexto` (`label`, `minLines`, `maxLines`, `onChanged`) e de `AppBotao` (`rotulo`, `variante`, `icone`, `carregando`, `onPressed`) em `lib/core/widgets/` e ajuste se necessário. Se `AppBotao` não tiver `carregando`, use o padrão de `modal_importar.dart`.

- [ ] **Step 5: Add the route and panel entry**

Em `lib/router.dart`, adicionar import e rota (fora do shell, como `/lista/:listaId`):

```dart
import 'features/compartilhamento/ui/receber_lista_screen.dart';
```
```dart
      GoRoute(
        path: '/receber-lista',
        builder: (context, state) => const ReceberListaScreen(),
      ),
```

Em `lib/features/listas/ui/painel_listas.dart`, no bloco de `actions` da `AppBar` (junto de arquivadas/busca), adicionar:

```dart
            IconButton(
              tooltip: AppStrings.receberLista,
              icon: const Icon(Icons.qr_code_scanner),
              onPressed: () => context.push('/receber-lista'),
            ),
```

(garantir `import 'package:go_router/go_router.dart';` no arquivo.)

- [ ] **Step 6: Run tests and analyze**

Run: `flutter test test/features/compartilhamento/receber_lista_screen_test.dart && flutter analyze`
Expected: PASS e analyze limpo.

- [ ] **Step 7: Commit**

```bash
git add lib/features/compartilhamento lib/features/listas/ui/painel_listas.dart lib/router.dart lib/core/l10n/app_strings.dart test/features/compartilhamento
git commit -m "feat(compartilhar): receber lista por código, texto, arquivo e QR (RF-33)"
```

---

## Task 6: Docs donos e fechamento

**Files:**
- Modify: `docs/12-prd.md` (RF-33 + matriz)
- Modify: `docs/05-app-flutter.md` (rotas/telas/providers)
- Modify: `docs/10-wireframes-telas.md` (sheet Compartilhar + tela Receber)
- Modify: `docs/04-importacao-lista.md` (nota do reuso do parser — spec §3)
- Modify: `docs/09-runbook-operacoes.md` (permissão de câmera)
- Modify: `docs/16-roadmap-pos-mvp.md` e `docs/14-tarefas.md` (fase/progresso)

- [ ] **Step 1: RF-33 no PRD (`docs/12-prd.md`)**

Adicionar na tabela de requisitos funcionais:

```
| RF-33 | Compartilhar lista sem nuvem: exportar (texto/arquivo/QR-código) e importar (texto/arquivo/QR) sempre criando uma lista nova, 100% offline | 05 §6.12 + 10 | F49 | [05 §8] |
```

Adicionar a linha correspondente na matriz de rastreabilidade (Seção 6):
`| RF-33 | US-01 | F49 | F49-T01…F49-T06 | Unit codec/repo + widgets |`

- [ ] **Step 2: Doc dono 05**

Criar a seção `§6.12 Compartilhar lista (RF-33)`: rota `/receber-lista`; sheet "Compartilhar" (texto/arquivo/QR); contrato `LeitorQr` e `plataformaComCamera()`; providers `compartilhamentoRepositoryProvider`/`leitorQrProvider`; regra "importar cria lista nova"; formato `ML1:`; e registrar a nota em `§2` (árvore de pastas) com `lib/features/compartilhamento/`.

- [ ] **Step 3: Wireframe 10 e demais donos**

Em `docs/10-wireframes-telas.md`: wireframe do sheet "Compartilhar" (3 opções + QR + copiar código) e da tela "Receber lista" (campo + arquivo + escanear + confirmar).
Em `docs/04-importacao-lista.md`: nota de que o formato **texto** de compartilhamento reusa o parser local (mesmo contrato).
Em `docs/09-runbook-operacoes.md`: registrar a permissão `CAMERA` (Android) e `NSCameraUsageDescription` (iOS), com o caráter opcional/offline.

- [ ] **Step 4: Roadmap e tarefas**

Em `docs/16-roadmap-pos-mvp.md`: mover a frente para "concluído" quando fechada.
Em `docs/14-tarefas.md`: criar `## Fase 49 — Compartilhar lista sem nuvem (RF-33)` com as tasks F49-T01…T06 e atualizar a tabela de progresso (somar a fase).

- [ ] **Step 5: Verify CI local**

Run: `dart format . && flutter analyze && flutter test`
Expected: format sem diffs, analyze limpo, todos os testes verdes.

- [ ] **Step 6: Commit**

```bash
git add docs
git commit -m "docs(compartilhar): RF-33, 05, 10, 04, 09, 14 e 16 (F49)"
```

---

## Self-Review (cobertura da spec)

- §3 modelo/formatos → Task 1 (JSON/código/texto; validação).
- §4 repositório (exportar todos os itens; importar lista nova; limite do código) → Task 2 (repo) + Task 3 (`limiteCodigoBytes`).
- §5 UI enviar (sheet, share, QR, copiar código) → Task 3.
- §6 UI receber (rota, auto-detecção, arquivo, scan, lista nova) → Task 5.
- §7 plataformas/deps/permissões/leitor injetável → Task 4.
- §9 decisões (sempre lista nova; todos os itens; texto só itens; Fase 49/RF-33) → Tasks 2/3 e Task 6.
- Testes da §8 → Tasks 1, 2, 3, 5.

## Documentos relacionados
- Spec: `docs/superpowers/specs/2026-09-30-compartilhar-lista-design.md`
- [05 App Flutter](../05-app-flutter.md) · [10 Wireframes](../10-wireframes-telas.md) · [12 PRD](../12-prd.md) · [14 Tarefas](../14-tarefas.md)
