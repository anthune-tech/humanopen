#!/bin/bash
# humanopen model setup script
# Usage: ./push_models.sh <path-to-3b-gguf> [path-to-0.5b-gguf]

MODEL_3B="$1"
MODEL_0_5B="$2"

PACKAGE="com.humanopen.humanopen"
MODEL_DIR="/storage/emulated/0/Android/data/${PACKAGE}/files/models"

if [ -z "$MODEL_3B" ]; then
    echo "Usage: $0 <path-to-3b-gguf> [path-to-0.5b-gguf]"
    echo ""
    echo "Recommended models:"
    echo "  3B: Dolphin3.0-Qwen2.5-3b-Q4_K_M.gguf (bartowski/Dolphin3.0-Qwen2.5-3b-GGUF)"
    echo "  0.5B: qwen2.5-0.5b-instruct-q4_k_m.gguf (Qwen/Qwen2.5-0.5B-Instruct-GGUF)"
    echo ""
    echo "Download:"
    echo "  hf download bartowski/Dolphin3.0-Qwen2.5-3b-GGUF Dolphin3.0-Qwen2.5-3b-Q4_K_M.gguf --local-dir ./"
    echo "  hf download Qwen/Qwen2.5-0.5B-Instruct-GGUF qwen2.5-0.5b-instruct-q4_k_m.gguf --local-dir ./"
    exit 1
fi

echo "Creating model directory..."
adb shell mkdir -p "$MODEL_DIR"

echo "Pushing main model (3B)..."
adb push "$MODEL_3B" "$MODEL_DIR/main.gguf"

if [ -n "$MODEL_0_5B" ]; then
    echo "Pushing summarizer model (0.5B)..."
    adb push "$MODEL_0_5B" "$MODEL_DIR/summarizer.gguf"
fi

echo "Updating config..."
CONFIG_PATH="/storage/emulated/0/Android/data/${PACKAGE}/files/humanopen/config.json"
adb shell "mkdir -p \$(dirname $CONFIG_PATH)"
adb shell "cat > $CONFIG_PATH << 'EOF'
{\"main_model\":\"${MODEL_DIR}/main.gguf\",\"main_model_name\":\"humanopen-3b\",\"summarizer_model\":\"${MODEL_DIR}/summarizer.gguf\",\"gpu_layers\":99,\"context_size\":32768,\"server_port\":8080,\"auto_start\":true,\"wifi_first\":true}
EOF"

echo "Force-stopping app to trigger reload..."
adb shell am force-stop "${PACKAGE}"

echo "Starting app..."
adb shell monkey -p "${PACKAGE}" -c android.intent.category.LAUNCHER 1 2>/dev/null

echo "Done! Waiting for model load..."
sleep 30
adb shell "echo -e 'GET /health HTTP/1.0\r\n\r\n' | nc -w 3 127.0.0.1 8080" 2>/dev/null | tail -1
