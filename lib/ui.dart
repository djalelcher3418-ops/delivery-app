import 'dart:async';

import 'package:flutter/material.dart';

import 'store.dart';

// ألوان «سوق الحي»: هريسة للأفعال، نعناع الشاي للحالات المطمئنة، نيلي للنص، زعفران للعروض
const brand = Color(0xFFC2410C); // الهريسة: الأزرار والإجراءات
const brandDark = Color(0xFF9A3412);
const brandSoft = Color(0xFFFBE3D6);
const tea = Color(0xFF0F7B5F); // نعناع الشاي: مفتوح، تم التوصيل
const teaDark = Color(0xFF0A5A43);
const teaSoft = Color(0xFFE1F1EA);
const ink = Color(0xFF1E2A4A); // النيلي: النصوص والأزرار الثانوية
const inkSoft = Color(0xFFE5E9F3);
const star = Color(0xFFF2A516); // الزعفران: العروض والتقييم (نصه نيلي دائماً)
const saffronSoft = Color(0xFFFDF0D5);
const saffronText = Color(0xFF7A4A12);
const paper = Color(0xFFF6F7F9); // أرضية الصفحات
const muted = Color(0xFF5B6474);
const hairline = Color(0xFFDDE1E8);
const danger = Color(0xFF9A2A12);

bool isDark(BuildContext context) => Theme.of(context).brightness == Brightness.dark;

/// لون النصوص المميزة: الهريسة في الوضع الفاتح، وأفتح منها في الداكن حتى تبقى مقروءة
Color accentOf(BuildContext context) => Theme.of(context).colorScheme.primary;

/// نعناع الشاي للنصوص (أفتح في الوضع الداكن)
Color teaOf(BuildContext context) => isDark(context) ? const Color(0xFF5CC9A7) : teaDark;

class Cat {
  final String id, label;
  final IconData icon;
  final Color bg, fg;
  const Cat(this.id, this.label, this.icon, this.bg, this.fg);
}

const cats = <Cat>[
  Cat('food', 'مطاعم', Icons.restaurant_rounded, brandSoft, brandDark),
  Cat('bread', 'مخابز وحلويات', Icons.bakery_dining_rounded, Color(0xFFF6EBDD), saffronText),
  Cat('veg', 'خضر وفواكه', Icons.eco_rounded, teaSoft, teaDark),
  Cat('grocery', 'مواد غذائية', Icons.local_grocery_store_rounded, inkSoft, ink),
  Cat('meat', 'لحوم ودجاج', Icons.kebab_dining_rounded, Color(0xFFFBE4E4), Color(0xFF8E1F1F)),
  Cat('pharma', 'شبه صيدلية', Icons.local_pharmacy_rounded, Color(0xFFE0F0F1), Color(0xFF0E6168)),
  Cat('other', 'محلات أخرى', Icons.storefront_rounded, saffronSoft, saffronText),
];

/// «دقيقة» أو «دقائق» حسب العدد (3 إلى 10 دقائق، وغيرها دقيقة)
String minutesWord(int n) => (n % 100 >= 3 && n % 100 <= 10) ? 'دقائق' : 'دقيقة';

String firstChar(String s) => s.trim().isEmpty ? '?' : s.trim().characters.first;

Cat catOf(String? id) => cats.firstWhere((c) => c.id == id, orElse: () => cats.last);

/// خط رفيع تحت البطاقات بدل الظلال الثقيلة
List<BoxShadow> softShadow(BuildContext context) =>
    isDark(context) ? const [] : const [BoxShadow(color: Color(0xFFE3E7ED), offset: Offset(0, 1))];

/// نقش الزليج: مربعان متقاطعان ونقطة في كل خلية (يُرسم فوق لون الهريسة)
class ZelligePainter extends CustomPainter {
  final Color color;
  const ZelligePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    const cell = 46.0, half = 12.0;
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final dot = Paint()..color = color;
    for (double y = 0; y < size.height + cell; y += cell) {
      for (double x = 0; x < size.width + cell; x += cell) {
        final c = Offset(x + cell / 2, y + cell / 2);
        canvas.drawRect(Rect.fromCenter(center: c, width: half * 2, height: half * 2), line);
        canvas.save();
        canvas.translate(c.dx, c.dy);
        canvas.rotate(0.785398);
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: half * 2, height: half * 2), line);
        canvas.restore();
        canvas.drawCircle(c, 3, dot);
      }
    }
  }

  @override
  bool shouldRepaint(ZelligePainter old) => old.color != color;
}

