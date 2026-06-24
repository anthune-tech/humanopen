import 'dart:async';
import 'package:flutter/material.dart';
import 'package:humanopen/memory/database.dart' show AppDatabase;
import 'package:humanopen/services/inference_service.dart';
import 'package:humanopen/services/stt_service.dart';
import 'package:humanopen/ui/gradient_background.dart';

class MiniChat extends StatefulWidget {
  final InferenceService inferenceService;
  final String? initialMatrixId;
  final String? initialSessionId;
  final String? initialTopic;

  const MiniChat({
    super.key,
    required this.inferenceService,
    this.initialMatrixId,
    this.initialSessionId,
    this.initialTopic,
  });

  @override
  State<MiniChat> createState() => _MiniChatState();
}

class _MiniChatState extends State<MiniChat> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _messages = <Map<String, String>>[];
  final _sttService = SttService();
  bool _isGenerating = false;
  bool _isListening = false;
  bool _loading = true;
  AiState _aiState = AiState.idle;
  StreamSubscription? _generationSub;

  String _currentMatrixId = '';
  String _currentSessionId = '';
  String _currentTopic = 'general';
  List<Map<String, dynamic>> _matrices = [];
  Map<String, List<Map<String, dynamic>>> _sessions = {};

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _generationSub?.cancel();
    _sttService.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    try {
      final matrices = await AppDatabase.getMatrices();
      _matrices = matrices;
      for (final m in matrices) {
        final sessions = await AppDatabase.getSessions(m['id'] as String);
        _sessions[m['id'] as String] = sessions;
      }

      if (widget.initialSessionId != null && widget.initialSessionId!.isNotEmpty) {
        _currentMatrixId = widget.initialMatrixId ?? '';
        _currentSessionId = widget.initialSessionId!;
        _currentTopic = widget.initialTopic ?? 'general';
        final msgs = await AppDatabase.getMessages(_currentSessionId);
        for (final m in msgs) {
          _messages.add({
            'role': m['role'] as String,
            'content': m['content'] as String,
          });
        }
      } else if (matrices.isNotEmpty) {
        final first = matrices.first;
        _currentMatrixId = first['id'] as String;
        _currentTopic = first['name'] as String;
        final sessions = _sessions[_currentMatrixId] ?? [];
        if (sessions.isNotEmpty) {
          _currentSessionId = sessions.first['id'] as String;
          final msgs = await AppDatabase.getMessages(_currentSessionId);
          for (final m in msgs) {
            _messages.add({
              'role': m['role'] as String,
              'content': m['content'] as String,
            });
          }
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _switchTopic(String matrixId) async {
    final sessions = _sessions[matrixId] ?? [];
    final sessionId = sessions.isNotEmpty ? sessions.first['id'] as String : '';
    final topic = _matrices.firstWhere((m) => m['id'] == matrixId)['name'] as String;

    _messages.clear();
    _currentMatrixId = matrixId;
    _currentSessionId = sessionId;
    _currentTopic = topic;

    if (sessionId.isNotEmpty) {
      try {
        final msgs = await AppDatabase.getMessages(sessionId);
        for (final m in msgs) {
          _messages.add({
            'role': m['role'] as String,
            'content': m['content'] as String,
          });
        }
      } catch (_) {}
    }
    if (mounted) setState(() {});
  }

  void _startListening() async {
    setState(() => _isListening = true);
    final text = await _sttService.listenOnce();
    if (mounted) {
      setState(() => _isListening = false);
      if (text.isNotEmpty) {
        _controller.text = text;
        _controller.selection = TextSelection.fromPosition(
          TextPosition(offset: text.length),
        );
      }
    }
  }

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isGenerating) return;

    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _isGenerating = true;
      _aiState = AiState.generating;
    });
    _controller.clear();
    _scrollDown();

    final buffer = StringBuffer();
    final sessionInfo = await widget.inferenceService.getOrCreateSession([
      {'role': 'user', 'content': text}
    ]);

    _currentMatrixId = sessionInfo['matrix_id']!;
    _currentSessionId = sessionInfo['session_id']!;
    _currentTopic = (await AppDatabase.getMatrices())
        .firstWhere((m) => m['id'] == _currentMatrixId)['name'] as String;

    _generationSub = widget.inferenceService
        .generate(_currentMatrixId, _currentSessionId, text)
        .listen(
      (token) {
        buffer.write(token);
        setState(() {
          if (_messages.isNotEmpty &&
              _messages.last['role'] == 'assistant') {
            _messages.last['content'] = buffer.toString();
          } else {
            _messages
                .add({'role': 'assistant', 'content': buffer.toString()});
          }
        });
        _scrollDown();
      },
      onDone: () {
        setState(() {
          _isGenerating = false;
          _aiState = AiState.idle;
        });
      },
      onError: (_) {
        setState(() {
          _isGenerating = false;
          _aiState = AiState.error;
        });
      },
    );

    _refreshMatrices();
  }

  Future<void> _refreshMatrices() async {
    try {
      final matrices = await AppDatabase.getMatrices();
      for (final m in matrices) {
        final sessions = await AppDatabase.getSessions(m['id'] as String);
        _sessions[m['id'] as String] = sessions;
      }
      if (mounted) setState(() => _matrices = matrices);
    } catch (_) {}
  }

  void _scrollDown() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      aiState: _aiState,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: _loading
              ? Text('Loading...',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6), fontSize: 14))
              : GestureDetector(
                  onTap: _showTopicPicker,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          _currentTopic,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 14,
                            letterSpacing: 2,
                            fontWeight: FontWeight.w300,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(Icons.arrow_drop_down,
                          color: Colors.white.withValues(alpha: 0.4), size: 18),
                    ],
                  ),
                ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back,
                color: Colors.white.withValues(alpha: 0.6)),
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            if (_messages.length > 2 && _currentSessionId.isNotEmpty)
              IconButton(
                icon: Icon(Icons.delete_outline,
                    color: Colors.white.withValues(alpha: 0.4), size: 18),
                onPressed: _clearSession,
                tooltip: 'Clear this session',
              ),
          ],
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white38))
            : Column(
                children: [
                  Expanded(
                    child: _messages.isEmpty
                        ? Center(
                            child: Text(
                              'Start a conversation...',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.2),
                                fontSize: 12,
                                letterSpacing: 2,
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final msg = _messages[index];
                              final isUser = msg['role'] == 'user';
                              return Padding(
                                padding: EdgeInsets.only(
                                  bottom: 12,
                                  left: isUser ? 40 : 0,
                                  right: isUser ? 0 : 40,
                                ),
                                child: Align(
                                  alignment: isUser
                                      ? Alignment.centerRight
                                      : Alignment.centerLeft,
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: (isUser
                                              ? Colors.white
                                              : Colors.white
                                                  .withValues(alpha: 0.08))
                                          .withValues(
                                              alpha: isUser ? 0.9 : 0.08),
                                      borderRadius:
                                          BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      msg['content'] ?? '',
                                      style: TextStyle(
                                        color: isUser
                                            ? Colors.black
                                            : Colors.white
                                                .withValues(alpha: 0.85),
                                        fontSize: 13,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  if (_isGenerating || _isListening)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        _isListening ? 'listening...' : 'generating...',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 10,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                            color: Colors.white.withValues(alpha: 0.08)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            enabled: !_isGenerating,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 13,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Type a message...',
                              hintStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.2),
                                fontSize: 13,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: BorderSide(
                                    color:
                                        Colors.white.withValues(alpha: 0.1)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: BorderSide(
                                    color:
                                        Colors.white.withValues(alpha: 0.1)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: BorderSide(
                                    color:
                                        Colors.white.withValues(alpha: 0.3)),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.05),
                            ),
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          onPressed: _isGenerating || _isListening
                              ? null
                              : _startListening,
                          icon: Icon(
                            _isListening ? Icons.mic : Icons.mic_outlined,
                            color: (_isListening ? Colors.red : Colors.white)
                                .withValues(alpha: _isListening ? 0.9 : 0.5),
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.05),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          onPressed: _isGenerating ? null : _sendMessage,
                          icon: Icon(
                            Icons.arrow_upward,
                            color: Colors.white.withValues(
                                alpha: _isGenerating ? 0.2 : 0.6),
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  void _showTopicPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CONVERSATIONS',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                  fontSize: 10,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 12),
              if (_matrices.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'No conversations yet',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 12),
                    ),
                  ),
                )
              else
                ..._matrices.map((m) {
                  final id = m['id'] as String;
                  final name = m['name'] as String;
                  final count = (_sessions[id] ?? []).fold<int>(
                      0, (sum, s) => sum + 1);
                  return ListTile(
                    dense: true,
                    selected: id == _currentMatrixId,
                    selectedTileColor: Colors.white.withValues(alpha: 0.05),
                    leading: Icon(Icons.folder_outlined,
                        color: Colors.white.withValues(alpha: 0.5), size: 18),
                    title: Text(
                      name,
                      style: TextStyle(
                        color: id == _currentMatrixId
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.7),
                        fontSize: 13,
                      ),
                    ),
                    subtitle: Text(
                      '$count sessions',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 10),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _switchTopic(id);
                    },
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  Future<void> _clearSession() async {
    if (_currentSessionId.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Text('Clear session?',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8))),
        content: Text(
          'Delete all messages in this session?',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Clear',
                style: TextStyle(color: Colors.red.withValues(alpha: 0.8))),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await AppDatabase.deleteMessagesFrom(_currentSessionId);
      setState(() => _messages.clear());
    }
  }
}
