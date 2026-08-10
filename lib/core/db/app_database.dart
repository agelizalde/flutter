import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables/sync_queue_table.dart';

part 'app_database.g.dart';

/// Base de datos local (sqlite vía Drift). Cada feature va a sumar acá sus
/// propias tablas de cache (ver CONTEXTO_WHEREHOUSE.md §6) — `SyncQueueEntries`
/// es la única tabla transversal, usada por todas las features con escritura.
@DriftDatabase(tables: [SyncQueueEntries])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;
}

QueryExecutor _openConnection() {
  return driftDatabase(name: 'wherehouse_db');
}
