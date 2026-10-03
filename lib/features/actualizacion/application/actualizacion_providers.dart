import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/providers.dart';
import '../data/actualizacion_api.dart';
import '../domain/version_app.dart';

/// Versión/`buildNumber` instalados en este dispositivo — el `buildNumber`
/// de Flutter es el `versionCode` de Android como string (el "+N" de
/// `pubspec.yaml`), directamente comparable con `version_code` del backend.
final packageInfoProvider = FutureProvider<PackageInfo>((ref) {
  return PackageInfo.fromPlatform();
});

final actualizacionApiProvider = Provider<ActualizacionApi>((ref) {
  return ActualizacionApi(ref.watch(dioClientProvider).dio);
});

/// `null` si no hay ninguna versión más nueva que la instalada (o si falló
/// el chequeo — no queremos que un error de red se muestre como si fuera
/// una actualización disponible). No es `autoDispose`: se resuelve una sola
/// vez por sesión de la app; `PerfilScreen` puede forzar un recheck con
/// `ref.invalidate(actualizacionDisponibleProvider)`.
final actualizacionDisponibleProvider = FutureProvider<VersionApp?>((ref) async {
  // La actualización es un .apk instalado vía OpenFilex — no existe en web
  // (ni `path_provider` ni "instalar" tienen sentido en el navegador), así
  // que el chequeo ni se hace: nunca hay "versión disponible" para mostrar.
  if (kIsWeb) return null;

  final info = await ref.watch(packageInfoProvider.future);
  final versionInstalada = int.tryParse(info.buildNumber) ?? 0;

  final ultima = await ref.watch(actualizacionApiProvider).ultimaVersion();
  if (ultima == null || ultima.versionCode <= versionInstalada) return null;

  return ultima;
});
