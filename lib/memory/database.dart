import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class AppDatabase {
  static Database? _instance;

  static Future<Database> getInstance() async {
    if (_instance != null) return _instance!;
    final dbPath = await getDatabasesPath();
    _instance = await openDatabase(
      p.join(dbPath, 'humanopen.db'),
      version: 1,
      onCreate: _onCreate,
    );
    return _instance!;
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE matrices (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT DEFAULT '',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE sessions (
        id TEXT PRIMARY KEY,
        matrix_id TEXT NOT NULL,
        title TEXT DEFAULT '',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        archived INTEGER DEFAULT 0,
        FOREIGN KEY (matrix_id) REFERENCES matrices(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE messages (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        token_count INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (session_id) REFERENCES sessions(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE memories (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        matrix_id TEXT NOT NULL,
        summary TEXT NOT NULL,
        message_first TEXT,
        message_last TEXT,
        token_count INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (session_id) REFERENCES sessions(id),
        FOREIGN KEY (matrix_id) REFERENCES matrices(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE facts (
        id TEXT PRIMARY KEY,
        matrix_id TEXT,
        fact TEXT NOT NULL,
        category TEXT DEFAULT 'general',
        confidence REAL DEFAULT 0.5,
        status TEXT DEFAULT 'pending',
        source_msg TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (matrix_id) REFERENCES matrices(id)
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_messages_session ON messages(session_id, created_at)
    ''');
    await db.execute('''
      CREATE INDEX idx_memories_matrix ON memories(matrix_id, created_at)
    ''');
    await db.execute('''
      CREATE INDEX idx_facts_matrix ON facts(matrix_id, status)
    ''');
  }

  static Future<String> createMatrix(String name, String description) async {
    final db = await getInstance();
    final id = 'm_${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await db.insert('matrices', {
      'id': id,
      'name': name,
      'description': description,
      'created_at': now,
      'updated_at': now,
    });
    return id;
  }

  static Future<List<Map<String, dynamic>>> getMatrices() async {
    final db = await getInstance();
    return db.query('matrices', orderBy: 'updated_at DESC');
  }

  static Future<void> deleteMatrix(String id) async {
    final db = await getInstance();
    await db.delete('facts', where: 'matrix_id = ?', whereArgs: [id]);
    await db.delete('memories', where: 'matrix_id = ?', whereArgs: [id]);
    final sessions = await db.query('sessions',
        columns: ['id'], where: 'matrix_id = ?', whereArgs: [id]);
    for (final s in sessions) {
      await db.delete('messages', where: 'session_id = ?', whereArgs: [s['id']]);
    }
    await db.delete('sessions', where: 'matrix_id = ?', whereArgs: [id]);
    await db.delete('matrices', where: 'id = ?', whereArgs: [id]);
  }

  static Future<String> createSession(String matrixId, {String title = ''}) async {
    final db = await getInstance();
    final id = 's_${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await db.insert('sessions', {
      'id': id,
      'matrix_id': matrixId,
      'title': title,
      'created_at': now,
      'updated_at': now,
    });
    return id;
  }

  static Future<List<Map<String, dynamic>>> getSessions(String matrixId) async {
    final db = await getInstance();
    return db.query('sessions',
        where: 'matrix_id = ?', whereArgs: [matrixId], orderBy: 'updated_at DESC');
  }

  static Future<void> deleteSession(String id) async {
    final db = await getInstance();
    await db.delete('messages', where: 'session_id = ?', whereArgs: [id]);
    await db.delete('memories', where: 'session_id = ?', whereArgs: [id]);
    await db.delete('sessions', where: 'id = ?', whereArgs: [id]);
  }

  static Future<String> insertMessage(String sessionId, String role, String content,
      {int tokenCount = 0}) async {
    final db = await getInstance();
    final id = 'msg_${DateTime.now().millisecondsSinceEpoch}_$role';
    await db.insert('messages', {
      'id': id,
      'session_id': sessionId,
      'role': role,
      'content': content,
      'token_count': tokenCount,
      'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    });
    await db.update('sessions', {'updated_at': DateTime.now().millisecondsSinceEpoch ~/ 1000},
        where: 'id = ?', whereArgs: [sessionId]);
    return id;
  }

  static Future<List<Map<String, dynamic>>> getMessages(String sessionId) async {
    final db = await getInstance();
    return db.query('messages',
        where: 'session_id = ?',
        whereArgs: [sessionId],
        orderBy: 'created_at ASC');
  }

  static Future<int> getMessageCount(String sessionId) async {
    final db = await getInstance();
    final result = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM messages WHERE session_id = ?', [sessionId]);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  static Future<void> deleteMessagesFrom(String sessionId) async {
    final db = await getInstance();
    await db.delete('messages', where: 'session_id = ?', whereArgs: [sessionId]);
  }

  static Future<void> insertMemory(String sessionId, String matrixId, String summary,
      {String? firstMsgId, String? lastMsgId, int tokenCount = 0}) async {
    final db = await getInstance();
    final id = 'mem_${DateTime.now().millisecondsSinceEpoch}';
    await db.insert('memories', {
      'id': id,
      'session_id': sessionId,
      'matrix_id': matrixId,
      'summary': summary,
      'message_first': firstMsgId,
      'message_last': lastMsgId,
      'token_count': tokenCount,
      'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    });
  }

  static Future<List<Map<String, dynamic>>> getMemories(String matrixId) async {
    final db = await getInstance();
    return db.query('memories',
        where: 'matrix_id = ?',
        whereArgs: [matrixId],
        orderBy: 'created_at ASC');
  }

  static Future<String> insertFact(String fact, {String? matrixId, String category = 'general',
    double confidence = 0.5, String? sourceMsg}) async {
    final db = await getInstance();
    final id = 'f_${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await db.insert('facts', {
      'id': id,
      'matrix_id': matrixId,
      'fact': fact,
      'category': category,
      'confidence': confidence,
      'status': 'pending',
      'source_msg': sourceMsg,
      'created_at': now,
      'updated_at': now,
    });
    return id;
  }

  static Future<void> confirmFact(String id) async {
    final db = await getInstance();
    await db.update('facts',
        {'status': 'confirmed', 'confidence': 1.0, 'updated_at': DateTime.now().millisecondsSinceEpoch ~/ 1000},
        where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> editFact(String id, String newFact) async {
    final db = await getInstance();
    await db.update('facts',
        {'fact': newFact, 'status': 'confirmed', 'confidence': 1.0,
         'updated_at': DateTime.now().millisecondsSinceEpoch ~/ 1000},
        where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> rejectFact(String id) async {
    final db = await getInstance();
    await db.delete('facts', where: 'id = ?', whereArgs: [id]);
  }

  static Future<List<Map<String, dynamic>>> getFacts(
      {String? matrixId, String? status, String? category}) async {
    final db = await getInstance();
    final where = <String>[];
    final args = <dynamic>[];
    if (matrixId != null) { where.add('matrix_id = ?'); args.add(matrixId); }
    if (status != null) { where.add('status = ?'); args.add(status); }
    if (category != null) { where.add('category = ?'); args.add(category); }
    return db.query('facts',
        where: where.isEmpty ? null : where.join(' AND '),
        whereArgs: args.isEmpty ? null : args,
        orderBy: 'confidence DESC, updated_at DESC');
  }

  static Future<void> decayFacts() async {
    final db = await getInstance();
    await db.rawUpdate('''
      UPDATE facts SET confidence = MAX(0.01, confidence - 0.1)
      WHERE status = 'pending'
      AND updated_at < ? - 604800
    ''', [DateTime.now().millisecondsSinceEpoch ~/ 1000]);
    await db.delete('facts',
        where: 'confidence < 0.1 AND status = \'pending\'');
  }

  static Future<List<Map<String, dynamic>>> getSessionsOlderThan(int timestamp) async {
    final db = await getInstance();
    return db.query('sessions',
        where: 'updated_at < ? AND archived = 0',
        whereArgs: [timestamp]);
  }

  static Future<void> markSessionArchived(String sessionId) async {
    final db = await getInstance();
    await db.update('sessions', {'archived': 1},
        where: 'id = ?', whereArgs: [sessionId]);
  }

  static Future<Map<String, dynamic>?> getArchivedSession(String sessionId) async {
    final db = await getInstance();
    final sessions = await db.query('sessions',
        where: 'id = ? AND archived = 1',
        whereArgs: [sessionId]);
    if (sessions.isEmpty) return null;
    final memories = await db.query('memories',
        where: 'session_id = ?',
        whereArgs: [sessionId],
        orderBy: 'created_at ASC');
    return {
      'session': sessions.first,
      'memories': memories,
    };
  }

  static Future<Map<String, dynamic>> getStats() async {
    final db = await getInstance();
    final msgCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM messages')) ?? 0;
    final sessionCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM sessions')) ?? 0;
    final factCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM facts')) ?? 0;
    final memoryCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM memories')) ?? 0;
    final matrixCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM matrices')) ?? 0;
    return {
      'messages': msgCount,
      'sessions': sessionCount,
      'facts': factCount,
      'memories': memoryCount,
      'matrices': matrixCount,
    };
  }
}
