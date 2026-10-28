import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/antenna_inbox_message.dart';
import '../models/antenna_ws_frame.dart';
import '../models/app_settings.dart';
import '../models/tag_record.dart';
import 'antenna_log_service.dart';
import 'antenna_receive_processor.dart';
import 'antenna_wifi_connector.dart';
import 'app_setting_service.dart';
import 'database_service.dart';
import 'live_herd_session_service.dart';
import 'local_storage_service.dart';
import 'location_service.dart';
import 'phone_gps_session.dart';
import 'tag_records_events.dart';
import 'record_day_service.dart';
import 'wifi_antenna_service.dart';
import '../models/antenna_log.dart';

/// App-level owner for the antenna receive session.
///
/// Receiving used to live inside ReceivePage. Keeping the transport here lets
/// the herd dashboard show connection/record state without tying reception to
/// a particular page being mounted.
class AntennaSessionController extends ChangeNotifier with WidgetsBindingObserver {
  AntennaSessionController._();

  static final AntennaSessionController instance = AntennaSessionController._();

  final WifiAntennaService _antennaService = WifiAntennaService();
  final AntennaReceiveProcessor _receiveProcessor = AntennaReceiveProcessor();
  late final PhoneGpsSession _phoneGps = PhoneGpsSession(onPosition: (fix) {
    lastLocationResult = fix;
    gpsStatus = _phoneGps.statusAt(DateTime.now());
    _notifyIncomingThrottled();
  });

  AppSettings appSettings = const AppSettings();
  List<TagRecord> records = <TagRecord>[];

  bool isInitialized = false;
  bool isAntennaConnected = false;
  bool isAntennaConnecting = false;
  bool isGettingLocation = false;
  String antennaStatus = 'قطع';
  String gpsStatus = 'GPS بررسی نشده';
  AppLocationResult? lastLocationResult;
  String lastAntennaJson = '-';
  int duplicateCount = 0;
  int _todayTotal = 0;
  String _currentDayKey = RecordDayService.todayKey;
  bool _recordsLoading = false;
  bool _needsRecordsReload = false;
  Timer? _uiEventTimer;
  Timer? _duplicateFlushTimer;
  DateTime? _lastMissingGpsLogAt;
  int _pendingDuplicateWrites = 0;
  String _pendingDuplicateDay = RecordDayService.todayKey;

  StreamSubscription<String>? _antennaSubscription;
  StreamSubscription<void>? _antennaDisconnectSubscription;
  Timer? _antennaReconnectTimer;
  Timer? _recordsReloadTimer;

