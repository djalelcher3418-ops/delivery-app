// إشعارات الهاتف: تظهر فقط والتطبيق في الخلفية أو الشاشة مطفأة.
// والتطبيق مفتوح تكفي الرسائل القصيرة داخل التطبيق.
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final Notifier notify = Notifier();

class Notifier {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  bool _foreground = true;
  AppLifecycleListener? _life;

  /// يُستدعى عند الضغط على إشعار، مع الحمولة (مثل chat:ORDER_ID)
  void Function(String payload)? onOpen;

  bool get inBackground => !_foreground;

  static const _updates = AndroidNotificationDetails(
    'orders',
    'طلباتي',
    channelDescription: 'حالة طلبك ورسائل الموصّل',
    importance: Importance.high,
    priority: Priority.high,
    category: AndroidNotificationCategory.message,
    visibility: NotificationVisibility.public,
  );

  Future<void> init() async {
    _life ??= AppLifecycleListener(onStateChange: (s) => _foreground = s == AppLifecycleState.resumed);
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
        onDidReceiveNotificationResponse: (r) {
          final p = r.payload;
          if (p != null && p.isNotEmpty) onOpen?.call(p);
        },
      );
      _ready = true;
    } catch (_) {}
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  /// يطلب إذن الإشعارات (أندرويد 13 فما فوق). يرجع true إذا كانت مسموحة.
  Future<bool> requestPermission() async {
    try {
      return await _android?.requestNotificationsPermission() ?? true;
    } catch (_) {
      return false;
    }
  }

  Future<bool?> enabled() async {
    try {
      return await _android?.areNotificationsEnabled();
    } catch (_) {
      return null;
    }
  }

  int _id(String key) => key.hashCode & 0x7fffffff;

  Future<void> _show(String key, String title, String body, AndroidNotificationDetails d, String payload) async {
    if (!_ready || _foreground) return;
    try {
      await _plugin.show(
        id: _id(key),
        title: title,
        body: body,
        notificationDetails: NotificationDetails(android: d),
        payload: payload,
      );
    } catch (_) {}
  }

  /// تحديث على طلب الزبون أو رسالة من الموصّل (نفس المعرّف يستبدل الإشعار السابق)
  Future<void> update(String key, String title, String body, String payload) =>
      _show(key, title, body, _updates, payload);
}
