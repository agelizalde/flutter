// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $SyncQueueEntriesTable extends SyncQueueEntries
    with TableInfo<$SyncQueueEntriesTable, SyncQueueEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncQueueEntriesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _entidadMeta = const VerificationMeta(
    'entidad',
  );
  @override
  late final GeneratedColumn<String> entidad = GeneratedColumn<String>(
    'entidad',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accionMeta = const VerificationMeta('accion');
  @override
  late final GeneratedColumn<String> accion = GeneratedColumn<String>(
    'accion',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endpointMeta = const VerificationMeta(
    'endpoint',
  );
  @override
  late final GeneratedColumn<String> endpoint = GeneratedColumn<String>(
    'endpoint',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _metodoHttpMeta = const VerificationMeta(
    'metodoHttp',
  );
  @override
  late final GeneratedColumn<String> metodoHttp = GeneratedColumn<String>(
    'metodo_http',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _expectedVersionMeta = const VerificationMeta(
    'expectedVersion',
  );
  @override
  late final GeneratedColumn<int> expectedVersion = GeneratedColumn<int>(
    'expected_version',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _intentosMeta = const VerificationMeta(
    'intentos',
  );
  @override
  late final GeneratedColumn<int> intentos = GeneratedColumn<int>(
    'intentos',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _estadoMeta = const VerificationMeta('estado');
  @override
  late final GeneratedColumn<String> estado = GeneratedColumn<String>(
    'estado',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('PENDIENTE'),
  );
  static const VerificationMeta _errorDetalleMeta = const VerificationMeta(
    'errorDetalle',
  );
  @override
  late final GeneratedColumn<String> errorDetalle = GeneratedColumn<String>(
    'error_detalle',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _creadoEnMeta = const VerificationMeta(
    'creadoEn',
  );
  @override
  late final GeneratedColumn<DateTime> creadoEn = GeneratedColumn<DateTime>(
    'creado_en',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    entidad,
    accion,
    endpoint,
    metodoHttp,
    payloadJson,
    expectedVersion,
    intentos,
    estado,
    errorDetalle,
    creadoEn,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_queue_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncQueueEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('entidad')) {
      context.handle(
        _entidadMeta,
        entidad.isAcceptableOrUnknown(data['entidad']!, _entidadMeta),
      );
    } else if (isInserting) {
      context.missing(_entidadMeta);
    }
    if (data.containsKey('accion')) {
      context.handle(
        _accionMeta,
        accion.isAcceptableOrUnknown(data['accion']!, _accionMeta),
      );
    } else if (isInserting) {
      context.missing(_accionMeta);
    }
    if (data.containsKey('endpoint')) {
      context.handle(
        _endpointMeta,
        endpoint.isAcceptableOrUnknown(data['endpoint']!, _endpointMeta),
      );
    } else if (isInserting) {
      context.missing(_endpointMeta);
    }
    if (data.containsKey('metodo_http')) {
      context.handle(
        _metodoHttpMeta,
        metodoHttp.isAcceptableOrUnknown(data['metodo_http']!, _metodoHttpMeta),
      );
    } else if (isInserting) {
      context.missing(_metodoHttpMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('expected_version')) {
      context.handle(
        _expectedVersionMeta,
        expectedVersion.isAcceptableOrUnknown(
          data['expected_version']!,
          _expectedVersionMeta,
        ),
      );
    }
    if (data.containsKey('intentos')) {
      context.handle(
        _intentosMeta,
        intentos.isAcceptableOrUnknown(data['intentos']!, _intentosMeta),
      );
    }
    if (data.containsKey('estado')) {
      context.handle(
        _estadoMeta,
        estado.isAcceptableOrUnknown(data['estado']!, _estadoMeta),
      );
    }
    if (data.containsKey('error_detalle')) {
      context.handle(
        _errorDetalleMeta,
        errorDetalle.isAcceptableOrUnknown(
          data['error_detalle']!,
          _errorDetalleMeta,
        ),
      );
    }
    if (data.containsKey('creado_en')) {
      context.handle(
        _creadoEnMeta,
        creadoEn.isAcceptableOrUnknown(data['creado_en']!, _creadoEnMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncQueueEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncQueueEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      entidad: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entidad'],
      )!,
      accion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}accion'],
      )!,
      endpoint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}endpoint'],
      )!,
      metodoHttp: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}metodo_http'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      expectedVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}expected_version'],
      ),
      intentos: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}intentos'],
      )!,
      estado: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}estado'],
      )!,
      errorDetalle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_detalle'],
      ),
      creadoEn: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}creado_en'],
      )!,
    );
  }

  @override
  $SyncQueueEntriesTable createAlias(String alias) {
    return $SyncQueueEntriesTable(attachedDatabase, alias);
  }
}

