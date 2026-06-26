package com.humanopen.humanopen

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity : FlutterActivity() {
    private val FOREGROUND_CHANNEL = "com.humanopen/foreground_service"
    private val STT_CHANNEL = "com.humanopen/stt"
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
