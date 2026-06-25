import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:humanopen/services/inference_service.dart';
import 'package:humanopen/services/connectivity_service.dart';
import 'package:humanopen/services/config.dart';
import 'package:humanopen/services/foreground_service.dart';
import 'package:humanopen/platform/inference_engine.dart';
import 'package:humanopen/memory/database.dart' show AppDatabase;
import 'package:humanopen/server/openai_server.dart';
import 'package:humanopen/ui/home_screen.dart';

late final InferenceService inferenceService;
late final ConnectivityService connectivityService;
late final OpenaiServer apiServer;
StreamSubscription? _connectivitySub;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Desktop platforms use sqflite_common_ffi instead of the Android/iOS plugin
  if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  await AppDatabase.getInstance();
  await Config.initialize();

  final engine = InferenceEngine();
  inferenceService = InferenceService(engine);
  connectivityService = ConnectivityService();
  apiServer = OpenaiServer(inferenceService, port: Config.instance.serverPort);

  connectivityService.start();

  _setupConnectivityHandler();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  runApp(const HumanopenApp());
}

void _setupConnectivityHandler() {
  _connectivitySub = connectivityService.stateStream.listen((state) {
    if (state.anyNetwork && !apiServer.isRunning) {
      apiServer.start();
    }
  });
}

class HumanopenApp extends StatefulWidget {
  const HumanopenApp({super.key});

  @override
  State<HumanopenApp> createState() => _HumanopenAppState();
}

class _HumanopenAppState extends State<HumanopenApp> {
  bool _initializing = true;
  String _initMessage = 'Initializing...';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() { _initMessage = 'Loading AI model...'; });

    // Try to load main model
    try {
      await inferenceService.loadModel(
        Config.instance.mainModelPath,
        modelName: Config.instance.mainModelName,
        gpuLayers: Config.instance.gpuLayers,
        contextSize: Config.instance.contextSize,
      );
    } catch (e) {
      setState(() { _initMessage = 'Model not found: $e'; });
      await Future.delayed(Duration(seconds: 3));
      setState(() { _initializing = false; });
      return;
    }

    // Summarizer loaded on-demand (not at startup)

    // Start API server
    try {
      await apiServer.start();
    } catch (_) {}

    // Start foreground service
    try {
      await ForegroundService().start();
    } catch (_) {}

    setState(() { _initializing = false; });
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'humanopen',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.transparent,
      ),
      home: _initializing
          ? Scaffold(
              backgroundColor: const Color.fromRGBO(10, 12, 28, 1),
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'humanopen',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 28,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _initMessage,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 11,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : HomeScreen(
              inferenceService: inferenceService,
              connectivityService: connectivityService,
            ),
    );
  }
}