class SyncQueueEntry extends DataClass implements Insertable<SyncQueueEntry> {
  final int id;

  /// Entidad de negocio afectada, ej. 'traslado', 'tarea_picking'.
  final String entidad;

  /// CREATE | UPDATE | ACTION (acciones como 'completar', 'confirmar').
  final String accion;

  /// Path del endpoint backend a invocar (ej. '/traslados/ejecutar').
  final String endpoint;

  /// Método HTTP del endpoint (POST/PATCH/etc.).
  final String metodoHttp;

  /// Payload ya serializado en JSON.
  final String payloadJson;

  /// `row_version` esperado, para detectar conflictos (CONTEXTO.md raíz §7.7).
  final int? expectedVersion;
  final int intentos;

  /// PENDIENTE | ENVIADO | ERROR | CONFLICTO.
  final String estado;
  final String? errorDetalle;
  final DateTime creadoEn;
  const SyncQueueEntry({
    required this.id,
    required this.entidad,
    required this.accion,
    required this.endpoint,
    required this.metodoHttp,
    required this.payloadJson,
    this.expectedVersion,
    required this.intentos,
    required this.estado,
    this.errorDetalle,
    required this.creadoEn,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['entidad'] = Variable<String>(entidad);
    map['accion'] = Variable<String>(accion);
    map['endpoint'] = Variable<String>(endpoint);
    map['metodo_http'] = Variable<String>(metodoHttp);
    map['payload_json'] = Variable<String>(payloadJson);
    if (!nullToAbsent || expectedVersion != null) {
      map['expected_version'] = Variable<int>(expectedVersion);
    }
    map['intentos'] = Variable<int>(intentos);
    map['estado'] = Variable<String>(estado);
    if (!nullToAbsent || errorDetalle != null) {
      map['error_detalle'] = Variable<String>(errorDetalle);
    }
    map['creado_en'] = Variable<DateTime>(creadoEn);
    return map;
  }

  SyncQueueEntriesCompanion toCompanion(bool nullToAbsent) {
    return SyncQueueEntriesCompanion(
      id: Value(id),
      entidad: Value(entidad),
      accion: Value(accion),
      endpoint: Value(endpoint),
      metodoHttp: Value(metodoHttp),
      payloadJson: Value(payloadJson),
      expectedVersion: expectedVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(expectedVersion),
      intentos: Value(intentos),
      estado: Value(estado),
      errorDetalle: errorDetalle == null && nullToAbsent
          ? const Value.absent()
          : Value(errorDetalle),
      creadoEn: Value(creadoEn),
    );
  }

  factory SyncQueueEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncQueueEntry(
      id: serializer.fromJson<int>(json['id']),
      entidad: serializer.fromJson<String>(json['entidad']),
      accion: serializer.fromJson<String>(json['accion']),
      endpoint: serializer.fromJson<String>(json['endpoint']),
      metodoHttp: serializer.fromJson<String>(json['metodoHttp']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      expectedVersion: serializer.fromJson<int?>(json['expectedVersion']),
      intentos: serializer.fromJson<int>(json['intentos']),
      estado: serializer.fromJson<String>(json['estado']),
      errorDetalle: serializer.fromJson<String?>(json['errorDetalle']),
      creadoEn: serializer.fromJson<DateTime>(json['creadoEn']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'entidad': serializer.toJson<String>(entidad),
      'accion': serializer.toJson<String>(accion),
      'endpoint': serializer.toJson<String>(endpoint),
      'metodoHttp': serializer.toJson<String>(metodoHttp),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'expectedVersion': serializer.toJson<int?>(expectedVersion),
      'intentos': serializer.toJson<int>(intentos),
      'estado': serializer.toJson<String>(estado),
      'errorDetalle': serializer.toJson<String?>(errorDetalle),
      'creadoEn': serializer.toJson<DateTime>(creadoEn),
    };
  }

  SyncQueueEntry copyWith({
    int? id,
    String? entidad,
    String? accion,
    String? endpoint,
    String? metodoHttp,
    String? payloadJson,
    Value<int?> expectedVersion = const Value.absent(),
    int? intentos,
    String? estado,
    Value<String?> errorDetalle = const Value.absent(),
    DateTime? creadoEn,
  }) => SyncQueueEntry(
    id: id ?? this.id,
    entidad: entidad ?? this.entidad,
    accion: accion ?? this.accion,
    endpoint: endpoint ?? this.endpoint,
    metodoHttp: metodoHttp ?? this.metodoHttp,
    payloadJson: payloadJson ?? this.payloadJson,
    expectedVersion: expectedVersion.present
        ? expectedVersion.value
        : this.expectedVersion,
    intentos: intentos ?? this.intentos,
    estado: estado ?? this.estado,
    errorDetalle: errorDetalle.present ? errorDetalle.value : this.errorDetalle,
    creadoEn: creadoEn ?? this.creadoEn,
  );
  SyncQueueEntry copyWithCompanion(SyncQueueEntriesCompanion data) {
    return SyncQueueEntry(
      id: data.id.present ? data.id.value : this.id,
      entidad: data.entidad.present ? data.entidad.value : this.entidad,
      accion: data.accion.present ? data.accion.value : this.accion,
      endpoint: data.endpoint.present ? data.endpoint.value : this.endpoint,
      metodoHttp: data.metodoHttp.present
          ? data.metodoHttp.value
          : this.metodoHttp,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      expectedVersion: data.expectedVersion.present
          ? data.expectedVersion.value
          : this.expectedVersion,
      intentos: data.intentos.present ? data.intentos.value : this.intentos,
      estado: data.estado.present ? data.estado.value : this.estado,
      errorDetalle: data.errorDetalle.present
          ? data.errorDetalle.value
          : this.errorDetalle,
      creadoEn: data.creadoEn.present ? data.creadoEn.value : this.creadoEn,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncQueueEntry(')
          ..write('id: $id, ')
          ..write('entidad: $entidad, ')
          ..write('accion: $accion, ')
          ..write('endpoint: $endpoint, ')
          ..write('metodoHttp: $metodoHttp, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('expectedVersion: $expectedVersion, ')
          ..write('intentos: $intentos, ')
          ..write('estado: $estado, ')
          ..write('errorDetalle: $errorDetalle, ')
          ..write('creadoEn: $creadoEn')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    entidad,
    accion,
    endpoint,
    metodoHttp,
    payloadJson,
    expectedVersion,
    intentos,
    estado,
    errorDetalle,
    creadoEn,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncQueueEntry &&
          other.id == this.id &&
          other.entidad == this.entidad &&
          other.accion == this.accion &&
          other.endpoint == this.endpoint &&
          other.metodoHttp == this.metodoHttp &&
          other.payloadJson == this.payloadJson &&
          other.expectedVersion == this.expectedVersion &&
          other.intentos == this.intentos &&
          other.estado == this.estado &&
          other.errorDetalle == this.errorDetalle &&
          other.creadoEn == this.creadoEn);
}

class SyncQueueEntriesCompanion extends UpdateCompanion<SyncQueueEntry> {
  final Value<int> id;
  final Value<String> entidad;
  final Value<String> accion;
  final Value<String> endpoint;
  final Value<String> metodoHttp;
  final Value<String> payloadJson;
  final Value<int?> expectedVersion;
  final Value<int> intentos;
  final Value<String> estado;
  final Value<String?> errorDetalle;
  final Value<DateTime> creadoEn;
  const SyncQueueEntriesCompanion({
    this.id = const Value.absent(),
    this.entidad = const Value.absent(),
    this.accion = const Value.absent(),
    this.endpoint = const Value.absent(),
    this.metodoHttp = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.expectedVersion = const Value.absent(),
    this.intentos = const Value.absent(),
    this.estado = const Value.absent(),
    this.errorDetalle = const Value.absent(),
    this.creadoEn = const Value.absent(),
  });
  SyncQueueEntriesCompanion.insert({
    this.id = const Value.absent(),
    required String entidad,
    required String accion,
    required String endpoint,
    required String metodoHttp,
    required String payloadJson,
    this.expectedVersion = const Value.absent(),
    this.intentos = const Value.absent(),
    this.estado = const Value.absent(),
    this.errorDetalle = const Value.absent(),
    this.creadoEn = const Value.absent(),
  }) : entidad = Value(entidad),
       accion = Value(accion),
       endpoint = Value(endpoint),
       metodoHttp = Value(metodoHttp),
       payloadJson = Value(payloadJson);
  static Insertable<SyncQueueEntry> custom({
    Expression<int>? id,
    Expression<String>? entidad,
    Expression<String>? accion,
    Expression<String>? endpoint,
    Expression<String>? metodoHttp,
    Expression<String>? payloadJson,
    Expression<int>? expectedVersion,
    Expression<int>? intentos,
    Expression<String>? estado,
    Expression<String>? errorDetalle,
    Expression<DateTime>? creadoEn,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (entidad != null) 'entidad': entidad,
      if (accion != null) 'accion': accion,
      if (endpoint != null) 'endpoint': endpoint,
      if (metodoHttp != null) 'metodo_http': metodoHttp,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (expectedVersion != null) 'expected_version': expectedVersion,
      if (intentos != null) 'intentos': intentos,
      if (estado != null) 'estado': estado,
      if (errorDetalle != null) 'error_detalle': errorDetalle,
      if (creadoEn != null) 'creado_en': creadoEn,
    });
  }

  SyncQueueEntriesCompanion copyWith({
    Value<int>? id,
    Value<String>? entidad,
    Value<String>? accion,
    Value<String>? endpoint,
    Value<String>? metodoHttp,
    Value<String>? payloadJson,
    Value<int?>? expectedVersion,
    Value<int>? intentos,
    Value<String>? estado,
    Value<String?>? errorDetalle,
    Value<DateTime>? creadoEn,
  }) {
    return SyncQueueEntriesCompanion(
      id: id ?? this.id,
      entidad: entidad ?? this.entidad,
      accion: accion ?? this.accion,
      endpoint: endpoint ?? this.endpoint,
      metodoHttp: metodoHttp ?? this.metodoHttp,
      payloadJson: payloadJson ?? this.payloadJson,
      expectedVersion: expectedVersion ?? this.expectedVersion,
      intentos: intentos ?? this.intentos,
      estado: estado ?? this.estado,
      errorDetalle: errorDetalle ?? this.errorDetalle,
      creadoEn: creadoEn ?? this.creadoEn,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (entidad.present) {
      map['entidad'] = Variable<String>(entidad.value);
    }
    if (accion.present) {
      map['accion'] = Variable<String>(accion.value);
    }
    if (endpoint.present) {
      map['endpoint'] = Variable<String>(endpoint.value);
    }
    if (metodoHttp.present) {
      map['metodo_http'] = Variable<String>(metodoHttp.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (expectedVersion.present) {
      map['expected_version'] = Variable<int>(expectedVersion.value);
    }
    if (intentos.present) {
      map['intentos'] = Variable<int>(intentos.value);
    }
    if (estado.present) {
      map['estado'] = Variable<String>(estado.value);
    }
    if (errorDetalle.present) {
      map['error_detalle'] = Variable<String>(errorDetalle.value);
    }
    if (creadoEn.present) {
      map['creado_en'] = Variable<DateTime>(creadoEn.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncQueueEntriesCompanion(')
          ..write('id: $id, ')
          ..write('entidad: $entidad, ')
          ..write('accion: $accion, ')
          ..write('endpoint: $endpoint, ')
          ..write('metodoHttp: $metodoHttp, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('expectedVersion: $expectedVersion, ')
          ..write('intentos: $intentos, ')
          ..write('estado: $estado, ')
          ..write('errorDetalle: $errorDetalle, ')
          ..write('creadoEn: $creadoEn')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SyncQueueEntriesTable syncQueueEntries = $SyncQueueEntriesTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [syncQueueEntries];
}

typedef $$SyncQueueEntriesTableCreateCompanionBuilder =
    SyncQueueEntriesCompanion Function({
      Value<int> id,
      required String entidad,
      required String accion,
      required String endpoint,
      required String metodoHttp,
      required String payloadJson,
      Value<int?> expectedVersion,
      Value<int> intentos,
      Value<String> estado,
      Value<String?> errorDetalle,
      Value<DateTime> creadoEn,
    });
typedef $$SyncQueueEntriesTableUpdateCompanionBuilder =
    SyncQueueEntriesCompanion Function({
      Value<int> id,
      Value<String> entidad,
      Value<String> accion,
      Value<String> endpoint,
      Value<String> metodoHttp,
      Value<String> payloadJson,
      Value<int?> expectedVersion,
      Value<int> intentos,
      Value<String> estado,
      Value<String?> errorDetalle,
      Value<DateTime> creadoEn,
    });

class $$SyncQueueEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $SyncQueueEntriesTable> {
  $$SyncQueueEntriesTableFilterComposer({
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

  ColumnFilters<String> get entidad => $composableBuilder(
    column: $table.entidad,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accion => $composableBuilder(
    column: $table.accion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get endpoint => $composableBuilder(
    column: $table.endpoint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metodoHttp => $composableBuilder(
    column: $table.metodoHttp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get expectedVersion => $composableBuilder(
    column: $table.expectedVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get intentos => $composableBuilder(
    column: $table.intentos,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get estado => $composableBuilder(
    column: $table.estado,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorDetalle => $composableBuilder(
    column: $table.errorDetalle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get creadoEn => $composableBuilder(
    column: $table.creadoEn,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncQueueEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncQueueEntriesTable> {
  $$SyncQueueEntriesTableOrderingComposer({
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

  ColumnOrderings<String> get entidad => $composableBuilder(
    column: $table.entidad,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accion => $composableBuilder(
    column: $table.accion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get endpoint => $composableBuilder(
    column: $table.endpoint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metodoHttp => $composableBuilder(
    column: $table.metodoHttp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get expectedVersion => $composableBuilder(
    column: $table.expectedVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get intentos => $composableBuilder(
    column: $table.intentos,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get estado => $composableBuilder(
    column: $table.estado,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorDetalle => $composableBuilder(
    column: $table.errorDetalle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get creadoEn => $composableBuilder(
    column: $table.creadoEn,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncQueueEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncQueueEntriesTable> {
  $$SyncQueueEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get entidad =>
      $composableBuilder(column: $table.entidad, builder: (column) => column);

  GeneratedColumn<String> get accion =>
      $composableBuilder(column: $table.accion, builder: (column) => column);

  GeneratedColumn<String> get endpoint =>
      $composableBuilder(column: $table.endpoint, builder: (column) => column);

  GeneratedColumn<String> get metodoHttp => $composableBuilder(
    column: $table.metodoHttp,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get expectedVersion => $composableBuilder(
    column: $table.expectedVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get intentos =>
      $composableBuilder(column: $table.intentos, builder: (column) => column);

  GeneratedColumn<String> get estado =>
      $composableBuilder(column: $table.estado, builder: (column) => column);

  GeneratedColumn<String> get errorDetalle => $composableBuilder(
    column: $table.errorDetalle,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get creadoEn =>
      $composableBuilder(column: $table.creadoEn, builder: (column) => column);
}

class $$SyncQueueEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncQueueEntriesTable,
          SyncQueueEntry,
          $$SyncQueueEntriesTableFilterComposer,
          $$SyncQueueEntriesTableOrderingComposer,
          $$SyncQueueEntriesTableAnnotationComposer,
          $$SyncQueueEntriesTableCreateCompanionBuilder,
          $$SyncQueueEntriesTableUpdateCompanionBuilder,
          (
            SyncQueueEntry,
            BaseReferences<
              _$AppDatabase,
              $SyncQueueEntriesTable,
              SyncQueueEntry
            >,
          ),
          SyncQueueEntry,
          PrefetchHooks Function()
        > {
  $$SyncQueueEntriesTableTableManager(
    _$AppDatabase db,
    $SyncQueueEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncQueueEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncQueueEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncQueueEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> entidad = const Value.absent(),
                Value<String> accion = const Value.absent(),
                Value<String> endpoint = const Value.absent(),
                Value<String> metodoHttp = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<int?> expectedVersion = const Value.absent(),
                Value<int> intentos = const Value.absent(),
                Value<String> estado = const Value.absent(),
                Value<String?> errorDetalle = const Value.absent(),
                Value<DateTime> creadoEn = const Value.absent(),
              }) => SyncQueueEntriesCompanion(
                id: id,
                entidad: entidad,
                accion: accion,
                endpoint: endpoint,
                metodoHttp: metodoHttp,
                payloadJson: payloadJson,
                expectedVersion: expectedVersion,
                intentos: intentos,
                estado: estado,
                errorDetalle: errorDetalle,
                creadoEn: creadoEn,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String entidad,
                required String accion,
                required String endpoint,
                required String metodoHttp,
                required String payloadJson,
                Value<int?> expectedVersion = const Value.absent(),
                Value<int> intentos = const Value.absent(),
                Value<String> estado = const Value.absent(),
                Value<String?> errorDetalle = const Value.absent(),
                Value<DateTime> creadoEn = const Value.absent(),
              }) => SyncQueueEntriesCompanion.insert(
                id: id,
                entidad: entidad,
                accion: accion,
                endpoint: endpoint,
                metodoHttp: metodoHttp,
                payloadJson: payloadJson,
                expectedVersion: expectedVersion,
                intentos: intentos,
                estado: estado,
                errorDetalle: errorDetalle,
                creadoEn: creadoEn,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncQueueEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncQueueEntriesTable,
      SyncQueueEntry,
      $$SyncQueueEntriesTableFilterComposer,
      $$SyncQueueEntriesTableOrderingComposer,
      $$SyncQueueEntriesTableAnnotationComposer,
      $$SyncQueueEntriesTableCreateCompanionBuilder,
      $$SyncQueueEntriesTableUpdateCompanionBuilder,
      (
        SyncQueueEntry,
        BaseReferences<_$AppDatabase, $SyncQueueEntriesTable, SyncQueueEntry>,
      ),
      SyncQueueEntry,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SyncQueueEntriesTableTableManager get syncQueueEntries =>
      $$SyncQueueEntriesTableTableManager(_db, _db.syncQueueEntries);
}
