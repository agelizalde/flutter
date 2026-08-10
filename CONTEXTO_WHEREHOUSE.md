# CONTEXTO WHEREHOUSE — App móvil de Depósito

> Referencia permanente para el desarrollo de **Wherehouse**, la app Flutter (Android/iOS, celular y tablet) para operarios de depósito. Consume las APIs del backend del ERP (ver `../CONTEXTO.md` para el detalle completo de stack/endpoints/BD del backend).
>
> Estado (2026-07-07): Fase 0 base + Stock, Recepción (manual), Traslados y Picking operario (flujo core, ver §12d) construidos y funcionales, todos **online-only** (ninguno usa la `sync_queue`/Drift de la Fase 0 — ver §12d). `flutter analyze` corre limpio. Pendiente: instalar Android Studio/Android SDK para poder compilar y probar en un dispositivo/emulador Android (no bloqueante para seguir escribiendo código); verificar Picking end-to-end contra el backend real (no se pudo levantar MySQL desde el entorno que lo construyó).

---

## 1. OBJETIVO Y ALCANCE

App nativa para que los operarios de depósito trabajen desde celular/tablet (en vez de la web del ERP, pensada para escritorio/oficina), con buena experiencia táctil, lectura de código de barras y tolerancia a conectividad débil dentro del depósito.

### Alcance v1
- **Control de stock** — consulta de existencias, KPIs, lotes por vencer
- **Recepción** — recibir mercadería de una OC
- **Traslados** — mover stock entre ubicaciones
- **Asignación de pickers** — asignar zonas/operarios a subpedidos en PICKING
- **Picking (operario)** — el flujo que el backend ya diseñó pensando en tablet (`/picking-operario`)
- **Control de calidad** — revisión post-picking (`/picking-control`)
- **Expedición** — ⚠️ ver nota en sección 5, no tiene endpoint backend dedicado todavía
- **Generación de pedidos** — ⚠️ confirmar con negocio el caso de uso exacto (¿pedido de venta normal desde depósito, o solicitud interna de reposición?) antes de construir la pantalla
- **Producción** — elegir receta, producir con cronómetro y finalizar cargando consumo/resultado/merma reales (ver §12f)

### Roadmap
Después de v1 se irán incorporando otros módulos del depósito (mermas, ajustes de stock, informes, etc.) sobre la misma arquitectura.

---

## 2. STACK TECNOLÓGICO

| Componente | Tecnología | Motivo |
|---|---|---|
| Framework | Flutter (stable) + Dart | Multiplataforma nativo, un solo código para Android/iOS/tablet |
| Estado | Riverpod (+ `riverpod_generator`) | Elegido por el usuario — estándar moderno, testeable |
| HTTP | `dio` | Interceptors para JWT, retry, logging |
| Cache/offline | `drift` (sqlite) | Tablas locales espejo + cola de sincronización |
| Auth storage | `flutter_secure_storage` | Token JWT fuera de shared_prefs plano |
| Navegación | `go_router` | Rutas declarativas, deep links si hace falta |
| Conectividad | `connectivity_plus` | Disparar sync al recuperar conexión |
| Escaneo | `mobile_scanner` | Códigos de barra de productos/contenedores (`productos_codigos_barra`) |
| Config entornos | `--dart-define` / `flutter_dotenv` | URL del backend por entorno (dev/staging/prod) |

No se reutiliza nada del frontend React — es un proyecto Flutter independiente (`wherehouse/`), pero consume las **mismas APIs** del backend FastAPI (`new21-3/back-app`) y respeta sus mismas reglas (optimistic locking con `row_version`/`expected_version`, permisos, JWT).

---

## 3. ARQUITECTURA GENERAL

**Offline-first** desde el día uno (decisión tomada: el depósito puede tener wifi débil/zonas sin señal).

- **Organización**: feature-first (cada módulo de negocio es una carpeta autocontenida).
- **Capas por feature**:
  - `presentation/` — screens, widgets, Riverpod providers/notifiers de UI
  - `domain/` — entidades y contrato de repositorio (interfaces), sin dependencias de Flutter ni de Drift/Dio
  - `data/` — `*_remote_datasource.dart` (Dio), `*_local_datasource.dart` (Drift), `*_repository_impl.dart` (decide remoto vs cache, resuelve qué se sirve a la UI)
- **Patrón repositorio**: la UI nunca llama a Dio ni a Drift directamente, solo al repositorio de la feature.
- **Cola de sincronización** (`core/sync`): tabla local `sync_queue` (acción pendiente, entidad, payload, `expected_version`, intentos, estado `PENDIENTE/ENVIADO/ERROR`). Un `SyncEngine` la procesa al detectar conexión (o periódicamente) y aplica los cambios contra el backend en orden.
- **Lecturas**: se sirven de cache local primero (UI instantánea), y se refrescan en background si hay conexión (patrón stale-while-revalidate).
- **Escrituras**: se aplican optimistamente en local + se encolan. Si el backend responde `409` (conflicto de `row_version`, igual que la regla del ERP web — ver `../CONTEXTO.md` §7.7), la fila queda marcada como conflicto para resolución manual (no se sobreescribe solo).

---

## 4. AUTENTICACIÓN

Reusa el mismo backend de auth que el ERP web:

- `POST /auth/login` (email/username + password) → guarda el JWT en `flutter_secure_storage`
- `GET /auth/me` → datos del usuario + permisos, para mostrar/ocultar acciones (mismo modelo `modulo.accion` que el ERP — ver `../CONTEXTO.md` §7.8)
- `POST /auth/logout`, `POST /auth/change-password`
- Access token JWT HS256, vigencia 8h (`ERP_ACCESS_TOKEN_MINUTES=480`) — la app debe manejar expiración (redirigir a login) y, si en algún momento el backend agrega refresh tokens, integrarlo
- Un usuario puede tener varios almacenes asignados (`usuarios_almacenes` / `GET /usuarios/{id}/almacenes`) — **pendiente decidir** (sección 11) si Wherehouse fija un almacén por dispositivo o permite elegir/cambiar

---

## 5. MAPEO MÓDULOS v1 → ENDPOINTS BACKEND

| Módulo Wherehouse | Endpoints backend (`new21-3/back-app`) | Notas |
|---|---|---|
| Control de stock | `GET /stock/kpis`, `/stock/existencias`, `/stock/por-producto`, `/stock/por-ubicacion`, `/stock/por-lote`, `/stock/lotes-por-vencer` | Solo lectura — buen primer módulo para validar la cache offline |
| Recepción | `GET/POST/PATCH /recepciones`, `POST /recepciones/solicitud-actualizacion-oc` | Incluye registrar lote/vencimiento (luego genera `lotes` al confirmar) |
| Traslados | `GET/POST /traslados`, `POST /traslados/ejecutar` (crear+confirmar en un paso, preferido), `GET /traslados/alertas-reacomodo` | Preferir `/traslados/ejecutar` sobre el flujo legacy borrador→confirmar |
| Asignación de pickers | `GET /picking-asignacion/subpedidos[/{id}]`, `POST .../preview`, `.../asignar`, `.../reasignar`, `GET .../historial` | Lógica de zonas con responsable (auto) vs round-robin ya vive en el backend |
| Picking (operario) | `GET /picking-operario/mis-tareas`, `.../contenedor/buscar`, `.../cajon/{id}/items`, `POST .../tarea/{id}/completar`, `.../cancelar`, `.../modificar-cantidad`, `.../picking-item/{id}/devolver`, `GET .../despickeo/mis-tareas`, `POST .../despickeo/{id}/confirmar` | **Ya diseñado para tablet en el backend** — candidato a primer módulo de escritura |
| Control de calidad | `GET /picking-control/subpedidos[/{id}]`, `POST .../iniciar`, `.../iniciar-completo`, `POST .../sesion/{id}/item/{id}/revisar`, `.../confirmar`, `.../cancelar`, `.../desconfirmar`, `GET .../informe` | Rechazos generan movimientos `TRASLADO` a REACOMODO |
| **Expedición** | ⚠️ **No existe endpoint backend dedicado.** El frontend React tiene un módulo (`modules/deposito/expedicion/`) que importa `src/api/expedicionApi.js`, **archivo que no existe** — es un módulo roto/placeholder en el ERP web también. `EXPEDIDO` es hoy solo un valor del enum de estado de `pedidos_subpedido`, seteado como parte de la confirmación de `picking-control`. **Antes de construir esta pantalla**: definir con el backend si expedición es un paso explícito (nuevo endpoint) o una vista de solo lectura de subpedidos en estado EXPEDIDO |
| **Generación de pedidos** | `/pedidos`, `/pedidos/subpedidos`, `/pedidos/items` (ver `../CONTEXTO.md` §3.6) | ⚠️ Confirmar con negocio el caso de uso: ¿el operario de depósito crea pedidos de venta normales, o se refiere a una solicitud interna de reposición (`/compras/solicitud-interna`)? Afecta qué API se integra |
| Producción (implementado 2026-07-13) | `GET /produccion/recetas[/{id}]`, `POST /produccion/ordenes/preview`, `POST /produccion/ordenes`, `POST .../{id}/iniciar`, `.../pausar`, `.../reanudar`, `.../finalizar`, `.../anular`, `GET /produccion/ordenes[/{id}]` (ver `../CONTEXTO.md` §3.9) | Mismos endpoints que el flujo Taller de la web (`/produccion/taller`) — no hay backend propio para mobile. `/finalizar` no manda `id_ubicacion_destino`, el backend usa la recomendada de la zona PRODUCCION (ver 12f) |

---

## 6. MODELO DE DATOS LOCAL (CACHE + SYNC)

Tablas Drift propuestas (solo los campos que la UI necesita, no espejos completos del esquema MySQL):

| Tabla local | Espejo de | Uso |
|---|---|---|
| `stock_existencias_cache` | `stock_existencias` (+ join producto/ubicación) | Listado de stock offline |
| `recepciones_cache` / `recepcion_items_cache` | `recepcion` / `recepcion_items` | Recepciones en curso |
| `traslados_cache` | `traspasos` / `traspasos_items` | Historial + traslados pendientes de sync |
| `tareas_picking_cache` | `stock_reserva_picking` (vista de "mis tareas") | Lista de tareas del operario logueado |
| `picking_control_cache` | `picking_control` / `picking_control_items` | Sesiones de control en curso |
| `usuarios_cache` | `usuarios` (subset) | Perfil + permisos cacheados para arrancar sin red |

**`sync_queue`** (motor de sincronización, una sola tabla para todas las features):

```
id              INTEGER PK
entidad         TEXT      -- ej. 'traslado', 'tarea_picking', 'recepcion'
accion          TEXT      -- CREATE | UPDATE | ACTION (ej. 'completar', 'confirmar')
endpoint        TEXT
payload_json    TEXT
expected_version INTEGER NULL
intentos        INTEGER DEFAULT 0
estado          TEXT      -- PENDIENTE | ENVIADO | ERROR | CONFLICTO
error_detalle   TEXT NULL
creado_en       DATETIME
```

Reglas:
- Las acciones se procesan en el orden en que se crearon (FIFO por entidad/registro relacionado).
- Si el backend responde `409` (conflicto de `row_version`), la fila pasa a `CONFLICTO` y no se reintenta sola — requiere que el usuario revise (recargar datos del servidor y decidir).
- Reintentos con backoff simple ante errores de red (no ante errores 4xx de negocio, esos no se reintentan).

---

## 7. ESTRUCTURA DE CARPETAS

> Generada con `flutter create` (2026-06-26) y con la base de la Fase 0 ya escrita. Las carpetas `features/*` distintas de `auth`/`home` existen pero todavía están vacías (`data/`, `domain/`, `presentation/`), listas para la Fase 1+.

