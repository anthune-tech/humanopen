import 'package:humanopen/memory/database.dart';

class MemoryManager {
  final int maxContextTokens;
  final int reservedForGeneration;

  MemoryManager({
    this.maxContextTokens = 32768,
    this.reservedForGeneration = 2048,
  });

  int get _usableTokens => maxContextTokens - reservedForGeneration;

  int estimateTokens(String text) {
    if (text.trim().isEmpty) return 0;
    return (text.length / 3.5).ceil();
  }

  int estimateTokensForList(List<String> texts) {
    final total = texts.fold<int>(0, (sum, t) => sum + t.length);
    return (total / 3.5).ceil();
  }

  Future<BuildResult> buildPrompt({
    required String matrixId,
    required String sessionId,
    required String systemPrompt,
    required String userMessage,
  }) async {
    final messages = await AppDatabase.getMessages(sessionId);
    final memories = await AppDatabase.getMemories(matrixId);
    final facts = await AppDatabase.getFacts(matrixId: matrixId, status: 'confirmed');

    final factLines = facts.map((f) => '- ${f['fact']}').join('\n');
    final memoryLines = memories.map((m) => '- ${m['summary']}').join('\n');

    final systemParts = <String>[systemPrompt];
    if (memoryLines.isNotEmpty) {
      systemParts.add('\n=== ARCHIVED MEMORIES ===\n$memoryLines');
    }
    if (factLines.isNotEmpty) {
      systemParts.add('\n=== KNOWN FACTS ===\n$factLines');
    }
    final systemText = systemParts.join('\n');
    final systemTokens = estimateTokens(systemText);

    int totalTokens = systemTokens;
    final promptMessages = <Map<String, String>>[];

    promptMessages.add({'role': 'system', 'content': systemText});

    bool needsSummarization = false;

    for (final msg in messages) {
      final msgTokens = (msg['token_count'] as int?) ?? estimateTokens(msg['content'] as String);
      if (totalTokens + msgTokens > _usableTokens) {
        needsSummarization = true;
        break;
      }
      promptMessages.add({
        'role': msg['role'] as String,
        'content': msg['content'] as String,
      });
      totalTokens += msgTokens;
    }

    final userTokens = estimateTokens(userMessage);
    if (totalTokens + userTokens > _usableTokens) {
      needsSummarization = true;
    }

    promptMessages.add({'role': 'user', 'content': userMessage});

    return BuildResult(
      messages: promptMessages,
      needsSummarization: needsSummarization,
      tokenCount: totalTokens + userTokens,
      systemTokens: systemTokens,
    );
  }

  Future<String> summarizeMessages(List<Map<String, dynamic>> messages) async {
    final content = messages.map((m) =>
        '${m['role']}: ${m['content']}').join('\n');
    if (content.length > 2000) {
      return content.substring(0, 2000) + '...[truncated]';
    }
    return content;
  }
}

class BuildResult {
  final List<Map<String, String>> messages;
  final bool needsSummarization;
  final int tokenCount;
  final int systemTokens;

  BuildResult({
    required this.messages,
    required this.needsSummarization,
    required this.tokenCount,
    required this.systemTokens,
  });
}
