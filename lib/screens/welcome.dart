import 'package:flutter/material.dart';

import '../store.dart';
import '../ui.dart';

/// شاشة الترحيب: خلفية الهريسة بنقش الزليج، لوحة فاتحة خلف صورة كبيرة،
/// نقاط الصفحات، وزر نيلي فيه دائرة بلون الهريسة وسهم.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});
  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _Slide {
  final IconData icon;
  final List<IconData> around;
  final String title, text;
  const _Slide(this.icon, this.around, this.title, this.text);
}

const _slides = [
  _Slide(Icons.delivery_dining_rounded, [Icons.restaurant_rounded, Icons.bakery_dining_rounded, Icons.local_grocery_store_rounded],
      'محلات مدينتك\nفي مكان واحد', 'مطاعم، مخابز، خضر ومواد غذائية… اطلب وتصلك إلى بابك'),
  _Slide(Icons.shopping_bag_rounded, [Icons.storefront_rounded, Icons.local_pharmacy_rounded, Icons.eco_rounded],
      'اشترِ لي\nأي شيء', 'من أي محل في المدينة، حتى لو لم يكن في التطبيق'),
  _Slide(Icons.map_rounded, [Icons.near_me_rounded, Icons.schedule_rounded, Icons.payments_rounded],
      'تابع الموصّل\nعلى الخريطة', 'بدون تسجيل، والدفع نقداً عند الاستلام'),
];

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool busy = false;
  String err = '';
  int page = 0;
  final ctrl = PageController();

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    setState(() {
      busy = true;
      err = '';
    });
    try {
      await app.signInAnon();
    } catch (e) {
      setState(() {
        busy = false;
        err = errText(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: brand,
      body: Stack(children: [
        const Zellige(opacity: 0.12),
        SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Row(children: [
              ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.asset('assets/icon.png', width: 40, height: 40)),
              const SizedBox(width: 10),
              const Text('Delivery', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
              const Spacer(),
              if (page < _slides.length - 1)
                TextButton(
                  onPressed: () => ctrl.animateToPage(_slides.length - 1, duration: const Duration(milliseconds: 400), curve: Curves.easeOut),
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  child: const Text('تخطّي'),
                ),
            ]),
          ),
          Expanded(
            child: PageView.builder(
              controller: ctrl,
              itemCount: _slides.length,
              onPageChanged: (i) => setState(() => page = i),
              itemBuilder: (_, i) => _SlideView(_slides[i]),
            ),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (int i = 0; i < _slides.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == page ? 20 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: i == page ? Colors.white : Colors.white.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
          ]),
          const SizedBox(height: 22),
          if (err.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Text(err, style: const TextStyle(color: brandDark, fontWeight: FontWeight.w600)),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: StartButton(label: 'ابدأ الطلب', busy: busy, onTap: busy ? null : _go),
          ),
          const SizedBox(height: 12),
          Text('بدون تسجيل، والدفع نقداً عند الاستلام', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13)),
          const SizedBox(height: 18),
        ]),
      ),
      ]),
    );
  }
}

class _SlideView extends StatelessWidget {
  final _Slide s;
  const _SlideView(this.s);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 10),
      child: Column(children: [
        Expanded(
          child: LayoutBuilder(builder: (context, box) {
            final d = box.maxHeight < box.maxWidth ? box.maxHeight : box.maxWidth;
            return Center(
              child: SizedBox(
                width: d,
                height: d,
                child: Stack(alignment: Alignment.center, children: [
                  // اللوحة الفاتحة خلف الصورة
                  Container(
                    width: d * 0.78,
                    height: d * 0.92,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(d * 0.14),
                    ),
                  ),
                  Container(
                    width: d * 0.6,
                    height: d * 0.6,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 30, offset: const Offset(0, 14))],
                    ),
                    child: Icon(s.icon, size: d * 0.32, color: brand),
                  ),
                  for (int k = 0; k < s.around.length; k++)
                    Align(
                      alignment: const [Alignment(-0.92, -0.55), Alignment(0.95, -0.15), Alignment(-0.55, 0.92)][k],
                      child: Container(
                        width: d * 0.2,
                        height: d * 0.2,
                        decoration: BoxDecoration(
                          color: brandSoft,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: Icon(s.around[k], size: d * 0.1, color: brandDark),
                      ),
                    ),
                ]),
              ),
            );
          }),
        ),
        const SizedBox(height: 14),
        Text(s.title,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(color: Colors.white, fontWeight: FontWeight.w800, height: 1.25)),
        const SizedBox(height: 8),
        Text(s.text,
            textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 14.5, height: 1.4)),
      ]),
    );
  }
}

/// زر نيلي وفي بدايته دائرة بلون الهريسة وسهم
class StartButton extends StatelessWidget {
  final String label;
  final bool busy;
  final VoidCallback? onTap;
  const StartButton({super.key, required this.label, this.busy = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ink,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 60,
          child: Row(children: [
            const SizedBox(width: 7),
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: brand, borderRadius: BorderRadius.circular(14)),
              child: busy
                  ? const Padding(padding: EdgeInsets.all(13), child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : const Icon(Icons.arrow_forward_rounded, color: Colors.white),
            ),
            Expanded(
              child: Text(label,
                  textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16.5)),
            ),
            const SizedBox(width: 53),
          ]),
        ),
      ),
    );
  }
}