`lib/core/widgets/wherehouse_app_bar.dart` — navbar común (logo izquierda, botón de scan circular centro, menú de usuario derecha con Perfil/Ajustes/Cerrar sesión), usado como `appBar:` de `HomeScreen`. El botón central hoy navega a una pantalla placeholder (`/escaner`); el plan es que más adelante dispare directo el escaneo de código de barras con `mobile_scanner` (ya en pubspec.yaml) en vez de navegar. "Perfil" y "Ajustes" también son placeholders (`/perfil`, `/ajustes`). Logo en `assets/images/logo.jpg` (copiado del mismo archivo que usa la web React, `erp - 21-3/public/logo.jpg` — marca "River Supply").

**Importante al verificar UI visualmente**: esta es una app para teléfono/tablet — probarla en un viewport de escritorio (1280x900) la hace ver "rara" (todo separado, proporciones raras). Siempre verificar con un viewport de teléfono real (ej. 390x844) antes de evaluar cómo queda un diseño.

### Rediseño visual tipo Holded (2026-06-26)

A pedido del usuario ("la visual no me convence, pensaba en un diseño tipo Holded"), se actualizó el sistema de diseño en `lib/app/theme.dart`:

- **Acento de marca**: `AppColors.accent` (`#4F46E5`, índigo) reemplaza al negro/neutro (`AppColors.ink`) en botones primarios, FAB, focus de inputs, texto de `TextButton` y segmento seleccionado de `SegmentedButton`. `ink` sigue existiendo (texto principal) pero ya no se usa para acciones — si se necesita un color de acción, usar `accent`/`accentDark`/`accentSoft`, nunca `ink`.
- **Inputs**: `InputDecorationTheme` global ahora es "filled, sin borde duro" (`fillColor: AppColors.soft`, `border: BorderSide.none`, radio 14, borde índigo solo al enfocar). Como `TextField`/`DropdownButtonFormField` heredan esto automáticamente, **no hace falta tocar pantalla por pantalla** — cualquier formulario nuevo ya sale con el estilo correcto solo usando los widgets estándar de Material con `InputDecoration` normal.
- **Botones**: `ElevatedButton` (accent, radio 14, sin elevación), `OutlinedButton` (borde neutro), `TextButton` (texto accent) definidos centralmente — no pasar `style:`/`backgroundColor:` manual en botones nuevos salvo necesidad real.
- **Listas de resultados** (bottom sheets de búsqueda en Recepción: proveedor, producto): se reemplazaron los `ListTile` planos por filas tipo tarjeta (`Material` + `InkWell`, icono en chip `accentSoft`, `chevron_right`) — mismo patrón que ya usaba Stock (`_ResultCard`). Si se agregan más selectores de búsqueda, replicar este patrón en vez de `ListTile` simple.
- **Bottom sheets**: usar `backgroundColor: Colors.transparent` en `showModalBottomSheet` + un `Container` propio con `borderRadius: BorderRadius.vertical(top: Radius.circular(24))` y un drag-handle (`Container` gris de 36×4) — el sheet default de Material no tiene esquinas redondeadas arriba ni handle.
- Las 8 tarjetas de color del Home (§12) **no se tocaron** — son una decisión de diseño separada y ya aprobada (un color por módulo para escaneo visual rápido), no siguen el acento único.

### Etiqueta de identificación de pantalla (debug-only)

`lib/core/widgets/debug_screen_tag.dart` (`DebugScreenTag`) — chip discreto abajo a la izquierda con el nombre de la pantalla (ej. "Recepción · Detalle"), para que el usuario pueda referirse a una pantalla puntual al pedir ajustes. Se envuelve en cada `GoRoute.builder` de `app/router.dart`, no en cada Scaffold individual. Solo se muestra si `kDebugMode` es true (desaparece sola en una build de release — verificado comparando `flutter build web` normal, que no la muestra, contra `flutter build web --debug`, que sí). Las pantallas `ComingSoonScreen` no se envuelven porque ya muestran su nombre como título del AppBar. **Al agregar una ruta nueva, envolver el `child` en `DebugScreenTag(label: '<Módulo> · <Pantalla>', child: ...)` siguiendo la misma convención de nombres.**

**Error de consola benigno conocido** (`flutter run -d chrome`, debug-mode-web): `Assertion failed ... _viewInsets.isNonNegative ... ViewInsets cannot be negative`. Es un bug del engine de Flutter web (cálculo de insets de teclado virtual al redimensionar la ventana/zoom con un `TextField` enfocado) — no es nuestro código. Solo ocurre en debug web (los `assert` se eliminan en `flutter build web` y no aplica en builds nativas Android/iOS). Confirmado que no rompe nada visible — ignorar si reaparece.

`HomeScreen` (`lib/features/home/presentation/home_screen.dart`): saludo dinámico según hora del día + nombre del usuario, grilla de módulos con tarjetas elevadas (sombra suave, sin borde) y un color distinto por módulo en el chip del ícono (paleta curada en `_modulos`, no son los tokens semánticos T.ok/T.wa/etc. del design system web — son colores de marca para diferenciar módulos a simple vista, pensado para operarios que la van a usar rápido/apurados).

`_ModuloCard` envuelve su contenido en `FittedBox(fit: BoxFit.scaleDown)` — si la celda de la grilla termina siendo más chica de lo esperado (ventana de Chrome angosta en dev, tablet en split-screen, rotación), el contenido se achica en vez de tirar un `RenderFlex overflowed`. Aplicar el mismo patrón a futuras tarjetas/tiles de tamaño fijo en vez de asumir que el viewport siempre va a ser "tamaño teléfono normal".

```
wherehouse/
├── CONTEXTO_WHEREHOUSE.md     # este documento
├── pubspec.yaml
├── lib/
│   ├── main.dart
│   ├── app/                   # MaterialApp/theme/router raíz
│   │   ├── app.dart
│   │   ├── theme.dart         # paleta mobile (ver §8)
│   │   └── router.dart        # go_router
│   ├── core/
│   │   ├── network/           # dio_client.dart (interceptor JWT, base URL por entorno)
│   │   ├── storage/           # secure_storage.dart
│   │   ├── db/                # app_database.dart (Drift) + tablas
│   │   ├── sync/              # sync_queue.dart, sync_engine.dart
│   │   ├── auth/               # auth_repository (login/me/logout), permission_guard
│   │   └── errors/             # mapeo de errores backend (409, 422, etc.)
│   └── features/
│       ├── auth/
│       ├── stock/
│       ├── recepcion/
│       ├── traslados/
│       ├── picking_asignacion/
│       ├── picking_operario/
│       ├── picking_control/
│       ├── expedicion/         # placeholder hasta definir backend (§5)
│       └── pedidos/
│           └── (cada una con data/ domain/ presentation/, ver §3)
└── test/
```

---

## 8. DISEÑO / UI

- Material 3, mobile-first (no es un calco del "Neutral Moderno" de `manifiestoStyle.txt`, pensado para mouse/escritorio, pero **sí reusar la misma paleta de tokens** stone/warm-gray para consistencia de marca entre la web y la app).
- Targets táctiles grandes (operarios con guantes, uso con una mano sosteniendo productos/escáner).
- Pantallas clave con escaneo de código de barras integrado (`mobile_scanner`) en lugar de búsqueda por texto cuando aplica (buscar contenedor, identificar producto).
- Modo tablet: layouts adaptactivos (no solo estirar el de celular) para las pantallas de asignación de pickers y control de calidad, que tienen más densidad de información.

---

## 9. CONVENCIONES DE CÓDIGO

| Contexto | Convención | Ejemplo |
|---|---|---|
| Archivos Dart | snake_case | `tareas_picking_repository.dart` |
| Clases | PascalCase | `TareasPickingRepository` |
| Variables/métodos | camelCase | `completarTarea()` |
| Providers Riverpod | sufijo `Provider` / `*NotifierProvider` | `tareasPickingProvider` |
| Carpetas de feature | snake_case, mismo nombre que en el backend cuando aplica | `picking_operario/` |

---

## 10. CONFIGURACIÓN / ENTORNOS

```
API_BASE_URL  # dev: IP local del backend FastAPI en la red del depósito (ej. http://192.168.x.x:8000)
              # prod: dominio del backend
```

A diferencia del frontend web (que usa proxy `/api` de Vite), la app corre en un dispositivo físico separado del backend, así que necesita la URL completa y configurable por build (`--dart-define=API_BASE_URL=...`), no un proxy.

`Env.apiBaseUrl` (`lib/core/config/env.dart`) infiere un default razonable si no se pasa `--dart-define`: `http://127.0.0.1:8000` en web/iOS/desktop, `http://10.0.2.2:8000` en emulador Android (que no resuelve `localhost` a la máquina host).

### Corriendo Wherehouse como web en Chrome (desarrollo)

```
flutter run -d chrome --web-port=5080
```

**Usar siempre el puerto 5080** — el backend (`new21-3/back-app/app.py`) solo permite CORS desde orígenes explícitos en `allow_origins`, igual que ya hace para la web React (puerto 5173). Se agregó `http://localhost:5080` / `http://127.0.0.1:5080` a esa misma lista para que el backend siga sirviendo a ambos frontends (CONTEXTO.md raíz no documenta esto todavía — está solo en `app.py`). Si se corre en otro puerto, el navegador bloquea las respuestas por CORS aunque el backend esté arriba y la URL sea correcta.

Esto **no aplica a builds nativos** (Android/iOS reales) — CORS es una restricción de navegador, no de apps nativas.

---

## 11. PENDIENTES / DECISIONES ABIERTAS

1. **Expedición** — no tiene endpoint backend (§5). Definir antes de construir la pantalla.
2. **Generación de pedidos** — confirmar caso de uso exacto con negocio (§5).
3. **Multi-almacén** — ¿la app fija un almacén por dispositivo, o el usuario elige entre los suyos (`usuarios_almacenes`) al loguearse?
4. **Resolución de conflictos de sync** — hoy se define como "marcar y dejar para revisión manual"; evaluar si algún caso amerita resolución automática (ej. último-gana) más adelante.
5. **Builds** — definir si se distribuye vía Play Store/App Store, MDM interno, o instalación manual de APK en los dispositivos del depósito (afecta firma, actualizaciones, etc.) — no bloqueante para empezar a desarrollar.

---

## 12b. MÓDULO STOCK (implementado 2026-06-26)

Primer módulo funcional de la Fase 1 (solo lectura). `lib/features/stock/`:

- **Búsqueda con 3 modos** (`StockSearchScreen`, `/stock`): Producto, Ubicación, Proveedor — `SegmentedButton` + `TextField` con debounce de 400ms (`Timer` manual, no hay librería de debounce).
  - **Producto** → `GET /stock/por-producto?q=` directo (ya trae stock_total/reservado/disponible agregados).
  - **Ubicación** → `GET /stock/por-ubicacion?q=` (resuelve nombre→id) → al tocar un resultado, `GET /stock/existencias?id_ubicacion=` (pantalla intermedia `UbicacionProductosScreen`, `/stock/ubicacion/:id`) → cada fila navega al detalle del producto. **Importante**: `/stock/por-ubicacion` NO tiene filtro de texto libre que devuelva productos directamente, por eso este drill-down de 2 pasos.
  - **Proveedor** → `GET /proveedores?q=` (resuelve nombre→id, pagina con `page`/`page_size`, no `limit`/`offset` como el resto) → `GET /productos?id_proveedor_cabecera=` (pantalla intermedia `ProveedorProductosScreen`, `/stock/proveedor/:id`). **Importante**: `/productos` no devuelve cantidades de stock, así que esa lista intermedia solo muestra nombre/código, no números.
