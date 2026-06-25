import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:humanopen/services/inference_service.dart';

class OpenaiServer {
  final InferenceService _inferenceService;
  HttpServer? _server;
  int _port;

  OpenaiServer(this._inferenceService, {int port = 8080}) : _port = port;

  int get port => _port;
  bool get isRunning => _server != null;

  Future<void> start({int? port}) async {
    if (_server != null) return;
    _port = port ?? _port;
    _server = await HttpServer.bind(InternetAddress.anyIPv4, _port);
    _server!.listen(_handleRequest);
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  void _handleRequest(HttpRequest request) {
    final uri = Uri.parse(request.uri.toString());
    final method = request.method;

    request.response.headers.set('Access-Control-Allow-Origin', '*');
    request.response.headers.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    request.response.headers.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');

    if (method == 'OPTIONS') {
      request.response.statusCode = 200;
      request.response.close();
      return;
    }

    switch ('$method ${uri.path}') {
      case 'GET /health':
        _handleHealth(request);
      case 'GET /v1/models':
        _handleListModels(request);
      case 'POST /v1/chat/completions':
        _handleChatCompletion(request);
      case 'POST /v1/completions':
        _handleCompletion(request);
      case 'POST /v1/memory/extract':
        _handleExtractFacts(request);
      case 'POST /v1/memory/confirm':
        _handleConfirmFact(request);
      case 'POST /v1/memory/edit':
        _handleEditFact(request);
      case 'POST /v1/memory/delete':
        _handleDeleteFact(request);
      case 'GET /v1/memory/facts':
        _handleListFacts(request);
      case 'GET /v1/memory/stats':
        _handleStats(request);
      default:
        _sendJson(request.response, {'error': 'not_found', 'message': 'Endpoint not found'}, 404);
    }
  }

  void _handleHealth(HttpRequest request) {
    _sendJson(request.response, {
      'status': 'ok',
      'model_loaded': _inferenceService.isModelLoaded,
      'model_name': _inferenceService.currentModelName,
      'uptime': _inferenceService.uptime,
    });
  }

  void _handleListModels(HttpRequest request) {
    _sendJson(request.response, {
      'object': 'list',
      'data': [
        {
          'id': _inferenceService.currentModelName ?? 'humanopen-3b',
          'object': 'model',
          'created': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          'owned_by': 'humanopen',
        }
      ],
    });
  }

  void _handleChatCompletion(HttpRequest request) {
    _readBody(request).then((body) {
      final data = jsonDecode(body) as Map<String, dynamic>;
      final messages = data['messages'] as List<dynamic>;
      final stream = data['stream'] as bool? ?? false;

      if (stream) {
        _handleStreamingChat(request, messages, data);
      } else {
        _handleNonStreamingChat(request, messages, data);
      }
    }).catchError((e) {
      _sendJson(request.response, {'error': 'invalid_request', 'message': e.toString()}, 400);
    });
  }

  void _handleStreamingChat(HttpRequest request, List<dynamic> messages, Map<String, dynamic> data) {
    request.response.headers.set('Content-Type', 'text/event-stream');
    request.response.headers.set('Cache-Control', 'no-cache');
    request.response.headers.set('Connection', 'keep-alive');

    _inferenceService.getOrCreateSession(messages).then((sessionInfo) {
      final matrixId = sessionInfo['matrix_id'] as String;
      final sessionId = sessionInfo['session_id'] as String;
      final userMsg = messages.last['content'] as String;

      _inferenceService.generate(matrixId, sessionId, userMsg).listen(
        (token) {
          final payload = jsonEncode({
            'choices': [{
              'delta': {'content': token},
              'index': 0,
            }],
          });
          request.response.write('data: $payload\n\n');
        },
        onDone: () {
          request.response.write('data: [DONE]\n\n');
          request.response.close();
        },
        onError: (e) {
          final payload = jsonEncode({'error': e.toString()});
          request.response.write('data: $payload\n\n');
          request.response.close();
        },
      );
    }).catchError((e) {
      request.response.write('data: ${jsonEncode({"error": e.toString()})}\n\n');
      request.response.close();
    });
  }

  void _handleNonStreamingChat(HttpRequest request, List<dynamic> messages, Map<String, dynamic> data) {
    _inferenceService.getOrCreateSession(messages).then((sessionInfo) {
      final matrixId = sessionInfo['matrix_id'] as String;
      final sessionId = sessionInfo['session_id'] as String;
      final userMsg = messages.last['content'] as String;

      final buffer = StringBuffer();
      _inferenceService.generate(matrixId, sessionId, userMsg).listen(
        (token) => buffer.write(token),
        onDone: () {
          _sendJson(request.response, {
            'id': 'chatcmpl-${DateTime.now().millisecondsSinceEpoch}',
            'object': 'chat.completion',
            'created': DateTime.now().millisecondsSinceEpoch ~/ 1000,
            'model': _inferenceService.currentModelName ?? 'humanopen-3b',
            'choices': [{
              'index': 0,
              'message': {
                'role': 'assistant',
                'content': buffer.toString(),
              },
              'finish_reason': 'stop',
            }],
            'usage': {
              'prompt_tokens': 0,
              'completion_tokens': 0,
              'total_tokens': 0,
            },
          });
        },
        onError: (e) {
          _sendJson(request.response, {'error': e.toString()}, 500);
        },
      );
    }).catchError((e) {
      _sendJson(request.response, {'error': e.toString()}, 500);
    });
  }

  void _handleCompletion(HttpRequest request) {
    _readBody(request).then((body) {
      final data = jsonDecode(body) as Map<String, dynamic>;
      final prompt = data['prompt'] as String;
      final stream = data['stream'] as bool? ?? false;

      if (stream) {
        request.response.headers.set('Content-Type', 'text/event-stream');
        _inferenceService.generateCompletion(prompt).listen(
          (token) {
            request.response.write('data: ${jsonEncode({"choices": [{"text": token}]})}\n\n');
          },
          onDone: () {
            request.response.write('data: [DONE]\n\n');
            request.response.close();
          },
          onError: (e) => request.response.close(),
        );
      } else {
        final buffer = StringBuffer();
        _inferenceService.generateCompletion(prompt).listen(
          (token) => buffer.write(token),
          onDone: () {
            _sendJson(request.response, {
              'id': 'cmpl-${DateTime.now().millisecondsSinceEpoch}',
              'object': 'text_completion',
              'choices': [{'text': buffer.toString(), 'index': 0, 'finish_reason': 'stop'}],
            });
          },
          onError: (e) => _sendJson(request.response, {'error': e.toString()}, 500),
        );
      }
    }).catchError((e) {
      _sendJson(request.response, {'error': 'invalid_request', 'message': e.toString()}, 400);
    });
  }

  void _handleExtractFacts(HttpRequest request) {
    _readBody(request).then((body) async {
      final data = jsonDecode(body) as Map<String, dynamic>;
      final matrixId = data['matrix_id'] as String?;
      final ids = await _inferenceService.extractFacts(matrixId: matrixId);
      _sendJson(request.response, {'facts': ids});
    }).catchError((e) {
      _sendJson(request.response, {'error': e.toString()}, 500);
    });
  }

  void _handleConfirmFact(HttpRequest request) {
    _readBody(request).then((body) async {
      final data = jsonDecode(body) as Map<String, dynamic>;
      await _inferenceService.confirmFact(data['id'] as String);
      _sendJson(request.response, {'status': 'confirmed'});
    }).catchError((e) {
      _sendJson(request.response, {'error': e.toString()}, 500);
    });
  }

  void _handleEditFact(HttpRequest request) {
    _readBody(request).then((body) async {
      final data = jsonDecode(body) as Map<String, dynamic>;
      await _inferenceService.editFact(data['id'] as String, data['fact'] as String);
      _sendJson(request.response, {'status': 'edited'});
    }).catchError((e) {
      _sendJson(request.response, {'error': e.toString()}, 500);
    });
  }

  void _handleDeleteFact(HttpRequest request) {
    _readBody(request).then((body) async {
      final data = jsonDecode(body) as Map<String, dynamic>;
      await _inferenceService.deleteFact(data['id'] as String);
      _sendJson(request.response, {'status': 'deleted'});
    }).catchError((e) {
      _sendJson(request.response, {'error': e.toString()}, 500);
    });
  }

  void _handleListFacts(HttpRequest request) {
    final params = request.uri.queryParameters;
    _inferenceService.listFacts(
      matrixId: params['matrix_id'],
      status: params['status'],
    ).then((facts) {
      _sendJson(request.response, {'facts': facts});
    }).catchError((e) {
      _sendJson(request.response, {'error': e.toString()}, 500);
    });
  }

  void _handleStats(HttpRequest request) {
    _inferenceService.getStats().then((stats) {
      _sendJson(request.response, stats);
    }).catchError((e) {
      _sendJson(request.response, {'error': e.toString()}, 500);
    });
  }

  void _sendJson(HttpResponse response, dynamic data, [int statusCode = 200]) {
    response.statusCode = statusCode;
    response.headers.set('Content-Type', 'application/json');
    response.write(jsonEncode(data));
    response.close();
  }

  Future<String> _readBody(HttpRequest request) async {
    final bytes = <int>[];
    await for (final chunk in request) {
      bytes.addAll(chunk);
    }
    return utf8.decode(bytes);
  }
}
