import 'package:flutter/material.dart';

import '../store.dart';
import '../ui.dart';
import 'shop.dart';

const _storyMs = 6000; // مدة عرض كل يومية

/// صف دوائر المحلات التي نشرت يوميات اليوم (في أعلى الصفحة الرئيسية)
class StoriesRow extends StatelessWidget {
  const StoriesRow({super.key});

  @override
  Widget build(BuildContext context) {
    final shops = app.storyShops;
    if (shops.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('يوميات المحلات', style: Theme.of(context).textTheme.titleMedium),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 104,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: shops.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) => StoryAvatar(
              shop: shops[i],
              onTap: () => openStories(context, shops, i),
            ),
          ),
        ),
      ]),
    );
  }
}

/// صورة المحل داخل حلقة: ملونة إذا فيها يوميات لم تُشاهد، رمادية إذا شوهدت كلها
class StoryAvatar extends StatelessWidget {
  final Doc shop;
  final VoidCallback onTap;
  final double size;
  final bool showName;
  const StoryAvatar({super.key, required this.shop, required this.onTap, this.size = 66, this.showName = true});

  @override
  Widget build(BuildContext context) {
    final seen = app.storySeen(shop);
    final cover = app.shopCover(shop);
    final c = catOf(shop['cat']);
    return Semantics(
      button: true,
      label: 'يوميات ${shop['name']}',
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: size + 10,
          child: Column(children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: seen ? null : const LinearGradient(colors: [Color(0xFFE8890C), Color(0xFFC2410C), Color(0xFF0F6B4F)]),
                color: seen ? Theme.of(context).dividerColor : null,
              ),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(shape: BoxShape.circle, color: Theme.of(context).scaffoldBackgroundColor),
                child: ClipOval(
                  child: SizedBox(
                    width: size,
                    height: size,
                    child: cover != null
                        ? Image.memory(cover, fit: BoxFit.cover, gaplessPlayback: true)
                        : ColoredBox(color: c.bg, child: Icon(c.icon, color: c.fg, size: size * 0.45)),
                  ),
                ),
              ),
            ),
            if (showName) ...[
              const SizedBox(height: 4),
              Text('${shop['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
            ],
          ]),
        ),
      ),
    );
  }
}

void openStories(BuildContext context, List<Doc> shops, int start) {
  Navigator.of(context).push(PageRouteBuilder(
    opaque: true,
    pageBuilder: (_, __, ___) => StoryViewer(shopIds: [for (final s in shops) '${s['id']}'], start: start),
    transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
  ));
}

