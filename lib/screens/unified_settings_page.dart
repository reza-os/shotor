import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/camel_backup_service.dart';

import '../models/app_settings.dart';
import '../models/sms_report_settings.dart';
import '../services/app_setting_service.dart';
import '../services/sms_report_settings_service.dart';
import '../services/sms_auto_sender_service.dart';
import '../services/sms_report_builder_service.dart';
import '../services/direct_sms_service.dart';
import '../services/antenna_wifi_connector.dart';

/// Single entry point for shepherd, herd, antenna and SMS configuration.
/// AppSettings and SmsReportSettings retain their independent persistence
/// contracts; opening an accordion never saves partial edits automatically.
class UnifiedSettingsPage extends StatefulWidget {
  const UnifiedSettingsPage({super.key});

  @override
  State<UnifiedSettingsPage> createState() => _UnifiedSettingsPageState();
}

class _UnifiedSettingsPageState extends State<UnifiedSettingsPage> {
  static const _brown = Color(0xFFA4542D);
  static const _dark = Color(0xFF21463C);
  static const _bg = Color(0xFFFFF8F4);

  final _shepherdName = TextEditingController();
  final _shepherdId = TextEditingController();
  final _centerPhone = TextEditingController();
  final _herdName = TextEditingController();
  final _herdId = TextEditingController();
  final _camelCount = TextEditingController();
  final _wifiSsid = TextEditingController();
  final _wifiPassword = TextEditingController();
  final _wifiUrl = TextEditingController();
  final _deviceId = TextEditingController();
  final _locationName = TextEditingController();
  final _smsPhone = TextEditingController();

  AppSettings _system = const AppSettings();
  SmsReportSettings _sms = const SmsReportSettings();
  bool _loading = true;
  bool _saving = false;
  bool _sendingTest = false;
  bool _showPassword = false;
  bool _backupBusy = false;
  bool _folderSelected = false;
  String _backupMessage = '';
  int? _expanded; // Only one settings area open at once.

  @override
  void initState() {
    super.initState();
    _load();
    _refreshBackupFolder();
  }

  Future<void> _load() async {
    final system = await AppSettingsService.loadSettings();
    final sms = await SmsReportSettingsService.loadSettings();
    if (!mounted) return;
    _shepherdName.text = system.shepherdName;
    _shepherdId.text = system.shepherdId;
    _centerPhone.text = system.centerPhone;
    _herdName.text = system.herdName;
    _herdId.text = system.herdId;
    _camelCount.text = system.camelCount.toString();
    _wifiSsid.text = system.wifiSsid;
    _wifiPassword.text = system.wifiPassword;
    _wifiUrl.text = system.wifiWebSocketUrl;
    _deviceId.text = system.deviceId;
    _locationName.text = system.defaultLocationName;
    _smsPhone.text = sms.phoneNumber;
    setState(() {
      _system = system;
      _sms = sms;
      _loading = false;
    });
  }

  Future<void> _refreshBackupFolder() async {
    try {
      final value = await CamelBackupService.hasSelectedFolder();
      if (mounted) setState(() => _folderSelected = value);
    } catch (_) {
      if (mounted) setState(() => _folderSelected = false);
    }
  }

  Future<void> _chooseBackupFolder() async {
    if (_backupBusy) return;
    setState(() => _backupBusy = true);
    try {
      final selected = await CamelBackupService.selectFolder();
      await _refreshBackupFolder();
      if (mounted) _notify(selected
          ? 'پوشه Shotor شامل عکس‌ها و فایل‌های بک‌آپ ساخته شد.'
          : 'انتخاب پوشه لغو شد.');
    } catch (error) {
      if (mounted) _notify('انتخاب پوشه ناموفق بود: $error');
    } finally {
      if (mounted) setState(() => _backupBusy = false);
    }
  }