- **Detalle de producto** (`ProductoDetalleScreen`, `/stock/producto/:id`): combina 3 llamadas en paralelo (`Future.wait`) vía `StockRepository.detalleCompleto()`: `GET /productos/{id}` (datos del producto: categoría/marca/proveedor/unidad), `GET /stock/por-producto/{id}/resumen` (KPIs cantidad real/reservada/disponible), `GET /stock/existencias?id_producto={id}` (desglose por lote+ubicación con código de color en vencimiento: rojo=vencido, ámbar=≤7 días, verde=ok).
- **Parsing defensivo** (`core/utils/parsing.dart`): los campos numéricos de `/stock/existencias` y `/stock/por-producto` llegan como JSON number (Decimal sin cast explícito en el backend), pero `/stock/kpis` y `/stock/valorizacion` los devuelven como string (`str()` explícito en `stock_service.py`) — `parseDouble()` acepta ambos para no romper si un endpoint cambia.
- **Riverpod**: `StateProvider` (modo/query de búsqueda) requiere importar `package:riverpod/legacy.dart` — en Riverpod 3.x se movió ahí, ya no está en `flutter_riverpod.dart` directo. Resto del feature usa `FutureProvider`/`FutureProvider.family` simples, sin generator.
- Verificado end-to-end contra el backend real (datos reales: "Harina 0000", proveedor "Frigorifico Guarani", ubicación "RACK A") con captura de pantalla en viewport de teléfono — los 3 modos de búsqueda y el detalle funcionan.

## 12c. MÓDULO RECEPCIÓN (implementado 2026-06-26, solo MANUAL)

Alcance pedido: únicamente recepción **manual** (sin orden de compra, sin resolver control de calidad — si el scoring automático del backend deriva una recepción a `PEND_CONTROL`, la app solo informa el estado, no tiene pantalla para resolverlo todavía). `lib/features/recepcion/`:

- **Lista** (`RecepcionesListScreen`, `/recepcion`): `GET /recepciones?origen_recepcion=MANUAL`, FAB para crear, badge de estado coloreado (BORRADOR/CONFIRMADA/PEND_CONTROL/CONTROLADA/INGRESADA/ANULADA).
- **Nueva recepción** (`NuevaRecepcionScreen`, `/recepcion/nueva`): proveedor (bottom sheet con búsqueda, reusa `ProveedoresApi` de Stock), almacén (`GET /almacenes`), ubicación de recepción opcional (`GET /ubicaciones?tipo_ubicacion=RECEPCION`) — ver nota de `configuracion_deposito` abajo. `POST /recepciones/manual`.
- **Detalle** (`RecepcionDetalleScreen`, `/recepcion/:id`): header + lista de ítems; si está en BORRADOR permite agregar/quitar ítems y confirmar (`POST /recepciones/{id}/confirmar`); en cualquier otro estado es de solo lectura.
- **Agregar ítem** (`AgregarItemScreen`, `/recepcion/:id/items/nuevo`): busca producto (reusa `ProductosApi` de Stock) → trae `GET /productos/{id}` (sub-objeto `almacenaje`) → muestra dinámicamente lote/vencimiento/faena **solo si el producto los requiere** (`requiere_lote`/`control_vencimiento`/`requiere_fecha_faena` de `productos_almacenaje`). Se queda en la pantalla para cargar varios ítems seguidos; "Listo" vuelve al detalle.
- Reusa `ProductosApi`/`ProveedoresApi` de `features/stock/data/` en vez de duplicarlos — son clientes genéricos de `/productos` y `/proveedores`, no lógica de stock.

### Bugs reales encontrados y corregidos en el camino

1. **Bug de backend (pre-existente, no relacionado a Flutter)**: `RecepcionCreateIn.fecha_recepcion` es `Optional[datetime] = None` en el schema, pero la columna `recepcion.fecha_recepcion` es `NOT NULL` y `recepcion_create_manual`/`recepcion_create` (`recepcion_service.py`) insertaban `payload.fecha_recepcion` tal cual sin default → `IntegrityError: Column 'fecha_recepcion' cannot be null` en **cualquier** cliente que no la mande explícitamente (no era un bug de la app Flutter — se reprodujo idéntico con `curl` puro). Fix aplicado: `fecha_recepcion = payload.fecha_recepcion or datetime.now()` antes del INSERT, en ambas funciones. Diagnosticado corriendo el servicio directo en Python (`C:\Users\Augustog\AppData\Local\Python\bin\python.exe`, el intérprete real del backend — el `python` del PATH no tiene `mysql-connector` instalado) para ver el traceback completo, ya que el handler global de errores de `app.py` solo devuelve `{"error":"internal_server_error"}` sin detalle al cliente.
2. **Bug de Flutter — bool vs int inconsistente entre endpoints**: `GET /productos/{id}` devuelve `almacenaje.requiere_lote` como `0`/`1` (int), pero `GET /recepciones/{id}/items` devuelve `requiere_lote`/`requiere_vencimiento`/`requiere_faena` como `true`/`false` (bool real) — mismas columnas de `productos_almacenaje`, distinta serialización según el query. Parsear ambos como si fueran siempre int causaba `TypeError: false: type 'bool' is not a subtype of type 'int?'`. **No asumir que un flag se serializa igual en dos endpoints distintos solo porque viene de la misma columna — verificar cada response por separado.**
3. **Bug de UX (afecta toda la app, no solo Recepción)**: los `catch (e)` y `error: (e, _)` mostraban `e.toString()` de un `DioException` crudo (la API de Dio obliga a que los interceptores rechacen con `DioException`, envolviendo el `AppException` mapeado en `.error`) — el usuario veía el volcado verboso de Dio en vez del mensaje limpio del backend. Fix: `describeError(Object e)` en `core/errors/app_exception.dart`, que desenvuelve `DioException.error` si es un `AppException`. Reemplazado en todas las pantallas (Stock incluido). **Usar siempre `describeError(e)`, nunca `e.toString()`, para mostrarle errores al usuario.**

### Rediseño de la pantalla de entrada al módulo (2026-06-26)

A pedido del usuario, `/recepcion` dejó de ser una lista plana y pasó a ser una mini-dashboard de 2 pantallas:

- **`RecepcionHomeScreen`** (`/recepcion`): tarjeta grande "Nueva recepción" (CTA principal, fondo `accent` sólido) + "Tus últimas recepciones" (`recepcionesRecientesProvider`: últimas 5 del usuario logueado vía `GET /recepciones?id_usuario_receptor=<idUsuario>&limit=5`, **no** de todos los usuarios) + link "Ver historial" al historial completo. Estado vacío si el usuario nunca creó ninguna.
- **`RecepcionHistorialScreen`** (`/recepcion/historial`): todas las recepciones (sin filtro de usuario), con buscador (`q`, debounce 400ms) sobre proveedor/almacén/observación — reusa el filtro `q` que ya soportaba `GET /recepciones`. Sin FAB — la acción de crear vive en el Home.
- Ambas reusan `RecepcionTile`/`EstadoRecepcionVisual` (`presentation/widgets/recepcion_tile.dart`) para que las filas se vean idénticas en las dos pantallas — si se ajusta el diseño de una fila, tocar ese archivo único.
- `recepcionesRecientesProvider` depende de `authControllerProvider.future` para el `idUsuario` — se recalcula solo en login/logout. Después de crear (`NuevaRecepcionScreen`) o confirmar (`RecepcionDetalleScreen`) una recepción, se invalidan **ambos** providers (`recepcionesRecientesProvider` + `recepcionHistorialProvider`), no uno solo, para que las dos pantallas queden al día.
- Se eliminó `recepciones_list_screen.dart` (la pantalla vieja, sustituida por las dos de arriba) y el provider `recepcionesListProvider` que usaba.

### Almacén invisible + ubicación preseleccionada (2026-06-26)

`NuevaRecepcionScreen` **ya no muestra el almacén en pantalla, ni siquiera de forma editable**. El almacén se resuelve en silencio:
- **Almacén**: el `id_almacen_seleccionado` del usuario logueado (`UsuarioActual.idAlmacenSeleccionado`, viene de `GET /auth/me`) — no hay dropdown, no se muestra cuál es. Si el usuario no tiene ninguno asignado, la pantalla bloquea la creación con un mensaje ("Pedile a un administrador que te asigne uno") en vez de dejarlo elegir uno a mano.
- **Ubicación de recepción**: SÍ es visible y editable. Se preselecciona con la **primera** ubicación de tipo `RECEPCION` del almacén resuelto (`GET /ubicaciones?id_almacen=&tipo_ubicacion=RECEPCION`, primer elemento de la lista). Si tiene más de una, el dropdown deja elegir otra. Si no tiene ninguna, cae a "Automática (configuración del depósito)" con una nota explicativa.

**Importante — versión anterior descartada**: la primera implementación dejaba el almacén visible y editable en un dropdown (con preselección). El usuario pidió explícitamente sacarlo de la pantalla por completo ("que ni siquiera le salga qué almacén es, directamente que vea ubicaciones") — si se vuelve a tocar esta pantalla, **no reintroducir el selector de almacén** salvo que el usuario lo pida de nuevo.

La pantalla tiene 3 estados de carga distintos en `build()`: `_resolviendoAlmacen` (spinner), `_sinAlmacenAsignado` (bloqueo con mensaje), y el form normal — los tres se resuelven en `initState`/`_resolverAlmacenDelUsuario`, antes de mostrar nada del formulario.

**Bug real de Flutter encontrado y corregido**: `DropdownButtonFormField.initialValue` solo se aplica **una vez**, al crear el widget — si se cambia `_almacen`/`_ubicacion` por código después (ej. la preselección async en `initState`), el dropdown sigue mostrando el placeholder viejo aunque el estado interno ya tenga el valor correcto. Fix: agregar `key: ValueKey('almacen-${_almacen?.idAlmacen}')` (e ídem para ubicación) — al cambiar el id cambia la key, Flutter recrea el `FormField` desde cero y ahí sí toma el `initialValue` nuevo. **Aplicar el mismo patrón si se preselecciona programáticamente cualquier otro `DropdownButtonFormField` en el futuro.**

**Bug real de backend encontrado (no de Flutter)**: `id_almacen_seleccionado` existe como columna en **dos tablas** (`usuarios` y `usuarios_datos`), pero `/auth/me` (`build_current_user` en `core/security.py`, vía `validate_session`) lee el valor de **`usuarios_datos.id_almacen_seleccionado`**, no de `usuarios.id_almacen_seleccionado`. Si algún script/herramienta administrativa actualiza la columna de `usuarios` pensando que es esa la fuente de verdad (como documenta la tabla en CONTEXTO.md raíz §4.1), el cambio **no se refleja en la sesión real** — hay que tocar `usuarios_datos`. Vale la pena que alguien revise si esto es un duplicado a propósito (¿una es legacy?) o un bug de diseño de esquema.

### Decisión de diseño: ubicación de recepción opcional

`POST /recepciones/manual` no exige `id_ubicacion_recepcion` — si se omite, el backend la resuelve de `configuracion_deposito` por el `id_almacen` de la recepción (no por la sesión del usuario). Se dejó el campo opcional en el form (no se fuerza a elegir) porque el error 409 ya se muestra claro vía `describeError` — si en algún almacén falta la config, el usuario lo nota al confirmar.

**Bug real resuelto 2026-06-26: `configuracion_deposito` estaba completamente vacía** (0 filas en toda la tabla) — por eso "Automática" nunca tenía nada que resolver y CUALQUIER recepción manual sin ubicación explícita quedaba colgada en `CONFIRMADA` para siempre al confirmar (el auto-ingreso tira 409 después de que `CONFIRMADA` ya se guardó en su propia transacción — no es atómico). Encontré 3 recepciones reales así en la base (ids 22, 26, 28) más otras 3 más viejas (ids 3, 4, 5) que se habían quedado en `CONFIRMADA` por una razón distinta (probablemente confirmadas con una versión anterior del flujo, antes de que existiera el auto-ingreso — sí tenían ubicación pero el ingreso nunca se disparó).