/// عارض اليوميات بملء الشاشة: يمر على يوميات كل محل ثم ينتقل للمحل التالي
class StoryViewer extends StatefulWidget {
  final List<String> shopIds;
  final int start;
  const StoryViewer({super.key, required this.shopIds, this.start = 0});
  @override
  State<StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<StoryViewer> with SingleTickerProviderStateMixin {
  late int shopIdx = widget.start;
  int item = 0;
  late final AnimationController timer = AnimationController(vsync: this, duration: const Duration(milliseconds: _storyMs))
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) _next();
    });

  Doc? get shop => shopIdx < widget.shopIds.length ? app.shop(widget.shopIds[shopIdx]) : null;
  List<Doc> get items => shop == null ? const [] : app.postsOf(shop!, 'story');

  @override
  void initState() {
    super.initState();
    // نبدأ من أول يومية لم يشاهدها الزبون
    final l = items;
    final firstUnseen = l.indexWhere((p) => !app.seenPosts.contains(p['id']));
    item = firstUnseen < 0 ? 0 : firstUnseen;
    _show();
  }

  @override
  void dispose() {
    timer.dispose();
    super.dispose();
  }

  void _show() {
    final l = items;
    if (l.isEmpty) {
      _nextShop();
      return;
    }
    if (item >= l.length) item = l.length - 1;
    final id = '${l[item]['id']}';
    // بعد الإطار: تسجيل المشاهدة يُبلغ بقية الشاشات، ولا يجوز ذلك أثناء البناء
    WidgetsBinding.instance.addPostFrameCallback((_) => app.markPostSeen(id));
    timer.forward(from: 0);
  }

  void _next() {
    if (item + 1 < items.length) {
      setState(() => item++);
      _show();
    } else {
      _nextShop();
    }
  }

  void _prev() {
    if (item > 0) {
      setState(() => item--);
    } else if (shopIdx > 0) {
      setState(() {
        shopIdx--;
        item = 0;
      });
    }
    _show();
  }

  void _nextShop() {
    if (shopIdx + 1 < widget.shopIds.length) {
      setState(() {
        shopIdx++;
        item = 0;
      });
      _show();
    } else {
      timer.stop();
      if (mounted) Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) =>
      ListenableBuilder(listenable: app, builder: (context, _) => _build(context)); // تُعاد عند وصول الصورة

  Widget _build(BuildContext context) {
    final s = shop;
    final l = items;
    if (s == null || l.isEmpty) return const Scaffold(backgroundColor: Colors.black);
    final p = l[item.clamp(0, l.length - 1)];
    final img = app.postImage(p);
    final text = '${p['text'] ?? ''}';
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        // الضغط على طرف البداية يرجع، وعلى طرف النهاية يتقدم. الضغط المطوّل يوقف العرض.
        onTapUp: (d) {
          final w = MediaQuery.of(context).size.width;
          final atStart = rtl ? d.globalPosition.dx > w * 0.65 : d.globalPosition.dx < w * 0.35;
          atStart ? _prev() : _next();
        },
        onLongPressStart: (_) => timer.stop(),
        onLongPressEnd: (_) => timer.forward(),
        onVerticalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0) > 300) Navigator.of(context).maybePop();
        },
        child: Stack(fit: StackFit.expand, children: [
          if (img != null)
            Image.memory(img, fit: BoxFit.contain, gaplessPlayback: true)
          else if (p['img'] == true)
            const Center(child: CircularProgressIndicator(color: Colors.white))
          else
            Container(
              decoration: const BoxDecoration(gradient: heroGradient),
              padding: const EdgeInsets.all(28),
              alignment: Alignment.center,
              child: Text(text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700, height: 1.4)),
            ),
          // الأعلى: أشرطة التقدم واسم المحل
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
              child: Column(children: [
                Row(children: [
                  for (int i = 0; i < l.length; i++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: AnimatedBuilder(
                            animation: timer,
                            builder: (_, __) => LinearProgressIndicator(
                              value: i < item ? 1 : (i == item ? timer.value : 0),
                              minHeight: 3,
                              backgroundColor: Colors.white30,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  StoryAvatar(shop: s, onTap: () {}, size: 34, showName: false),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${s['name']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      Text(ago(asInt(p['at'])), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ]),
                  ),
                  IconButton(
                    tooltip: 'إغلاق',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ]),
              ]),
            ),
          ),
          // الأسفل: التعليق وزر المحل
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black87, Colors.transparent]),
              ),
              padding: EdgeInsets.fromLTRB(16, 40, 16, MediaQuery.of(context).padding.bottom + 16),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (img != null && text.isNotEmpty) ...[
                  Text(text, style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.4)),
                  const SizedBox(height: 12),
                ],
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black87),
                  onPressed: () {
                    timer.stop();
                    final nav = Navigator.of(context);
                    nav.pop();
                    nav.push(MaterialPageRoute(builder: (_) => ShopScreen(shopId: '${s['id']}')));
                  },
                  icon: const Icon(Icons.storefront_rounded),
                  label: const Text('اطلب من المحل'),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

/// «إعلانات المحلات» في الصفحة الرئيسية: أحدث الإعلانات من كل المحلات، الضغط يفتح المحل
class AdsRow extends StatelessWidget {
  const AdsRow({super.key});

  @override
  Widget build(BuildContext context) {
    final ads = app.allAds;
    if (ads.isEmpty) return const SizedBox.shrink();
    final hint = Theme.of(context).hintColor;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('إعلانات المحلات', style: Theme.of(context).textTheme.titleMedium),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 206,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: ads.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final s = ads[i].shop, ad = ads[i].ad;
              final img = app.postImage(ad);
              final c = catOf(s['cat']);
              return SizedBox(
                width: 250,
                child: Box(
                  padding: EdgeInsets.zero,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ShopScreen(shopId: '${s['id']}'))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                      child: SizedBox(
                        height: 110,
                        child: img != null
                            ? Image.memory(img, fit: BoxFit.cover, gaplessPlayback: true)
                            : ColoredBox(color: c.bg, child: Icon(Icons.campaign_rounded, color: c.fg, size: 44)),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: Text('${s['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 2, 12, 0),
                      child: Text('${ad['text'] ?? ''}',
                          maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: hint, fontSize: 13, height: 1.35)),
                    ),
                  ]),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}
