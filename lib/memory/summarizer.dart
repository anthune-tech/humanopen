import 'dart:async';
import 'package:humanopen/platform/inference_engine.dart';

class Summarizer {
  final InferenceEngine _engine;
  bool _loaded = false;

  Summarizer(this._engine);

  bool get isLoaded => _loaded;

  Future<void> loadModel(String modelPath) async {
    if (!_loaded) {
      await _engine.loadSummarizerModel(modelPath);
      _loaded = true;
    }
  }

  Future<void> unload() async {
    if (_loaded) {
      await _engine.unloadSummarizerModel();
      _loaded = false;
    }
  }

  Future<String> summarize(List<Map<String, dynamic>> messages) async {
    final text = messages.map((m) =>
        '${m['role']}: ${m['content']}').join('\n\n');

    final prompt = '''
Summarize the following conversation in 2-3 sentences. Capture key topics, decisions, and user preferences mentioned.

Conversation:
$text

Summary:
''';

    final buffer = StringBuffer();
    await for (final token in _engine.summarize(prompt)) {
      buffer.write(token);
    }
    return buffer.toString().trim();
  }
}
