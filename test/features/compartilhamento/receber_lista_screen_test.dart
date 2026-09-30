import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lista_compras/core/dominio/categoria.dart';
import 'package:lista_compras/core/dominio/unidade.dart';
import 'package:lista_compras/core/l10n/app_strings.dart';
import 'package:lista_compras/drift/database.dart';
import 'package:lista_compras/features/compartilhamento/domain/codec_lista.dart';
import 'package:lista_compras/features/compartilhamento/domain/lista_compartilhada.dart';
import 'package:lista_compras/features/compartilhamento/ui/receber_lista_screen.dart';
import 'package:lista_compras/features/listas/providers/listas_providers.dart';

Widget _app(AppDatabase db) {
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
    overrides: [appDatabaseProvider.overrideWithValue(db)],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('deve_criar_lista_nova_quando_cola_codigo', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final codigo = codificarLista(
      const ListaCompartilhada(
        titulo: 'Recebida',
        itens: [
          ItemCompartilhado(
            nome: 'Arroz',
            quantidade: 2,
            unidade: Unidade.kg,
            categoria: CategoriaItem.mercearia,
            concluido: false,
            ordem: 0,
          ),
        ],
      ),
    );

    await tester.pumpWidget(_app(db));
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
    await tester.pumpWidget(_app(db));
    await tester.enterText(find.byType(TextField).first, 'ML1:***');
    await tester.tap(find.text('Criar lista'));
    await tester.pumpAndSettle();
    expect(find.text('Código ou arquivo inválido.'), findsOneWidget);
  });

  testWidgets('deve_criar_lista_nova_quando_cola_json', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final json = jsonEncode(
      const ListaCompartilhada(
        titulo: 'Recebida json',
        itens: [
          ItemCompartilhado(
            nome: 'Feijão',
            quantidade: 3,
            unidade: Unidade.pacote,
            categoria: CategoriaItem.mercearia,
            concluido: false,
            ordem: 0,
          ),
        ],
      ).toJson(),
    );

    await tester.pumpWidget(_app(db));
    await tester.enterText(find.byType(TextField).first, json);
    await tester.tap(find.text('Criar lista'));
    await tester.pumpAndSettle();

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
    await tester.enterText(find.byType(TextField).first, '1kg de arroz');
    await tester.tap(find.text('Criar lista'));
    await tester.pumpAndSettle();

    final listas = await db.select(db.listaLocal).get();
    expect(listas, hasLength(1));
    expect(listas.single.titulo, AppStrings.listaCompartilhada);
    final itens = await db.select(db.itemLocal).get();
    expect(itens.single.nome, 'Arroz');
    expect(itens.single.quantidade, 1);
    expect(itens.single.unidade, Unidade.kg.valor);
  });
}
