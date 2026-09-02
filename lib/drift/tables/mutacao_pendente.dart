import 'package:drift/drift.dart';

/// Fila de mutações pendentes (doc 03 §3). Drenada por lista, em ordem;
/// coalescing mantém apenas a última mutação por registro.
class MutacaoPendente extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get tabela => text()(); // 'listas' | 'itens_lista'
  TextColumn get operacao => text()(); // 'INSERT' | 'UPDATE' | 'DELETE_SOFT'
  TextColumn get registroId => text()(); // UUID da entidade
  TextColumn get payload => text()(); // JSON: estado completo do registro
  DateTimeColumn get tsLocal => dateTime()(); // vira updated_at no flush
  TextColumn get listaId => text()(); // agrupamento/dreno por lista
  IntColumn get tentativas => integer().withDefault(const Constant(0))();
}
