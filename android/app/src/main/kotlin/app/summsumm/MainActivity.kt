package app.summsumm

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat

import androidx.core.content.pm.ShortcutInfoCompat
import androidx.core.content.pm.ShortcutManagerCompat

import androidx.core.graphics.drawable.IconCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import android.content.ContentResolver
import android.media.MediaMetadataRetriever
import android.provider.OpenableColumns
import java.io.File
import java.util.UUID

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "app.summsumm/intent"
        private const val RECORDING_CHANNEL = "app.summsumm/recording"
        private const val RECORDING_EVENTS_CHANNEL = "app.summsumm/recording_events"
        private const val PROCESSING_CHANNEL = "app.summsumm/processing"
        private const val STOP_RECORDING_ACTION = "app.summsumm.STOP_RECORDING"
        private const val REQUEST_READ_STORAGE = 1001
        private const val MAX_PDF_SIZE_BYTES = 10 * 1024 * 1024 // 10MB
        private const val PREFS_NAME = "SummsummPrefs"
        private const val KEY_SHORTCUT_CREATED = "shortcutCreated"
        private const val ACTION_SETTINGS = "app.summsumm.OPEN_SETTINGS"
    }

    private var eventSink: EventChannel.EventSink? = null
    private var flutterEngineRef: FlutterEngine? = null

    private val stopRecordingReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            eventSink?.success("stopped")
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        val action = intent?.action
        if (action == Intent.ACTION_MAIN || action == ACTION_SETTINGS) {
            setTheme(R.style.NormalTheme)
        }
        super.onCreate(savedInstanceState)
        if (action == Intent.ACTION_MAIN || action == ACTION_SETTINGS) {
            try {
                val m = android.app.Activity::class.java.getDeclaredMethod("convertFromTranslucent")
                m.isAccessible = true
                m.invoke(this)
            } catch (_: Throwable) {
                // Best-effort; ignore if unavailable.
            }
        }
        ContextCompat.registerReceiver(
            this,
            stopRecordingReceiver,
            IntentFilter(STOP_RECORDING_ACTION),
            ContextCompat.RECEIVER_NOT_EXPORTED,
        )
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        // Notify Flutter about the new intent
        flutterEngineRef?.let { engine ->
            MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
                .invokeMethod("onNewIntent", getInitialIntent())
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngineRef = flutterEngine

        // MethodChannel for intent handling
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
                            } catch (e: SecurityException) {
                                result.error("PERMISSION_DENIED", "Permission denied. Please grant storage access.", null)
                            } catch (e: Exception) {
                                result.error("READ_ERROR", e.message, null)
                            }
                        } else {
                            result.error("INVALID_URI", "URI is null", null)
                        }
                    }
                    "getAudioDuration" -> {
                        val filePath = call.argument<String>("path")
                        if (filePath != null) {
                            val durationMs = getAudioDurationMs(filePath)
                            result.success(durationMs)
                        } else {
                            result.error("INVALID_PATH", "Path is null", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        // MethodChannel for recording control
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, RECORDING_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startForegroundService" -> {
                    val intent = Intent(this, RecordingService::class.java)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(null)
                }
                "stopForegroundService" -> {
                    val intent = Intent(this, RecordingService::class.java)
                    stopService(intent)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // MethodChannel for processing service (transcription/summarization)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PROCESSING_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startProcessingService" -> {
                    val intent = Intent(this, ProcessingService::class.java)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(null)
                }
                "stopProcessingService" -> {
                    val intent = Intent(this, ProcessingService::class.java)
                    stopService(intent)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // EventChannel for recording events
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, RECORDING_EVENTS_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, sink: EventChannel.EventSink) {
                    eventSink = sink
                }
                override fun onCancel(args: Any?) {
                    eventSink = null
                }
            }
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQUEST_READ_STORAGE) {
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                getInitialIntent()?.let { intentData ->
                    flutterEngineRef?.let { engine ->
                        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
                            .invokeMethod("onPermissionGranted", intentData)
                    }
                }
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        unregisterReceiver(stopRecordingReceiver)
    }

    private fun readContentUriBytes(uri: Uri): ByteArray? {
        return try {
            if (ContextCompat.checkSelfPermission(
                    this,
                    Manifest.permission.READ_EXTERNAL_STORAGE
                ) != PackageManager.PERMISSION_GRANTED &&
                Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE),
                    REQUEST_READ_STORAGE
                )
                return null
            }
            this.contentResolver.openInputStream(uri)?.use {
                val bytes = it.readBytes()
                Log.d("Summsumm", "Read ${bytes.size} bytes from URI: $uri")
                bytes
            }
        } catch (e: SecurityException) {
            Log.e("Summsumm", "Permission denied for URI: $uri", e)
            null
        } catch (e: Exception) {
            Log.e("Summsumm", "Failed to read URI: $uri", e)
            null
        }
    }

    private fun getInitialIntent(): Map<String, Any?>? {
        val intent = this.intent ?: return null
        val action = intent.action ?: return null
        val documents = mutableListOf<Map<String, Any?>>()

        if (Intent.ACTION_VIEW == action && intent.type == "application/pdf") {
            val uri = intent.data
            uri?.let { addPdfDocument(it, documents) }
        } else if (Intent.ACTION_SEND == action) {
            when {
                intent.type == "text/plain" -> {
                    val text = intent.getStringExtra(Intent.EXTRA_TEXT)
                    text?.let { documents.add(mapOf("text" to it)) }
                }
                intent.type?.startsWith("audio/") == true -> {
                    val uri = getParcelableExtraCompat(intent, Intent.EXTRA_STREAM)
                    uri?.let { addAudioDocument(it, documents, intent.type!!) }
                }
                intent.type == "application/pdf" -> {
                    val uri = getParcelableExtraCompat(intent, Intent.EXTRA_STREAM)
                    uri?.let { addPdfDocument(it, documents) }
                }
            }
        } else if (Intent.ACTION_SEND_MULTIPLE == action) {
            when {
                intent.type == "text/plain" -> {
                    val texts = intent.getStringArrayListExtra(Intent.EXTRA_TEXT)
                    texts?.forEach { text -> documents.add(mapOf("text" to text)) }
                }
                intent.type?.startsWith("audio/") == true -> {
                    val uris = getParcelableArrayListExtraCompat(intent, Intent.EXTRA_STREAM)
                    uris?.forEach { addAudioDocument(it, documents, intent.type!!) }
                }
                intent.type == "application/pdf" -> {
                    val uris = getParcelableArrayListExtraCompat(intent, Intent.EXTRA_STREAM)
                    uris?.forEach { uri -> addPdfDocument(uri, documents) }
                }
            }
        } else if (Intent.ACTION_PROCESS_TEXT == action) {
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
            documents.add(mapOf(
                "text" to "",
                "name" to fileName,
                "error" to "file_too_large"
            ))
            return
        }

        documents.add(mapOf(
            "uri" to uri.toString(),
            "name" to fileName,
            "size" to fileSize
        ))
    }

    private fun addAudioDocument(uri: Uri, documents: MutableList<Map<String, Any?>>, mimeType: String) {
        val fileName = getFileName(uri)
        val fileSize = getFileSize(uri)
        var durationMs: Long? = null

        try {
            val retriever = MediaMetadataRetriever()
            retriever.setDataSource(this, uri)
            durationMs = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull()
            retriever.release()
        } catch (_: Exception) { }

        val meetingsDir = File(filesDir, "meetings")
        meetingsDir.mkdirs()
        val id = UUID.randomUUID().toString()
        val ext = when (mimeType.lowercase()) {
            "audio/mpeg" -> "mp3"
            "audio/mp4", "audio/x-m4a" -> "m4a"
            "audio/wav", "audio/x-wav" -> "wav"
            "audio/x-flac" -> "flac"
            "audio/aac" -> "aac"
            "audio/ogg", "audio/x-ogg" -> "ogg"
            "audio/webm" -> "webm"
            else -> "audio"
        }
        val destFile = File(meetingsDir, "$id.$ext")

        try {
            contentResolver.openInputStream(uri)?.use { input ->
                destFile.outputStream().use { output ->
                    input.copyTo(output)
                }
            }
        } catch (_: Exception) {
            documents.add(mapOf("text" to "", "name" to fileName, "error" to "copy_failed"))
            return
        }

        documents.add(mapOf(
            "type" to "audio",
            "path" to destFile.absolutePath,
            "name" to fileName,
            "size" to fileSize,
            "durationMs" to durationMs
        ))
    }

    private fun getFileName(uri: Uri): String? {
        var name: String? = null
        this.contentResolver.query(uri, null, null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) {
                val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (nameIndex >= 0) name = cursor.getString(nameIndex)
            }
        }
        return name
    }

    private fun getFileSize(uri: Uri): Long? {
        var size: Long? = null
        this.contentResolver.query(uri, null, null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) {
                val sizeIndex = cursor.getColumnIndex(OpenableColumns.SIZE)
                if (sizeIndex >= 0) size = cursor.getLong(sizeIndex)
            }
        }
        return size
    }

    private fun offerSettingsShortcutIfNeeded() {
        val prefs: SharedPreferences = this.getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
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
    private fun getParcelableExtraCompat(intent: Intent, extra: String): Uri? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(extra, Uri::class.java)
        } else {
            @Suppress("UNCHECKED_CAST")
            intent.getParcelableExtra(extra) as Uri?
        }
    }

    @Suppress("DEPRECATION")
    private fun getParcelableArrayListExtraCompat(intent: Intent, extra: String): List<Uri>? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableArrayListExtra(extra, Uri::class.java)
        } else {
            val result = intent.getParcelableArrayListExtra<android.os.Parcelable>(extra)
            @Suppress("UNCHECKED_CAST")
            result?.filterIsInstance<Uri>()
        }
    }

    /// Returns audio duration in milliseconds using MediaMetadataRetriever.
    /// Returns 0 if duration cannot be determined.
    private fun getAudioDurationMs(filePath: String): Int {
        return try {
            val retriever = MediaMetadataRetriever()
            retriever.setDataSource(filePath)
            val durationMs = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0L
            retriever.release()
            (durationMs / 1000).toInt() // Convert to seconds
        } catch (_: Exception) {
            0
        }
    }
}