import 'dart:async';
import 'package:humanopen/platform/inference_engine.dart';
import 'package:humanopen/memory/database.dart' show AppDatabase;

class FactExtractor {
  final InferenceEngine _engine;

  FactExtractor(this._engine);

  Future<List<Map<String, String>>> extract(
      String userMessage, String assistantResponse) async {
    final prompt = '''
Extract personal facts about the user from this conversation exchange.
Focus on: preferences, habits, technical details, personal info, goals.

User: $userMessage
Assistant: $assistantResponse

Return ONLY a JSON array of objects, each with "fact" and "category" keys.
Categories: preference, personal_info, technical, habit, goal, opinion
If no facts found, return empty array: []
''';

    final buffer = StringBuffer();
    await for (final token in _engine.generate(prompt, maxTokens: 256)) {
      buffer.write(token);
    }

    final result = buffer.toString().trim();
    return _parseResult(result);
  }

  List<Map<String, String>> _parseResult(String text) {
    try {
      final start = text.indexOf('[');
      final end = text.lastIndexOf(']');
      if (start >= 0 && end > start) {
        final json = text.substring(start, end + 1);
        final parsed = json as List<dynamic>;
        return parsed.map((e) => {
          'fact': e['fact'] as String,
          'category': e['category'] as String? ?? 'general',
        }).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<String>> storeFacts(
      String userId, String userMsg, String assistantMsg, String? matrixId) async {
    final facts = await extract(userMsg, assistantMsg);
    final ids = <String>[];
    for (final f in facts) {
      final id = await AppDatabase.insertFact(
        f['fact']!,
        matrixId: matrixId,
        category: f['category']!,
      );
      ids.add(id);
    }
    return ids;
  }
}