**Fix aplicado**: inserté una fila en `configuracion_deposito` para `id_almacen=1` (River Supply) → `id_ubicacion_recepcion=2` (RECEPCION-01, la misma que ya usan otras recepciones reales). Verificado: una recepción nueva sin elegir ubicación ahora confirma directo a `INGRESADA`. También resolví manualmente las 6 recepciones que habían quedado colgadas (ids 3, 4, 5, 22, 26, 28) llamando a `recepcion_dar_ingreso` directo en Python (bypasea el chequeo de permiso HTTP — ver nota de permisos abajo).

**Pendiente, no resuelto**: `id_almacen=2` (Capasa 1) **no tiene ninguna ubicación de tipo `RECEPCION`** — no hay ninguna ubicación válida para configurarle como default. Si se crea una recepción manual en Capasa 1 sin elegir ubicación explícita, va a volver a quedar colgada en `CONFIRMADA`. Hace falta que alguien cree una ubicación tipo RECEPCION para ese almacén (módulo de Ajustes del ERP web, no algo que se resuelva desde Wherehouse) antes de poder configurar su `configuracion_deposito`.

**Nota de permisos**: el usuario admin de prueba no tiene el permiso `recepciones.ingresar` (confirmado con un 403 real al pegarle al endpoint `/recepciones/{id}/dar-ingreso` directamente) — probablemente porque ese código de permiso no existe todavía como fila en `usuarios_permisos` (no se puede asignar un permiso que no existe). Si en el futuro se construye una pantalla de "reintentar ingreso" en Wherehouse para resolver recepciones colgadas en `CONFIRMADA`, va a fallar con 403 hasta que se seedee ese permiso.

### Rediseño de Recepción · Inicio v2 — permisos + filtros por estado (2026-06-26)

A pedido del usuario, `RecepcionHomeScreen` cambió de nuevo:

- **"Recibir OC"**: botón principal, deshabilitado visualmente (gris, ícono apagado) con badge "PRÓXIMAMENTE" — representa el flujo de recepción desde orden de compra, todavía no construido. Sigue siendo tappable y muestra un snackbar explicativo en vez de quedar completamente muerto.
- **"Recepción manual"**: botón secundario (acento, igual que antes), **solo visible si el usuario tiene el permiso `recepciones.manual`** (`usuario.tienePermiso('recepciones.manual')`) — si no lo tiene, el botón ni se renderiza, no queda deshabilitado.
- **"Historial" y "Pendientes de control"**: dos tiles cuadrados lado a lado (reemplazan el link de texto "Ver historial" de la versión anterior). Ambos navegan a `RecepcionHistorialScreen`, parametrizada con `estadoFijo`/`titulo` — `/recepcion/historial` (sin filtro) y `/recepcion/pendientes-control` (`estadoFijo: 'PEND_CONTROL'`).
- **"Tus últimas recepciones"**: ya no muestra las últimas 5 de cualquier estado — ahora son las últimas 5 que están **`PEND_CONTROL` o `INGRESADA`** únicamente (lo que el usuario necesita ver de un vistazo: qué quedó pendiente y qué se completó). El backend no soporta filtrar por una lista de estados en una sola llamada (`recepcion_list` solo acepta `estado=` singular), así que `recepcionesRecientesProvider` pide ambos estados por separado (`Future.wait`) y mezcla+ordena+recorta a 5 del lado del cliente.
- Las filas con estado `PEND_CONTROL` (`RecepcionTile`) muestran un ícono de alerta (`Icons.warning_amber_rounded`) en naranja vívido (`AppColors.alertBg`/`alertTx`, nuevos tokens — distintos del ámbar `wa*` genérico que ya se usaba para vencimientos en Stock) en vez del ícono de caja genérico.
- **`RecepcionHistorialScreen` ahora SIEMPRE filtra por el usuario logueado** (`id_usuario_receptor`) — antes el historial mostraba las recepciones de **todos** los usuarios; ahora cada operario solo ve las que él mismo creó, en historial y en pendientes de control. **Importante**: esto es un filtro de UX del lado del cliente (parámetro de query al mismo `GET /recepciones` de siempre), **no** una restricción real de seguridad en el backend — cualquiera con el permiso `recepciones.ver` y acceso directo a la API podría seguir viendo recepciones de otros usuarios si quisiera. Si en algún momento esto necesita ser una restricción real, hay que implementarla en el backend (`recepcion_list`), no alcanza con el filtro de Wherehouse.
- Provider nuevo: `recepcionListadoProvider` (`FutureProvider.family<List<Recepcion>, (String query, String? estado)>`) — reemplazó a `recepcionHistorialProvider`/`recepcionHistorialQueryProvider`. Para refrescar después de crear/confirmar una recepción, invalidar la familia completa: `ref.invalidate(recepcionListadoProvider)` (sin argumentos invalida todas las instancias).

**Permiso `recepciones.manual` — creado en este paso, no preexistía.** No había ningún permiso para gatear específicamente el flujo manual (solo `recepciones.crear/ver/editar/confirmar/ingresar`). Se creó una fila nueva en `usuarios_permisos` (`modulo='recepciones'`, `accion='manual'`, `codigo_permiso='recepciones.manual'`) y se asignó al rol `ADMIN`. **Si se crean roles nuevos para operarios de depósito, hay que asignarles este permiso explícitamente o no van a poder ver el botón de "Recepción manual".**

### Bug real: error transitorio confundido con "sin almacén asignado" (2026-06-27)

El usuario reportó que `NuevaRecepcionScreen` le decía "no tenés un almacén base asignado" pese a tener uno asignado y visible en el modal "Resumen" de `/ajustes/usuarios/usuarios/1` en la web. Investigación:

- Verificado en DB: `usuarios.id_almacen_seleccionado` y `usuarios_datos.id_almacen_seleccionado` son **dos columnas físicas distintas, en tablas distintas, sin ningún trigger que las sincronice**. La web (modal "Resumen", `GET/PUT /usuarios/{id}/almacenes/base`) lee/escribe `usuarios.id_almacen_seleccionado`. Wherehouse (vía `/auth/me` → `core/security.py::validate_session`) lee `usuarios_datos.id_almacen_seleccionado`. Si alguna vez se asigna/cambia el almacén base desde la web, **solo se actualiza la columna que la web usa**, no la que lee Wherehouse — quedan desincronizadas sin que nada avise. Está documentado como deuda de backend a resolver (unificar a una sola columna), no se tocó en este paso.
- Reproduciendo el flujo completo de punta a punta (login real → `/auth/me` → `/almacenes` → pantalla), con los valores actuales de la BD (ambas columnas en `1`) **no se reprodujo el bug** — la pantalla resolvió bien el almacén y mostró el formulario normalmente.
- **La causa real encontrada en el código**: `_resolverAlmacenDelUsuario()` en `nueva_recepcion_screen.dart` tenía un único `catch (_) { _sinAlmacenAsignado = true; }` que convertía **cualquier error** (de red, de backend, lo que sea) en el mismo mensaje "no tenés almacén asignado", de forma permanente hasta cerrar y reabrir la pantalla — sin mostrar el error real ni dejar reintentar. Si en algún momento se disparó un error transitorio (timeout, blip de red, etc.), quedaba mostrando ese mensaje para siempre aunque el almacén estuviera perfectamente asignado.
- **Fix**: se separaron los 3 casos en `nueva_recepcion_screen.dart`: (1) `_sinAlmacenAsignado` — genuinamente `id_almacen_seleccionado == null`, mensaje original; (2) almacén asignado pero no encontrado en `/almacenes` (almacén inactivo/borrado) — mensaje específico con el ID; (3) `_errorResolviendo` — cualquier otro error real, mostrado con `describeError()` + botón "Reintentar" que vuelve a llamar `_resolverAlmacenDelUsuario()` sin necesidad de salir de la pantalla.

### Botón "Controlar" en Recepción · Detalle (2026-06-27)

A pedido del usuario: si una recepción está `PEND_CONTROL` y el usuario tiene el permiso `recepciones.controlar` (**nuevo, no existía** — ni siquiera el endpoint backend `/recepciones/control/*` era usable por nadie hasta crear este permiso y asignarlo a ADMIN, mismo patrón que `recepciones.manual`), aparece un botón "Controlar" (naranja, ícono `fact_check_outlined`) que navega a una pantalla nueva `RecepcionControlScreen` (`/recepcion/:id/controlar`).

Esa pantalla resuelve `POST /recepciones/control/{id_recepcion_control}/resolver`:
- El `id_recepcion_control` no viene en `Recepcion` — hay que buscarlo en `GET /recepciones/control/pendientes` (lista todos los pendientes del sistema, sin filtro por `id_recepcion`; se filtra del lado del cliente) y su `row_version` en `GET /recepciones/control/{id}` (el listado de pendientes no lo trae). Todo esto se combina en el provider `recepcionControlPreparacionProvider`.
- Por cada ítem se carga `cantidad_recibida`/`cantidad_rechazada` (default: toda la cantidad recibida, nada rechazado — el usuario ajusta si hace falta) y se elige un resultado general `POSITIVO`/`NEGATIVO`.
- **Importante**: resolver el control deja la recepción en estado `CONTROLADA`, **no la ingresa a stock automáticamente** — hace falta un paso extra (`POST /recepciones/{id}/reintentar-ingreso`, permiso `recepciones.ingresar`, que ADMIN ya tiene) que **no se construyó en este paso** porque no fue parte de lo pedido. Si se quiere cerrar el círculo completo (controlar → ingresar) sin que la recepción quede "colgada" en CONTROLADA para siempre (mismo tipo de problema que ya pasó antes con `configuracion_deposito` vacía), falta agregar un botón "Dar ingreso" cuando `estado == 'CONTROLADA'`.
- La pantalla de detalle también se rediseñó visualmente para parecerse a Recepción · Inicio: el header ahora tiene un ícono chip (alerta naranja si `PEND_CONTROL`, caja índigo si no) y cada ítem tiene su propio ícono chip — mismo lenguaje visual que `RecepcionTile`.

**Nota de testing**: para verificar el flujo de control de punta a punta se resolvió de verdad la recepción real id=25 (Frigorífico Guaraní, Capasa 1) como `POSITIVO` — quedó en estado `CONTROLADA` en la base real, no es reversible con un endpoint (no hay "deshacer control"). Si esa recepción se estaba usando como caso de prueba para "pendientes de control" en otra demo, ya no va a aparecer ahí.

### Bug real: 422 al agregar ítem con lote+vencimiento+faena (2026-06-27)

El usuario reportó `POST /recepciones/34/items` → 422 al cargar un producto que requiere lote + vencimiento + faena (ej. "Costilla Neuland", id_producto=4). Dos bugs reales encontrados:

