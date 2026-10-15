import 'package:flutter/material.dart';

import '../store.dart';
import '../ui.dart';
import 'shell.dart';
import 'stories.dart';

class ShopScreen extends StatefulWidget {
  final String shopId;
  const ShopScreen({super.key, required this.shopId});
  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  List<Doc>? reviews;
  bool loadingReviews = false;

  Future<void> _loadReviews() async {
    setState(() => loadingReviews = true);
    try {
      final r = await app.loadReviews(widget.shopId);
      if (mounted) setState(() => reviews = r);
    } catch (e) {
      app.toast(errText(e));
    }
    if (mounted) setState(() => loadingReviews = false);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final s = app.shop(widget.shopId);
        if (s == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        final open = app.isOpen(s);
        final c = catOf(s['cat']);
        final cover = app.shopCover(s);
        final fav = app.favs.contains(s['id']);
        final prods = app.productsOf(s['id']);
        final sections = <String>[];
        for (final p in prods) {
          final sec = '${p['section'] ?? ''}';
          if (!sections.contains(sec)) sections.add(sec);
        }
        final zone = app.currentZone;
        final offers = app.shopCoupons(s['id']);
        final stories = app.postsOf(s, 'story'), ads = app.postsOf(s, 'ad');
        final ci = app.cartInfo();
        final showBar = app.cartShop == s['id'] && ci.count > 0;
        final prep = asInt(s['prepMin']) > 0 ? asInt(s['prepMin']) : 15;
        final hint = Theme.of(context).hintColor;
        final h = s['hours'];

        return Scaffold(
          body: CustomScrollView(slivers: [
            SliverAppBar(
              expandedHeight: 210,
              pinned: true,
              backgroundColor: c.bg,
              foregroundColor: Colors.black87,
              leading: Padding(
                padding: const EdgeInsets.all(6),
                child: CircleAvatar(
                  backgroundColor: Colors.white.withValues(alpha: 0.92),
                  child: const BackButton(color: Colors.black87),
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: CircleAvatar(
                    backgroundColor: Colors.white.withValues(alpha: 0.92),
                    child: IconButton(
                      tooltip: fav ? 'إزالة من المفضلة' : 'أضف إلى المفضلة',
                      onPressed: () => app.toggleFav(s['id']),
                      icon: Icon(fav ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: const Color(0xFFC2410C)),
                    ),
                  ),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: cover != null
                    ? Image.memory(cover, fit: BoxFit.cover, gaplessPlayback: true)
                    : Container(color: c.bg, child: Icon(c.icon, size: 80, color: c.fg)),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Box(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(child: Text('${s['name']}', style: Theme.of(context).textTheme.titleLarge)),
                      RatingChip(s, showNew: true),
                    ]),
                    const SizedBox(height: 4),
                    Text('${c.label}${(s['desc'] ?? '').toString().isNotEmpty ? ' · ${s['desc']}' : ''}', style: TextStyle(color: hint, fontSize: 13)),
                    const SizedBox(height: 10),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      open
                          ? const Pill('مفتوح الآن', bg: Color(0xFFE2F1EA), fg: Color(0xFF0A5A41))
                          : Pill(app.closedLabel(s)),
                      if (zone != null) Pill('التوصيل إلى ${zone['name']}: ${money(asInt(zone['fee']))}'),
                      Pill('${prep + 10}–${prep + 25} د', icon: Icons.schedule_rounded),
                      if (h is Map && h['from'] != null) Pill('${h['from']} – ${h['to']}', icon: Icons.access_time_rounded),
                      if (asInt(s['minOrder']) > 0) Pill('أقل طلب ${money(asInt(s['minOrder']))}'),
                    ]),
                  ]),
                ),
              ),
            ),
            if (!open)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Box(
                    color: const Color(0xFFFCE9DC),
                    child: const Text('المحل مغلق الآن. يمكنك تصفّح المنتجات، والطلب يكون عند فتحه.',
                        style: TextStyle(color: Color(0xFF8A3414), fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            if (stories.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Box(
                    onTap: () => openStories(context, [s], 0),
                    child: Row(children: [
                      StoryAvatar(shop: s, onTap: () => openStories(context, [s], 0), size: 48, showName: false),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('يوميات المحل اليوم', style: TextStyle(fontWeight: FontWeight.w700)),
                          Text(app.storySeen(s) ? 'شاهدتها · اضغط لتعيدها' : 'جديد · اضغط لتشاهد',
                              style: TextStyle(color: hint, fontSize: 13)),
                        ]),
                      ),
                      const Icon(Icons.play_circle_fill_rounded, color: orange, size: 32),
                    ]),
                  ),
                ),
              ),
            for (final ad in ads)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: _AdCard(ad: ad),
                ),
              ),
            for (final cp in offers)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Box(
                    color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF3A2A12) : const Color(0xFFFFF1DC),
                    border: Border.all(color: orange),
                    onTap: () {
                      app.setCoupon('${cp['code']}');
                      app.toast('سيُطبَّق الرمز ${cp['code']} على طلبك من هذا المحل');
                    },
                    child: Row(children: [
                      const Icon(Icons.local_offer_rounded, color: orange),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${app.couponLabel(cp)}${asInt(cp['minOrder']) > 0 ? ' للطلبات من ${money(asInt(cp['minOrder']))}' : ''}',
                              style: const TextStyle(fontWeight: FontWeight.w800, color: orange)),
                          Text(app.coupon == cp['code'] ? 'سيُطبَّق على طلبك ✓' : 'اضغط لاستعمال الرمز ${cp['code']}',
                              style: const TextStyle(fontSize: 13)),
                        ]),
                      ),
                    ]),
                  ),
                ),
              ),
            if (!app.productsLoaded)
              const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())))
            else if (prods.isEmpty)
              const SliverToBoxAdapter(child: EmptyState(icon: Icons.inventory_2_outlined, title: 'لم يضف هذا المحل منتجاته بعد'))
            else
              for (final sec in sections) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                    child: Text(sec.isEmpty ? 'منتجات' : sec, style: Theme.of(context).textTheme.titleMedium),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList.separated(
                    itemCount: prods.where((p) => '${p['section'] ?? ''}' == sec).length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final p = prods.where((p) => '${p['section'] ?? ''}' == sec).elementAt(i);
                      return _ProductTile(p: p, cat: '${s['cat']}', open: open);
                    },
                  ),
                ),
              ],
            if (asInt(s['ratingCount']) > 0)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: Box(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text('آراء الزبائن', style: Theme.of(context).textTheme.titleMedium)),
                        RatingChip(s),
                      ]),
                      const SizedBox(height: 8),
                      if (reviews == null)
                        OutlinedButton(onPressed: loadingReviews ? null : _loadReviews, child: const Text('اعرض التعليقات'))
                      else if (reviews!.isEmpty)
                        Text('لا توجد تعليقات مكتوبة بعد.', style: TextStyle(color: hint))
                      else
                        for (final r in reviews!)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                Expanded(child: Text('${r['name'] ?? 'زبون'}', style: const TextStyle(fontWeight: FontWeight.w700))),
                                for (int k = 1; k <= 5; k++)
                                  Icon(Icons.star_rounded, size: 16, color: k <= asInt(r['shop']) ? star : Theme.of(context).dividerColor),
                              ]),
                              if ('${r['comment'] ?? ''}'.isNotEmpty) Text('${r['comment']}'),
                              Text(ago(asInt(r['createdAtMs'])), style: TextStyle(fontSize: 12, color: hint)),
                            ]),
                          ),
                    ]),
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ]),
          bottomNavigationBar: showBar
              ? SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: FilledButton(
                      onPressed: () {
                        tab.value = 3;
                        Navigator.of(context).popUntil((r) => r.isFirst);
                      },
                      child: Row(children: [
                        Text('عرض السلة · ${ci.count}'),
                        const Spacer(),
                        Text(money(ci.subtotal)),
                      ]),
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }
}

