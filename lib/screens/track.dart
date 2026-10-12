import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../store.dart';
import '../ui.dart';
import 'chat.dart';
import 'home.dart' show Pulse;

class TrackScreen extends StatefulWidget {
  final String orderId;
  const TrackScreen({super.key, required this.orderId});
  @override
  State<TrackScreen> createState() => _TrackScreenState();
}

class _TrackScreenState extends State<TrackScreen> {
  int shopStars = 0, courierStars = 0;
  final comment = TextEditingController();
  bool busy = false;

  @override
  void dispose() {
    comment.dispose();
    super.dispose();
  }

  Future<void> _call(String phone) => launchUrl(Uri(scheme: 'tel', path: phone));

  Future<void> _confirm(String title, String body, String yes, Future<void> Function() act) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('تراجع')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(yes)),
        ],
      ),
    );
    if (ok == true) {
      try {
        await act();
      } catch (e) {
        app.toast(errText(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final o = app.order(widget.orderId);
        if (o == null) {
          return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
        }
        final any = isAny(o);
        final st = '${o['status']}';
        final live = activeStatuses.contains(st);
        final hint = Theme.of(context).hintColor;

        // steps
        List<List<String>> steps;
        int idx;
        if (any) {
          steps = [
            ['تم إرسال الطلب', 'نبحث لك عن موصّل قريب'],
            ['الموصّل يشتري طلبك', 'من ${'${o['anyFrom'] ?? ''}'.isEmpty ? 'أقرب محل' : o['anyFrom']}'],
            ['في الطريق', 'الموصّل في طريقه إليك'],
            ['تم التوصيل', 'ادفع الثمن حسب الوصل + التوصيل'],
          ];
          idx = st == 'prep' ? (o['courierUid'] != null ? 1 : 0) : st == 'road' ? 2 : st == 'done' ? 3 : -1;
        } else {
          steps = [
            ['تم إرسال الطلب', 'وصل طلبك إلى المحل'],
            ['المحل يحضّر الطلب', 'قبل المحل طلبك'],
            ['الطلب جاهز', 'ينتظر وصول الموصّل'],
            ['في الطريق', 'الموصّل في طريقه إليك'],
            ['تم التوصيل', 'ادفع نقداً للموصّل'],
          ];
          idx = const ['new', 'prep', 'ready', 'road', 'done'].indexOf(st);
        }

        // map points
        final s = app.shop(o['shopId']);
        final pts = <_Pt>[];
        if (!any && s != null && s['lat'] != null && st != 'road') pts.add(_Pt('s', asD(s['lat'])!, asD(s['lng'])!, Icons.storefront_rounded, orange));
        if (o['cLat'] != null && o['courierUid'] != null && live) pts.add(_Pt('c', asD(o['cLat'])!, asD(o['cLng'])!, Icons.delivery_dining_rounded, info));
        if (o['custLat'] != null) pts.add(_Pt('h', asD(o['custLat'])!, asD(o['custLng'])!, Icons.home_rounded, brand));
        final showMap = live && pts.isNotEmpty && (o['courierUid'] != null || st != 'new');
        final eta = live ? app.etaMin(o) : null;

        return Scaffold(
          body: CustomScrollView(slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 150,
              foregroundColor: Colors.white,
              backgroundColor: any ? const Color(0xFFB45F06) : brandDark,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsetsDirectional.only(start: 56, bottom: 14, end: 16),
                title: Text(app.headOf(o), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 17)),
                background: Container(
                  decoration: BoxDecoration(gradient: any ? anyGradient : heroGradient),
                  padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 56, 20, 0),
                  alignment: AlignmentDirectional.topStart,
                  child: Text('طلب رقم ${o['no'] ?? ''} · ${app.orderTitle(o)}', style: const TextStyle(color: Colors.white70)),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              sliver: SliverList.list(children: [
                if (st == 'done' && o['rated'] != true) ...[_rateCard(o), const SizedBox(height: 12)],
                if (live) ...[
                  Box(
                    child: Row(children: [
                      const Pulse(),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(st == 'road' ? 'يصلك الموصّل خلال' : 'الوصول المتوقع', style: TextStyle(color: hint, fontSize: 13)),
                          Text(eta != null ? '$eta دقيقة تقريباً' : app.headOf(o),
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: eta != null ? 22 : 16, color: brand)),
                        ]),
                      ),
                      if (o['scheduledFor'] != null)
                        Pill(schedText(asInt(o['scheduledFor'])), icon: Icons.schedule_rounded, bg: const Color(0xFFE3ECF7), fg: info),
                    ]),
                  ),
                  const SizedBox(height: 12),
                ],
                if (showMap) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: SizedBox(height: 240, child: _LiveMap(key: ValueKey('${o['id']}|${pts.map((p) => p.k).join()}'), pts: pts)),
                  ),
                  if (o['cAt'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('آخر موقع للموصّل ${ago(asInt(o['cAt']))}', style: TextStyle(fontSize: 12, color: hint)),
                    ),
                  const SizedBox(height: 12),
                ],
                if (idx >= 0)
                  Steps(steps: steps, index: idx, finished: st == 'done')
                else
                  Box(
                    color: const Color(0xFFFCE9DC),
                    child: Text(st == 'rejected' ? 'اعتذر المحل عن هذا الطلب، ولن تدفع شيئاً.' : 'أُلغي هذا الطلب، ولن تدفع شيئاً.',
                        style: const TextStyle(color: Color(0xFF8A3414), fontWeight: FontWeight.w600)),
                  ),
                const SizedBox(height: 12),
                if (o['courierUid'] != null && st != 'done') ...[
                  Box(
                    child: Row(children: [
                      const CircleAvatar(radius: 24, backgroundColor: Color(0xFFE3ECF7), child: Icon(Icons.delivery_dining_rounded, color: info)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${o['courierName'] ?? 'الموصّل'}', style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text('موصّلك', style: TextStyle(color: hint, fontSize: 13)),
                        ]),
                      ),
                      Badge(
                        isLabelVisible: app.unread(o),
                        smallSize: 12,
                        backgroundColor: orange,
                        child: IconButton.filled(
                          tooltip: 'راسل الموصّل',
                          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatScreen(orderId: o['id']))),
                          icon: const Icon(Icons.chat_rounded),
                        ),
                      ),
                      const SizedBox(width: 6),
                      if ('${o['courierPhone'] ?? ''}'.isNotEmpty)
                        IconButton.filled(
                          tooltip: 'اتصل بالموصّل',
                          style: IconButton.styleFrom(backgroundColor: info),
                          onPressed: () => _call('${o['courierPhone']}'),
                          icon: const Icon(Icons.call_rounded),
                        ),
                    ]),
                  ),
                  const SizedBox(height: 12),
                ],
                if (live) ...[
                  Box(
                    color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF332A17) : const Color(0xFFF6EED8),
                    child: Row(children: [
                      Expanded(child: Text(any && o['anyPaid'] == null ? 'تدفع عند الاستلام (تقريباً)' : 'تدفع عند الاستلام')),
                      Text(money(asInt(o['total'])), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    ]),
                  ),
                  const SizedBox(height: 12),
                ],
                _details(o, hint),
                const SizedBox(height: 12),
                Box(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('العنوان', style: TextStyle(color: hint, fontSize: 13)),
                    Text('${o['zoneName'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text('${o['address'] ?? ''}'),
                  ]),
                ),
                const SizedBox(height: 16),
                if (st == 'new' || (any && st == 'prep' && o['courierUid'] == null))
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF9A2A12)),
                    onPressed: () => _confirm('إلغاء الطلب؟', 'لن تدفع شيئاً.', 'نعم، ألغِ', () => app.setStatus(o['id'], 'cancelled')),
                    child: const Text('إلغاء الطلب'),
                  ),
                if (st == 'road')
                  FilledButton(
                    onPressed: () => _confirm('استلمت طلبك؟', 'سجّل الاستلام بعد أن تدفع للموصّل.', 'نعم، استلمت',
                        () => app.setStatus(o['id'], 'done', {'doneAt': nowMs()})),
                    child: const Text('استلمت طلبي ودفعت'),
                  ),
              ]),
            ),
          ]),
        );
      },
    );
  }

  Widget _details(Doc o, Color hint) {
    if (isAny(o)) {
      final paid = o['anyPaid'];
      return Box(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('تفاصيل الطلب', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text('من: ${'${o['anyFrom'] ?? ''}'.isEmpty ? 'أي محل قريب' : o['anyFrom']}', style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('${o['anyText'] ?? ''}'),
          const Divider(),
          Line(paid != null ? 'ثمن المشتريات (حسب الوصل)' : 'الميزانية التقديرية', money(asInt(paid ?? o['anyBudget']))),
          Line('التوصيل', money(asInt(o['fee']))),
          Line(paid != null ? 'المجموع' : 'المجموع التقريبي', money(asInt(o['total'])), bold: true),
        ]),
      );
    }
    final items = (o['items'] as List?) ?? const [];
    return Box(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('تفاصيل الطلب', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        for (final i in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${asInt(i['qty'])}× ${i['name']}'),
                  if (optsText(i).isNotEmpty) Text(optsText(i), style: TextStyle(fontSize: 12, color: hint)),
                ]),
              ),
              Text(money(asInt(i['price']) * asInt(i['qty']))),
            ]),
          ),
        if ('${o['note'] ?? ''}'.isNotEmpty) Text('ملاحظة: ${o['note']}', style: TextStyle(color: hint)),
        const Divider(),
        if (asInt(o['discount']) > 0) Line('خصم الكوبون ${o['coupon'] ?? ''}', '−${money(asInt(o['discount']))}', color: brand),
        Line('التوصيل', money(asInt(o['fee']))),
        Line('المجموع', money(asInt(o['total'])), bold: true),
      ]),
    );
  }

  Widget _stars(int value, ValueChanged<int> onPick) => Row(children: [
        for (int n = 1; n <= 5; n++)
          IconButton(
            tooltip: '$n من 5',
            onPressed: () => onPick(n),
            iconSize: 34,
            icon: Icon(n <= value ? Icons.star_rounded : Icons.star_outline_rounded, color: n <= value ? star : Theme.of(context).dividerColor),
          ),
      ]);

  Widget _rateCard(Doc o) {
    return Box(
      border: Border.all(color: star, width: 2),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('كيف كان طلبك؟', style: Theme.of(context).textTheme.titleMedium),
        if (!isAny(o)) ...[
          const SizedBox(height: 8),
          Text('${o['shopName']}', style: const TextStyle(fontWeight: FontWeight.w600)),
          _stars(shopStars, (n) => setState(() => shopStars = n)),
        ],
        if (o['courierUid'] != null) ...[
          Text('الموصّل ${o['courierName'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w600)),
          _stars(courierStars, (n) => setState(() => courierStars = n)),
        ],
        TextField(
          controller: comment,
          maxLines: 2,
          maxLength: 300,
          decoration: const InputDecoration(labelText: 'تعليق (اختياري)', hintText: 'اكتب رأيك ليستفيد غيرك'),
        ),
        FilledButton(
          onPressed: busy || (shopStars == 0 && courierStars == 0)
              ? null
              : () async {
                  setState(() => busy = true);
                  try {
                    await app.rate(o, shopStars, courierStars, comment.text);
                  } catch (e) {
                    app.toast(errText(e));
                  }
                  if (mounted) setState(() => busy = false);
                },
          child: const Text('إرسال التقييم'),
        ),
      ]),
    );
  }
}

class _Pt {
  final String k;
  final double lat, lng;
  final IconData icon;
  final Color color;
  _Pt(this.k, this.lat, this.lng, this.icon, this.color);
}

class _LiveMap extends StatelessWidget {
  final List<_Pt> pts;
  const _LiveMap({super.key, required this.pts});

  @override
  Widget build(BuildContext context) {
    final coords = pts.map((p) => LatLng(p.lat, p.lng)).toList();
    final distinct = coords.map((c) => '${c.latitude},${c.longitude}').toSet().length;
    return FlutterMap(
      options: MapOptions(
        initialCenter: coords.first,
        initialZoom: 16,
        initialCameraFit: distinct > 1
            ? CameraFit.coordinates(coordinates: coords, padding: const EdgeInsets.all(48), maxZoom: 17)
            : null,
      ),
      children: [
        TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'dz.delivery.app'),
        MarkerLayer(markers: [
          for (final p in pts)
            Marker(
              point: LatLng(p.lat, p.lng),
              width: 42,
              height: 42,
              child: Container(
                decoration: BoxDecoration(
                  color: p.color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6)],
                ),
                child: Icon(p.icon, color: Colors.white, size: 20),
              ),
            ),
        ]),
      ],
    );
  }
}
