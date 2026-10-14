import 'package:flutter/material.dart';

import 'store.dart';

const brand = Color(0xFF0F6B4F);
const brandDark = Color(0xFF084532);
const orange = Color(0xFFE8890C);
const star = Color(0xFFF2A516);
const info = Color(0xFF1D4E89);

const heroGradient = LinearGradient(
  begin: Alignment.topRight,
  end: Alignment.bottomLeft,
  colors: [Color(0xFF0F6B4F), Color(0xFF0B5640), Color(0xFF084532)],
);
const anyGradient = LinearGradient(
  begin: Alignment.topRight,
  end: Alignment.bottomLeft,
  colors: [Color(0xFFD9770A), Color(0xFFB45F06)],
);

class Cat {
  final String id, label;
  final IconData icon;
  final Color bg, fg;
  const Cat(this.id, this.label, this.icon, this.bg, this.fg);
}

const cats = <Cat>[
  Cat('food', 'مطاعم', Icons.restaurant_rounded, Color(0xFFFCE9DC), Color(0xFF8A3414)),
  Cat('bread', 'مخابز وحلويات', Icons.bakery_dining_rounded, Color(0xFFF6EED8), Color(0xFF6E500F)),
  Cat('veg', 'خضر وفواكه', Icons.eco_rounded, Color(0xFFE2F1EA), Color(0xFF0A5A41)),
  Cat('grocery', 'مواد غذائية', Icons.local_grocery_store_rounded, Color(0xFFE3ECF7), Color(0xFF1D4E89)),
  Cat('meat', 'لحوم ودجاج', Icons.kebab_dining_rounded, Color(0xFFFBE4E4), Color(0xFF8E1F1F)),
  Cat('pharma', 'شبه صيدلية', Icons.local_pharmacy_rounded, Color(0xFFE1F3F4), Color(0xFF0E6168)),
  Cat('other', 'محلات أخرى', Icons.storefront_rounded, Color(0xFFFFF1DC), Color(0xFF8A4B00)),
];

String firstChar(String s) => s.trim().isEmpty ? '?' : s.trim().characters.first;

Cat catOf(String? id) => cats.firstWhere((c) => c.id == id, orElse: () => cats.last);

List<BoxShadow> softShadow(BuildContext context) => Theme.of(context).brightness == Brightness.dark
    ? const []
    : [BoxShadow(color: const Color(0xFF14201B).withValues(alpha: 0.07), blurRadius: 16, offset: const Offset(0, 4))];

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
        borderRadius: BorderRadius.circular(18),
        border: border,
        boxShadow: softShadow(context),
      ),
      child: child,
    );
    if (onTap == null) return c;
    return Material(
      color: Colors.transparent,
      child: InkWell(borderRadius: BorderRadius.circular(18), onTap: onTap, child: c),
    );
  }
}

class Pill extends StatelessWidget {
  final String text;
  final Color bg, fg;
  final IconData? icon;
  const Pill(this.text, {super.key, this.bg = const Color(0xFFEEF2F0), this.fg = const Color(0xFF56625C), this.icon});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: dark ? fg.withValues(alpha: 0.22) : bg, borderRadius: BorderRadius.circular(9)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 14, color: dark ? Colors.white70 : fg), const SizedBox(width: 4)],
        Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: dark ? Colors.white : fg)),
      ]),
    );
  }
}

Pill statusPill(Doc o) {
  switch (o['status']) {
    case 'new':
      return const Pill('جديد', bg: Color(0xFFFCE9DC), fg: Color(0xFF8A3414));
    case 'prep':
      return isAny(o)
          ? Pill(o['courierUid'] != null ? 'يشتري' : 'نبحث', bg: const Color(0xFFFFF1DC), fg: const Color(0xFF8A4B00))
          : const Pill('قيد التحضير', bg: Color(0xFFF6EED8), fg: Color(0xFF6E500F));
    case 'ready':
      return const Pill('جاهز', bg: Color(0xFFE3ECF7), fg: info);
    case 'road':
      return const Pill('في الطريق', bg: Color(0xFFE3ECF7), fg: info);
    case 'done':
      return const Pill('تم التوصيل', bg: Color(0xFFE2F1EA), fg: Color(0xFF0A5A41));
    case 'rejected':
      return const Pill('مرفوض');
    default:
      return const Pill('ملغى');
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
      return showNew ? Text('جديد', style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)) : const SizedBox.shrink();
    }
    return Row(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.star_rounded, size: 17, color: star),
      const SizedBox(width: 2),
      Text(a.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      Text(' (${asInt(x['ratingCount'])})', style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
    ]);
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  final String? trailing;
  const SectionTitle(this.title, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
        child: Row(children: [
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 18))),
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
          CircleAvatar(
            radius: 34,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Icon(icon, size: 32, color: Theme.of(context).hintColor),
          ),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16), textAlign: TextAlign.center),
          if (text.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(text, style: TextStyle(color: Theme.of(context).hintColor), textAlign: TextAlign.center),
          ],
          if (action != null) ...[const SizedBox(height: 14), action!],
        ]),
      );
}

