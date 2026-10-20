import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../market.dart';
import '../store.dart';
import '../ui.dart';
import 'messages.dart';
import 'post.dart';

IconData marketCatIcon(String? id) => switch (id) {
      'phones' => Icons.smartphone_rounded,
      'electro' => Icons.tv_rounded,
      'home' => Icons.chair_rounded,
      'clothes' => Icons.checkroom_rounded,
      'vehicles' => Icons.pedal_bike_rounded,
      'kids' => Icons.toys_rounded,
      _ => Icons.sell_rounded,
    };

(Color, Color) marketCatColors(String? id) => switch (id) {
      'phones' || 'electro' => (inkSoft, ink),
      'home' => (const Color(0xFFF6EBDD), saffronText),
      'clothes' => (const Color(0xFFFBE4E4), const Color(0xFF8E1F1F)),
      'vehicles' => (teaSoft, teaDark),
      'kids' => (brandSoft, brandDark),
      _ => (saffronSoft, saffronText),
    };

void openListing(BuildContext context, String id) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ListingScreen(listingId: id)));

void openPost(BuildContext context) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PostScreen()));

/// تبويب السوق: بحث، أقسام، ترتيب، وشبكة الإعلانات
class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key});
  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  String q = '', cat = 'all', sort = 'new'; // new | near | cheap

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: ListenableBuilder(
          listenable: Listenable.merge([market, app]),
          builder: (context, _) {
            final query = q.trim();
            final myZone = app.currentZone?['id'];
            final rows = market.listings.where((l) {
              if (cat != 'all' && l['cat'] != cat) return false;
              if (query.isNotEmpty && !'${l['title']} ${l['desc']}'.contains(query)) return false;
              return true;
            }).toList();
            if (sort == 'cheap') rows.sort((a, b) => asInt(a['price']).compareTo(asInt(b['price'])));
            if (sort == 'near') {
              rows.sort((a, b) => (a['zoneId'] == myZone ? 0 : 1).compareTo(b['zoneId'] == myZone ? 0 : 1));
            }
            return CustomScrollView(slivers: [
              SliverToBoxAdapter(
                child: Stack(children: [
                  const Positioned.fill(child: ColoredBox(color: ink)),
                  const Zellige(opacity: 0.1),
                  Padding(
                    padding: EdgeInsets.fromLTRB(20, top + 12, 12, 44),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(
                          child: Text('سوق ${app.config['city'] ?? 'برج الغدير'}',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13)),
                        ),
                        TextButton.icon(
                          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyListingsScreen())),
                          style: TextButton.styleFrom(foregroundColor: Colors.white),
                          icon: const Icon(Icons.inventory_2_outlined, size: 20),
                          label: Text(market.mine.isEmpty ? 'إعلاناتي' : 'إعلاناتي (${market.mine.length})'),
                        ),
                      ]),
                      Text('بِع واشترِ في مدينتك، ونحن نوصل',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontSize: 27, height: 1.2)),
                      const SizedBox(height: 14),
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        child: TextField(
                          onChanged: (v) => setState(() => q = v),
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            hintText: 'ابحث: هاتف، ثلاجة، دراجة…',
                            prefixIcon: const Icon(Icons.search_rounded),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
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
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 96,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      _cat('all', 'الكل', Icons.apps_rounded, inkSoft, ink),
                      for (final c in marketCats)
                        _cat(c.$1, c.$2, marketCatIcon(c.$1), marketCatColors(c.$1).$1, marketCatColors(c.$1).$2),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    children: [
                      for (final o in const [('new', 'الأحدث'), ('near', 'في حيّي أولاً'), ('cheap', 'الأرخص')])
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: 8),
                          child: ChoiceChip(
                            label: Text(o.$2),
                            selected: sort == o.$1,
                            showCheckmark: false,
                            onSelected: (_) => setState(() => sort = o.$1),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (market.banned)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Box(color: brandSoft, child: Text('حسابك موقوف عن النشر في السوق.', style: TextStyle(color: brandDark))),
                  ),
                ),
              if (!market.loaded)
                const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())))
              else if (rows.isEmpty)
                SliverToBoxAdapter(
                  child: EmptyState(
                    icon: Icons.storefront_outlined,
                    title: market.listings.isEmpty ? 'السوق ينتظر أول إعلان' : 'لا توجد نتائج',
                    text: market.listings.isEmpty ? 'كن أول من يبيع في مدينته. النشر مجاني دائماً.' : 'جرّب كلمة أخرى أو قسماً آخر.',
                    action: market.listings.isEmpty
                        ? FilledButton.icon(
                            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                            onPressed: () => openPost(context),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('انشر إعلاناً'))
                        : null,
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
                  sliver: SliverGrid.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, mainAxisExtent: 262),
                    itemCount: rows.length,
                    itemBuilder: (_, i) => ListingCard(l: rows[i]),
                  ),
                ),
            ]);
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: brand,
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          onPressed: () => openPost(context),
          icon: const Icon(Icons.add_rounded),
          label: const Text('انشر إعلاناً مجاناً', style: TextStyle(fontFamily: 'Plex', fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  Widget _cat(String id, String label, IconData icon, Color bg, Color fg) {
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
          width: 72,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            StarBadge(
              size: 54,
              color: on ? brand : (dark ? fg.withValues(alpha: 0.3) : bg),
              child: Icon(icon, size: 24, color: on ? Colors.white : (dark ? Colors.white : fg)),
            ),
            const SizedBox(height: 6),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, fontWeight: on ? FontWeight.w700 : FontWeight.w500, color: on ? accentOf(context) : null)),
          ]),
        ),
      ),
    );
  }
}

