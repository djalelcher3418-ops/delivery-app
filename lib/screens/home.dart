import 'dart:async';

import 'package:flutter/material.dart';

import '../store.dart';
import '../ui.dart';
import 'shell.dart';
import 'shop.dart';
import 'stories.dart';
import 'track.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String q = '';
  String cat = 'all';
  String sort = 'best'; // best | near | rating
  bool openOnly = false;
  final page = PageController(viewportFraction: 0.9);
  int slide = 0;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!page.hasClients) return;
      final n = _slides().length;
      if (n < 2) return;
      final next = (slide + 1) % n;
      page.animateToPage(next, duration: const Duration(milliseconds: 450), curve: Curves.easeOut);
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    page.dispose();
    super.dispose();
  }

  void openShop(String id) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ShopScreen(shopId: id)));

  List<Widget> _slides() {
    final out = <Widget>[];
    final bans = app.banners.where((b) => b['active'] != false && b['data'] != null).toList()
      ..sort((a, b) => asInt(a['pos']).compareTo(asInt(b['pos'])));
    for (final b in bans) {
      final img = app.dataUrl(b['data']);
      if (img == null) continue;
      out.add(_slideBox(
        onTap: () {
          final sid = b['shopId'];
          if (sid != null && app.shop(sid) != null) openShop(sid);
        },
        child: Image.memory(img, fit: BoxFit.cover, gaplessPlayback: true),
      ));
    }
    if (app.anyOn) {
      out.add(_builtSlide(anyGradient, 'اشترِ لي أي شيء', 'من أي محل في المدينة، حتى لو لم يكن في التطبيق', 'اطلب الآن',
          Icons.shopping_bag_rounded, () => tab.value = 1));
    }
    final offers = app.liveCoupons;
    if (offers.isNotEmpty) {
      out.add(_builtSlide(heroGradient, '${offers.length} عروض وخصومات', 'رموز خصم من محلات مدينتك', 'شاهد العروض',
          Icons.local_offer_rounded, () => openShop(offers.first['shopId'])));
    }
    if (out.isEmpty) {
      out.add(_builtSlide(const LinearGradient(colors: [Color(0xFF1D4E89), Color(0xFF3478C6)]), 'كل محلات مدينتك في مكان واحد',
          'اطلب وتابع الموصّل على الخريطة حتى بابك', '', Icons.delivery_dining_rounded, null));
    }
    return out;
  }

  Widget _slideBox({required Widget child, VoidCallback? onTap}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: Material(child: InkWell(onTap: onTap, child: child)),
        ),
      );

  Widget _builtSlide(Gradient g, String title, String sub, String cta, IconData icon, VoidCallback? onTap) => _slideBox(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(gradient: g),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Stack(children: [
            PositionedDirectional(
              end: -16,
              bottom: -20,
              child: Icon(icon, size: 130, color: Colors.white.withValues(alpha: 0.16)),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(sub, style: const TextStyle(color: Colors.white, fontSize: 13)),
              if (cta.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: ink, borderRadius: BorderRadius.circular(30)),
                  child: Text(cta, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              ],
            ]),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final zones = app.activeZones, zone = app.currentZone;
        final used = app.visibleShops.map((s) => s['cat']).toSet();
        final catList = cats.where((c) => used.contains(c.id)).toList();
        final filtered = q.trim().isNotEmpty || cat != 'all';
        final Doc? live = app.orders.cast<Doc?>().firstWhere((o) => activeStatuses.contains(o!['status']), orElse: () => null);
        return CustomScrollView(slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 10, 12, 4),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Row(children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: const BoxDecoration(color: mint, shape: BoxShape.circle),
                        child: const Icon(Icons.location_on_rounded, color: brandDark, size: 20),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('التوصيل إلى', style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12)),
                          if (zones.isEmpty)
                            const Text('لا توجد أحياء بعد', style: TextStyle(fontWeight: FontWeight.w700))
                          else
                            DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: zone?['id'],
                                isDense: true,
                                borderRadius: BorderRadius.circular(16),
                                style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface,
                                    fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15),
                                items: [for (final z in zones) DropdownMenuItem(value: z['id'] as String, child: Text('${z['name']}'))],
                                onChanged: (v) {
                                  if (v != null) app.setZone(v);
                                },
                              ),
                            ),
                        ]),
                      ),
                    ]),
                  ),
                  IconButton(
                    tooltip: 'السلة',
                    onPressed: () => tab.value = 3,
                    icon: Badge(
                      isLabelVisible: app.cartCount > 0,
                      label: Text('${app.cartCount}'),
                      child: const Icon(Icons.shopping_cart_outlined),
                    ),
                  ),
                  IconButton(
                    tooltip: 'الخروج',
                    onPressed: () => _logout(context),
                    icon: Icon(Icons.logout_rounded, color: Theme.of(context).hintColor),
                  ),
                ]),
                const SizedBox(height: 16),
                Text.rich(
                  TextSpan(children: [
                    const TextSpan(text: 'أهلاً'),
                    if (app.name.isNotEmpty) TextSpan(text: '، ${app.name.split(' ').first}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  ]),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w500),
                ),
                Text('ماذا نوصل لك اليوم؟', style: TextStyle(color: Theme.of(context).hintColor, fontSize: 14.5)),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: DecoratedBox(
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(30), boxShadow: softShadow(context)),
                    child: TextField(
                      onChanged: (v) => setState(() => q = v),
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'ابحث عن محل أو أكلة أو منتج',
                        prefixIcon: const Icon(Icons.search_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: const BorderSide(color: brand, width: 1.5)),
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ),
          if (live != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Box(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TrackScreen(orderId: live['id']))),
                  child: Row(children: [
                    const Pulse(),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(app.headOf(live), style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text('${app.orderTitle(live)} · تابع طلبك', style: TextStyle(fontSize: 13, color: Theme.of(context).hintColor)),
                      ]),
                    ),
                    const Icon(Icons.chevron_left_rounded),
                  ]),
                ),
              ),
            ),
          if (!filtered) const SliverToBoxAdapter(child: StoriesRow()),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                children: [
                  _catBtn('all', 'الكل'),
                  for (final c in catList) _catBtn(c.id, c.label),
                  if (app.favs.isNotEmpty) _catBtn('fav', 'المفضلة ♥'),
                ],
              ),
            ),
          ),
          if (!filtered) const SliverToBoxAdapter(child: AdsRow()),
          ..._body(filtered),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ]);
      },
    );
  }

  /// تبويب نصي يتحته خط أخضر عند اختياره (مثل ALL · FAST FOOD في التصميم)
  Widget _catBtn(String id, String label) {
    final on = cat == id;
    final hint = Theme.of(context).hintColor;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => cat = id),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 180),
            style: TextStyle(
              fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
              fontSize: 14.5,
              fontWeight: on ? FontWeight.w800 : FontWeight.w500,
              color: on ? Theme.of(context).colorScheme.onSurface : hint,
            ),
            child: Text(label),
          ),
          const SizedBox(height: 5),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: on ? 22 : 0,
            height: 3,
            decoration: BoxDecoration(color: brand, borderRadius: BorderRadius.circular(2)),
          ),
        ]),
      ),
    );
  }

  List<Widget> _body(bool filtered) {
    if (!app.shopsLoaded) {
      return const [SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())))];
    }
    final query = q.trim();
    final rows = <MapEntry<Doc, List<Doc>>>[];
    // «الأقرب» بلا موقع محفوظ (حذفه الزبون مثلاً) يرجع إلى «الأنسب»
    final effSort = sort == 'near' && app.lat == null ? 'best' : sort;
    final dist = <String, double>{};
    double distOf(Doc s) => dist.putIfAbsent('${s['id']}', () => app.distanceTo(s) ?? 999);
    // ترتيب «بايزي»: المتوسط مسحوب نحو 4 بقدر قلة التقييمات، فلا يتقدم محل بتقييم واحد ولا محل كثير التقييمات الضعيفة
    double score(Doc s) => (asInt(s['ratingSum']) + 5 * 4.0) / (asInt(s['ratingCount']) + 5);
    for (final s in app.visibleShops) {
      if (cat == 'fav' ? !app.favs.contains(s['id']) : (cat != 'all' && s['cat'] != cat)) continue;
      if (openOnly && !app.isOpen(s)) continue;
      var hits = <Doc>[];
      if (query.isNotEmpty && !'${s['name']}'.contains(query)) {
        hits = app.productsOf(s['id']).where((p) => '${p['name']}'.contains(query) || '${p['desc'] ?? ''}'.contains(query)).toList();
        if (hits.isEmpty) continue;
      }
      rows.add(MapEntry(s, hits));
    }
    rows.sort((a, b) {
      final o = (app.isOpen(b.key) ? 1 : 0) - (app.isOpen(a.key) ? 1 : 0);
      if (o != 0) return o;
      if (effSort == 'near') {
        final da = distOf(a.key), db = distOf(b.key);
        if (da != db) return da.compareTo(db);
      }
      if (effSort == 'rating') {
        final ra = score(a.key), rb = score(b.key);
        if (ra != rb) return rb.compareTo(ra);
      }
      final r = (avgRating(b.key) ?? 0).compareTo(avgRating(a.key) ?? 0);
      return r != 0 ? r : '${a.key['name']}'.compareTo('${b.key['name']}');
    });
    final title = query.isNotEmpty
        ? 'نتائج البحث'
        : cat == 'fav'
            ? 'محلاتك المفضلة'
            : cat != 'all'
                ? catOf(cat).label
                : 'كل المحلات';
    final list = <Widget>[
      SliverToBoxAdapter(child: SectionTitle(title, trailing: '${rows.length} محلات')),
      SliverToBoxAdapter(
        child: SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final o in const [('best', 'الأنسب', Icons.auto_awesome_rounded), ('near', 'الأقرب', Icons.near_me_rounded), ('rating', 'الأعلى تقييماً', Icons.star_rounded)])
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: ChoiceChip(
                    avatar: Icon(o.$3, size: 16),
                    label: Text(o.$2),
                    selected: effSort == o.$1,
                    showCheckmark: false,
                    onSelected: (_) {
                      if (o.$1 == 'near' && app.lat == null) {
                        app.toast('أضف موقعك في عنوان التوصيل (صفحة السلة) لنرتب المحلات حسب المسافة.');
                        return;
                      }
                      setState(() => sort = o.$1);
                    },
                  ),
                ),
              FilterChip(
                label: const Text('المفتوح الآن'),
                selected: openOnly,
                onSelected: (v) => setState(() => openOnly = v),
              ),
            ],
          ),
        ),
      ),
      if (rows.isEmpty && openOnly && app.visibleShops.isNotEmpty)
        SliverToBoxAdapter(
          child: EmptyState(
            icon: Icons.nightlight_round,
            title: 'لا توجد محلات مفتوحة الآن',
            text: 'المرشّح «المفتوح الآن» مفعّل. ألغِه لترى كل المحلات وتطلب عند فتحها.',
            action: OutlinedButton(onPressed: () => setState(() => openOnly = false), child: const Text('اعرض كل المحلات')),
          ),
        )
      else if (rows.isEmpty)
        SliverToBoxAdapter(
          child: EmptyState(
            icon: Icons.search_off_rounded,
            title: app.visibleShops.isEmpty ? 'لا توجد محلات بعد' : 'لا توجد نتائج',
            text: 'جرّب كلمة أخرى، أو اطلب من «اشترِ لي أي شيء».',
            action: OutlinedButton.icon(onPressed: () => tab.value = 1, icon: const Icon(Icons.shopping_bag_outlined), label: const Text('اشترِ لي أي شيء')),
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList.separated(
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (_, i) => ShopCard(shop: rows[i].key, hits: rows[i].value, onTap: () => openShop(rows[i].key['id'])),
          ),
        ),
    ];
    if (filtered) return list;

    final slides = _slides();
    final offers = app.liveCoupons;
    // منتجات بصور من محلات مفتوحة؛ المقصوصة الخلفية أولاً، والترتيب يتغير كل يوم
    final day = DateTime.now().difference(DateTime(2026)).inDays;
    final openIds = app.visibleShops.where(app.isOpen).map((s) => s['id']).toSet();
    final picks = app.products
        .where((p) => p['hasImg'] == true && p['available'] == true && openIds.contains(p['shopId']))
        .toList()
      ..sort((a, b) {
        final c = (b['cut'] == true ? 1 : 0) - (a['cut'] == true ? 1 : 0);
        if (c != 0) return c;
        return ('${a['id']}$day'.hashCode & 0xffff).compareTo('${b['id']}$day'.hashCode & 0xffff);
      });
    if (picks.length > 10) picks.removeRange(10, picks.length);
    final top = app.visibleShops.where((s) => asInt(s['ratingCount']) >= 1).toList()
      ..sort((a, b) => (avgRating(b) ?? 0).compareTo(avgRating(a) ?? 0));
    return [
      SliverToBoxAdapter(
        child: Column(children: [
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: PageView(controller: page, onPageChanged: (i) => setState(() => slide = i), children: slides),
          ),
          if (slides.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (int i = 0; i < slides.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == slide ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(color: i == slide ? brand : Theme.of(context).dividerColor, borderRadius: BorderRadius.circular(3)),
                  ),
              ]),
            ),
        ]),
      ),
      if (picks.isNotEmpty) ...[
        const SliverToBoxAdapter(child: SectionTitle('مقترحات لك')),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 262,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              itemCount: picks.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (_, i) => ProductCard(p: picks[i]),
            ),
          ),
        ),
      ],
      if (offers.isNotEmpty) ...[
        const SliverToBoxAdapter(child: SectionTitle('عروض وخصومات')),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 112,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: offers.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => _OfferCard(c: offers[i], onTap: () => openShop(offers[i]['shopId'])),
            ),
          ),
        ),
      ],
      if (top.length >= 2) ...[
        const SliverToBoxAdapter(child: SectionTitle('الأعلى تقييماً')),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 196,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              itemCount: top.length > 8 ? 8 : top.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => ShopCard(shop: top[i], mini: true, onTap: () => openShop(top[i]['id'])),
            ),
          ),
        ),
      ],
      ...list,
    ];
  }

  Future<void> _logout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('الخروج؟'),
        content: const Text('إذا خرجت ستفقد سجل طلباتك على هذا الهاتف، وتبدأ كزبون جديد.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('تراجع')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('خروج')),
        ],
      ),
    );
    if (ok == true) await app.signOut();
  }
}

