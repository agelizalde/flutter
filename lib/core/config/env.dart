import 'package:flutter/foundation.dart';

import '../network/backend_resolver.dart';
import '../network/conexion_estado.dart';
import 'servidor_config_store.dart';

/// Configuración de entorno de la app.
///
/// El backend FastAPI no expone proxy `/api` como la web (Vite) — la app
/// corre en un dispositivo físico separado, así que necesita la URL completa
/// del backend. Para producción se define en build time con
/// `--dart-define=API_BASE_URL=...`; en desarrollo se infiere un default
/// razonable según la plataforma. Además, cualquier usuario puede pisar ese
/// valor a mano desde la pantalla "Configurar servidor" (login) sin tener
/// que recompilar — ver `_runtimeOverride` abajo.
class Env {
  static const _override = String.fromEnvironment('API_BASE_URL');

  /// Backend real: red interna de la empresa (`erp.`, DNS interno la
  /// resuelve a la LAN del servidor, filtrado por IP en `nginx.conf`) o
  /// túnel público (`public.`, Cloudflare) cuando el dispositivo no está en
  /// esa red. A diferencia del acceso directo a un puerto del backend
  /// (desarrollo), ambos pasan por nginx bajo el prefijo `/api/` — ver
  /// `apiBaseUrl`. `public.` solo abre `/api/auth/`, `/api/pedidos/`,
  /// `/api/productos/`, `/api/proveedores/`, `/api/compras/oc/` y
  /// `/api/firmas/` (ver `nginx.conf`), así que fuera de la oficina solo
  /// login, pedidos (ver/crear/entregar), OC simple y firmas (ver/aprobar/
  /// rechazar) van a andar; el resto responde 404 a propósito.
  static const _erpOrigin = 'https://erp.riversupply.com.py';
  static const _publicHost = 'public.riversupply.com.py';
  static const _publicOrigin = 'https://$_publicHost';

  /// IP LAN fija del servidor (mismo host que resuelve el DNS interno de
  /// la empresa para `erp.riversupply.com.py`, ver `nginx.conf`). Solo se
  /// usa como último recurso -- ver `_probarErp` -- para no depender de
  /// que el dispositivo resuelva bien ese nombre por su cuenta.
  static const _erpLanIp = '192.168.100.253';

  static final Uri _erpUri = Uri.parse(_erpOrigin);

  /// Host de `erp.` sin esquema ni puerto -- lo usa `AutoDominioHttpOverrides`
  /// para saber a qué requests aplicarles `erpIpForzada`.
  static String get erpHost => _erpUri.host;

  /// true mientras la sesión está llegando a `erp.` a través de
  /// `_erpLanIp` en vez de la resolución DNS normal del dispositivo (ver
  /// `_probarErp`). `AutoDominioHttpOverrides` lo lee en cada conexión
  /// nueva -- Dio, `BackendResolver`, `NetworkImage`, todo por igual -- así
  /// que no hace falta reconstruir nada cuando cambia.
  static bool _erpViaIpLan = false;
  static String? get erpIpForzada => _erpViaIpLan ? _erpLanIp : null;

  static const _resolver = BackendResolver();

  /// Detalle de cada intento (erp. por DNS, erp. por IP forzada, public.)
  /// de la ÚLTIMA resolución que terminó en fallo total -- se muestra en
  /// `SinConexionScreen` (ver `cargarOverrideGuardado`/`reintentarConexion`)
  /// porque sin esto un fallo en el campo (dispositivo real, red de la
  /// empresa) no dice si fue DNS, TLS, timeout, o un código HTTP -- ver
  /// `BackendResolver.disponible`.
  static final List<String> _ultimoDiagnostico = [];
  static void _diag(String detalle) => _ultimoDiagnostico.add(detalle);

  /// Valor guardado en el dispositivo (`ServidorConfigStore`), pisado a
  /// mano desde "Configurar servidor". Gana sobre todo lo demás (incluida
  /// la auto-detección erp./public.) porque es la forma en que alguien
  /// corrige la URL sin recompilar/reinstalar el APK.
  static String? _runtimeOverride;

  /// Origen elegido automáticamente entre `_erpOrigin` y `_publicOrigin`
  /// cuando no hay override manual. A diferencia de `_runtimeOverride`,
  /// este SÍ cambia durante la vida de la app — `marcarErpCaido()` (llamado
  /// por `DioClient` ante un error de conexión), `reevaluarConexion()`
  /// (llamado por `BackendMonitor`) y `reintentarConexion()` (llamado por
  /// el botón "Reintentar" de `SinConexionScreen`) lo actualizan en
  /// caliente, sin reiniciar la app.
  static String? _origenActivo;

