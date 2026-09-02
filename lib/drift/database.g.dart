// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $ListaLocalTable extends ListaLocal
    with TableInfo<$ListaLocalTable, ListaLocalData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ListaLocalTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tituloMeta = const VerificationMeta('titulo');
  @override
  late final GeneratedColumn<String> titulo = GeneratedColumn<String>(
    'titulo',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 120,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _donoIdMeta = const VerificationMeta('donoId');
  @override
  late final GeneratedColumn<String> donoId = GeneratedColumn<String>(
    'dono_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletadoEmMeta = const VerificationMeta(
    'deletadoEm',
  );
  @override
  late final GeneratedColumn<DateTime> deletadoEm = GeneratedColumn<DateTime>(
    'deletado_em',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    titulo,
    donoId,
    deletadoEm,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'lista_local';
  @override
  VerificationContext validateIntegrity(
    Insertable<ListaLocalData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('titulo')) {
      context.handle(
        _tituloMeta,
        titulo.isAcceptableOrUnknown(data['titulo']!, _tituloMeta),
      );
    } else if (isInserting) {
      context.missing(_tituloMeta);
    }
    if (data.containsKey('dono_id')) {
      context.handle(
        _donoIdMeta,
        donoId.isAcceptableOrUnknown(data['dono_id']!, _donoIdMeta),
      );
    } else if (isInserting) {
      context.missing(_donoIdMeta);
    }
    if (data.containsKey('deletado_em')) {
      context.handle(
        _deletadoEmMeta,
        deletadoEm.isAcceptableOrUnknown(data['deletado_em']!, _deletadoEmMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ListaLocalData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ListaLocalData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      titulo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}titulo'],
      )!,
      donoId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dono_id'],
      )!,
      deletadoEm: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deletado_em'],
      ),
    );
  }

  @override
  $ListaLocalTable createAlias(String alias) {
    return $ListaLocalTable(attachedDatabase, alias);
  }
}

class ListaLocalData extends DataClass implements Insertable<ListaLocalData> {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String titulo;
  final String donoId;
  final DateTime? deletadoEm;
  const ListaLocalData({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.titulo,
    required this.donoId,
    this.deletadoEm,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['titulo'] = Variable<String>(titulo);
    map['dono_id'] = Variable<String>(donoId);
    if (!nullToAbsent || deletadoEm != null) {
      map['deletado_em'] = Variable<DateTime>(deletadoEm);
    }
    return map;
  }

  ListaLocalCompanion toCompanion(bool nullToAbsent) {
    return ListaLocalCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      titulo: Value(titulo),
      donoId: Value(donoId),
      deletadoEm: deletadoEm == null && nullToAbsent
          ? const Value.absent()
          : Value(deletadoEm),
    );
  }

  factory ListaLocalData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ListaLocalData(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      titulo: serializer.fromJson<String>(json['titulo']),
      donoId: serializer.fromJson<String>(json['donoId']),
      deletadoEm: serializer.fromJson<DateTime?>(json['deletadoEm']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'titulo': serializer.toJson<String>(titulo),
      'donoId': serializer.toJson<String>(donoId),
      'deletadoEm': serializer.toJson<DateTime?>(deletadoEm),
    };
  }

  ListaLocalData copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? titulo,
    String? donoId,
    Value<DateTime?> deletadoEm = const Value.absent(),
  }) => ListaLocalData(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    titulo: titulo ?? this.titulo,
    donoId: donoId ?? this.donoId,
    deletadoEm: deletadoEm.present ? deletadoEm.value : this.deletadoEm,
  );
  ListaLocalData copyWithCompanion(ListaLocalCompanion data) {
    return ListaLocalData(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      titulo: data.titulo.present ? data.titulo.value : this.titulo,
      donoId: data.donoId.present ? data.donoId.value : this.donoId,
      deletadoEm: data.deletadoEm.present
          ? data.deletadoEm.value
          : this.deletadoEm,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ListaLocalData(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('titulo: $titulo, ')
          ..write('donoId: $donoId, ')
          ..write('deletadoEm: $deletadoEm')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, createdAt, updatedAt, titulo, donoId, deletadoEm);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ListaLocalData &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.titulo == this.titulo &&
          other.donoId == this.donoId &&
          other.deletadoEm == this.deletadoEm);
}

