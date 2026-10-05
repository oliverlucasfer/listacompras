import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras/core/dominio/categoria.dart';
import 'package:lista_compras/core/l10n/categoria_l10n.dart';

import '../../support/app_teste.dart';

void main() {
  Future<Map<CategoriaItem, String>> rotulosPorLocale(
    WidgetTester tester,
    Locale locale,
  ) async {
    final rotulos = <CategoriaItem, String>{};
    await tester.pumpWidget(
      appTeste(
        Builder(
          builder: (context) {
            for (final categoria in CategoriaItem.values) {
              rotulos[categoria] = categoria.rotulo(context);
            }
            return const SizedBox.shrink();
          },
        ),
        locale: locale,
      ),
    );
    return rotulos;
  }

  testWidgets('deve_rotular_categorias_quando_locale_pt', (tester) async {
    expect(await rotulosPorLocale(tester, const Locale('pt')), {
      CategoriaItem.hortifruti: 'Hortifrúti',
      CategoriaItem.mercearia: 'Mercearia',
      CategoriaItem.frios: 'Frios',
      CategoriaItem.laticinios: 'Laticínios',
      CategoriaItem.congelados: 'Congelados',
      CategoriaItem.padaria: 'Padaria',
      CategoriaItem.bebidas: 'Bebidas',
      CategoriaItem.pet: 'Pet',
      CategoriaItem.limpeza: 'Limpeza',
      CategoriaItem.higiene: 'Higiene',
      CategoriaItem.outros: 'Outros',
    });
  });

  testWidgets('deve_rotular_categorias_quando_locale_en', (tester) async {
    expect(await rotulosPorLocale(tester, const Locale('en')), {
      CategoriaItem.hortifruti: 'Produce',
      CategoriaItem.mercearia: 'Grocery',
      CategoriaItem.frios: 'Deli',
      CategoriaItem.laticinios: 'Dairy',
      CategoriaItem.congelados: 'Frozen',
      CategoriaItem.padaria: 'Bakery',
      CategoriaItem.bebidas: 'Beverages',
      CategoriaItem.pet: 'Pet',
      CategoriaItem.limpeza: 'Cleaning',
      CategoriaItem.higiene: 'Personal care',
      CategoriaItem.outros: 'Other',
    });
  });

  testWidgets('deve_rotular_categorias_quando_locale_es', (tester) async {
    expect(await rotulosPorLocale(tester, const Locale('es')), {
      CategoriaItem.hortifruti: 'Frutas y verduras',
      CategoriaItem.mercearia: 'Abarrotes',
      CategoriaItem.frios: 'Fiambres',
      CategoriaItem.laticinios: 'Lácteos',
      CategoriaItem.congelados: 'Congelados',
      CategoriaItem.padaria: 'Panadería',
      CategoriaItem.bebidas: 'Bebidas',
      CategoriaItem.pet: 'Mascotas',
      CategoriaItem.limpeza: 'Limpieza',
      CategoriaItem.higiene: 'Higiene',
      CategoriaItem.outros: 'Otros',
    });
  });
}
