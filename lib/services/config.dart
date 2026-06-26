import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class Config {
  static Config? _singleton;

  static Config get instance {
    if (_singleton == null) throw StateError('Config not initialized. Call Config.initialize() first.');
    return _singleton!;
  }

  Map<String, dynamic> _data = {};

  static Future<Config> initialize() async {
    if (_singleton != null) return _singleton!;
    final config = Config();
    await config._load();
    _singleton = config;
    return config;
  }

  Future<String> get _configPath async {
    final dir = await getExternalStorageDirectory();
    return '${dir?.path ?? '/sdcard'}/humanopen/config.json';
  }

  Future<void> _load() async {
    try {
      final path = await _configPath;
      final file = File(path);
      if (await file.exists()) {
        _data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      } else {
        _data = _defaults();
        await save();
      }
    } catch (_) {
      _data = _defaults();
    }
  }

  Map<String, dynamic> _defaults() => {
    'main_model': '/storage/emulated/0/Android/data/com.humanopen.humanopen/files/models/main.gguf',
    'main_model_name': 'humanopen-3b',
    'summarizer_model': '/storage/emulated/0/Android/data/com.humanopen.humanopen/files/models/summarizer.gguf',
    'gpu_layers': 99,
    'context_size': 8192,
    'build_threads': 8,
    'server_port': 8080,
    'auto_start': true,
    'wifi_first': true,
    'api_base_url': 'http://localhost:8080',
    'api_key': '',
    'use_local_model': true,
    'use_local_stt': true,
    'temperature': 0.7,
  };

  Future<void> save() async {
    try {
      final path = await _configPath;
      final file = File(path);
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(_data));
    } catch (_) {}
  }

  String get mainModelPath => _data['main_model'] as String? ?? _defaults()['main_model'] as String;
  String get mainModelName => _data['main_model_name'] as String? ?? _defaults()['main_model_name'] as String;
  String get summarizerModelPath => _data['summarizer_model'] as String? ?? _defaults()['summarizer_model'] as String;
  int get gpuLayers => _data['gpu_layers'] as int? ?? _defaults()['gpu_layers'] as int;
  int get contextSize => _data['context_size'] as int? ?? _defaults()['context_size'] as int;
  int get buildThreads => _data['build_threads'] as int? ?? _defaults()['build_threads'] as int;
  int get serverPort => _data['server_port'] as int? ?? _defaults()['server_port'] as int;
  bool get autoStart => _data['auto_start'] as bool? ?? _defaults()['auto_start'] as bool;
  bool get wifiFirst => _data['wifi_first'] as bool? ?? _defaults()['wifi_first'] as bool;
  String get apiBaseUrl => _data['api_base_url'] as String? ?? _defaults()['api_base_url'] as String;
  String get apiKey => _data['api_key'] as String? ?? _defaults()['api_key'] as String;
  bool get useLocalModel => _data['use_local_model'] as bool? ?? _defaults()['use_local_model'] as bool;
  bool get useLocalStt => _data['use_local_stt'] as bool? ?? _defaults()['use_local_stt'] as bool;
  double get temperature => (_data['temperature'] as num?)?.toDouble() ?? (_defaults()['temperature'] as num).toDouble();

  set mainModelPath(String v) { _data['main_model'] = v; save(); }
  set mainModelName(String v) { _data['main_model_name'] = v; save(); }
  set summarizerModelPath(String v) { _data['summarizer_model'] = v; save(); }
  set gpuLayers(int v) { _data['gpu_layers'] = v; save(); }
  set contextSize(int v) { _data['context_size'] = v; save(); }
  set buildThreads(int v) { _data['build_threads'] = v; save(); }
  set serverPort(int v) { _data['server_port'] = v; save(); }
  set autoStart(bool v) { _data['auto_start'] = v; save(); }
  set wifiFirst(bool v) { _data['wifi_first'] = v; save(); }
  set apiBaseUrl(String v) { _data['api_base_url'] = v; save(); }
  set apiKey(String v) { _data['api_key'] = v; save(); }
  set useLocalModel(bool v) { _data['use_local_model'] = v; save(); }
  set useLocalStt(bool v) { _data['use_local_stt'] = v; save(); }
  set temperature(double v) { _data['temperature'] = v; save(); }

  Map<String, dynamic> toMap() => Map.from(_data);
}
