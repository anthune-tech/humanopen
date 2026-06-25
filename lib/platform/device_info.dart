class DeviceInfo {
  int _totalRamMb = 8192;
  int _freeRamMb = 4096;
  String _gpuName = 'unknown';
  bool _vulkanSupported = false;
  int _recommendedGpuLayers = 0;

  int get totalRamMb => _totalRamMb;
  int get freeRamMb => _freeRamMb;
  String get gpuName => _gpuName;
  bool get vulkanSupported => _vulkanSupported;
  int get recommendedGpuLayers => _recommendedGpuLayers;

  void setFromGpuInfo(Map<String, dynamic> gpuInfo) {
    _gpuName = gpuInfo['gpuName'] as String? ?? 'unknown';
    _vulkanSupported = gpuInfo['vulkanSupported'] as bool? ?? false;
    _recommendedGpuLayers = gpuInfo['recommendedGpuLayers'] as int? ?? 0;
  }

  void setRamFromBytes(int deviceLocalBytes, int freeRamBytes) {
    _totalRamMb = deviceLocalBytes ~/ (1024 * 1024);
    _freeRamMb = freeRamBytes ~/ (1024 * 1024);
  }

  int get recommendedContextSize {
    if (_totalRamMb >= 12000) return 65536;
    if (_totalRamMb >= 8000) return 32768;
    if (_totalRamMb >= 6000) return 16384;
    return 8192;
  }

  String get statusString =>
      '${_totalRamMb}MB RAM | $_gpuName${_vulkanSupported ? ' (Vulkan)' : ''}';
}
