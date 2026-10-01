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
  static const VerificationMeta _arquivadaEmMeta = const VerificationMeta(
    'arquivadaEm',
  );
  @override
  late final GeneratedColumn<DateTime> arquivadaEm = GeneratedColumn<DateTime>(
    'arquivada_em',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _orcamentoCentavosMeta = const VerificationMeta(
    'orcamentoCentavos',
  );
  @override
  late final GeneratedColumn<int> orcamentoCentavos = GeneratedColumn<int>(
    'orcamento_centavos',
    aliasedName,
    true,
    type: DriftSqlType.int,
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
    arquivadaEm,
    orcamentoCentavos,
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
    if (data.containsKey('arquivada_em')) {
      context.handle(
        _arquivadaEmMeta,
        arquivadaEm.isAcceptableOrUnknown(
          data['arquivada_em']!,
          _arquivadaEmMeta,
        ),
      );
    }
    if (data.containsKey('orcamento_centavos')) {
      context.handle(
        _orcamentoCentavosMeta,
        orcamentoCentavos.isAcceptableOrUnknown(
          data['orcamento_centavos']!,
          _orcamentoCentavosMeta,
        ),
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
      arquivadaEm: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}arquivada_em'],
      ),
      orcamentoCentavos: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}orcamento_centavos'],
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
  final DateTime? arquivadaEm;
  final int? orcamentoCentavos;
  const ListaLocalData({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.titulo,
    required this.donoId,
    this.deletadoEm,
    this.arquivadaEm,
    this.orcamentoCentavos,
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
    if (!nullToAbsent || arquivadaEm != null) {
      map['arquivada_em'] = Variable<DateTime>(arquivadaEm);
    }
    if (!nullToAbsent || orcamentoCentavos != null) {
      map['orcamento_centavos'] = Variable<int>(orcamentoCentavos);
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
      arquivadaEm: arquivadaEm == null && nullToAbsent
          ? const Value.absent()
          : Value(arquivadaEm),
      orcamentoCentavos: orcamentoCentavos == null && nullToAbsent
          ? const Value.absent()
          : Value(orcamentoCentavos),
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
      arquivadaEm: serializer.fromJson<DateTime?>(json['arquivadaEm']),
      orcamentoCentavos: serializer.fromJson<int?>(json['orcamentoCentavos']),
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
      'arquivadaEm': serializer.toJson<DateTime?>(arquivadaEm),
      'orcamentoCentavos': serializer.toJson<int?>(orcamentoCentavos),
    };
  }

  ListaLocalData copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? titulo,
    String? donoId,
    Value<DateTime?> deletadoEm = const Value.absent(),
    Value<DateTime?> arquivadaEm = const Value.absent(),
    Value<int?> orcamentoCentavos = const Value.absent(),
  }) => ListaLocalData(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    titulo: titulo ?? this.titulo,
    donoId: donoId ?? this.donoId,
    deletadoEm: deletadoEm.present ? deletadoEm.value : this.deletadoEm,
    arquivadaEm: arquivadaEm.present ? arquivadaEm.value : this.arquivadaEm,
    orcamentoCentavos: orcamentoCentavos.present
        ? orcamentoCentavos.value
        : this.orcamentoCentavos,
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
      arquivadaEm: data.arquivadaEm.present
          ? data.arquivadaEm.value
          : this.arquivadaEm,
      orcamentoCentavos: data.orcamentoCentavos.present
          ? data.orcamentoCentavos.value
          : this.orcamentoCentavos,
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
          ..write('deletadoEm: $deletadoEm, ')
          ..write('arquivadaEm: $arquivadaEm, ')
          ..write('orcamentoCentavos: $orcamentoCentavos')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    updatedAt,
    titulo,
    donoId,
    deletadoEm,
    arquivadaEm,
    orcamentoCentavos,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ListaLocalData &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.titulo == this.titulo &&
          other.donoId == this.donoId &&
          other.deletadoEm == this.deletadoEm &&
          other.arquivadaEm == this.arquivadaEm &&
          other.orcamentoCentavos == this.orcamentoCentavos);
}

