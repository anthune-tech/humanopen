import 'dart:async';
import 'package:flutter/material.dart';
import 'package:humanopen/memory/database.dart' show AppDatabase;
import 'package:humanopen/services/inference_service.dart';
import 'package:humanopen/ui/gradient_background.dart' show AiState, GradientBackground;
import 'package:humanopen/ui/mini_chat.dart';

class BrowseView extends StatefulWidget {
  final InferenceService inferenceService;
  final String initialTab;

  const BrowseView({
    super.key,
    required this.inferenceService,
    this.initialTab = 'topics',
  });

  @override
  State<BrowseView> createState() => _BrowseViewState();
}

class _BrowseViewState extends State<BrowseView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _matrices = [];
  List<Map<String, dynamic>> _facts = [];
  Map<String, List<Map<String, dynamic>>> _sessions = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
        length: 2, vsync: this,
        initialIndex: widget.initialTab == 'facts' ? 1 : 0);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final matrices = await AppDatabase.getMatrices();
      for (final m in matrices) {
        final sessions = await AppDatabase.getSessions(m['id'] as String);
        _sessions[m['id'] as String] = sessions;
      }
      _facts = await AppDatabase.getFacts();
      if (mounted) setState(() {
        _matrices = matrices;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      aiState: AiState.idle,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back,
                color: Colors.white.withValues(alpha: 0.6)),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            'Browse',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 16,
              letterSpacing: 2,
              fontWeight: FontWeight.w300,
            ),
          ),
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white.withValues(alpha: 0.3),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white.withValues(alpha: 0.4),
            labelStyle: const TextStyle(fontSize: 11, letterSpacing: 2),
            tabs: const [
              Tab(text: 'TOPICS'),
              Tab(text: 'FACTS'),
            ],
          ),
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white38))
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildTopicsTab(),
                  _buildFactsTab(),
                ],
              ),
      ),
    );
  }

  Widget _buildTopicsTab() {
    if (_matrices.isEmpty) {
      return Center(
        child: Text(
          'No conversations yet',
          style:
              TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _matrices.length,
      itemBuilder: (context, i) {
        final m = _matrices[i];
        final id = m['id'] as String;
        final name = m['name'] as String;
        final sessions = _sessions[id] ?? [];
        return Card(
          color: Colors.white.withValues(alpha: 0.05),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: ExpansionTile(
            leading: Icon(Icons.folder_outlined,
                color: Colors.white.withValues(alpha: 0.5), size: 20),
            title: Text(
              name,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 14,
              ),
            ),
            subtitle: Text(
              '${sessions.length} session${sessions.length == 1 ? '' : 's'}',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3), fontSize: 10),
            ),
            iconColor: Colors.white.withValues(alpha: 0.3),
            collapsedIconColor: Colors.white.withValues(alpha: 0.3),
            children: sessions.isEmpty
                ? [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Sessions will appear after you chat',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.2),
                            fontSize: 11),
                      ),
                    )
                  ]
                : sessions.map((s) {
                    final sid = s['id'] as String;
                    final title = s['title'] as String? ?? 'Untitled';
                    return ListTile(
                      dense: true,
                      leading: Icon(Icons.chat_outlined,
                          color: Colors.white.withValues(alpha: 0.3),
                          size: 16),
                      title: Text(
                        title,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                      trailing: Icon(Icons.chevron_right,
                          color: Colors.white.withValues(alpha: 0.2),
                          size: 16),
                      onTap: () => _openSession(id, sid, name),
                    );
                  }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildFactsTab() {
    if (_facts.isEmpty) {
      return Center(
        child: Text(
          'No facts extracted yet.\nAsk me to remember something!',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.3), fontSize: 12),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _facts.length,
      itemBuilder: (context, i) {
        final f = _facts[i];
        final content = f['content'] as String? ?? '';
        final status = f['status'] as String? ?? 'pending';
        final confidence = (f['confidence'] as num?)?.toDouble() ?? 0;
        return Card(
          color: Colors.white.withValues(alpha: 0.05),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: ListTile(
            leading: Icon(
              status == 'confirmed'
                  ? Icons.check_circle
                  : status == 'rejected'
                      ? Icons.cancel
                      : Icons.help_outline,
              color: status == 'confirmed'
                  ? Colors.green.withValues(alpha: 0.6)
                  : status == 'rejected'
                      ? Colors.red.withValues(alpha: 0.6)
                      : Colors.orange.withValues(alpha: 0.6),
              size: 18,
            ),
            title: Text(
              content,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
            subtitle: Text(
              '${(confidence * 100).toInt()}% confident',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3), fontSize: 10),
            ),
          ),
        );
      },
    );
  }

  void _openSession(String matrixId, String sessionId, String topicName) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MiniChat(
          inferenceService: widget.inferenceService,
          initialMatrixId: matrixId,
          initialSessionId: sessionId,
          initialTopic: topicName,
        ),
      ),
    );
  }
}