  /// true si esta build puede auto-elegir entre erp./public. (release, sin
  /// `--dart-define=API_BASE_URL`). No depende de si hay o no un override
  /// manual activo *ahora mismo* — eso lo resuelve `modoAutoDominioActivo`,
  /// para que "Restablecer al valor de fábrica" en Configurar servidor
  /// reactive la auto-detección sin tratamiento especial.
  static bool get _autoDominioSoportado =>
      kReleaseMode && !kIsWeb && _override.isEmpty;

  /// true cuando la app está auto-eligiendo entre erp./public. ahora mismo
  /// (soportado y sin override manual activo). `BackendMonitor` y el
  /// interceptor de `DioClient` no hacen nada si esto es false.
  static bool get modoAutoDominioActivo =>
      _autoDominioSoportado && _runtimeOverride == null;

  static bool get estaUsandoErp => _origenActivo == _erpOrigin;

  /// true cuando el origen activo ahora mismo es `public.` — override manual
  /// apuntando ahí, o auto-detección que cayó al túnel. Lo usa `HomeScreen`
  /// para ocultar las tarjetas de módulos que ni loguean intentan (ver
  /// `_ModuloDeposito.requiereRedInterna`): `public.` solo abre
  /// `/api/auth/`, `/api/pedidos/`, `/api/clientes/`, `/api/lugares-entrega/`,
  /// `/api/vehiculos/`, `/api/productos/`, `/api/proveedores/`,
  /// `/api/compras/oc/`, `/api/firmas/` y `/api/recepciones/` (esta última
  /// solo para el contexto de diferencia de peso/exceso de cantidad de una
  /// firma) en nginx (ver `nginx.conf`). Firmas no tiene tarjeta propia en
  /// el Home (se llega desde Perfil, no depende de `requiereRedInterna`);
  /// todo lo demás del grid
  /// (Stock/Recepción/Traslados/Picking/etc.) da 404 seguro. En desarrollo
  /// puro (sin auto-detección, sin override) da `false` a propósito — no
  /// tiene sentido restringir módulos mientras se prueba contra un backend
  /// local.
  static bool get usandoAccesoPublico {
    if (_runtimeOverride != null) return _runtimeOverride!.contains(_publicHost);
    return _origenActivo == _publicOrigin;
  }

  /// Espejo `Listenable` de `usandoAccesoPublico` (mismo patrón que
  /// `ConexionEstado.sinConexion`) para que `HomeScreen` pueda reaccionar en
  /// caliente a un cambio de red en medio de la sesión, sin tener que
  /// reabrir la app. Se resincroniza a mano (`_sincronizarAccesoPublico()`)
  /// en cada lugar donde cambia `_origenActivo`/`_runtimeOverride` — no hay
  /// un único setter central para esos dos campos.
  static final ValueNotifier<bool> usandoAccesoPublicoListenable =
      ValueNotifier<bool>(false);

  static void _sincronizarAccesoPublico() {
    usandoAccesoPublicoListenable.value = usandoAccesoPublico;
  }

  /// true si tiene sentido que `BackendMonitor` mantenga vivo su timer:
  /// hay un override manual (puede haberse caído y hay que reintentarlo) o
  /// esta build auto-elige erp./public. En desarrollo puro (sin override,
  /// sin auto-detección) no hay nada que un timer pueda arreglar solo.
  static bool get monitoreoUtil => _runtimeOverride != null || _autoDominioSoportado;

  /// Relee el valor guardado en disco y, si nadie configuró nada a mano,
  /// resuelve el origen inicial probando primero la red de la empresa. Se
  /// llama una vez en `main()` antes de `runApp`, así el primer request ya
  /// usa la URL correcta. No se persiste a disco: se re-evalúa en cada
  /// apertura de la app (y en caliente durante la sesión, ver
  /// `BackendMonitor`). Si ni erp. ni public. responden (override manual
  /// incluido), marca `ConexionEstado` para que el router mande a
  /// `/sin-conexion` en vez de dejar la app esperando en silencio.
  static Future<void> cargarOverrideGuardado() async {
    final guardado = await ServidorConfigStore().leer();
    if (guardado != null) {
      _runtimeOverride = guardado;
      _sincronizarAccesoPublico();
      if (await _probarOverride(guardado)) return;
      if (await _abandonarOverrideFallido()) return;
      ConexionEstado.marcarSinConexion(
        _runtimeOverride == null
            ? _ultimoDiagnostico.join('\n')
            : 'No se pudo conectar con $guardado',
      );
      return;
    }
    if (_autoDominioSoportado && !await _resolverAutoDominio()) {
      ConexionEstado.marcarSinConexion(_ultimoDiagnostico.join('\n'));
    }
  }

