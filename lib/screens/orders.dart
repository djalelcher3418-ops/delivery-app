import 'package:flutter/material.dart';

import '../store.dart';
import '../ui.dart';
import 'shell.dart';
import 'track.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  Future<void> _reorder(BuildContext context, Doc o) async {
    final items = o['items'];
    if (items is! List) return;
    final miss = <String>[];
    final lines = <CartLine>[];
    for (final i in items) {
      final p = app.product(i['pid']);
      if (p != null && p['available'] == true) {
        lines.add(CartLine(
          pid: p['id'],
          qty: asInt(i['qty']),
          size: '${i['size'] ?? ''}',
          extras: List<String>.from((i['extras'] as List?) ?? const []),
          note: '${i['note'] ?? ''}',
        ));
      } else {
        miss.add('${i['name']}');
      }
    }
    if (lines.isEmpty) {
      app.toast('منتجات هذا الطلب غير متوفرة الآن.');
      return;
    }
    app.cart.clear();
    app.cartShop = null;
    app.coupon = '';
    for (final l in lines) {
      app.addLine(app.product(l.pid)!, l);
    }
    if (miss.isNotEmpty) app.toast('غير متوفر الآن: ${miss.join('، ')}');
    tab.value = 3;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final hint = Theme.of(context).hintColor;
        return Scaffold(
          appBar: AppBar(title: const Text('طلباتي')),
          body: !app.ordersLoaded
              ? const Center(child: CircularProgressIndicator())
              : app.orders.isEmpty
                  ? Center(
                      child: EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'لا توجد طلبات بعد',
                        text: 'عندما تطلب، تجد طلبك هنا وتتابع حالته.',
                        action: FilledButton(onPressed: () => tab.value = 0, child: const Text('اطلب الآن')),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: app.orders.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final o = app.orders[i];
                        final active = activeStatuses.contains(o['status']);
                        final rate = o['status'] == 'done' && o['rated'] != true;
                        final again = !active && !isAny(o);
                        void open() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TrackScreen(orderId: o['id'])));
                        return Box(
                          onTap: open,
                          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            Row(children: [
                              if (isAny(o)) ...[
                                const Pill('أي شيء', bg: inkSoft, fg: ink),
                                const SizedBox(width: 6),
                              ],
                              Expanded(
                                  child: Text(app.orderTitle(o),
                                      maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
                              statusPill(o),
                            ]),
                            const SizedBox(height: 4),
                            Text(app.orderLines(o), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: hint, fontSize: 13)),
                            if (o['scheduledFor'] != null && active)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Align(
                                  alignment: AlignmentDirectional.centerStart,
                                  child: Pill('مجدول ${schedText(asInt(o['scheduledFor']))}',
                                      icon: Icons.schedule_rounded, bg: inkSoft, fg: ink),
                                ),
                              ),
                            if (app.unread(o))
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text('رسالة جديدة من الموصّل', style: TextStyle(color: accentOf(context), fontWeight: FontWeight.w700)),
                              ),
                            const SizedBox(height: 6),
                            Row(children: [
                              Expanded(child: Text('طلب رقم ${o['no'] ?? ''}، ${ago(asInt(o['createdAtMs']))}', style: TextStyle(color: hint, fontSize: 13))),
                              Text(money(asInt(o['total'])), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 17)),
                            ]),
                            if (rate || again) ...[
                              const SizedBox(height: 10),
                              Row(children: [
                                if (rate)
                                  Expanded(
                                    child: FilledButton.icon(
                                      style: FilledButton.styleFrom(backgroundColor: star, foregroundColor: ink, minimumSize: const Size(0, 44)),
                                      onPressed: open,
                                      icon: const Icon(Icons.star_rounded),
                                      label: const Text('قيّم الطلب'),
                                    ),
                                  ),
                                if (rate && again) const SizedBox(width: 8),
                                if (again)
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => _reorder(context, o),
                                      icon: const Icon(Icons.replay_rounded),
                                      label: const Text('اطلب مرة أخرى'),
                                    ),
                                  ),
                              ]),
                            ],
                          ]),
                        );
                      },
                    ),
        );
      },
    );
  }
}
