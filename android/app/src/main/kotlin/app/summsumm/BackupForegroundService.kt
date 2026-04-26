package app.summsumm

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import android.content.pm.ServiceInfo

class BackupForegroundService : Service() {
    companion object {
        const val CHANNEL_ID = "BackupServiceChannel"
        const val NOTIFICATION_ID = 2
        const val ACTION_START = "app.summsumm.START_BACKUP"
        const val ACTION_STOP = "app.summsumm.STOP_BACKUP"
        const val ACTION_UPDATE_PROGRESS = "app.summsumm.UPDATE_BACKUP_PROGRESS"
        const val ACTION_SHOW_COMPLETE = "app.summsumm.SHOW_BACKUP_COMPLETE"
        const val ACTION_SHOW_ERROR = "app.summsumm.SHOW_BACKUP_ERROR"
        
        const val EXTRA_TITLE = "title"
        const val EXTRA_TEXT = "text"
        const val EXTRA_PROGRESS = "progress"
        const val EXTRA_MAX = "max"
        const val EXTRA_INDETERMINATE = "indeterminate"
        const val EXTRA_FILE_PATH = "filePath"
        const val EXTRA_DISPLAY_NAME = "displayName"
        const val EXTRA_ERROR_MESSAGE = "errorMessage"
        
        fun start(context: Context) {
            val intent = Intent(context, BackupForegroundService::class.java).apply {
                action = ACTION_START
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }
        
        fun stop(context: Context) {
            val intent = Intent(context, BackupForegroundService::class.java).apply {
                action = ACTION_STOP
            }
            context.startService(intent)
        }
        
        fun updateProgress(context: Context, title: String, text: String, progress: Int, max: Int = 100, indeterminate: Boolean = false) {
            val intent = Intent(context, BackupForegroundService::class.java).apply {
                action = ACTION_UPDATE_PROGRESS
                putExtra(EXTRA_TITLE, title)
                putExtra(EXTRA_TEXT, text)
                putExtra(EXTRA_PROGRESS, progress)
                putExtra(EXTRA_MAX, max)
                putExtra(EXTRA_INDETERMINATE, indeterminate)
            }
            context.startService(intent)
        }
        
        fun showComplete(context: Context, filePath: String, displayName: String) {
            val intent = Intent(context, BackupForegroundService::class.java).apply {
                action = ACTION_SHOW_COMPLETE
                putExtra(EXTRA_FILE_PATH, filePath)
                putExtra(EXTRA_DISPLAY_NAME, displayName)
            }
            context.startService(intent)
        }
        
        fun showError(context: Context, errorMessage: String) {
            val intent = Intent(context, BackupForegroundService::class.java).apply {
                action = ACTION_SHOW_ERROR
                putExtra(EXTRA_ERROR_MESSAGE, errorMessage)
            }
            context.startService(intent)
        }
    }

    private lateinit var notificationManager: NotificationManager

    override fun onCreate() {
        super.onCreate()
        notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_UPDATE_PROGRESS -> {
                val title = intent.getStringExtra(EXTRA_TITLE) ?: "Creating backup"
                val text = intent.getStringExtra(EXTRA_TEXT) ?: "Please wait..."
                val progress = intent.getIntExtra(EXTRA_PROGRESS, 0)
                val max = intent.getIntExtra(EXTRA_MAX, 100)
                val indeterminate = intent.getBooleanExtra(EXTRA_INDETERMINATE, false)
                val notification = buildProgressNotification(title, text, progress, max, indeterminate)
                notificationManager.notify(NOTIFICATION_ID, notification)
                return START_STICKY
            }
            ACTION_SHOW_COMPLETE -> {
                val filePath = intent.getStringExtra(EXTRA_FILE_PATH) ?: ""
                val displayName = intent.getStringExtra(EXTRA_DISPLAY_NAME) ?: filePath.substringAfterLast("/")
                stopForeground(STOP_FOREGROUND_REMOVE)
                val notification = buildCompleteNotification(filePath, displayName)
                notificationManager.notify(NOTIFICATION_ID, notification)
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_SHOW_ERROR -> {
                val errorMessage = intent.getStringExtra(EXTRA_ERROR_MESSAGE) ?: "Backup failed"
                stopForeground(STOP_FOREGROUND_REMOVE)
                val notification = buildErrorNotification(errorMessage)
                notificationManager.notify(NOTIFICATION_ID, notification)
                stopSelf()
                return START_NOT_STICKY
            }
        }
        
        val notification = buildProgressNotification("Creating backup", "Please wait...", 0, 100, true)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        return START_STICKY
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Backup Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows backup progress"
            }
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun buildProgressNotification(title: String, text: String, progress: Int, max: Int, indeterminate: Boolean): Notification {
        val tapIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_menu_save)
            .setContentIntent(tapIntent)
            .setOngoing(true)
            .setProgress(max, progress, indeterminate)
            .build()
    }

    private fun buildCompleteNotification(filePath: String, displayName: String): Notification {
        val tapIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Backup complete")
            .setContentText("Saved to $displayName")
            .setSmallIcon(android.R.drawable.ic_menu_save)
            .setContentIntent(tapIntent)
            .setOngoing(false)
            .setAutoCancel(true)
            .build()
    }

    private fun buildErrorNotification(errorMessage: String): Notification {
        val tapIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Backup failed")
            .setContentText(errorMessage)
            .setSmallIcon(android.R.drawable.ic_menu_save)
            .setContentIntent(tapIntent)
            .setOngoing(false)
            .setAutoCancel(true)
            .build()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
    }
}