/// صورة الإعلان أو أيقونة قسمه على لونه
class ListingPhoto extends StatelessWidget {
  final Doc l;
  final int index;
  final double iconSize;
  const ListingPhoto({super.key, required this.l, this.index = 0, this.iconSize = 44});

  @override
  Widget build(BuildContext context) {
    final img = market.photo(l, index);
    if (img != null) return Image.memory(img, fit: BoxFit.cover, gaplessPlayback: true);
    final (bg, fg) = marketCatColors(l['cat']);
    final dark = isDark(context);
    return ColoredBox(
      color: dark ? fg.withValues(alpha: 0.3) : bg,
      child: Center(
        child: asInt(l['imgN']) > index
            ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: dark ? Colors.white54 : fg))
            : Icon(marketCatIcon(l['cat']), size: iconSize, color: dark ? Colors.white70 : fg),
      ),
    );
  }
}

class ListingCard extends StatelessWidget {
  final Doc l;
  const ListingCard({super.key, required this.l});

  @override
  Widget build(BuildContext context) {
    final hint = Theme.of(context).hintColor;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openListing(context, '${l['id']}'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(height: 132, child: ListingPhoto(l: l)),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(money(asInt(l['price'])),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 17, fontWeight: FontWeight.w800, color: accentOf(context))),
              Text('${l['title']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.35)),
              const SizedBox(height: 4),
              Meta(Icons.place_outlined, '${l['zoneName'] ?? ''}'),
              Meta(Icons.schedule_rounded, ago(asInt(l['at'])), color: hint),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// صفحة الإعلان: الصور، السعر، الوصف، البائع، المراسلة والإبلاغ
class ListingScreen extends StatefulWidget {
  final String listingId;
  const ListingScreen({super.key, required this.listingId});
  @override
  State<ListingScreen> createState() => _ListingScreenState();
}

class _ListingScreenState extends State<ListingScreen> {
  int page = 0;

  Future<void> _report(Doc l) async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text('لماذا تبلّغ عن هذا الإعلان؟', style: Theme.of(c).textTheme.titleMedium?.copyWith(fontSize: 19)),
          ),
          for (final r in reportReasons) ListTile(title: Text(r), onTap: () => Navigator.pop(c, r)),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (reason == null) return;
    final e = await market.report(l, reason);
    app.toast(e.isEmpty ? 'شكراً، وصل بلاغك. سنراجع الإعلان.' : e);
  }

  Future<void> _confirm(String title, String body, Future<void> Function() act) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('تراجع')),
          FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(0, 44)), onPressed: () => Navigator.pop(c, true), child: const Text('نعم')),
        ],
      ),
    );
    if (ok == true) await act();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: market,
      builder: (context, _) {
        final l = market.listing(widget.listingId);
        if (l == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(icon: Icons.visibility_off_outlined, title: 'هذا الإعلان لم يعد متاحاً', text: 'ربما بِيع أو حذفه صاحبه.'),
          );
        }
        final mine = l['uid'] == market.uid;
        final n = asInt(l['imgN']);
        final hint = Theme.of(context).hintColor;
        final top = MediaQuery.of(context).padding.top;
        final surface = Theme.of(context).colorScheme.surface;
        final sellerCount = market.listings.where((x) => x['uid'] == l['uid']).length;
        final dark = isDark(context);
        return Scaffold(
          backgroundColor: surface,
          body: Stack(children: [
            CustomScrollView(slivers: [
              SliverToBoxAdapter(
                child: Stack(children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 320 + top,
                    child: PageView.builder(
                      itemCount: n == 0 ? 1 : n,
                      onPageChanged: (i) => setState(() => page = i),
                      itemBuilder: (_, i) => ListingPhoto(l: l, index: i, iconSize: 96),
                    ),
                  ),
                  if (n > 1)
                    Positioned(
                      top: 290 + top - 36,
                      left: 0,
                      right: 0,
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        for (int i = 0; i < n; i++)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: i == page ? 18 : 6,
                            height: 6,
                            decoration: BoxDecoration(color: i == page ? Colors.white : Colors.white54, borderRadius: BorderRadius.circular(3)),
                          ),
                      ]),
                    ),
                  Container(
                    margin: EdgeInsets.only(top: 292 + top),
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                    decoration: BoxDecoration(color: surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if (l['status'] == 'review')
                        const Padding(
                          padding: EdgeInsets.only(bottom: 10),
                          child: Pill('قيد المراجعة: لا يراه الناس الآن', bg: saffronSoft, fg: saffronText, icon: Icons.hourglass_top_rounded),
                        ),
                      if (l['sold'] == true)
                        const Padding(padding: EdgeInsets.only(bottom: 10), child: OpenPill(text: 'بِيع')),
                      Text(money(asInt(l['price'])),
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 30, color: accentOf(context), height: 1.1)),
                      const SizedBox(height: 4),
                      Text('${l['title']}', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, height: 1.35)),
                      const SizedBox(height: 6),
                      Wrap(spacing: 14, runSpacing: 4, children: [
                        Meta(Icons.place_outlined, '${l['zoneName'] ?? ''}'),
                        Meta(Icons.schedule_rounded, ago(asInt(l['at']))),
                        Meta(marketCatIcon(l['cat']), marketCatLabel(l['cat'])),
                      ]),
                      const SizedBox(height: 12),
                      Pill(l['used'] == false ? 'جديد' : 'مستعمل'),
                      if ('${l['desc'] ?? ''}'.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Text('${l['desc']}', style: TextStyle(height: 1.7, color: dark ? null : const Color(0xFF3A4560))),
                      ],
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: dark ? Colors.white.withValues(alpha: 0.06) : paper, borderRadius: BorderRadius.circular(18)),
                        child: Row(children: [
                          CircleAvatar(
                            radius: 23,
                            backgroundColor: dark ? const Color(0xFF2A3550) : ink,
                            child: Text(firstChar('${l['name'] ?? ''}'),
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontSize: 19)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(mine ? 'أنت البائع' : '${l['name'] ?? 'بائع'}', style: const TextStyle(fontWeight: FontWeight.w700)),
                              Text(sellerCount <= 1 ? 'إعلان واحد في السوق' : 'له $sellerCount إعلانات في السوق',
                                  style: TextStyle(color: hint, fontSize: 13)),
                            ]),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: dark ? tea.withValues(alpha: 0.2) : teaSoft, borderRadius: BorderRadius.circular(16)),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Icon(Icons.verified_user_outlined, color: teaOf(context), size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'تواصل برسائل التطبيق، وقابل البائع في مكان عام، وافحص الغرض قبل أن تدفع. لا تحوّل مالاً مسبقاً لأي أحد.',
                              style: TextStyle(fontSize: 13.5, height: 1.55, color: teaOf(context)),
                            ),
                          ),
                        ]),
                      ),
                      if (!mine) ...[
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: market.reported(l) ? null : () => _report(l),
                          style: TextButton.styleFrom(foregroundColor: hint),
                          icon: const Icon(Icons.flag_outlined, size: 18),
                          label: Text(market.reported(l) ? 'أبلغتَ عن هذا الإعلان' : 'أبلغ عن هذا الإعلان'),
                        ),
                      ],
                    ]),
                  ),
                ]),
              ),
            ]),
            PositionedDirectional(
              top: top + 10,
              start: 14,
              child: FloatBtn(icon: Icons.arrow_back_rounded, tooltip: 'رجوع', onTap: () => Navigator.of(context).maybePop()),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(color: surface, border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant))),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: mine
                        ? Row(children: [
                            if (l['sold'] != true && l['status'] == 'live')
                              Expanded(
                                child: FilledButton.icon(
                                  style: FilledButton.styleFrom(backgroundColor: tea),
                                  onPressed: () => _confirm('بِعت هذا الغرض؟', 'يختفي الإعلان من السوق.', () => market.markSold(l)),
                                  icon: const Icon(Icons.check_rounded),
                                  label: const Text('بِعته'),
                                ),
                              ),
                            if (l['sold'] != true && l['status'] == 'live') const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 54)),
                                onPressed: () => _confirm('حذف الإعلان؟', 'يُحذف الإعلان وصوره نهائياً.', () async {
                                  final nav = Navigator.of(context);
                                  await market.remove(l);
                                  nav.maybePop();
                                }),
                                icon: const Icon(Icons.delete_outline_rounded),
                                label: const Text('حذف'),
                              ),
                            ),
                          ])
                        : FilledButton.icon(
                            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => ListingChatScreen(listingId: '${l['id']}', buyerUid: market.uid ?? ''))),
                            icon: const Icon(Icons.chat_bubble_outline_rounded),
                            label: Text(market.chat(chatIdOf('${l['id']}', market.uid ?? '')) == null ? 'راسل البائع' : 'متابعة المحادثة'),
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

