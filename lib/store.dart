// Delivery — حالة التطبيق والاتصال بـ Firebase (نفس قاعدة بيانات الموقع)
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notify.dart';

typedef Doc = Map<String, dynamic>;

final AppState app = AppState();

const activeStatuses = ['new', 'prep', 'ready', 'road'];

int asInt(dynamic v) => v is num ? v.toInt() : (int.tryParse('$v') ?? 0);
double? asD(dynamic v) => v is num ? v.toDouble() : null;
int msOf(dynamic v) {
  if (v is Timestamp) return v.millisecondsSinceEpoch;
  if (v is num) return v.toInt();
  return DateTime.now().millisecondsSinceEpoch;
}

int nowMs() => DateTime.now().millisecondsSinceEpoch;

String latinDigits(String s) {
  const ar = '٠١٢٣٤٥٦٧٨٩';
  const fa = '۰۱۲۳۴۵۶۷۸۹';
  final b = StringBuffer();
  for (final ch in s.split('')) {
    final i = ar.indexOf(ch);
    final j = fa.indexOf(ch);
    b.write(i >= 0 ? '$i' : (j >= 0 ? '$j' : ch));
  }
  return b.toString();
}

int? parseInt(String s) => int.tryParse(latinDigits(s).replaceAll(RegExp(r'[\s,.]'), ''));
String cleanPhone(String p) => latinDigits(p).replaceAll(RegExp(r'[\s.\-]'), '');
bool phoneOk(String p) => RegExp(r'^0[5-7]\d{8}$').hasMatch(p);

String fmt(num n) {
  final s = n.round().abs().toString();
  final b = StringBuffer(n < 0 ? '-' : '');
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  return b.toString();
}


/// كتابة في Firestore: تُحفظ في الهاتف فوراً وتظهر في الشاشة، ثم تُرسل حين يتوفر الاتصال.
/// لا ننتظر رد الخادم أكثر من 8 ثوانٍ حتى لا تعلق الأزرار مع الشبكة الضعيفة.
/// ترجع true إذا أكّد الخادم، و false إذا بقيت تنتظر الاتصال.
Future<bool> queued(Future<void> write) async {
  try {
    await write.timeout(const Duration(seconds: 8));
    return true;
  } on TimeoutException {
    return false;
  }
}

const pendingNote = 'سيُرسل عند عودة الاتصال';

String money(num n) => '${fmt(n)} دج';

String two(int n) => n.toString().padLeft(2, '0');
String clock(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${two(d.hour)}:${two(d.minute)}';
}

String ago(int ms) {
  final m = (nowMs() - ms) ~/ 60000;
  if (m < 1) return 'الآن';
  if (m < 60) return 'منذ $m د';
  final h = m ~/ 60;
  if (h < 24) return 'منذ $h سا';
  return 'منذ ${h ~/ 24} يوم';
}

String schedText(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = day.difference(today).inDays;
  final label = diff == 0 ? 'اليوم' : (diff == 1 ? 'غداً' : '${d.day}/${d.month}');
  return '$label ${clock(ms)}';
}

double? km(double? aLat, double? aLng, double? bLat, double? bLng) {
  if (aLat == null || aLng == null || bLat == null || bLng == null) return null;
  const r = 6371.0;
  final dLa = (bLat - aLat) * math.pi / 180, dLo = (bLng - aLng) * math.pi / 180;
  final x = math.sin(dLa / 2) * math.sin(dLa / 2) +
      math.cos(aLat * math.pi / 180) * math.cos(bLat * math.pi / 180) * math.sin(dLo / 2) * math.sin(dLo / 2);
  return 2 * r * math.atan2(math.sqrt(x), math.sqrt(1 - x));
}

String kmText(double? d) => d == null ? '' : (d < 1 ? '${(d * 1000).round()} م' : '${d.toStringAsFixed(1)} كم');

List<Doc> optList(dynamic v) =>
    v is List ? v.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList() : <Doc>[];
bool hasOpts(Doc p) => optList(p['sizes']).isNotEmpty || optList(p['extras']).isNotEmpty;
int basePrice(Doc p) {
  final s = optList(p['sizes']);
  if (s.isNotEmpty) return s.map((x) => asInt(x['price'])).reduce(math.min);
  return asInt(p['price']);
}

int linePrice(Doc p, String size, List<String> extras) {
  int pr = asInt(p['price']);
  for (final z in optList(p['sizes'])) {
    if (z['name'] == size) pr = asInt(z['price']);
  }
  for (final e in optList(p['extras'])) {
    if (extras.contains(e['name'])) pr += asInt(e['price']);
  }
  return pr;
}

double? avgRating(Doc x) {
  final c = asInt(x['ratingCount']);
  if (c <= 0) return null;
  return asInt(x['ratingSum']) / c;
}

bool isAny(Doc o) => o['kind'] == 'any';