class _OfferCard extends StatelessWidget {
  final Doc c;
  final VoidCallback onTap;
  const _OfferCard({required this.c, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final s = app.shop(c['shopId']);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 236,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF3A2A12) : const Color(0xFFFFF1DC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: orange),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(app.couponLabel(c), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: orange)),
          Text('عند ${s?['name'] ?? ''}${asInt(c['minOrder']) > 0 ? ' · من ${money(asInt(c['minOrder']))}' : ''}',
              maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
          const Spacer(),
          Row(children: [
            const Text('الرمز: ', style: TextStyle(fontSize: 13)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(6)),
              child: Text('${c['code']}', style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.6)),
            ),
          ]),
        ]),
      ),
    );
  }
}

class Pulse extends StatefulWidget {
  const Pulse({super.key});
  @override
  State<Pulse> createState() => _PulseState();
}

class _PulseState extends State<Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: c,
        builder: (_, __) => Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: brand,
            boxShadow: [BoxShadow(color: brand.withValues(alpha: 0.5 * (1 - c.value)), spreadRadius: 10 * c.value)],
          ),
        ),
      );
}


/// بطاقة منتج بنمط التصميم: صورة كبيرة في دائرة نعناعية تبرز فوق البطاقة
class ProductCard extends StatelessWidget {
  final Doc p;
  const ProductCard({super.key, required this.p});