class ListaLocalCompanion extends UpdateCompanion<ListaLocalData> {
  final Value<String> id;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<String> titulo;
  final Value<String> donoId;
  final Value<DateTime?> deletadoEm;
  final Value<DateTime?> arquivadaEm;
  final Value<int?> orcamentoCentavos;
  final Value<int> rowid;
  const ListaLocalCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.titulo = const Value.absent(),
    this.donoId = const Value.absent(),
    this.deletadoEm = const Value.absent(),
    this.arquivadaEm = const Value.absent(),
    this.orcamentoCentavos = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ListaLocalCompanion.insert({
    required String id,
    required DateTime createdAt,
    required DateTime updatedAt,
    required String titulo,
    required String donoId,
    this.deletadoEm = const Value.absent(),
    this.arquivadaEm = const Value.absent(),
    this.orcamentoCentavos = const Value.absent(),
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
    Expression<DateTime>? arquivadaEm,
    Expression<int>? orcamentoCentavos,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (titulo != null) 'titulo': titulo,
      if (donoId != null) 'dono_id': donoId,
      if (deletadoEm != null) 'deletado_em': deletadoEm,
      if (arquivadaEm != null) 'arquivada_em': arquivadaEm,
      if (orcamentoCentavos != null) 'orcamento_centavos': orcamentoCentavos,
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
    Value<DateTime?>? arquivadaEm,
    Value<int?>? orcamentoCentavos,
    Value<int>? rowid,
  }) {
    return ListaLocalCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      titulo: titulo ?? this.titulo,
      donoId: donoId ?? this.donoId,
      deletadoEm: deletadoEm ?? this.deletadoEm,
      arquivadaEm: arquivadaEm ?? this.arquivadaEm,
      orcamentoCentavos: orcamentoCentavos ?? this.orcamentoCentavos,
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
    if (arquivadaEm.present) {
      map['arquivada_em'] = Variable<DateTime>(arquivadaEm.value);
    }
    if (orcamentoCentavos.present) {
      map['orcamento_centavos'] = Variable<int>(orcamentoCentavos.value);
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
          ..write('arquivadaEm: $arquivadaEm, ')
          ..write('orcamentoCentavos: $orcamentoCentavos, ')
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
  static const VerificationMeta _categoriaMeta = const VerificationMeta(
    'categoria',
  );
  @override
  late final GeneratedColumn<String> categoria = GeneratedColumn<String>(
    'categoria',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('outros'),
  );
  static const VerificationMeta _precoCentavosMeta = const VerificationMeta(
    'precoCentavos',
  );
  @override
  late final GeneratedColumn<int> precoCentavos = GeneratedColumn<int>(
    'preco_centavos',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
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
    categoria,
    precoCentavos,
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
    if (data.containsKey('categoria')) {
      context.handle(
        _categoriaMeta,
        categoria.isAcceptableOrUnknown(data['categoria']!, _categoriaMeta),
      );
    }
    if (data.containsKey('preco_centavos')) {
      context.handle(
        _precoCentavosMeta,
        precoCentavos.isAcceptableOrUnknown(
          data['preco_centavos']!,
          _precoCentavosMeta,
        ),
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
      categoria: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}categoria'],
      )!,
      precoCentavos: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}preco_centavos'],
      ),
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
  final String categoria;
  final int? precoCentavos;
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
    required this.categoria,
    this.precoCentavos,
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
    map['categoria'] = Variable<String>(categoria);
    if (!nullToAbsent || precoCentavos != null) {
      map['preco_centavos'] = Variable<int>(precoCentavos);
    }
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
      categoria: Value(categoria),
      precoCentavos: precoCentavos == null && nullToAbsent
          ? const Value.absent()
          : Value(precoCentavos),
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
      categoria: serializer.fromJson<String>(json['categoria']),
      precoCentavos: serializer.fromJson<int?>(json['precoCentavos']),
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
      'categoria': serializer.toJson<String>(categoria),
      'precoCentavos': serializer.toJson<int?>(precoCentavos),
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
    String? categoria,
    Value<int?> precoCentavos = const Value.absent(),
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
    categoria: categoria ?? this.categoria,
    precoCentavos: precoCentavos.present
        ? precoCentavos.value
        : this.precoCentavos,
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
      categoria: data.categoria.present ? data.categoria.value : this.categoria,
      precoCentavos: data.precoCentavos.present
          ? data.precoCentavos.value
          : this.precoCentavos,
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
          ..write('categoria: $categoria, ')
          ..write('precoCentavos: $precoCentavos, ')
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
    categoria,
    precoCentavos,
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
          other.categoria == this.categoria &&
          other.precoCentavos == this.precoCentavos &&
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
  final Value<String> categoria;
  final Value<int?> precoCentavos;
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
    this.categoria = const Value.absent(),
    this.precoCentavos = const Value.absent(),
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
    this.categoria = const Value.absent(),
    this.precoCentavos = const Value.absent(),
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
    Expression<String>? categoria,
    Expression<int>? precoCentavos,
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
      if (categoria != null) 'categoria': categoria,
      if (precoCentavos != null) 'preco_centavos': precoCentavos,
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
    Value<String>? categoria,
    Value<int?>? precoCentavos,
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
      categoria: categoria ?? this.categoria,
      precoCentavos: precoCentavos ?? this.precoCentavos,
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
    if (categoria.present) {
      map['categoria'] = Variable<String>(categoria.value);
    }
    if (precoCentavos.present) {
      map['preco_centavos'] = Variable<int>(precoCentavos.value);
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
          ..write('categoria: $categoria, ')
          ..write('precoCentavos: $precoCentavos, ')
          ..write('concluido: $concluido, ')
          ..write('ordem: $ordem, ')
          ..write('deletadoEm: $deletadoEm, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HistoricoPrecoLocalTable extends HistoricoPrecoLocal
    with TableInfo<$HistoricoPrecoLocalTable, HistoricoPrecoLocalData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HistoricoPrecoLocalTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _nomeNormalizadoMeta = const VerificationMeta(
    'nomeNormalizado',
  );
  @override
  late final GeneratedColumn<String> nomeNormalizado = GeneratedColumn<String>(
    'nome_normalizado',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _precoCentavosMeta = const VerificationMeta(
    'precoCentavos',
  );
  @override
  late final GeneratedColumn<int> precoCentavos = GeneratedColumn<int>(
    'preco_centavos',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
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
    requiredDuringInsert: true,
  );
  static const VerificationMeta _registradoEmMeta = const VerificationMeta(
    'registradoEm',
  );
  @override
  late final GeneratedColumn<DateTime> registradoEm = GeneratedColumn<DateTime>(
    'registrado_em',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    nomeNormalizado,
    precoCentavos,
    unidade,
    registradoEm,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'historico_preco_local';
  @override
  VerificationContext validateIntegrity(
    Insertable<HistoricoPrecoLocalData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('nome_normalizado')) {
      context.handle(
        _nomeNormalizadoMeta,
        nomeNormalizado.isAcceptableOrUnknown(
          data['nome_normalizado']!,
          _nomeNormalizadoMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_nomeNormalizadoMeta);
    }
    if (data.containsKey('preco_centavos')) {
      context.handle(
        _precoCentavosMeta,
        precoCentavos.isAcceptableOrUnknown(
          data['preco_centavos']!,
          _precoCentavosMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_precoCentavosMeta);
    }
    if (data.containsKey('unidade')) {
      context.handle(
        _unidadeMeta,
        unidade.isAcceptableOrUnknown(data['unidade']!, _unidadeMeta),
      );
    } else if (isInserting) {
      context.missing(_unidadeMeta);
    }
    if (data.containsKey('registrado_em')) {
      context.handle(
        _registradoEmMeta,
        registradoEm.isAcceptableOrUnknown(
          data['registrado_em']!,
          _registradoEmMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_registradoEmMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {nomeNormalizado};
  @override
  HistoricoPrecoLocalData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HistoricoPrecoLocalData(
      nomeNormalizado: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nome_normalizado'],
      )!,
      precoCentavos: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}preco_centavos'],
      )!,
      unidade: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unidade'],
      )!,
      registradoEm: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}registrado_em'],
      )!,
    );
  }

  @override
  $HistoricoPrecoLocalTable createAlias(String alias) {
    return $HistoricoPrecoLocalTable(attachedDatabase, alias);
  }
}

class HistoricoPrecoLocalData extends DataClass
    implements Insertable<HistoricoPrecoLocalData> {
  final String nomeNormalizado;
  final int precoCentavos;
  final String unidade;
  final DateTime registradoEm;
  const HistoricoPrecoLocalData({
    required this.nomeNormalizado,
    required this.precoCentavos,
    required this.unidade,
    required this.registradoEm,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['nome_normalizado'] = Variable<String>(nomeNormalizado);
    map['preco_centavos'] = Variable<int>(precoCentavos);
    map['unidade'] = Variable<String>(unidade);
    map['registrado_em'] = Variable<DateTime>(registradoEm);
    return map;
  }

  HistoricoPrecoLocalCompanion toCompanion(bool nullToAbsent) {
    return HistoricoPrecoLocalCompanion(
      nomeNormalizado: Value(nomeNormalizado),
      precoCentavos: Value(precoCentavos),
      unidade: Value(unidade),
      registradoEm: Value(registradoEm),
    );
  }

  factory HistoricoPrecoLocalData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HistoricoPrecoLocalData(
      nomeNormalizado: serializer.fromJson<String>(json['nomeNormalizado']),
      precoCentavos: serializer.fromJson<int>(json['precoCentavos']),
      unidade: serializer.fromJson<String>(json['unidade']),
      registradoEm: serializer.fromJson<DateTime>(json['registradoEm']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'nomeNormalizado': serializer.toJson<String>(nomeNormalizado),
      'precoCentavos': serializer.toJson<int>(precoCentavos),
      'unidade': serializer.toJson<String>(unidade),
      'registradoEm': serializer.toJson<DateTime>(registradoEm),
    };
  }

  HistoricoPrecoLocalData copyWith({
    String? nomeNormalizado,
    int? precoCentavos,
    String? unidade,
    DateTime? registradoEm,
  }) => HistoricoPrecoLocalData(
    nomeNormalizado: nomeNormalizado ?? this.nomeNormalizado,
    precoCentavos: precoCentavos ?? this.precoCentavos,
    unidade: unidade ?? this.unidade,
    registradoEm: registradoEm ?? this.registradoEm,
  );
  HistoricoPrecoLocalData copyWithCompanion(HistoricoPrecoLocalCompanion data) {
    return HistoricoPrecoLocalData(
      nomeNormalizado: data.nomeNormalizado.present
          ? data.nomeNormalizado.value
          : this.nomeNormalizado,
      precoCentavos: data.precoCentavos.present
          ? data.precoCentavos.value
          : this.precoCentavos,
      unidade: data.unidade.present ? data.unidade.value : this.unidade,
      registradoEm: data.registradoEm.present
          ? data.registradoEm.value
          : this.registradoEm,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HistoricoPrecoLocalData(')
          ..write('nomeNormalizado: $nomeNormalizado, ')
          ..write('precoCentavos: $precoCentavos, ')
          ..write('unidade: $unidade, ')
          ..write('registradoEm: $registradoEm')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(nomeNormalizado, precoCentavos, unidade, registradoEm);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HistoricoPrecoLocalData &&
          other.nomeNormalizado == this.nomeNormalizado &&
          other.precoCentavos == this.precoCentavos &&
          other.unidade == this.unidade &&
          other.registradoEm == this.registradoEm);
}

class HistoricoPrecoLocalCompanion
    extends UpdateCompanion<HistoricoPrecoLocalData> {
  final Value<String> nomeNormalizado;
  final Value<int> precoCentavos;
  final Value<String> unidade;
  final Value<DateTime> registradoEm;
  final Value<int> rowid;
  const HistoricoPrecoLocalCompanion({
    this.nomeNormalizado = const Value.absent(),
    this.precoCentavos = const Value.absent(),
    this.unidade = const Value.absent(),
    this.registradoEm = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HistoricoPrecoLocalCompanion.insert({
    required String nomeNormalizado,
    required int precoCentavos,
    required String unidade,
    required DateTime registradoEm,
    this.rowid = const Value.absent(),
  }) : nomeNormalizado = Value(nomeNormalizado),
       precoCentavos = Value(precoCentavos),
       unidade = Value(unidade),
       registradoEm = Value(registradoEm);
  static Insertable<HistoricoPrecoLocalData> custom({
    Expression<String>? nomeNormalizado,
    Expression<int>? precoCentavos,
    Expression<String>? unidade,
    Expression<DateTime>? registradoEm,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (nomeNormalizado != null) 'nome_normalizado': nomeNormalizado,
      if (precoCentavos != null) 'preco_centavos': precoCentavos,
      if (unidade != null) 'unidade': unidade,
      if (registradoEm != null) 'registrado_em': registradoEm,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HistoricoPrecoLocalCompanion copyWith({
    Value<String>? nomeNormalizado,
    Value<int>? precoCentavos,
    Value<String>? unidade,
    Value<DateTime>? registradoEm,
    Value<int>? rowid,
  }) {
    return HistoricoPrecoLocalCompanion(
      nomeNormalizado: nomeNormalizado ?? this.nomeNormalizado,
      precoCentavos: precoCentavos ?? this.precoCentavos,
      unidade: unidade ?? this.unidade,
      registradoEm: registradoEm ?? this.registradoEm,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (nomeNormalizado.present) {
      map['nome_normalizado'] = Variable<String>(nomeNormalizado.value);
    }
    if (precoCentavos.present) {
      map['preco_centavos'] = Variable<int>(precoCentavos.value);
    }
    if (unidade.present) {
      map['unidade'] = Variable<String>(unidade.value);
    }
    if (registradoEm.present) {
      map['registrado_em'] = Variable<DateTime>(registradoEm.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HistoricoPrecoLocalCompanion(')
          ..write('nomeNormalizado: $nomeNormalizado, ')
          ..write('precoCentavos: $precoCentavos, ')
          ..write('unidade: $unidade, ')
          ..write('registradoEm: $registradoEm, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $IdaCompraTable extends IdaCompra
    with TableInfo<$IdaCompraTable, IdaCompraData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $IdaCompraTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _listaIdMeta = const VerificationMeta(
    'listaId',
  );
  @override
  late final GeneratedColumn<String> listaId = GeneratedColumn<String>(
    'lista_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tituloMeta = const VerificationMeta('titulo');
  @override
  late final GeneratedColumn<String> titulo = GeneratedColumn<String>(
    'titulo',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _finalizadaEmMeta = const VerificationMeta(
    'finalizadaEm',
  );
  @override
  late final GeneratedColumn<DateTime> finalizadaEm = GeneratedColumn<DateTime>(
    'finalizada_em',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalCentavosMeta = const VerificationMeta(
    'totalCentavos',
  );
  @override
  late final GeneratedColumn<int> totalCentavos = GeneratedColumn<int>(
    'total_centavos',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _itensCountMeta = const VerificationMeta(
    'itensCount',
  );
  @override
  late final GeneratedColumn<int> itensCount = GeneratedColumn<int>(
    'itens_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _mercadoMeta = const VerificationMeta(
    'mercado',
  );
  @override
  late final GeneratedColumn<String> mercado = GeneratedColumn<String>(
    'mercado',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    listaId,
    titulo,
    finalizadaEm,
    totalCentavos,
    itensCount,
    mercado,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ida_compra';
  @override
  VerificationContext validateIntegrity(
    Insertable<IdaCompraData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('lista_id')) {
      context.handle(
        _listaIdMeta,
        listaId.isAcceptableOrUnknown(data['lista_id']!, _listaIdMeta),
      );
    }
    if (data.containsKey('titulo')) {
      context.handle(
        _tituloMeta,
        titulo.isAcceptableOrUnknown(data['titulo']!, _tituloMeta),
      );
    } else if (isInserting) {
      context.missing(_tituloMeta);
    }
    if (data.containsKey('finalizada_em')) {
      context.handle(
        _finalizadaEmMeta,
        finalizadaEm.isAcceptableOrUnknown(
          data['finalizada_em']!,
          _finalizadaEmMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_finalizadaEmMeta);
    }
    if (data.containsKey('total_centavos')) {
      context.handle(
        _totalCentavosMeta,
        totalCentavos.isAcceptableOrUnknown(
          data['total_centavos']!,
          _totalCentavosMeta,
        ),
      );
    }
    if (data.containsKey('itens_count')) {
      context.handle(
        _itensCountMeta,
        itensCount.isAcceptableOrUnknown(data['itens_count']!, _itensCountMeta),
      );
    }
    if (data.containsKey('mercado')) {
      context.handle(
        _mercadoMeta,
        mercado.isAcceptableOrUnknown(data['mercado']!, _mercadoMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  IdaCompraData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return IdaCompraData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      listaId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lista_id'],
      ),
      titulo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}titulo'],
      )!,
      finalizadaEm: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}finalizada_em'],
      )!,
      totalCentavos: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_centavos'],
      )!,
      itensCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}itens_count'],
      )!,
      mercado: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mercado'],
      ),
    );
  }

  @override
  $IdaCompraTable createAlias(String alias) {
    return $IdaCompraTable(attachedDatabase, alias);
  }
}

class IdaCompraData extends DataClass implements Insertable<IdaCompraData> {
  final String id;
  final String? listaId;
  final String titulo;
  final DateTime finalizadaEm;
  final int totalCentavos;
  final int itensCount;
  final String? mercado;
  const IdaCompraData({
    required this.id,
    this.listaId,
    required this.titulo,
    required this.finalizadaEm,
    required this.totalCentavos,
    required this.itensCount,
    this.mercado,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || listaId != null) {
      map['lista_id'] = Variable<String>(listaId);
    }
    map['titulo'] = Variable<String>(titulo);
    map['finalizada_em'] = Variable<DateTime>(finalizadaEm);
    map['total_centavos'] = Variable<int>(totalCentavos);
    map['itens_count'] = Variable<int>(itensCount);
    if (!nullToAbsent || mercado != null) {
      map['mercado'] = Variable<String>(mercado);
    }
    return map;
  }

  IdaCompraCompanion toCompanion(bool nullToAbsent) {
    return IdaCompraCompanion(
      id: Value(id),
      listaId: listaId == null && nullToAbsent
          ? const Value.absent()
          : Value(listaId),
      titulo: Value(titulo),
      finalizadaEm: Value(finalizadaEm),
      totalCentavos: Value(totalCentavos),
      itensCount: Value(itensCount),
      mercado: mercado == null && nullToAbsent
          ? const Value.absent()
          : Value(mercado),
    );
  }

  factory IdaCompraData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return IdaCompraData(
      id: serializer.fromJson<String>(json['id']),
      listaId: serializer.fromJson<String?>(json['listaId']),
      titulo: serializer.fromJson<String>(json['titulo']),
      finalizadaEm: serializer.fromJson<DateTime>(json['finalizadaEm']),
      totalCentavos: serializer.fromJson<int>(json['totalCentavos']),
      itensCount: serializer.fromJson<int>(json['itensCount']),
      mercado: serializer.fromJson<String?>(json['mercado']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'listaId': serializer.toJson<String?>(listaId),
      'titulo': serializer.toJson<String>(titulo),
      'finalizadaEm': serializer.toJson<DateTime>(finalizadaEm),
      'totalCentavos': serializer.toJson<int>(totalCentavos),
      'itensCount': serializer.toJson<int>(itensCount),
      'mercado': serializer.toJson<String?>(mercado),
    };
  }

  IdaCompraData copyWith({
    String? id,
    Value<String?> listaId = const Value.absent(),
    String? titulo,
    DateTime? finalizadaEm,
    int? totalCentavos,
    int? itensCount,
    Value<String?> mercado = const Value.absent(),
  }) => IdaCompraData(
    id: id ?? this.id,
    listaId: listaId.present ? listaId.value : this.listaId,
    titulo: titulo ?? this.titulo,
    finalizadaEm: finalizadaEm ?? this.finalizadaEm,
    totalCentavos: totalCentavos ?? this.totalCentavos,
    itensCount: itensCount ?? this.itensCount,
    mercado: mercado.present ? mercado.value : this.mercado,
  );
  IdaCompraData copyWithCompanion(IdaCompraCompanion data) {
    return IdaCompraData(
      id: data.id.present ? data.id.value : this.id,
      listaId: data.listaId.present ? data.listaId.value : this.listaId,
      titulo: data.titulo.present ? data.titulo.value : this.titulo,
      finalizadaEm: data.finalizadaEm.present
          ? data.finalizadaEm.value
          : this.finalizadaEm,
      totalCentavos: data.totalCentavos.present
          ? data.totalCentavos.value
          : this.totalCentavos,
      itensCount: data.itensCount.present
          ? data.itensCount.value
          : this.itensCount,
      mercado: data.mercado.present ? data.mercado.value : this.mercado,
    );
  }

  @override
  String toString() {
    return (StringBuffer('IdaCompraData(')
          ..write('id: $id, ')
          ..write('listaId: $listaId, ')
          ..write('titulo: $titulo, ')
          ..write('finalizadaEm: $finalizadaEm, ')
          ..write('totalCentavos: $totalCentavos, ')
          ..write('itensCount: $itensCount, ')
          ..write('mercado: $mercado')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    listaId,
    titulo,
    finalizadaEm,
    totalCentavos,
    itensCount,
    mercado,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is IdaCompraData &&
          other.id == this.id &&
          other.listaId == this.listaId &&
          other.titulo == this.titulo &&
          other.finalizadaEm == this.finalizadaEm &&
          other.totalCentavos == this.totalCentavos &&
          other.itensCount == this.itensCount &&
          other.mercado == this.mercado);
}

class IdaCompraCompanion extends UpdateCompanion<IdaCompraData> {
  final Value<String> id;
  final Value<String?> listaId;
  final Value<String> titulo;
  final Value<DateTime> finalizadaEm;
  final Value<int> totalCentavos;
  final Value<int> itensCount;
  final Value<String?> mercado;
  final Value<int> rowid;
  const IdaCompraCompanion({
    this.id = const Value.absent(),
    this.listaId = const Value.absent(),
    this.titulo = const Value.absent(),
    this.finalizadaEm = const Value.absent(),
    this.totalCentavos = const Value.absent(),
    this.itensCount = const Value.absent(),
    this.mercado = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  IdaCompraCompanion.insert({
    required String id,
    this.listaId = const Value.absent(),
    required String titulo,
    required DateTime finalizadaEm,
    this.totalCentavos = const Value.absent(),
    this.itensCount = const Value.absent(),
    this.mercado = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       titulo = Value(titulo),
       finalizadaEm = Value(finalizadaEm);
  static Insertable<IdaCompraData> custom({
    Expression<String>? id,
    Expression<String>? listaId,
    Expression<String>? titulo,
    Expression<DateTime>? finalizadaEm,
    Expression<int>? totalCentavos,
    Expression<int>? itensCount,
    Expression<String>? mercado,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (listaId != null) 'lista_id': listaId,
      if (titulo != null) 'titulo': titulo,
      if (finalizadaEm != null) 'finalizada_em': finalizadaEm,
      if (totalCentavos != null) 'total_centavos': totalCentavos,
      if (itensCount != null) 'itens_count': itensCount,
      if (mercado != null) 'mercado': mercado,
      if (rowid != null) 'rowid': rowid,
    });
  }

  IdaCompraCompanion copyWith({
    Value<String>? id,
    Value<String?>? listaId,
    Value<String>? titulo,
    Value<DateTime>? finalizadaEm,
    Value<int>? totalCentavos,
    Value<int>? itensCount,
    Value<String?>? mercado,
    Value<int>? rowid,
  }) {
    return IdaCompraCompanion(
      id: id ?? this.id,
      listaId: listaId ?? this.listaId,
      titulo: titulo ?? this.titulo,
      finalizadaEm: finalizadaEm ?? this.finalizadaEm,
      totalCentavos: totalCentavos ?? this.totalCentavos,
      itensCount: itensCount ?? this.itensCount,
      mercado: mercado ?? this.mercado,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (listaId.present) {
      map['lista_id'] = Variable<String>(listaId.value);
    }
    if (titulo.present) {
      map['titulo'] = Variable<String>(titulo.value);
    }
    if (finalizadaEm.present) {
      map['finalizada_em'] = Variable<DateTime>(finalizadaEm.value);
    }
    if (totalCentavos.present) {
      map['total_centavos'] = Variable<int>(totalCentavos.value);
    }
    if (itensCount.present) {
      map['itens_count'] = Variable<int>(itensCount.value);
    }
    if (mercado.present) {
      map['mercado'] = Variable<String>(mercado.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('IdaCompraCompanion(')
          ..write('id: $id, ')
          ..write('listaId: $listaId, ')
          ..write('titulo: $titulo, ')
          ..write('finalizadaEm: $finalizadaEm, ')
          ..write('totalCentavos: $totalCentavos, ')
          ..write('itensCount: $itensCount, ')
          ..write('mercado: $mercado, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ItemIdaTable extends ItemIda with TableInfo<$ItemIdaTable, ItemIdaData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ItemIdaTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idaIdMeta = const VerificationMeta('idaId');
  @override
  late final GeneratedColumn<String> idaId = GeneratedColumn<String>(
    'ida_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES ida_compra (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _nomeMeta = const VerificationMeta('nome');
  @override
  late final GeneratedColumn<String> nome = GeneratedColumn<String>(
    'nome',
    aliasedName,
    false,
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
  static const VerificationMeta _categoriaMeta = const VerificationMeta(
    'categoria',
  );
  @override
  late final GeneratedColumn<String> categoria = GeneratedColumn<String>(
    'categoria',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('outros'),
  );
  static const VerificationMeta _precoCentavosMeta = const VerificationMeta(
    'precoCentavos',
  );
  @override
  late final GeneratedColumn<int> precoCentavos = GeneratedColumn<int>(
    'preco_centavos',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    idaId,
    nome,
    quantidade,
    unidade,
    categoria,
    precoCentavos,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'item_ida';
  @override
  VerificationContext validateIntegrity(
    Insertable<ItemIdaData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('ida_id')) {
      context.handle(
        _idaIdMeta,
        idaId.isAcceptableOrUnknown(data['ida_id']!, _idaIdMeta),
      );
    } else if (isInserting) {
      context.missing(_idaIdMeta);
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
    if (data.containsKey('categoria')) {
      context.handle(
        _categoriaMeta,
        categoria.isAcceptableOrUnknown(data['categoria']!, _categoriaMeta),
      );
    }
    if (data.containsKey('preco_centavos')) {
      context.handle(
        _precoCentavosMeta,
        precoCentavos.isAcceptableOrUnknown(
          data['preco_centavos']!,
          _precoCentavosMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ItemIdaData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ItemIdaData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      idaId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ida_id'],
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
      categoria: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}categoria'],
      )!,
      precoCentavos: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}preco_centavos'],
      ),
    );
  }

  @override
  $ItemIdaTable createAlias(String alias) {
    return $ItemIdaTable(attachedDatabase, alias);
  }
}

class ItemIdaData extends DataClass implements Insertable<ItemIdaData> {
  final String id;
  final String idaId;
  final String nome;
  final double quantidade;
  final String unidade;
  final String categoria;
  final int? precoCentavos;
  const ItemIdaData({
    required this.id,
    required this.idaId,
    required this.nome,
    required this.quantidade,
    required this.unidade,
    required this.categoria,
    this.precoCentavos,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['ida_id'] = Variable<String>(idaId);
    map['nome'] = Variable<String>(nome);
    map['quantidade'] = Variable<double>(quantidade);
    map['unidade'] = Variable<String>(unidade);
    map['categoria'] = Variable<String>(categoria);
    if (!nullToAbsent || precoCentavos != null) {
      map['preco_centavos'] = Variable<int>(precoCentavos);
    }
    return map;
  }

  ItemIdaCompanion toCompanion(bool nullToAbsent) {
    return ItemIdaCompanion(
      id: Value(id),
      idaId: Value(idaId),
      nome: Value(nome),
      quantidade: Value(quantidade),
      unidade: Value(unidade),
      categoria: Value(categoria),
      precoCentavos: precoCentavos == null && nullToAbsent
          ? const Value.absent()
          : Value(precoCentavos),
    );
  }

  factory ItemIdaData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ItemIdaData(
      id: serializer.fromJson<String>(json['id']),
      idaId: serializer.fromJson<String>(json['idaId']),
      nome: serializer.fromJson<String>(json['nome']),
      quantidade: serializer.fromJson<double>(json['quantidade']),
      unidade: serializer.fromJson<String>(json['unidade']),
      categoria: serializer.fromJson<String>(json['categoria']),
      precoCentavos: serializer.fromJson<int?>(json['precoCentavos']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'idaId': serializer.toJson<String>(idaId),
      'nome': serializer.toJson<String>(nome),
      'quantidade': serializer.toJson<double>(quantidade),
      'unidade': serializer.toJson<String>(unidade),
      'categoria': serializer.toJson<String>(categoria),
      'precoCentavos': serializer.toJson<int?>(precoCentavos),
    };
  }

  ItemIdaData copyWith({
    String? id,
    String? idaId,
    String? nome,
    double? quantidade,
    String? unidade,
    String? categoria,
    Value<int?> precoCentavos = const Value.absent(),
  }) => ItemIdaData(
    id: id ?? this.id,
    idaId: idaId ?? this.idaId,
    nome: nome ?? this.nome,
    quantidade: quantidade ?? this.quantidade,
    unidade: unidade ?? this.unidade,
    categoria: categoria ?? this.categoria,
    precoCentavos: precoCentavos.present
        ? precoCentavos.value
        : this.precoCentavos,
  );
  ItemIdaData copyWithCompanion(ItemIdaCompanion data) {
    return ItemIdaData(
      id: data.id.present ? data.id.value : this.id,
      idaId: data.idaId.present ? data.idaId.value : this.idaId,
      nome: data.nome.present ? data.nome.value : this.nome,
      quantidade: data.quantidade.present
          ? data.quantidade.value
          : this.quantidade,
      unidade: data.unidade.present ? data.unidade.value : this.unidade,
      categoria: data.categoria.present ? data.categoria.value : this.categoria,
      precoCentavos: data.precoCentavos.present
          ? data.precoCentavos.value
          : this.precoCentavos,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ItemIdaData(')
          ..write('id: $id, ')
          ..write('idaId: $idaId, ')
          ..write('nome: $nome, ')
          ..write('quantidade: $quantidade, ')
          ..write('unidade: $unidade, ')
          ..write('categoria: $categoria, ')
          ..write('precoCentavos: $precoCentavos')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    idaId,
    nome,
    quantidade,
    unidade,
    categoria,
    precoCentavos,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ItemIdaData &&
          other.id == this.id &&
          other.idaId == this.idaId &&
          other.nome == this.nome &&
          other.quantidade == this.quantidade &&
          other.unidade == this.unidade &&
          other.categoria == this.categoria &&
          other.precoCentavos == this.precoCentavos);
}

class ItemIdaCompanion extends UpdateCompanion<ItemIdaData> {
  final Value<String> id;
  final Value<String> idaId;
  final Value<String> nome;
  final Value<double> quantidade;
  final Value<String> unidade;
  final Value<String> categoria;
  final Value<int?> precoCentavos;
  final Value<int> rowid;
  const ItemIdaCompanion({
    this.id = const Value.absent(),
    this.idaId = const Value.absent(),
    this.nome = const Value.absent(),
    this.quantidade = const Value.absent(),
    this.unidade = const Value.absent(),
    this.categoria = const Value.absent(),
    this.precoCentavos = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ItemIdaCompanion.insert({
    required String id,
    required String idaId,
    required String nome,
    this.quantidade = const Value.absent(),
    this.unidade = const Value.absent(),
    this.categoria = const Value.absent(),
    this.precoCentavos = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       idaId = Value(idaId),
       nome = Value(nome);
  static Insertable<ItemIdaData> custom({
    Expression<String>? id,
    Expression<String>? idaId,
    Expression<String>? nome,
    Expression<double>? quantidade,
    Expression<String>? unidade,
    Expression<String>? categoria,
    Expression<int>? precoCentavos,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (idaId != null) 'ida_id': idaId,
      if (nome != null) 'nome': nome,
      if (quantidade != null) 'quantidade': quantidade,
      if (unidade != null) 'unidade': unidade,
      if (categoria != null) 'categoria': categoria,
      if (precoCentavos != null) 'preco_centavos': precoCentavos,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ItemIdaCompanion copyWith({
    Value<String>? id,
    Value<String>? idaId,
    Value<String>? nome,
    Value<double>? quantidade,
    Value<String>? unidade,
    Value<String>? categoria,
    Value<int?>? precoCentavos,
    Value<int>? rowid,
  }) {
    return ItemIdaCompanion(
      id: id ?? this.id,
      idaId: idaId ?? this.idaId,
      nome: nome ?? this.nome,
      quantidade: quantidade ?? this.quantidade,
      unidade: unidade ?? this.unidade,
      categoria: categoria ?? this.categoria,
      precoCentavos: precoCentavos ?? this.precoCentavos,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (idaId.present) {
      map['ida_id'] = Variable<String>(idaId.value);
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
    if (categoria.present) {
      map['categoria'] = Variable<String>(categoria.value);
    }
    if (precoCentavos.present) {
      map['preco_centavos'] = Variable<int>(precoCentavos.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ItemIdaCompanion(')
          ..write('id: $id, ')
          ..write('idaId: $idaId, ')
          ..write('nome: $nome, ')
          ..write('quantidade: $quantidade, ')
          ..write('unidade: $unidade, ')
          ..write('categoria: $categoria, ')
          ..write('precoCentavos: $precoCentavos, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ListaLocalTable listaLocal = $ListaLocalTable(this);
  late final $ItemLocalTable itemLocal = $ItemLocalTable(this);
  late final $HistoricoPrecoLocalTable historicoPrecoLocal =
      $HistoricoPrecoLocalTable(this);
  late final $IdaCompraTable idaCompra = $IdaCompraTable(this);
  late final $ItemIdaTable itemIda = $ItemIdaTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    listaLocal,
    itemLocal,
    historicoPrecoLocal,
    idaCompra,
    itemIda,
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
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'ida_compra',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('item_ida', kind: UpdateKind.delete)],
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
      Value<DateTime?> arquivadaEm,
      Value<int?> orcamentoCentavos,
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
      Value<DateTime?> arquivadaEm,
      Value<int?> orcamentoCentavos,
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

  ColumnFilters<DateTime> get arquivadaEm => $composableBuilder(
    column: $table.arquivadaEm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get orcamentoCentavos => $composableBuilder(
    column: $table.orcamentoCentavos,
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

  ColumnOrderings<DateTime> get arquivadaEm => $composableBuilder(
    column: $table.arquivadaEm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get orcamentoCentavos => $composableBuilder(
    column: $table.orcamentoCentavos,
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

  GeneratedColumn<DateTime> get arquivadaEm => $composableBuilder(
    column: $table.arquivadaEm,
    builder: (column) => column,
  );

  GeneratedColumn<int> get orcamentoCentavos => $composableBuilder(
    column: $table.orcamentoCentavos,
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
                Value<DateTime?> arquivadaEm = const Value.absent(),
                Value<int?> orcamentoCentavos = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ListaLocalCompanion(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                titulo: titulo,
                donoId: donoId,
                deletadoEm: deletadoEm,
                arquivadaEm: arquivadaEm,
                orcamentoCentavos: orcamentoCentavos,
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
                Value<DateTime?> arquivadaEm = const Value.absent(),
                Value<int?> orcamentoCentavos = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ListaLocalCompanion.insert(
                id: id,
                createdAt: createdAt,
                updatedAt: updatedAt,
                titulo: titulo,
                donoId: donoId,
                deletadoEm: deletadoEm,
                arquivadaEm: arquivadaEm,
                orcamentoCentavos: orcamentoCentavos,
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
      Value<String> categoria,
      Value<int?> precoCentavos,
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
      Value<String> categoria,
      Value<int?> precoCentavos,
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

  ColumnFilters<String> get categoria => $composableBuilder(
    column: $table.categoria,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get precoCentavos => $composableBuilder(
    column: $table.precoCentavos,
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

  ColumnOrderings<String> get categoria => $composableBuilder(
    column: $table.categoria,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get precoCentavos => $composableBuilder(
    column: $table.precoCentavos,
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

  GeneratedColumn<String> get categoria =>
      $composableBuilder(column: $table.categoria, builder: (column) => column);

  GeneratedColumn<int> get precoCentavos => $composableBuilder(
    column: $table.precoCentavos,
    builder: (column) => column,
  );

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
                Value<String> categoria = const Value.absent(),
                Value<int?> precoCentavos = const Value.absent(),
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
                categoria: categoria,
                precoCentavos: precoCentavos,
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
                Value<String> categoria = const Value.absent(),
                Value<int?> precoCentavos = const Value.absent(),
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
                categoria: categoria,
                precoCentavos: precoCentavos,
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
typedef $$HistoricoPrecoLocalTableCreateCompanionBuilder =
    HistoricoPrecoLocalCompanion Function({
      required String nomeNormalizado,
      required int precoCentavos,
      required String unidade,
      required DateTime registradoEm,
      Value<int> rowid,
    });
typedef $$HistoricoPrecoLocalTableUpdateCompanionBuilder =
    HistoricoPrecoLocalCompanion Function({
      Value<String> nomeNormalizado,
      Value<int> precoCentavos,
      Value<String> unidade,
      Value<DateTime> registradoEm,
      Value<int> rowid,
    });

class $$HistoricoPrecoLocalTableFilterComposer
    extends Composer<_$AppDatabase, $HistoricoPrecoLocalTable> {
  $$HistoricoPrecoLocalTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get nomeNormalizado => $composableBuilder(
    column: $table.nomeNormalizado,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get precoCentavos => $composableBuilder(
    column: $table.precoCentavos,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unidade => $composableBuilder(
    column: $table.unidade,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get registradoEm => $composableBuilder(
    column: $table.registradoEm,
    builder: (column) => ColumnFilters(column),
  );
}

class $$HistoricoPrecoLocalTableOrderingComposer
    extends Composer<_$AppDatabase, $HistoricoPrecoLocalTable> {
  $$HistoricoPrecoLocalTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get nomeNormalizado => $composableBuilder(
    column: $table.nomeNormalizado,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get precoCentavos => $composableBuilder(
    column: $table.precoCentavos,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unidade => $composableBuilder(
    column: $table.unidade,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get registradoEm => $composableBuilder(
    column: $table.registradoEm,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HistoricoPrecoLocalTableAnnotationComposer
    extends Composer<_$AppDatabase, $HistoricoPrecoLocalTable> {
  $$HistoricoPrecoLocalTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get nomeNormalizado => $composableBuilder(
    column: $table.nomeNormalizado,
    builder: (column) => column,
  );

  GeneratedColumn<int> get precoCentavos => $composableBuilder(
    column: $table.precoCentavos,
    builder: (column) => column,
  );

  GeneratedColumn<String> get unidade =>
      $composableBuilder(column: $table.unidade, builder: (column) => column);

  GeneratedColumn<DateTime> get registradoEm => $composableBuilder(
    column: $table.registradoEm,
    builder: (column) => column,
  );
}

class $$HistoricoPrecoLocalTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HistoricoPrecoLocalTable,
          HistoricoPrecoLocalData,
          $$HistoricoPrecoLocalTableFilterComposer,
          $$HistoricoPrecoLocalTableOrderingComposer,
          $$HistoricoPrecoLocalTableAnnotationComposer,
          $$HistoricoPrecoLocalTableCreateCompanionBuilder,
          $$HistoricoPrecoLocalTableUpdateCompanionBuilder,
          (
            HistoricoPrecoLocalData,
            BaseReferences<
              _$AppDatabase,
              $HistoricoPrecoLocalTable,
              HistoricoPrecoLocalData
            >,
          ),
          HistoricoPrecoLocalData,
          PrefetchHooks Function()
        > {
  $$HistoricoPrecoLocalTableTableManager(
    _$AppDatabase db,
    $HistoricoPrecoLocalTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HistoricoPrecoLocalTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HistoricoPrecoLocalTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$HistoricoPrecoLocalTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> nomeNormalizado = const Value.absent(),
                Value<int> precoCentavos = const Value.absent(),
                Value<String> unidade = const Value.absent(),
                Value<DateTime> registradoEm = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HistoricoPrecoLocalCompanion(
                nomeNormalizado: nomeNormalizado,
                precoCentavos: precoCentavos,
                unidade: unidade,
                registradoEm: registradoEm,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String nomeNormalizado,
                required int precoCentavos,
                required String unidade,
                required DateTime registradoEm,
                Value<int> rowid = const Value.absent(),
              }) => HistoricoPrecoLocalCompanion.insert(
                nomeNormalizado: nomeNormalizado,
                precoCentavos: precoCentavos,
                unidade: unidade,
                registradoEm: registradoEm,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$HistoricoPrecoLocalTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HistoricoPrecoLocalTable,
      HistoricoPrecoLocalData,
      $$HistoricoPrecoLocalTableFilterComposer,
      $$HistoricoPrecoLocalTableOrderingComposer,
      $$HistoricoPrecoLocalTableAnnotationComposer,
      $$HistoricoPrecoLocalTableCreateCompanionBuilder,
      $$HistoricoPrecoLocalTableUpdateCompanionBuilder,
      (
        HistoricoPrecoLocalData,
        BaseReferences<
          _$AppDatabase,
          $HistoricoPrecoLocalTable,
          HistoricoPrecoLocalData
        >,
      ),
      HistoricoPrecoLocalData,
      PrefetchHooks Function()
    >;
typedef $$IdaCompraTableCreateCompanionBuilder =
    IdaCompraCompanion Function({
      required String id,
      Value<String?> listaId,
      required String titulo,
      required DateTime finalizadaEm,
      Value<int> totalCentavos,
      Value<int> itensCount,
      Value<String?> mercado,
      Value<int> rowid,
    });
typedef $$IdaCompraTableUpdateCompanionBuilder =
    IdaCompraCompanion Function({
      Value<String> id,
      Value<String?> listaId,
      Value<String> titulo,
      Value<DateTime> finalizadaEm,
      Value<int> totalCentavos,
      Value<int> itensCount,
      Value<String?> mercado,
      Value<int> rowid,
    });

final class $$IdaCompraTableReferences
    extends BaseReferences<_$AppDatabase, $IdaCompraTable, IdaCompraData> {
  $$IdaCompraTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ItemIdaTable, List<ItemIdaData>>
  _itemIdaRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.itemIda,
    aliasName: 'ida_compra__id__item_ida__ida_id',
  );

  $$ItemIdaTableProcessedTableManager get itemIdaRefs {
    final manager = $$ItemIdaTableTableManager(
      $_db,
      $_db.itemIda,
    ).filter((f) => f.idaId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_itemIdaRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$IdaCompraTableFilterComposer
    extends Composer<_$AppDatabase, $IdaCompraTable> {
  $$IdaCompraTableFilterComposer({
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

  ColumnFilters<String> get listaId => $composableBuilder(
    column: $table.listaId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get titulo => $composableBuilder(
    column: $table.titulo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get finalizadaEm => $composableBuilder(
    column: $table.finalizadaEm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalCentavos => $composableBuilder(
    column: $table.totalCentavos,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get itensCount => $composableBuilder(
    column: $table.itensCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mercado => $composableBuilder(
    column: $table.mercado,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> itemIdaRefs(
    Expression<bool> Function($$ItemIdaTableFilterComposer f) f,
  ) {
    final $$ItemIdaTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.itemIda,
      getReferencedColumn: (t) => t.idaId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemIdaTableFilterComposer(
            $db: $db,
            $table: $db.itemIda,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$IdaCompraTableOrderingComposer
    extends Composer<_$AppDatabase, $IdaCompraTable> {
  $$IdaCompraTableOrderingComposer({
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

  ColumnOrderings<String> get listaId => $composableBuilder(
    column: $table.listaId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get titulo => $composableBuilder(
    column: $table.titulo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get finalizadaEm => $composableBuilder(
    column: $table.finalizadaEm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalCentavos => $composableBuilder(
    column: $table.totalCentavos,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get itensCount => $composableBuilder(
    column: $table.itensCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mercado => $composableBuilder(
    column: $table.mercado,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$IdaCompraTableAnnotationComposer
    extends Composer<_$AppDatabase, $IdaCompraTable> {
  $$IdaCompraTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get listaId =>
      $composableBuilder(column: $table.listaId, builder: (column) => column);

  GeneratedColumn<String> get titulo =>
      $composableBuilder(column: $table.titulo, builder: (column) => column);

  GeneratedColumn<DateTime> get finalizadaEm => $composableBuilder(
    column: $table.finalizadaEm,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalCentavos => $composableBuilder(
    column: $table.totalCentavos,
    builder: (column) => column,
  );

  GeneratedColumn<int> get itensCount => $composableBuilder(
    column: $table.itensCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mercado =>
      $composableBuilder(column: $table.mercado, builder: (column) => column);

  Expression<T> itemIdaRefs<T extends Object>(
    Expression<T> Function($$ItemIdaTableAnnotationComposer a) f,
  ) {
    final $$ItemIdaTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.itemIda,
      getReferencedColumn: (t) => t.idaId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemIdaTableAnnotationComposer(
            $db: $db,
            $table: $db.itemIda,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$IdaCompraTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $IdaCompraTable,
          IdaCompraData,
          $$IdaCompraTableFilterComposer,
          $$IdaCompraTableOrderingComposer,
          $$IdaCompraTableAnnotationComposer,
          $$IdaCompraTableCreateCompanionBuilder,
          $$IdaCompraTableUpdateCompanionBuilder,
          (IdaCompraData, $$IdaCompraTableReferences),
          IdaCompraData,
          PrefetchHooks Function({bool itemIdaRefs})
        > {
  $$IdaCompraTableTableManager(_$AppDatabase db, $IdaCompraTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$IdaCompraTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$IdaCompraTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$IdaCompraTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> listaId = const Value.absent(),
                Value<String> titulo = const Value.absent(),
                Value<DateTime> finalizadaEm = const Value.absent(),
                Value<int> totalCentavos = const Value.absent(),
                Value<int> itensCount = const Value.absent(),
                Value<String?> mercado = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => IdaCompraCompanion(
                id: id,
                listaId: listaId,
                titulo: titulo,
                finalizadaEm: finalizadaEm,
                totalCentavos: totalCentavos,
                itensCount: itensCount,
                mercado: mercado,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> listaId = const Value.absent(),
                required String titulo,
                required DateTime finalizadaEm,
                Value<int> totalCentavos = const Value.absent(),
                Value<int> itensCount = const Value.absent(),
                Value<String?> mercado = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => IdaCompraCompanion.insert(
                id: id,
                listaId: listaId,
                titulo: titulo,
                finalizadaEm: finalizadaEm,
                totalCentavos: totalCentavos,
                itensCount: itensCount,
                mercado: mercado,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$IdaCompraTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({itemIdaRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (itemIdaRefs) db.itemIda],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (itemIdaRefs)
                    await $_getPrefetchedData<
                      IdaCompraData,
                      $IdaCompraTable,
                      ItemIdaData
                    >(
                      currentTable: table,
                      referencedTable: $$IdaCompraTableReferences
                          ._itemIdaRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$IdaCompraTableReferences(db, table, p0).itemIdaRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.idaId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$IdaCompraTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $IdaCompraTable,
      IdaCompraData,
      $$IdaCompraTableFilterComposer,
      $$IdaCompraTableOrderingComposer,
      $$IdaCompraTableAnnotationComposer,
      $$IdaCompraTableCreateCompanionBuilder,
      $$IdaCompraTableUpdateCompanionBuilder,
      (IdaCompraData, $$IdaCompraTableReferences),
      IdaCompraData,
      PrefetchHooks Function({bool itemIdaRefs})
    >;
typedef $$ItemIdaTableCreateCompanionBuilder =
    ItemIdaCompanion Function({
      required String id,
      required String idaId,
      required String nome,
      Value<double> quantidade,
      Value<String> unidade,
      Value<String> categoria,
      Value<int?> precoCentavos,
      Value<int> rowid,
    });
typedef $$ItemIdaTableUpdateCompanionBuilder =
    ItemIdaCompanion Function({
      Value<String> id,
      Value<String> idaId,
      Value<String> nome,
      Value<double> quantidade,
      Value<String> unidade,
      Value<String> categoria,
      Value<int?> precoCentavos,
      Value<int> rowid,
    });

final class $$ItemIdaTableReferences
    extends BaseReferences<_$AppDatabase, $ItemIdaTable, ItemIdaData> {
  $$ItemIdaTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $IdaCompraTable _idaIdTable(_$AppDatabase db) =>
      db.idaCompra.createAlias('item_ida__ida_id__ida_compra__id');

  $$IdaCompraTableProcessedTableManager get idaId {
    final $_column = $_itemColumn<String>('ida_id')!;

    final manager = $$IdaCompraTableTableManager(
      $_db,
      $_db.idaCompra,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_idaIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ItemIdaTableFilterComposer
    extends Composer<_$AppDatabase, $ItemIdaTable> {
  $$ItemIdaTableFilterComposer({
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

  ColumnFilters<String> get categoria => $composableBuilder(
    column: $table.categoria,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get precoCentavos => $composableBuilder(
    column: $table.precoCentavos,
    builder: (column) => ColumnFilters(column),
  );

  $$IdaCompraTableFilterComposer get idaId {
    final $$IdaCompraTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.idaId,
      referencedTable: $db.idaCompra,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$IdaCompraTableFilterComposer(
            $db: $db,
            $table: $db.idaCompra,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ItemIdaTableOrderingComposer
    extends Composer<_$AppDatabase, $ItemIdaTable> {
  $$ItemIdaTableOrderingComposer({
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

  ColumnOrderings<String> get categoria => $composableBuilder(
    column: $table.categoria,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get precoCentavos => $composableBuilder(
    column: $table.precoCentavos,
    builder: (column) => ColumnOrderings(column),
  );

  $$IdaCompraTableOrderingComposer get idaId {
    final $$IdaCompraTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.idaId,
      referencedTable: $db.idaCompra,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$IdaCompraTableOrderingComposer(
            $db: $db,
            $table: $db.idaCompra,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ItemIdaTableAnnotationComposer
    extends Composer<_$AppDatabase, $ItemIdaTable> {
  $$ItemIdaTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get nome =>
      $composableBuilder(column: $table.nome, builder: (column) => column);

  GeneratedColumn<double> get quantidade => $composableBuilder(
    column: $table.quantidade,
    builder: (column) => column,
  );

  GeneratedColumn<String> get unidade =>
      $composableBuilder(column: $table.unidade, builder: (column) => column);

  GeneratedColumn<String> get categoria =>
      $composableBuilder(column: $table.categoria, builder: (column) => column);

  GeneratedColumn<int> get precoCentavos => $composableBuilder(
    column: $table.precoCentavos,
    builder: (column) => column,
  );

  $$IdaCompraTableAnnotationComposer get idaId {
    final $$IdaCompraTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.idaId,
      referencedTable: $db.idaCompra,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$IdaCompraTableAnnotationComposer(
            $db: $db,
            $table: $db.idaCompra,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ItemIdaTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ItemIdaTable,
          ItemIdaData,
          $$ItemIdaTableFilterComposer,
          $$ItemIdaTableOrderingComposer,
          $$ItemIdaTableAnnotationComposer,
          $$ItemIdaTableCreateCompanionBuilder,
          $$ItemIdaTableUpdateCompanionBuilder,
          (ItemIdaData, $$ItemIdaTableReferences),
          ItemIdaData,
          PrefetchHooks Function({bool idaId})
        > {
  $$ItemIdaTableTableManager(_$AppDatabase db, $ItemIdaTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ItemIdaTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ItemIdaTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ItemIdaTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> idaId = const Value.absent(),
                Value<String> nome = const Value.absent(),
                Value<double> quantidade = const Value.absent(),
                Value<String> unidade = const Value.absent(),
                Value<String> categoria = const Value.absent(),
                Value<int?> precoCentavos = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ItemIdaCompanion(
                id: id,
                idaId: idaId,
                nome: nome,
                quantidade: quantidade,
                unidade: unidade,
                categoria: categoria,
                precoCentavos: precoCentavos,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String idaId,
                required String nome,
                Value<double> quantidade = const Value.absent(),
                Value<String> unidade = const Value.absent(),
                Value<String> categoria = const Value.absent(),
                Value<int?> precoCentavos = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ItemIdaCompanion.insert(
                id: id,
                idaId: idaId,
                nome: nome,
                quantidade: quantidade,
                unidade: unidade,
                categoria: categoria,
                precoCentavos: precoCentavos,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ItemIdaTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({idaId = false}) {
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
                    if (idaId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.idaId,
                                referencedTable: $$ItemIdaTableReferences
                                    ._idaIdTable(db),
                                referencedColumn: $$ItemIdaTableReferences
                                    ._idaIdTable(db)
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

typedef $$ItemIdaTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ItemIdaTable,
      ItemIdaData,
      $$ItemIdaTableFilterComposer,
      $$ItemIdaTableOrderingComposer,
      $$ItemIdaTableAnnotationComposer,
      $$ItemIdaTableCreateCompanionBuilder,
      $$ItemIdaTableUpdateCompanionBuilder,
      (ItemIdaData, $$ItemIdaTableReferences),
      ItemIdaData,
      PrefetchHooks Function({bool idaId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ListaLocalTableTableManager get listaLocal =>
      $$ListaLocalTableTableManager(_db, _db.listaLocal);
  $$ItemLocalTableTableManager get itemLocal =>
      $$ItemLocalTableTableManager(_db, _db.itemLocal);
  $$HistoricoPrecoLocalTableTableManager get historicoPrecoLocal =>
      $$HistoricoPrecoLocalTableTableManager(_db, _db.historicoPrecoLocal);
  $$IdaCompraTableTableManager get idaCompra =>
      $$IdaCompraTableTableManager(_db, _db.idaCompra);
  $$ItemIdaTableTableManager get itemIda =>
      $$ItemIdaTableTableManager(_db, _db.itemIda);
}
