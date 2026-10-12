import 'dart:async';

import 'package:flutter/material.dart';

import '../store.dart';
import '../ui.dart';
import 'shell.dart';
import 'shop.dart';
import 'track.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String q = '';
  String cat = 'all';
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
          borderRadius: BorderRadius.circular(20),
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                  child: Text(cta, style: const TextStyle(color: brandDark, fontWeight: FontWeight.w700, fontSize: 13)),
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
            child: Container(
              decoration: const BoxDecoration(
                gradient: heroGradient,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
              ),
              padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 12, 16, 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.location_on_outlined, color: Colors.white),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('التوصيل إلى', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      if (zones.isEmpty)
                        const Text('لا توجد أحياء بعد', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))
                      else
                        DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: zone?['id'],
                            isDense: true,
                            dropdownColor: brandDark,
                            iconEnabledColor: Colors.white,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                            items: [for (final z in zones) DropdownMenuItem(value: z['id'] as String, child: Text('${z['name']}'))],
                            onChanged: (v) {
                              if (v != null) app.setZone(v);
                            },
                          ),
                        ),
                    ]),
                  ),
                  IconButton(
                    tooltip: 'الخروج',
                    onPressed: () => _logout(context),
                    icon: const Icon(Icons.logout_rounded, color: Colors.white),
                  ),
                ]),
                const SizedBox(height: 14),
                Text(app.name.isNotEmpty ? 'أهلاً ${app.name.split(' ').first}، ماذا نوصل لك اليوم؟' : 'ماذا نوصل لك اليوم؟',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white)),
                const SizedBox(height: 14),
                TextField(
                  onChanged: (v) => setState(() => q = v),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'ابحث عن محل أو أكلة أو منتج',
                    prefixIcon: const Icon(Icons.search_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
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
          SliverToBoxAdapter(
            child: SizedBox(
              height: 106,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
                children: [
                  _catBtn('all', 'الكل', Icons.grid_view_rounded, const Color(0xFFEEF2F0), const Color(0xFF14201B)),
                  for (final c in catList) _catBtn(c.id, c.label, c.icon, c.bg, c.fg),
                  if (app.favs.isNotEmpty) _catBtn('fav', 'المفضلة', Icons.favorite_rounded, const Color(0xFFFFE4DA), const Color(0xFFC2410C)),
                ],
              ),
            ),
          ),
          ..._body(filtered),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ]);
      },
    );
  }

  Widget _catBtn(String id, String label, IconData icon, Color bg, Color fg) {
    final on = cat == id;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => setState(() => cat = id),
        child: SizedBox(
          width: 72,
          child: Column(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: on ? brand : (dark ? fg.withValues(alpha: 0.25) : bg),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: on ? Colors.white : (dark ? Colors.white : fg), size: 28),
            ),
            const SizedBox(height: 5),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, fontWeight: on ? FontWeight.w700 : FontWeight.w500, color: on ? brand : null)),
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
    for (final s in app.visibleShops) {
      if (cat == 'fav' ? !app.favs.contains(s['id']) : (cat != 'all' && s['cat'] != cat)) continue;
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
      if (rows.isEmpty)
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
