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

   Stream<void> get disconnectStream {
      return _disconnectController.stream;
    }

  bool get isConnected {
    return _socket != null;
  }

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
        _jsonController.addError(error);

        if (!_disconnectController.isClosed) {
          _disconnectController.add(null);
        }
      },
      onDone: () {
        _socket = null;
        _subscription = null;

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

    _buffer += text;

    _extractJsonMessages();
  }

  void _extractJsonMessages() {
    while (true) {
      final startIndex = _buffer.indexOf('{');

      if (startIndex == -1) {
        if (_buffer.length > 1000) {
          _buffer = '';
        }

        return;
      }

      final endIndex = _buffer.indexOf('}', startIndex);

      if (endIndex == -1) {
        if (startIndex > 0) {
          _buffer = _buffer.substring(startIndex);
        }

        return;
      }

      final jsonText = _buffer.substring(
        startIndex,
        endIndex + 1,
      );

      _buffer = _buffer.substring(endIndex + 1);

      _jsonController.add(jsonText.trim());
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