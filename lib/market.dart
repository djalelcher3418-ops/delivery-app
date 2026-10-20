// سوق المدينة: إعلانات البيع والشراء بين الناس، والرسائل بين البائع والمشتري، والبلاغات
import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'notify.dart';
import 'store.dart';

final MarketState market = MarketState();

/// أقسام السوق
const marketCats = <(String, String)>[
  ('phones', 'هواتف'),
  ('electro', 'إلكترونيات'),
  ('home', 'أثاث وبيت'),
  ('clothes', 'ملابس'),
  ('vehicles', 'مركبات'),
  ('kids', 'أطفال'),
  ('other', 'أخرى'),
];

String marketCatLabel(String? id) => marketCats.firstWhere((c) => c.$1 == id, orElse: () => marketCats.last).$2;

const listingDays = 30; // مدة بقاء الإعلان
const maxListings = 10; // إعلانات منشورة في نفس الوقت لكل مستخدم
const maxPhotos = 4;
const hideAfterReports = 3; // يُخفى الإعلان ويذهب للمراجعة بعد 3 بلاغات من 3 أشخاص

const reportReasons = ['احتيال أو سعر وهمي', 'غرض ممنوع', 'محتوى غير لائق', 'إعلان مكرر أو مزعج', 'سبب آخر'];

/// كلمات ترسل الإعلان إلى المراجعة قبل نشره (إلى أن يتولى الذكاء الاصطناعي ذلك من الخادم)
const _flagWords = [
  'سلاح', 'مسدس', 'بندقية', 'ذخيرة', 'رصاص', 'مخدر', 'حشيش', 'زطلة', 'كيف', 'قرقوبي', 'كوكايين', 'هيروين',
  'حبوب مهلوسة', 'خمر', 'كحول', 'بيرة', 'ويسكي', 'شراب مسكر', 'تزوير', 'مزور', 'بطاقة تعريف', 'جواز سفر',
  'رخصة سياقة', 'قمار', 'رهان', 'دواء بدون وصفة', 'ترامادول', 'ليريكا', 'بريغابالين',
];

/// يرجع الكلمة المشبوهة الأولى في النص، أو null
String? flagWord(String text) {
  final t = text.toLowerCase();
  for (final w in _flagWords) {
    if (RegExp('(^|[\\s،,.!؟?«»"\'()-])$w').hasMatch(t)) return w;
  }
  return null;
}

String chatIdOf(String listingId, String buyerUid) => '${listingId}_$buyerUid';

class MarketState extends ChangeNotifier {
  FirebaseFirestore get fs => app.fs;
  String? get uid => app.user?.uid;

  List<Doc> listings = []; // المنشورة (live) ولم تنته مدتها
  List<Doc> mine = []; // إعلاناتي بكل حالاتها
  List<Doc> chats = [];
  bool loaded = false, chatsLoaded = false, banned = false;
  String? openChat; // المحادثة المفتوحة الآن (لا نرسل لها إشعاراً)

  final List<StreamSubscription> _subs = [];
  final Map<String, int> _lastN = {};
  final Map<String, Uint8List?> _img = {};
  final Set<String> _imgLoading = {};

  List<Doc> _docs(QuerySnapshot<Map<String, dynamic>> s) => s.docs.map((d) => <String, dynamic>{...d.data(), 'id': d.id}).toList();

  void start(String me) {
    stop();
    _subs.add(fs.collection('listings').where('status', isEqualTo: 'live').snapshots().listen((s) {
      final now = nowMs();
      listings = _docs(s).where((l) => asInt(l['until']) > now && l['sold'] != true).toList()
        ..sort((a, b) => asInt(b['at']).compareTo(asInt(a['at'])));
      loaded = true;
      notifyListeners();
    }, onError: (_) {
      loaded = true;
      notifyListeners();
    }));
    _subs.add(fs.collection('listings').where('uid', isEqualTo: me).snapshots().listen((s) {
      mine = _docs(s).where((l) => l['status'] != 'removed').toList()..sort((a, b) => asInt(b['at']).compareTo(asInt(a['at'])));
      notifyListeners();
    }, onError: (_) {}));
    _subs.add(fs.collection('bans').doc(me).snapshots().listen((s) {
      banned = s.exists;
      notifyListeners();
    }, onError: (_) {}));
    _subs.add(fs.collection('chats').where('users', arrayContains: me).snapshots().listen((s) {
      chats = _docs(s)..sort((a, b) => asInt(b['lastAt']).compareTo(asInt(a['lastAt'])));
      final first = !chatsLoaded;
      chatsLoaded = true;
      for (final c in chats) {
        final id = '${c['id']}', n = asInt(c['n']);
        if (!first && n > (_lastN[id] ?? 0) && c['lastBy'] != me && openChat != id) {
          notify.update('mchat:$id', 'رسالة عن «${c['title'] ?? ''}»', '${c['lastText'] ?? ''}', 'mchat:$id');
        }
        _lastN[id] = n;
      }
      notifyListeners();
    }, onError: (_) {}));
  }

