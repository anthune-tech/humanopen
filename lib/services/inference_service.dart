import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
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
import 'package:humanopen/services/tool_registry.dart';
import 'package:llama_flutter_android/llama_flutter_android.dart';

class InferenceService {
  final InferenceEngine _engine;
  final MemoryManager _memoryManager;
  final FactManager _factManager;
  late final Summarizer _summarizer;
  late final Archiver _archiver;
  late final FactExtractor _factExtractor;

  final ToolRegistry toolRegistry;

  String? _currentModelName;
  bool _isModelLoaded = false;
  final DateTime _startTime = DateTime.now();

  String _lastSessionId = '';

  InferenceService(this._engine)
      : _memoryManager = MemoryManager(),
        _factManager = FactManager(),
        toolRegistry = ToolRegistry.createDefault() {
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

  /// Parses tool calls from model response.
  /// First tries tagged format: <|tool_call|> JSON <|/tool_call|>
  /// Then tries bare JSON with name + arguments.
  List<ToolCall> _parseToolCalls(String response) {
    final calls = <ToolCall>[];
    
    // Try tagged format first
    final pattern = RegExp(
      r'<\|tool_call\|>\s*(\{.*?\})\s*<\|/?tool_call\|>',
      dotAll: true,
    );
    for (final match in pattern.allMatches(response)) {
      try {
        final json = jsonDecode(match.group(1)!) as Map<String, dynamic>;
        calls.add(ToolCall.fromJson(json));
      } catch (_) {}
    }
    
    if (calls.isNotEmpty) return calls;
    
    // Try bare JSON response (Dolphin3.0 native format)
    try {
      final trimmed = response.trim();
      if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
        final json = jsonDecode(trimmed) as Map<String, dynamic>;
        if (json.containsKey('name') && json.containsKey('arguments')) {
          calls.add(ToolCall.fromJson(json));
        }
      }
    } catch (_) {}
    
    return calls;
  }

  /// Strips tool call blocks from text for clean user display.
  String _stripToolCalls(String text) {
    return text
        .replaceAll(RegExp(r'<\|/?tool_call\|>', dotAll: true), '')
        .trim();
  }

  /// Proactively gathers directory listings for file-related queries.
  /// The 3B model cannot reliably call tools — this gives it real data.
  Future<String> _enrichWithFileContext(String userMessage) async {
    final lower = userMessage.toLowerCase();
    final fileKeywords = ['file', 'folder', 'directory', 'download', 'picture', 'photo', 'image', 'document', 'saved', 'list'];
    if (!fileKeywords.any((k) => lower.contains(k))) return userMessage;

    const channel = MethodChannel('com.humanopen/file_list');
    final dirs = [
      '/storage/emulated/0/Download',
      '/storage/emulated/0/Pictures',
      '/storage/emulated/0/DCIM/Camera',
      '/storage/emulated/0/Documents',
    ];

    final context = StringBuffer();
    int dirCount = 0;
    for (final dirPath in dirs) {
      try {
        final output = await channel.invokeMethod<String>('listFiles', {'path': dirPath});
        if (output == null || output.trim().isEmpty) continue;
        final lines = output.trim().split('\n');
        if (lines.isEmpty) continue;
        dirCount++;
        context.writeln('Directory $dirPath contains:');
        for (final line in lines) {
          if (line.startsWith('total ')) continue;
          context.writeln('- $line');
        }
      } catch (e) {
        print('[enrich] Error reading $dirPath: $e');
      }
    }
    if (dirCount == 0) return userMessage;
    final info = context.toString().trim();
    print('[enrich] Scanned $dirCount dirs');
    return 'User question: "$userMessage"\n\nHere are the actual files currently on device. ONLY use these real listings — do NOT invent files:\n$info\n\nNow answer the user question about files based ONLY on the listings above.';
  }

  Stream<String> generate(String matrixId, String sessionId, String userMessage) async* {
    final systemPrompt = _buildSystemPrompt(matrixId, sessionId);

    // Proactively inject file listings so the 3B model has real data
    final enriched = await _enrichWithFileContext(userMessage);

    // Save original user message to DB (without file context noise)
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
        {'role': 'user', 'content': enriched},
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

    // Local model with tool support
    await for (final token in _generateWithTools(matrixId, sessionId, systemPrompt, enriched)) {
      yield token;
    }
  }

  /// Internal generation loop with tool calling support.
  /// Tool calls and results are hidden — no trace in DB or UI.
  /// Only the final clean assistant response is stored and yielded.
  Stream<String> _generateWithTools(
    String matrixId,
    String sessionId,
    String systemPrompt,
    String userMessage,
  ) async* {
    const maxToolIterations = 5;

    // First iteration: build prompt from DB (system + user message)
    var currentMessages = <ChatMessage>[];
    String? finalResponse;

    for (int iter = 0; iter < maxToolIterations; iter++) {
      if (iter == 0) {
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

        currentMessages = buildResult.messages.map((m) =>
            ChatMessage(role: m['role']!, content: m['content']!)).toList();
      }

      await _engine.clearContext();

      final iterBuffer = StringBuffer();
      await for (final token in _engine.generateChat(currentMessages, temperature: Config.instance.temperature)) {
        iterBuffer.write(token);
      }

      final rawResponse = iterBuffer.toString();
      final toolCalls = _parseToolCalls(rawResponse);
      final cleanResponse = _stripToolCalls(rawResponse);

      if (toolCalls.isEmpty) {
        finalResponse = cleanResponse;
        if (finalResponse.isNotEmpty) {
          await AppDatabase.insertMessage(sessionId, 'assistant', finalResponse);
        }
        break;
      }

      // Execute tools silently
      for (final call in toolCalls) {
        final result = await toolRegistry.execute(call);
        final resultText = result.error ?? '${result.result}';
        // Append tool result as a system note so the model sees it
        currentMessages.addAll([
          ChatMessage(role: 'assistant', content: rawResponse),
          ChatMessage(role: 'system', content: '[Tool ${call.name} result: $resultText]'),
        ]);
      }
    }

    if (finalResponse != null && finalResponse.isNotEmpty) {
      for (int i = 0; i < finalResponse.length; i++) {
        yield finalResponse[i];
      }
    }
  }

  Stream<String> generateCompletion(String prompt) async* {
    await for (final token in _engine.generate(prompt)) {
      yield token;
    }
  }

  String _buildSystemPrompt(String matrixId, String sessionId) {
    return '''
You are humanopen, a private AI assistant with persistent memory.
Be concise, honest, and direct. Never make up information.

Today: ${DateTime.now().toIso8601String().split('T')[0]}

Android paths: /storage/emulated/0/ (alias /sdcard/)
Pictures=/storage/emulated/0/Pictures/
Camera=/storage/emulated/0/DCIM/Camera/
Download=/storage/emulated/0/Download/
Documents=/storage/emulated/0/Documents/
Use list_files tool to explore dirs before accessing files.
${toolRegistry.systemPromptBlock}
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