1. **Causa de fondo (regla de negocio real, no un bug)**: el backend exige `fecha_vencimiento >= fecha_faenado` (`recepcion_item_service.py`, `model_validator` de `RecepcionItemCreateIn`, espejo del `CHECK` de la tabla `lotes`). `_elegirFecha()` en `agregar_item_screen.dart` abría ambos date pickers con rangos independientes (`initialDate: ahora` para los dos, sin relación entre sí) — nada impedía elegir, por ejemplo, vencimiento el 20/06 y faenado el 25/06 (vencimiento antes que faenado), lo cual el backend rechaza con 422. **Fix**: ahora el picker de "Fecha de faenado" restringe `lastDate` a la fecha de vencimiento ya elegida (si hay una), y el de "Fecha de vencimiento" restringe `firstDate` a la fecha de faenado ya elegida — es estructuralmente imposible armar una combinación inválida desde la UI, en vez de dejarla pasar y que el backend la rechace. Verificado visualmente: tras elegir vencimiento=08/06/2026, el picker de faenado deshabilita (gris) todos los días posteriores al 8.
2. **Bug real y más grave, transversal a TODA la app**: `DioClient._mapError()` (`core/network/dio_client.dart`) extraía `detail` con `error.response?.data['detail']?.toString()`. Eso funciona para errores de negocio normales (`HTTPException(detail="texto")`, `detail` es un `String`), pero **cuando el 422 viene de una validación de Pydantic** (`field_validator`/`model_validator`, como este caso), FastAPI devuelve `detail` como una **lista** de objetos `{loc, msg, type}` — `.toString()` sobre esa lista mostraba un volcado crudo de Dart ilegible en vez del mensaje real ("fecha_vencimiento no puede ser menor que fecha_faenado"). Esto afectaba a cualquier pantalla de la app que pudiera disparar un 422 de validación de Pydantic, no solo a este formulario. **Fix**: `_extraerDetalle()` ahora maneja ambas formas — si `detail` es lista, junta los `msg` de cada item (sacando el prefijo redundante "Value error, " que antepone Pydantic v2 a los `ValueError` de validadores propios).

Reproducido el bug exacto contra el backend real con `curl` (vencimiento 20/06 antes que faenado 25/06 → 422 con el `detail` en formato lista) antes de armar el fix, para confirmar la causa con certeza en vez de adivinar.

### Escaneo de código de barras en "Agregar producto" (2026-06-27)

Primer uso real de `mobile_scanner` (hasta ahora solo era una dependencia instalada en la Fase 0, sin ninguna pantalla conectada — `/escaner` seguía siendo un placeholder `ComingSoonScreen`).

- **`lib/core/widgets/barcode_scanner_screen.dart`** (nuevo, reusable): pantalla full-screen con `MobileScanner` + marco visor + botón de flash + `errorBuilder` (si la cámara no está disponible/permiso denegado, muestra un mensaje en vez de romper). Devuelve (`Navigator.pop`) el `rawValue` crudo del primer código detectado.
- **Backend ya tenía el endpoint necesario** y no hizo falta tocar nada ahí: `GET /productos/codigos-barra/buscar/{codigo}` (`producto_codigo_barra_rout.py`, permiso `productos.ver`) — devuelve `id_producto`/`producto_nombre`/`producto_codigo_interno` si existe, 404 `"Código de barras no encontrado"` si no. Agregado `ProductosApi.buscarPorCodigoBarra()` (reusable por cualquier feature, no solo Recepción) y expuesto en `RecepcionRepository.buscarProductoPorCodigoBarra()`.
- **`agregar_item_screen.dart`**: el campo de búsqueda de producto tiene un ícono de cámara (`suffixIcon`) que abre el escáner; al detectar un código, resuelve el producto y salta directo al formulario dinámico (mismo destino que tocar un resultado de búsqueda por texto). Si el código no está registrado, muestra el mensaje del backend en un snackbar.
- **Permisos de cámara agregados** (no existían): `android/app/src/main/AndroidManifest.xml` (`CAMERA` + features opcionales) e `ios/Runner/Info.plist` (`NSCameraUsageDescription`). Web no necesita nada adicional desde `mobile_scanner` v5+.
- **Verificación**: Chrome headless no tiene cámara real, así que se usaron los flags `--use-fake-device-for-media-stream --use-fake-ui-for-media-stream` para que el navegador otorgue el permiso automáticamente y sirva un feed de video sintético — confirmó que el widget `MobileScanner` renderiza el preview, el visor y el botón de flash sin errores, y que volver atrás no rompe nada. **No se pudo verificar la detección real de un código sobre un frame de cámara** (necesitaría un video sintético con un barcode real codificado, no se armó). Se verificó por separado, contra el backend real, que el endpoint de búsqueda por código resuelve bien tanto un código existente (`778885554654` → "Harina 0000") como uno inexistente (404 con mensaje claro) — la lógica de la app está correctamente conectada a ambos casos. La detección real frame-a-frame solo se puede confirmar en un dispositivo físico.

## 12d. MÓDULO PICKING OPERARIO (implementado 2026-07-07, flujo core)

Justo antes de esta pasada, el backend (`new21-3/back-app/endpoints/modules/deposito/picking_operario/`) fue rediseñado en la misma sesión: agregó sesión de zona con cronómetro server-side (`picking_sesion_zona`), cajón atado a la sesión (ya no un parámetro suelto por request), pesables (`unidades.pesable`, reemplaza al viejo `productos_almacenaje.picking_por_peso`) que aceptan cualquier peso real sin tope, y traslado real de stock a la ubicación de armado al completar cada tarea. `lib/features/picking_operario/`:

- **Alcance de esta pasada**: solo el flujo core del operario — mis tareas → elegir zona (arranca cronómetro) → elegir/escanear cajón → completar tareas (con pesables) → pickeo parcial → terminar sesión. **Explícitamente fuera de alcance** (a pedido del usuario, para una pasada posterior): cancelar tarea / modificar cantidad (acciones de supervisor, requieren modal de credenciales), devolver ítem de un cajón, e informe de subpedidos. Despickeo se agregó después, ver más abajo.
- **Decisión de arquitectura — online-only, sin `sync_queue`**: aunque §3 de este documento describe una arquitectura offline-first con cola de sincronización, en la práctica ninguna feature construida hasta ahora (Stock, Recepción, Traslados) la usa — todas llaman directo a Dio y esperan respuesta. Picking tiene un modelo de sesión *server-authoritative* (cronómetro, timeout de 10 min por inactividad, una sola sesión activa por operario, validación de stock en tiempo real) que encaja mal con escrituras encoladas para sincronizar después con un delay arbitrario — se construyó igual que las demás features, sin cola ni cache local.
- **Pantallas**: `PickingHomeScreen` (`/picking-operario`, lista subpedidos + banner de "zona en curso" si hay sesión activa) → `ZonaSelectorScreen` (`/picking-operario/subpedido/:id/zona`, agrupa tareas pendientes por zona, llama `POST .../zona/iniciar`) → si la sesión queda sin cajón, fuerza `CajonSelectorScreen` (pusheada con `Navigator`, no es ruta — mismo tratamiento que `BarcodeScannerScreen`) → `PickingTrabajoScreen` (`/picking-operario/trabajo`, cronómetro + banner de cajón + lista de tareas de la zona).
- **Sin provider de sesión separado**: `PickingTrabajoScreen` no recibe la sesión por parámetro ni la cachea aparte — siempre la lee de `misTareasProvider` (`data.sesionActiva`), para no arriesgarse a que la UI muestre una sesión que el servidor ya cerró.
- **El polling normal ES el heartbeat**: `GET /picking-operario/mis-tareas` dispara internamente `GET .../zona/sesion/activa` en el backend, que ya actualiza `ultima_actividad_en` — por eso `misTareasProvider` usa `enableSilentRefresh(interval: 20s)` mientras cualquier pantalla del módulo está abierta, y esa sola llamada periódica evita que la sesión se cierre por inactividad sin necesitar un timer de heartbeat separado. Si el operario deja el teléfono quieto/en background más de 10 minutos, el próximo refresh trae `sesion_activa: null` y `PickingTrabajoScreen` lo detecta (diálogo + vuelta a Home).
- **Cronómetro**: puramente visual (`Timer.periodic` de 1s recalculando `DateTime.now().difference(sesion.iniciadoEn)`) — el cliente nunca decide que la sesión terminó, solo pinta lo que ya es cierto en el servidor.
- **Shape inconsistente de `POST /zona/iniciar`**: cuando la sesión es nueva (`accion: 'iniciada'`) la respuesta NO trae `iniciado_en` ni `id_contenedor_activo` (solo cuando `accion: 'retomada'` los trae) — por eso `ZonaSelectorScreen` siempre pide `GET .../zona/sesion/activa` después de iniciar, en vez de confiar en la respuesta de `iniciar`, para tener siempre el shape completo.
- **Peseable sin confirmación intermedia**: a diferencia de la versión web (que interponía un diálogo de "¿confirmás pickeo parcial?"), el bottom sheet de completar tarea (`TareaPickingTile`/`_CompletarTareaSheet`) solo muestra un aviso inline si la cantidad ingresada es menor a la pedida — sin paso de confirmación extra, coherente con que el resto de la app (Traslados) tampoco interpone diálogos intermedios en sus flujos de confirmación.
- Reusa `BarcodeScannerScreen` (escaneo de cajón) y el patrón de bottom sheet con drag-handle manual de Traslados (`_BuscarUbicacionSheet`) tal cual, sin duplicar código de escaneo/estilo.
- **Pendiente de verificar en dispositivo real / contra el backend real**: no se pudo levantar el backend+MySQL desde este entorno para probar el flujo end-to-end — `flutter analyze` corre limpio pero falta la verificación funcional real (ver punto de Verificación de la sesión de planificación). Probar en viewport de teléfono (390×844), no el tamaño de escritorio de Chrome.

### Bugs reales encontrados al probar contra el backend real (2026-07-07)

1. **`state.extra` de go_router no sobrevive a un re-parse de la ruta actual**: `AuthController` refresca `/auth/me` cada 15s en segundo plano y notifica al router (`_AuthRefreshListenable`), que re-evalúa `redirect` y reconstruye la ruta activa. Como `extra` viaja pegado a la navegación original (no está en la URL), se pierde en esa reconstrucción — si el operario se quedaba parado en `ZonaSelectorScreen` más de ~15s, `state.extra as SubpedidoPicking` recibía `null` y tiraba un `TypeError` real en producción. **Fix**: `ZonaSelectorScreen` ya no recibe el `SubpedidoPicking` por `extra` — recibe solo `idPedidoSubpedido` (path param, sobrevive a cualquier re-render/refresh) y busca los datos en `misTareasProvider`, igual que el resto de las pantallas del módulo. **Regla general para esta app**: no pasar objetos de dominio por `extra` de go_router si la pantalla puede quedar montada más de unos segundos — preferir IDs por path param + lookup en el provider.
2. **Cartel de cierre de zona poco claro**: cuando la zona se completaba (todas las tareas `COMPLETADO`, sesión cerrada por el backend con `motivo_fin=AUTO_COMPLETADO`), se mostraba el mismo diálogo genérico que para el cierre por inactividad ("se completó la zona o se cerró por inactividad") — confuso, no le decía al operario qué hacer. **Fix**: `PickingTrabajoScreen` ahora distingue los dos casos comparando las tareas de la última zona conocida (`_ultimaSesion`, capturada mientras la sesión seguía activa) contra `misTareasProvider` — si todas quedaron `COMPLETADO`, muestra `_PickingCompletoCartel` (pantalla completa, no diálogo: logo + check + "¡Picking completo!" + "Depositá los cajones en la ubicación de armado '{código}'"); si no, mantiene el diálogo de inactividad (ahora con mensaje más específico, sin el "o se completó la zona"). Requirió agregar `ubicacion_armado_codigo`/`ubicacion_armado_nombre` a la respuesta de `GET .../zona/sesion/activa` (`picking_operario_service.py::get_sesion_activa`) — se resuelven ahí porque una vez que la sesión pasa a `null` ya no hay de dónde sacar esos datos server-side, hay que capturarlos del lado del cliente mientras la sesión todavía estaba activa.

### Picking sin cajón (2026-07-07)

A pedido del usuario: hay productos que no entran en un cajón (bultos grandes), así que `CajonSelectorScreen` ahora tiene un botón "Picking sin cajón" que deja `id_contenedor_activo` en `NULL` en vez de forzar a elegir uno. Requirió backend (`SeleccionarCajonIn.id_contenedor` pasó a `Optional`, `completar_tarea` ya no exige cajón) y frontend:

