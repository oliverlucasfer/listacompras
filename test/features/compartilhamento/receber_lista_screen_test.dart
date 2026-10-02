import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lista_compras/core/dominio/categoria.dart';
import 'package:lista_compras/core/dominio/unidade.dart';
import 'package:lista_compras/core/l10n/app_strings.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/compartilhamento/domain/codec_lista.dart';
import 'package:lista_compras/features/compartilhamento/domain/leitor_qr.dart';
import 'package:lista_compras/features/compartilhamento/domain/lista_compartilhada.dart';
import 'package:lista_compras/features/compartilhamento/providers/compartilhamento_providers.dart';
import 'package:lista_compras/features/compartilhamento/ui/receber_lista_screen.dart';
import 'package:lista_compras/features/listas/providers/listas_providers.dart';

import '../../support/app_teste.dart';

class _FakeLeitorQr implements LeitorQr {
  _FakeLeitorQr(this.codigo);
  final String? codigo;
  @override
  Future<String?> escanear(BuildContext context) async => codigo;
}

Widget _app(AppDatabase db, {LeitorQr? leitorQr}) {
  final router = GoRouter(
    initialLocation: '/receber-lista',
    routes: [
      GoRoute(
        path: '/receber-lista',
        builder: (_, _) => const ReceberListaScreen(),
      ),
      GoRoute(
        path: '/lista/:id',
        builder: (_, _) => const Scaffold(body: Text('lista')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      if (leitorQr != null) leitorQrProvider.overrideWithValue(leitorQr),
    ],
    child: appTesteRouter(router),
  );
}

ListaCompartilhada _entrada(String titulo, String nome) => ListaCompartilhada(
  titulo: titulo,
  itens: [
    ItemCompartilhado(
      nome: nome,
      quantidade: 2,
      unidade: Unidade.kg,
      categoria: CategoriaItem.mercearia,
      concluido: false,
      ordem: 0,
    ),
  ],
);

Future<void> _colarEConfirmar(WidgetTester tester, String texto) async {
  await tester.enterText(find.byType(TextField).first, texto);
  await tester.tap(find.text(AppStrings.receberContinuar));
  await tester.pumpAndSettle();
  await tester.tap(find.text(AppStrings.receberConfirmar));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('deve_criar_lista_nova_quando_cola_codigo', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final codigo = codificarLista(_entrada('Recebida', 'Arroz'));

    await tester.pumpWidget(_app(db));
    await _colarEConfirmar(tester, codigo);

    final listas = await db.select(db.listaLocal).get();
    expect(listas, hasLength(1));
    expect(listas.single.titulo, 'Recebida');
  });

  testWidgets('deve_mostrar_erro_quando_codigo_invalido', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(_app(db));
    await tester.enterText(find.byType(TextField).first, 'ML1:***');
    await tester.tap(find.text(AppStrings.receberContinuar));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.receberInvalido), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('deve_criar_lista_nova_quando_cola_json', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final json = jsonEncode(_entrada('Recebida json', 'Feijão').toJson());

    await tester.pumpWidget(_app(db));
    await _colarEConfirmar(tester, json);

    final listas = await db.select(db.listaLocal).get();
    expect(listas, hasLength(1));
    expect(listas.single.titulo, 'Recebida json');
    final itens = await db.select(db.itemLocal).get();
    expect(itens.single.nome, 'Feijão');
  });

  testWidgets('deve_criar_lista_nova_quando_cola_texto', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(_app(db));
    await _colarEConfirmar(tester, '1kg de arroz');

    final listas = await db.select(db.listaLocal).get();
    expect(listas, hasLength(1));
    expect(listas.single.titulo, AppStrings.listaCompartilhada);
    final itens = await db.select(db.itemLocal).get();
    expect(itens.single.nome, 'Arroz');
    expect(itens.single.quantidade, 1);
    expect(itens.single.unidade, Unidade.kg.valor);
  });

  testWidgets('deve_permitir_editar_titulo_quando_recebe', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final codigo = codificarLista(_entrada('Recebida', 'Arroz'));

    await tester.pumpWidget(_app(db));
    await tester.enterText(find.byType(TextField).first, codigo);
    await tester.tap(find.text(AppStrings.receberContinuar));
    await tester.pumpAndSettle();

    final campoTitulo = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(campoTitulo, 'Minha lista nova');
    await tester.pump();
    await tester.tap(find.text(AppStrings.receberConfirmar));
    await tester.pumpAndSettle();

    final listas = await db.select(db.listaLocal).get();
    expect(listas, hasLength(1));
    expect(listas.single.titulo, 'Minha lista nova');
  });

  testWidgets('deve_criar_lista_quando_escaneia_qr', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final codigo = codificarLista(_entrada('Recebida qr', 'Uva'));

    await tester.pumpWidget(_app(db, leitorQr: _FakeLeitorQr(codigo)));
    await tester.tap(find.text(AppStrings.escanearQr));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.receberConfirmar));
    await tester.pumpAndSettle();

    final listas = await db.select(db.listaLocal).get();
    expect(listas, hasLength(1));
    expect(listas.single.titulo, 'Recebida qr');
    final itens = await db.select(db.itemLocal).get();
    expect(itens.single.nome, 'Uva');

    debugDefaultTargetPlatformOverride = null;
  });
}
