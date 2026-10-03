import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'auth/auth_repository.dart';
import 'auth/sesion_expirada.dart';
import 'db/app_database.dart';
import 'network/dio_client.dart';
import 'storage/secure_storage.dart';
import 'sync/sync_engine.dart';

/// Providers de infraestructura compartidos por toda la app. Cada feature
/// construye sus propios repositorios/providers sobre estos (ver
/// CONTEXTO_WHEREHOUSE.md §3 y §7).
final secureStorageProvider = Provider<SecureStorage>((ref) {
  return SecureStorage(const FlutterSecureStorage());
});

final dioClientProvider = Provider<DioClient>((ref) {
  return DioClient(
    ref.watch(secureStorageProvider),
    onUnauthorized: () => ref.read(sesionExpiradaProvider).add(null),
  );
});

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(dioClientProvider),
    ref.watch(secureStorageProvider),
  );
});

final syncEngineProvider = Provider<SyncEngine>((ref) {
  return SyncEngine(
    ref.watch(appDatabaseProvider),
    ref.watch(dioClientProvider),
  );
});