class _ProductTile extends StatelessWidget {
  final Doc p;
  final String cat;
  final bool open;
  const _ProductTile({required this.p, required this.cat, required this.open});

  @override
  Widget build(BuildContext context) {
    final off = p['available'] != true;
    final n = app.qtyInCart(p['id']);
    final opt = hasOpts(p);
    final simpleLine = app.cart[p['id']];
    final hint = Theme.of(context).hintColor;
    Widget right;
    if (off) {
      right = const Pill('نفد حالياً');
    } else if (!opt && simpleLine != null) {
      right = QtyStepper(
        qty: simpleLine.qty,
        enabled: open,
        onAdd: () => app.changeQty(p['id'], 1),
        onSub: () => app.changeQty(p['id'], -1),
      );
    } else {
      right = IconButton.filled(
        tooltip: 'أضف ${p['name']}',
        onPressed: open ? () => addProduct(context, p) : null,
        icon: const Icon(Icons.add_rounded),
        style: IconButton.styleFrom(backgroundColor: ink, foregroundColor: Colors.white, shape: const CircleBorder()),
      );
    }
    return Opacity(
      opacity: off ? 0.6 : 1,
      child: Box(
        padding: const EdgeInsets.all(12),
        onTap: off ? null : () => openProductSheet(context, p),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ItemThumb(product: p, cat: cat, size: 96),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 96,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: Text('${p['name']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
                  if (n > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                      decoration: BoxDecoration(color: brand, borderRadius: BorderRadius.circular(10)),
                      child: Text('×$n', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                ]),
                if ('${p['desc'] ?? ''}'.isNotEmpty)
                  Text('${p['desc']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: hint)),
                const Spacer(),
                Row(children: [
                  Expanded(
                    child: Text('${optList(p['sizes']).isNotEmpty ? 'من ' : ''}${money(basePrice(p))}',
                        style: const TextStyle(fontWeight: FontWeight.w800, color: brand, fontSize: 15)),
                  ),
                  right,
                ]),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

/// إضافة سريعة للمنتج البسيط، أو فتح نافذة الخيارات
Future<void> addProduct(BuildContext context, Doc p) async {
  if (hasOpts(p)) return openProductSheet(context, p);
  await addWithConfirm(context, p, CartLine(pid: p['id']));
}

Future<bool> addWithConfirm(BuildContext context, Doc p, CartLine line) async {
  if (app.addLine(p, line)) return true;
  final other = app.shop(app.cartShop);
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('سلتك فيها منتجات من محل آخر'),
      content: Text('الطلب الواحد يكون من محل واحد. هل تفرغ سلتك من ${other?['name'] ?? 'المحل الآخر'} وتبدأ من هذا المحل؟'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('تراجع')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('أفرغ السلة')),
      ],
    ),
  );
  if (ok == true) return app.addLine(p, line, replace: true);
  return false;
}

Future<void> openProductSheet(BuildContext context, Doc p) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => _ProductSheet(p: p, parent: context),
  );
}

class _ProductSheet extends StatefulWidget {
  final Doc p;
  final BuildContext parent;
  const _ProductSheet({required this.p, required this.parent});
  @override
  State<_ProductSheet> createState() => _ProductSheetState();
}

class _ProductSheetState extends State<_ProductSheet> {
  late String size;
  final extras = <String>[];
  final note = TextEditingController();
  int qty = 1;