/// طبقة النقش تملأ ما تحتها ولا تلتقط اللمس
class Zellige extends StatelessWidget {
  final double opacity;
  const Zellige({super.key, this.opacity = 0.13});

  @override
  Widget build(BuildContext context) => Positioned.fill(
        child: IgnorePointer(
          child: ClipRect(child: CustomPaint(painter: ZelligePainter(Colors.white.withValues(alpha: opacity)))),
        ),
      );
}

/// نجمة الزليج الثمانية (شكل شارات الأقسام)
class StarClipper extends CustomClipper<Path> {
  const StarClipper();
  static const _pts = [
    [0.5, 0.0], [0.343, 0.121], [0.146, 0.146], [0.121, 0.343], //
    [0.0, 0.5], [0.121, 0.657], [0.146, 0.854], [0.343, 0.879],
    [0.5, 1.0], [0.657, 0.879], [0.854, 0.854], [0.879, 0.657],
    [1.0, 0.5], [0.879, 0.343], [0.854, 0.146], [0.657, 0.121],
  ];

  @override
  Path getClip(Size s) {
    final p = Path()..moveTo(_pts[0][0] * s.width, _pts[0][1] * s.height);
    for (final q in _pts.skip(1)) {
      p.lineTo(q[0] * s.width, q[1] * s.height);
    }
    return p..close();
  }

  @override
  bool shouldReclip(StarClipper old) => false;
}

class StarBadge extends StatelessWidget {
  final double size;
  final Color color;
  final Widget child;
  const StarBadge({super.key, this.size = 58, required this.color, required this.child});

  @override
  Widget build(BuildContext context) => ClipPath(
        clipper: const StarClipper(),
        child: Container(width: size, height: size, color: color, alignment: Alignment.center, child: child),
      );
}

class Box extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Border? border;
  final VoidCallback? onTap;
  const Box({super.key, required this.child, this.padding = const EdgeInsets.all(14), this.color, this.border, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: border,
        boxShadow: color == null ? softShadow(context) : null,
      ),
      child: child,
    );
    if (onTap == null) return c;
    return Material(
      color: Colors.transparent,
      child: InkWell(borderRadius: BorderRadius.circular(20), onTap: onTap, child: c),
    );
  }
}

class Pill extends StatelessWidget {
  final String text;
  final Color bg, fg;
  final IconData? icon;
  const Pill(this.text, {super.key, this.bg = const Color(0xFFF1F3F6), this.fg = ink, this.icon});

  @override
  Widget build(BuildContext context) {
    final dark = isDark(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: dark ? fg.withValues(alpha: 0.28) : bg, borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 14, color: dark ? Colors.white70 : fg), const SizedBox(width: 4)],
        Flexible(
          child: Text(text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: dark ? Colors.white : fg)),
        ),
      ]),
    );
  }
}

/// شارة «مفتوح» بنقطة خضراء
class OpenPill extends StatelessWidget {
  final String text;
  const OpenPill({super.key, this.text = 'مفتوح الآن'});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: isDark(context) ? tea.withValues(alpha: 0.3) : teaSoft, borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 8, height: 8, decoration: const BoxDecoration(color: tea, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: teaOf(context))),
        ]),
      );
}

Widget statusPill(Doc o) {
  switch (o['status']) {
    case 'new':
      return const Pill('جديد', bg: inkSoft, fg: ink);
    case 'prep':
      return isAny(o)
          ? Pill(o['courierUid'] != null ? 'يشتري' : 'نبحث', bg: saffronSoft, fg: saffronText)
          : const Pill('قيد التحضير', bg: saffronSoft, fg: saffronText);
    case 'ready':
      return const Pill('جاهز', bg: brandSoft, fg: brandDark);
    case 'road':
      return const Pill('في الطريق', bg: brandSoft, fg: brandDark);
    case 'done':
      return const OpenPill(text: 'تم التوصيل');
    case 'rejected':
      return const Pill('مرفوض');
    default:
      return const Pill('ملغى');
  }
}

