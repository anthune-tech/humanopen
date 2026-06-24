# humanopen

Standalone personal AI appliance for Android — private, persistent, unlimited.
Targets OnePlus 5 (cheeseburger, SD835) running LineageOS 22.2 (Android 15).

## Features

- Local LLM inference via llama.cpp (GGML CPU backend)
- Persistent chat with SQLite, topic-based conversation folders
- Automatic summarization, fact extraction, and 3-month archive
- OpenAI-compatible API server on port 8080 (streaming SSE)
- Cross-platform client mode (use any OpenAI-compatible remote API)
- Speech-to-text via Android SpeechRecognizer
- Ambient gradient background that pulses during generation
- Settings UI for model paths, GPU layers, temperature, context size

## Prerequisites

- Android device (arm64-v8a), minSdk 28
- Flutter SDK with Android NDK
- Model files (GGUF format):
  - Main model: e.g. Dolphin3.0-Qwen2.5-3b-Q4_K_M.gguf
  - Summarizer: e.g. qwen2.5-0.5b-instruct-q4_k_m.gguf

## Build & Install

```bash
# 1. Build (run from project root on a fast filesystem)
cd /tmp/opencode/humanopen
flutter build apk --debug --target-platform android-arm64

# 2. Install
adb install -r build/app/outputs/flutter-apk/app-debug.apk

# 3. Copy models to app-private directory
adb shell cp /storage/emulated/0/humanopen/models/main.gguf \
  /storage/emulated/0/Android/data/com.humanopen.humanopen/files/models/
adb shell cp /storage/emulated/0/humanopen/models/summarizer.gguf \
  /storage/emulated/0/Android/data/com.humanopen.humanopen/files/models/

# 4. Launch
adb shell monkey -p com.humanopen.humanopen -c android.intent.category.LAUNCHER 1
```

## Device Setup

Push model files to the device first:
```bash
adb push models/main.gguf /storage/emulated/0/humanopen/models/
adb push models/summarizer.gguf /storage/emulated/0/humanopen/models/
```

## Stack

- Flutter (Dart) — UI + logic
- llama.cpp — LLM inference (via `llama_flutter_android` plugin)
- SQLite — persistence
- Android SpeechRecognizer — offline STT