- **`CajonSelectorScreen` devuelve 3 casos distintos, no 2**: `null` (canceló, sin cambios), `ContenedorPicking` (eligió uno) o `SinCajonSeleccionado` (eligió explícitamente pickear sin cajón). Antes solo se distinguía `null`/`ContenedorPicking`; el `push` pasó de `Navigator.push<ContenedorPicking>` a `Navigator.push<Object>` en ambos lugares donde se usa (`ZonaSelectorScreen`, `PickingTrabajoScreen._cambiarCajon`) para poder recibir cualquiera de los 3.
- **Bug de NULL en SQL evitado a propósito**: `stock_existencias`/`stock_movimientos` usan `id_contenedor` para encontrar la fila de la ubicación de armado (`WHERE ... AND id_contenedor = %s`), pero en SQL `columna = NULL` nunca es verdadero (ni siquiera si la columna es NULL) — hacía falta una rama `IS NULL` aparte para poder reencontrar/acumular siempre la misma fila en vez de crear una nueva cada vez que se pickea sin cajón. Ver `_find_existencia()` en `picking_operario_service.py` (y el equivalente en `picking_control_service.py::_resolver_existencia_armado`, que tenía el mismo problema para reconciliar rechazos de control).

### Ajuste automático de stock por diferencia de peso (2026-07-07)

A pedido del usuario: si un producto pesable se pesa por más de lo que `stock_existencias` tenía registrado (ej. sistema decía 8kg, el operario pesó 10kg), el picking ya no se rechaza — "la realidad tiene que primar siempre". El backend (`_ajustar_stock_por_diferencia_pesaje` en `picking_operario_service.py`) corrige la existencia (+diferencia) y deja un `stock_movimientos` tipo `AJUSTE_ENTRADA`, dentro de la misma transacción del picking.

**Decisión de arquitectura importante, confirmada con el usuario**: el sistema YA tiene un módulo formal de "Ajuste de Stock" (`ajuste_stock_service.py`, el mismo que consume `wherehouse/lib/features/ajuste_stock/`), pero es un flujo de conteo físico con revisión humana en 3 pasos (BORRADOR→CONFIRMADO→APLICADO, cada uno en su propia transacción) — no encaja con una corrección instantánea y automática en medio de otra operación. Se descartó reutilizarlo (hubiera requerido llamar 3 funciones en transacciones separadas, con riesgo de inconsistencia si algún paso fallaba a mitad de camino) a favor de una corrección directa + `stock_movimientos` en la misma transacción atómica del pick. **Consecuencia**: este ajuste automático NO aparece en la pantalla "Ajustes de Stock" de la app (esa pantalla solo lista los `ajustes_stock` formales) — si en algún momento se necesita que aparezca ahí también, hay que decidir si vale la pena adaptar ese módulo para soportar un modo "auto-aplicado sin revisión", o si al usuario le alcanza con el historial de `stock_movimientos`.

`CompletarTareaResultado.ajusteStockDiferencia` (nullable) trae la diferencia cuando pasó esto — `TareaPickingTile._abrirCompletar` muestra un SnackBar informativo ("⚖ Se ajustó el stock automáticamente...") después de cerrar el bottom sheet de completar, usando el context de la pantalla de fondo (no el del sheet, que ya se cerró).

### "Quitar productos" — devolución/despickeo (2026-07-07)

El backend de despickeo (`subpedido_despickeo_service.py`, dentro de `ventas/pedidos/subpedidos/PICKING/`, expuesto bajo `/picking-operario/despickeo/*` en `picking_operario_rout.py`) ya existía desde antes — se genera una tarea `PENDIENTE` en `picking_despickeo_tareas` cuando un cambio del lado de Ventas (cantidad, producto, regla de fulfillment) deja sin sentido algo que un operario YA había pickeado físicamente (está en un cajón en la ubicación de armado). Lo que faltaba era la pantalla en Flutter — quedó explícitamente fuera de alcance en la pasada de Picking Operario, ver arriba.

- **Pantallas**: nueva entrada "Quitar productos" en `PickingHomeScreen` (banner ámbar, solo visible si hay tareas pendientes — mismo patrón que el banner de "Zona en curso") → `QuitarProductosScreen` (`/picking-operario/quitar-productos`, lista de `TareaDespickeoTile`) → tocar una tarea abre un bottom sheet (`_ConfirmarDespickeoSheet`) con producto/cantidad/ubicación destino/pedido/cliente + observación opcional → "Confirmar — ya lo saqué del cajón" llama `POST /picking-operario/despickeo/{id}/confirmar`.
- **Solo trae las tareas del usuario logueado**: `GET .../despickeo/mis-tareas` filtra server-side por `id_usuario_operario` (el picker que estaba activo en esa zona cuando se generó la tarea) — no es una bandeja general para cualquier controlador. Si en el futuro hace falta que un supervisor/controlador vea también las tareas de otros, hay que ampliar el backend (hoy no lo permite).
- **Refresco**: mismo patrón que `misTareasProvider` — `enableSilentRefresh(interval: 20s)` mientras alguna pantalla del módulo esté abierta, así el banner de "Quitar productos" en el home se actualiza solo.
- **No se agregó gating de permiso `.operar` en el cliente** (solo se chequea `picking_operario.ver` para ver el módulo entero, igual que ya hacía `PickingHomeScreen`) — si al usuario le falta `picking_operario.operar` para confirmar, el error 403 del backend se muestra igual vía `describeError`, mismo criterio que el resto de las acciones de este módulo.

## 12e. MÓDULO CONTROL DE PICKING (implementado 2026-07-07, flujo core)

El backend de control (`new21-3/back-app/endpoints/modules/deposito/picking_control/`) ya existía (listar/iniciar/revisar/confirmar), pero el criterio de "¿cuándo se puede controlar algo?" era a nivel de todo el subpedido/ítem-producto (esperaba que `pedidos_subpedido_items.estado = 'PICKEADO'`). A pedido del usuario, pasó a ser **por cajón físico**: apenas se cierra un cajón (el operario cambia de cajón o termina/se le corta la sesión), ese cajón puntual ya se puede controlar sin esperar al resto del subpedido. `lib/features/picking_control/`:

- **Alcance de esta pasada**: listar subpedidos controlables → elegir cajón/SIN CAJÓN → revisar ítems (OK/cruz, rechazar producto o modificar cantidad) → confirmar el control. **Fuera de alcance**: cancelar sesión sin confirmar, desconfirmar un control ya confirmado, pantalla de informe/historial, "iniciar completo desde cero" (requiere permiso extra `control_picking.controlar_completo`).
- **Nuevo criterio "listo para control"** (`_LISTO_PARA_CONTROL_SQL` en `picking_control_service.py`): un `picking_items` es controlable si `(id_contenedor IS NOT NULL AND contenedores.estado = 'EN_TRANSITO')` (el cajón ya se cerró) `OR (id_contenedor IS NULL AND picking_sesion_zona.estado = 'FINALIZADA')` (pick sin cajón, pero la sesión que lo generó ya terminó). Requirió una migración nueva: `picking_items.id_sesion` (FK a `picking_sesion_zona`, `ON DELETE SET NULL`) — antes no se guardaba de qué sesión salió cada pick, así que no había forma de saber si un ítem sin cajón ya estaba "cerrado". La condición se repite (con distintos alias) en `listar_subpedidos_para_control`, `iniciar_control` (gate + pre-población de `picking_control_items`) e `_items_query` — duplicación deliberada, mismo criterio que ya usa `_resolver_ubicacion_armado` entre módulos; mantener sincronizada si se cambia.
- **Sesión de control = foto fija al iniciar**: si se cierra un cajón nuevo después de iniciar una sesión de control, no aparece solo en esa sesión — el controlador tiene que confirmar y volver a iniciar para verlo. Limitación aceptada, no es un bug.
- **Agrupación por cajón es 100% client-side**: el backend no cambió el shape de `_items_query` — cada `ItemControl` ya trae `id_contenedor`/`contenedor_identificador`; `DetalleControl.gruposPorCajon` (en `picking_control_models.dart`) arma los grupos agrupando por `idContenedor`, con `null` como el pseudo-cajón "SIN CAJÓN" (siempre al final, ordenado alfabéticamente el resto).
- **Pantallas**: `PickingControlHomeScreen` (`/picking-control`, lista subpedidos listos con refresh cada 20s vía `enableSilentRefresh`, igual que Picking Operario) → `PickingControlDetalleScreen` (`/picking-control/subpedido/:id`, botón "Iniciar control" si no hay sesión propia, si no lista los grupos-cajón con conteo pendientes/aprobados/rechazados + botón "Confirmar control" habilitado solo cuando no quedan pendientes) → `ControlCajonScreen` (pusheada con `Navigator`, no es ruta — mismo tratamiento que `CajonSelectorScreen` de Picking Operario; recibe la lista de ítems de un grupo y la reproduce en estado local para reflejar cada revisión al instante).
- **"Modificar cantidad" reusa el mecanismo de rechazo, no es una acción nueva en el backend**: confirmado con el usuario — tanto "Rechazar producto" como "Modificar cantidad" llaman al mismo `POST .../item/{id}/revisar` con `resultado: RECHAZADO`; la única diferencia es el motivo y la cantidad. "Rechazar producto" deja elegir motivo entre `CALIDAD/VENCIMIENTO/DANO/OTRO` (excluye `CANTIDAD` a propósito, ver `_motivosRechazoProducto` en `control_cajon_screen.dart`) y manda `cantidad_controlada = 0`; "Modificar cantidad" fija el motivo en `CANTIDAD` y deja editar la cantidad real. El backend ya reubicaba `CANTIDAD` como REACOMODO (sin dar de baja) y el resto como MERMA — sin cambios de esquema.
- **Botones ✓/✗ quedan siempre activos, incluso después de revisar un ítem**: a diferencia de Picking Operario (donde una tarea completada ya no es tocable), acá el controlador puede corregir su propia revisión tocando de nuevo el ítem — el backend acepta `UPDATE` sobre `picking_control_items` sin restricción mientras la sesión siga `EN_PROCESO`.
- **Escaneo de cajón** (2026-07-07, confirmado con el usuario): `PickingControlDetalleScreen` tiene un botón "Escanear" que reusa `BarcodeScannerScreen` (igual que `CajonSelectorScreen` de Picking Operario) — el código escaneado se matchea client-side contra `contenedor_identificador`/`contenedor_codigo_barras` de los grupos ya cargados (`_matchCajonEscaneado`), sin pegarle al backend. El pseudo-cajón "SIN CAJÓN" nunca matchea (no tiene código físico). Los cajones ya completamente revisados (`pendientes == 0`) se ven con fondo verde (`AppColors.okBg`) en la lista.
- **"Quitar" y "agregar" producto NO son acciones nuevas**: confirmado con el usuario — "quitar producto" es el mismo "Rechazar producto" ya implementado (rechazo con motivo, sigue generando re-pickeo por la cantidad rechazada al confirmar); "agregar producto" (anotar algo sobre un ítem) ya está cubierto por el campo de observación del rechazo. No requirió cambios de backend ni de UI más allá de lo ya construido.
- **Permisos `control_picking.controlar` / `control_picking.ver` / `control_picking.controlar_completo` no están seedeados** en `create_admin.py` ni en ningún otro lado del repo (mismo caso que pasó con `recepciones.manual`/`recepciones.controlar`) — hay que crearlos en `usuarios_permisos` y asignarlos antes de poder probar el módulo.
- **Pendiente para el usuario**: correr la migración SQL de `picking_items.id_sesion` (documentada en `picking_operario/BD.txt`), crear/asignar los permisos de arriba, y probar el flujo real: cerrar un cajón en Picking Operario → verificar que aparece en `/picking-control` aunque el resto del subpedido siga en `PICKING` → controlar sus ítems → confirmar. No se pudo levantar el backend+MySQL desde este entorno — `flutter analyze` corre limpio pero falta la verificación funcional real.