String optsText(Map i) {
  final a = <String>[];
  if ((i['size'] ?? '').toString().isNotEmpty) a.add(i['size']);
  final ex = i['extras'];
  if (ex is List && ex.isNotEmpty) a.add('+ ${ex.join('، ')}');
  if ((i['note'] ?? '').toString().isNotEmpty) a.add('«${i['note']}»');
  return a.join(' · ');
}

class CartLine {
  String pid;
  int qty;
  String size;
  List<String> extras;
  String note;
  CartLine({required this.pid, this.qty = 1, this.size = '', List<String>? extras, this.note = ''})
      : extras = extras ?? <String>[];

  Map<String, dynamic> toJson() => {'pid': pid, 'qty': qty, 'size': size, 'extras': extras, 'note': note};
  static CartLine fromJson(Map m) => CartLine(
      pid: '${m['pid']}',
      qty: asInt(m['qty']),
      size: '${m['size'] ?? ''}',
      extras: List<String>.from((m['extras'] as List?) ?? const []),
      note: '${m['note'] ?? ''}');

  String get key {
    final ex = List<String>.of(extras)..sort();
    return [pid, if (size.isNotEmpty) size, if (ex.isNotEmpty) '+${ex.join('+')}', if (note.isNotEmpty) note].join('|');
  }
}

class CartItem {
  final String key;
  final CartLine line;
  final Doc product;
  final int unit;
  CartItem(this.key, this.line, this.product, this.unit);
}

class CartInfo {
  final List<CartItem> items;
  final int subtotal, count, fee, discount;
  final Doc? coupon, shop, zone;
  final String couponErr;
  CartInfo(this.items, this.subtotal, this.count, this.fee, this.discount, this.coupon, this.couponErr, this.shop, this.zone);
  int get total => subtotal - discount + fee;
}

class AppState extends ChangeNotifier {
  final FirebaseFirestore fs = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;
  late SharedPreferences _prefs;

  User? user;
  bool ready = false;
  List<Doc> zones = [], shops = [], products = [], banners = [], coupons = [], orders = [];
  Doc config = {};
  bool shopsLoaded = false, productsLoaded = false, ordersLoaded = false;
  final List<StreamSubscription> _subs = [];

  // session (saved on this phone)
  String name = '', phone = '', addr = '', zoneId = '', coupon = '';
  double? lat, lng;
  List<String> favs = [];
  Map<String, CartLine> cart = {};
  String? cartShop;
  Map<String, int> seen = {};
  String anyFrom = '', anyText = '', anyBudget = '';
  List<Map<String, dynamic>> places = []; // عناوين محفوظة: {label, zoneId, addr, lat, lng}
  List<String> seenPosts = []; // يوميات شاهدها الزبون (لتلوين حلقة المحل)

  void Function(String msg)? onToast;
  String? openChatId; // the chat currently on screen

