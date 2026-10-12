import 'package:flutter/material.dart';

import '../store.dart';
import '../ui.dart';
import 'address.dart';
import 'shell.dart';
import 'track.dart';

/// «اشترِ لي أي شيء»: الموصّل يشتري من أي محل بماله ويوصله
class AnyScreen extends StatefulWidget {
  const AnyScreen({super.key});
  @override
  State<AnyScreen> createState() => _AnyScreenState();
}

class _AnyScreenState extends State<AnyScreen> {
  late final TextEditingController from = TextEditingController(text: app.anyFrom);
  late final TextEditingController text = TextEditingController(text: app.anyText);
  late final TextEditingController budget = TextEditingController(text: app.anyBudget);
  bool busy = false;
  String err = '';

  @override
  void dispose() {
    from.dispose();
    text.dispose();
    budget.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    String? e = app.addressError();
    final b = parseInt(budget.text) ?? 0;
    if (text.text.trim().length < 3) e = 'اكتب ما تريد شراءه.';
    if (b <= 0) {
      e = 'اكتب مبلغاً تقديرياً بالدينار.';
    } else if (b > app.anyCap) {
      e = 'أكبر مبلغ مسموح ${money(app.anyCap)}. قسّم طلبك أو اطلب من محل في التطبيق.';
    }
    if (e != null) {
      setState(() => err = e!);
      return;
    }
    setState(() {
      busy = true;
      err = '';
    });
    try {
      final id = await app.placeAny();
      from.clear();
      text.clear();
      budget.clear();
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
        final zone = app.currentZone;
        final fee = (zone == null ? 0 : asInt(zone['fee'])) + app.anyExtra;
        final b = parseInt(budget.text) ?? 0;
        return Scaffold(
          body: ListView(padding: EdgeInsets.zero, children: [
            Container(
              decoration: const BoxDecoration(gradient: anyGradient, borderRadius: BorderRadius.vertical(bottom: Radius.circular(26))),
              padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 20, 20, 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.shopping_bag_rounded, color: Colors.white, size: 36),
                const SizedBox(height: 10),
                Text('اشترِ لي أي شيء', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white)),
                const SizedBox(height: 6),
                const Text('اكتب ما تحتاجه ومن أين، فيشتريه الموصّل بماله ويوصله إليك. تدفع له ثمن المشتريات والتوصيل عند الاستلام.',
                    style: TextStyle(color: Colors.white, height: 1.5)),
              ]),
            ),
            if (!app.anyOn)
              const Padding(padding: EdgeInsets.all(16), child: Box(child: Text('هذه الخدمة متوقفة مؤقتاً.')))
            else
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Box(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      TextField(
                        controller: from,
                        decoration: const InputDecoration(labelText: 'من أين نشتري؟', hintText: 'مثال: صيدلية الحي، أو «أي محل قريب»'),
                        onChanged: (v) {
                          app.anyFrom = v;
                          app.save();
                        },
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: text,
                        minLines: 3,
                        maxLines: 6,
                        maxLength: 600,
                        decoration: const InputDecoration(labelText: 'ماذا تريد؟ (كل شيء في سطر)', hintText: 'خبز 4\nحليب 2 لتر\nبطاقة تعبئة 500 دج'),
                        onChanged: (v) {
                          app.anyText = v;
                          app.save();
                        },
                      ),
                      TextField(
                        controller: budget,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: 'كم تتوقع أن يكلّف؟', suffixText: 'دج', helperText: 'الحد الأقصى ${money(app.anyCap)}، لأن الموصّل يدفع من ماله.'),
                        onChanged: (v) {
                          app.anyBudget = v;
                          app.save();
                          setState(() {});
                        },
                      ),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  const AddressForm(),
                  const SizedBox(height: 12),
                  Box(
                    child: Column(children: [
                      Line('المشتريات (تقديري)', money(b)),
                      Line('التوصيل', money(fee)),
                      const Divider(),
                      Line('المجموع التقريبي', money(b + fee), bold: true),
                    ]),
                  ),
                  if (err.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Box(color: const Color(0xFFFCE9DC), child: Text(err, style: const TextStyle(color: Color(0xFF8A3414), fontWeight: FontWeight.w600))),
                    ),
                  const SizedBox(height: 16),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB84A0B)),
                    onPressed: busy ? null : _send,
                    child: busy
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                        : const Text('أرسل الطلب للموصّلين'),
                  ),
                  const SizedBox(height: 24),
                ]),
              ),
          ]),
        );
      },
    );
  }
}