## 12f. MÓDULO PRODUCCIÓN (implementado 2026-07-13, flujo core)

Flujo pedido explícitamente por el usuario, simple y "gamificado" (insignias de nivel Nueva/Bronce/Plata/Oro según `veces_producida`, igual criterio que `tierInfo()` en la web): elegir receta → cartel con todo lo que necesita → cargar cuánto vas a usar → el sistema estima en vivo → empezar (crea+inicia la orden en un paso) → cronómetro con pausar/reanudar → finalizar (cargar consumo/resultado/merma reales) → cartel de cierre con estadísticas. `lib/features/produccion/`:

- **Reusa exactamente los mismos endpoints que el Taller de la web** (`/produccion/{recetas,ordenes}/*`, ver `../CONTEXTO.md` §3.9) — no hay backend propio para mobile, igual que el resto de los módulos de esta app.
- **"Cartel con todo lo que necesita" sin tocar el backend**: `POST /produccion/ordenes/preview` devuelve cantidades escaladas pero **sin nombre/unidad de producto** (`calcular_estimado()` en el backend solo emite `id_producto`/`cantidad_planificada`). En vez de extender el backend, `NuevaOrdenScreen` pide primero `GET /produccion/recetas/{id}` (trae `consumo[]`/`resultado[]`/`mermas[]` con nombre y unidad) y combina esas listas **por posición** con las de `preview` — es seguro porque ambos endpoints arman sus listas con el mismo `ORDER BY` (`es_referencia DESC`/`es_principal DESC`, luego id ASC) a partir de la misma tabla, así que el índice `i` siempre corresponde al mismo producto en ambas respuestas.
- **Decisión de producto — ubicación destino automática**: a diferencia de la web (que deja elegir ubicación dentro de la zona `PRODUCCION` en un paso del wizard), acá `POST .../finalizar` **nunca manda `id_ubicacion_destino`** — el backend resuelve solo la recomendada de la zona (ver `../CONTEXTO.md` §4.15 y `[[project_produccion_modulo]]`). Confirmado explícitamente con el usuario para mantener el flujo mobile en los 8 pasos pedidos, sin pantalla extra. Si más adelante hace falta elegir ubicación desde el celular, agregar un paso análogo al de la web (`GET .../ubicaciones-destino`).
- **Cronómetro con pausa sin recalcular client-side**: el backend ya devuelve `tiempo_transcurrido_segundos` resuelto en `GET /produccion/ordenes/{id}` (suma los intervalos, o `tiempo_real_segundos` si ya finalizó). `OrdenEnCursoScreen` solo seguye tickeando en pantalla mientras `estado == 'EN_PROCESO'` (base del último fetch + segundos transcurridos localmente); si está `PAUSADA` el número se congela. Cada refresco silencioso (`enableSilentRefresh`, 15s) reconcilia el valor con el servidor — útil si se pausa/reanuda desde la web mientras la app sigue abierta.
- **Sin paso de anular en los 8 pedidos, pero se agregó igual**: `OrdenEnCursoScreen` tiene un botón secundario discreto "Anular producción" (con diálogo de confirmación, mismo patrón que "Terminar picking" en Picking Operario) — necesario como salida de emergencia real (receta equivocada, cantidad mal tipeada) aunque el usuario no lo haya pedido en la lista de pasos; no interfiere con el flujo principal.
- **"Retomar" en el Home del módulo**: `GET /produccion/ordenes?estado=EN_PROCESO` + `?estado=PAUSADA` (dos llamadas, el backend no acepta lista de estados) filtradas por el almacén del usuario — para el caso de cerrar la app a mitad de una producción y volver después.
- **Pantalla de cierre reusa el mismo estado terminal, no hay una pantalla de "resumen" separada**: al finalizar, `FinalizarOrdenScreen` navega con `context.go('/produccion/taller/:id')` (mismo id) — como el estado de la orden ya es `FINALIZADA`, `OrdenEnCursoScreen` renderiza directamente el cartel de cierre (`_EstadoTerminalCartel`, con cantidad producida/tiempo real/merma) en vez de los controles de cronómetro. Evita duplicar una pantalla de "resumen" aparte.
- **Pendiente para el usuario**: no se pudo levantar el backend+MySQL desde este entorno — `flutter analyze` corre limpio pero falta la verificación funcional real contra datos reales (elegir receta → producir → finalizar → ver el cartel de cierre).

### Etiquetas + impresora de red (2026-07-13)

Pedido explícito del usuario tras terminar el flujo core: imprimir la etiqueta física del lote al finalizar, con 4 datos (nombre+marca, kg estándar, código de barra, lote/vencimiento), conectando directo con una impresora Honeywell — confirmó por WiFi/red (tiene IP propia), y que "configurar los datos" significa tanto guardar la conexión como elegir qué campos se imprimen.

- **Backend enriquecido, no solo el frontend**: `GET /produccion/ordenes/{id}/etiquetas` (`orden_service.py::ordenes_etiquetas`) antes solo devolvía `lote_interno`/`producto`/`cantidad`/`unidad`/`fecha_vencimiento`. Se agregó `marca` (`productos.id_marca → marcas.nombre`), `kg_estandar` (`productos_almacenaje.peso_unitario`) ⚠️ **sacado de nuevo el 2026-07-14**, ver más abajo, y `codigo_barra`+`tipo_codigo` (el código de barra **principal** de `productos_codigos_barra`, resuelto con subquery `LIMIT 1` porque no hay UNIQUE que garantice un solo `principal=1` por producto). Detalle completo en `produccion/ordenes/BD.txt` del backend.
- **Impresión por ZPL sobre socket TCP crudo, no un plugin de impresora**: no existe un plugin Flutter oficial de Honeywell, y el usuario confirmó que la impresora está en la red (IP propia) — así que `ImpresoraService` (`lib/features/produccion/data/impresora_service.dart`) abre un `Socket` de `dart:io` al puerto 9100 (RAW/"JetDirect", el estándar de facto en impresoras de etiquetas) y manda el comando en **ZPL** (Zebra Programming Language) — es el lenguaje de impresión más compatible entre marcas; la mayoría de las Honeywell industriales (PC42/PM43/PD41, etc.) lo soportan como modo de emulación. **No se pudo probar contra la impresora Honeywell real** — si esa unidad puntual corre nativo en otro lenguaje (Fingerprint/DPL) y no tiene la emulación ZPL activada, hay que revisar el menú de configuración de la impresora (casi todas permiten cambiar de lenguaje) antes de poder imprimir.
- **Código de barras según `tipo_codigo`**: `construirZplEtiqueta()` mapea el tipo (`EAN13`→`^BE`, `EAN8`→`^B8`, `UPC`→`^BU`, `QR`→`^BQ`, cualquier otro/`CODE128`→`^BC` como fallback universal) — el usuario eligió que el código de barras imprimido sea el propio del producto (`productos_codigos_barra`), no el `lote_interno` que ya usa la web.
- **Configuración persistida por dispositivo**: `ImpresoraConfigStore` usa `shared_preferences` (paquete nuevo agregado al pubspec — no `flutter_secure_storage`, esa queda reservada al JWT) para guardar IP/puerto, tamaño físico del rollo (`anchoMm`/`altoMm`) y la lista ordenada de campos activos. `ConfigurarImpresoraScreen` (`/produccion/impresora`) tiene además un botón "Probar conexión" (abre y cierra el socket sin imprimir nada, para no gastar etiquetas en cada prueba).
- **Pantalla de etiquetas** (`/produccion/taller/:id/etiquetas`, accesible desde el cartel de cierre de `OrdenEnCursoScreen` con el botón "Ver e imprimir etiquetas"): lista las etiquetas de la orden ya finalizada, cada una con botón "Imprimir" propio y un banner de aviso si todavía no se configuró ninguna impresora.
- **Bug preexistente encontrado de paso**: `android/app/src/main/AndroidManifest.xml` no declaraba `android.permission.INTERNET` — bloquearía **toda** la red de la app (no solo la impresora) en un build de Android real. Agregado.

### Editor de tamaño/orden de la etiqueta + vista previa (2026-07-13)

El usuario preguntó "cómo hago para editar la etiqueta, tamaño, dónde van las cosas, cómo luce" — eligió explícitamente "tamaño + orden de los campos" (no un editor visual de posición libre, eso quedó descartado por mucho trabajo) y "sí" a una vista previa en pantalla antes de imprimir.

⚠️ **La parte de "orden de los campos" de esta sección quedó SUPERADA al día siguiente** (ver "Plantilla de etiqueta por receta" más abajo) — el usuario pidió que la elección de campos pase a configurarse por receta en la web, no por dispositivo en Flutter. ⚠️ **El tamaño físico también quedó SUPERADO el 2026-07-15** (ver "Catálogo reusable de etiquetas") — `construirZplEtiqueta()` ya no usa `ImpresoraConfig.anchoMm/altoMm` para el `^PW`/`^LL` de la etiqueta, usa las dimensiones de la plantilla asignada (`EtiquetaTemplate.anchoMm/altoMm`). Lo que sigue vigente de acá: el mecanismo de vista previa con `barcode_widget` y el campo `ImpresoraConfig.anchoMm/altoMm` como config de referencia del dispositivo (ya no afecta el contenido impreso).

- ~~`ImpresoraConfig` se rediseñó: los 4 booleanos... se reemplazaron por una sola `List<String> campos`~~ — reemplazado por la plantilla de la receta, ver abajo.
- ~~Tamaño físico configurable vía `ImpresoraConfig.anchoMm`/`altoMm`~~ — sigue existiendo el campo (con presets en `TamanoEtiqueta.opciones`), pero ya no lo usa `construirZplEtiqueta()`; el tamaño real de impresión sale de la plantilla (`EtiquetaTemplate.anchoMm/altoMm`, ver "Catálogo reusable de etiquetas"). `_dotsPorMm` (203dpi asumido) sigue siendo la constante a ajustar si la Honeywell real es de 300dpi.
- ~~Reordenar campos en `ConfigurarImpresoraScreen`~~ — esa pantalla ya no tiene la lista reordenable, ver abajo.
- **Vista previa con `barcode_widget` (paquete nuevo)** (sigue vigente, adaptada a la plantilla de receta): `EtiquetaPreview` (`lib/features/produccion/presentation/widgets/etiqueta_preview.dart`) dibuja una aproximación de la etiqueta (proporción ancho/alto real, mismo orden de campos que el ZPL) usando `BarcodeWidget` para renderizar el código de barras real según su `tipo_codigo` — no es un render pixel-perfect de lo que hace la impresora, es una guía de layout para no gastar etiquetas físicas ajustando a ciegas.
- **Pendiente para el usuario**: probar contra la impresora Honeywell real (verificar que corre en modo ZPL, y ajustar `^PW` en `construirZplEtiqueta()` si el ancho del rollo de etiquetas real es distinto a 60mm/480 dots).

### Plantilla de etiqueta por receta (2026-07-14) — ⚠️ SUPERADA el 2026-07-15, ver sección siguiente

El usuario pidió que la etiqueta "se configure al crear la receta.. que desde ahí se pueda modificar", con campos nuevos que no existían: Producto (ahora también toggleable, antes era fijo), Marca, Lote, Código de barra, **Código QR** (nuevo, símbolo separado), Cantidad (con 3 modos), Fecha de embalaje (nueva), Fecha de vencimiento (separada de Lote, antes iban juntos en una sola línea), Observación (nueva). Antes de programar se confirmaron 3 ambigüedades reales con impacto de diseño:

