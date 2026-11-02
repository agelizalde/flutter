package com.riversupply.wherehouse

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterShellArgs
import io.flutter.plugin.common.MethodChannel

/**
 * Elige el motor gráfico al arrancar, para que UN SOLO APK sirva en todos los
 * dispositivos: Impeller (el nuevo de Flutter) da pantalla negra / se cierra en
 * GPUs de Android viejos, y antes había que compilar un APK aparte con
 * `EnableImpeller=false` para esas terminales.
 *
 * `--enable-impeller=false` por argumento está permitido en release y le gana al
 * `EnableImpeller` del manifest (ver FlutterLoader/FlutterEngineFlags del engine).
 *
 * Modo guardado en el teléfono (sobrevive a las actualizaciones), se cambia desde
 * Configuración -> Modo gráfico (canal [CANAL]):
 * - "auto" (default): compatibilidad si Android < 10 o sin Vulkan 1.1, que es
 *   donde Impeller cae a OpenGL y falla.
 * - "compat": siempre el motor anterior.
 * - "moderno": siempre Impeller.
 */
class MainActivity : FlutterActivity() {

    override fun getFlutterShellArgs(): FlutterShellArgs {
        val args = super.getFlutterShellArgs()
        if (usaCompatibilidad(this)) {
            args.add("--enable-impeller=false")
        }
        return args
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CANAL).setMethodCallHandler { call, result ->
            when (call.method) {
                "estado" -> result.success(
                    mapOf(
                        "modo" to leerModo(this),
                        "compatibilidadAuto" to requiereCompatibilidad(this),
                        "compatibilidadActiva" to usaCompatibilidad(this),
                    )
                )
                "guardar" -> {
                    val modo = call.argument<String>("modo")
                    if (modo !in MODOS) {
                        result.error("MODO_INVALIDO", "Modo desconocido: $modo", null)
                    } else {
                        prefs(this).edit().putString(CLAVE_MODO, modo).commit()
                        result.success(null)
                    }
                }
                "reiniciar" -> {
                    result.success(null)
                    reiniciarApp()
                }
                else -> result.notImplemented()
            }
        }
    }

    /**
     * El motor se elige una sola vez por proceso (FlutterLoader), así que para
     * aplicar un modo nuevo hay que matar el proceso, no alcanza con cerrar la
     * pantalla.
     */
    private fun reiniciarApp() {
        val intent = packageManager.getLaunchIntentForPackage(packageName) ?: return
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
        startActivity(intent)
        Runtime.getRuntime().exit(0)
    }

    companion object {
        private const val CANAL = "wherehouse/modo_grafico"
        private const val PREFS = "wherehouse_modo_grafico"
        private const val CLAVE_MODO = "modo"
        private val MODOS = setOf("auto", "compat", "moderno")

        // VK_API_VERSION_1_1, como lo espera FEATURE_VULKAN_HARDWARE_VERSION.
        private const val VULKAN_1_1 = 0x00401000

        private fun prefs(context: Context) =
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

        private fun leerModo(context: Context): String =
            prefs(context).getString(CLAVE_MODO, "auto") ?: "auto"

        private fun requiereCompatibilidad(context: Context): Boolean {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return true
            return !context.packageManager.hasSystemFeature(
                PackageManager.FEATURE_VULKAN_HARDWARE_VERSION,
                VULKAN_1_1,
            )
        }

        private fun usaCompatibilidad(context: Context): Boolean = when (leerModo(context)) {
            "compat" -> true
            "moderno" -> false
            else -> requiereCompatibilidad(context)
        }
    }
}