  /// Un override manual guardado (pantalla "Configurar servidor") que dejó
  /// de responder no tiene por qué dejar la app sin conexión para siempre
  /// si esta build igual sabe auto-elegir entre erp./public. — pasa
  /// exactamente lo mismo que un teléfono de prueba, configurado hace
  /// tiempo contra la PC de un desarrollador, que termina instalado en el
  /// depósito: sin esto esa URL vieja gana para siempre (ver `apiBaseUrl`)
  /// y la auto-detección, aunque esté perfecta, nunca llega a correr. Lo
  /// abandona (memoria y disco) y cae a la auto-detección, igual que si el
  /// usuario hubiera tocado "Restablecer al valor de fábrica" él mismo. No
  /// hace nada en builds sin auto-detección (dev): ahí un override sigue
  /// ganando siempre, aunque esté caído, porque no hay a dónde más caer.
  /// Devuelve si quedó conectado.
  static Future<bool> _abandonarOverrideFallido() async {
    if (!_autoDominioSoportado) return false;
    final conectado = await _resolverAutoDominio();
    _runtimeOverride = null;
    await ServidorConfigStore().guardar(null);
    _sincronizarAccesoPublico();
    return conectado;
  }

  /// Prueba un override manual ("Configurar servidor"). Si apunta a
  /// `public.` -- la escriban con o sin `/api`, con o sin barra final -- la
  /// raíz de ese host nunca responde por diseño (ver `_publicoDisponible`),
  /// así que probamos `/api/pedidos` en vez de la URL tal cual.
  static Future<bool> _probarOverride(String origen) {
    if (origen.contains(_publicHost)) {
      return _publicoDisponible();
    }
    return _resolver.disponible(origen);
  }

  static Future<bool> _resolverAutoDominio() async {
    if (await _probarErp()) {
      _origenActivo = _erpOrigin;
      _sincronizarAccesoPublico();
      return true;
    }
    final publicoOk = await _publicoDisponible();
    _origenActivo = _publicOrigin;
    _sincronizarAccesoPublico();
    return publicoOk;
  }

  /// Prueba `erp.` con la resolución DNS normal del dispositivo y, si
  /// falla, otra vez pero forzando la IP LAN fija del servidor (ver
  /// `_erpLanIp` y `AutoDominioHttpOverrides`) -- cubre el caso de un
  /// dispositivo que, aun conectado al wifi de la oficina, no resuelve
  /// `erp.riversupply.com.py` a la IP interna (DNS privado de Android,
  /// alguna VPN de otra app instalada, etc.), aunque una PC en esa misma
  /// red sí llegue bien. Si la segunda prueba es la que funciona,
  /// `_erpViaIpLan` queda en `true` para que el resto de los requests de
  /// la sesión (Dio, fotos, etc.) sigan usando esa misma IP forzada.
  static Future<bool> _probarErp() async {
    _ultimoDiagnostico.clear();
    _erpViaIpLan = false;
    if (await _resolver.disponible(
      _erpOrigin,
      onResultado: (d) => _diag('[erp. DNS normal] $d'),
    )) {
      return true;
    }
    _erpViaIpLan = true;
    if (await _resolver.disponible(
      _erpOrigin,
      onResultado: (d) => _diag('[erp. IP forzada $_erpLanIp] $d'),
    )) {
      return true;
    }
    _erpViaIpLan = false;
    return false;
  }

  /// `public.` no sirve nada en `/` a propósito (nginx.conf y el filtro de
  /// Path del túnel de Cloudflare solo dejan pasar prefijos de `/api/`
  /// puntuales — ver `migracion_acceso_publico.sql`), así que un GET a la
  /// raíz siempre da 404 aunque el túnel esté perfecto. Probamos contra
  /// `/api/pedidos`, que sí está en el allowlist, y aceptamos 401 como
  /// "conectado" -- significa que el pedido llegó hasta el backend y solo
  /// falta loguearse, no que el servidor sea inalcanzable.
  static Future<bool> _publicoDisponible() {
    return _resolver.disponible(
      '$_publicOrigin/api/pedidos',
      codigosAdicionales: const {401},
      onResultado: (d) => _diag('[public.] $d'),
    );
  }

  /// Lo llama `DioClient` apenas un request falla por conexión estando en
  /// erp. — pasa a public. al toque, sin esperar al próximo chequeo
  /// periódico de `BackendMonitor`. Idempotente: si ya estábamos en
  /// public. no hace nada.
  static void marcarErpCaido() {
    if (modoAutoDominioActivo && _origenActivo == _erpOrigin) {
      _origenActivo = _publicOrigin;
      _erpViaIpLan = false;
      _sincronizarAccesoPublico();
    }
  }