- **Código de barra vs Código QR**: son el MISMO dato (el código de barras principal del producto) en dos símbolos distintos — no hay un dato de QR separado. El usuario puede activar uno, el otro, o ambos.
- **Cantidad modo "solicitar que se pese"**: NO es un texto fijo tipo "A PESAR" — es un flujo interactivo real: si imprimís 10 etiquetas de una receta con este modo, la app pregunta el peso de cada paquete, UNO POR UNO, justo antes de imprimir esa copia puntual. Es 100% client-side (el backend no persiste pesos individuales de copias).
- **Observación**: texto FIJO configurado una vez en la receta (ej. "Mantener refrigerado"), no algo que se carga en cada producción.

**Arquitectura resultante** (reemplaza lo que describían las dos secciones de arriba sobre "campos" del dispositivo):

- **Backend nuevo**: tabla `produccion_recetas_etiqueta_campos` (catálogo fijo de 9 `campo`, orden = orden de inserción, `cantidad_modo`/`cantidad_texto_fijo` solo si `campo=CANTIDAD`, `observacion_texto` solo si `campo=OBSERVACION`) + `POST /produccion/recetas/{id}/etiqueta/replace` (mismo patrón replace-all que consumo/resultado/mermas) + `GET /produccion/recetas/{id}` ahora incluye `etiqueta_campos[]`. Al crear una receta sin mandar `etiqueta_campos`, se siembra un default razonable. Detalle completo en `../new21-3/back-app/.../produccion/recetas/BD.txt` y `../CONTEXTO.md` §3.9/§4.15.
- **Web**: nueva sección "Etiqueta de producción" en `RecetaDetallePage.jsx` — lista con botones subir/bajar (no hay librería de drag-and-drop en el repo, se optó por flechas en vez de agregar una dependencia nueva) + checkbox de activo por campo, con el select de modo de Cantidad y el input de Observación inline cuando corresponde. Auto-guarda en cada cambio, sin botón "Guardar" (mismo patrón que `ProductSlots`/`MermasTray` de esa misma página) — y sin estado local espejo de la lista (se deriva todo de las props en cada render), para que un persist fallido no deje la UI "adelantada" respecto del servidor.
- **Flutter — `ConfigurarImpresoraScreen` se simplificó**: ya NO tiene la lista reordenable de campos (eso vivía mal ahí, era una config de dispositivo para algo que ahora es por receta) — solo queda IP/puerto + tamaño del rollo. `ImpresoraConfig` perdió el campo `campos`.
- **Flutter — `construirZplEtiqueta()` y `EtiquetaPreview` ahora reciben la plantilla de la receta** (`List<RecetaEtiquetaCampo>`, obtenida vía `recetaDetalleProvider(idReceta)` — `idReceta` sale de la primera etiqueta de la orden, `EtiquetaProduccion.idReceta` es un campo nuevo) en vez de leer campos fijos de `ImpresoraConfig`. Cada uno de los 9 tipos de campo tiene su propio bloque ZPL/widget de preview.
- **Flujo de pesado en `EtiquetasScreen`**: si la plantilla tiene `CANTIDAD` en modo `PESAR`, el botón "Imprimir" dispara `_imprimirPesando()` — pide cuántas copias (`_pedirCantidadCopias`), y por cada una pide el peso con un diálogo bloqueante (`_pedirPeso`, `barrierDismissible: false`) e imprime esa copia individual antes de pasar a la siguiente; cancelar un diálogo de peso corta el resto del lote. El resto de los modos (`REAL`/`FIJO`) imprimen de un tiro como antes.
- **Reemplazada por el catálogo reusable de la sección siguiente** — no hace falta correr la migración vieja de `produccion_recetas_etiqueta_campos`, `produccion_tablas.sql` ya la superó.

### Catálogo reusable de etiquetas (2026-07-15)

El usuario pidió mejorar el modal de etiqueta y agregar dimensiones configurables, centrado por línea y reordenar por drag-and-drop — y, en vez de seguir agregando eso a la plantilla embebida-por-receta del día anterior, pidió directamente "un módulo de creación de etiquetas.. y lo único que hay que hacer es seleccionar una etiqueta [en la receta] y poner qué campos querés que se vean, y el sistema ajusta los tamaños". Se confirmaron 3 decisiones antes de programar: (1) catálogo reusable aparte de las recetas (no embebido), reutilizable entre varias; (2) "centrar" = alineación de texto por línea (`IZQUIERDA`/`CENTRO`/`DERECHA`), no centrar todo el bloque en la etiqueta; (3) reordenar = drag-and-drop real, no las flechas subir/bajar de la versión anterior.

- **Backend**: la tabla `produccion_recetas_etiqueta_campos` (embebida, un día de vida) se reemplaza por `produccion_etiquetas` (cabecera: `nombre` único, `ancho_mm`, `alto_mm`) + `produccion_etiquetas_campos` (mismo catálogo de 9 tipos + `alineacion` nueva) + `produccion_recetas.id_etiqueta` (FK nullable, `ON DELETE SET NULL`). Nuevo router `/produccion/etiquetas` (CRUD completo, reusa los permisos `produccion.ver`/`editar`/`desactivar`, no hay permisos nuevos). Detalle en `../new21-3/back-app/endpoints/modules/produccion/etiquetas/BD.txt` y `../CONTEXTO.md` §4.16.
- **Web**: nuevo módulo `/produccion/etiquetas` (`EtiquetasPage` lista, `EtiquetaDetallePage` detalle con ancho/alto + editor de campos drag-and-drop vía `@dnd-kit/core`+`@dnd-kit/sortable`, primera librería de DnD del repo). `RecetaDetallePage.jsx` ya no tiene el editor embebido — solo un *picker* (`EtiquetaPicker`) para elegir/cambiar/quitar la plantilla asignada, con link directo a editarla en el módulo nuevo.
- **Flutter — modelos renombrados**: `RecetaEtiquetaCampo` → `EtiquetaCampoTemplate` (+ campo `alineacion`), `CampoEtiquetaReceta` → `CampoEtiqueta` (ya no es "de la receta", es del catálogo). Nuevo `EtiquetaTemplate` (dimensiones + campos, `GET /produccion/etiquetas/{id}`) y `EtiquetaResumen` (lo que trae embebido `RecetaDetalle.etiqueta`: solo id/nombre/dimensiones, para no tener que traer los campos completos si no hace falta imprimir). `EtiquetasScreen` ahora resuelve la plantilla en cadena: `etiquetasProvider(idOrden)` → `id_receta` → `recetaDetalleProvider` → `receta.etiqueta.idEtiqueta` → `etiquetaTemplateProvider(idEtiqueta)`; si la receta no tiene `id_etiqueta`, muestra un aviso en vez de intentar imprimir.
- **Flutter — auto-ajuste real, no solo visual**: `construirZplEtiqueta()` (`impresora_service.dart`) ya NO usa `ImpresoraConfig.anchoMm/altoMm` para el tamaño de la etiqueta — usa `EtiquetaTemplate.anchoMm/altoMm` (las dimensiones de la plantilla asignada, no del rollo cargado en el dispositivo) y reparte el espacio disponible entre los campos activos según un peso por tipo (código de barra/QR pesan mucho más que una línea de texto: `_pesoCampo`), calculando tamaño de fuente y alto de código de barra proporcional a la porción que le toca a cada uno. La alineación se aplica con `^FB` (field block) para texto, y con un offset `^FO` **aproximado** (no hay forma exacta de conocer el largo renderizado de un código de barra sin rasterizar) para códigos de barra/QR. `ImpresoraConfig.anchoMm/altoMm` sigue existiendo pero ahora es solo un valor de referencia al configurar el dispositivo — no se usa para el contenido de la impresión.
- **Flutter — preview actualizado**: `EtiquetaPreview` ahora recibe `EtiquetaTemplate` en vez de `ImpresoraConfig` + lista de campos, usa `anchoMm/altoMm` de la plantilla para la proporción del recuadro, y respeta la alineación por línea (`Alignment`/`TextAlign` según el campo).

### Rotación 90° fija + campo RSPA (2026-07-15, mismo día)

El usuario compartió un ZPL real que ya usa en producción — distinto de lo recién generado en dos cosas concretas: (1) texto/códigos de barra ROTADOS 90° (`^A0R`/`^BCR` en vez de `^A0N`/`^BCN`), con los campos apilados de DERECHA A IZQUIERDA sobre el ancho físico de la etiqueta; (2) un campo nuevo, **RSPA** (registro sanitario/habilitación del establecimiento — SENACSA en Paraguay, confirmado por el usuario). Se confirmaron ambas cosas antes de tocar código: RSPA se agrega al catálogo (mecánica igual a OBSERVACION, columna propia `rspa_texto`), y la rotación es **fija para TODAS las etiquetas de producción**, no una opción por plantilla.

- **`construirZplEtiqueta()` reescrito con los ejes invertidos**: con texto rotado (`^A0R`), el `^FB` (ancho de bloque de texto) corre en el eje Y, no en X — así que ahora `ancho_mm`/`^PW` es el eje donde se APILAN los campos (cada uno ocupa una porción proporcional a su peso, arrancando cerca del borde derecho y restando hacia la izquierda), y `alto_mm`/`^LL` es el eje donde se EXTIENDE cada línea de texto (`^FB`) o cada código de barra (su "largo" renderizado). Es al revés de la primera versión del generador (donde `alto_mm` se repartía entre campos y `ancho_mm` era el ancho de cada línea). Los comandos de barcode/QR pasan a su variante rotada (`^BER`/`^B8R`/`^BUR`/`^BCR`/`^BQR`); la justificación `^FB` (L/C/R) no cambia de sintaxis con la rotación.
- **RSPA** en `CampoEtiqueta`/`EtiquetaCampoTemplate.rspaTexto`, peso 1.0 en `_pesoCampo`, renderizado en `_camposRenderables` igual que OBSERVACION (si el texto está vacío, no imprime esa línea).
- **El preview (web y Flutter) sigue SIN rotar a propósito** — es una guía de campos/orden/alineación, no una simulación pixel-perfect de la orientación física real; solo la impresión ZPL sale rotada.
- **No verificado contra la Honeywell real** — la heurística de reparto de peso y estimación de largo de barcode/QR es una aproximación razonable, no calibrada con esa impresora específica ni con las posiciones manuales exactas del ZPL de referencia que compartió el usuario (ese estaba ajustado a mano, no auto-generado).

- **Pendiente para el usuario**: correr la migración SQL de `produccion_etiquetas`/`produccion_etiquetas_campos` + `ALTER produccion_recetas ADD id_etiqueta` (sección 7 de `produccion_tablas.sql`, que también dropea la tabla vieja `produccion_recetas_etiqueta_campos` si llegó a crearse), crear al menos una plantilla real desde `/produccion/etiquetas` y asignarla a una receta, y probar impresión + drag-and-drop + auto-ajuste + rotación + campo RSPA contra la Honeywell real (el cálculo de tamaños es una heurística no verificada contra hardware real).

## 12. ROADMAP DE FASES

| Fase | Contenido |
|---|---|
| 0 | ✅ Flutter SDK instalado, `flutter create`, arquitectura base (Riverpod + Dio + Drift + go_router), login funcional contra `/auth/login`+`/auth/me` |
| 1 | ✅ Control de stock (solo lectura) |
| 2 | ✅ Picking operario (flujo core + Quitar productos/despickeo — ver §12d; faltan acciones de supervisor, devolver ítem e informe) |
| 3 | Asignación de pickers pendiente; ✅ Control de calidad (flujo core — ver §12e; faltan cancelar/desconfirmar/informe) |
| 4 | ✅ Recepción (solo manual) + Traslados |
| 5 | Expedición (post definición backend) + Generación de pedidos |
| 6 | ✅ Producción (flujo core — ver §12f); resto de módulos del depósito (mermas, ajustes de stock, informes, etc.) |
