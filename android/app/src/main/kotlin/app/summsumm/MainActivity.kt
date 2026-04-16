package app.summsumm

import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
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
                else -> result.notImplemented()
            }
        }
    }

    private fun getInitialIntent(): Map<String, Any?>? {
        val intent = intent ?: return null
        val action = intent.action ?: return null
        val documents = mutableListOf<Map<String, String?>>()

        // Handle ACTION_SEND (single document)
        if (Intent.ACTION_SEND == action && "text/plain" == intent.type) {
            val text = intent.getStringExtra(Intent.EXTRA_TEXT)
            text?.let { documents.add(mapOf("text" to it)) }
        }
        // Handle ACTION_SEND_MULTIPLE (multiple documents)
        else if (Intent.ACTION_SEND_MULTIPLE == action && "text/plain" == intent.type) {
            val texts = intent.getStringArrayListExtra(Intent.EXTRA_TEXT)
            texts?.forEach { text -> documents.add(mapOf("text" to text)) }
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
}