  @override
  void initState() {
    super.initState();
    final sizes = optList(widget.p['sizes']);
    size = sizes.length == 1 ? '${sizes.first['name']}' : '';
  }

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    final s = app.shop(p['shopId']);
    final open = app.isOpen(s);
    final sizes = optList(p['sizes']), exs = optList(p['extras']);
    final needSize = sizes.isNotEmpty;
    final unit = linePrice(p, size, extras);
    final can = open && p['available'] == true && (!needSize || size.isNotEmpty);
    final img = app.productImage(p);
    final hint = Theme.of(context).hintColor;
    final prep = asInt(s?['prepMin']) > 0 ? asInt(s?['prepMin']) : 15;
    final rating = s == null ? null : avgRating(s);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Flexible(
            child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(18, 0, 18, 8), children: [
              const SizedBox(height: 4),
              // رأس المنتج مثل صفحة «Yummy! Noodles»: الاسم والسعر بالأخضر، معلومات صغيرة، وصورة كبيرة في دائرة
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Text('${p['name']}',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, height: 1.2)),
                ),
                const SizedBox(width: 10),
                Text(money(needSize && size.isEmpty ? basePrice(p) : linePrice(p, size, const [])),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: brand)),
              ]),
              const SizedBox(height: 14),
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _Stat('${prep + 10}–${prep + 25} د', 'التوصيل'),
                  const SizedBox(height: 14),
                  _Stat(rating != null ? rating.toStringAsFixed(1) : 'جديد', 'التقييم'),
                  const SizedBox(height: 14),
                  _Stat('${s?['name'] ?? ''}', 'المحل'),
                ]),
                const SizedBox(width: 12),
                Expanded(
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: ItemThumb(product: p, cat: '${s?['cat'] ?? ''}', size: img != null ? 190 : 140),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 6),
              if ('${p['desc'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('${p['desc']}', style: TextStyle(color: hint))),
              if (needSize) ...[
                const SizedBox(height: 14),
                Row(children: [
                  const Expanded(child: Text('اختر الحجم', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
                  const Pill('مطلوب', bg: Color(0xFFFCE9DC), fg: Color(0xFF8A3414)),
                ]),
                for (final z in sizes)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    onTap: () => setState(() => size = '${z['name']}'),
                    leading: Icon(size == z['name'] ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                        color: size == z['name'] ? brand : hint),
                    title: Text('${z['name']}'),
                    trailing: Text(money(asInt(z['price'])), style: TextStyle(color: hint)),
                  ),
              ],
              if (exs.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Text('إضافات (اختياري)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                for (final x in exs)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: extras.contains(x['name']),
                    onChanged: (v) => setState(() {
                      if (v == true) {
                        extras.add('${x['name']}');
                      } else {
                        extras.remove(x['name']);
                      }
                    }),
                    title: Text('${x['name']}'),
                    secondary: Text('+${money(asInt(x['price']))}', style: TextStyle(color: hint)),
                  ),
              ],
              const SizedBox(height: 10),
              TextField(
                controller: note,
                maxLength: 80,
                decoration: const InputDecoration(labelText: 'ملاحظة على هذا المنتج (اختياري)', hintText: 'مثال: بدون بصل، حار قليلاً'),
              ),
              if (!open)
                const Text('المحل مغلق الآن.', style: TextStyle(color: Color(0xFF8A3414), fontWeight: FontWeight.w600)),
            ]),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 12),
              child: Row(children: [
                QtyStepper(qty: qty, onAdd: () => setState(() => qty = qty < 50 ? qty + 1 : qty), onSub: () => setState(() => qty = qty > 1 ? qty - 1 : 1)),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: can
                        ? () async {
                            final line = CartLine(pid: p['id'], qty: qty, size: size, extras: List.of(extras), note: note.text.trim());
                            final parent = widget.parent;
                            Navigator.pop(context);
                            if (!parent.mounted) return;
                            if (await addWithConfirm(parent, p, line)) app.toast('أُضيف «${p['name']}» إلى السلة');
                          }
                        : null,
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Flexible(
                        child: Text(needSize && size.isEmpty ? 'اختر الحجم أولاً' : 'أضف · ${money(unit * qty)}',
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      if (!(needSize && size.isEmpty)) ...[const SizedBox(width: 8), const Icon(Icons.arrow_forward_rounded, size: 20)],
                    ]),
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

/// إعلان من المحل: صورة اختيارية ونص
class _AdCard extends StatelessWidget {
  final Doc ad;
  const _AdCard({required this.ad});

  @override
  Widget build(BuildContext context) {
    final img = app.postImage(ad);
    final hint = Theme.of(context).hintColor;
    return Box(
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (ad['img'] == true)
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: img != null
                  ? Image.memory(img, fit: BoxFit.cover, gaplessPlayback: true)
                  : ColoredBox(color: Theme.of(context).colorScheme.surfaceContainerHighest),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Pill('إعلان', bg: Color(0xFFE3ECF7), fg: info, icon: Icons.campaign_rounded),
              const SizedBox(width: 8),
              Text(ago(asInt(ad['at'])), style: TextStyle(color: hint, fontSize: 12)),
            ]),
            if ('${ad['text'] ?? ''}'.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('${ad['text']}', style: const TextStyle(fontSize: 15, height: 1.45)),
            ],
          ]),
        ),
      ]),
    );
  }
}


class _Stat extends StatelessWidget {
  final String value, label;
  const _Stat(this.value, this.label);
  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 120),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
        ]),
      );
}
