import 'dart:async';
import 'package:humanopen/memory/database.dart' show AppDatabase;

class FactManager {
  Future<List<Map<String, String>>> extractFacts(
      String userMessage, String assistantResponse) async {
    final facts = <Map<String, String>>[];
    final combined = '$userMessage\n$assistantResponse';

    final preferencePatterns = [
      RegExp(r'I (?:like|love|prefer|hate|dislike|enjoy|want|need|have) (.+?)[\.!]',
        caseSensitive: false),
      RegExp(r'my (?:name|age|job|work|hobby|interest|goal|project) (?:is|are) (.+?)[\.!]',
        caseSensitive: false),
      RegExp(r'I (?:work|live|study|use|run) (.+?)[\.!]',
        caseSensitive: false),
    ];

    for (final pattern in preferencePatterns) {
      final matches = pattern.allMatches(combined);
      for (final m in matches) {
        facts.add({
          'fact': m.group(1)!.trim(),
          'category': 'preference',
        });
      }
    }

    return facts;
  }

  Future<List<String>> storeCandidateFacts(
      String userMessage, String assistantResponse, String? matrixId) async {
    final candidates = await extractFacts(userMessage, assistantResponse);
    final ids = <String>[];
    for (final f in candidates) {
      final id = await AppDatabase.insertFact(
        f['fact']!,
        matrixId: matrixId,
        category: f['category']!,
      );
      ids.add(id);
    }
    return ids;
  }

  Future<String> buildFactsSection({String? matrixId}) async {
    final facts = await AppDatabase.getFacts(matrixId: matrixId, status: 'confirmed');
    if (facts.isEmpty) return '';
    return facts.map((f) => '- ${f['fact']}').join('\n');
  }

  Future<void> runDecayCycle() async {
    await AppDatabase.decayFacts();
  }
}