  @override
  Widget build(BuildContext context) {
    final shop = app.shop(p['shopId']);
    final hint = Theme.of(context).hintColor;
    void open() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ShopScreen(shopId: p['shopId'])));
    return SizedBox(
      width: 172,
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned.fill(
          top: 52,
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(26),
            elevation: 0,
            child: InkWell(
              borderRadius: BorderRadius.circular(26),
              onTap: () => openProductSheet(context, p),
              child: Container(
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(26), boxShadow: softShadow(context)),
                padding: const EdgeInsets.fromLTRB(14, 86, 14, 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${p['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                  InkWell(
                    onTap: open,
                    child: Text('${shop?['name'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: hint)),
                  ),
                  const Spacer(),
                  Row(children: [
                    Expanded(
                      child: Text('${optList(p['sizes']).isNotEmpty ? 'من ' : ''}${money(basePrice(p))}',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: brand)),
                    ),
                    Material(
                      color: ink,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => addProduct(context, p),
                        child: const SizedBox(width: 34, height: 34, child: Icon(Icons.add_rounded, color: Colors.white, size: 20)),
                      ),
                    ),
                  ]),
                ]),
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Center(
            child: IgnorePointer(child: ItemThumb(product: p, cat: '${shop?['cat'] ?? ''}', size: 132)),
          ),
        ),
      ]),
    );
  }
}
