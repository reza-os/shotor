import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:usb_serial/usb_serial.dart';

class UsbAntennaService {
  UsbPort? _port;
  UsbDevice? _connectedDevice;
  StreamSubscription<Uint8List>? _subscription;

  final StreamController<String> _jsonController =
      StreamController<String>.broadcast();

  String _buffer = '';

  Stream<String> get jsonStream => _jsonController.stream;

  bool get isConnected => _port != null;

  String get connectedDeviceName {
    final device = _connectedDevice;

    if (device == null) {
      return 'بدون اتصال';
    }

    final manufacturer = device.manufacturerName ?? '';
    final product = device.productName ?? device.deviceName;

    return '$manufacturer $product'.trim();
  }

  Future<List<UsbDevice>> listDevices() {
    return UsbSerial.listDevices();
  }

  Future<void> connectFirstDevice({
    int baudRate = 115200,
  }) async {
    final devices = await UsbSerial.listDevices();

    if (devices.isEmpty) {
      throw Exception('هیچ دستگاه USB Serial پیدا نشد.');
    }

    await connectToDevice(
      devices.first,
      baudRate: baudRate,
    );
  }

  Future<void> connectToDevice(
    UsbDevice device, {
    int baudRate = 115200,
  }) async {
    await disconnect();

    final port = await device.create();

    if (port == null) {
      throw Exception('امکان ساخت پورت USB وجود ندارد.');
    }

    final opened = await port.open();

    if (opened != true) {
      await port.close();
      throw Exception('باز کردن پورت USB ناموفق بود.');
    }

    await port.setDTR(true);
    await port.setRTS(true);

    await port.setPortParameters(
      baudRate,
      UsbPort.DATABITS_8,
      UsbPort.STOPBITS_1,
      UsbPort.PARITY_NONE,
    );

    final inputStream = port.inputStream;

    if (inputStream == null) {
      await port.close();
      throw Exception('جریان ورودی USB در دسترس نیست.');
    }

    _port = port;
    _connectedDevice = device;

    _subscription = inputStream.listen(
      _onUsbData,
      onError: (error) {
        _jsonController.addError(error);
      },
    );
  }

  void _onUsbData(Uint8List data) {
    final chunk = utf8.decode(data, allowMalformed: true);

    _buffer += chunk;

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

      final jsonText = _buffer.substring(startIndex, endIndex + 1);
      _buffer = _buffer.substring(endIndex + 1);

      _jsonController.add(jsonText);
    }
  }

  Future<void> disconnect() async {
    await _subscription?.cancel();
    _subscription = null;

    await _port?.close();
    _port = null;
    _connectedDevice = null;
    _buffer = '';
  }

  Future<void> dispose() async {
    await disconnect();
    await _jsonController.close();
  }
}