  void stop() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    listings = [];
    mine = [];
    chats = [];
    loaded = chatsLoaded = banned = false;
    _lastN.clear();
  }

  Doc? listing(String? id) {
    for (final l in [...listings, ...mine]) {
      if (l['id'] == id) return l;
    }
    return null;
  }

  Doc? chat(String? id) {
    for (final c in chats) {
      if (c['id'] == id) return c;
    }
    return null;
  }

  bool unread(Doc c) => c['lastBy'] != uid && asInt(c['n']) > asInt((c['read'] as Map?)?[uid]);
  int get unreadCount => chats.where(unread).length;
  int get liveMine => mine.where((l) => l['status'] == 'live' && l['sold'] != true && asInt(l['until']) > nowMs()).length;

  // ---------------- الصور ----------------
  /// الصورة رقم i من صور الإعلان (تُحمَّل مرة واحدة ثم تبقى في الذاكرة)
  Uint8List? photo(Doc l, int i) {
    if (i >= asInt(l['imgN'])) return null;
    final key = '${l['id']}_$i';
    if (_img.containsKey(key)) return _img[key];
    if (_imgLoading.add(key)) {
      fs.collection('listingImages').doc(key).get().then((s) {
        final d = s.data()?['data'];
        Uint8List? b;
        if (d is String && d.contains(',')) {
          try {
            b = base64Decode(d.substring(d.indexOf(',') + 1));
          } catch (_) {}
        }
        _img[key] = b;
        notifyListeners();
      }).catchError((_) {
        _imgLoading.remove(key);
      });
    }
    return null;
  }

  // ---------------- النشر ----------------
  /// ينشر إعلاناً جديداً. يرجع رسالة خطأ أو '' عند النجاح، و review=true إذا ذهب للمراجعة
  Future<({String err, bool review})> post({
    required String title,
    required String desc,
    required String cat,
    required int price,
    required bool used,
    required String zoneId,
    required List<String> photos, // data URLs
  }) async {
    final me = uid;
    if (me == null) return (err: 'سجّل الدخول أولاً', review: false);
    if (banned) return (err: 'حسابك موقوف عن النشر في السوق.', review: false);
    if (liveMine >= maxListings) return (err: 'لك $maxListings إعلانات منشورة. احذف إعلاناً أو علّمه «بيع» قبل نشر جديد.', review: false);
    final zone = app.zones.cast<Doc?>().firstWhere((z) => z!['id'] == zoneId, orElse: () => null);
    final flag = flagWord('$title $desc');
    final now = nowMs();
    final ref = fs.collection('listings').doc();
    final b = fs.batch();
    for (int i = 0; i < photos.length; i++) {
      b.set(fs.collection('listingImages').doc('${ref.id}_$i'), {'uid': me, 'listingId': ref.id, 'data': photos[i]});
    }
    b.set(ref, {
      'uid': me,
      'name': app.name.trim(),
      'title': title.trim(),
      'desc': desc.trim(),
      'cat': cat,
      'price': price,
      'used': used,
      'zoneId': zoneId,
      'zoneName': zone?['name'] ?? '',
      'imgN': photos.length,
      'status': flag == null ? 'live' : 'review',
      if (flag != null) 'flag': 'كلمة تحتاج مراجعة: $flag',
      'reports': 0,
      'reporters': <String>[],
      'sold': false,
      'at': now,
      'until': now + listingDays * 86400000,
      'createdAt': FieldValue.serverTimestamp(),
    });
    try {
      if (!await queued(b.commit())) return (err: '', review: flag != null);
      return (err: '', review: flag != null);
    } catch (e) {
      return (err: errText(e), review: false);
    }
  }

  Future<void> markSold(Doc l) => queued(fs.collection('listings').doc(l['id']).update({'sold': true}));

  Future<void> renew(Doc l) =>
      queued(fs.collection('listings').doc(l['id']).update({'until': nowMs() + listingDays * 86400000, 'sold': false}));

  /// الحذف يخفي الإعلان (removed) ويحذف صوره
  Future<void> remove(Doc l) async {
    final b = fs.batch();
    b.update(fs.collection('listings').doc(l['id']), {'status': 'removed'});
    for (int i = 0; i < asInt(l['imgN']); i++) {
      b.delete(fs.collection('listingImages').doc('${l['id']}_$i'));
    }
    await queued(b.commit());
  }

  // ---------------- البلاغات ----------------
  bool reported(Doc l) => (l['reporters'] as List? ?? const []).contains(uid);

  Future<String> report(Doc l, String reason) async {
    final me = uid;
    if (me == null || reported(l)) return 'سبق أن أبلغت عن هذا الإعلان.';
    if (l['uid'] == me) return 'لا يمكنك الإبلاغ عن إعلانك.';
    final n = asInt(l['reports']) + 1;
    final b = fs.batch();
    b.set(fs.collection('reports').doc('${l['id']}_$me'), {
      'listingId': l['id'],
      'title': l['title'],
      'sellerUid': l['uid'],
      'uid': me,
      'reason': reason,
      'at': nowMs(),
    });
    b.update(fs.collection('listings').doc(l['id']), {
      'reports': FieldValue.increment(1),
      'reporters': FieldValue.arrayUnion([me]),
      if (n >= hideAfterReports) 'status': 'review',
      if (n >= hideAfterReports) 'flag': 'أُخفي بعد $n بلاغات',
    });
    try {
      await queued(b.commit());
      return '';
    } catch (e) {
      return errText(e);
    }
  }

  // ---------------- الرسائل ----------------
  /// يرسل رسالة في محادثة إعلان. المشتري يبدأ المحادثة، والبائع يرد في نفس المحادثة.
  Future<String?> send(Doc l, String buyerUid, String text) async {
    final me = uid;
    final t = text.trim();
    if (me == null || t.isEmpty) return null;
    final msg = t.length > 500 ? t.substring(0, 500) : t;
    final id = chatIdOf('${l['id']}', buyerUid);
    final c = chat(id);
    final n = asInt(c?['n']) + 1;
    final ref = fs.collection('chats').doc(id);
    final b = fs.batch();
    b.set(
        ref,
        {
          'listingId': l['id'],
          'title': l['title'] ?? c?['title'] ?? '',
          'price': l['price'] ?? c?['price'] ?? 0,
          'sellerUid': l['uid'] ?? c?['sellerUid'],
          'buyerUid': buyerUid,
          'users': [l['uid'] ?? c?['sellerUid'], buyerUid],
          'names': {me: app.name.trim().isEmpty ? 'زبون' : app.name.trim()},
          'lastText': msg.length > 80 ? msg.substring(0, 80) : msg,
          'lastBy': me,
          'lastAt': nowMs(),
          'n': FieldValue.increment(1),
          'read': {me: n},
        },
        SetOptions(merge: true));
    b.set(ref.collection('messages').doc(), {'uid': me, 'text': msg, 'atMs': nowMs(), 'at': FieldValue.serverTimestamp()});
    try {
      if (!await queued(b.commit())) app.toast('الرسالة $pendingNote');
      return id;
    } catch (e) {
      app.toast(errText(e));
      return null;
    }
  }

  void markRead(String chatId) {
    final c = chat(chatId);
    final me = uid;
    if (c == null || me == null || !unread(c)) return;
    fs.collection('chats').doc(chatId).set({
      'read': {me: asInt(c['n'])}
    }, SetOptions(merge: true)).catchError((_) {});
  }

  Stream<List<Doc>> messages(String chatId) => fs
      .collection('chats')
      .doc(chatId)
      .collection('messages')
      .orderBy('atMs')
      .limitToLast(200)
      .snapshots()
      .map((s) => s.docs.map((d) => <String, dynamic>{...d.data(), 'id': d.id}).toList());

  /// اسم الطرف الآخر في المحادثة
  String otherName(Doc c) {
    final names = (c['names'] as Map?) ?? const {};
    for (final e in names.entries) {
      if (e.key != uid) return '${e.value}';
    }
    return c['sellerUid'] == uid ? 'مشترٍ' : 'البائع';
  }
}
