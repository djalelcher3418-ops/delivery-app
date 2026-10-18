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
  String? section; // القسم المختار في شريط الأقسام
  final keys = <String, GlobalKey>{};
  final scroll = ScrollController();
  bool collapsed = false; // بعد تجاوز الغلاف يظهر شريط علوي باسم المحل

  @override
  void initState() {
    super.initState();
    scroll.addListener(() {
      final c = scroll.offset > 170;
      if (c != collapsed) setState(() => collapsed = c);
    });
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

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

  void _jump(String sec) {
    setState(() => section = sec);
    final ctx = keys[sec]?.currentContext;
    if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 350), curve: Curves.easeOut, alignment: 0.05);
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
        for (final sec in sections) {
          keys.putIfAbsent(sec, () => GlobalKey());
        }
        final zone = app.currentZone;
        final offers = app.shopCoupons(s['id']);
        final stories = app.postsOf(s, 'story'), ads = app.postsOf(s, 'ad');
        final ci = app.cartInfo();
        final showBar = app.cartShop == s['id'] && ci.count > 0;
        final prep = asInt(s['prepMin']) > 0 ? asInt(s['prepMin']) : 15;
        final hint = Theme.of(context).hintColor;
        final h = s['hours'];
        final dark = isDark(context);
        final top = MediaQuery.of(context).padding.top;
        final firstAd = stories.isNotEmpty && ads.isNotEmpty ? ads.first : null;

        return Scaffold(
          body: Stack(children: [
            CustomScrollView(controller: scroll, slivers: [
              // الغلاف، وبطاقة المحل تصعد فوقه
              SliverToBoxAdapter(
                child: Stack(children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 210 + top,
                    child: cover != null
                        ? Image.memory(cover, fit: BoxFit.cover, gaplessPlayback: true)
                        : Container(
                            color: dark ? c.fg.withValues(alpha: 0.3) : c.bg,
                            alignment: Alignment.center,
                            padding: EdgeInsets.only(top: top),
                            child: Icon(c.icon, size: 86, color: dark ? Colors.white70 : c.fg),
                          ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(16, 184 + top, 16, 0),
                    child: Box(
                      padding: const EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Expanded(child: Text('${s['name']}', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 26))),
                          Padding(padding: const EdgeInsets.only(top: 6), child: RatingChip(s, showNew: true)),
                        ]),
                        Text((s['desc'] ?? '').toString().isNotEmpty ? '${s['desc']}' : c.label, style: TextStyle(color: hint, fontSize: 14)),
                        const SizedBox(height: 12),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          open ? const OpenPill() : Pill(app.closedLabel(s), bg: brandSoft, fg: brandDark),
                          if (zone != null) Pill('التوصيل ${money(asInt(zone['fee']))}', icon: Icons.delivery_dining_rounded),
                          Pill('${prep + 10}–${prep + 25} دقيقة', icon: Icons.schedule_rounded),
                          if (h is Map && h['from'] != null) Pill('${h['from']} – ${h['to']}', icon: Icons.access_time_rounded),
                          if (asInt(s['minOrder']) > 0) Pill('أقل طلب ${money(asInt(s['minOrder']))}'),
                        ]),
                      ]),
                    ),
                  ),
                ]),
              ),
              if (!open)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Box(
                      color: dark ? brand.withValues(alpha: 0.25) : brandSoft,
                      child: Text('المحل مغلق الآن. يمكنك تصفّح المنتجات، والطلب يكون عند فتحه.',
                          style: TextStyle(color: dark ? Colors.white : brandDark, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              // يوميات اليوم (وبجانبها أحدث إعلان)
              if (stories.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: IntrinsicHeight(
                      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        if (firstAd == null)
                          Expanded(child: _StoryTile(shop: s, story: stories.first, wide: true))
                        else
                          _StoryTile(shop: s, story: stories.first, wide: false),
                        if (firstAd != null) ...[const SizedBox(width: 10), Expanded(child: _AdCard(ad: firstAd, compact: true))],
                      ]),
                    ),
                  ),
                ),
              for (final ad in ads.where((a) => a != firstAd))
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
                      color: dark ? star.withValues(alpha: 0.18) : saffronSoft,
                      border: Border.all(color: star, width: 1.5),
                      onTap: () {
                        app.setCoupon('${cp['code']}');
                        app.toast('سيُطبَّق الرمز ${cp['code']} على طلبك من هذا المحل');
                      },
                      child: Row(children: [
                        const StarBadge(size: 40, color: star, child: Icon(Icons.local_offer_rounded, color: ink, size: 20)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${app.couponLabel(cp)}${asInt(cp['minOrder']) > 0 ? ' للطلبات من ${money(asInt(cp['minOrder']))}' : ''}',
                                style: const TextStyle(fontWeight: FontWeight.w800)),
                            Text(app.coupon == cp['code'] ? 'سيُطبَّق على طلبك ✓' : 'اضغط لاستعمال الرمز ${cp['code']}',
                                style: const TextStyle(fontSize: 13)),
                          ]),
                        ),
                      ]),
                    ),
                  ),
                ),
              if (sections.length > 1)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 58,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                      itemCount: sections.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) => ChoiceChip(
                        label: Text(sections[i].isEmpty ? 'منتجات' : sections[i]),
                        selected: (section ?? sections.first) == sections[i],
                        showCheckmark: false,
                        onSelected: (_) => _jump(sections[i]),
                      ),
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
                      key: keys[sec],
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                      child: Text(sec.isEmpty ? 'منتجات' : sec, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 19)),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Box(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                        child: Column(children: [
                          for (final (i, p) in prods.where((p) => '${p['section'] ?? ''}' == sec).indexed) ...[
                            if (i > 0) Divider(height: 1, color: Theme.of(context).dividerColor),
                            _ProductTile(p: p, cat: '${s['cat']}', open: open),
                          ],
                        ]),
                      ),
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
                          Expanded(child: Text('آراء الزبائن', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 19))),
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
              SliverToBoxAdapter(child: SizedBox(height: showBar ? 110 : 32)),
            ]),
            // بعد التمرير: شريط علوي باسم المحل خلف الزرين
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: collapsed ? 1 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: Container(
                    height: top + 64,
                    padding: EdgeInsets.fromLTRB(72, top, 72, 0),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
                    ),
                    child: Text('${s['name']}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 18)),
                  ),
                ),
              ),
            ),
            // زرا الرجوع والمفضلة ثابتان فوق الغلاف
            PositionedDirectional(
              top: top + 10,
              start: 14,
              child: FloatBtn(icon: Icons.arrow_back_rounded, tooltip: 'رجوع', onTap: () => Navigator.of(context).maybePop()),
            ),
            PositionedDirectional(
              top: top + 10,
              end: 14,
              child: FloatBtn(
                icon: fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: brand,
                tooltip: fav ? 'إزالة من المفضلة' : 'أضف إلى المفضلة',
                onTap: () => app.toggleFav(s['id']),
              ),
            ),
            // شريط السلة: نيلي، والزر بلون الهريسة
            if (showBar)
              Positioned(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).padding.bottom + 14,
                child: Material(
                  color: dark ? const Color(0xFF2A3550) : ink,
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () {
                      tab.value = 3;
                      Navigator.of(context).popUntil((r) => r.isFirst);
                    },
                    child: SizedBox(
                      height: 62,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(children: [
                          Expanded(
                            child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('سلتك: ${itemsText(ci.count)}', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12.5)),
                              Text(money(ci.subtotal),
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontSize: 19, height: 1.15)),
                            ]),
                          ),
                          Container(
                            height: 42,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: brand, borderRadius: BorderRadius.circular(12)),
                            child: const Text('عرض السلة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                          ),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
          ]),
        );
      },
    );
  }
}

