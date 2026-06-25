import 'dart:async';
import 'package:humanopen/memory/database.dart' show AppDatabase;
import 'package:humanopen/memory/summarizer.dart';

class Archiver {
  final Summarizer _summarizer;
  final Duration _archiveAge;

  Archiver(this._summarizer, {Duration? archiveAge})
      : _archiveAge = archiveAge ?? Duration(days: 90);

  Future<void> runArchiveCycle() async {
    final cutoff = DateTime.now().subtract(_archiveAge).millisecondsSinceEpoch ~/ 1000;
    final oldSessions = await AppDatabase.getSessionsOlderThan(cutoff);

    for (final session in oldSessions) {
      final sessionId = session['id'] as String;
      final matrixId = session['matrix_id'] as String;
      final messages = await AppDatabase.getMessages(sessionId);

      if (messages.isEmpty) {
        await AppDatabase.markSessionArchived(sessionId);
        continue;
      }

      if (_summarizer.isLoaded) {
        try {
          final summary = await _summarizer.summarize(messages);
          await AppDatabase.insertMemory(
            sessionId, matrixId, summary,
            firstMsgId: messages.first['id'] as String?,
            lastMsgId: messages.last['id'] as String?,
            tokenCount: (summary.length / 3.5).ceil(),
          );
        } catch (_) {
          final fallback = 'Session with ${messages.length} messages. Topics: ${messages.first['content'].toString().substring(0, 100)}...';
          await AppDatabase.insertMemory(sessionId, matrixId, fallback);
        }
      } else {
        final fallback = 'Session with ${messages.length} messages. Topics: ${messages.first['content'].toString().substring(0, 100)}...';
        await AppDatabase.insertMemory(sessionId, matrixId, fallback);
      }

      await AppDatabase.deleteMessagesFrom(sessionId);
      await AppDatabase.markSessionArchived(sessionId);
    }
  }

  Future<void> archiveSession(String sessionId, String matrixId) async {
    final messages = await AppDatabase.getMessages(sessionId);
    if (messages.isEmpty) return;

    if (_summarizer.isLoaded) {
      try {
        final summary = await _summarizer.summarize(messages);
        await AppDatabase.insertMemory(sessionId, matrixId, summary);
      } catch (_) {
        await AppDatabase.insertMemory(sessionId, matrixId,
            'Archived session with ${messages.length} messages.');
      }
    } else {
      await AppDatabase.insertMemory(sessionId, matrixId,
          'Archived session with ${messages.length} messages.');
    }

    await AppDatabase.deleteMessagesFrom(sessionId);
    await AppDatabase.markSessionArchived(sessionId);
  }
}
