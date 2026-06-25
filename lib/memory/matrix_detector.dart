class MatrixDetector {
  static const _topicKeywords = {
    'tech': ['code', 'programming', 'bug', 'github', 'flutter', 'dart', 'python',
             'api', 'server', 'database', 'linux', 'terminal', 'app', 'software',
             'deploy', 'config', 'docker', 'git', 'android', 'ios'],
    'work': ['meeting', 'deadline', 'project', 'client', 'colleague', 'manager',
             'report', 'email', 'presentation', 'budget', 'schedule', 'task',
             'milestone', 'sprint', 'standup'],
    'personal': ['family', 'friend', 'weekend', 'hobby', 'travel', 'health',
                 'food', 'fitness', 'music', 'movie', 'book', 'game',
                 'relationship', 'feeling', 'thought'],
    'research': ['paper', 'research', 'study', 'experiment', 'data', 'analysis',
                 'hypothesis', 'theory', 'algorithm', 'model', 'training',
                 'benchmark', 'compare', 'result', 'accuracy'],
    'planning': ['plan', 'goal', 'roadmap', 'next', 'future', 'strategy',
                 'priority', 'timeline', 'phase', 'iteration', 'version',
                 'release', 'update', 'improve'],
  };

  static String detect(String message, List<String> existingMatrixNames) {
    final text = message.toLowerCase();
    final scores = <String, int>{};

    for (final entry in _topicKeywords.entries) {
      for (final keyword in entry.value) {
        if (text.contains(keyword)) {
          scores[entry.key] = (scores[entry.key] ?? 0) + 1;
        }
      }
    }

    if (scores.isEmpty) {
      return existingMatrixNames.isNotEmpty ? existingMatrixNames.first : 'general';
    }

    final best = scores.entries.reduce((a, b) => a.value > b.value ? a : b);
    return best.key;
  }
}