/// «2 منتجان»، «3 منتجات»، «11 منتجاً»
String itemsText(int n) => n == 1
    ? 'منتج واحد'
    : n == 2
        ? 'منتجان'
        : (n % 100 >= 3 && n % 100 <= 10)
            ? '$n منتجات'
            : '$n منتجاً';

/// بطاقة يوميات المحل: صورة اليومية أو نصها على لون الهريسة الداكن، مع حلقة إذا لم تُشاهد
class _StoryTile extends StatelessWidget {
  final Doc shop, story;
  final bool wide;
  const _StoryTile({required this.shop, required this.story, required this.wide});

  @override
  Widget build(BuildContext context) {
    final img = app.postImage(story);
    final seen = app.storySeen(shop);
    final text = '${story['text'] ?? ''}';
    return Semantics(
      button: true,
      label: 'يوميات المحل اليوم${seen ? '' : '، جديدة'}',
      child: Material(
        color: brandDark,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => openStories(context, [shop], 0),
          child: SizedBox(
            width: wide ? double.infinity : 112,
            height: 148,
            child: Stack(fit: StackFit.expand, children: [
              if (img != null) Image.memory(img, fit: BoxFit.cover, gaplessPlayback: true) else const Zellige(opacity: 0.1),
              if (img != null)
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.center, colors: [Colors.black54, Colors.transparent]),
                  ),
                ),
              PositionedDirectional(
                top: 10,
                start: 10,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: seen ? Colors.white54 : Colors.white, width: 2.5),
                  ),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 16),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Align(
                  alignment: AlignmentDirectional.bottomStart,
                  child: Text(
                    text.isNotEmpty && img == null ? text : 'يوميات اليوم',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontSize: 15, height: 1.3),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
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
    Widget? trailing;
    if (off) {
      trailing = null;
    } else if (!opt && simpleLine != null) {
      trailing = QtyStepper(
        qty: simpleLine.qty,
        enabled: open,
        onAdd: () => app.changeQty(p['id'], 1),
        onSub: () => app.changeQty(p['id'], -1),
      );
    } else {
      trailing = IconButton(
        tooltip: 'أضف ${p['name']}',
        onPressed: open ? () => addProduct(context, p) : null,
        icon: const Icon(Icons.add_rounded, size: 24),
        style: IconButton.styleFrom(
          backgroundColor: brand,
          foregroundColor: Colors.white,
          disabledBackgroundColor: isDark(context) ? Colors.white12 : const Color(0xFFE3E7ED),
          fixedSize: const Size(44, 44),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
    }
    return InkWell(
      onTap: off ? null : () => openProductSheet(context, p),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text('${p['name']}',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: off ? hint : null)),
                ),
                if (n > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                    decoration: BoxDecoration(color: tea, borderRadius: BorderRadius.circular(8)),
                    child: Text('×$n', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ],
              ]),
              if ('${p['desc'] ?? ''}'.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text('${p['desc']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: hint)),
                ),
              const SizedBox(height: 4),
              Text(
                off ? 'نفد حالياً' : '${optList(p['sizes']).isNotEmpty ? 'من ' : ''}${money(basePrice(p))}',
                style: off ? TextStyle(fontSize: 13, color: hint) : TextStyle(fontWeight: FontWeight.w700, color: accentOf(context), fontSize: 15),
              ),
            ]),
          ),
          const SizedBox(width: 12),
          Opacity(opacity: off ? 0.5 : 1, child: ItemThumb(product: p, cat: cat, size: 76)),
          if (trailing != null) ...[const SizedBox(width: 10), trailing],
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
              // رأس المنتج: الاسم والسعر، معلومات صغيرة، وصورة كبيرة
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Text('${p['name']}',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, height: 1.2)),
                ),
                const SizedBox(width: 10),
                Text(money(needSize && size.isEmpty ? basePrice(p) : linePrice(p, size, const [])),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 24, color: accentOf(context))),
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
                  const Pill('مطلوب', bg: brandSoft, fg: brandDark),
                ]),
                for (final z in sizes)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    onTap: () => setState(() => size = '${z['name']}'),
                    leading: Icon(size == z['name'] ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                        color: size == z['name'] ? accentOf(context) : hint),
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
                Text('المحل مغلق الآن.', style: TextStyle(color: accentOf(context), fontWeight: FontWeight.w600)),
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
                        child: Text(needSize && size.isEmpty ? 'اختر الحجم أولاً' : 'أضف بـ ${money(unit * qty)}',
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

/// إعلان من المحل: إطار زعفراني وشارة «إعلان»، وصورة اختيارية
class _AdCard extends StatelessWidget {
  final Doc ad;
  final bool compact;
  const _AdCard({required this.ad, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final img = app.postImage(ad);
    final hint = Theme.of(context).hintColor;
    final text = '${ad['text'] ?? ''}';
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: star, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (ad['img'] == true && !compact)
          AspectRatio(
            aspectRatio: 16 / 9,
            child: img != null
                ? Image.memory(img, fit: BoxFit.cover, gaplessPlayback: true)
                : ColoredBox(color: Theme.of(context).colorScheme.surfaceContainerHighest),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(color: star, borderRadius: BorderRadius.circular(8)),
              child: const Text('إعلان', style: TextStyle(color: ink, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
            if (text.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(text,
                  maxLines: compact ? 3 : null,
                  overflow: compact ? TextOverflow.ellipsis : null,
                  style: const TextStyle(fontSize: 14.5, height: 1.5)),
            ],
            const SizedBox(height: 6),
            Text(ago(asInt(ad['at'])), style: TextStyle(color: hint, fontSize: 12)),
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
