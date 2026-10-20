import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../store.dart';
import '../ui.dart';
import 'any.dart';
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
      out.add(_builtSlide(ink, Colors.white, 'اشترِ لي أي شيء', 'من أي محل في المدينة، حتى لو لم يكن في التطبيق', 'اطلب الآن',
          Icons.shopping_bag_rounded, () => openAny(context)));
    }
    final offers = app.liveCoupons;
    if (offers.isNotEmpty) {
      out.add(_builtSlide(star, ink, '${offers.length} عروض وخصومات', 'رموز خصم من محلات مدينتك', 'شاهد العروض', Icons.local_offer_rounded,
          () => openShop(offers.first['shopId'])));
    }
    if (out.isEmpty) {
      out.add(_builtSlide(tea, Colors.white, 'كل محلات مدينتك في مكان واحد', 'اطلب وتابع الموصّل على الخريطة حتى بابك', '',
          Icons.delivery_dining_rounded, null));
    }
    return out;
  }

  Widget _slideBox({required Widget child, VoidCallback? onTap}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Material(child: InkWell(onTap: onTap, child: child)),
        ),
      );

  /// شريحة بلون واحد ونقش زليج خفيف، وزر صغير بلون معاكس
  Widget _builtSlide(Color bg, Color fg, String title, String sub, String cta, IconData icon, VoidCallback? onTap) => _slideBox(
        onTap: onTap,
        child: Container(
          color: bg,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Stack(children: [
            Zellige(opacity: fg == ink ? 0.0 : 0.12),
            PositionedDirectional(
              end: -16,
              bottom: -20,
              child: Icon(icon, size: 130, color: fg.withValues(alpha: 0.16)),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: fg, fontSize: 23)),
              const SizedBox(height: 2),
              Text(sub, style: TextStyle(color: fg, fontSize: 13.5)),
              if (cta.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  decoration: BoxDecoration(color: fg == ink ? ink : brand, borderRadius: BorderRadius.circular(12)),
                  child: Text(cta, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13.5)),
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
        final top = MediaQuery.of(context).padding.top;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: CustomScrollView(slivers: [
            // الرأس بلون الهريسة ونقش الزليج، والورقة تصعد فوقه بزاوية 28
            SliverToBoxAdapter(
              child: Stack(children: [
                const Positioned.fill(child: ColoredBox(color: brand)),
                const Zellige(),
                Padding(
                  padding: EdgeInsets.fromLTRB(20, top + 10, 8, 46),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Icon(Icons.location_on_outlined, color: Colors.white, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('التوصيل إلى', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12)),
                          if (zones.isEmpty)
                            const Text('لا توجد أحياء بعد',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16))
                          else
                            DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: zone?['id'],
                                isDense: true,
                                borderRadius: BorderRadius.circular(16),
                                iconEnabledColor: Colors.white,
                                dropdownColor: Theme.of(context).colorScheme.surface,
                                style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface,
                                    fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16),
                                selectedItemBuilder: (_) => [
                                  for (final z in zones)
                                    Text('${z['name']}',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                                ],
                                items: [for (final z in zones) DropdownMenuItem(value: z['id'] as String, child: Text('${z['name']}'))],
                                onChanged: (v) {
                                  if (v != null) app.setZone(v);
                                },
                              ),
                            ),
                        ]),
                      ),
                      IconButton(
                        tooltip: 'السلة',
                        color: Colors.white,
                        onPressed: () => tab.value = 4,
                        icon: Badge(
                          isLabelVisible: app.cartCount > 0,
                          label: Text('${app.cartCount}'),
                          child: const Icon(Icons.shopping_cart_outlined),
                        ),
                      ),
                      IconButton(
                        tooltip: 'الخروج',
                        color: Colors.white,
                        onPressed: () => _logout(context),
                        icon: const Icon(Icons.logout_rounded),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    if (app.name.isNotEmpty)
                      Text('أهلاً، ${app.name.split(' ').first}',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 15, fontWeight: FontWeight.w600)),
                    Text('ماذا نوصل لك اليوم؟',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontSize: 30, height: 1.2)),
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 12),
                      child: TextField(
                        onChanged: (v) => setState(() => q = v),
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: 'ابحث عن محل أو طبق أو منتج',
                          prefixIcon: const Icon(Icons.search_rounded),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: ink, width: 1.6)),
                        ),
                      ),
                    ),
                  ]),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: -1,
                  height: 26,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                    ),
                  ),
                ),
              ]),
            ),
            if (live != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Box(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TrackScreen(orderId: live['id']))),
                    child: Row(children: [
                      const Pulse(),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(app.headOf(live), style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text('${app.orderTitle(live)}، اضغط لتتابع طلبك',
                              style: TextStyle(fontSize: 13, color: Theme.of(context).hintColor)),
                        ]),
                      ),
                      const Icon(Icons.chevron_left_rounded),
                    ]),
                  ),
                ),
              ),
            // الأقسام: شارات على شكل نجمة الزليج
            SliverToBoxAdapter(
              child: SizedBox(
                height: 98,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  children: [
                    if (app.anyOn) _anyBtn(),
                    _catBtn('all', 'الكل', Icons.apps_rounded, inkSoft, ink),
                    for (final c in catList) _catBtn(c.id, c.label, c.icon, c.bg, c.fg),
                    if (app.favs.isNotEmpty) _catBtn('fav', 'المفضلة', Icons.favorite_rounded, brandSoft, brandDark),
                  ],
                ),
              ),
            ),
            if (!filtered) const SliverToBoxAdapter(child: StoriesRow()),
            if (!filtered) const SliverToBoxAdapter(child: AdsRow()),
            ..._body(filtered),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ]),
        );
      },
    );
  }

  /// «اشترِ لي أي شيء» أول الشارات، بلون الزعفران
  Widget _anyBtn() => Semantics(
        button: true,
        label: 'اشترِ لي أي شيء',
        excludeSemantics: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => openAny(context),
          child: const SizedBox(
            width: 74,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              StarBadge(color: star, child: Icon(Icons.shopping_bag_rounded, size: 26, color: ink)),
              SizedBox(height: 6),
              Text('اشترِ لي', maxLines: 1, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      );

  /// شارة القسم: المختارة بلون الهريسة وأيقونتها بيضاء
  Widget _catBtn(String id, String label, IconData icon, Color bg, Color fg) {
    final on = cat == id;
    final dark = isDark(context);
    return Semantics(
      button: true,
      selected: on,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => cat = on && id != 'all' ? 'all' : id),
        child: SizedBox(
          width: 74,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            AnimatedScale(
              scale: on ? 1.06 : 1,
              duration: const Duration(milliseconds: 180),
              child: StarBadge(
                color: on ? brand : (dark ? fg.withValues(alpha: 0.3) : bg),
                child: Icon(icon, size: 26, color: on ? Colors.white : (dark ? Colors.white : fg)),
              ),
            ),
            const SizedBox(height: 6),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                  color: on ? accentOf(context) : Theme.of(context).colorScheme.onSurface,
                )),
          ]),
        ),
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
              for (final o in const [
                ('best', 'الأنسب', Icons.auto_awesome_rounded),
                ('near', 'الأقرب', Icons.near_me_rounded),
                ('rating', 'الأعلى تقييماً', Icons.star_rounded)
              ])
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: ChoiceChip(
                    avatar:
                        Icon(o.$3, size: 16, color: effSort == o.$1 ? (isDark(context) ? ink : Colors.white) : Theme.of(context).hintColor),
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
            action: OutlinedButton.icon(
                onPressed: () => openAny(context), icon: const Icon(Icons.shopping_bag_outlined), label: const Text('اشترِ لي أي شيء')),
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList.separated(
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
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
    final picks = app.products.where((p) => p['hasImg'] == true && p['available'] == true && openIds.contains(p['shopId'])).toList()
      ..sort((a, b) {
        final c = (b['cut'] == true ? 1 : 0) - (a['cut'] == true ? 1 : 0);
        if (c != 0) return c;
        return ('${a['id']}$day'.hashCode & 0xffff).compareTo('${b['id']}$day'.hashCode & 0xffff);
      });
    if (picks.length > 10) picks.removeRange(10, picks.length);
    final best = app.visibleShops.where((s) => asInt(s['ratingCount']) >= 1).toList()
      ..sort((a, b) => (avgRating(b) ?? 0).compareTo(avgRating(a) ?? 0));
    return [
      SliverToBoxAdapter(
        child: Column(children: [
          const SizedBox(height: 18),
          SizedBox(
            height: 172,
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
                    decoration:
                        BoxDecoration(color: i == slide ? brand : Theme.of(context).dividerColor, borderRadius: BorderRadius.circular(3)),
                  ),
              ]),
            ),
        ]),
      ),
      if (picks.isNotEmpty) ...[
        const SliverToBoxAdapter(child: SectionTitle('مقترحات لك')),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 244,
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
      if (best.length >= 2) ...[
        const SliverToBoxAdapter(child: SectionTitle('الأعلى تقييماً')),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 200,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              itemCount: best.length > 8 ? 8 : best.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => ShopCard(shop: best[i], mini: true, onTap: () => openShop(best[i]['id'])),
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
    final dark = isDark(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 236,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: dark ? star.withValues(alpha: 0.18) : saffronSoft,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: star, width: 1.5),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(app.couponLabel(c), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 18, fontWeight: FontWeight.w800)),
          Text('عند ${s?['name'] ?? ''}${asInt(c['minOrder']) > 0 ? '، من ${money(asInt(c['minOrder']))}' : ''}',
              maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
          const Spacer(),
          Row(children: [
            const Text('الرمز: ', style: TextStyle(fontSize: 13)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: star, borderRadius: BorderRadius.circular(8)),
              child: Text('${c['code']}', style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.6, color: ink)),
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

/// بطاقة منتج: صورة مربعة على لون القسم، الاسم والمحل، والسعر مع زر إضافة بلون الهريسة
class ProductCard extends StatelessWidget {
  final Doc p;
  const ProductCard({super.key, required this.p});

  @override
  Widget build(BuildContext context) {
    final shop = app.shop(p['shopId']);
    final hint = Theme.of(context).hintColor;
    void open() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ShopScreen(shopId: p['shopId'])));
    return SizedBox(
      width: 160,
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => openProductSheet(context, p),
          child: Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), boxShadow: softShadow(context)),
            padding: const EdgeInsets.all(8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ItemThumb(product: p, cat: '${shop?['cat'] ?? ''}', size: 144),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text('${p['name']}',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
              InkWell(
                onTap: open,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text('${shop?['name'] ?? ''}',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: hint)),
                ),
              ),
              const Spacer(),
              Row(children: [
                const SizedBox(width: 4),
                Expanded(
                  child: Text('${optList(p['sizes']).isNotEmpty ? 'من ' : ''}${money(basePrice(p))}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: accentOf(context))),
                ),
                IconButton(
                  tooltip: 'أضف ${p['name']}',
                  onPressed: () => addProduct(context, p),
                  style: IconButton.styleFrom(
                    backgroundColor: brand,
                    foregroundColor: Colors.white,
                    fixedSize: const Size(40, 40),
                    minimumSize: const Size(40, 40),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 22),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}
