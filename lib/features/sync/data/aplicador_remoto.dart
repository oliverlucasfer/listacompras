import 'package:drift/drift.dart';

import '../../../drift/database.dart';
import '../../listas/domain/unidade.dart';

/// Aplica no Drift o registro remoto vencedor do LWW (doc 03 §5):
/// sobrescreve a linha inteira, incluindo tombstones — remoção remota
/// some da UI e não "ressuscita" (doc 03 §1.4).
class AplicadorRemoto {
  AplicadorRemoto(this._db);

  final AppDatabase _db;

  Future<void> aplicar(String tabela, Map<String, Object?> registro) {
    return switch (tabela) {
      'listas' => _aplicarLista(registro),
      'itens_lista' => _aplicarItem(registro),
      _ => throw ArgumentError('tabela desconhecida: $tabela'),
    };
  }

  Future<void> _aplicarLista(Map<String, Object?> r) {
    return _db
        .into(_db.listaLocal)
        .insertOnConflictUpdate(
          ListaLocalCompanion.insert(
            id: r['id'] as String,
            createdAt: _data(r['created_at']),
            updatedAt: _data(r['updated_at']),
            titulo: r['titulo'] as String,
            donoId: r['dono_id'] as String,
            deletadoEm: Value(_dataOpcional(r['deletado_em'])),
          ),
        );
  }

  Future<void> _aplicarItem(Map<String, Object?> r) {
    return _db
        .into(_db.itemLocal)
        .insertOnConflictUpdate(
          ItemLocalCompanion.insert(
            id: r['id'] as String,
            createdAt: _data(r['created_at']),
            updatedAt: _data(r['updated_at']),
            listaId: r['lista_id'] as String,
            nome: r['nome'] as String,
            quantidade: Value((r['quantidade'] as num).toDouble()),
            unidade: Value(Unidade.fromValor(r['unidade'] as String).valor),
            // Tolerância (spec F6 §7): linha gravada por app antigo
            // (1.0.0+2) chega sem a coluna → 'outros'.
            categoria: Value(
              r['categoria'] is String && (r['categoria'] as String).isNotEmpty
                  ? r['categoria'] as String
                  : 'outros',
            ),
            concluido: Value(r['concluido'] as bool? ?? false),
            ordem: Value((r['ordem'] as num?)?.toInt() ?? 0),
            deletadoEm: Value(_dataOpcional(r['deletado_em'])),
          ),
        );
  }

  DateTime _data(Object? iso) => DateTime.parse(iso! as String).toUtc();

  DateTime? _dataOpcional(Object? iso) =>
      iso is String ? DateTime.parse(iso).toUtc() : null;
}