/// معلومة صغيرة: أيقونة ونص (بدل النقاط الفاصلة)
class Meta extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;
  const Meta(this.icon, this.text, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).hintColor;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 15, color: c),
      const SizedBox(width: 4),
      Text(text, style: TextStyle(fontSize: 13, color: c)),
    ]);
  }
}

class RatingChip extends StatelessWidget {
  final Doc x;
  final bool showNew;
  const RatingChip(this.x, {super.key, this.showNew = false});

  @override
  Widget build(BuildContext context) {
    final a = avgRating(x);
    if (a == null) {
      return showNew ? Text('جديد', style: TextStyle(fontSize: 12.5, color: Theme.of(context).hintColor)) : const SizedBox.shrink();
    }
    return Row(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.star_rounded, size: 18, color: star),
      const SizedBox(width: 2),
      Text(a.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
      Text(' (${asInt(x['ratingCount'])})', style: TextStyle(fontSize: 12.5, color: Theme.of(context).hintColor)),
    ]);
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  final String? trailing;
  const SectionTitle(this.title, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 19))),
          if (trailing != null) Text(trailing!, style: TextStyle(fontSize: 13, color: Theme.of(context).hintColor)),
        ]),
      );
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title, text;
  final Widget? action;
  const EmptyState({super.key, required this.icon, required this.title, this.text = '', this.action});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          StarBadge(
            size: 72,
            color: isDark(context) ? brand.withValues(alpha: 0.3) : brandSoft,
            child: Icon(icon, size: 30, color: isDark(context) ? Colors.white : brandDark),
          ),
          const SizedBox(height: 14),
          Text(title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
          if (text.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(text, style: TextStyle(color: Theme.of(context).hintColor), textAlign: TextAlign.center),
          ],
          if (action != null) ...[const SizedBox(height: 14), action!],
        ]),
      );
}

/// زر مربع صغير بزوايا مدوّرة (الإنقاص رمادي، والزيادة بلون الهريسة)
class _StepBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool primary;
  final VoidCallback? onTap;
  const _StepBtn(this.icon, this.label, this.primary, this.onTap);

  @override
  Widget build(BuildContext context) {
    final dark = isDark(context);
    final bg = primary ? brand : (dark ? Colors.white12 : const Color(0xFFF1F3F6));
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      child: Material(
        color: onTap == null ? bg.withValues(alpha: 0.4) : bg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: SizedBox(
            width: 38,
            height: 44,
            child: Icon(icon, size: 20, color: primary ? Colors.white : (dark ? Colors.white : ink)),
          ),
        ),
      ),
    );
  }
}

class QtyStepper extends StatelessWidget {
  final int qty;
  final VoidCallback onAdd, onSub;
  final bool enabled;
  const QtyStepper({super.key, required this.qty, required this.onAdd, required this.onSub, this.enabled = true});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        _StepBtn(Icons.remove_rounded, 'إنقاص', false, onSub),
        SizedBox(
          width: 30,
          child: Text('$qty', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        ),
        _StepBtn(Icons.add_rounded, 'زيادة', true, enabled ? onAdd : null),
      ]);
}

/// صورة المنتج في مربع بزوايا مدوّرة على لون القسم.
/// الصورة المقصوصة الخلفية (cut) تظهر كاملة فوق اللون، والعادية تملأ المربع.
class ItemThumb extends StatelessWidget {
  final Doc product;
  final String cat;
  final double size;
  const ItemThumb({super.key, required this.product, required this.cat, this.size = 88});

