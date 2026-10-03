import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../../app/theme.dart';
import '../../../core/config/env.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/providers.dart';
import '../domain/version_app.dart';

/// Diálogo de "hay una versión nueva" — se abre desde `WherehouseShell`
/// cuando `actualizacionDisponibleProvider` resuelve a una versión, o a
/// mano desde "Buscar actualizaciones" en `PerfilScreen`. Descarga el .apk
/// con progreso y al terminar le pide a Android que lo instale
/// (`OpenFilex.open` — dispara la pantalla nativa de instalación; el tap
/// final de "Instalar" es del usuario, Android no permite automatizarlo).
Future<void> mostrarDialogoActualizacion(BuildContext context, VersionApp version) {
  return showDialog<void>(
    context: context,
    barrierDismissible: !version.obligatoria,
    builder: (_) => ActualizacionDialog(version: version),
  );
}

class ActualizacionDialog extends ConsumerStatefulWidget {
  const ActualizacionDialog({super.key, required this.version});

  final VersionApp version;

  @override
  ConsumerState<ActualizacionDialog> createState() => _ActualizacionDialogState();
}

class _ActualizacionDialogState extends ConsumerState<ActualizacionDialog> {
  bool _descargando = false;
  double _progreso = 0;
  String? _error;

  String _formatTamano(int? bytes) {
    if (bytes == null || bytes <= 0) return '';
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }

  Future<void> _actualizar() async {
    setState(() {
      _descargando = true;
      _progreso = 0;
      _error = null;
    });

    try {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/wherehouse_update.apk';
      final url = Env.resolveStorageUrl(widget.version.archivoUrl);
      final dio = ref.read(dioClientProvider).dio;

      await dio.download(
        url,
        path,
        onReceiveProgress: (recibido, total) {
          if (total > 0 && mounted) {
            setState(() => _progreso = recibido / total);
          }
        },
      );

      final resultado = await OpenFilex.open(path);
      if (resultado.type != ResultType.done && mounted) {
        setState(() {
          _error = 'No se pudo abrir el instalador (${resultado.message})';
          _descargando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = describeError(e);
          _descargando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tamano = _formatTamano(widget.version.archivoTamanoBytes);

    return PopScope(
      canPop: !widget.version.obligatoria,
      child: AlertDialog(
        title: const Text('Actualización disponible'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Versión ${widget.version.versionName}${tamano.isNotEmpty ? ' · $tamano' : ''}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if (widget.version.notasVersion?.trim().isNotEmpty ?? false) ...[
              const SizedBox(height: 10),
              Text(widget.version.notasVersion!.trim()),
            ],
            if (widget.version.obligatoria) ...[
              const SizedBox(height: 10),
              const Text(
                'Esta actualización es obligatoria para seguir usando la app.',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
            if (_descargando) ...[
              const SizedBox(height: 18),
              LinearProgressIndicator(value: _progreso > 0 ? _progreso : null),
              const SizedBox(height: 6),
              Text(
                'Descargando… ${(_progreso * 100).toStringAsFixed(0)}%',
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(fontSize: 13, color: AppColors.erTx)),
            ],
          ],
        ),
        actions: [
          if (!widget.version.obligatoria)
            TextButton(
              onPressed: _descargando ? null : () => Navigator.of(context).pop(),
              child: const Text('Más tarde'),
            ),
          FilledButton(
            onPressed: _descargando ? null : _actualizar,
            child: Text(_descargando ? 'Descargando…' : 'Actualizar ahora'),
          ),
        ],
      ),
    );
  }
}