class QtyStepper extends StatelessWidget {
  final int qty;
  final VoidCallback onAdd, onSub;
  final bool enabled;
  const QtyStepper({super.key, required this.qty, required this.onAdd, required this.onSub, this.enabled = true});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = dark ? const Color(0xFF86D9B6) : const Color(0xFF0A5A41);
    return Container(
      decoration: BoxDecoration(color: dark ? const Color(0xFF16352A) : const Color(0xFFE2F1EA), borderRadius: BorderRadius.circular(13)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(onPressed: enabled ? onAdd : null, icon: Icon(Icons.add_rounded, color: fg), tooltip: 'زيادة'),
        Text('$qty', style: TextStyle(fontWeight: FontWeight.w700, color: fg, fontSize: 16)),
        IconButton(onPressed: onSub, icon: Icon(Icons.remove_rounded, color: fg), tooltip: 'إنقاص'),
      ]),
    );
  }
}

class ItemThumb extends StatelessWidget {
  final Doc product;
  final String cat;
  final double size;
  const ItemThumb({super.key, required this.product, required this.cat, this.size = 88});

  @override
  Widget build(BuildContext context) {
    final img = app.productImage(product);
    final c = catOf(cat);
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: size,
        height: size,
        child: img != null
            ? Image.memory(img, fit: BoxFit.cover, gaplessPlayback: true)
            : Container(
                color: c.bg,
                alignment: Alignment.center,
                child: Text(firstChar('${product['name'] ?? ''}'),
                    style: TextStyle(fontSize: size * 0.32, fontWeight: FontWeight.w700, color: c.fg)),
              ),
      ),
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
    final st = TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w500, fontSize: bold ? 16 : 14, color: color);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(child: Text(label, style: bold ? st : st.copyWith(color: color ?? Theme.of(context).hintColor))),
        Text(value, style: st),
      ]),
    );
  }
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
    final hint = Theme.of(context).hintColor;
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
              height: mini ? 100 : 136,
              child: Stack(fit: StackFit.expand, children: [
                if (cover != null)
                  Image.memory(cover, fit: BoxFit.cover, gaplessPlayback: true)
                else
                  Container(color: c.bg, child: Icon(c.icon, size: mini ? 44 : 58, color: c.fg)),
                if (!open)
                  Container(
                    color: Colors.black.withValues(alpha: 0.55),
                    alignment: Alignment.center,
                    child: Text(app.closedLabel(shop), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                if (offers.isNotEmpty)
                  PositionedDirectional(
                    bottom: 10,
                    start: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(color: orange, borderRadius: BorderRadius.circular(8)),
                      child: Text(app.couponLabel(offers.first),
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ),
                PositionedDirectional(
                  top: 8,
                  end: 8,
                  child: Material(
                    color: Colors.white.withValues(alpha: 0.92),
                    shape: const CircleBorder(),
                    child: IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: fav ? 'إزالة من المفضلة' : 'أضف إلى المفضلة',
                      onPressed: () => app.toggleFav(shop['id']),
                      icon: Icon(fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: fav ? const Color(0xFFC2410C) : const Color(0xFF56625C)),
                    ),
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
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
                  RatingChip(shop),
                ]),
                const SizedBox(height: 4),
                Wrap(spacing: 10, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Text(c.label, style: TextStyle(fontSize: 12.5, color: hint)),
                  if (!mini)
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.schedule_rounded, size: 14, color: hint),
                      const SizedBox(width: 3),
                      Text('${prep + 10}–${prep + 25} د', style: TextStyle(fontSize: 12.5, color: hint)),
                    ]),
                  if (zone != null) Text('التوصيل ${money(asInt(zone['fee']))}', style: TextStyle(fontSize: 12.5, color: hint)),
                  if (app.distanceTo(shop) != null)
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.near_me_rounded, size: 14, color: hint),
                      const SizedBox(width: 3),
                      Text(kmText(app.distanceTo(shop)!), style: TextStyle(fontSize: 12.5, color: hint)),
                    ]),
                ]),
                if (hits.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('فيه: ${hits.take(3).map((p) => p['name']).join('، ')}',
                        style: const TextStyle(fontSize: 12.5, color: brand, fontWeight: FontWeight.w600)),
                  ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// الخطوط الملوّنة لمراحل الطلب
class Steps extends StatelessWidget {
  final List<List<String>> steps;
  final int index;
  final bool finished;
  const Steps({super.key, required this.steps, required this.index, required this.finished});

  @override
  Widget build(BuildContext context) {
    final hint = Theme.of(context).hintColor;
    final primary = Theme.of(context).colorScheme.primary;
    return Box(
      child: Column(children: [
        for (int i = 0; i < steps.length; i++)
          IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SizedBox(
                width: 30,
                child: Column(children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (i < index || (i == index && finished)) ? primary : Colors.transparent,
                      border: Border.all(color: i <= index ? primary : Theme.of(context).dividerColor, width: i == index && !finished ? 7 : 2),
                    ),
                    child: (i < index || (i == index && finished)) ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
                  ),
                  if (i < steps.length - 1)
                    Expanded(child: Container(width: 2, margin: const EdgeInsets.symmetric(vertical: 2), color: i < index ? primary : Theme.of(context).dividerColor)),
                ]),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(steps[i][0], style: TextStyle(fontWeight: i == index ? FontWeight.w700 : FontWeight.w600, color: i <= index ? null : hint)),
                    Text(steps[i][1], style: TextStyle(fontSize: 13, color: hint)),
                  ]),
                ),
              ),
            ]),
          ),
      ]),
    );
  }
}
