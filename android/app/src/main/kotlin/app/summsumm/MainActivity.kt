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
import android.content.ContentValues
import android.media.MediaMetadataRetriever
import android.os.Environment
import android.provider.MediaStore
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

    private val supportedAudioExtensions = setOf("m4a", "mp3", "wav", "flac", "aac", "ogg", "webm")

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
                    "startBackupForeground" -> {
                        BackupForegroundService.start(this)
                        result.success(null)
                    }
                    "stopBackupForeground" -> {
                        BackupForegroundService.stop(this)
                        result.success(null)
                    }
                    "updateBackupProgress" -> {
                        val title = call.argument<String>("title") ?: "Creating backup"
                        val text = call.argument<String>("text") ?: "Please wait..."
                        val progress = call.argument<Int>("progress") ?: 0
                        val max = call.argument<Int>("max") ?: 100
                        val indeterminate = call.argument<Boolean>("indeterminate") ?: false
                        BackupForegroundService.updateProgress(this, title, text, progress, max, indeterminate)
                        result.success(null)
                    }
                    "showBackupComplete" -> {
                        val filePath = call.argument<String>("filePath") ?: ""
                        val displayName = call.argument<String>("displayName") ?: filePath.substringAfterLast("/")
                        BackupForegroundService.showComplete(this, filePath, displayName)
                        result.success(null)
                    }
                    "showBackupError" -> {
                        val errorMessage = call.argument<String>("errorMessage") ?: "Backup failed"
                        BackupForegroundService.showError(this, errorMessage)
                        result.success(null)
                    }
                    "saveToPublicDownloads" -> {
                        val sourcePath = call.argument<String>("sourcePath")
                        val displayName = call.argument<String>("displayName")
                        if (sourcePath != null && displayName != null) {
                            try {
                                val publicPath = saveToPublicDownloads(sourcePath, displayName)
                                result.success(publicPath)
                            } catch (e: Exception) {
                                result.error("SAVE_ERROR", e.message, null)
                            }
                        } else {
                            result.error("INVALID_ARGS", "sourcePath or displayName is null", null)
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

        if (Intent.ACTION_VIEW == action) {
            val uri = intent.data
            when {
                uri != null && isAudioIntent(intent.type, uri) -> {
                    addAudioDocument(uri, documents, intent.type)
                }
                intent.type == "application/pdf" -> {
                    val uri = intent.data
                    uri?.let { addPdfDocument(it, documents) }
                }
                intent.type == "application/octet-stream" -> {
                    val uri = intent.data
                    uri?.let { addBackupDocument(it, documents) }
                }
            }
        } else if (Intent.ACTION_SEND == action) {
            when {
                intent.type == "text/plain" -> {
                    val text = intent.getStringExtra(Intent.EXTRA_TEXT)
                    text?.let { documents.add(mapOf("text" to it)) }
                }
                isAudioIntent(intent.type, getParcelableExtraCompat(intent, Intent.EXTRA_STREAM)) -> {
                    val uri = getParcelableExtraCompat(intent, Intent.EXTRA_STREAM)
                    uri?.let { addAudioDocument(it, documents, intent.type) }
                }
                intent.type == "application/pdf" -> {
                    val uri = getParcelableExtraCompat(intent, Intent.EXTRA_STREAM)
                    uri?.let { addPdfDocument(it, documents) }
                }
                intent.type == "application/octet-stream" -> {
                    val uri = getParcelableExtraCompat(intent, Intent.EXTRA_STREAM)
                    uri?.let { addBackupDocument(it, documents) }
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
                    uris?.forEach { addAudioDocument(it, documents, intent.type) }
                }
                intent.type == "application/octet-stream" -> {
                    val uris = getParcelableArrayListExtraCompat(intent, Intent.EXTRA_STREAM)
                    uris?.forEach { uri ->
                        if (isAudioUri(uri)) {
                            addAudioDocument(uri, documents, intent.type)
                        } else {
                            addBackupDocument(uri, documents)
                        }
                    }
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

    private fun addBackupDocument(uri: Uri, documents: MutableList<Map<String, Any?>>) {
        val fileName = getFileName(uri)
        val fileSize = getFileSize(uri)

        documents.add(mapOf(
            "type" to "backup",
            "uri" to uri.toString(),
            "name" to fileName,
            "size" to fileSize
        ))
    }

    private fun addAudioDocument(uri: Uri, documents: MutableList<Map<String, Any?>>, mimeType: String?) {
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
        val ext = when (mimeType?.lowercase()) {
            "audio/mpeg" -> "mp3"
            "audio/mp4", "audio/x-m4a" -> "m4a"
            "audio/wav", "audio/x-wav" -> "wav"
            "audio/x-flac" -> "flac"
            "audio/aac" -> "aac"
            "audio/ogg", "audio/x-ogg" -> "ogg"
            "audio/webm" -> "webm"
            else -> fileName?.substringAfterLast('.', missingDelimiterValue = "")
                ?.lowercase()
                ?.takeIf { it in supportedAudioExtensions }
                ?: "audio"
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

    private fun isAudioIntent(mimeType: String?, uri: Uri?): Boolean {
        return mimeType?.startsWith("audio/") == true || (mimeType == "application/octet-stream" && uri != null && isAudioUri(uri))
    }

    private fun isAudioUri(uri: Uri): Boolean {
        val fileName = getFileName(uri) ?: uri.lastPathSegment ?: return false
        val ext = fileName.substringAfterLast('.', missingDelimiterValue = "").lowercase()
        return ext in supportedAudioExtensions
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

    /// Saves a file to the public Downloads folder using MediaStore.
    /// Returns the public URI of the saved file.
    private fun saveToPublicDownloads(sourcePath: String, displayName: String): String? {
        val sourceFile = File(sourcePath)
        if (!sourceFile.exists()) {
            throw IllegalArgumentException("Source file does not exist: $sourcePath")
        }

        val resolver = contentResolver
        val contentValues = ContentValues().apply {
            put(MediaStore.Downloads.DISPLAY_NAME, displayName)
            put(MediaStore.Downloads.MIME_TYPE, "application/octet-stream")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(MediaStore.Downloads.IS_PENDING, 1)
            }
        }

        val collection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        } else {
            MediaStore.Downloads.EXTERNAL_CONTENT_URI
        }

        val uri = resolver.insert(collection, contentValues)
            ?: throw RuntimeException("Failed to create MediaStore entry")

        try {
            resolver.openOutputStream(uri)?.use { outputStream ->
                sourceFile.inputStream().use { inputStream ->
                    inputStream.copyTo(outputStream)
                }
            }
        } catch (e: Exception) {
            resolver.delete(uri, null, null)
            throw RuntimeException("Failed to copy file to Downloads: ${e.message}")
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            contentValues.clear()
            contentValues.put(MediaStore.Downloads.IS_PENDING, 0)
            resolver.update(uri, contentValues, null, null)
        }

        return uri.toString()
    }
}