  /// Lo llama `BackendMonitor` cada cierto tiempo (o ante un cambio de red)
  /// para ver si conviene volver a erp., o si ya se puede recuperar algo de
  /// conexión estando totalmente caído — incluido el caso de un override
  /// manual que se cayó (nadie más lo reintenta solo mientras el usuario no
  /// toque "Reintentar"). Si ya está todo bien no hay nada que revisar.
  static Future<void> reevaluarConexion() async {
    if (_runtimeOverride != null) {
      if (!ConexionEstado.sinConexion.value) return;
      if (await _probarOverride(_runtimeOverride!)) {
        ConexionEstado.marcarConectado();
        return;
      }
      if (await _abandonarOverrideFallido()) {
        ConexionEstado.marcarConectado();
      }
      return;
    }

    if (!modoAutoDominioActivo) return;
    if (_origenActivo == _erpOrigin && !ConexionEstado.sinConexion.value) {
      return;
    }
    if (await _probarErp()) {
      _origenActivo = _erpOrigin;
      _sincronizarAccesoPublico();
      ConexionEstado.marcarConectado();
      return;
    }
    if (ConexionEstado.sinConexion.value && await _publicoDisponible()) {
      _origenActivo = _publicOrigin;
      _sincronizarAccesoPublico();
      ConexionEstado.marcarConectado();
    }
  }

  /// Reintento manual — botón "Reintentar" de `SinConexionScreen`, o al
  /// guardar/restablecer en "Configurar servidor". A diferencia de
  /// `reevaluarConexion()` (que evita pruebas de más si ya está todo bien),
  /// este siempre vuelve a probar posta porque lo disparó el usuario.
  /// Devuelve si quedó conectado.
  static Future<bool> reintentarConexion() async {
    if (_runtimeOverride != null) {
      final origenPrevio = _runtimeOverride;
      if (await _probarOverride(origenPrevio!)) {
        ConexionEstado.marcarConectado();
        return true;
      }
      if (await _abandonarOverrideFallido()) {
        ConexionEstado.marcarConectado();
        return true;
      }
      ConexionEstado.marcarSinConexion('No se pudo conectar con $origenPrevio');
      return false;
    }
    if (!_autoDominioSoportado) {
      // Desarrollo sin override: no hay nada que auto-detectar, y nunca se
      // marcó `ConexionEstado` para esta build — no hay una "pantalla de
      // sin conexión" de la que salir acá.
      return true;
    }
    final ok = await _resolverAutoDominio();
    if (ok) {
      ConexionEstado.marcarConectado();
    } else {
      ConexionEstado.marcarSinConexion(_ultimoDiagnostico.join('\n'));
    }
    return ok;
  }

  /// Actualiza el valor en memoria sin esperar una relectura de disco — lo
  /// usa la pantalla de configuración justo después de guardar/restablecer.
  static void setOverrideEnMemoria(String? url) {
    final trimmed = url?.trim();
    _runtimeOverride = (trimmed != null && trimmed.isNotEmpty) ? trimmed : null;
    _sincronizarAccesoPublico();
  }

  static String get apiBaseUrl {
    if (_runtimeOverride != null) return _runtimeOverride!;
    if (_override.isNotEmpty) return _override;

    if (_origenActivo != null) return '$_origenActivo/api';

    if (kIsWeb) return 'http://127.0.0.1:8000';

    // El emulador de Android no resuelve "localhost" a la máquina host —
    // necesita el alias especial 10.0.2.2. iOS simulator y desktop sí
    // pueden usar localhost directo.
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }

    return 'http://127.0.0.1:8000';
  }

  /// Resuelve una URL de archivo servido por el backend (fotos de
  /// producto, etc.) a una URL absoluta. El storage local devuelve rutas
  /// relativas (`/static/...`); el backend OCI ya devuelve la URL completa
  /// — se detecta por el esquema, no hay flag aparte que lo indique.
  ///
  /// `/static/` cuelga de la raíz de nginx, no de `/api/` (ver
  /// `nginx.conf`), por eso no reusa `apiBaseUrl` en modo dominio. Nota:
  /// `public.` no sirve `/static/` en absoluto (a propósito, expondría
  /// todos los archivos subidos al ERP) — una foto no va a cargar si la
  /// app está en modo público.
  static String resolveStorageUrl(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    if (_origenActivo != null) return '$_origenActivo$url';
    return '$apiBaseUrl$url';
  }
}