/// إعلاناتي: الحالة، التجديد، البيع، الحذف
class MyListingsScreen extends StatelessWidget {
  const MyListingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إعلاناتي')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openPost(context),
        backgroundColor: brand,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.add_rounded),
        label: const Text('إعلان جديد', style: TextStyle(fontFamily: 'Plex', fontWeight: FontWeight.w700)),
      ),
      body: ListenableBuilder(
        listenable: market,
        builder: (context, _) {
          if (market.mine.isEmpty) {
            return const EmptyState(icon: Icons.inventory_2_outlined, title: 'لم تنشر أي إعلان بعد', text: 'صوّر ما لا تحتاجه وبِعه لجيرانك.');
          }
          final now = nowMs();
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            itemCount: market.mine.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final l = market.mine[i];
              final expired = asInt(l['until']) <= now;
              final Widget st = l['sold'] == true
                  ? const OpenPill(text: 'بِيع')
                  : l['status'] == 'review'
                      ? const Pill('قيد المراجعة', bg: saffronSoft, fg: saffronText)
                      : expired
                          ? const Pill('انتهت مدته')
                          : Pill('منشور، يبقى ${((asInt(l['until']) - now) / 86400000).ceil()} يوماً', bg: inkSoft, fg: ink);
              return Box(
                padding: const EdgeInsets.all(10),
                onTap: () => openListing(context, '${l['id']}'),
                child: Row(children: [
                  ClipRRect(borderRadius: BorderRadius.circular(14), child: SizedBox(width: 72, height: 72, child: ListingPhoto(l: l, iconSize: 30))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${l['title']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(money(asInt(l['price'])), style: TextStyle(color: accentOf(context), fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      st,
                    ]),
                  ),
                  if (expired && l['sold'] != true && l['status'] == 'live')
                    TextButton(onPressed: () => market.renew(l), child: const Text('جدّد')),
                ]),
              );
            },
          );
        },
      ),
    );
  }
}