class ListaLocalCompanion extends UpdateCompanion<ListaLocalData> {
  final Value<String> id;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<String> titulo;
  final Value<String> donoId;
  final Value<DateTime?> deletadoEm;
  final Value<int> rowid;
  const ListaLocalCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.titulo = const Value.absent(),
    this.donoId = const Value.absent(),
    this.deletadoEm = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ListaLocalCompanion.insert({
    required String id,
    required DateTime createdAt,
    required DateTime updatedAt,
    required String titulo,
    required String donoId,
    this.deletadoEm = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       titulo = Value(titulo),
       donoId = Value(donoId);
  static Insertable<ListaLocalData> custom({
    Expression<String>? id,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? titulo,
    Expression<String>? donoId,
    Expression<DateTime>? deletadoEm,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (titulo != null) 'titulo': titulo,
      if (donoId != null) 'dono_id': donoId,
      if (deletadoEm != null) 'deletado_em': deletadoEm,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ListaLocalCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<String>? titulo,
    Value<String>? donoId,
    Value<DateTime?>? deletadoEm,
    Value<int>? rowid,
  }) {
    return ListaLocalCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      titulo: titulo ?? this.titulo,
      donoId: donoId ?? this.donoId,
      deletadoEm: deletadoEm ?? this.deletadoEm,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (titulo.present) {
      map['titulo'] = Variable<String>(titulo.value);
    }
    if (donoId.present) {
      map['dono_id'] = Variable<String>(donoId.value);
    }
    if (deletadoEm.present) {
      map['deletado_em'] = Variable<DateTime>(deletadoEm.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ListaLocalCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('titulo: $titulo, ')
          ..write('donoId: $donoId, ')
          ..write('deletadoEm: $deletadoEm, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ItemLocalTable extends ItemLocal
    with TableInfo<$ItemLocalTable, ItemLocalData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ItemLocalTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _listaIdMeta = const VerificationMeta(
    'listaId',
  );
  @override
  late final GeneratedColumn<String> listaId = GeneratedColumn<String>(
    'lista_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES lista_local (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _nomeMeta = const VerificationMeta('nome');
  @override
  late final GeneratedColumn<String> nome = GeneratedColumn<String>(
    'nome',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 120,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quantidadeMeta = const VerificationMeta(
    'quantidade',
  );
  @override
  late final GeneratedColumn<double> quantidade = GeneratedColumn<double>(
    'quantidade',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(1.0),
  );
  static const VerificationMeta _unidadeMeta = const VerificationMeta(
    'unidade',
  );
  @override
  late final GeneratedColumn<String> unidade = GeneratedColumn<String>(
    'unidade',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('un'),
  );
  static const VerificationMeta _concluidoMeta = const VerificationMeta(
    'concluido',
  );
  @override
  late final GeneratedColumn<bool> concluido = GeneratedColumn<bool>(
    'concluido',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("concluido" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _ordemMeta = const VerificationMeta('ordem');
  @override
  late final GeneratedColumn<int> ordem = GeneratedColumn<int>(
    'ordem',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _deletadoEmMeta = const VerificationMeta(
    'deletadoEm',
  );
  @override
  late final GeneratedColumn<DateTime> deletadoEm = GeneratedColumn<DateTime>(
    'deletado_em',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    listaId,
    nome,
    quantidade,
    unidade,
    concluido,
    ordem,
    deletadoEm,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'item_local';
  @override
  VerificationContext validateIntegrity(
    Insertable<ItemLocalData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('lista_id')) {
      context.handle(
        _listaIdMeta,
        listaId.isAcceptableOrUnknown(data['lista_id']!, _listaIdMeta),
      );
    } else if (isInserting) {
      context.missing(_listaIdMeta);
    }
    if (data.containsKey('nome')) {
      context.handle(
        _nomeMeta,
        nome.isAcceptableOrUnknown(data['nome']!, _nomeMeta),
      );
    } else if (isInserting) {
      context.missing(_nomeMeta);
    }
    if (data.containsKey('quantidade')) {
      context.handle(
        _quantidadeMeta,
        quantidade.isAcceptableOrUnknown(data['quantidade']!, _quantidadeMeta),
      );
    }
    if (data.containsKey('unidade')) {
      context.handle(
        _unidadeMeta,
        unidade.isAcceptableOrUnknown(data['unidade']!, _unidadeMeta),
      );
    }
    if (data.containsKey('concluido')) {
      context.handle(
        _concluidoMeta,
        concluido.isAcceptableOrUnknown(data['concluido']!, _concluidoMeta),
      );
    }
    if (data.containsKey('ordem')) {
      context.handle(
        _ordemMeta,
        ordem.isAcceptableOrUnknown(data['ordem']!, _ordemMeta),
      );
    }
    if (data.containsKey('deletado_em')) {
      context.handle(
        _deletadoEmMeta,
        deletadoEm.isAcceptableOrUnknown(data['deletado_em']!, _deletadoEmMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ItemLocalData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ItemLocalData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      listaId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lista_id'],
      )!,
      nome: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nome'],
      )!,
      quantidade: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}quantidade'],
      )!,
      unidade: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unidade'],
      )!,
      concluido: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}concluido'],
      )!,
      ordem: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ordem'],
      )!,
      deletadoEm: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deletado_em'],
      ),
    );
  }

  @override
  $ItemLocalTable createAlias(String alias) {
    return $ItemLocalTable(attachedDatabase, alias);
  }
}

class ItemLocalData extends DataClass implements Insertable<ItemLocalData> {
  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String listaId;
  final String nome;
  final double quantidade;
  final String unidade;
  final bool concluido;
  final int ordem;
  final DateTime? deletadoEm;
  const ItemLocalData({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.listaId,
    required this.nome,
    required this.quantidade,
    required this.unidade,
    required this.concluido,
    required this.ordem,
    this.deletadoEm,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['lista_id'] = Variable<String>(listaId);
    map['nome'] = Variable<String>(nome);
    map['quantidade'] = Variable<double>(quantidade);
    map['unidade'] = Variable<String>(unidade);
    map['concluido'] = Variable<bool>(concluido);
    map['ordem'] = Variable<int>(ordem);
    if (!nullToAbsent || deletadoEm != null) {
      map['deletado_em'] = Variable<DateTime>(deletadoEm);
    }
    return map;
  }

  ItemLocalCompanion toCompanion(bool nullToAbsent) {
    return ItemLocalCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      listaId: Value(listaId),
      nome: Value(nome),
      quantidade: Value(quantidade),
      unidade: Value(unidade),
      concluido: Value(concluido),
      ordem: Value(ordem),
      deletadoEm: deletadoEm == null && nullToAbsent
          ? const Value.absent()
          : Value(deletadoEm),
    );
  }

  factory ItemLocalData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ItemLocalData(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      listaId: serializer.fromJson<String>(json['listaId']),
      nome: serializer.fromJson<String>(json['nome']),
      quantidade: serializer.fromJson<double>(json['quantidade']),
      unidade: serializer.fromJson<String>(json['unidade']),
      concluido: serializer.fromJson<bool>(json['concluido']),
      ordem: serializer.fromJson<int>(json['ordem']),
      deletadoEm: serializer.fromJson<DateTime?>(json['deletadoEm']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'listaId': serializer.toJson<String>(listaId),
      'nome': serializer.toJson<String>(nome),
      'quantidade': serializer.toJson<double>(quantidade),
      'unidade': serializer.toJson<String>(unidade),
      'concluido': serializer.toJson<bool>(concluido),
      'ordem': serializer.toJson<int>(ordem),
      'deletadoEm': serializer.toJson<DateTime?>(deletadoEm),
    };
  }

  ItemLocalData copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? listaId,
    String? nome,
    double? quantidade,
    String? unidade,
    bool? concluido,
    int? ordem,
    Value<DateTime?> deletadoEm = const Value.absent(),
  }) => ItemLocalData(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    listaId: listaId ?? this.listaId,
    nome: nome ?? this.nome,
    quantidade: quantidade ?? this.quantidade,
    unidade: unidade ?? this.unidade,
    concluido: concluido ?? this.concluido,
    ordem: ordem ?? this.ordem,
    deletadoEm: deletadoEm.present ? deletadoEm.value : this.deletadoEm,
  );
  ItemLocalData copyWithCompanion(ItemLocalCompanion data) {
    return ItemLocalData(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      listaId: data.listaId.present ? data.listaId.value : this.listaId,
      nome: data.nome.present ? data.nome.value : this.nome,
      quantidade: data.quantidade.present
          ? data.quantidade.value
          : this.quantidade,
      unidade: data.unidade.present ? data.unidade.value : this.unidade,
      concluido: data.concluido.present ? data.concluido.value : this.concluido,
      ordem: data.ordem.present ? data.ordem.value : this.ordem,
      deletadoEm: data.deletadoEm.present
          ? data.deletadoEm.value
          : this.deletadoEm,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ItemLocalData(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('listaId: $listaId, ')
          ..write('nome: $nome, ')
          ..write('quantidade: $quantidade, ')
          ..write('unidade: $unidade, ')
          ..write('concluido: $concluido, ')
          ..write('ordem: $ordem, ')
          ..write('deletadoEm: $deletadoEm')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    updatedAt,
    listaId,
    nome,
    quantidade,
    unidade,
    concluido,
    ordem,
    deletadoEm,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ItemLocalData &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.listaId == this.listaId &&
          other.nome == this.nome &&
          other.quantidade == this.quantidade &&
          other.unidade == this.unidade &&
          other.concluido == this.concluido &&
          other.ordem == this.ordem &&
          other.deletadoEm == this.deletadoEm);
}

class ItemLocalCompanion extends UpdateCompanion<ItemLocalData> {
  final Value<String> id;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<String> listaId;
  final Value<String> nome;
  final Value<double> quantidade;
  final Value<String> unidade;
  final Value<bool> concluido;
  final Value<int> ordem;
  final Value<DateTime?> deletadoEm;
  final Value<int> rowid;
  const ItemLocalCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.listaId = const Value.absent(),
    this.nome = const Value.absent(),
    this.quantidade = const Value.absent(),
    this.unidade = const Value.absent(),
    this.concluido = const Value.absent(),
    this.ordem = const Value.absent(),
    this.deletadoEm = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ItemLocalCompanion.insert({
    required String id,
    required DateTime createdAt,
    required DateTime updatedAt,
    required String listaId,
    required String nome,
    this.quantidade = const Value.absent(),
    this.unidade = const Value.absent(),
    this.concluido = const Value.absent(),
    this.ordem = const Value.absent(),
    this.deletadoEm = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       listaId = Value(listaId),
       nome = Value(nome);
  static Insertable<ItemLocalData> custom({
    Expression<String>? id,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? listaId,
    Expression<String>? nome,
    Expression<double>? quantidade,
    Expression<String>? unidade,
    Expression<bool>? concluido,
    Expression<int>? ordem,
    Expression<DateTime>? deletadoEm,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (listaId != null) 'lista_id': listaId,
      if (nome != null) 'nome': nome,
      if (quantidade != null) 'quantidade': quantidade,
      if (unidade != null) 'unidade': unidade,
      if (concluido != null) 'concluido': concluido,
      if (ordem != null) 'ordem': ordem,
      if (deletadoEm != null) 'deletado_em': deletadoEm,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ItemLocalCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<String>? listaId,
    Value<String>? nome,
    Value<double>? quantidade,
    Value<String>? unidade,
    Value<bool>? concluido,
    Value<int>? ordem,
    Value<DateTime?>? deletadoEm,
    Value<int>? rowid,
  }) {
    return ItemLocalCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      listaId: listaId ?? this.listaId,
      nome: nome ?? this.nome,
      quantidade: quantidade ?? this.quantidade,
      unidade: unidade ?? this.unidade,
      concluido: concluido ?? this.concluido,
      ordem: ordem ?? this.ordem,
      deletadoEm: deletadoEm ?? this.deletadoEm,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (listaId.present) {
      map['lista_id'] = Variable<String>(listaId.value);
    }
    if (nome.present) {
      map['nome'] = Variable<String>(nome.value);
    }
    if (quantidade.present) {
      map['quantidade'] = Variable<double>(quantidade.value);
    }
    if (unidade.present) {
      map['unidade'] = Variable<String>(unidade.value);
    }
    if (concluido.present) {
      map['concluido'] = Variable<bool>(concluido.value);
    }
    if (ordem.present) {
      map['ordem'] = Variable<int>(ordem.value);
    }
    if (deletadoEm.present) {
      map['deletado_em'] = Variable<DateTime>(deletadoEm.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ItemLocalCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('listaId: $listaId, ')
          ..write('nome: $nome, ')
          ..write('quantidade: $quantidade, ')
          ..write('unidade: $unidade, ')
          ..write('concluido: $concluido, ')
          ..write('ordem: $ordem, ')
          ..write('deletadoEm: $deletadoEm, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MutacaoPendenteTable extends MutacaoPendente
    with TableInfo<$MutacaoPendenteTable, MutacaoPendenteData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MutacaoPendenteTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _tabelaMeta = const VerificationMeta('tabela');
  @override
  late final GeneratedColumn<String> tabela = GeneratedColumn<String>(
    'tabela',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _operacaoMeta = const VerificationMeta(
    'operacao',
  );
  @override
  late final GeneratedColumn<String> operacao = GeneratedColumn<String>(
    'operacao',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _registroIdMeta = const VerificationMeta(
    'registroId',
  );
  @override
  late final GeneratedColumn<String> registroId = GeneratedColumn<String>(
    'registro_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tsLocalMeta = const VerificationMeta(
    'tsLocal',
  );
  @override
  late final GeneratedColumn<DateTime> tsLocal = GeneratedColumn<DateTime>(
    'ts_local',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _listaIdMeta = const VerificationMeta(
    'listaId',
  );
  @override
  late final GeneratedColumn<String> listaId = GeneratedColumn<String>(
    'lista_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tentativasMeta = const VerificationMeta(
    'tentativas',
  );
  @override
  late final GeneratedColumn<int> tentativas = GeneratedColumn<int>(
    'tentativas',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tabela,
    operacao,
    registroId,
    payload,
    tsLocal,
    listaId,
    tentativas,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'mutacao_pendente';
  @override
  VerificationContext validateIntegrity(
    Insertable<MutacaoPendenteData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('tabela')) {
      context.handle(
        _tabelaMeta,
        tabela.isAcceptableOrUnknown(data['tabela']!, _tabelaMeta),
      );
    } else if (isInserting) {
      context.missing(_tabelaMeta);
    }
    if (data.containsKey('operacao')) {
      context.handle(
        _operacaoMeta,
        operacao.isAcceptableOrUnknown(data['operacao']!, _operacaoMeta),
      );
    } else if (isInserting) {
      context.missing(_operacaoMeta);
    }
    if (data.containsKey('registro_id')) {
      context.handle(
        _registroIdMeta,
        registroId.isAcceptableOrUnknown(data['registro_id']!, _registroIdMeta),
      );
    } else if (isInserting) {
      context.missing(_registroIdMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('ts_local')) {
      context.handle(
        _tsLocalMeta,
        tsLocal.isAcceptableOrUnknown(data['ts_local']!, _tsLocalMeta),
      );
    } else if (isInserting) {
      context.missing(_tsLocalMeta);
    }
    if (data.containsKey('lista_id')) {
      context.handle(
        _listaIdMeta,
        listaId.isAcceptableOrUnknown(data['lista_id']!, _listaIdMeta),
      );
    } else if (isInserting) {
      context.missing(_listaIdMeta);
    }
    if (data.containsKey('tentativas')) {
      context.handle(
        _tentativasMeta,
        tentativas.isAcceptableOrUnknown(data['tentativas']!, _tentativasMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MutacaoPendenteData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MutacaoPendenteData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      tabela: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tabela'],
      )!,
      operacao: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operacao'],
      )!,
      registroId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}registro_id'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      tsLocal: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ts_local'],
      )!,
      listaId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lista_id'],
      )!,
      tentativas: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tentativas'],
      )!,
    );
  }

  @override
  $MutacaoPendenteTable createAlias(String alias) {
    return $MutacaoPendenteTable(attachedDatabase, alias);
  }
}

class MutacaoPendenteData extends DataClass
    implements Insertable<MutacaoPendenteData> {
  final int id;
  final String tabela;
  final String operacao;
  final String registroId;
  final String payload;
  final DateTime tsLocal;
  final String listaId;
  final int tentativas;
  const MutacaoPendenteData({
    required this.id,
    required this.tabela,
    required this.operacao,
    required this.registroId,
    required this.payload,
    required this.tsLocal,
    required this.listaId,
    required this.tentativas,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['tabela'] = Variable<String>(tabela);
    map['operacao'] = Variable<String>(operacao);
    map['registro_id'] = Variable<String>(registroId);
    map['payload'] = Variable<String>(payload);
    map['ts_local'] = Variable<DateTime>(tsLocal);
    map['lista_id'] = Variable<String>(listaId);
    map['tentativas'] = Variable<int>(tentativas);
    return map;
  }

  MutacaoPendenteCompanion toCompanion(bool nullToAbsent) {
    return MutacaoPendenteCompanion(
      id: Value(id),
      tabela: Value(tabela),
      operacao: Value(operacao),
      registroId: Value(registroId),
      payload: Value(payload),
      tsLocal: Value(tsLocal),
      listaId: Value(listaId),
      tentativas: Value(tentativas),
    );
  }

  factory MutacaoPendenteData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MutacaoPendenteData(
      id: serializer.fromJson<int>(json['id']),
      tabela: serializer.fromJson<String>(json['tabela']),
      operacao: serializer.fromJson<String>(json['operacao']),
      registroId: serializer.fromJson<String>(json['registroId']),
      payload: serializer.fromJson<String>(json['payload']),
      tsLocal: serializer.fromJson<DateTime>(json['tsLocal']),
      listaId: serializer.fromJson<String>(json['listaId']),
      tentativas: serializer.fromJson<int>(json['tentativas']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'tabela': serializer.toJson<String>(tabela),
      'operacao': serializer.toJson<String>(operacao),
      'registroId': serializer.toJson<String>(registroId),
      'payload': serializer.toJson<String>(payload),
      'tsLocal': serializer.toJson<DateTime>(tsLocal),
      'listaId': serializer.toJson<String>(listaId),
      'tentativas': serializer.toJson<int>(tentativas),
    };
  }

  MutacaoPendenteData copyWith({
    int? id,
    String? tabela,
    String? operacao,
    String? registroId,
    String? payload,
    DateTime? tsLocal,
    String? listaId,
    int? tentativas,
  }) => MutacaoPendenteData(
    id: id ?? this.id,
    tabela: tabela ?? this.tabela,
    operacao: operacao ?? this.operacao,
    registroId: registroId ?? this.registroId,
    payload: payload ?? this.payload,
    tsLocal: tsLocal ?? this.tsLocal,
    listaId: listaId ?? this.listaId,
    tentativas: tentativas ?? this.tentativas,
  );
  MutacaoPendenteData copyWithCompanion(MutacaoPendenteCompanion data) {
    return MutacaoPendenteData(
      id: data.id.present ? data.id.value : this.id,
      tabela: data.tabela.present ? data.tabela.value : this.tabela,
      operacao: data.operacao.present ? data.operacao.value : this.operacao,
      registroId: data.registroId.present
          ? data.registroId.value
          : this.registroId,
      payload: data.payload.present ? data.payload.value : this.payload,
      tsLocal: data.tsLocal.present ? data.tsLocal.value : this.tsLocal,
      listaId: data.listaId.present ? data.listaId.value : this.listaId,
      tentativas: data.tentativas.present
          ? data.tentativas.value
          : this.tentativas,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MutacaoPendenteData(')
          ..write('id: $id, ')
          ..write('tabela: $tabela, ')
          ..write('operacao: $operacao, ')
          ..write('registroId: $registroId, ')
          ..write('payload: $payload, ')
          ..write('tsLocal: $tsLocal, ')
          ..write('listaId: $listaId, ')
          ..write('tentativas: $tentativas')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    tabela,
    operacao,
    registroId,
    payload,
    tsLocal,
    listaId,
    tentativas,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MutacaoPendenteData &&
          other.id == this.id &&
          other.tabela == this.tabela &&
          other.operacao == this.operacao &&
          other.registroId == this.registroId &&
          other.payload == this.payload &&
          other.tsLocal == this.tsLocal &&
          other.listaId == this.listaId &&
          other.tentativas == this.tentativas);
}

class MutacaoPendenteCompanion extends UpdateCompanion<MutacaoPendenteData> {
  final Value<int> id;
  final Value<String> tabela;
  final Value<String> operacao;
  final Value<String> registroId;
  final Value<String> payload;
  final Value<DateTime> tsLocal;
  final Value<String> listaId;
  final Value<int> tentativas;
  const MutacaoPendenteCompanion({
    this.id = const Value.absent(),
    this.tabela = const Value.absent(),
    this.operacao = const Value.absent(),
    this.registroId = const Value.absent(),
    this.payload = const Value.absent(),
    this.tsLocal = const Value.absent(),
    this.listaId = const Value.absent(),
    this.tentativas = const Value.absent(),
  });
  MutacaoPendenteCompanion.insert({
    this.id = const Value.absent(),
    required String tabela,
    required String operacao,
    required String registroId,
    required String payload,
    required DateTime tsLocal,
    required String listaId,
    this.tentativas = const Value.absent(),
  }) : tabela = Value(tabela),
       operacao = Value(operacao),
       registroId = Value(registroId),
       payload = Value(payload),
       tsLocal = Value(tsLocal),
       listaId = Value(listaId);
  static Insertable<MutacaoPendenteData> custom({
    Expression<int>? id,
    Expression<String>? tabela,
    Expression<String>? operacao,
    Expression<String>? registroId,
    Expression<String>? payload,
    Expression<DateTime>? tsLocal,
    Expression<String>? listaId,
    Expression<int>? tentativas,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tabela != null) 'tabela': tabela,
      if (operacao != null) 'operacao': operacao,
      if (registroId != null) 'registro_id': registroId,
      if (payload != null) 'payload': payload,
      if (tsLocal != null) 'ts_local': tsLocal,
      if (listaId != null) 'lista_id': listaId,
      if (tentativas != null) 'tentativas': tentativas,
    });
  }

  MutacaoPendenteCompanion copyWith({
    Value<int>? id,
    Value<String>? tabela,
    Value<String>? operacao,
    Value<String>? registroId,
    Value<String>? payload,
    Value<DateTime>? tsLocal,
    Value<String>? listaId,
    Value<int>? tentativas,
  }) {
    return MutacaoPendenteCompanion(
      id: id ?? this.id,
      tabela: tabela ?? this.tabela,
      operacao: operacao ?? this.operacao,
      registroId: registroId ?? this.registroId,
      payload: payload ?? this.payload,
      tsLocal: tsLocal ?? this.tsLocal,
      listaId: listaId ?? this.listaId,
      tentativas: tentativas ?? this.tentativas,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (tabela.present) {
      map['tabela'] = Variable<String>(tabela.value);
    }
    if (operacao.present) {
      map['operacao'] = Variable<String>(operacao.value);
    }
    if (registroId.present) {
      map['registro_id'] = Variable<String>(registroId.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (tsLocal.present) {
      map['ts_local'] = Variable<DateTime>(tsLocal.value);
    }
    if (listaId.present) {
      map['lista_id'] = Variable<String>(listaId.value);
    }
    if (tentativas.present) {
      map['tentativas'] = Variable<int>(tentativas.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MutacaoPendenteCompanion(')
          ..write('id: $id, ')
          ..write('tabela: $tabela, ')
          ..write('operacao: $operacao, ')
          ..write('registroId: $registroId, ')
          ..write('payload: $payload, ')
          ..write('tsLocal: $tsLocal, ')
          ..write('listaId: $listaId, ')
          ..write('tentativas: $tentativas')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ListaLocalTable listaLocal = $ListaLocalTable(this);
  late final $ItemLocalTable itemLocal = $ItemLocalTable(this);
  late final $MutacaoPendenteTable mutacaoPendente = $MutacaoPendenteTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    listaLocal,
    itemLocal,
    mutacaoPendente,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'lista_local',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('item_local', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$ListaLocalTableCreateCompanionBuilder =
    ListaLocalCompanion Function({
      required String id,
      required DateTime createdAt,
      required DateTime updatedAt,
      required String titulo,
      required String donoId,
      Value<DateTime?> deletadoEm,
      Value<int> rowid,
    });
typedef $$ListaLocalTableUpdateCompanionBuilder =
    ListaLocalCompanion Function({
      Value<String> id,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<String> titulo,
      Value<String> donoId,
      Value<DateTime?> deletadoEm,
      Value<int> rowid,
    });

final class $$ListaLocalTableReferences
    extends BaseReferences<_$AppDatabase, $ListaLocalTable, ListaLocalData> {
  $$ListaLocalTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ItemLocalTable, List<ItemLocalData>>
  _itemLocalRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.itemLocal,
    aliasName: 'lista_local__id__item_local__lista_id',
  );

  $$ItemLocalTableProcessedTableManager get itemLocalRefs {
    final manager = $$ItemLocalTableTableManager(
      $_db,
      $_db.itemLocal,
    ).filter((f) => f.listaId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_itemLocalRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ListaLocalTableFilterComposer
    extends Composer<_$AppDatabase, $ListaLocalTable> {
  $$ListaLocalTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get titulo => $composableBuilder(
    column: $table.titulo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get donoId => $composableBuilder(
    column: $table.donoId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletadoEm => $composableBuilder(
    column: $table.deletadoEm,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> itemLocalRefs(
    Expression<bool> Function($$ItemLocalTableFilterComposer f) f,
  ) {
    final $$ItemLocalTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.itemLocal,
      getReferencedColumn: (t) => t.listaId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemLocalTableFilterComposer(
            $db: $db,
            $table: $db.itemLocal,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ListaLocalTableOrderingComposer
    extends Composer<_$AppDatabase, $ListaLocalTable> {
  $$ListaLocalTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get titulo => $composableBuilder(
    column: $table.titulo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get donoId => $composableBuilder(
    column: $table.donoId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletadoEm => $composableBuilder(
    column: $table.deletadoEm,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ListaLocalTableAnnotationComposer
    extends Composer<_$AppDatabase, $ListaLocalTable> {
  $$ListaLocalTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get titulo =>
      $composableBuilder(column: $table.titulo, builder: (column) => column);

  GeneratedColumn<String> get donoId =>
      $composableBuilder(column: $table.donoId, builder: (column) => column);

  GeneratedColumn<DateTime> get deletadoEm => $composableBuilder(
    column: $table.deletadoEm,
    builder: (column) => column,
  );

  Expression<T> itemLocalRefs<T extends Object>(
    Expression<T> Function($$ItemLocalTableAnnotationComposer a) f,
  ) {
    final $$ItemLocalTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.itemLocal,
      getReferencedColumn: (t) => t.listaId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemLocalTableAnnotationComposer(
            $db: $db,
            $table: $db.itemLocal,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ListaLocalTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ListaLocalTable,
          ListaLocalData,
          $$ListaLocalTableFilterComposer,
          $$ListaLocalTableOrderingComposer,
          $$ListaLocalTableAnnotationComposer,
          $$ListaLocalTableCreateCompanionBuilder,
          $$ListaLocalTableUpdateCompanionBuilder,
          (ListaLocalData, $$ListaLocalTableReferences),
          ListaLocalData,
          PrefetchHooks Function({bool itemLocalRefs})
        > {
  $$ListaLocalTableTableManager(_$AppDatabase db, $ListaLocalTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ListaLocalTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ListaLocalTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ListaLocalTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String> titulo = const Value.absent(),
                Value<String> donoId = const Value.absent(),
                Value<DateTime?> deletadoEm = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ListaLocalCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                titulo: titulo,
                donoId: donoId,
                deletadoEm: deletadoEm,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required DateTime createdAt,
                required DateTime updatedAt,
                required String titulo,
                required String donoId,
                Value<DateTime?> deletadoEm = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ListaLocalCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                titulo: titulo,
                donoId: donoId,
                deletadoEm: deletadoEm,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ListaLocalTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({itemLocalRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (itemLocalRefs) db.itemLocal],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (itemLocalRefs)
                    await $_getPrefetchedData<
                      ListaLocalData,
                      $ListaLocalTable,
                      ItemLocalData
                    >(
                      currentTable: table,
                      referencedTable: $$ListaLocalTableReferences
                          ._itemLocalRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$ListaLocalTableReferences(
                            db,
                            table,
                            p0,
                          ).itemLocalRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.listaId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$ListaLocalTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ListaLocalTable,
      ListaLocalData,
      $$ListaLocalTableFilterComposer,
      $$ListaLocalTableOrderingComposer,
      $$ListaLocalTableAnnotationComposer,
      $$ListaLocalTableCreateCompanionBuilder,
      $$ListaLocalTableUpdateCompanionBuilder,
      (ListaLocalData, $$ListaLocalTableReferences),
      ListaLocalData,
      PrefetchHooks Function({bool itemLocalRefs})
    >;
typedef $$ItemLocalTableCreateCompanionBuilder =
    ItemLocalCompanion Function({
      required String id,
      required DateTime createdAt,
      required DateTime updatedAt,
      required String listaId,
      required String nome,
      Value<double> quantidade,
      Value<String> unidade,
      Value<bool> concluido,
      Value<int> ordem,
      Value<DateTime?> deletadoEm,
      Value<int> rowid,
    });
typedef $$ItemLocalTableUpdateCompanionBuilder =
    ItemLocalCompanion Function({
      Value<String> id,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<String> listaId,
      Value<String> nome,
      Value<double> quantidade,
      Value<String> unidade,
      Value<bool> concluido,
      Value<int> ordem,
      Value<DateTime?> deletadoEm,
      Value<int> rowid,
    });

final class $$ItemLocalTableReferences
    extends BaseReferences<_$AppDatabase, $ItemLocalTable, ItemLocalData> {
  $$ItemLocalTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ListaLocalTable _listaIdTable(_$AppDatabase db) =>
      db.listaLocal.createAlias('item_local__lista_id__lista_local__id');

  $$ListaLocalTableProcessedTableManager get listaId {
    final $_column = $_itemColumn<String>('lista_id')!;

    final manager = $$ListaLocalTableTableManager(
      $_db,
      $_db.listaLocal,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_listaIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ItemLocalTableFilterComposer
    extends Composer<_$AppDatabase, $ItemLocalTable> {
  $$ItemLocalTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nome => $composableBuilder(
    column: $table.nome,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get quantidade => $composableBuilder(
    column: $table.quantidade,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unidade => $composableBuilder(
    column: $table.unidade,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get concluido => $composableBuilder(
    column: $table.concluido,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ordem => $composableBuilder(
    column: $table.ordem,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletadoEm => $composableBuilder(
    column: $table.deletadoEm,
    builder: (column) => ColumnFilters(column),
  );

  $$ListaLocalTableFilterComposer get listaId {
    final $$ListaLocalTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.listaId,
      referencedTable: $db.listaLocal,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ListaLocalTableFilterComposer(
            $db: $db,
            $table: $db.listaLocal,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ItemLocalTableOrderingComposer
    extends Composer<_$AppDatabase, $ItemLocalTable> {
  $$ItemLocalTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nome => $composableBuilder(
    column: $table.nome,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get quantidade => $composableBuilder(
    column: $table.quantidade,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unidade => $composableBuilder(
    column: $table.unidade,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get concluido => $composableBuilder(
    column: $table.concluido,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ordem => $composableBuilder(
    column: $table.ordem,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletadoEm => $composableBuilder(
    column: $table.deletadoEm,
    builder: (column) => ColumnOrderings(column),
  );

  $$ListaLocalTableOrderingComposer get listaId {
    final $$ListaLocalTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.listaId,
      referencedTable: $db.listaLocal,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ListaLocalTableOrderingComposer(
            $db: $db,
            $table: $db.listaLocal,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ItemLocalTableAnnotationComposer
    extends Composer<_$AppDatabase, $ItemLocalTable> {
  $$ItemLocalTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get nome =>
      $composableBuilder(column: $table.nome, builder: (column) => column);

  GeneratedColumn<double> get quantidade => $composableBuilder(
    column: $table.quantidade,
    builder: (column) => column,
  );

  GeneratedColumn<String> get unidade =>
      $composableBuilder(column: $table.unidade, builder: (column) => column);

  GeneratedColumn<bool> get concluido =>
      $composableBuilder(column: $table.concluido, builder: (column) => column);

  GeneratedColumn<int> get ordem =>
      $composableBuilder(column: $table.ordem, builder: (column) => column);

  GeneratedColumn<DateTime> get deletadoEm => $composableBuilder(
    column: $table.deletadoEm,
    builder: (column) => column,
  );

  $$ListaLocalTableAnnotationComposer get listaId {
    final $$ListaLocalTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.listaId,
      referencedTable: $db.listaLocal,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ListaLocalTableAnnotationComposer(
            $db: $db,
            $table: $db.listaLocal,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ItemLocalTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ItemLocalTable,
          ItemLocalData,
          $$ItemLocalTableFilterComposer,
          $$ItemLocalTableOrderingComposer,
          $$ItemLocalTableAnnotationComposer,
          $$ItemLocalTableCreateCompanionBuilder,
          $$ItemLocalTableUpdateCompanionBuilder,
          (ItemLocalData, $$ItemLocalTableReferences),
          ItemLocalData,
          PrefetchHooks Function({bool listaId})
        > {
  $$ItemLocalTableTableManager(_$AppDatabase db, $ItemLocalTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ItemLocalTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ItemLocalTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ItemLocalTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String> listaId = const Value.absent(),
                Value<String> nome = const Value.absent(),
                Value<double> quantidade = const Value.absent(),
                Value<String> unidade = const Value.absent(),
                Value<bool> concluido = const Value.absent(),
                Value<int> ordem = const Value.absent(),
                Value<DateTime?> deletadoEm = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ItemLocalCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                listaId: listaId,
                nome: nome,
                quantidade: quantidade,
                unidade: unidade,
                concluido: concluido,
                ordem: ordem,
                deletadoEm: deletadoEm,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required DateTime createdAt,
                required DateTime updatedAt,
                required String listaId,
                required String nome,
                Value<double> quantidade = const Value.absent(),
                Value<String> unidade = const Value.absent(),
                Value<bool> concluido = const Value.absent(),
                Value<int> ordem = const Value.absent(),
                Value<DateTime?> deletadoEm = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ItemLocalCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                listaId: listaId,
                nome: nome,
                quantidade: quantidade,
                unidade: unidade,
                concluido: concluido,
                ordem: ordem,
                deletadoEm: deletadoEm,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ItemLocalTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({listaId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (listaId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.listaId,
                                referencedTable: $$ItemLocalTableReferences
                                    ._listaIdTable(db),
                                referencedColumn: $$ItemLocalTableReferences
                                    ._listaIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ItemLocalTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ItemLocalTable,
      ItemLocalData,
      $$ItemLocalTableFilterComposer,
      $$ItemLocalTableOrderingComposer,
      $$ItemLocalTableAnnotationComposer,
      $$ItemLocalTableCreateCompanionBuilder,
      $$ItemLocalTableUpdateCompanionBuilder,
      (ItemLocalData, $$ItemLocalTableReferences),
      ItemLocalData,
      PrefetchHooks Function({bool listaId})
    >;
typedef $$MutacaoPendenteTableCreateCompanionBuilder =
    MutacaoPendenteCompanion Function({
      Value<int> id,
      required String tabela,
      required String operacao,
      required String registroId,
      required String payload,
      required DateTime tsLocal,
      required String listaId,
      Value<int> tentativas,
    });
typedef $$MutacaoPendenteTableUpdateCompanionBuilder =
    MutacaoPendenteCompanion Function({
      Value<int> id,
      Value<String> tabela,
      Value<String> operacao,
      Value<String> registroId,
      Value<String> payload,
      Value<DateTime> tsLocal,
      Value<String> listaId,
      Value<int> tentativas,
    });

class $$MutacaoPendenteTableFilterComposer
    extends Composer<_$AppDatabase, $MutacaoPendenteTable> {
  $$MutacaoPendenteTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tabela => $composableBuilder(
    column: $table.tabela,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operacao => $composableBuilder(
    column: $table.operacao,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get registroId => $composableBuilder(
    column: $table.registroId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get tsLocal => $composableBuilder(
    column: $table.tsLocal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get listaId => $composableBuilder(
    column: $table.listaId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tentativas => $composableBuilder(
    column: $table.tentativas,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MutacaoPendenteTableOrderingComposer
    extends Composer<_$AppDatabase, $MutacaoPendenteTable> {
  $$MutacaoPendenteTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tabela => $composableBuilder(
    column: $table.tabela,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operacao => $composableBuilder(
    column: $table.operacao,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get registroId => $composableBuilder(
    column: $table.registroId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get tsLocal => $composableBuilder(
    column: $table.tsLocal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get listaId => $composableBuilder(
    column: $table.listaId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tentativas => $composableBuilder(
    column: $table.tentativas,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MutacaoPendenteTableAnnotationComposer
    extends Composer<_$AppDatabase, $MutacaoPendenteTable> {
  $$MutacaoPendenteTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tabela =>
      $composableBuilder(column: $table.tabela, builder: (column) => column);

  GeneratedColumn<String> get operacao =>
      $composableBuilder(column: $table.operacao, builder: (column) => column);

  GeneratedColumn<String> get registroId => $composableBuilder(
    column: $table.registroId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get tsLocal =>
      $composableBuilder(column: $table.tsLocal, builder: (column) => column);

  GeneratedColumn<String> get listaId =>
      $composableBuilder(column: $table.listaId, builder: (column) => column);

  GeneratedColumn<int> get tentativas => $composableBuilder(
    column: $table.tentativas,
    builder: (column) => column,
  );
}

class $$MutacaoPendenteTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MutacaoPendenteTable,
          MutacaoPendenteData,
          $$MutacaoPendenteTableFilterComposer,
          $$MutacaoPendenteTableOrderingComposer,
          $$MutacaoPendenteTableAnnotationComposer,
          $$MutacaoPendenteTableCreateCompanionBuilder,
          $$MutacaoPendenteTableUpdateCompanionBuilder,
          (
            MutacaoPendenteData,
            BaseReferences<
              _$AppDatabase,
              $MutacaoPendenteTable,
              MutacaoPendenteData
            >,
          ),
          MutacaoPendenteData,
          PrefetchHooks Function()
        > {
  $$MutacaoPendenteTableTableManager(
    _$AppDatabase db,
    $MutacaoPendenteTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MutacaoPendenteTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MutacaoPendenteTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MutacaoPendenteTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> tabela = const Value.absent(),
                Value<String> operacao = const Value.absent(),
                Value<String> registroId = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<DateTime> tsLocal = const Value.absent(),
                Value<String> listaId = const Value.absent(),
                Value<int> tentativas = const Value.absent(),
              }) => MutacaoPendenteCompanion(
                id: id,
                tabela: tabela,
                operacao: operacao,
                registroId: registroId,
                payload: payload,
                tsLocal: tsLocal,
                listaId: listaId,
                tentativas: tentativas,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String tabela,
                required String operacao,
                required String registroId,
                required String payload,
                required DateTime tsLocal,
                required String listaId,
                Value<int> tentativas = const Value.absent(),
              }) => MutacaoPendenteCompanion.insert(
                id: id,
                tabela: tabela,
                operacao: operacao,
                registroId: registroId,
                payload: payload,
                tsLocal: tsLocal,
                listaId: listaId,
                tentativas: tentativas,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MutacaoPendenteTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MutacaoPendenteTable,
      MutacaoPendenteData,
      $$MutacaoPendenteTableFilterComposer,
      $$MutacaoPendenteTableOrderingComposer,
      $$MutacaoPendenteTableAnnotationComposer,
      $$MutacaoPendenteTableCreateCompanionBuilder,
      $$MutacaoPendenteTableUpdateCompanionBuilder,
      (
        MutacaoPendenteData,
        BaseReferences<
          _$AppDatabase,
          $MutacaoPendenteTable,
          MutacaoPendenteData
        >,
      ),
      MutacaoPendenteData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ListaLocalTableTableManager get listaLocal =>
      $$ListaLocalTableTableManager(_db, _db.listaLocal);
  $$ItemLocalTableTableManager get itemLocal =>
      $$ItemLocalTableTableManager(_db, _db.itemLocal);
  $$MutacaoPendenteTableTableManager get mutacaoPendente =>
      $$MutacaoPendenteTableTableManager(_db, _db.mutacaoPendente);
}
