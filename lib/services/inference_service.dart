import 'dart:async';
import 'package:humanopen/memory/database.dart' show AppDatabase;
import 'package:humanopen/memory/memory_manager.dart';
import 'package:humanopen/memory/fact_manager.dart';
import 'package:humanopen/memory/fact_extractor.dart';
import 'package:humanopen/memory/archiver.dart';
import 'package:humanopen/memory/summarizer.dart';
import 'package:humanopen/memory/matrix_detector.dart';
import 'package:humanopen/platform/inference_engine.dart';
import 'package:humanopen/services/api_client.dart';
import 'package:humanopen/services/config.dart';
import 'package:llama_flutter_android/llama_flutter_android.dart';

class InferenceService {
  final InferenceEngine _engine;
  final MemoryManager _memoryManager;
  final FactManager _factManager;
  late final Summarizer _summarizer;
  late final Archiver _archiver;
  late final FactExtractor _factExtractor;

  String? _currentModelName;
  bool _isModelLoaded = false;
  final DateTime _startTime = DateTime.now();

  String _lastSessionId = '';

  InferenceService(this._engine)
      : _memoryManager = MemoryManager(),
        _factManager = FactManager() {
    _summarizer = Summarizer(_engine);
    _archiver = Archiver(_summarizer);
    _factExtractor = FactExtractor(_engine);
  }

  bool get isModelLoaded => _isModelLoaded;
  String? get currentModelName => _currentModelName;
  String get computeMode => _engine.computeMode;
  int get uptime => DateTime.now().difference(_startTime).inSeconds;

  Future<void> loadModel(String modelPath, {String modelName = 'humanopen-3b', int gpuLayers = 99, int contextSize = 32768, int threads = 8}) async {
    await _engine.loadMainModel(modelPath, gpuLayers: gpuLayers, contextSize: contextSize, threads: threads);
    _isModelLoaded = true;
    _currentModelName = modelName;
  }

  Future<void> loadSummarizer(String modelPath) async {
    await _summarizer.loadModel(modelPath);
  }

  Future<Map<String, String>> getOrCreateSession(List<dynamic> messages) async {
    final userMsg = messages.isNotEmpty ? messages.last['content'] as String : '';
    final matrices = await AppDatabase.getMatrices();
    final matrixNames = matrices.map((m) => m['name'] as String).toList();
    final topic = MatrixDetector.detect(userMsg, matrixNames);

    String matrixId;
    final existingMatrix = matrices.where((m) => m['name'] == topic).toList();

    if (existingMatrix.isNotEmpty) {
      matrixId = existingMatrix.first['id'] as String;
    } else {
      matrixId = await AppDatabase.createMatrix(topic, 'Auto-created for $topic discussions');
    }

    final sessions = await AppDatabase.getSessions(matrixId);
    String sessionId;
    if (sessions.isEmpty) {
      sessionId = await AppDatabase.createSession(matrixId, title: topic);
    } else {
      sessionId = sessions.first['id'] as String;
    }

    _lastSessionId = sessionId;

    return {
      'matrix_id': matrixId,
      'session_id': sessionId,
    };
  }

  Stream<String> generate(String matrixId, String sessionId, String userMessage) async* {
    final systemPrompt = _buildSystemPrompt(matrixId, sessionId);

    await AppDatabase.insertMessage(sessionId, 'user', userMessage);

    if (!Config.instance.useLocalModel) {
      final client = ApiClient();
      client.updateFromConfig();
      final msgs = [
        {'role': 'system', 'content': systemPrompt},
        ...(await AppDatabase.getMessages(sessionId)).map((m) => {
          'role': m['role'] as String,
          'content': m['content'] as String,
        }),
      ];

      final buffer = StringBuffer();
      await for (final token in client.chatCompletion(messages: msgs, temperature: Config.instance.temperature)) {
        buffer.write(token);
        yield token;
      }

      final response = buffer.toString();
      await AppDatabase.insertMessage(sessionId, 'assistant', response);
      return;
    }

    final buildResult = await _memoryManager.buildPrompt(
      matrixId: matrixId,
      sessionId: sessionId,
      systemPrompt: systemPrompt,
      userMessage: userMessage,
    );

    if (buildResult.needsSummarization) {
      final messages = await AppDatabase.getMessages(sessionId);
      if (messages.isNotEmpty) {
        final half = messages.length ~/ 2;
        if (half > 0) {
          final toSummarize = messages.sublist(0, half);
          final summary = await _summarizer.summarize(toSummarize);
          await AppDatabase.insertMemory(sessionId, matrixId, summary);
          await AppDatabase.deleteMessagesFrom(sessionId);
        }
      }
    }

    final llmMessages = buildResult.messages.map((m) =>
        ChatMessage(role: m['role']!, content: m['content']!)).toList();

    final buffer = StringBuffer();
    await for (final token in _engine.generateChat(llmMessages, temperature: Config.instance.temperature)) {
      buffer.write(token);
      yield token;
    }

    final response = buffer.toString();
    await AppDatabase.insertMessage(sessionId, 'assistant', response);
  }

  Stream<String> generateCompletion(String prompt) async* {
    await for (final token in _engine.generate(prompt)) {
      yield token;
    }
  }

  String _buildSystemPrompt(String matrixId, String sessionId) {
    return '''
You are humanopen, a private AI assistant with persistent memory.
You remember everything the user has told you across all conversations.
Be concise, honest, and direct. Never make up information.
The user is your only user - all data is private and personal to them.

Today's date: ${DateTime.now().toIso8601String().split('T')[0]}
''';
  }

  Future<List<String>> extractFacts({String? matrixId}) async {
    try {
      final messages = await AppDatabase.getMessages(_lastSessionId);
      if (messages.length < 2) return [];

      final userMsg = messages.where((m) => m['role'] == 'user').last['content'] as String;
      final assistantMsg = messages.where((m) => m['role'] == 'assistant').last['content'] as String;

      return await _factExtractor.storeFacts('user', userMsg, assistantMsg, matrixId);
    } catch (_) {
      return [];
    }
  }

  Future<void> confirmFact(String id) async => AppDatabase.confirmFact(id);
  Future<void> editFact(String id, String fact) async => AppDatabase.editFact(id, fact);
  Future<void> deleteFact(String id) async => AppDatabase.rejectFact(id);

  Future<List<Map<String, dynamic>>> listFacts({String? matrixId, String? status}) async {
    return AppDatabase.getFacts(matrixId: matrixId, status: status);
  }

  Future<Map<String, dynamic>> getStats() async {
    final dbStats = await AppDatabase.getStats();
    return {
      ...dbStats,
      'uptime': uptime,
      'model_loaded': _isModelLoaded,
      'model': _currentModelName,
    };
  }

  Future<void> runMaintenance() async {
    await _factManager.runDecayCycle();
    await _archiver.runArchiveCycle();
  }

  Future<void> dispose() async {
    await _engine.dispose();
  }
}
