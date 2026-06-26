import 'dart:async';
import 'package:llama_flutter_android/llama_flutter_android.dart';

class InferenceEngine {
  LlamaController? _mainController;
  LlamaController? _summarizerController;
  bool _mainLoaded = false;
  bool _summarizerLoaded = false;
  String? _mainModelPath;

  int _mainGpuLayers = 0;

  bool get isMainLoaded => _mainLoaded;
  String get computeMode => _mainGpuLayers > 0 ? 'GPU' : 'CPU';
  bool get isSummarizerLoaded => _summarizerLoaded;
  bool get isGenerating => _mainController?.isGenerating ?? false;

  Future<GpuInfo> detectGpu() async {
    final ctrl = LlamaController();
    final info = await ctrl.detectGpu();
    return info;
  }

  Future<void> loadMainModel(String modelPath, {int gpuLayers = 99, int contextSize = 32768, int threads = 8}) async {
    if (_mainLoaded) return;

    if (gpuLayers > 0) {
      final tempCtrl = LlamaController();
      try {
        await tempCtrl.loadModel(
          modelPath: modelPath,
          threads: threads,
          contextSize: contextSize,
          gpuLayers: gpuLayers,
        );
        _mainController = tempCtrl;
        _mainLoaded = true;
        _mainModelPath = modelPath;
        _mainGpuLayers = gpuLayers;
        return;
      } catch (_) {
        await tempCtrl.dispose();
      }
    }

    _mainController = LlamaController();
    await _mainController!.loadModel(
      modelPath: modelPath,
      threads: threads,
      contextSize: contextSize,
      gpuLayers: 0,
    );
    _mainLoaded = true;
    _mainModelPath = modelPath;
    _mainGpuLayers = 0;
  }

  Future<void> unloadMainModel() async {
    if (_mainController != null) {
      await _mainController!.dispose();
      _mainController = null;
    }
    _mainLoaded = false;
    _mainModelPath = null;
  }

  Future<void> loadSummarizerModel(String modelPath) async {
    if (_summarizerLoaded) return;
    _summarizerController = LlamaController();
    try {
      await _summarizerController!.loadModel(
        modelPath: modelPath,
        threads: 2,
        contextSize: 2048,
        gpuLayers: 0,
      );
      _summarizerLoaded = true;
    } catch (_) {
      _summarizerController?.dispose();
      _summarizerController = null;
      rethrow;
    }
  }

  Future<void> unloadSummarizerModel() async {
    if (_summarizerController != null) {
      await _summarizerController!.dispose();
      _summarizerController = null;
    }
    _summarizerLoaded = false;
  }

  Future<void> reloadMainModel() async {
    if (_mainModelPath != null && !_mainLoaded) {
      await loadMainModel(_mainModelPath!, gpuLayers: _mainGpuLayers);
    }
  }

  Stream<String> generate(String prompt, {int maxTokens = 1024, double temperature = 0.7}) {
    if (_mainController == null) {
      return Stream.error(Exception('Main model not loaded'));
    }
    return _mainController!.generate(
      prompt: prompt,
      maxTokens: maxTokens,
      temperature: temperature,
      topP: 0.9,
      topK: 40,
      repeatPenalty: 1.1,
    );
  }

  Stream<String> generateChat(List<ChatMessage> messages, {int maxTokens = 1024, double temperature = 0.7}) {
    if (_mainController == null) {
      return Stream.error(Exception('Main model not loaded'));
    }
    return _mainController!.generateChat(
      messages: messages,
      maxTokens: maxTokens,
      temperature: temperature,
      topP: 0.9,
    );
  }

  Stream<String> summarize(String prompt) {
    if (_summarizerController == null) {
      return Stream.error(Exception('Summarizer model not loaded'));
    }
    return _summarizerController!.generate(
      prompt: prompt,
      maxTokens: 256,
      temperature: 0.3,
      topP: 0.9,
      topK: 20,
      repeatPenalty: 1.0,
    );
  }

  Future<void> stop() async {
    await _mainController?.stop();
    await _summarizerController?.stop();
  }

  Future<void> dispose() async {
    await unloadMainModel();
    await unloadSummarizerModel();
  }

  Future<void> clearContext() async {
    await _mainController?.clearContext();
  }
}
