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
