package com.homepanel.clock

import android.Manifest
import android.content.ContentUris
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import android.provider.MediaStore
import android.view.View
import android.view.WindowManager
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

class MainActivity : AudioServiceActivity() {
    private val channelName = "home_info_clock/platform"
    private val mediaExecutor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private var pendingAudioAccessResult: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        enterKioskMode()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "enterKioskMode" -> {
                    enterKioskMode()
                    result.success(null)
                }
                "openBilibili" -> result.success(openBilibili())
                "requestAudioAccess" -> requestAudioAccess(result)
                "scanAudioFolder" -> scanAudioFolderAsync(result)
                "openAudioFolder" -> result.success(openAudioFolder())
                else -> result.notImplemented()
            }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != audioPermissionRequestCode) return
        pendingAudioAccessResult?.success(audioAccessResult())
        pendingAudioAccessResult = null
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) enterKioskMode()
    }

    override fun onDestroy() {
        mediaExecutor.shutdownNow()
        super.onDestroy()
    }

    private fun enterKioskMode() {
        window.decorView.systemUiVisibility =
            View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY or
                View.SYSTEM_UI_FLAG_FULLSCREEN or
                View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or
                View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN or
                View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION or
                View.SYSTEM_UI_FLAG_LAYOUT_STABLE
    }

    private fun openBilibili(): Boolean {
        val packages = arrayOf("tv.danmaku.bili", "com.bilibili.app.in", "com.bilibili.app.blue")
        for (packageName in packages) {
            val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
            if (launchIntent != null) {
                launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(launchIntent)
                return true
            }
        }
        return try {
            startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("bilibili://home")))
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun requestAudioAccess(result: MethodChannel.Result) {
        val missingPermissions = mutableListOf<String>()
        val audioPermission = requiredAudioPermission()
        if (audioPermission != null && !isPermissionGranted(audioPermission)) {
            missingPermissions.add(audioPermission)
        }
        if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                !isPermissionGranted(Manifest.permission.POST_NOTIFICATIONS)
        ) {
            missingPermissions.add(Manifest.permission.POST_NOTIFICATIONS)
        }

        if (missingPermissions.isEmpty()) {
            result.success(audioAccessResult())
            return
        }
        if (pendingAudioAccessResult != null) {
            result.error("audio_permission_pending", "An audio permission request is already active", null)
            return
        }

        pendingAudioAccessResult = result
        requestPermissions(missingPermissions.toTypedArray(), audioPermissionRequestCode)
    }

    private fun audioAccessResult(): Map<String, Boolean> {
        val notificationGranted =
            Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
                isPermissionGranted(Manifest.permission.POST_NOTIFICATIONS)
        return mapOf(
            "audioGranted" to hasAudioAccess(),
            "notificationGranted" to notificationGranted,
        )
    }

    private fun hasAudioAccess(): Boolean {
        val permission = requiredAudioPermission() ?: return true
        return isPermissionGranted(permission)
    }

    private fun requiredAudioPermission(): String? {
        return when {
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU ->
                Manifest.permission.READ_MEDIA_AUDIO
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.M ->
                Manifest.permission.READ_EXTERNAL_STORAGE
            else -> null
        }
    }

    private fun isPermissionGranted(permission: String): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
            checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED
    }

    private fun scanAudioFolderAsync(result: MethodChannel.Result) {
        if (!hasAudioAccess()) {
            result.error("audio_permission_denied", "Audio permission is required", null)
            return
        }
        mediaExecutor.execute {
            try {
                val tracks = scanAudioFolder()
                mainHandler.post { result.success(tracks) }
            } catch (error: Exception) {
                mainHandler.post {
                    result.error("audio_scan_failed", error.message, null)
                }
            }
        }
    }

    private fun scanAudioFolder(): List<Map<String, Any>> {
        val collection =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            } else {
                MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
            }
        val projection = mutableListOf(
            MediaStore.Audio.Media._ID,
            MediaStore.Audio.Media.DISPLAY_NAME,
            MediaStore.Audio.Media.TITLE,
            MediaStore.Audio.Media.ARTIST,
            MediaStore.Audio.Media.DURATION,
            MediaStore.Audio.Media.MIME_TYPE,
        )
        val selection: String
        val selectionArguments: Array<String>
        var legacyFolderPath: String? = null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            projection.add(MediaStore.Audio.Media.RELATIVE_PATH)
            selection = "${MediaStore.Audio.Media.RELATIVE_PATH} = ?"
            selectionArguments = arrayOf(audioRelativePath)
        } else {
            projection.add(MediaStore.Audio.Media.DATA)
            val folder = File(
                Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MUSIC),
                audioFolderName,
            )
            legacyFolderPath = folder.absolutePath
            selection = "${MediaStore.Audio.Media.DATA} LIKE ?"
            selectionArguments = arrayOf("${folder.absolutePath}/%")
        }

        val tracks = mutableListOf<Map<String, Any>>()
        contentResolver.query(
            collection,
            projection.toTypedArray(),
            selection,
            selectionArguments,
            "${MediaStore.Audio.Media.DISPLAY_NAME} COLLATE NOCASE ASC",
        )?.use { cursor ->
            val idColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media._ID)
            val nameColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DISPLAY_NAME)
            val titleColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.TITLE)
            val artistColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ARTIST)
            val durationColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DURATION)
            val mimeColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.MIME_TYPE)
            val dataColumn =
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
                    cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DATA)
                } else {
                    -1
                }
            while (cursor.moveToNext()) {
                if (dataColumn >= 0) {
                    val dataPath = cursor.getString(dataColumn) ?: continue
                    if (File(dataPath).parentFile?.absolutePath != legacyFolderPath) continue
                }
                val displayName = cursor.getString(nameColumn)?.trim().orEmpty()
                if (displayName.isEmpty()) continue
                val title = cursor.getString(titleColumn)?.trim().orEmpty()
                    .ifEmpty { displayName.substringBeforeLast('.') }
                val rawArtist = cursor.getString(artistColumn)?.trim().orEmpty()
                val artist = rawArtist.takeUnless {
                    it == MediaStore.UNKNOWN_STRING || it == "<unknown>"
                }.orEmpty()
                val id = cursor.getLong(idColumn)
                tracks.add(
                    mapOf(
                        "uri" to ContentUris.withAppendedId(collection, id).toString(),
                        "displayName" to displayName,
                        "title" to title,
                        "artist" to artist,
                        "durationMs" to cursor.getLong(durationColumn).coerceAtLeast(0L),
                        "mimeType" to cursor.getString(mimeColumn).orEmpty().ifEmpty { "audio/*" },
                    ),
                )
            }
        }
        return tracks
    }

    private fun openAudioFolder(): Boolean {
        val folder = File(
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MUSIC),
            audioFolderName,
        )
        val folderReady = folder.isDirectory || (!folder.exists() && folder.mkdirs())

        val exactFolderUri = DocumentsContract.buildDocumentUri(
            externalStorageAuthority,
            "primary:Music/$audioFolderName",
        )
        if (folderReady) {
            val directIntent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(exactFolderUri, "vnd.android.document/directory")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            if (startIfAvailable(directIntent)) return true
        }

        val musicUri = DocumentsContract.buildDocumentUri(
            externalStorageAuthority,
            "primary:Music",
        )
        val pickerIntent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
            )
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                putExtra(
                    DocumentsContract.EXTRA_INITIAL_URI,
                    if (folderReady) exactFolderUri else musicUri,
                )
            }
        }
        return startIfAvailable(pickerIntent)
    }

    private fun startIfAvailable(intent: Intent): Boolean {
        return try {
            startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }

    private companion object {
        const val audioPermissionRequestCode = 6101
        const val audioFolderName = "HomeInfoClock"
        const val audioRelativePath = "Music/HomeInfoClock/"
        const val externalStorageAuthority = "com.android.externalstorage.documents"
    }
}