  @override
  Widget build(BuildContext context) {
    final img = app.productImage(product);
    final c = catOf(cat);
    final dark = isDark(context);
    final bg = dark ? c.fg.withValues(alpha: 0.3) : c.bg;
    final r = BorderRadius.circular(size * 0.22);
    Widget inner;
    if (img == null) {
      inner = Text(firstChar('${product['name'] ?? ''}'),
          style: TextStyle(
              fontFamily: Theme.of(context).textTheme.titleLarge?.fontFamily,
              fontSize: size * 0.36,
              fontWeight: FontWeight.w800,
              color: dark ? Colors.white : c.fg));
    } else if (product['cut'] == true) {
      inner = Padding(padding: EdgeInsets.all(size * 0.06), child: Image.memory(img, fit: BoxFit.contain, gaplessPlayback: true));
    } else {
      inner = Image.memory(img, fit: BoxFit.cover, width: size, height: size, gaplessPlayback: true);
    }
    return ClipRRect(
      borderRadius: r,
      child: Container(width: size, height: size, color: bg, alignment: Alignment.center, child: inner),
    );
  }
}

class Line extends StatelessWidget {
  final String label, value;
  final bool bold;
  final Color? color;
  const Line(this.label, this.value, {super.key, this.bold = false, this.color});

  @override
  Widget build(BuildContext context) {
    final st = TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w500, fontSize: bold ? 15 : 14, color: color);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
        Expanded(child: Text(label, style: bold ? st : st.copyWith(color: color ?? Theme.of(context).hintColor))),
        Text(value,
            style: bold
                ? Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 21, fontWeight: FontWeight.w800, color: color)
                : st),
      ]),
    );
  }
}

/// زر مربع أبيض (رجوع، مفضلة) يطفو فوق الصور والخرائط
class FloatBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;
  const FloatBtn({super.key, required this.icon, required this.tooltip, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        icon: Icon(icon, size: 22),
        style: IconButton.styleFrom(
          fixedSize: const Size(44, 44),
          backgroundColor: Theme.of(context).colorScheme.surface,
          foregroundColor: color ?? Theme.of(context).colorScheme.onSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
}

class ShopCard extends StatelessWidget {
  final Doc shop;
  final bool mini;
  final List<Doc> hits;
  final VoidCallback onTap;
  const ShopCard({super.key, required this.shop, required this.onTap, this.mini = false, this.hits = const []});

  @override
  Widget build(BuildContext context) {
    final open = app.isOpen(shop);
    final cover = app.shopCover(shop);
    final c = catOf(shop['cat']);
    final offers = app.shopCoupons(shop['id']);
    final fav = app.favs.contains(shop['id']);
    final zone = app.currentZone;
    final prep = asInt(shop['prepMin']) > 0 ? asInt(shop['prepMin']) : 15;
    final dist = mini ? null : app.distanceTo(shop);
    final dark = isDark(context);
    return Container(
      width: mini ? 220 : null,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: softShadow(context),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
              height: mini ? 96 : 128,
              child: Stack(fit: StackFit.expand, children: [
                if (cover != null)
                  Image.memory(cover, fit: BoxFit.cover, gaplessPlayback: true)
                else
                  Container(
                    color: dark ? c.fg.withValues(alpha: 0.3) : c.bg,
                    child: Icon(c.icon, size: mini ? 42 : 54, color: dark ? Colors.white70 : c.fg),
                  ),
                if (!open)
                  Container(
                    color: ink.withValues(alpha: 0.62),
                    alignment: Alignment.center,
                    child: Text(app.closedLabel(shop), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                if (open && !mini)
                  PositionedDirectional(
                    top: 10,
                    start: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(width: 8, height: 8, decoration: const BoxDecoration(color: tea, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        const Text('مفتوح', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: teaDark)),
                      ]),
                    ),
                  ),
                if (offers.isNotEmpty)
                  PositionedDirectional(
                    bottom: 10,
                    start: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: star, borderRadius: BorderRadius.circular(10)),
                      child: Text(app.couponLabel(offers.first), style: const TextStyle(color: ink, fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ),
                PositionedDirectional(
                  top: 4,
                  end: 4,
                  child: IconButton(
                    tooltip: fav ? 'إزالة من المفضلة' : 'أضف إلى المفضلة',
                    onPressed: () => app.toggleFav(shop['id']),
                    style: IconButton.styleFrom(backgroundColor: Colors.white, fixedSize: const Size(40, 40)),
                    icon: Icon(fav ? Icons.favorite_rounded : Icons.favorite_border_rounded, size: 21, color: fav ? brand : muted),
                  ),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text('${shop['name']}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: mini ? 16 : 18.5, fontWeight: FontWeight.w700)),
                  ),
                  RatingChip(shop),
                ]),
                const SizedBox(height: 4),
                Wrap(spacing: 14, runSpacing: 4, children: [
                  if (mini) Text(c.label, style: TextStyle(fontSize: 13, color: Theme.of(context).hintColor)),
                  if (!mini) Meta(Icons.schedule_rounded, '${prep + 10}–${prep + 25} د'),
                  if (zone != null) Meta(Icons.delivery_dining_rounded, money(asInt(zone['fee']))),
                  if (dist != null) Meta(Icons.place_outlined, kmText(dist)),
                ]),
                if (hits.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('فيه: ${hits.take(3).map((p) => p['name']).join('، ')}',
                        style: TextStyle(fontSize: 13, color: accentOf(context), fontWeight: FontWeight.w600)),
                  ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// مراحل الطلب كشرائط أفقية: المنجز بالأخضر، الحالي بالهريسة، والقادم رمادي
class Steps extends StatelessWidget {
  final List<String> labels;
  final int index;
  final bool finished;
  const Steps({super.key, required this.labels, required this.index, required this.finished});

  @override
  Widget build(BuildContext context) {
    final hint = Theme.of(context).hintColor;
    final accent = accentOf(context);
    final off = isDark(context) ? Colors.white12 : const Color(0xFFE3E7ED);
    return Semantics(
      label: 'مراحل الطلب: ${labels[index.clamp(0, labels.length - 1)]}، المرحلة ${index + 1} من ${labels.length}',
      excludeSemantics: true,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (int i = 0; i < labels.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: (i < index || (i == index && finished)) ? tea : (i == index ? accent : off),
                ),
              ),
              const SizedBox(height: 6),
              Text(labels[i],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: i == index ? FontWeight.w700 : FontWeight.w600,
                    color: (i < index || (i == index && finished)) ? teaOf(context) : (i == index ? accent : hint),
                  )),
            ]),
          ),
        ],
      ]),
    );
  }
}

