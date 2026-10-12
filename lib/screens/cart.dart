import 'package:flutter/material.dart';

import '../store.dart';
import '../ui.dart';
import 'address.dart';
import 'shell.dart';
import 'track.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});
  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final note = TextEditingController();
  final couponCtl = TextEditingController();
  bool later = false;
  DateTime? when;
  bool busy = false;
  String err = '';

  @override
  void dispose() {
    note.dispose();
    couponCtl.dispose();
    super.dispose();
  }

  Future<void> _pickWhen() async {
    final now = DateTime.now();
    final first = now.add(const Duration(minutes: 30));
    final d = await showDatePicker(context: context, firstDate: DateTime(now.year, now.month, now.day), lastDate: now.add(const Duration(days: 3)), initialDate: when ?? first);
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(when ?? first.add(const Duration(minutes: 30))));
    if (t == null) return;
    setState(() => when = DateTime(d.year, d.month, d.day, t.hour, t.minute));
  }

  Future<void> _place() async {
    final ci = app.cartInfo();
    String? e = app.addressError();
    int? sched;
    if (later) {
      if (when == null || when!.millisecondsSinceEpoch < nowMs() + 20 * 60000) {
        e = 'اختر وقتاً بعد نصف ساعة على الأقل من الآن.';
      } else {
        sched = when!.millisecondsSinceEpoch;
      }
    }
    if (app.coupon.isNotEmpty && ci.couponErr.isNotEmpty) e = 'رمز الخصم: ${ci.couponErr} أزله أو صحّحه.';
    final gone = ci.items.where((i) => i.product['available'] != true).map((i) => i.product['name']).toList();
    if (gone.isNotEmpty) e = 'نفد من المحل: ${gone.join('، ')}. احذفه من السلة ثم أكّد.';
    if (!app.isOpen(ci.shop)) e = 'المحل مغلق الآن، لا يمكن إرسال الطلب.';
    final min = asInt(ci.shop?['minOrder']);
    if (min > 0 && ci.subtotal < min) e = 'أقل طلب من هذا المحل ${money(min)}.';
    if (e != null) {
      setState(() => err = e!);
      return;
    }
    setState(() {
      busy = true;
      err = '';
    });
    try {
      final id = await app.placeOrder(note: note.text, scheduledFor: sched);
      note.clear();
      later = false;
      when = null;
      if (!mounted) return;
      tab.value = 2;
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => TrackScreen(orderId: id)));
    } catch (x) {
      setState(() => err = errText(x));
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final ci = app.cartInfo();
        final hint = Theme.of(context).hintColor;
        if (ci.count == 0 || ci.shop == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('سلتك')),
            body: Center(
              child: EmptyState(
                icon: Icons.shopping_cart_outlined,
                title: 'سلتك فارغة',
                text: 'اختر محلاً وأضف ما تريد.',
                action: FilledButton(onPressed: () => tab.value = 0, child: const Text('تصفّح المحلات')),
              ),
            ),
          );
        }
        final sh = ci.shop!;
        final open = app.isOpen(sh);
        final prep = asInt(sh['prepMin']) > 0 ? asInt(sh['prepMin']) : 15;
        final offers = app.shopCoupons(sh['id']);
        return Scaffold(
          appBar: AppBar(title: const Text('سلتك')),
          body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
            Box(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('من ${sh['name']}', style: TextStyle(color: hint, fontSize: 13)),
                for (final i in ci.items) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(children: [
                      ItemThumb(product: i.product, cat: '${sh['cat']}', size: 52),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${i.product['name']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                          if (optsText(i.line.toJson()).isNotEmpty) Text(optsText(i.line.toJson()), style: TextStyle(fontSize: 12, color: hint)),
                          Text(money(i.unit * i.line.qty), style: TextStyle(fontSize: 13, color: hint)),
                        ]),
                      ),
                      QtyStepper(
                        qty: i.line.qty,
                        enabled: open && i.product['available'] == true,
                        onAdd: () => app.changeQty(i.key, 1),
                        onSub: () => app.changeQty(i.key, -1),
                      ),
                    ]),
                  ),
                  if (i != ci.items.last) const Divider(height: 1),
                ],
                const SizedBox(height: 8),
                TextField(
                  controller: note,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'ملاحظة للمحل (اختياري)', hintText: 'مثال: أضيفوا مناديل'),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            Box(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('وقت التوصيل', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('في أقرب وقت'), icon: Icon(Icons.bolt_rounded)),
                    ButtonSegment(value: true, label: Text('جدولة'), icon: Icon(Icons.event_rounded)),
                  ],
                  selected: {later},
                  onSelectionChanged: (v) => setState(() => later = v.first),
                ),
                const SizedBox(height: 8),
                if (later)
                  OutlinedButton.icon(
                    onPressed: _pickWhen,
                    icon: const Icon(Icons.schedule_rounded),
                    label: Text(when == null ? 'اختر اليوم والساعة' : 'يصلك ${schedText(when!.millisecondsSinceEpoch)}'),
                  )
                else
                  Text('يصلك خلال ${prep + 10}–${prep + 25} دقيقة تقريباً', style: TextStyle(color: hint)),
              ]),
            ),
            const SizedBox(height: 12),
            const AddressForm(),
            const SizedBox(height: 12),
            Box(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('رمز خصم', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                if (ci.coupon != null)
                  Row(children: [
                    const Icon(Icons.check_circle_rounded, color: brand, size: 20),
                    const SizedBox(width: 6),
                    Expanded(
                        child: Text('${app.couponLabel(ci.coupon!)} · ${ci.coupon!['code']}',
                            style: const TextStyle(color: brand, fontWeight: FontWeight.w700))),
                    TextButton(onPressed: () => app.setCoupon(''), child: const Text('إزالة')),
                  ])
                else ...[
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: couponCtl,
                        textCapitalization: TextCapitalization.characters,
                        textDirection: TextDirection.ltr,
                        decoration: const InputDecoration(hintText: 'اكتب الرمز'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () {
                        app.setCoupon(couponCtl.text);
                        final c2 = app.cartInfo();
                        app.toast(c2.coupon != null ? 'طُبّق الخصم: −${money(c2.discount)}' : c2.couponErr);
                      },
                      child: const Text('تطبيق'),
                    ),
                  ]),
                  if (app.coupon.isNotEmpty && ci.couponErr.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(ci.couponErr, style: const TextStyle(color: Color(0xFF9A2A12), fontSize: 13)),
                    ),
                  if (offers.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Wrap(spacing: 8, children: [
                        for (final c in offers)
                          ActionChip(
                            avatar: const Icon(Icons.local_offer_rounded, size: 16, color: orange),
                            label: Text('${c['code']}'),
                            onPressed: () => app.setCoupon('${c['code']}'),
                          ),
                      ]),
                    ),
                ],
              ]),
            ),
            const SizedBox(height: 12),
            const Box(
              child: Row(children: [
                Icon(Icons.payments_rounded, color: brand),
                SizedBox(width: 10),
                Expanded(child: Text('الدفع نقداً للموصّل عند الاستلام', style: TextStyle(fontWeight: FontWeight.w600))),
              ]),
            ),
            const SizedBox(height: 12),
            Box(
              child: Column(children: [
                Line('المنتجات', money(ci.subtotal)),
                if (ci.discount > 0) Line('خصم الكوبون', '−${money(ci.discount)}', color: brand),
                Line('التوصيل${ci.zone != null ? ' إلى ${ci.zone!['name']}' : ''}', money(ci.fee)),
                const Divider(),
                Line('المجموع', money(ci.total), bold: true),
              ]),
            ),
            if (err.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Box(color: const Color(0xFFFCE9DC), child: Text(err, style: const TextStyle(color: Color(0xFF8A3414), fontWeight: FontWeight.w600))),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: busy || !open ? null : _place,
              child: busy
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : Text(open ? 'تأكيد الطلب · ${money(ci.total)}' : 'المحل مغلق الآن'),
            ),
          ]),
        );
      },
    );
  }
}
