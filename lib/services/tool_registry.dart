import 'dart:io';

/// Corrects common Linux paths in shell commands to Android paths.
String _androidizePath(String cmd) {
  // ~/ and $HOME → /storage/emulated/0/
  cmd = cmd.replaceAll(RegExp(r'(?<!\w)~/'), '/storage/emulated/0/');
  cmd = cmd.replaceAll(RegExp(r'\$HOME(?=/)'), '/storage/emulated/0');
  // /home/username/ → /storage/emulated/0/
  cmd = cmd.replaceAll(RegExp(r'/home/\w+/'), '/storage/emulated/0/');
  // standalone /home/ → /storage/emulated/0/
  cmd = cmd.replaceAll(RegExp(r'(?<!\S)/home/(?=/)'), '/storage/emulated/0/');
  return cmd;
}

class ToolDefinition {
  final String name;
  final String description;
  final Map<String, dynamic> parameters;

  const ToolDefinition({
    required this.name,
    required this.description,
    required this.parameters,
  });
}

class ToolCall {
  final String name;
  final Map<String, dynamic> arguments;

  ToolCall(this.name, this.arguments);

  factory ToolCall.fromJson(Map<String, dynamic> json) {
    return ToolCall(
      json['name'] as String? ?? '',
      (json['arguments'] as Map<String, dynamic>?) ?? {},
    );
  }

  Map<String, dynamic> toJson() => {'name': name, 'arguments': arguments};
}

class ToolResult {
  final String name;
  final dynamic result;
  final String? error;

  ToolResult({required this.name, this.result, this.error});

  Map<String, dynamic> toJson() => {
    'name': name,
    if (error != null) 'error': error,
    if (result != null) 'result': result,
  };
}

typedef ToolExecutor = Future<ToolResult> Function(ToolCall call);

class ToolRegistry {
  final Map<String, ToolExecutor> _executors = {};
  final List<ToolDefinition> _definitions = [];

  void register(ToolDefinition def, ToolExecutor executor) {
    _definitions.add(def);
    _executors[def.name] = executor;
  }

  List<ToolDefinition> get definitions => _definitions;

  bool hasTool(String name) => _executors.containsKey(name);

  Future<ToolResult> execute(ToolCall call) async {
    final executor = _executors[call.name];
    if (executor == null) {
      return ToolResult(name: call.name, error: 'Unknown tool: ${call.name}');
    }
    try {
      return await executor(call);
    } catch (e) {
      return ToolResult(name: call.name, error: e.toString());
    }
  }

  String get systemPromptBlock {
    if (_definitions.isEmpty) return '';
    final buf = StringBuffer('\n\nTools: ');
    for (final def in _definitions) {
      buf.write('${def.name}(${def.description}) ');
    }
    buf.write('\nCall tool: {"name":"x","arguments":{}}');
    return buf.toString();
  }

  static ToolRegistry createDefault() {
    final reg = ToolRegistry();

    reg.register(
      const ToolDefinition(
        name: 'shell',
        description: 'run cmd',
        parameters: {'command': 'string'},
      ),
      (call) async {
        final raw = call.arguments['command'] as String? ?? '';
        if (raw.isEmpty) return ToolResult(name: 'shell', error: 'No command specified');
        final cmd = _androidizePath(raw);
        try {
          final result = await Process.run(
            '/system/bin/sh',
            ['-c', cmd],
            runInShell: false,
          );
          final out = (result.stdout as String?)?.trim() ?? '';
          final err = (result.stderr as String?)?.trim() ?? '';
          final mapped = raw != cmd ? '\n[path corrected for Android]' : '';
          return ToolResult(
            name: 'shell',
            result: err.isNotEmpty ? '$out\nstderr: $err$mapped' : '$out$mapped',
          );
        } catch (e) {
          return ToolResult(name: 'shell', error: e.toString());
        }
      },
    );

    reg.register(
      const ToolDefinition(
        name: 'get_resources',
        description: 'RAM/CPU/battery/storage',
        parameters: {},
      ),
      (_) async {
        final result = StringBuffer();

        try {
          final mem = await Process.run('/system/bin/sh', ['-c', 'free -h']);
          result.writeln('MEMORY:');
          result.writeln((mem.stdout as String?)?.trim() ?? 'N/A');
        } catch (_) { result.writeln('MEMORY: N/A'); }

        try {
          final cpu = await Process.run('/system/bin/sh', ['-c', 'cat /proc/loadavg']);
          result.writeln('CPU LOAD: ${(cpu.stdout as String?)?.trim() ?? "N/A"}');
        } catch (_) { result.writeln('CPU LOAD: N/A'); }

        try {
          final batt = await Process.run('/system/bin/sh', ['-c', 'dumpsys battery']);
          final lines = (batt.stdout as String?)?.split('\n').where((l) =>
              l.contains(':')).take(5).join('\n') ?? 'N/A';
          result.writeln('BATTERY:');
          result.writeln(lines);
        } catch (_) { result.writeln('BATTERY: N/A'); }

        try {
          final df = await Process.run('/system/bin/sh', ['-c', 'df -h /data']);
          result.writeln('STORAGE:');
          result.writeln((df.stdout as String?)?.trim() ?? 'N/A');
        } catch (_) { result.writeln('STORAGE: N/A'); }

        return ToolResult(name: 'get_resources', result: result.toString());
      },
    );

    reg.register(
      const ToolDefinition(
        name: 'get_network',
        description: 'WiFi/mobile status',
        parameters: {},
      ),
      (_) async {
        final result = StringBuffer();
        try {
          final interfaces = await NetworkInterface.list();
          final wifi = interfaces.any((i) =>
              i.name.contains('wlan') && i.addresses.any((a) =>
                  a.address.isNotEmpty));
          final mobile = interfaces.any((i) =>
              (i.name.contains('rmnet') || i.name.contains('ccmni') ||
               i.name.contains('wwan')) &&
              i.addresses.any((a) => a.address.isNotEmpty));
          result.writeln('WiFi: ${wifi ? "connected" : "disconnected"}');
          result.writeln('Mobile data: ${mobile ? "connected" : "disconnected"}');
        } catch (_) {
          result.writeln('Network info unavailable');
        }
        return ToolResult(name: 'get_network', result: result.toString());
      },
    );

    reg.register(
      const ToolDefinition(
        name: 'get_camera',
        description: 'photo filepath',
        parameters: {},
      ),
      (_) async {
        return ToolResult(
          name: 'get_camera',
          error: 'Camera capture requires Android Intent - not available in shell mode.',
        );
      },
    );

    reg.register(
      const ToolDefinition(
        name: 'list_files',
        description: 'list dir contents',
        parameters: {'path': 'string'},
      ),
      (call) async {
        final raw = call.arguments['path'] as String? ?? '/storage/emulated/0/';
        final path = _androidizePath(raw);
        try {
          final result = await Process.run('/system/bin/sh', ['-c', r'ls -la "$1"', '_', path]);
          return ToolResult(
            name: 'list_files',
            result: (result.stdout as String?)?.trim() ?? '',
          );
        } catch (e) {
          return ToolResult(name: 'list_files', error: e.toString());
        }
      },
    );

    return reg;
  }
}
