package com.rizcut.app

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Receives videos/photos shared to RizCut ("Share → RizCut") and hands
 * Flutter local copies of them over the "rizcut/share" channel.
 */
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private val pending = mutableListOf<String>()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "rizcut/share").also {
            it.setMethodCallHandler { call, result ->
                when (call.method) {
                    "takeShared" -> {
                        val out = synchronized(pending) { pending.toList().also { pending.clear() } }
                        result.success(out)
                    }
                    else -> result.notImplemented()
                }
            }
        }
        receive(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        receive(intent)
    }

    private fun sharedUris(intent: Intent?): List<Uri> {
        if (intent == null) return emptyList()
        return when (intent.action) {
            Intent.ACTION_SEND -> listOfNotNull(
                if (Build.VERSION.SDK_INT >= 33) {
                    intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableExtra(Intent.EXTRA_STREAM)
                }
            )
            Intent.ACTION_SEND_MULTIPLE ->
                (if (Build.VERSION.SDK_INT >= 33) {
                    intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM)
                })?.toList() ?: emptyList()
            Intent.ACTION_VIEW -> listOfNotNull(intent.data)
            else -> emptyList()
        }
    }

    /** Copies shared files off the main thread, then tells Flutter. */
    private fun receive(intent: Intent?) {
        val uris = sharedUris(intent)
        if (uris.isEmpty()) return
        // Don't handle the same share again after a configuration change.
        intent?.action = null
        Thread {
            val dir = File(cacheDir, "shared").apply { mkdirs() }
            val copied = uris.mapNotNull { uri -> copy(uri, dir) }
            if (copied.isEmpty()) return@Thread
            synchronized(pending) { pending.addAll(copied) }
            runOnUiThread { channel?.invokeMethod("shared", null) }
        }.start()
    }

    private fun copy(uri: Uri, dir: File): String? = try {
        var name = "shared_${System.currentTimeMillis()}"
        contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { c ->
            if (c.moveToFirst() && !c.isNull(0)) name = c.getString(0)
        }
        if (!name.contains('.')) {
            val type = contentResolver.getType(uri) ?: ""
            name += when {
                type.startsWith("image/") -> ".jpg"
                else -> ".mp4"
            }
        }
        val safe = name.replace(Regex("[^A-Za-z0-9._-]"), "_")
        val out = File(dir, "${System.currentTimeMillis()}_$safe")
        contentResolver.openInputStream(uri)?.use { input ->
            out.outputStream().use { input.copyTo(it) }
        }
        if (out.length() > 0) out.absolutePath else null
    } catch (e: Exception) {
        null
    }
}
