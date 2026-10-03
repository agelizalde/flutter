/// Versión publicada de la app Wherehouse (`app_android_versiones`, ver
/// `app_android_service.py`). "Última versión" en el backend es la de mayor
/// `versionCode` entre las activas — acá simplemente mostramos lo que llega.
class VersionApp {
  VersionApp({
    required this.idVersion,
    required this.versionCode,
    required this.versionName,
    this.notasVersion,
    required this.archivoUrl,
    this.archivoTamanoBytes,
    required this.obligatoria,
  });

  factory VersionApp.fromJson(Map<String, dynamic> j) => VersionApp(
    idVersion: j['id_version'] as int,
    versionCode: j['version_code'] as int,
    versionName: j['version_name'] as String? ?? '',
    notasVersion: j['notas_version'] as String?,
    archivoUrl: j['archivo_url'] as String? ?? '',
    archivoTamanoBytes: j['archivo_tamano_bytes'] as int?,
    obligatoria: j['obligatoria'] == true || j['obligatoria'] == 1,
  );

  final int idVersion;
  final int versionCode;
  final String versionName;
  final String? notasVersion;
  final String archivoUrl;
  final int? archivoTamanoBytes;
  final bool obligatoria;
}
