package com.example.nexora

import android.app.DownloadManager
import android.content.Context
import android.net.Uri
import android.os.Build
import android.os.Environment
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private companion object {
        const val CHANNEL = "com.nexora/material_download"
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveToDownloads" -> {
                        val url = call.argument<String>("url")
                        val fileName = call.argument<String>("fileName")
                        if (url.isNullOrBlank() || fileName.isNullOrBlank()) {
                            result.error("bad_args", "url and fileName are required", null)
                        } else {
                            try {
                                val id = enqueueDownload(url, fileName)
                                result.success(id)
                            } catch (e: Exception) {
                                result.error("download_failed", e.message, null)
                            }
                        }
                    }
                    "saveBytesToDownloads" -> {
                        val bytes = call.argument<ByteArray>("bytes")
                        val fileName = call.argument<String>("fileName")
                        if (bytes == null || fileName.isNullOrBlank()) {
                            result.error("bad_args", "bytes and fileName are required", null)
                        } else {
                            try {
                                val path = saveBytesToPublicDownloads(bytes, fileName)
                                result.success(path)
                            } catch (e: Exception) {
                                result.error("save_bytes_failed", e.message, null)
                            }
                        }
                    }
                    "getDownloadDirectory" -> {
                        result.success(
                            Environment.getExternalStoragePublicDirectory(
                                Environment.DIRECTORY_DOWNLOADS
                            ).absolutePath
                        )
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun saveBytesToPublicDownloads(bytes: ByteArray, fileName: String): String {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = android.content.ContentValues().apply {
                put(android.provider.MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                put(
                    android.provider.MediaStore.MediaColumns.MIME_TYPE,
                    if (fileName.endsWith(".pdf", ignoreCase = true)) "application/pdf" else "application/octet-stream"
                )
                put(android.provider.MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
            }
            val uri = contentResolver.insert(android.provider.MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: throw Exception("Could not insert entry into MediaStore Downloads")
            contentResolver.openOutputStream(uri)?.use { os ->
                os.write(bytes)
            } ?: throw Exception("Could not open output stream for $fileName")
            return "Downloads/$fileName"
        } else {
            val dir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
            if (!dir.exists()) dir.mkdirs()
            val file = java.io.File(dir, fileName)
            file.writeBytes(bytes)
            return file.absolutePath
        }
    }

    /**
     * Hands the URL to the system DownloadManager so the file lands in the
     * user's public Downloads folder and survives app uninstall.
     *
     * Requires WRITE_EXTERNAL_STORAGE on API <= 28; on API 29+ scoped storage
     * makes DownloadManager the only permission-free route.
     */
    private fun enqueueDownload(url: String, fileName: String): Long {
        val request = DownloadManager.Request(Uri.parse(url))
            .setTitle(fileName)
            .setDescription("Downloading Nexora material")
            .setNotificationVisibility(
                DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED
            )
            .setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS, fileName)
            .setAllowedOverMetered(true)
            .setAllowedOverRoaming(false)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            request.addRequestHeader("User-Agent", "Mozilla/5.0 (Linux; Android 10)")
        }

        val dm = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
        return dm.enqueue(request)
    }
}