  bool _allowAntennaReconnect = false;
  bool _userRequestedDisconnect = false;
  int _antennaReconnectAttempt = 0;
  int _antennaConnectionGeneration = 0;
  bool _tagListenerAttached = false;
  Future<void>? _initializeFuture;
  Timer? _dayRolloverTimer;
  static const _autoConnectKey = 'antenna_user_enabled';

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // When the user enables Android Location while the antenna remains
    // connected, explicitly restart GPS even if the old position stream died.
    if (isAntennaConnected) {
      unawaited(_phoneGps.recheck(requestPermission: true));
    }
    if (_allowAntennaReconnect && !_userRequestedDisconnect &&
        !isAntennaConnected && !isAntennaConnecting) {
      _scheduleAntennaReconnect();
    }
  }

  Future<void> _rememberConnectIntent(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_autoConnectKey, enabled);
    } catch (error) {
      debugPrint('Could not persist antenna reconnect preference: $error');
    }
  }


  Future<void>? _inboxDrainFuture;
  bool _inboxDrainRequested = false;

  int get recordCount => _todayTotal;
  TagRecord? get latestRecord => records.isEmpty ? null : records.first;

  void _rolloverTodayCounters() {
    final today = RecordDayService.todayKey;
    if (_currentDayKey == today) return;
    if (_pendingDuplicateWrites > 0) unawaited(_flushDuplicateCount());
    _currentDayKey = today;
    _pendingDuplicateDay = today;
    duplicateCount = 0;
    _todayTotal = 0;
    unawaited(_loadDuplicateCount(today));
    records.clear();
    unawaited(refreshRecords());
  }

  Future<void> _loadDuplicateCount(String day) async {
    final stored = await LocalStorageService.readDuplicateCount(day);
    if (_currentDayKey != day) return;
    duplicateCount = stored + _pendingDuplicateWrites;
    _notifyIncomingThrottled();
  }

  void _onDuplicate() {
    _rolloverTodayCounters();
    duplicateCount++;
    _pendingDuplicateWrites++;
    _notifyIncomingThrottled();
    _duplicateFlushTimer ??= Timer(const Duration(seconds: 2), () {
      _duplicateFlushTimer = null;
      unawaited(_flushDuplicateCount());
    });
  }

  Future<void> _flushDuplicateCount() async {
    final count = _pendingDuplicateWrites;
    if (count <= 0) return;
    final day = _pendingDuplicateDay;
    _pendingDuplicateWrites = 0;
    try {
      await LocalStorageService.addDuplicateCount(day, count);
    } catch (error) {
      debugPrint('Could not save duplicate count: $error');
      if (_pendingDuplicateDay == day) _pendingDuplicateWrites += count;
    }
  }

  bool get gpsReady => _phoneGps.snapshotAt(DateTime.now()) != null;

  String get gpsDetails => _phoneGps.statusAt(DateTime.now());

  Future<void> initialize() {
    if (isInitialized) return Future<void>.value();
    final current = _initializeFuture;
    if (current != null) return current;

    final job = _doInitialize();
    _initializeFuture = job;
    return job.whenComplete(() {
      _initializeFuture = null;
    });
  }

  Future<void> _doInitialize() async {
    if (!_tagListenerAttached) {
      TagRecordsEvents.revision.addListener(_onTagRecordsChanged);
      _tagListenerAttached = true;
      WidgetsBinding.instance.addObserver(this);
    }

    appSettings = await AppSettingsService.loadSettings();
    try {
      await LocalStorageService.pruneExpired();
    } catch (error) {
      debugPrint('Retention cleanup failed: $error');
    }
    _dayRolloverTimer ??= Timer.periodic(const Duration(seconds: 30), (_) => _rolloverTodayCounters());
    await refreshRecords();
    await _loadDuplicateCount(_currentDayKey);
    await _scheduleInboxDrain();

    isInitialized = true;
    notifyListeners();
    unawaited(refreshGpsStatus());
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_autoConnectKey) == true && appSettings.wifiAutoReconnect) {
      _allowAntennaReconnect = true;
      _userRequestedDisconnect = false;
      unawaited(connect(isAutoReconnect: true));
    }
  }

  void _onTagRecordsChanged() {
    if (_recordsReloadTimer?.isActive == true) return;
    _recordsReloadTimer = Timer(const Duration(milliseconds: 1200), () {
      unawaited(refreshRecords());
    });
  }

  Future<void> refreshRecords() async {
    if (_recordsLoading) { _needsRecordsReload = true; return; }
    _recordsLoading = true;
    try {
      do {
        _needsRecordsReload = false;
        final day = RecordDayService.today;
        final result = await Future.wait<dynamic>([
          LocalStorageService.loadLatestRecordsForDay(day, limit: 200),
          LocalStorageService.countRecordsForDay(day),
        ]);
        records = result[0] as List<TagRecord>;
        _todayTotal = result[1] as int;
        _currentDayKey = RecordDayService.key(day);
        notifyListeners();
      } while (_needsRecordsReload);
      unawaited(LocalStorageService.pruneExpired().catchError((Object error) {
        debugPrint('Scheduled retention cleanup failed: $error');
      }));
    } finally { _recordsLoading = false; }
  }

  void _notifyIncomingThrottled() {
    if (_uiEventTimer?.isActive == true) return;
    _uiEventTimer = Timer(const Duration(milliseconds: 500), notifyListeners);
  }


  Future<void> refreshGpsStatus() async {
    // Available as an explicit GPS retry in the herd dashboard. If the
    // antenna is connected, also re-open a failed position stream.
    if (isAntennaConnected && !_phoneGps.watching) _phoneGps.startWatching();
    if (isAntennaConnected) {
      unawaited(_phoneGps.recheck(requestPermission: true));
    }
    isGettingLocation = true;
    gpsStatus = 'در حال بررسی GPS...';
    notifyListeners();

    try {
      final result = await _phoneGps.refresh();
      lastLocationResult = result;
      gpsStatus = _phoneGps.statusAt(DateTime.now());
    } catch (error) {
      gpsStatus = 'GPS در دسترس نیست';
    } finally {
      gpsStatus = _phoneGps.statusAt(DateTime.now());
      isGettingLocation = false;
      notifyListeners();
    }
  }

  Future<bool> connect({bool isAutoReconnect = false}) async {
    if (isAntennaConnecting) return false;
    if (isAutoReconnect && (isAntennaConnected || _antennaService.isConnected)) {
      return isAntennaConnected;
    }
    // Explicit Connect is also a device-switch action. Free a previously
    // bound Android Wi-Fi network so a newly selected antenna can be used.
    if (!isAutoReconnect && (isAntennaConnected || _antennaService.isConnected)) {
      await _antennaSubscription?.cancel();
      await _antennaService.disconnect();
      await AntennaWifiConnector.releaseWifiNetwork();
      isAntennaConnected = false;
    }

    // Warm up phone GNSS BEFORE connecting to the ESP Wi-Fi network. This is
    // important for an antenna network without Internet: acquiring the first
    // fix only after joining that network often times out. GPS continues to
    // recover automatically if Location was OFF when Connect was tapped.
    _phoneGps.startWatching();
    unawaited(_phoneGps.recheck(requestPermission: true));

    // Pick up changes saved in the Settings screen before reconnecting.
    appSettings = await AppSettingsService.loadSettings();
    _cancelAntennaReconnect(resetAttempt: false);
    _allowAntennaReconnect = appSettings.wifiAutoReconnect;
    _userRequestedDisconnect = false;
    isAntennaConnecting = true;
    antennaStatus = 'در حال اتصال به آنتن WiFi...';
    notifyListeners();

    try {
      await _antennaSubscription?.cancel();
      final generationForConnection = ++_antennaConnectionGeneration;

      _antennaSubscription = _antennaService.jsonStream.listen(
        (jsonText) {
          // Backpressure: do not spawn unbounded SQLite writes when ESP sends
          // a burst. ACK is sent only after the Inbox row is durable.
          final subscription = _antennaSubscription;
          subscription?.pause();
          _antennaService.pauseReading();
          unawaited(_handleAntennaWebSocketText(
            jsonText, generationForConnection,
          ).whenComplete(() {
            if (generationForConnection == _antennaConnectionGeneration) {
              subscription?.resume();
              _antennaService.resumeReading();
            }
          }));
        },
        onError: (Object error) {
          isAntennaConnected = false;
          antennaStatus = 'خطا در دریافت داده WiFi';
          notifyListeners();
          _scheduleAntennaReconnect();
        },
        onDone: () {
          isAntennaConnected = false;
          antennaStatus = 'اتصال WiFi قطع شد';
          notifyListeners();
          _scheduleAntennaReconnect();
        },
      );

      await _antennaDisconnectSubscription?.cancel();
      _antennaDisconnectSubscription =
          _antennaService.disconnectStream.listen((_) {
        if (!_allowAntennaReconnect || _userRequestedDisconnect) return;
        isAntennaConnected = false;
        antennaStatus = 'اتصال WebSocket قطع شد';
        notifyListeners();
        _scheduleAntennaReconnect();
      });

      antennaStatus = 'در حال اتصال به WiFi آنتن...';
      notifyListeners();

      // First honor Wi-Fi already selected by the user in Android settings.
      // A successful manual connection can therefore register a new antenna.
      final currentSsid = await AntennaWifiConnector.currentWifiSsid();
      var connectedOnCurrentWifi = false;
      if (!isAutoReconnect || currentSsid == appSettings.wifiSsid) {
        try {
          await _antennaService.connect(url: appSettings.wifiWebSocketUrl);
          connectedOnCurrentWifi = true;
        } catch (_) {
          // Not necessarily an antenna network: try the saved Wi-Fi below.
        }
      }
      if (!connectedOnCurrentWifi) {
        antennaStatus = 'در حال اتصال به دستگاه ذخیره‌شده...';
        notifyListeners();
        final wifiAssociated = await AntennaWifiConnector.connectToAntennaWifi(
          ssid: appSettings.wifiSsid, password: appSettings.wifiPassword,
        ).timeout(const Duration(seconds: 25));
        if (!wifiAssociated) throw StateError('اتصال به Wi-Fi دستگاه برقرار نشد');
        await _antennaService.connect(url: appSettings.wifiWebSocketUrl);
      }

      // Persist only a positively identified SSID after a working WebSocket
      // handshake. The OS does NOT allow reading the manually entered key.
      if (!isAutoReconnect && connectedOnCurrentWifi &&
          currentSsid != null && currentSsid != appSettings.wifiSsid) {
        // Android exposes the SSID after manual selection, not the password.
        // Never reuse the previous antenna's password for another network.
        appSettings = appSettings.copyWith(
          wifiSsid: currentSsid,
          wifiPassword: '',
        );
        await AppSettingsService.saveSettings(appSettings);
      }

      // GNSS was started before the Wi-Fi handshake. Do not block the
      // WebSocket or its ACK path waiting for a slow first satellite fix.
      gpsStatus = _phoneGps.statusAt(DateTime.now());

      antennaStatus = 'در حال ارسال ساعت گوشی به ESP...';
      notifyListeners();
      await _antennaService.syncClockWithPhone();

      // Reconnecting the antenna must not zero out a day's observations.
      await LiveHerdSessionService.ensureSession();

      await AntennaLogService.addLog(
        type: AntennaLogType.connected,
        title: 'اتصال WiFi برقرار شد',
        message: _antennaService.connectedDeviceName,
      );

      _antennaReconnectAttempt = 0;
      if (!isAutoReconnect) unawaited(_rememberConnectIntent(true));
      isAntennaConnected = true;
      antennaStatus = 'متصل به ${appSettings.wifiSsid}';
      notifyListeners();
      return true;
    } catch (error) {
      await _antennaSubscription?.cancel();
      _antennaSubscription = null;
      await _antennaService.disconnect();

      await AntennaLogService.addLog(
        type: AntennaLogType.error,
        title: 'خطا در اتصال WiFi',
        message: error.toString(),
      );

      isAntennaConnected = false;
      antennaStatus = isAutoReconnect
          ? 'اتصال مجدد ناموفق؛ تلاش دوباره انجام می‌شود'
          : 'اتصال WiFi ناموفق';
      notifyListeners();

      return false;
    } finally {
      isAntennaConnecting = false;
      notifyListeners();
      if (isAutoReconnect && !isAntennaConnected) _scheduleAntennaReconnect();
    }
  }

  Future<void> disconnect() async {
    _antennaConnectionGeneration++;
    _userRequestedDisconnect = true;
    unawaited(_rememberConnectIntent(false));
    _allowAntennaReconnect = false;
    _cancelAntennaReconnect();

    await _antennaSubscription?.cancel();
    _antennaSubscription = null;
    await _antennaDisconnectSubscription?.cancel();
    _antennaDisconnectSubscription = null;

    await _antennaService.disconnect();
    await AntennaWifiConnector.releaseWifiNetwork();
    await _phoneGps.stopWatching();

    await AntennaLogService.addLog(
      type: AntennaLogType.disconnected,
      title: 'اتصال WiFi قطع شد',
      message: 'کاربر اتصال WiFi آنتن را قطع کرد.',
    );

    isAntennaConnected = false;
    isAntennaConnecting = false;
    antennaStatus = 'قطع';
    notifyListeners();
  }

  void _cancelAntennaReconnect({bool resetAttempt = true}) {
    _antennaReconnectTimer?.cancel();
    _antennaReconnectTimer = null;
    if (resetAttempt) _antennaReconnectAttempt = 0;
  }

  void _scheduleAntennaReconnect() {
    if (!_allowAntennaReconnect) return;
    if (isAntennaConnecting || _antennaService.isConnected) return;
    if (_antennaReconnectTimer?.isActive == true) return;

    _antennaReconnectAttempt++;
    isAntennaConnected = false;
    final delaySeconds = [3, 6, 12, 24, 30][
      (_antennaReconnectAttempt - 1).clamp(0, 4).toInt()];
    antennaStatus =
        'اتصال قطع شد؛ تلاش $_antennaReconnectAttempt تا $delaySeconds ثانیه دیگر...';
    notifyListeners();

    _antennaReconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      _antennaReconnectTimer = null;
      if (!_userRequestedDisconnect && _allowAntennaReconnect) {
        unawaited(connect(isAutoReconnect: true));
      }
    });
  }

  Future<void> _handleAntennaWebSocketText(
    String jsonText,
    int generation,
  ) async {
    try {
      final frame = AntennaWsFrame.parse(jsonText);

      if (frame.isControlMessage) {
        if (generation != _antennaConnectionGeneration) return;
        await _handleAntennaControlFrame(frame);
        return;
      }

      if (!frame.isDataMessage || !frame.hasRequiredDataFields) {
        await AntennaLogService.addLog(
          type: AntennaLogType.error,
          title: 'پیام نامعتبر از ESP',
          message: jsonText,
        );
        return;
      }

      // Freeze the PHONE GPS fix at WebSocket reception. The Inbox may be
      // processed minutes later, after the phone has moved.
      final incoming = frame.toInboxMessage();
      final phoneFix = _phoneGps.snapshotAt(incoming.receivedAtApp);
      if (phoneFix == null) {
        // Log the reason at most once per minute rather than once per tag;
        // high-rate ESP bursts must not flood SharedPreferences or UI.
        final now = DateTime.now();
        final lastLog = _lastMissingGpsLogAt;
        if (lastLog == null || now.difference(lastLog) >=
            const Duration(minutes: 1)) {
          _lastMissingGpsLogAt = now;
          unawaited(AntennaLogService.addLog(
            type: AntennaLogType.error,
            title: 'رکورد بدون GPS گوشی',
            message: _phoneGps.statusAt(now),
          ));
        }
        // Trigger recovery without delaying durable Inbox storage and ACK.
        unawaited(_phoneGps.recheck());
      }
      final inboxMessage = phoneFix == null ? incoming : incoming.copyWith(
        phoneLatitude: phoneFix.latitude,
        phoneLongitude: phoneFix.longitude,
        phoneAccuracy: phoneFix.accuracy,
        phoneFixAt: phoneFix.capturedAt,
      );
      final inserted =
          await DatabaseService.insertAntennaInboxMessage(inboxMessage);

      if (!inserted) {
        if (!await DatabaseService.antennaInboxDataMatches(inboxMessage)) {
          throw StateError('ESP MessageId collision or invalid Inbox insert');
        }
        _onDuplicate();
      }

      if (generation == _antennaConnectionGeneration &&
          _antennaService.isConnected) {
        try {
          await _antennaService.ack(inboxMessage.messageId);
        } catch (_) {
          // ESP will retransmit; the durable inbox safely de-duplicates it.
        }
      }

      unawaited(_scheduleInboxDrain());
    } catch (error) {
      await AntennaLogService.addLog(
        type: AntennaLogType.error,
        title: 'خطا در تحلیل پیام WebSocket',
        message: '$error\n$jsonText',
      );
      antennaStatus = 'پیام نامعتبر از ESP دریافت شد';
      notifyListeners();
    }
  }

  Future<void> _handleAntennaControlFrame(AntennaWsFrame frame) async {
    final type = frame.type ?? '';

    switch (type) {
      case 'hello':
        antennaStatus = 'ارتباط با ESP برقرار شد';
        break;
      case 'time_synced':
        antennaStatus = 'ساعت ESP تنظیم شد؛ فعال‌سازی صف...';
        notifyListeners();
        await _antennaService.subscribe();
        return;
      case 'time_error':
        antennaStatus = 'خطا در تنظیم ساعت ESP';
        isAntennaConnected = false;
        break;
      case 'time_busy':
        antennaStatus = 'ESP توسط اتصال دیگری در حال استفاده است';
        isAntennaConnected = false;
        break;
      case 'time_status':
        antennaStatus = 'وضعیت ساعت ESP دریافت شد';
        break;
      case 'subscribed':
        antennaStatus = 'متصل و آماده دریافت';
        isAntennaConnected = true;
        break;
      case 'busy':
        antennaStatus = 'ESP در حال استفاده توسط اتصال دیگر است';
        isAntennaConnected = false;
        break;
      case 'storage_error':
        antennaStatus = 'خطای حافظه در ESP';
        isAntennaConnected = false;
        break;
      case 'ack_timeout':
        antennaStatus = 'مهلت ACK تمام شد؛ اتصال مجدد';
        isAntennaConnected = false;
        notifyListeners();
        _scheduleAntennaReconnect();
        return;
      default:
        antennaStatus = 'پیام ESP: $type';
    }

    notifyListeners();
  }

  Future<void> _scheduleInboxDrain() {
    _inboxDrainRequested = true;
    final current = _inboxDrainFuture;
    if (current != null) return current;

    final job = _runInboxDrain();
    _inboxDrainFuture = job;
    unawaited(job.whenComplete(() {
      _inboxDrainFuture = null;
      if (_inboxDrainRequested) unawaited(_scheduleInboxDrain());
    }));
    return job;
  }

  Future<void> _runInboxDrain() async {
    try {
      do {
        _inboxDrainRequested = false;
        var afterRowId = 0;

        while (true) {
          final batch = await DatabaseService.getPendingInboxBatch(
            afterRowId: afterRowId,
            limit: 50,
          );
          if (batch.isEmpty) break;

          for (final entry in batch) {
            afterRowId = entry.rowId;
            await _processInboxMessage(entry.message);
          }
        }
      } while (_inboxDrainRequested);
    } catch (error, stack) {
      debugPrint('Inbox drain stopped: $error\n$stack');
    }
  }

  Future<void> _processInboxMessage(AntennaInboxMessage message) async {
    try {
      if (await DatabaseService.isAntennaInboxMessageProcessed(
        message.messageId,
      )) {
        return;
      }

      var didInsertRecord = false;
      final result = await _receiveProcessor.processJsonText(
        jsonText: message.rawJson,
        locationName: appSettings.defaultLocationName,
        skipDuplicateCheck: true,
        capturePhoneLocation: false,
        phoneLocationAtReception: message.phoneFixAt == null ||
            message.phoneLatitude == null || message.phoneLongitude == null
            ? null
            : AppLocationResult(
                success: true,
                latitude: message.phoneLatitude,
                longitude: message.phoneLongitude,
                accuracy: message.phoneAccuracy,
                capturedAt: message.phoneFixAt,
                message: 'GPS گوشی هنگام دریافت',
              ),
        persistRecord: (record) async {
          didInsertRecord = await DatabaseService.commitInboxTagRecord(
            messageId: message.messageId,
            record: record,
          );
        },
      );

      if (!result.isSaved || result.record == null) {
        throw StateError('Inbox record was not saved: ${result.message}');
      }

      if (didInsertRecord) {
        lastAntennaJson = message.rawJson;
        _rolloverTodayCounters();
        if (RecordDayService.forRecord(result.record!) == _currentDayKey) {
          records.insert(0, result.record!);
          if (records.length > 200) records.removeLast();
          _todayTotal++;
        }
        if (isAntennaConnected) {
          antennaStatus = 'دریافت شد: ${result.tagId}';
        }
        _notifyIncomingThrottled();
      }
    } catch (error, stack) {
      try {
        if (!await DatabaseService.isAntennaInboxMessageProcessed(
          message.messageId,
        )) {
          await DatabaseService.markAntennaInboxMessageError(
            message.messageId,
            error,
          );
        }
        await AntennaLogService.addLog(
          type: AntennaLogType.error,
          title: 'خطای پردازش Inbox ESP',
          message: '${message.messageId}: $error',
        );
      } catch (_) {}
      debugPrint('Inbox processing failed: $error\n$stack');
    }
  }
}
