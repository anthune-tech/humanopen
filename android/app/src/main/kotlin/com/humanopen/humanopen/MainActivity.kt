package com.humanopen.humanopen

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.os.Environment
import android.provider.MediaStore
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.Locale

class MainActivity : FlutterActivity() {
    private val FOREGROUND_CHANNEL = "com.humanopen/foreground_service"
    private val STT_CHANNEL = "com.humanopen/stt"
    private val FILE_CHANNEL = "com.humanopen/file_list"
    private var speechRecognizer: SpeechRecognizer? = null
    private var pendingSttResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FOREGROUND_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startService" -> {
                    val intent = Intent(this, ForegroundService::class.java)
                    startForegroundService(intent)
                    result.success(null)
                }
                "stopService" -> {
                    val intent = Intent(this, ForegroundService::class.java)
                    stopService(intent)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FILE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "listFiles" -> {
                    val path = call.argument<String>("path") ?: "/storage/emulated/0"
                    try {
                        val output = listDirectory(path)
                        result.success(output)
                    } catch (e: Exception) {
                        Log.e("HumanopenFile", "Error listing $path: ${e.message}")
                        result.error("FILE_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, STT_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "initialize" -> {
                    val available = SpeechRecognizer.isRecognitionAvailable(this)
                    result.success(available)
                }
                "hasPermission" -> {
                    val granted = ContextCompat.checkSelfPermission(this,
                        Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
                    result.success(granted)
                }
                "requestPermission" -> {
                    pendingSttResult = result
                    ActivityCompat.requestPermissions(this,
                        arrayOf(Manifest.permission.RECORD_AUDIO), 1001)
                }
                "listen" -> {
                    val duration = (call.argument<Int>("durationSeconds") ?: 15).toInt()
                    startListening(result, duration)
                }
                "cancel" -> {
                    speechRecognizer?.cancel()
                    speechRecognizer?.destroy()
                    speechRecognizer = null
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 1001) {
            val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingSttResult?.success(granted)
            pendingSttResult = null
        }
    }

    private fun listDirectory(path: String): String {
        Log.d("HumanopenFile", "listDirectory($path) hasManageStorage=${Environment.isExternalStorageManager()}")

        // If we have MANAGE_EXTERNAL_STORAGE, use direct File API
        if (Environment.isExternalStorageManager()) {
            try {
                val dir = File(path)
                if (dir.exists() && dir.isDirectory) {
                    val files = dir.listFiles()
                    if (files != null && files.isNotEmpty()) {
                        val sb = StringBuilder()
                        for (file in files) {
                            val type = if (file.isDirectory) "dir" else "file"
                            sb.appendLine("$type ${file.name} (${file.length()} bytes, modified ${file.lastModified()})")
                        }
                        Log.d("HumanopenFile", "File API returned ${files.size} entries")
                        return sb.toString().trimEnd()
                    }
                    Log.d("HumanopenFile", "File API: directory exists but no files visible")
                } else {
                    Log.d("HumanopenFile", "File API: $path does not exist")
                }
            } catch (e: Exception) {
                Log.e("HumanopenFile", "File API failed: ${e.message}")
            }
        }

        // Try without su (standard app UID)
        try {
            val process = Runtime.getRuntime().exec(arrayOf("ls", "-la", path))
            val reader = java.io.BufferedReader(java.io.InputStreamReader(process.inputStream))
            val errReader = java.io.BufferedReader(java.io.InputStreamReader(process.errorStream))
            val output = reader.readText()
            val err = errReader.readText()
            process.waitFor()
            Log.d("HumanopenFile", "ls stdout: $output")
            Log.d("HumanopenFile", "ls stderr: $err")
            if (output.isNotBlank()) return output
        } catch (e: Exception) {
            Log.e("HumanopenFile", "ls exec failed: ${e.message}")
        }

        // MediaStore fallback for well-known paths
        try {
            val uri = when {
                path.contains("/Download") -> MediaStore.Downloads.EXTERNAL_CONTENT_URI
                path.contains("/DCIM/Camera") || path.contains("/Pictures") -> MediaStore.Images.Media.EXTERNAL_CONTENT_URI
                else -> null
            }
            if (uri != null) {
                val sb = StringBuilder()
                val projection = arrayOf(
                    MediaStore.MediaColumns.DISPLAY_NAME,
                    MediaStore.MediaColumns.SIZE,
                    MediaStore.MediaColumns.DATE_MODIFIED,
                )
                contentResolver.query(uri, projection, null, null, null)?.use { cursor ->
                    val count = cursor.count
                    Log.d("HumanopenFile", "MediaStore returned $count rows")
                    while (cursor.moveToNext()) {
                        val name = cursor.getString(0) ?: "unknown"
                        val size = cursor.getLong(1)
                        val modified = cursor.getLong(2)
                        sb.appendLine("$name ($size bytes, modified $modified)")
                    }
                }
                if (sb.isNotEmpty()) return sb.toString()
            }
        } catch (e: Exception) {
            Log.e("HumanopenFile", "MediaStore query failed: ${e.message}")
        }

        return ""
    }

    private fun startListening(result: MethodChannel.Result, durationSeconds: Int) {
        try {
            speechRecognizer?.cancel()
            speechRecognizer?.destroy()
        } catch (_: Exception) {}

        speechRecognizer = SpeechRecognizer.createSpeechRecognizer(this)
        if (speechRecognizer == null) {
            result.error("STT_UNAVAILABLE", "SpeechRecognizer not available", null)
            return
        }

        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.US.toString())
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
        }

        val capturedResult = result
        speechRecognizer!!.setRecognitionListener(object : RecognitionListener {
            private val allText = StringBuilder()
            private var handled = false

            override fun onReadyForSpeech(params: Bundle?) {}
            override fun onBeginningOfSpeech() {}
            override fun onRmsChanged(rmsdB: Float) {}
            override fun onBufferReceived(buffer: ByteArray?) {}
            override fun onEndOfSpeech() {}

            override fun onPartialResults(partialResults: Bundle?) {
                val matches = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                if (!matches.isNullOrEmpty()) {
                    allText.clear()
                    allText.append(matches[0])
                }
            }

            override fun onResults(results: Bundle?) {
                if (handled) return
                handled = true
                val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                if (!matches.isNullOrEmpty()) {
                    capturedResult.success(matches[0])
                } else if (allText.isNotEmpty()) {
                    capturedResult.success(allText.toString())
                } else {
                    capturedResult.success("")
                }
            }

            override fun onError(error: Int) {
                android.util.Log.e("HumanopenSTT", "SpeechRecognizer error code: $error")
                if (handled) return
                handled = true
                if (allText.isNotEmpty()) {
                    capturedResult.success(allText.toString())
                } else {
                    capturedResult.success("")
                }
            }

            override fun onEvent(eventType: Int, params: Bundle?) {}
        })

        speechRecognizer!!.startListening(intent)
    }

    override fun onDestroy() {
        try {
            speechRecognizer?.cancel()
            speechRecognizer?.destroy()
        } catch (_: Exception) {}
        super.onDestroy()
    }
}
