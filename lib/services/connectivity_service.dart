import 'dart:async';
import 'dart:io';

class ConnectivityService {
  bool _wifiAvailable = false;
  bool _mobileDataOn = false;
  Timer? _checkTimer;

  bool get wifiAvailable => _wifiAvailable;
  bool get mobileDataOn => _mobileDataOn;

  final StreamController<ConnectivityState> _stateController =
      StreamController<ConnectivityState>.broadcast();
  Stream<ConnectivityState> get stateStream => _stateController.stream;

  void start() {
    _checkConnectivity();
    _checkTimer = Timer.periodic(Duration(seconds: 30), (_) => _checkConnectivity());
  }

  void stop() {
    _checkTimer?.cancel();
    _stateController.close();
  }

  Future<void> _checkConnectivity() async {
    try {
      final interfaces = await NetworkInterface.list();
      final wifiUp = interfaces.any((i) =>
          i.name.toLowerCase().contains('wlan') &&
          i.addresses.any((a) => a.address.isNotEmpty));
      final mobileUp = interfaces.any((i) =>
          (i.name.toLowerCase().contains('rmnet') ||
           i.name.toLowerCase().contains('ccmni') ||
           i.name.toLowerCase().contains('wwan')) &&
          i.addresses.any((a) => a.address.isNotEmpty));

      final prevWifi = _wifiAvailable;
      final prevMobile = _mobileDataOn;

      _wifiAvailable = wifiUp;
      _mobileDataOn = mobileUp;

      if (wifiUp && !prevWifi && prevMobile) {
        await disableMobileData();
      } else if (!wifiUp && prevWifi && !mobileUp) {
        await enableMobileData();
      }

      if (wifiUp != prevWifi || mobileUp != prevMobile) {
        _stateController.add(ConnectivityState(
          wifiAvailable: wifiUp,
          mobileDataOn: mobileUp,
        ));
      }
    } catch (_) {}
  }

  Future<void> enableMobileData() async {
    try {
      final result = await Process.run('svc', ['data', 'enable']);
      if (result.exitCode == 0) {
        _mobileDataOn = true;
      }
    } catch (_) {}
  }

  Future<void> disableMobileData() async {
    try {
      final result = await Process.run('svc', ['data', 'disable']);
      if (result.exitCode == 0) {
        _mobileDataOn = false;
      }
    } catch (_) {}
  }

  Future<bool> isRootAvailable() async {
    try {
      final result = await Process.run('which', ['su']);
      return result.exitCode == 0 && (result.stdout as String).trim().isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}

class ConnectivityState {
  final bool wifiAvailable;
  final bool mobileDataOn;

  ConnectivityState({required this.wifiAvailable, required this.mobileDataOn});

  bool get anyNetwork => wifiAvailable || mobileDataOn;
  String get activeNetwork => wifiAvailable ? 'WiFi' : (mobileDataOn ? 'GSM' : 'none');
}