/// دائرة تحميل لا تعلق بصمت: بعد 15 ثانية تشرح السبب المحتمل وتعرض «أعد المحاولة»
class SlowSpinner extends StatefulWidget {
  final VoidCallback? onRetry;
  const SlowSpinner({super.key, this.onRetry});
  @override
  State<SlowSpinner> createState() => _SlowSpinnerState();
}

class _SlowSpinnerState extends State<SlowSpinner> {
  bool slow = false;
  Timer? t;

  @override
  void initState() {
    super.initState();
    t = Timer(const Duration(seconds: 15), () {
      if (mounted) setState(() => slow = true);
    });
  }

  @override
  void dispose() {
    t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const CircularProgressIndicator(),
              if (slow) ...[
                const SizedBox(height: 20),
                Text('الاتصال يأخذ وقتاً أطول من المعتاد', style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
                const SizedBox(height: 6),
                Text('تحقق من الإنترنت (جرّب الواي فاي بدل بيانات الهاتف أو العكس، وأوقف أي VPN)، وتأكد أن تاريخ الهاتف وساعته صحيحان.',
                    textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).hintColor, height: 1.5)),
                if (widget.onRetry != null) ...[
                  const SizedBox(height: 16),
                  FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size(160, 48)),
                    onPressed: () {
                      setState(() => slow = false);
                      t?.cancel();
                      t = Timer(const Duration(seconds: 15), () {
                        if (mounted) setState(() => slow = true);
                      });
                      widget.onRetry!();
                    },
                    child: const Text('أعد المحاولة'),
                  ),
                ],
              ],
            ]),
          ),
        ),
      );
}
