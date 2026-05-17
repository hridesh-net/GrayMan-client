import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../core/networking/api_config.dart';
import '../models/worker_dto.dart';

/// Backend-mediated interview WebSocket — mirrors InterviewSession.swift.
class InterviewSession {
  InterviewSession({
    required this.token,
    required this.lang,
    this.trade,
    this.duration = 4,
  });

  final String token;
  final String lang;
  final String? trade;
  final int duration;

  WebSocketChannel? _channel;
  InterviewState state = InterviewState.idle;
  String lastTextTurn = '';

  void Function(InterviewState)? onStateChange;
  void Function(String)? onText;
  void Function(InterviewScores)? onScores;
  void Function(String)? onError;

  void _setState(InterviewState s) {
    state = s;
    onStateChange?.call(s);
  }

  Future<void> connect() async {
    final query = <String, String>{'token': token, 'lang': lang};
    if (trade != null) query['trade'] = trade!;
    query['duration'] = '$duration';

    final url = ApiConfig.wsUrl('/interview/ws', query);
    _setState(InterviewState.connecting);
    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      _setState(InterviewState.listening);
      _channel!.stream.listen(_onMessage, onError: (e) {
        _setState(InterviewState.failed);
        onError?.call('$e');
      }, onDone: () => _setState(InterviewState.ended));
    } catch (e) {
      _setState(InterviewState.failed);
      onError?.call('$e');
    }
  }

  void _onMessage(dynamic data) {
    try {
      final j = jsonDecode(data as String) as Map<String, dynamic>;
      switch (j['type']) {
        case 'ready':
          _setState(InterviewState.listening);
          break;
        case 'text':
          lastTextTurn = j['text'] as String? ?? '';
          onText?.call(lastTextTurn);
          break;
        case 'scores':
          onScores?.call(InterviewScores.fromJson(j));
          _setState(InterviewState.ended);
          break;
        case 'done':
          _setState(InterviewState.ended);
          break;
        case 'error':
          _setState(InterviewState.failed);
          onError?.call(j['message'] as String? ?? 'Unknown error');
          break;
      }
    } catch (_) {}
  }

  void sendAudioChunk(List<int> pcm16) {
    if (_channel == null) return;
    final b64 = base64Encode(pcm16);
    _channel!.sink.add(jsonEncode({'type': 'audio', 'data': b64}));
  }

  void end() {
    _channel?.sink.add(jsonEncode({'type': 'end'}));
    disconnect();
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }
}

enum InterviewState { idle, connecting, listening, speaking, ended, failed }
