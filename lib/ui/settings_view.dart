import 'package:flutter/material.dart';
import 'package:humanopen/services/config.dart';
import 'package:humanopen/services/inference_service.dart';
import 'package:humanopen/ui/gradient_background.dart';

class SettingsView extends StatefulWidget {
  final InferenceService inferenceService;

  const SettingsView({super.key, required this.inferenceService});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  late TextEditingController _mainModelCtrl;
  late TextEditingController _modelNameCtrl;
  late TextEditingController _summarizerCtrl;
  late TextEditingController _apiUrlCtrl;
  late TextEditingController _apiKeyCtrl;
  int _gpuLayers = 99;
  int _contextSize = 8192;
  int _buildThreads = 8;
  double _temperature = 0.7;
  bool _useLocalModel = true;
  bool _useLocalStt = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _mainModelCtrl = TextEditingController(text: Config.instance.mainModelPath);
    _modelNameCtrl = TextEditingController(text: Config.instance.mainModelName);
    _summarizerCtrl = TextEditingController(text: Config.instance.summarizerModelPath);
    _apiUrlCtrl = TextEditingController(text: Config.instance.apiBaseUrl);
    _apiKeyCtrl = TextEditingController(text: Config.instance.apiKey);
    _gpuLayers = Config.instance.gpuLayers;
    _contextSize = Config.instance.contextSize;
    _buildThreads = Config.instance.buildThreads;
    _temperature = Config.instance.temperature;
    _useLocalModel = Config.instance.useLocalModel;
    _useLocalStt = Config.instance.useLocalStt;
  }

  @override
  void dispose() {
    _mainModelCtrl.dispose();
    _modelNameCtrl.dispose();
    _summarizerCtrl.dispose();
    _apiUrlCtrl.dispose();
    _apiKeyCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveAndReload() async {
    setState(() => _loading = true);

    Config.instance.mainModelPath = _mainModelCtrl.text;
    Config.instance.mainModelName = _modelNameCtrl.text;
    Config.instance.summarizerModelPath = _summarizerCtrl.text;
    Config.instance.gpuLayers = _gpuLayers;
    Config.instance.contextSize = _contextSize;
    Config.instance.buildThreads = _buildThreads;
    Config.instance.temperature = _temperature;
    Config.instance.apiBaseUrl = _apiUrlCtrl.text;
    Config.instance.apiKey = _apiKeyCtrl.text;
    Config.instance.useLocalModel = _useLocalModel;
    Config.instance.useLocalStt = _useLocalStt;

    try {
      await widget.inferenceService.loadModel(
        Config.instance.mainModelPath,
        modelName: Config.instance.mainModelName,
        gpuLayers: Config.instance.gpuLayers,
        contextSize: Config.instance.contextSize,
        threads: Config.instance.buildThreads,
      );
      try {
        await widget.inferenceService.loadSummarizer(Config.instance.summarizerModelPath);
      } catch (_) {}
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Model loaded'), duration: Duration(seconds: 2)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red.shade800),
        );
      }
    }

    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      aiState: _loading ? AiState.loading : AiState.idle,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text('Settings',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 14, letterSpacing: 2, fontWeight: FontWeight.w300,
            ),
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.white.withValues(alpha: 0.6)),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: ListView(
          padding: EdgeInsets.all(20),
          children: [
            _buildSection('MAIN MODEL'),
            _buildField('Model file path', _mainModelCtrl,
                hint: '/sdcard/humanopen/models/...'),
            _buildField('Model name', _modelNameCtrl,
                hint: 'humanopen-3b'),
            SizedBox(height: 20),
            _buildSection('SUMMARIZER (Qwen0.5B)'),
            _buildField('Summarizer path', _summarizerCtrl,
                hint: '/sdcard/humanopen/models/summarizer.gguf'),
            SizedBox(height: 20),
            _buildSection('INFERENCE'),
            _buildDropdown('GPU layers', _gpuLayers,
                [0, 16, 32, 99], (v) => setState(() => _gpuLayers = v!)),
            SizedBox(height: 12),
            _buildDropdown('Context size', _contextSize,
                [4096, 8192, 16384, 32768], (v) => setState(() => _contextSize = v!)),
            SizedBox(height: 12),
            _buildDropdown('Threads', _buildThreads,
                [4, 6, 8], (v) => setState(() => _buildThreads = v!)),
            SizedBox(height: 12),
            _buildSlider('Temperature', _temperature, (v) => setState(() => _temperature = v)),
            SizedBox(height: 24),
            _buildSection('CLIENT MODE'),
            _buildSwitch('Use local model', _useLocalModel, (v) {
              setState(() => _useLocalModel = v);
              Config.instance.useLocalModel = v;
            }),
            SizedBox(height: 12),
            if (!_useLocalModel) ...[
              _buildField('API Base URL', _apiUrlCtrl, hint: 'http://192.168.1.100:8080'),
              SizedBox(height: 8),
              _buildField('API Key (optional)', _apiKeyCtrl, hint: 'sk-...'),
              SizedBox(height: 12),
            ],
            _buildSwitch('Use local STT', _useLocalStt, (v) {
              setState(() => _useLocalStt = v);
              Config.instance.useLocalStt = v;
            }),
            SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _saveAndReload,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  foregroundColor: Colors.white.withValues(alpha: 0.8),
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                ),
                child: Text(_loading ? 'LOADING...' : 'SAVE & RELOAD MODEL',
                    style: TextStyle(letterSpacing: 2, fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Text(title,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.3),
          fontSize: 10, letterSpacing: 3,
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, {String? hint}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2), fontSize: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.05),
        ),
      ),
    );
  }

  Widget _buildSwitch(String label, bool value, ValueChanged<bool> onChanged) {
    return Row(
      children: [
        Expanded(
          child: Text(label,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11, letterSpacing: 1),
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: Colors.tealAccent.withValues(alpha: 0.6),
          inactiveThumbColor: Colors.white.withValues(alpha: 0.3),
          inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
        ),
      ],
    );
  }

  Widget _buildDropdown(String label, int value, List<int> items, ValueChanged<int?> onChanged) {
    return Row(
      children: [
        Text(label,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11, letterSpacing: 1),
        ),
        SizedBox(width: 16),
        DropdownButton<int>(
          value: value,
          dropdownColor: Color.fromRGBO(15, 17, 35, 1),
          style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
          underline: Container(height: 1, color: Colors.white.withValues(alpha: 0.1)),
          items: items.map((v) => DropdownMenuItem(value: v, child: Text('$v'))).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildSlider(String label, double value, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11, letterSpacing: 1),
            ),
            Text(value.toStringAsFixed(1),
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
            ),
          ],
        ),
        Slider(
          value: value,
          min: 0.0,
          max: 2.0,
          divisions: 20,
          onChanged: onChanged,
          activeColor: Colors.tealAccent.withValues(alpha: 0.5),
          inactiveColor: Colors.white.withValues(alpha: 0.1),
          thumbColor: Colors.white.withValues(alpha: 0.7),
        ),
      ],
    );
  }
}
