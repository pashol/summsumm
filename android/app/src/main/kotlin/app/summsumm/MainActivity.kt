package app.summsumm

import android.content.ContentResolver
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import androidx.core.content.pm.ShortcutInfoCompat
import androidx.core.content.pm.ShortcutManagerCompat
import androidx.core.graphics.drawable.IconCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        const val CHANNEL = "app.summsumm/intent"
        const val ACTION_SETTINGS = "app.summsumm.OPEN_SETTINGS"
        const val PREFS_NAME = "summsumm_prefs"
        const val KEY_SHORTCUT_CREATED = "shortcut_created"
        const val MAX_PDF_SIZE_BYTES = 5 * 1024 * 1024 // 5MB
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        .setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialIntent" -> result.success(getInitialIntent())
                "offerSettingsShortcut" -> {
                    offerSettingsShortcutIfNeeded()
                    result.success(null)
                }
                "readContentUri" -> {
                    val uriString = call.argument<String>("uri")
                    if (uriString != null) {
                        try {
                            val uri = Uri.parse(uriString)
                            val bytes = readContentUriBytes(uri)
                            result.success(bytes?.toList())
                        } catch (e: Exception) {
                            result.error("READ_ERROR", e.message, null)
                        }
                    } else {
                        result.error("INVALID_URI", "URI is null", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun readContentUriBytes(uri: Uri): ByteArray? {
        return try {
            contentResolver.openInputStream(uri)?.use { it.readBytes() }
        } catch (e: Exception) {
            null
        }
    }

    private fun getInitialIntent(): Map<String, Any?>? {
        val intent = intent ?: return null
        val action = intent.action ?: return null
        val documents = mutableListOf<Map<String, Any?>>()

        // Handle ACTION_SEND (single document)
        if (Intent.ACTION_SEND == action) {
            when (intent.type) {
                "text/plain" -> {
                    val text = intent.getStringExtra(Intent.EXTRA_TEXT)
                    text?.let { documents.add(mapOf("text" to it)) }
                }
                "application/pdf" -> {
                    val uri = getParcelableExtraCompat(intent, Intent.EXTRA_STREAM)
                    uri?.let { addPdfDocument(it, documents) }
                }
            }
        }
        // Handle ACTION_SEND_MULTIPLE (multiple documents)
        else if (Intent.ACTION_SEND_MULTIPLE == action) {
            when (intent.type) {
                "text/plain" -> {
                    val texts = intent.getStringArrayListExtra(Intent.EXTRA_TEXT)
                    texts?.forEach { text -> documents.add(mapOf("text" to text)) }
                }
                "application/pdf" -> {
                    val uris = getParcelableArrayListExtraCompat<Uri>(intent, Intent.EXTRA_STREAM)
                    uris?.forEach { uri -> addPdfDocument(uri, documents) }
                }
            }
        }
        // Handle ACTION_PROCESS_TEXT (text selection)
        else if (Intent.ACTION_PROCESS_TEXT == action) {
            val text = intent.getStringExtra(Intent.EXTRA_PROCESS_TEXT)
            text?.let { documents.add(mapOf("text" to it)) }
        }

        return if (documents.isNotEmpty()) {
            mapOf("action" to action, "documents" to documents)
        } else {
            null
        }
    }

    private fun addPdfDocument(uri: Uri, documents: MutableList<Map<String, Any?>>) {
        val fileName = getFileName(uri)
        val fileSize = getFileSize(uri)

        if (fileSize != null && fileSize > MAX_PDF_SIZE_BYTES) {
            // Add with error flag instead of rejecting
            documents.add(mapOf(
                "text" to "",
                "name" to fileName,
                "error" to "file_too_large"
            ))
            return
        }

        // Pass the URI as string - Flutter will handle reading the file
        documents.add(mapOf(
            "uri" to uri.toString(),
            "name" to fileName,
            "size" to fileSize
        ))
    }

    private fun getFileName(uri: Uri): String? {
        var name: String? = null
        contentResolver.query(uri, null, null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) {
                val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (nameIndex >= 0) name = cursor.getString(nameIndex)
            }
        }
        return name
    }

    private fun getFileSize(uri: Uri): Long? {
        var size: Long? = null
        contentResolver.query(uri, null, null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) {
                val sizeIndex = cursor.getColumnIndex(OpenableColumns.SIZE)
                if (sizeIndex >= 0) size = cursor.getLong(sizeIndex)
            }
        }
        return size
    }

    private fun extractText(): String? = when (intent.action) {
        Intent.ACTION_PROCESS_TEXT ->
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                intent.getCharSequenceExtra(Intent.EXTRA_PROCESS_TEXT)?.toString()
            } else null
        Intent.ACTION_SEND ->
            intent.getStringExtra(Intent.EXTRA_TEXT)
        else -> null
    }

    private fun offerSettingsShortcutIfNeeded() {
        val prefs: SharedPreferences = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
        if (prefs.getBoolean(KEY_SHORTCUT_CREATED, false)) return
        if (!ShortcutManagerCompat.isRequestPinShortcutSupported(this)) return

        val shortcutIntent = Intent(ACTION_SETTINGS).apply {
            setClass(this@MainActivity, MainActivity::class.java)
        }
        val shortcutInfo = ShortcutInfoCompat.Builder(this, "open_settings")
            .setShortLabel("AI Summarizer Settings")
            .setLongLabel("AI Text Summarizer — Settings")
            .setIntent(shortcutIntent)
            .setIcon(IconCompat.createWithResource(this, android.R.drawable.ic_menu_preferences))
            .build()

        ShortcutManagerCompat.requestPinShortcut(this, shortcutInfo, null)
        prefs.edit().putBoolean(KEY_SHORTCUT_CREATED, true).apply()
    }

    @Suppress("DEPRECATION")
    private fun <T> getParcelableExtraCompat(intent: Intent, extra: String): T? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(extra, T::class.java)
        } else {
            intent.getParcelableExtra(extra)
        }
    }

    @Suppress("DEPRECATION")
    private fun <T> getParcelableArrayListExtraCompat(intent: Intent, extra: String): List<T>? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableArrayListExtra(extra, T::class.java)
        } else {
            intent.getParcelableArrayListExtra(extra)
        }
    }
}