  final Map<String, Uint8List?> _img = {};
  final Set<String> _imgLoading = {};
  final Map<String, String> _lastState = {};
  final Map<String, int> _lastMsgN = {};
  final Map<String, int> _lastPrepAt = {};
  final Set<String> _nearAlerted = {}; // طلبات نُبّه فيها الزبون أن الموصّل قريب

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs.getString('sess');
    if (raw != null) {
      try {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        name = m['name'] ?? '';
        phone = m['phone'] ?? '';
        addr = m['addr'] ?? '';
        zoneId = m['zoneId'] ?? '';
        coupon = m['coupon'] ?? '';
        lat = asD(m['lat']);
        lng = asD(m['lng']);
        favs = List<String>.from(m['favs'] ?? const []);
        cartShop = m['cartShop'];
        final c = m['cart'];
        if (c is Map) {
          c.forEach((k, v) {
            if (v is Map) cart['$k'] = CartLine.fromJson(v);
          });
        }
        final s = m['seen'];
        if (s is Map) s.forEach((k, v) => seen['$k'] = asInt(v));
        anyFrom = m['anyFrom'] ?? '';
        anyText = m['anyText'] ?? '';
        anyBudget = m['anyBudget'] ?? '';
        final sp = m['seenPosts'];
        if (sp is List) seenPosts = sp.map((x) => '$x').toList();
        final pl = m['places'];
        if (pl is List) places = pl.whereType<Map>().map((x) => Map<String, dynamic>.from(x)).toList();
      } catch (_) {}
    }
    auth.authStateChanges().listen((u) {
      user = u;
      ready = true;
      _stop();
      if (u != null) _start();
      notifyListeners();
    });
  }

  void save() {
    _prefs.setString(
        'sess',
        jsonEncode({
          'name': name,
          'phone': phone,
          'addr': addr,
          'zoneId': zoneId,
          'coupon': coupon,
          'lat': lat,
          'lng': lng,
          'favs': favs,
          'cartShop': cartShop,
          'cart': cart.map((k, v) => MapEntry(k, v.toJson())),
          'seen': seen,
          'anyFrom': anyFrom,
          'anyText': anyText,
          'anyBudget': anyBudget,
          'places': places,
          'seenPosts': seenPosts,
        }));
  }

  void toast(String m) => onToast?.call(m);

  void _stop() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    zones = [];
    shops = [];
    products = [];
    banners = [];
    coupons = [];
    orders = [];
    shopsLoaded = productsLoaded = ordersLoaded = false;
  }

  List<Doc> _docs(QuerySnapshot<Map<String, dynamic>> s) => s.docs.map((d) => <String, dynamic>{...d.data(), 'id': d.id}).toList();

  void _onErr(Object e) {
    if (e is FirebaseException && e.code == 'permission-denied') {
      toast('ليست لديك صلاحية. تأكد من نشر آخر قواعد حماية في Firestore.');
    } else {
      toast('تعذّر الاتصال بالخادم. تحقق من الإنترنت.');
    }
  }

  void _start() {
    final uid = user!.uid;
    _subs.add(fs.collection('zones').snapshots().listen((s) {
      zones = _docs(s);
      notifyListeners();
    }, onError: _onErr));
    _subs.add(fs.collection('shops').snapshots().listen((s) {
      shops = _docs(s);
      shopsLoaded = true;
      notifyListeners();
    }, onError: _onErr));
    _subs.add(fs.collection('products').snapshots().listen((s) {
      products = _docs(s);
      productsLoaded = true;
      notifyListeners();
    }, onError: _onErr));
    _subs.add(fs.collection('banners').snapshots().listen((s) {
      banners = _docs(s);
      notifyListeners();
    }, onError: (_) {}));
    _subs.add(fs.collection('coupons').where('active', isEqualTo: true).snapshots().listen((s) {
      coupons = _docs(s);
      notifyListeners();
    }, onError: (_) {}));
    _subs.add(fs.collection('config').doc('platform').snapshots().listen((s) {
      config = s.data() ?? {};
      notifyListeners();
    }, onError: (_) {}));
    _subs.add(fs.collection('orders').where('customerUid', isEqualTo: uid).snapshots().listen((s) {
      orders = _docs(s);
      for (final o in orders) {
        o['createdAtMs'] = msOf(o['createdAt']);
      }
      orders.sort((a, b) => (b['createdAtMs'] as int).compareTo(a['createdAtMs'] as int));
      final firstLoad = !ordersLoaded;
      ordersLoaded = true;
      for (final o in orders) {
        final id = o['id'] as String;
        final st = '${o['status']}|${o['courierUid'] ?? ''}';
        if (!firstLoad && _lastState[id] != null && _lastState[id] != st) {
          toast('طلب ${o['no'] ?? ''}: ${headOf(o)}');
          notify.update('order:$id', '${orderTitle(o)} · طلب ${o['no'] ?? ''}', headOf(o), 'track:$id');
        }
        _lastState[id] = st;
        final n = asInt(o['msgN']);
        if (!firstLoad && _lastMsgN[id] != null && n > _lastMsgN[id]! && o['lastMsgBy'] == 'courier' && openChatId != id) {
          toast('رسالة من الموصّل: ${o['lastMsgText'] ?? ''}');
          notify.update('chat:$id', 'رسالة من الموصّل · طلب ${o['no'] ?? ''}', '${o['lastMsgText'] ?? ''}', 'chat:$id');
        }
        _lastMsgN[id] = n;
        // المحل طلب وقتاً إضافياً للتحضير (أخّر وقت بدء التحضير)
        final pa = asInt(o['prepAt']), wasPa = _lastPrepAt[id];
        if (!firstLoad && wasPa != null && wasPa > 0 && pa - wasPa > 60000 && o['status'] == 'prep') {
          final eta = etaMin(o);
          final msg = 'يحتاج ${o['shopName'] ?? 'المحل'} وقتاً إضافياً لتحضير طلبك${eta == null ? '' : ' · يصلك بعد ~$eta د'}';
          toast(msg);
          notify.update('order:$id', '${orderTitle(o)} · طلب ${o['no'] ?? ''}', msg, 'track:$id');
        }
        _lastPrepAt[id] = pa;
        // الموصّل على بعد 400 م أو أقل من عنوان الزبون
        if (o['status'] == 'road' && o['cAt'] != null && nowMs() - asInt(o['cAt']) < 3 * 60000) {
          final d = km(asD(o['cLat']), asD(o['cLng']), asD(o['custLat']), asD(o['custLng']));
          if (d != null && d <= 0.4 && _nearAlerted.add(id) && !firstLoad) {
            final msg = 'الموصّل قريب منك (${d < 0.1 ? 'عند الباب تقريباً' : '${(d * 1000).round()} م'}). جهّز ${money(asInt(o['total']))}.';
            toast(msg);
            notify.update('order:$id', '${orderTitle(o)} · طلب ${o['no'] ?? ''}', msg, 'track:$id');
          }
        }
      }
      syncKeepAlive();
      notifyListeners();
    }, onError: _onErr));
  }

  // ---------------- البقاء متصلاً في الخلفية ----------------
  // بدون خدمة في المقدمة يجمّد أندرويد التطبيق في الخلفية فلا تصل تنبيهات الطلب.
  // نشغّلها (إشعار ثابت «نتابع طلبك») ما دام عند الزبون طلب جارٍ فقط.
  StreamSubscription<Position>? _keepAlive;
  AppLifecycleListener? _life;
  bool _keepAliveBusy = false;

  Future<void> syncKeepAlive() async {
    _life ??= AppLifecycleListener(onResume: syncKeepAlive);
    final need = activeOrders > 0;
    if (!need) {
      await _keepAlive?.cancel();
      _keepAlive = null;
      return;
    }
    if (_keepAlive != null || _keepAliveBusy || defaultTargetPlatform != TargetPlatform.android) return;
    _keepAliveBusy = true;
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.whileInUse || perm == LocationPermission.always) {
        _keepAlive = Geolocator.getPositionStream(
          locationSettings: AndroidSettings(
            accuracy: LocationAccuracy.low,
            distanceFilter: 1000,
            intervalDuration: const Duration(minutes: 5),
            foregroundNotificationConfig: const ForegroundNotificationConfig(
              notificationTitle: 'نتابع طلبك في Delivery',
              notificationText: 'تصلك التنبيهات حتى يصل طلبك، ثم يختفي هذا الإشعار',
              enableWakeLock: true,
              setOngoing: true,
            ),
          ),
        ).listen((_) {}, onError: (_) {
          // مثلاً بدأ والتطبيق في الخلفية (يمنعه أندرويد): نعيد المحاولة عند فتح التطبيق
          _keepAlive?.cancel();
          _keepAlive = null;
        });
      }
    } catch (_) {
      _keepAlive = null;
    }
    _keepAliveBusy = false;
  }

  /// بعد إرسال الطلب: أذونات الإشعارات والموقع (الخدمة في الخلفية تحتاج الموقع)
  Future<void> _afterOrder() async {
    await notify.requestPermission();
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) await Geolocator.requestPermission();
    } catch (_) {}
    await syncKeepAlive();
  }

  // ---------------- read helpers ----------------
  Doc? byId(List<Doc> l, String? id) {
    if (id == null) return null;
    for (final x in l) {
      if (x['id'] == id) return x;
    }
    return null;
  }

  Doc? shop(String? id) => byId(shops, id);
  Doc? product(String? id) => byId(products, id);
  Doc? order(String? id) => byId(orders, id);

  List<Doc> get activeZones {
    final z = zones.where((z) => z['active'] != false).toList();
    z.sort((a, b) => asInt(a['pos']).compareTo(asInt(b['pos'])));
    return z;
  }

  Doc? get currentZone {
    final a = activeZones;
    for (final z in a) {
      if (z['id'] == zoneId) return z;
    }
    return a.isEmpty ? null : a.first;
  }

  List<Doc> get visibleShops => shops.where((s) => s['active'] != false).toList();

  // ---------------- يوميات وإعلانات المحلات (الحقل posts في مستند المحل) ----------------
  /// منشورات المحل التي لم تنتهِ. kind: story أو ad. اليوميات من الأقدم للأحدث، والإعلانات الأحدث أولاً.
  List<Doc> postsOf(Doc shop, String kind) {
    final now = nowMs();
    final l = (shop['posts'] is List ? shop['posts'] as List : const [])
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .where((p) => p['kind'] == kind && asInt(p['until']) > now)
        .toList();
    l.sort((a, b) => kind == 'story' ? asInt(a['at']).compareTo(asInt(b['at'])) : asInt(b['at']).compareTo(asInt(a['at'])));
    return l;
  }

  Uint8List? postImage(Doc p) => image('${p['id']}', p['img'] == true, p['at']);

  bool storySeen(Doc shop) => postsOf(shop, 'story').every((p) => seenPosts.contains(p['id']));

  /// المحلات التي عندها يوميات اليوم: غير المشاهَدة أولاً، ثم الأحدث
  List<Doc> get storyShops {
    final l = visibleShops.where((s) => postsOf(s, 'story').isNotEmpty).toList();
    int last(Doc s) => postsOf(s, 'story').map((p) => asInt(p['at'])).fold(0, math.max);
    l.sort((a, b) {
      final sa = storySeen(a), sb = storySeen(b);
      if (sa != sb) return sa ? 1 : -1;
      return last(b).compareTo(last(a));
    });
    return l;
  }

  void markPostSeen(String id) {
    if (seenPosts.contains(id)) return;
    seenPosts.add(id);
    if (seenPosts.length > 300) seenPosts = seenPosts.sublist(seenPosts.length - 300);
    save();
    notifyListeners();
  }

  List<Doc> productsOf(String shopId) {
    final l = products.where((p) => p['shopId'] == shopId).toList();
    l.sort((a, b) {
      final c = '${a['section'] ?? ''}'.compareTo('${b['section'] ?? ''}');
      return c != 0 ? c : asInt(a['pos']).compareTo(asInt(b['pos']));
    });
    return l;
  }

  int _hm(String? s) {
    if (s == null || !RegExp(r'^\d{1,2}:\d{2}$').hasMatch(s)) return -1;
    final p = s.split(':');
    return int.parse(p[0]) * 60 + int.parse(p[1]);
  }

  bool withinHours(Doc s) {
    final h = s['hours'];
    if (h is! Map) return true;
    final f = _hm(h['from']), t = _hm(h['to']);
    if (f < 0 || t < 0) return true;
    final d = DateTime.now();
    final n = d.hour * 60 + d.minute;
    return f <= t ? (n >= f && n < t) : (n >= f || n < t);
  }

  bool isOpen(Doc? s) => s != null && s['open'] == true && withinHours(s);
  String closedLabel(Doc s) {
    final h = s['hours'];
    if (s['open'] == true && !withinHours(s) && h is Map) return 'مغلق · يفتح ${h['from']}';
    return 'مغلق';
  }

  int get anyCap => config['anyCap'] != null ? asInt(config['anyCap']) : 3000;
  int get anyExtra => config['anyExtra'] != null ? asInt(config['anyExtra']) : 0;
  bool get anyOn => config['anyOn'] != false;

  List<Doc> shopCoupons(String shopId) => coupons
      .where((c) => c['shopId'] == shopId && c['active'] != false && (c['until'] == null || nowMs() < asInt(c['until'])))
      .toList();
  List<Doc> get liveCoupons => coupons.where((c) {
        final s = shop(c['shopId']);
        return s != null && s['active'] != false && (c['until'] == null || nowMs() < asInt(c['until']));
      }).toList();

  String couponLabel(Doc c) => c['type'] == 'pct' ? 'خصم ${asInt(c['value'])}%' : 'خصم ${money(asInt(c['value']))}';

  String couponValid(Doc c, String shopId, int subtotal) {
    if (c['active'] == false || c['shopId'] != shopId) return 'هذا الرمز لا يعمل مع هذا المحل.';
    if (c['until'] != null && nowMs() > asInt(c['until'])) return 'انتهت صلاحية هذا الرمز.';
    if (asInt(c['minOrder']) > 0 && subtotal < asInt(c['minOrder'])) {
      return 'يعمل للطلبات من ${money(asInt(c['minOrder']))} فما فوق.';
    }
    if (c['once'] == true && orders.any((o) => o['couponId'] == c['id'] && o['status'] != 'cancelled' && o['status'] != 'rejected')) {
      return 'استعملت هذا الرمز من قبل.';
    }
    return '';
  }

  int couponOff(Doc c, int subtotal) {
    final v = c['type'] == 'pct' ? (subtotal * math.min(asInt(c['value']), 90) / 100).round() : asInt(c['value']);
    return v.clamp(0, subtotal).toInt();
  }

  CartInfo cartInfo() {
    final items = <CartItem>[];
    cart.forEach((k, l) {
      final p = product(l.pid);
      if (p != null) items.add(CartItem(k, l, p, linePrice(p, l.size, l.extras)));
    });
    final subtotal = items.fold<int>(0, (s, i) => s + i.unit * i.line.qty);
    final count = items.fold<int>(0, (s, i) => s + i.line.qty);
    final zone = currentZone;
    final fee = zone == null ? 0 : asInt(zone['fee']);
    final sh = shop(cartShop);
    Doc? cp;
    String err = '';
    int disc = 0;
    if (coupon.isNotEmpty && sh != null) {
      for (final c in coupons) {
        if (c['code'] == coupon && c['shopId'] == sh['id']) cp = c;
      }
      err = cp == null ? 'هذا الرمز غير صحيح أو لا يعمل مع هذا المحل.' : couponValid(cp, sh['id'], subtotal);
      if (err.isEmpty && cp != null) {
        disc = couponOff(cp, subtotal);
      } else {
        cp = null;
      }
    }
    return CartInfo(items, subtotal, count, fee, disc, cp, err, sh, zone);
  }

  int qtyInCart(String pid) => cart.values.where((l) => l.pid == pid).fold(0, (s, l) => s + l.qty);
  int get cartCount => cart.values.fold(0, (s, l) => s + l.qty);
  int get activeOrders => orders.where((o) => activeStatuses.contains(o['status'])).length;

  bool unread(Doc o) {
    if (openChatId == o['id']) return false;
    final n = asInt(o['msgN']);
    return n > 0 && o['lastMsgBy'] == 'courier' && n > (seen[o['id']] ?? 0);
  }

  bool get anyUnread => orders.any(unread);

  String headOf(Doc o) {
    final st = o['status'];
    if (isAny(o) && st == 'prep') return o['courierUid'] != null ? 'الموصّل يشتري طلبك الآن' : 'نبحث لك عن موصّل…';
    final sf = o['scheduledFor'];
    if (sf != null && (st == 'new' || st == 'prep') && asInt(sf) > nowMs() + 20 * 60000) return 'طلب مجدول ${schedText(asInt(sf))}';
    switch (st) {
      case 'new':
        return 'أُرسل طلبك إلى المحل';
      case 'prep':
        return 'المحل يحضّر طلبك';
      case 'ready':
        return 'طلبك جاهز وينتظر الموصّل';
      case 'road':
        return 'طلبك في الطريق إليك';
      case 'done':
        return 'تم التوصيل، بالهناء';
      case 'rejected':
        return 'اعتذر المحل عن طلبك';
      default:
        return 'أُلغي هذا الطلب';
    }
  }

  String orderTitle(Doc o) => isAny(o) ? 'اشترِ لي${(o['anyFrom'] ?? '').toString().isNotEmpty ? ': ${o['anyFrom']}' : ''}' : '${o['shopName'] ?? ''}';
  String orderLines(Doc o) {
    if (isAny(o)) return '${o['anyText'] ?? ''}'.split('\n').where((x) => x.trim().isNotEmpty).join(' · ');
    final it = o['items'];
    if (it is! List) return '';
    return it.map((i) => '${asInt(i['qty'])}× ${i['name']}').join(' · ');
  }

  int? etaMin(Doc o) {
    final s = shop(o['shopId']);
    const v = 0.33; // كم في الدقيقة (~20 كم/سا)
    final st = o['status'];
    if (st == 'road') {
      final d = km(asD(o['cLat']), asD(o['cLng']), asD(o['custLat']), asD(o['custLng']));
      return d == null ? null : math.max(2, (d / v * 1.3).round() + 2);
    }
    if (isAny(o)) return null;
    final sf = o['scheduledFor'];
    if (sf != null && asInt(sf) > nowMs() + 20 * 60000) return null;
    if (st == 'new' || st == 'prep' || st == 'ready') {
      final prep = s != null && asInt(s['prepMin']) > 0 ? asInt(s['prepMin']) : 15;
      final el = o['prepAt'] != null ? (nowMs() - asInt(o['prepAt'])) / 60000 : 0;
      final left = st == 'ready' ? 2 : math.max(3, prep - el);
      final d2 = km(asD(s?['lat']), asD(s?['lng']), asD(o['custLat']), asD(o['custLng']));
      return (left + (d2 != null ? d2 / v * 1.3 : 8) + (st == 'new' ? 3 : 0) + 3).round();
    }
    return null;
  }

  // ---------------- images (stored as data URLs in Firestore) ----------------
  Uint8List? image(String docId, bool has, dynamic v) {
    if (!has) return null;
    final key = '$docId:${v ?? 0}';
    if (_img.containsKey(key)) return _img[key];
    if (!_imgLoading.contains(key)) {
      _imgLoading.add(key);
      fs.collection('images').doc(docId).get().then((s) {
        final d = s.data()?['data'];
        Uint8List? bytes;
        if (d is String && d.contains(',')) {
          try {
            bytes = base64Decode(d.substring(d.indexOf(',') + 1));
          } catch (_) {}
        }
        _img[key] = bytes;
        notifyListeners();
      }).catchError((_) {
        _img[key] = null;
      });
    }
    return null;
  }

  Uint8List? productImage(Doc p) => image(p['id'], p['hasImg'] == true, p['imgV']);
  Uint8List? shopCover(Doc s) => image('cover_${s['id']}', s['hasCover'] == true, s['coverV']);
  Uint8List? dataUrl(String? d) {
    if (d == null || !d.contains(',')) return null;
    final key = 'url:${d.length}:${d.hashCode}';
    if (_img.containsKey(key)) return _img[key];
    try {
      _img[key] = base64Decode(d.substring(d.indexOf(',') + 1));
    } catch (_) {
      _img[key] = null;
    }
    return _img[key];
  }

  // ---------------- actions ----------------
  Future<void> signInAnon() => auth.signInAnonymously();
  Future<void> signOut() async {
    cart.clear();
    cartShop = null;
    save();
    await auth.signOut();
  }

  static const maxPlaces = 5;

  /// يحفظ العنوان الحالي باسم (البيت، العمل…). نفس الاسم يستبدل القديم.
  String savePlace(String label) {
    final l = label.trim();
    if (l.isEmpty) return 'اكتب اسماً للعنوان.';
    if (zoneId.isEmpty || addr.trim().isEmpty) return 'اختر الحي واكتب وصف العنوان أولاً.';
    final p = {'label': l.length > 20 ? l.substring(0, 20) : l, 'zoneId': zoneId, 'addr': addr.trim(), 'lat': lat, 'lng': lng};
    final i = places.indexWhere((x) => x['label'] == p['label']);
    if (i >= 0) {
      places[i] = p;
    } else {
      if (places.length >= maxPlaces) return 'يمكنك حفظ $maxPlaces عناوين فقط. احذف واحداً أولاً.';
      places.add(p);
    }
    save();
    notifyListeners();
    toast('حُفظ العنوان «${p['label']}»');
    return '';
  }

  void usePlace(Map<String, dynamic> p) {
    zoneId = '${p['zoneId'] ?? ''}';
    addr = '${p['addr'] ?? ''}';
    lat = asD(p['lat']);
    lng = asD(p['lng']);
    save();
    notifyListeners();
  }

  void deletePlace(Map<String, dynamic> p) {
    places.remove(p);
    save();
    notifyListeners();
  }

  /// هل العنوان الحالي هو هذا العنوان المحفوظ؟
  bool isPlace(Map<String, dynamic> p) => p['zoneId'] == zoneId && p['addr'] == addr.trim();

  void setZone(String id) {
    zoneId = id;
    save();
    notifyListeners();
  }

  void toggleFav(String id) {
    if (favs.contains(id)) {
      favs.remove(id);
    } else {
      favs.add(id);
      toast('أُضيف إلى المفضلة');
    }
    save();
    notifyListeners();
  }

  /// يرجع false إذا كانت السلة من محل آخر (يجب سؤال الزبون أولاً)
  bool addLine(Doc p, CartLine l, {bool replace = false}) {
    if (cartShop != null && cartShop != p['shopId'] && cart.isNotEmpty && !replace) return false;
    if (replace || (cartShop != p['shopId'])) {
      if (cartShop != p['shopId']) {
        cart.clear();
        coupon = '';
      }
    }
    cartShop = p['shopId'];
    final k = l.key;
    if (cart.containsKey(k)) {
      cart[k]!.qty += l.qty;
    } else {
      cart[k] = l;
    }
    save();
    notifyListeners();
    return true;
  }

  void changeQty(String key, int d) {
    final l = cart[key];
    if (l == null) return;
    l.qty += d;
    if (l.qty <= 0) cart.remove(key);
    if (cart.isEmpty) {
      cartShop = null;
      coupon = '';
    }
    save();
    notifyListeners();
  }

  void setCoupon(String c) {
    coupon = c.trim().toUpperCase();
    save();
    notifyListeners();
  }

  String? addressError() {
    if (name.trim().length < 2) return 'اكتب اسمك ليعرفك الموصّل.';
    if (!phoneOk(cleanPhone(phone))) return 'اكتب رقم هاتف صحيحاً من 10 أرقام يبدأ بـ 05 أو 06 أو 07.';
    if (addr.trim().length < 4) return 'اكتب وصفاً للعنوان ليجدك الموصّل، مثل أقرب معلم.';
    if (currentZone == null) return 'لا توجد أحياء متاحة للتوصيل الآن.';
    return null;
  }

  Future<int> _withCounter(DocumentReference<Map<String, dynamic>> ref, Map<String, dynamic> order) {
    final counter = fs.collection('counters').doc('orders');
    return fs.runTransaction<int>((t) async {
      final s = await t.get(counter);
      final n = (s.exists ? asInt(s.data()?['n']) : 0) + 1;
      t.set(counter, {'n': n});
      order['no'] = n;
      t.set(ref, order);
      return n;
    });
  }

  Future<String> placeOrder({required String note, int? scheduledFor}) async {
    final ci = cartInfo();
    final sh = ci.shop!;
    final zone = ci.zone!;
    final ph = cleanPhone(phone);
    phone = ph;
    save();
    final ref = fs.collection('orders').doc();
    final order = <String, dynamic>{
      'kind': 'shop',
      'customerUid': user!.uid,
      'customerName': name.trim(),
      'shopId': sh['id'],
      'shopName': sh['name'],
      'items': ci.items.map((i) {
        final x = <String, dynamic>{'pid': i.product['id'], 'name': i.product['name'], 'price': i.unit, 'qty': i.line.qty};
        if (i.line.size.isNotEmpty) x['size'] = i.line.size;
        if (i.line.extras.isNotEmpty) x['extras'] = i.line.extras;
        if (i.line.note.isNotEmpty) x['note'] = i.line.note;
        return x;
      }).toList(),
      'discount': ci.discount,
      'coupon': ci.coupon?['code'],
      'couponId': ci.coupon?['id'],
      'scheduledFor': scheduledFor,
      'msgN': 0,
      'note': note.trim().length > 300 ? note.trim().substring(0, 300) : note.trim(),
      'zoneId': zone['id'],
      'zoneName': zone['name'],
      'address': addr.trim(),
      'phone': ph,
      'custLat': lat,
      'custLng': lng,
      'subtotal': ci.subtotal,
      'fee': ci.fee,
      'total': ci.total,
      'status': 'new',
      'courierUid': null,
      'offerTo': null,
      'settled': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    final n = await _withCounter(ref, order);
    cart.clear();
    cartShop = null;
    coupon = '';
    save();
    notifyListeners();
    toast('أُرسل طلبك رقم $n إلى ${sh['name']}');
    _afterOrder(); // لنخبرك بحالة طلبك والتطبيق في الخلفية
    return ref.id;
  }

  Future<String> placeAny() async {
    final zone = currentZone!;
    final budget = parseInt(anyBudget) ?? 0;
    final fee = asInt(zone['fee']) + anyExtra;
    final ph = cleanPhone(phone);
    phone = ph;
    final ref = fs.collection('orders').doc();
    final order = <String, dynamic>{
      'kind': 'any',
      'customerUid': user!.uid,
      'customerName': name.trim(),
      'shopId': null,
      'shopName': 'اشترِ لي',
      'anyFrom': anyFrom.trim(),
      'anyText': anyText.trim(),
      'anyBudget': budget,
      'items': [],
      'note': '',
      'zoneId': zone['id'],
      'zoneName': zone['name'],
      'address': addr.trim(),
      'phone': ph,
      'custLat': lat,
      'custLng': lng,
      'subtotal': budget,
      'discount': 0,
      'fee': fee,
      'total': budget + fee,
      'status': 'prep',
      'dispatch': 'pool',
      'courierUid': null,
      'offerTo': null,
      'settled': false,
      'msgN': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    final n = await _withCounter(ref, order);
    anyFrom = anyText = anyBudget = '';
    save();
    notifyListeners();
    toast('أُرسل طلبك رقم $n للموصّلين');
    _afterOrder();
    return ref.id;
  }

  Future<void> setStatus(String id, String status, [Map<String, dynamic>? extra]) async {
    final sent = await queued(
        fs.collection('orders').doc(id).update({'status': status, 'updatedAt': FieldValue.serverTimestamp(), ...?extra}));
    if (!sent) toast(pendingNote);
  }

  Future<void> rate(Doc o, int shopStars, int courierStars, String comment) async {
    final b = fs.batch();
    final c = comment.trim();
    b.set(fs.collection('reviews').doc(o['id']), {
      'shopId': o['shopId'],
      'courierUid': o['courierUid'],
      'shop': shopStars,
      'courier': courierStars,
      'comment': c.length > 300 ? c.substring(0, 300) : c,
      'name': '${o['customerName'] ?? ''}'.split(' ').first,
      'createdAt': FieldValue.serverTimestamp(),
    });
    b.update(fs.collection('orders').doc(o['id']), {
      'rated': true,
      'stars': {'shop': shopStars, 'courier': courierStars}
    });
    if (shopStars > 0 && o['shopId'] != null && shop(o['shopId']) != null) {
      b.update(fs.collection('shops').doc(o['shopId']),
          {'ratingSum': FieldValue.increment(shopStars), 'ratingCount': FieldValue.increment(1)});
    }
    if (courierStars > 0 && o['courierUid'] != null) {
      b.update(fs.collection('couriers').doc(o['courierUid']),
          {'ratingSum': FieldValue.increment(courierStars), 'ratingCount': FieldValue.increment(1)});
    }
    await b.commit();
    toast('شكراً! وصل تقييمك');
  }

  Future<void> sendMsg(String orderId, String text) async {
    final t = text.trim();
    if (t.isEmpty) return;
    final msg = t.length > 400 ? t.substring(0, 400) : t;
    final ref = fs.collection('orders').doc(orderId);
    final b = fs.batch();
    b.set(ref.collection('messages').doc(), {
      'by': 'customer',
      'uid': user!.uid,
      'text': msg,
      'atMs': nowMs(),
      'at': FieldValue.serverTimestamp(),
    });
    b.update(ref, {
      'msgN': FieldValue.increment(1),
      'lastMsgBy': 'customer',
      'lastMsgText': msg.length > 80 ? msg.substring(0, 80) : msg,
    });
    if (!await queued(b.commit())) toast('الرسالة $pendingNote');
  }

  void markSeen(String orderId) {
    final o = order(orderId);
    if (o == null) return;
    final n = asInt(o['msgN']);
    if ((seen[orderId] ?? 0) != n) {
      seen[orderId] = n;
      save();
    }
  }

  Future<List<Doc>> loadReviews(String shopId) async {
    final s = await fs.collection('reviews').where('shopId', isEqualTo: shopId).limit(40).get();
    final l = s.docs.map((d) => <String, dynamic>{...d.data(), 'id': d.id}).where((r) => asInt(r['shop']) > 0).toList();
    for (final r in l) {
      r['createdAtMs'] = msOf(r['createdAt']);
    }
    l.sort((a, b) => (b['createdAtMs'] as int).compareTo(a['createdAtMs'] as int));
    return l.take(20).toList();
  }
}

String errText(Object e) {
  if (e is FirebaseException) {
    switch (e.code) {
      case 'permission-denied':
        return 'ليست لديك صلاحية. تأكد من نشر آخر قواعد حماية في Firestore.';
      case 'unavailable':
        return 'لا يوجد اتصال بالخادم الآن. أعد المحاولة بعد قليل.';
      case 'admin-restricted-operation':
      case 'operation-not-allowed':
        return 'الدخول كزبون غير مفعّل في Firebase (Anonymous).';
      case 'network-request-failed':
        return 'لا يوجد اتصال بالإنترنت.';
    }
    return 'حدث خطأ (${e.code}).';
  }
  return 'حدث خطأ غير متوقع.';
}
