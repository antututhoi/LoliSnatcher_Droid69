package com.noaisu.loliSnatcher

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.HandlerThread
import android.os.IBinder
import android.os.Message
import android.os.Messenger
import android.os.SystemClock
import android.util.Log
import androidx.core.content.FileProvider
import java.io.File
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference

/**
 * 69 mod: sends a finished download to 69-Media Helper, which converts it with its own settings
 * (quality / size, GIF to MP4 – kept as GIF when the MP4 is not smaller, WebM, cover picture in videos).
 */
object Mod69Helper {
    private const val TAG = "Mod69Helper"
    const val PACKAGE = "com.gor69.mediahelper"
    private const val ACTION_PROCESS = "com.gor69.mediahelper.PROCESS"
    private const val ACTION_OPEN_SETTINGS = "com.gor69.mediahelper.OPEN_SETTINGS"
    private const val MSG_PROCESS = 1
    private const val MSG_RESULT = 2

    class Result(
        val file: File,
        val changed: Boolean,
        val extension: String,
        val mime: String?,
        val suffix: String,
        val info: String,
        val originalSize: Long,
        val finalSize: Long,
    )

    fun isInstalled(c: Context): Boolean = runCatching {
        c.packageManager.getPackageInfo(PACKAGE, 0); true
    }.getOrDefault(false)

    fun openSettings(c: Context): Boolean = runCatching {
        c.startActivity(Intent(ACTION_OPEN_SETTINGS).setPackage(PACKAGE).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        true
    }.getOrDefault(false)

    fun typeFor(ext: String): Int = when (ext.lowercase()) {
        "gif" -> 1
        "mp4", "webm", "mkv", "mov", "m4v" -> 2
        else -> 0
    }

    /** Blocking; run off the main thread. Returns null when the helper is missing or failed. */
    fun process(c: Context, input: File, ext: String): Result? {
        if (!isInstalled(c)) return null
        val app = c.applicationContext
        val authority = app.packageName + ".fileprovider"
        val out = File(app.cacheDir, "mod69_out_" + System.nanoTime())
        out.createNewFile()
        val inUri: Uri
        val outUri: Uri
        try {
            inUri = FileProvider.getUriForFile(app, authority, input)
            outUri = FileProvider.getUriForFile(app, authority, out)
        } catch (e: Exception) {
            Log.w(TAG, "cannot share files", e)
            out.delete()
            return null
        }
        app.grantUriPermission(PACKAGE, inUri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
        app.grantUriPermission(PACKAGE, outUri, Intent.FLAG_GRANT_WRITE_URI_PERMISSION or Intent.FLAG_GRANT_READ_URI_PERMISSION)
        try {
            val m = Message.obtain(null, MSG_PROCESS)
            m.data = Bundle().apply {
                putParcelable("in", inUri)
                putParcelable("out", outUri)
                putInt("type", typeFor(ext))
                putString("ext", ext.lowercase())
            }
            val answer = call(app, m) ?: run { out.delete(); return null }
            if (!answer.getBoolean("ok", false)) {
                out.delete()
                return null
            }
            val changed = answer.getBoolean("changed", false) && out.length() > 0
            if (!changed) out.delete()
            val file = if (changed) out else input
            return Result(
                file = file,
                changed = changed,
                extension = answer.getString("ext")?.ifBlank { null } ?: ext,
                mime = answer.getString("mime"),
                suffix = answer.getString("suffix") ?: "",
                info = answer.getString("info") ?: "",
                originalSize = answer.getLong("original_size", input.length()),
                finalSize = file.length(),
            )
        } finally {
            app.revokeUriPermission(inUri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
            app.revokeUriPermission(outUri, Intent.FLAG_GRANT_WRITE_URI_PERMISSION or Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
    }

    private fun call(app: Context, request: Message): Bundle? {
        val connected = CountDownLatch(1)
        val service = AtomicReference<Messenger?>()
        val conn = object : ServiceConnection {
            override fun onServiceConnected(name: ComponentName?, binder: IBinder?) {
                service.set(Messenger(binder))
                connected.countDown()
            }

            override fun onServiceDisconnected(name: ComponentName?) {
                service.set(null)
            }
        }
        val replyThread = HandlerThread("mod69-helper-reply").apply { start() }
        try {
            val bound = app.bindService(Intent(ACTION_PROCESS).setPackage(PACKAGE), conn, Context.BIND_AUTO_CREATE or Context.BIND_IMPORTANT)
            if (!bound || !connected.await(15, TimeUnit.SECONDS) || service.get() == null) {
                Log.w(TAG, "helper not reachable (same signing key?)")
                return null
            }
            val answered = CountDownLatch(1)
            val answer = AtomicReference<Bundle?>()
            request.replyTo = Messenger(Handler(replyThread.looper) { msg ->
                if (msg.what == MSG_RESULT) {
                    answer.set(msg.data)
                    answered.countDown()
                }
                true
            })
            service.get()!!.send(request)
            val deadline = SystemClock.elapsedRealtime() + TimeUnit.HOURS.toMillis(2)
            while (!answered.await(1, TimeUnit.SECONDS)) {
                if (service.get() == null || SystemClock.elapsedRealtime() > deadline) return null
            }
            return answer.get()
        } catch (e: Exception) {
            Log.w(TAG, "helper call failed", e)
            return null
        } finally {
            runCatching { app.unbindService(conn) }
            replyThread.quitSafely()
        }
    }

    fun sizeText(bytes: Long): String = when {
        bytes < 0 -> "?"
        bytes >= 1024 * 1024 -> String.format(java.util.Locale.US, "%.1f MB", bytes / 1048576.0)
        else -> "${maxOf(1, bytes / 1024)} KB"
    }
}