  Future<void> _createBackup() async {
    if (_backupBusy) return;
    setState(() => _backupBusy = true);
    try {
      final result = await CamelBackupService.exportBackup();
      if (!mounted) return;
      setState(() => _backupMessage =
          '${result.camels} شتر و ${result.photosInZip} عکس داخل ZIP ذخیره شد. '
          '${result.photosMirrored} عکس در پوشه عکس‌ها کپی شد.');
      _notify('بک‌آپ با موفقیت در فایل‌منیجر ذخیره شد.');
    } catch (error) {
      if (mounted) _notify('بک‌آپ انجام نشد: $error');
    } finally {
      if (mounted) setState(() => _backupBusy = false);
    }
  }

  Future<void> _importBackup() async {
    if (_backupBusy) return;
    setState(() => _backupBusy = true);
    try {
      final file = await CamelBackupService.pickBackup();
      if (file == null) return;
      final details = await CamelBackupService.inspect(file);
      if (!mounted) return;
      final accepted = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('بازیابی اطلاعات شترها'),
          content: Text('این فایل شامل ${details.camelCount} شتر و '
              '${details.photoCount} عکس است. شترهای جدید اضافه و '
              'شترهای هم‌تگ با اطلاعات این فایل به‌روز می‌شوند. '
              'شترهای دیگر حذف نمی‌شوند. ادامه می‌دهید؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('انصراف')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('بازیابی')),
          ],
        ),
      );
      if (accepted != true) return;
      final result = await CamelBackupService.importBackup(file);
      if (!mounted) return;
      setState(() => _backupMessage =
          '${result.camels} شتر بازیابی شد. ${result.details} اطلاعات تکمیلی ثبت شد.');
      _notify('اطلاعات شترها و عکس‌ها بازیابی شدند.');
    } catch (error) {
      if (mounted) _notify('بازیابی انجام نشد: $error');
    } finally {
      if (mounted) setState(() => _backupBusy = false);
    }
  }

  Widget _backupSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      OutlinedButton.icon(
        onPressed: _backupBusy ? null : _chooseBackupFolder,
        icon: const Icon(Icons.folder_open_rounded, size: 20),
        label: Text(_folderSelected ? 'تغییر پوشه' : 'انتخاب پوشه'),
      ),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: FilledButton.icon(
          onPressed: (!_folderSelected || _backupBusy) ? null : _createBackup,
          style: FilledButton.styleFrom(backgroundColor: _brown),
          icon: const Icon(Icons.archive_outlined, size: 19),
          label: const Text('بک‌آپ'),
        )),
        const SizedBox(width: 8),
        Expanded(child: OutlinedButton.icon(
          onPressed: _backupBusy ? null : _importBackup,
          icon: const Icon(Icons.unarchive_outlined, size: 19),
          label: const Text('بازیابی'),
        )),
      ]),
      if (_backupBusy) const Padding(
        padding: EdgeInsets.only(top: 10),
        child: LinearProgressIndicator(),
      ),
      if (_backupMessage.isNotEmpty) Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Text(_backupMessage,
            style: const TextStyle(fontSize: 12, color: Color(0xFF326A56))),
      ),
    ],
  );

  @override
  void dispose() {
    for (final controller in [
      _shepherdName, _shepherdId, _centerPhone, _herdName, _herdId,
      _camelCount, _wifiSsid, _wifiPassword, _wifiUrl, _deviceId,
      _locationName, _smsPhone,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final wifiUrl = _wifiUrl.text.trim();
    final uri = Uri.tryParse(wifiUrl);
    if (uri == null || !['ws', 'wss'].contains(uri.scheme) || uri.host.isEmpty) {
      _notify('آدرس WebSocket باید با ws:// یا wss:// شروع شود.');
      setState(() => _expanded = 2);
      return;
    }
    final count = int.tryParse(_camelCount.text.trim());
    if (count == null || count < 0) {
      _notify('تعداد شترها باید عدد صحیح و غیرمنفی باشد.');
      setState(() => _expanded = 1);
      return;
    }
    if (_sms.scheduled && _smsPhone.text.trim().isEmpty) {
      _notify('شماره مقصد پیامک را وارد کنید.');
      setState(() => _expanded = 3);
      return;
    }
    if (_sms.scheduled && !await DirectSmsService.requestSmsPermission()) {
      if (mounted) _notify('برای زمان‌بندی، مجوز ارسال پیامک لازم است.');
      return;
    }
    setState(() => _saving = true);
    try {
      final system = _system.copyWith(
        shepherdName: _shepherdName.text.trim(),
        shepherdId: _shepherdId.text.trim(),
        centerPhone: _centerPhone.text.trim(),
        herdName: _herdName.text.trim(),
        herdId: _herdId.text.trim(),
        camelCount: count,
        wifiSsid: _wifiSsid.text.trim(),
        wifiPassword: _wifiPassword.text,
        wifiWebSocketUrl: wifiUrl,
        deviceId: _deviceId.text.trim(),
        defaultLocationName: _locationName.text.trim(),
      );
      final sms = _sms.copyWith(phoneNumber: _smsPhone.text.trim());
      await AppSettingsService.saveSettings(system);
      await SmsReportSettingsService.saveSettings(sms);
      await SmsAutoSenderService.restart();
      if (!mounted) return;
      setState(() { _system = system; _sms = sms; });
      _notify('تنظیمات ذخیره شدند.');
    } catch (_) {
      if (mounted) _notify('ذخیره تنظیمات انجام نشد. دوباره تلاش کنید.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  SmsReportSettings get _currentSms =>
      _sms.copyWith(phoneNumber: _smsPhone.text.trim());

  Future<void> _previewSms() async {
    try {
      final message = await SmsReportBuilderService.buildCurrentMessage(_currentSms);
      if (!mounted) return;
      await showDialog<void>(context: context, builder: (dialogContext) =>
        AlertDialog(title: const Text('پیش‌نمایش پیامک'),
          content: SingleChildScrollView(child: SelectableText(message,
            textDirection: TextDirection.rtl)),
          actions: [
            TextButton.icon(onPressed: () async {
              await Clipboard.setData(ClipboardData(text: message));
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            }, icon: const Icon(Icons.copy_rounded), label: const Text('کپی متن')),
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('بستن')),
          ]));
    } catch (_) { if (mounted) _notify('ساخت پیش‌نمایش پیامک ممکن نشد.'); }
  }

  Future<void> _sendNowSms() async {
    if (_sendingTest) return;
    final sms = _currentSms;
    if (sms.phoneNumber.isEmpty) {
      _notify('شماره مقصد پیامک را وارد کنید.');
      return;
    }
    setState(() => _sendingTest = true);
    try {
      final message = await SmsReportBuilderService.buildCurrentMessage(sms);
      if (!mounted) return;
      final accepted = await showDialog<bool>(context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('ارسال پیامک'),
          content: SingleChildScrollView(child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('به: ${sms.phoneNumber}', textDirection: TextDirection.ltr),
              const SizedBox(height: 12),
              SelectableText(message, textDirection: TextDirection.rtl),
            ],
          )),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('انصراف')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('ارسال')),
          ],
        ),
      );
      if (accepted != true) return;
      await DirectSmsService.sendDirectSms(
        phoneNumber: sms.phoneNumber, message: message);
      if (mounted) _notify('درخواست ارسال پیامک به شبکه ثبت شد.');
    } catch (error) {
      if (mounted) _notify('ارسال انجام نشد: $error');
    } finally {
      if (mounted) setState(() => _sendingTest = false);
    }
  }

  Future<void> _readCurrentWifi() async {
    final ssid = await AntennaWifiConnector.currentWifiSsid();
    if (!mounted) return;
    if (ssid == null) {
      _notify('نام وای‌فای قابل خواندن نیست؛ اجازه موقعیت مکانی و اتصال Wi-Fi را بررسی کنید.');
      return;
    }
    setState(() {
      if (_wifiSsid.text.trim() != ssid) _wifiPassword.clear();
      _wifiSsid.text = ssid;
    });
    _notify('نام شبکه فعلی دریافت شد؛ رمز شبکه جدید را در صورت نیاز وارد کنید و ذخیره بزنید.');
  }

  void _notify(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Widget _field(String title, TextEditingController controller, IconData icon,
      {TextInputType type = TextInputType.text, bool ltr = false,
       bool obscured = false, Widget? suffix}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: type,
        obscureText: obscured,
        textDirection: ltr ? TextDirection.ltr : TextDirection.rtl,
        decoration: InputDecoration(
          labelText: title,
          prefixIcon: Icon(icon, color: _brown, size: 20),
          suffixIcon: suffix,
          filled: true,
          fillColor: const Color(0xFFF7F5F4),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        ),
      ),
    );
  }

  Widget _switch(String label, bool value, ValueChanged<bool> changed,
      {String? detail}) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: detail == null ? null : Text(detail, style: const TextStyle(fontSize: 11)),
      value: value, activeTrackColor: const Color(0xFFD0E9DF),
      activeThumbColor: const Color(0xFF167B5A),
      onChanged: (v) => setState(() => changed(v)),
    );
  }

  Widget _section(int index, String label, String summary, IconData icon, Widget child,
      Color tone) {
    final expanded = _expanded == index;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: expanded ? tone.withValues(alpha: .35) : const Color(0xFFF0E5DF)),
        boxShadow: [BoxShadow(color: const Color(0xFF7A3D1E).withValues(alpha: .045),
          blurRadius: 15, offset: const Offset(0, 5))]),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        InkWell(
          onTap: () => setState(() => _expanded = expanded ? null : index),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(children: [
              CircleAvatar(radius: 23, backgroundColor: tone.withValues(alpha: .12),
                child: Icon(icon, color: tone)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(summary, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF897A72)))])),
              Icon(expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                color: tone),
            ]),
          ),
        ),
        if (expanded) ...[
          const Divider(height: 1, color: Color(0xFFF4ECE8)),
          Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 6), child: child),
        ],
      ]),
    );
  }

  Widget _shepherdSection() => Column(children: [
    _field('نام ساربان', _shepherdName, Icons.person_outline_rounded),
    _field('شناسه ساربان', _shepherdId, Icons.badge_outlined, ltr: true),
    _field('شماره مرکز / مدیر', _centerPhone, Icons.phone_outlined,
      type: TextInputType.phone, ltr: true),
  ]);

  Widget _herdSection() => Column(children: [
    _field('نام گله', _herdName, Icons.pets_rounded),
    _field('شناسه گله', _herdId, Icons.badge_outlined, ltr: true),
    _field('تعداد کل شترها (مقدار تنظیمی)', _camelCount,
        Icons.format_list_numbered_rounded, type: TextInputType.number),
  ]);

  Widget _wifiSection() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    _field('نام شبکه آنتن (SSID)', _wifiSsid, Icons.wifi_rounded, ltr: true),
    Wrap(spacing: 8, runSpacing: 8, children: [
      OutlinedButton.icon(onPressed: () async {
        try { await AntennaWifiConnector.openWifiPanel(); }
        catch (_) { if (mounted) _notify('پنل Wi-Fi در دسترس نیست.'); }
      }, icon: const Icon(Icons.settings_input_antenna_rounded, size: 18),
        label: const Text('انتخاب Wi-Fi گوشی')),
      OutlinedButton.icon(onPressed: _readCurrentWifi,
        icon: const Icon(Icons.wifi_find_rounded, size: 18),
        label: const Text('خواندن نام شبکه')),
    ]),
    const SizedBox(height: 12),
    _field('رمز Wi-Fi آنتن', _wifiPassword, Icons.lock_outline_rounded,
      ltr: true, obscured: !_showPassword,
      suffix: IconButton(onPressed: () => setState(() => _showPassword = !_showPassword),
        icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility))),
    _field('آدرس WebSocket آنتن', _wifiUrl, Icons.link_rounded, ltr: true),
    _field('شناسه دستگاه', _deviceId, Icons.smartphone_rounded, ltr: true),
    _field('نام محل پیش‌فرض دریافت', _locationName, Icons.place_outlined),
    _switch('اتصال مجدد خودکار', _system.wifiAutoReconnect,
      (v) => _system = _system.copyWith(wifiAutoReconnect: v)),
    const Padding(padding: EdgeInsets.only(bottom: 12),
      child: Text('پس از اتصال دستی به آنتن و موفقیت اتصال داخل برنامه، نام شبکه جدید به عنوان پیش‌فرض ثبت می‌شود. اندروید رمز شبکه‌ای را که دستی وارد کرده‌اید به برنامه نمی‌دهد؛ برای اتصال خودکار در شبکه جدید، رمز را اینجا نیز وارد و ذخیره کنید.',
        style: TextStyle(fontSize: 12, color: Color(0xFF7B6257), height: 1.6))),
  ]);

  Widget _smsSection() {
    Widget option(String name, bool current, SmsReportSettings Function(bool) update) =>
        _switch(name, current, (v) => _sms = update(v));
    final scheduled = _sms.schedule != 'now';
    final hour = _sms.hour.toString().padLeft(2, '0');
    final minute = _sms.minute.toString().padLeft(2, '0');
    const weekdays = {
      6: 'شنبه', 7: 'یکشنبه', 1: 'دوشنبه', 2: 'سه‌شنبه',
      3: 'چهارشنبه', 4: 'پنجشنبه', 5: 'جمعه',
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _field('شماره گیرنده', _smsPhone, Icons.phone_android_rounded,
        ltr: true, type: TextInputType.phone),
      const Text('زمان ارسال', style: TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Row(children: [
        for (final choice in const [
          ('now', 'هم‌اکنون'), ('daily', 'هر روز'), ('weekly', 'هر هفته'),
        ]) ...[
          Expanded(child: ChoiceChip(
            showCheckmark: false,
            label: FittedBox(child: Text(choice.$2)),
            selected: _sms.schedule == choice.$1,
            selectedColor: _brown.withValues(alpha: .16),
            onSelected: (_) => setState(() => _sms = _sms.copyWith(
              schedule: choice.$1, enabled: choice.$1 != 'now')),
          )),
          if (choice.$1 != 'weekly') const SizedBox(width: 4),
        ],
      ]),
      if (scheduled) ...[
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () async {
            final selected = await showTimePicker(context: context,
              initialTime: TimeOfDay(hour: _sms.hour, minute: _sms.minute));
            if (selected != null && mounted) {
              setState(() => _sms = _sms.copyWith(
                hour: selected.hour, minute: selected.minute));
            }
          },
          icon: const Icon(Icons.schedule_rounded),
          label: Text('ساعت ارسال (ایران): $hour:$minute'),
        ),
        if (_sms.schedule == 'weekly') Padding(
          padding: const EdgeInsets.only(top: 10),
          child: DropdownButtonFormField<int>(
            initialValue: _sms.weekday,
            decoration: InputDecoration(labelText: 'روز هفته', filled: true,
              fillColor: const Color(0xFFF7F5F4),
              border: OutlineInputBorder(borderSide: BorderSide.none,
                borderRadius: BorderRadius.circular(16))),
            items: weekdays.entries.map((day) => DropdownMenuItem<int>(
              value: day.key, child: Text(day.value))).toList(),
            onChanged: (day) {
              if (day != null) setState(() => _sms = _sms.copyWith(weekday: day));
            },
          ),
        ),
        option('فعال بودن ارسال خودکار', _sms.enabled,
          (v) => _sms.copyWith(enabled: v)),
      ],
      option('فقط هنگام وجود مشکل', _sms.sendOnlyIfHasProblem,
        (v) => _sms.copyWith(sendOnlyIfHasProblem: v)),
      const Divider(height: 20),
      const Text('محتوای پیام', style: TextStyle(fontWeight: FontWeight.w700)),
      option('تاریخ', _sms.includeDate, (v) => _sms.copyWith(includeDate: v)),
      option('دیده‌شده', _sms.includeSeenCount,
        (v) => _sms.copyWith(includeSeenCount: v)),
      option('دیده‌نشده', _sms.includeMissingCount,
        (v) => _sms.copyWith(includeMissingCount: v)),
      option('داخل محدوده', _sms.includeInsideAllowedCount,
        (v) => _sms.copyWith(includeInsideAllowedCount: v)),
      option('خارج محدوده', _sms.includeOutsideAllowedCount,
        (v) => _sms.copyWith(includeOutsideAllowedCount: v)),
      option('باتری ضعیف', _sms.includeLowBatteryCount,
        (v) => _sms.copyWith(includeLowBatteryCount: v)),
      option('آخرین دریافت', _sms.includeLastReceiveTime,
        (v) => _sms.copyWith(includeLastReceiveTime: v)),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: OutlinedButton.icon(
          onPressed: _previewSms,
          icon: const Icon(Icons.visibility_outlined, size: 18),
          label: const Text('پیش‌نمایش'))),
        const SizedBox(width: 8),
        Expanded(child: FilledButton.icon(
          onPressed: _sendingTest ? null : _sendNowSms,
          style: FilledButton.styleFrom(backgroundColor: _brown),
          icon: const Icon(Icons.send_rounded, size: 18),
          label: const Text('ارسال هم‌اکنون'))),
      ]),
      const SizedBox(height: 10),
      const Text('ارسال دوره‌ای در اندروید ممکن است با تأخیر انجام شود. برای فعال‌شدن زمان‌بندی، ذخیره را بزنید.',
        style: TextStyle(fontSize: 11, color: Color(0xFF8C7E76))),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(title: const Text('تنظیمات'), centerTitle: true,
          foregroundColor: Colors.white, backgroundColor: _dark),
        body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 500),
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 18, 16, 30), children: [
                const Text('تنظیمات سامانه', style: TextStyle(fontSize: 22,
                  fontWeight: FontWeight.w800, color: _dark)),
                const SizedBox(height: 5),
                const Text('برای ویرایش، یکی از بخش‌ها را باز کنید.',
                  style: TextStyle(color: Color(0xFF8C7E76), fontSize: 12)),
                const SizedBox(height: 20),
                _section(0, 'ساربان', _shepherdName.text, Icons.person_rounded,
                  _shepherdSection(), _brown),
                _section(1, 'گله', _herdName.text.isEmpty ? 'مشخصات گله' : _herdName.text,
                  Icons.pets_rounded, _herdSection(), const Color(0xFF2B826B)),
                _section(2, 'آنتن و Wi-Fi', _wifiSsid.text,
                  Icons.wifi_rounded, _wifiSection(), const Color(0xFF37779A)),
                _section(3, 'پیامک', _sms.scheduled ? (_sms.schedule == 'daily' ? 'ارسال روزانه' : 'ارسال هفتگی') : 'ارسال دستی',
                  Icons.sms_rounded, _smsSection(), const Color(0xFF9C6B42)),
                _section(4, 'بک‌آپ شترها و عکس‌ها',
                  _folderSelected ? 'پوشه فایل‌منیجر انتخاب شده' : 'انتخاب پوشه برای شروع',
                  Icons.backup_rounded, _backupSection(), const Color(0xFF317C67)),
                const SizedBox(height: 10),
                FilledButton.icon(onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(backgroundColor: _brown,
                    minimumSize: const Size(double.infinity, 54),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                  icon: _saving ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_rounded),
                  label: const Text('ذخیره تنظیمات')),
              ]))),
      ));
  }
}
