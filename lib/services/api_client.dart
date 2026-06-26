import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._();
  factory ApiClient() => _instance;
  ApiClient._();

  String _baseUrl = '';
  String _apiKey = '';

  String get baseUrl => _baseUrl;
  String get apiKey => _apiKey;

  void updateFromConfig() {
    _baseUrl = Config.instance.apiBaseUrl;
    _apiKey = Config.instance.apiKey;
  }

  Uri get _chatUrl => Uri.parse('$_baseUrl/v1/chat/completions');
  Uri get _transcriptionUrl => Uri.parse('$_baseUrl/v1/audio/transcriptions');
  Uri get _modelsUrl => Uri.parse('$_baseUrl/v1/models');
  Uri get _completionUrl => Uri.parse('$_baseUrl/v1/completions');

  Map<String, String> get _headers {
    final h = {'Content-Type': 'application/json'};
    if (_apiKey.isNotEmpty) h['Authorization'] = 'Bearer $_apiKey';
    return h;
  }

  Future<bool> checkHealth() async {
    try {
      final url = Uri.parse('$_baseUrl/health');
      final res = await http.get(url).timeout(Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> listModels() async {
    try {
      final res = await http.get(_modelsUrl, headers: _headers);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final data = body['data'] as List? ?? [];
        return data.cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    return [];
  }

  Stream<String> chatCompletion({
    required List<Map<String, dynamic>> messages,
    String model = 'humanopen-3b',
    int maxTokens = 1024,
    double temperature = 0.7,
  }) async* {
    try {
      final body = jsonEncode({
        'model': model,
        'messages': messages,
        'max_tokens': maxTokens,
        'temperature': temperature,
        'stream': true,
      });

      final request = http.Request('POST', _chatUrl)
        ..headers.addAll(_headers)
        ..body = body;

      final response = await request.send().timeout(Duration(seconds: 120));
      if (response.statusCode != 200) {
        yield 'Error: HTTP ${response.statusCode}';
        return;
      }

      await for (final chunk in response.stream.transform(utf8.decoder)) {
        for (final line in chunk.split('\n')) {
          final s = line.trim();
          if (s.startsWith('data: ')) {
            final data = s.substring(6).trim();
            if (data == '[DONE]') return;
            try {
              final json = jsonDecode(data) as Map<String, dynamic>;
              final choice = (json['choices'] as List?)?.firstOrNull;
              final delta = choice?['delta'] as Map<String, dynamic>?;
              final content = delta?['content'] as String?;
              if (content != null && content.isNotEmpty) yield content;
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      yield 'Error: $e';
    }
  }

  Stream<String> completion({
    required String prompt,
    String model = 'humanopen-3b',
    int maxTokens = 1024,
    double temperature = 0.7,
  }) async* {
    try {
      final body = jsonEncode({
        'model': model,
        'prompt': prompt,
        'max_tokens': maxTokens,
        'temperature': temperature,
        'stream': true,
      });

      final request = http.Request('POST', _completionUrl)
        ..headers.addAll(_headers)
        ..body = body;

      final response = await request.send().timeout(Duration(seconds: 120));
      if (response.statusCode != 200) {
        yield 'Error: HTTP ${response.statusCode}';
        return;
      }

      await for (final chunk in response.stream.transform(utf8.decoder)) {
        for (final line in chunk.split('\n')) {
          final s = line.trim();
          if (s.startsWith('data: ')) {
            final data = s.substring(6).trim();
            if (data == '[DONE]') return;
            try {
              final json = jsonDecode(data) as Map<String, dynamic>;
              final choice = (json['choices'] as List?)?.firstOrNull;
              final text = choice?['text'] as String?;
              if (text != null && text.isNotEmpty) yield text;
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      yield 'Error: $e';
    }
  }

  Future<String> transcribeAudio(List<int> audioBytes) async {
    try {
      final request = http.MultipartRequest('POST', _transcriptionUrl);
      if (_apiKey.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $_apiKey';
      }
      request.files.add(http.MultipartFile.fromBytes(
        'file', audioBytes, filename: 'audio.wav',
      ));
      request.fields['model'] = 'whisper-1';

      final response = await request.send().timeout(Duration(seconds: 30));
      if (response.statusCode == 200) {
        final body = await response.stream.bytesToString();
        return jsonDecode(body)['text'] as String? ?? '';
      }
    } catch (_) {}
    return '';
  }
}
