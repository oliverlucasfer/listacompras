import 'dart:convert';

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
    final codigo =
        'ML1:${_base64('{"tipo":"minhas-listas/lista","versao":9,"titulo":"x","itens":[]}')}';
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
          {
            'nome': '  ',
            'quantidade': 1,
            'unidade': 'un',
            'categoria': 'outros',
            'concluido': false,
            'ordem': 0,
            'preco_centavos': null,
          },
        ],
      }),
      throwsA(isA<CompartilhamentoInvalidoException>()),
    );
  });

  test('deve_gerar_texto_uma_linha_por_item_quando_exporta', () {
    expect(gerarTextoLista(_exemplo()), '2 kg arroz\n1 un Leite');
  });
}

String _base64(String s) => base64Url.encode(utf8.encode(s));
