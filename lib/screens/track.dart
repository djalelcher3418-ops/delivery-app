import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../store.dart';
import '../ui.dart';
import 'chat.dart';

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

        // المراحل: اسم قصير تحت كل شريط، ووصف المرحلة الحالية تحتها
        List<List<String>> steps;
        int idx;
        if (any) {
          steps = [
            ['أُرسل', 'نبحث لك عن موصّل قريب'],
            ['يشتري', 'الموصّل يشتري طلبك من ${'${o['anyFrom'] ?? ''}'.isEmpty ? 'أقرب محل' : o['anyFrom']}'],
            ['في الطريق', 'الموصّل في طريقه إليك'],
            ['وصل', 'ادفع الثمن حسب الوصل مع التوصيل'],
          ];
          idx = st == 'prep' ? (o['courierUid'] != null ? 1 : 0) : st == 'road' ? 2 : st == 'done' ? 3 : -1;
        } else {
          steps = [
            ['أُرسل', 'وصل طلبك إلى المحل'],
            ['يُحضَّر', 'قبل المحل طلبك ويحضّره'],
            ['جاهز', 'الطلب جاهز وينتظر الموصّل'],
            ['في الطريق', 'الموصّل في طريقه إليك'],
            ['وصل', 'ادفع نقداً للموصّل'],
          ];
          idx = const ['new', 'prep', 'ready', 'road', 'done'].indexOf(st);
        }

        // نقاط الخريطة: المحل بالأخضر، الموصّل بالهريسة، والبيت بالنيلي
        final s = app.shop(o['shopId']);
        final pts = <_Pt>[];
        if (!any && s != null && s['lat'] != null && st != 'road') pts.add(_Pt('s', asD(s['lat'])!, asD(s['lng'])!, Icons.storefront_rounded, tea));
        if (o['cLat'] != null && o['courierUid'] != null && live) {
          pts.add(_Pt('c', asD(o['cLat'])!, asD(o['cLng'])!, Icons.delivery_dining_rounded, brand));
        }
        if (o['custLat'] != null) pts.add(_Pt('h', asD(o['custLat'])!, asD(o['custLng'])!, Icons.home_rounded, ink, square: true));
        final showMap = live && pts.isNotEmpty && (o['courierUid'] != null || st != 'new');
        final eta = live ? app.etaMin(o) : null;
        final top = MediaQuery.of(context).padding.top;
        final topH = showMap ? 330.0 : 170 + top;
        final dark = isDark(context);
        final surface = Theme.of(context).colorScheme.surface;
        final subtitle = '${app.orderTitle(o)}، طلب رقم ${o['no'] ?? ''}';

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: showMap && !dark ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
          child: Scaffold(
          backgroundColor: surface,
          body: Stack(children: [
            CustomScrollView(slivers: [
              SliverToBoxAdapter(
                child: Stack(children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: topH,
                    child: showMap
                        ? _LiveMap(key: ValueKey('${o['id']}|${pts.map((p) => p.k).join()}'), pts: pts)
                        : ColoredBox(
                            color: any ? ink : brand,
                            child: Stack(children: [
                              const Zellige(),
                              PositionedDirectional(
                                end: 24,
                                top: top + 34,
                                child: Icon(any ? Icons.shopping_bag_rounded : Icons.receipt_long_rounded,
                                    size: 84, color: Colors.white.withValues(alpha: 0.9)),
                              ),
                            ]),
                          ),
                  ),
                  // الورقة البيضاء
                  Container(
                    margin: EdgeInsets.only(top: topH - 28),
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
                    decoration: BoxDecoration(color: surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Row(children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(app.headOf(o), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 25, height: 1.2)),
                            const SizedBox(height: 4),
                            Text(subtitle, style: TextStyle(color: hint, fontSize: 14)),
                          ]),
                        ),
                        if (eta != null) ...[
                          const SizedBox(width: 12),
                          Semantics(
                            label: 'يصل خلال $eta ${minutesWord(eta)} تقريباً',
                            excludeSemantics: true,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(color: dark ? brand.withValues(alpha: 0.25) : brandSoft, borderRadius: BorderRadius.circular(18)),
                              child: Column(children: [
                                Text('$eta',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(fontSize: 30, height: 1, color: dark ? Colors.white : brandDark)),
                                Text(minutesWord(eta), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: dark ? Colors.white : brandDark)),
                              ]),
                            ),
                          ),
                        ],
                      ]),
                      if (o['scheduledFor'] != null) ...[
                        const SizedBox(height: 10),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Pill(schedText(asInt(o['scheduledFor'])), icon: Icons.schedule_rounded, bg: inkSoft, fg: ink),
                        ),
                      ],
                      const SizedBox(height: 18),
                      if (idx >= 0) ...[
                        Steps(labels: [for (final x in steps) x[0]], index: idx, finished: st == 'done'),
                        const SizedBox(height: 10),
                        Text(steps[idx][1], style: TextStyle(color: hint, fontSize: 13.5)),
                        if (showMap && o['cAt'] != null)
                          Text('آخر موقع للموصّل ${ago(asInt(o['cAt']))}', style: TextStyle(fontSize: 12, color: hint)),
                      ] else
                        Box(
                          color: dark ? brand.withValues(alpha: 0.25) : brandSoft,
                          child: Text(st == 'rejected' ? 'اعتذر المحل عن هذا الطلب، ولن تدفع شيئاً.' : 'أُلغي هذا الطلب، ولن تدفع شيئاً.',
                              style: TextStyle(color: dark ? Colors.white : brandDark, fontWeight: FontWeight.w600)),
                        ),
                      if (st == 'done' && o['rated'] != true) ...[const SizedBox(height: 18), _rateCard(o)],
                      if (o['courierUid'] != null && st != 'done') ...[
                        const SizedBox(height: 18),
                        _courierCard(o),
                      ],
                      const SizedBox(height: 22),
                      _details(o, hint, live),
                      const SizedBox(height: 18),
                      Divider(height: 1, color: Theme.of(context).dividerColor),
                      const SizedBox(height: 14),
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Icon(Icons.place_outlined, color: hint, size: 22),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${o['zoneName'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
                            if ('${o['address'] ?? ''}'.isNotEmpty) Text('${o['address']}', style: TextStyle(color: hint)),
                          ]),
                        ),
                      ]),
                      const SizedBox(height: 20),
                      if (st == 'new' || (any && st == 'prep' && o['courierUid'] == null))
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(foregroundColor: dark ? const Color(0xFFF08A5D) : danger),
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
              ),
            ]),
            PositionedDirectional(
              top: top + 10,
              start: 14,
              child: FloatBtn(icon: Icons.arrow_back_rounded, tooltip: 'رجوع', onTap: () => Navigator.of(context).maybePop()),
            ),
          ]),
        ),
        );
      },
    );
  }

  /// بطاقة الموصّل: الحرف الأول في دائرة نيلية، وزرا المراسلة والاتصال
  Widget _courierCard(Doc o) {
    final hint = Theme.of(context).hintColor;
    final dark = isDark(context);
    final name = '${o['courierName'] ?? 'الموصّل'}';
    final sq = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: dark ? Colors.white.withValues(alpha: 0.06) : paper, borderRadius: BorderRadius.circular(18)),
      child: Row(children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: dark ? const Color(0xFF2A3550) : ink,
          child: Text(firstChar(name),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontSize: 20)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$name، الموصّل', style: const TextStyle(fontWeight: FontWeight.w700)),
            Text('موصّلك لهذا الطلب', style: TextStyle(color: hint, fontSize: 13)),
          ]),
        ),
        Badge(
          isLabelVisible: app.unread(o),
          smallSize: 12,
          backgroundColor: brand,
          child: IconButton(
            tooltip: 'راسل الموصّل',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatScreen(orderId: o['id']))),
            style: IconButton.styleFrom(
              fixedSize: const Size(44, 44),
              backgroundColor: Theme.of(context).colorScheme.surface,
              foregroundColor: Theme.of(context).colorScheme.onSurface,
              side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
              shape: sq,
            ),
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 21),
          ),
        ),
        if ('${o['courierPhone'] ?? ''}'.isNotEmpty) ...[
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'اتصل بالموصّل',
            onPressed: () => _call('${o['courierPhone']}'),
            style: IconButton.styleFrom(fixedSize: const Size(44, 44), backgroundColor: tea, foregroundColor: Colors.white, shape: sq),
            icon: const Icon(Icons.call_rounded, size: 21),
          ),
        ],
      ]),
    );
  }

  Widget _details(Doc o, Color hint, bool live) {
    final payLabel = live ? 'تدفع عند الاستلام' : 'المجموع';
    final title = Text('تفاصيل الطلب', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 18));
    if (isAny(o)) {
      final paid = o['anyPaid'];
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        title,
        const SizedBox(height: 6),
        Text('من: ${'${o['anyFrom'] ?? ''}'.isEmpty ? 'أي محل قريب' : o['anyFrom']}', style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text('${o['anyText'] ?? ''}'),
        const SizedBox(height: 8),
        Line(paid != null ? 'ثمن المشتريات (حسب الوصل)' : 'الميزانية التقديرية', money(asInt(paid ?? o['anyBudget']))),
        Line('التوصيل', money(asInt(o['fee']))),
        Divider(color: Theme.of(context).dividerColor),
        Line(live && paid == null ? '$payLabel (تقريباً)' : payLabel, money(asInt(o['total'])), bold: true),
      ]);
    }
    final items = (o['items'] as List?) ?? const [];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      title,
      const SizedBox(height: 6),
      for (final i in items)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${i['name']} × ${asInt(i['qty'])}', style: TextStyle(color: hint)),
                if (optsText(i).isNotEmpty) Text(optsText(i), style: TextStyle(fontSize: 12, color: hint)),
              ]),
            ),
            Text(money(asInt(i['price']) * asInt(i['qty']))),
          ]),
        ),
      if ('${o['note'] ?? ''}'.isNotEmpty) Text('ملاحظة: ${o['note']}', style: TextStyle(color: hint)),
      if (asInt(o['discount']) > 0) Line('خصم الكوبون ${o['coupon'] ?? ''}', '−${money(asInt(o['discount']))}', color: teaOf(context)),
      Line('التوصيل', money(asInt(o['fee']))),
      Divider(color: Theme.of(context).dividerColor),
      Line(payLabel, money(asInt(o['total'])), bold: true),
    ]);
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
      color: isDark(context) ? star.withValues(alpha: 0.14) : saffronSoft,
      border: Border.all(color: star, width: 1.5),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('كيف كان طلبك؟', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 19)),
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
  final bool square;
  _Pt(this.k, this.lat, this.lng, this.icon, this.color, {this.square = false});
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
            ? CameraFit.coordinates(coordinates: coords, padding: const EdgeInsets.fromLTRB(48, 72, 48, 64), maxZoom: 17)
            : null,
      ),
      children: [
        TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'dz.delivery.app'),
        MarkerLayer(markers: [
          for (final p in pts)
            Marker(
              point: LatLng(p.lat, p.lng),
              width: 44,
              height: 44,
              child: Container(
                decoration: BoxDecoration(
                  color: p.color,
                  shape: p.square ? BoxShape.rectangle : BoxShape.circle,
                  borderRadius: p.square ? BorderRadius.circular(12) : null,
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
                ),
                child: Icon(p.icon, color: Colors.white, size: 20),
              ),
            ),
        ]),
      ],
    );
  }
}
