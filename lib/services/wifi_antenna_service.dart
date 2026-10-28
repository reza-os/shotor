import 'dart:async';
import 'dart:convert';
import 'dart:io';

class WifiAntennaService {
  static const String defaultUrl = 'ws://192.168.4.1:81/';

  WebSocket? _socket;
  StreamSubscription<dynamic>? _subscription;

  final StreamController<String> _jsonController =
      StreamController<String>.broadcast();

  final StreamController<void> _disconnectController =
      StreamController<void>.broadcast();




  String _buffer = '';
  String _url = defaultUrl;

  Stream<String> get jsonStream {
    return _jsonController.stream;
  }

  /// Pause at the source websocket, not just the broadcast UI stream.
  /// Without this, a paused broadcast subscriber still queues inbound
  /// packets and can grow without bounds during high-rate reception.
  void pauseReading() => _subscription?.pause();
  void resumeReading() => _subscription?.resume();

   Stream<void> get disconnectStream {
      return _disconnectController.stream;
    }

  bool get isConnected => _socket?.readyState == WebSocket.open;

  String get connectedDeviceName {
    if (!isConnected) {
      return 'بدون اتصال';
    }

    return 'Mobile_Antenna_ESP32 / $_url';
  }








  Future<void> sendJson(Map<String, dynamic> data) async {
    final socket = _socket;

    if (socket == null || socket.readyState != WebSocket.open) {
      throw StateError('WebSocket متصل نیست.');
    }

    socket.add(jsonEncode(data));
  }


    Future<void> syncClockWithPhone() async {
      final unixMs = DateTime.now().toUtc().millisecondsSinceEpoch;

      await sendJson({
        'type': 'time_sync',
        'unixMs': unixMs,
      });
    }


  Future<void> subscribe() async {
    await sendJson({
      'type': 'subscribe',
    });
  }

  Future<void> ack(String messageId) async {
    await sendJson({
      'type': 'ack',
      'MessageId': messageId,
    });
  }

  Future<void> unsubscribe() async {
    if (!isConnected) {
      return;
    }

    await sendJson({
      'type': 'unsubscribe',
    });
  }



  Future<void> connect({
    String url = defaultUrl,
  }) async {
    await disconnect();

    _url = url;

    final socket = await WebSocket.connect(
      url,
    ).timeout(
      const Duration(seconds: 8),
    );

    socket.pingInterval = const Duration(seconds: 10);

    _socket = socket;

    _subscription = socket.listen(
      _onMessage,
      onError: (error) {
        if (identical(_socket, socket)) _socket = null;
        _jsonController.addError(error);

        if (!_disconnectController.isClosed) {
          _disconnectController.add(null);
        }
      },
      onDone: () {
        if (identical(_socket, socket)) {
          _socket = null;
          _subscription = null;
        }

        if (!_disconnectController.isClosed) {
          _disconnectController.add(null);
        }
      },
      cancelOnError: false,
    );
  }

  void _onMessage(dynamic message) {
    String text;

    if (message is String) {
      text = message;
    } else if (message is List<int>) {
      text = utf8.decode(
        message,
        allowMalformed: true,
      );
    } else {
      return;
    }

    // Prevent malformed or endless packets from growing process memory.
    if (_buffer.length + text.length > 262144) {
      _buffer = '';
      _jsonController.addError(const FormatException('ESP packet exceeds 256 KiB'));
      return;
    }
    _buffer += text;
    _extractJsonMessages();
  }

  /// WebSocket frames usually carry a single JSON object, but can contain
  /// multiple concatenated objects or embedded JSON objects (for GPS data).
  /// String contents and escaped quotes must not terminate a packet.
  void _extractJsonMessages() {
    while (_buffer.isNotEmpty) {
      final start = _buffer.indexOf('{');
      if (start < 0) { _buffer = ''; return; }
      if (start > 0) _buffer = _buffer.substring(start);
      var depth = 0;
      var quoted = false;
      var escaped = false;
      var end = -1;
      for (var i = 0; i < _buffer.length; i++) {
        final char = _buffer[i];
        if (quoted) {
          if (escaped) { escaped = false; continue; }
          if (char.codeUnitAt(0) == 92) { escaped = true; continue; }
          if (char == '"') quoted = false;
          continue;
        }
        if (char == '"') { quoted = true; continue; }
        if (char == '{') depth++;
        if (char == '}') {
          depth--;
          if (depth == 0) { end = i; break; }
        }
      }
      if (end < 0) return;
      final complete = _buffer.substring(0, end + 1);
      _buffer = _buffer.substring(end + 1);
      _jsonController.add(complete);
    }
  }

  Future<void> disconnect() async {
    await _subscription?.cancel();
    _subscription = null;

    await _socket?.close();
    _socket = null;

    _buffer = '';
  }

 Future<void> dispose() async {
   await disconnect();
   await _jsonController.close();
   await _disconnectController.close();
 }
}