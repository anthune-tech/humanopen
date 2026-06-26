import 'dart:async';
import 'package:flutter/material.dart';
import 'package:humanopen/services/inference_service.dart';
import 'package:humanopen/services/connectivity_service.dart';
import 'package:humanopen/services/config.dart';
import 'package:humanopen/ui/gradient_background.dart';
import 'package:humanopen/ui/mini_chat.dart';
import 'package:humanopen/ui/settings_view.dart';
import 'package:humanopen/ui/browse_view.dart';

class HomeScreen extends StatefulWidget {
  final InferenceService inferenceService;
  final ConnectivityService connectivityService;

  const HomeScreen({
    super.key,
    required this.inferenceService,
    required this.connectivityService,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  AiState _aiState = AiState.idle;
  String _status = 'Initializing...';
  String _networkStatus = 'checking...';
  Map<String, dynamic> _stats = {};
  Timer? _statsTimer;
  StreamSubscription? _connectivitySub;

  @override
  void initState() {
    super.initState();
    _refreshStats();
    _statsTimer = Timer.periodic(Duration(seconds: 5), (_) => _refreshStats());

    _connectivitySub = widget.connectivityService.stateStream.listen((_) {
      _updateNetworkStatus();
    });
  }

  @override
  void dispose() {
    _statsTimer?.cancel();
    _connectivitySub?.cancel();
    super.dispose();
  }

  Future<void> _refreshStats() async {
    try {
      final stats = await widget.inferenceService.getStats();
      if (mounted) {
        setState(() { _stats = stats; });
      }
    } catch (_) {}
    _updateNetworkStatus();
    _updateStatus();
  }

  void _updateNetworkStatus() {
    final cs = widget.connectivityService;
    setState(() {
      _networkStatus = cs.wifiAvailable
          ? 'Connected (WiFi)'
          : cs.mobileDataOn
              ? 'Connected (GSM)'
              : 'No network';
    });
  }

  void _updateStatus() {
    setState(() {
      _aiState = widget.inferenceService.isModelLoaded
          ? AiState.idle
          : AiState.loading;
      final mode = Config.instance.useLocalModel ? 'local' : 'remote';
      final compute = Config.instance.useLocalModel
          ? widget.inferenceService.computeMode
          : '';
      _status = widget.inferenceService.isModelLoaded
          ? 'Model: ${widget.inferenceService.currentModelName} ($mode / $compute)'
          : Config.instance.useLocalModel
              ? 'No model loaded'
              : 'Remote: ${Config.instance.apiBaseUrl}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      aiState: _aiState,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  'humanopen',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 28,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 4,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'personal AI',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 12,
                    letterSpacing: 6,
                  ),
                ),
                SizedBox(height: 40),

                // Status card
                _buildStatusCard('Status', _status),
                SizedBox(height: 12),
                _buildStatusCard('Network', _networkStatus),
                SizedBox(height: 12),
                _buildStatusCard('Server', 'Port 8080'),
                SizedBox(height: 24),

                // Stats grid
                Text(
                  'MEMORY',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 10,
                    letterSpacing: 3,
                  ),
                ),
                SizedBox(height: 12),
                _buildStatsGrid(),
                SizedBox(height: 24),

                // Actions
                Center(
                  child: Column(
                    children: [
                      _buildActionButton(
                        'OPEN CHAT',
                        Icons.chat_outlined,
                        () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => MiniChat(
                                inferenceService: widget.inferenceService),
                          ),
                        ),
                      ),
                      SizedBox(height: 12),
                      _buildActionButton(
                        'REFRESH',
                        Icons.refresh,
                        _refreshStats,
                      ),
                      SizedBox(height: 12),
                      _buildActionButton(
                        'SETTINGS',
                        Icons.settings_outlined,
                        () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SettingsView(
                              inferenceService: widget.inferenceService,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard(String label, String value) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 11,
              letterSpacing: 1,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    final items = [
      ('Messages', '${_stats['messages'] ?? 0}', 'topics'),
      ('Sessions', '${_stats['sessions'] ?? 0}', 'topics'),
      ('Facts', '${_stats['facts'] ?? 0}', 'facts'),
      ('Matrices', '${_stats['matrices'] ?? 0}', 'topics'),
      ('Uptime', '${_stats['uptime'] ?? 0}s', null),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        final label = item.$1;
        final value = item.$2;
        final tab = item.$3;
        return GestureDetector(
          onTap: tab != null
              ? () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => BrowseView(
                        inferenceService: widget.inferenceService,
                        initialTab: tab,
                      ),
                    ),
                  )
              : null,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 18,
                    fontWeight: FontWeight.w300,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 9,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActionButton(String label, IconData icon, VoidCallback onTap) {
    return SizedBox(
      width: 200,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16),
        label: Text(label, style: TextStyle(letterSpacing: 2, fontSize: 11)),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white.withValues(alpha: 0.7),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
          padding: EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}
