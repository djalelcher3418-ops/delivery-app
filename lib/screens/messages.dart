import 'package:flutter/material.dart';

import '../market.dart';
import '../store.dart';
import '../ui.dart';
import 'market.dart';

/// تبويب الرسائل: محادثات السوق (مع البائعين ومع المشترين)
class ChatsScreen extends StatelessWidget {
  const ChatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الرسائل')),
      body: ListenableBuilder(
        listenable: market,
        builder: (context, _) {
          if (!market.chatsLoaded) return const Center(child: CircularProgressIndicator());
          if (market.chats.isEmpty) {
            return const EmptyState(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'لا توجد رسائل بعد',
              text: 'راسل بائعاً من صفحة إعلانه في السوق، أو انشر إعلاناً وانتظر المشترين.',
            );
          }
          final hint = Theme.of(context).hintColor;
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            itemCount: market.chats.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final c = market.chats[i];
              final unread = market.unread(c);
              final selling = c['sellerUid'] == market.uid;
              final l = market.listing('${c['listingId']}');
              return Box(
                padding: const EdgeInsets.all(10),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ListingChatScreen(listingId: '${c['listingId']}', buyerUid: '${c['buyerUid']}'))),
                child: Row(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      width: 60,
                      height: 60,
                      child: l != null
                          ? ListingPhoto(l: l, iconSize: 26)
                          : ColoredBox(color: inkSoft, child: Icon(Icons.sell_outlined, color: hint)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(
                          child: Text(market.otherName(c),
                              maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: unread ? FontWeight.w800 : FontWeight.w700)),
                        ),
                        Text(ago(asInt(c['lastAt'])), style: TextStyle(color: hint, fontSize: 12)),
                      ]),
                      Text('${selling ? 'يريد شراء' : 'تشتري'}: ${c['title'] ?? ''}',
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: hint, fontSize: 12.5)),
                      Row(children: [
                        Expanded(
                          child: Text('${c['lastBy'] == market.uid ? 'أنت: ' : ''}${c['lastText'] ?? ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 14, fontWeight: unread ? FontWeight.w700 : FontWeight.w400)),
                        ),
                        if (unread)
                          Container(width: 10, height: 10, decoration: const BoxDecoration(color: brand, shape: BoxShape.circle)),
                      ]),
                    ]),
                  ),
                ]),
              );
            },
          );
        },
      ),
    );
  }
}

/// محادثة حول إعلان بين المشتري والبائع
class ListingChatScreen extends StatefulWidget {
  final String listingId, buyerUid;
  const ListingChatScreen({super.key, required this.listingId, required this.buyerUid});
  @override
  State<ListingChatScreen> createState() => _ListingChatScreenState();
}

class _ListingChatScreenState extends State<ListingChatScreen> {
  final input = TextEditingController();
  final scroll = ScrollController();
  Stream<List<Doc>>? stream;
  String get id => chatIdOf(widget.listingId, widget.buyerUid);

  static const quickBuyer = ['هل ما زال متوفراً؟', 'آخر سعر؟', 'أين يمكن أن نلتقي؟'];
  static const quickSeller = ['نعم، ما زال متوفراً', 'السعر نهائي', 'متى يناسبك؟'];

  @override
  void initState() {
    super.initState();
    market.openChat = id;
  }

  @override
  void dispose() {
    market.markRead(id);
    if (market.openChat == id) market.openChat = null;
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  Future<void> _send(String t) async {
    if (t.trim().isEmpty) return;
    final c = market.chat(id);
    final l = market.listing(widget.listingId) ??
        (c == null ? null : {'id': widget.listingId, 'title': c['title'], 'price': c['price'], 'uid': c['sellerUid']});
    if (l == null) {
      app.toast('هذا الإعلان لم يعد متاحاً.');
      return;
    }
    input.clear();
    await market.send(l, widget.buyerUid, t);
  }

  void _toEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) scroll.jumpTo(scroll.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: market,
      builder: (context, _) {
        final c = market.chat(id);
        final l = market.listing(widget.listingId);
        // الرسائل تُقرأ بعد أن توجد المحادثة (قبل أول رسالة لا شيء لنقرأه)
        if (c != null) stream ??= market.messages(id);
        final selling = (c?['sellerUid'] ?? l?['uid']) == market.uid;
        final hint = Theme.of(context).hintColor;
        final title = '${l?['title'] ?? c?['title'] ?? ''}';
        final price = asInt(l?['price'] ?? c?['price']);
        final quick = selling ? quickSeller : quickBuyer;
        return Scaffold(
          appBar: AppBar(
            title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c != null ? market.otherName(c) : '${l?['name'] ?? 'البائع'}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: hint)),
            ]),
          ),
          body: Column(children: [
            if (l != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Box(
                  padding: const EdgeInsets.all(8),
                  onTap: () => openListing(context, widget.listingId),
                  child: Row(children: [
                    ClipRRect(borderRadius: BorderRadius.circular(12), child: SizedBox(width: 48, height: 48, child: ListingPhoto(l: l, iconSize: 22))),
                    const SizedBox(width: 10),
                    Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
                    Text(money(price), style: TextStyle(color: accentOf(context), fontWeight: FontWeight.w700)),
                    const SizedBox(width: 4),
                  ]),
                ),
              ),
            Expanded(
              child: stream == null
                  ? EmptyState(
                      icon: Icons.waving_hand_outlined,
                      title: 'ابدأ المحادثة',
                      text: selling ? 'لا رسائل بعد.' : 'اسأل البائع عن الغرض، واتفقا على السعر ومكان اللقاء.',
                    )
                  : StreamBuilder<List<Doc>>(
                      stream: stream,
                      builder: (context, snap) {
                        if (snap.hasError) return Center(child: Text(errText(snap.error!)));
                        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                        final msgs = snap.data!;
                        market.markRead(id);
                        _toEnd();
                        return ListView.builder(
                          controller: scroll,
                          padding: const EdgeInsets.all(16),
                          itemCount: msgs.length,
                          itemBuilder: (context, i) {
                            final m = msgs[i];
                            final mine = m['uid'] == market.uid;
                            return Align(
                              alignment: mine ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
                              child: Container(
                                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                padding: const EdgeInsets.fromLTRB(13, 9, 13, 7),
                                decoration: BoxDecoration(
                                  color: mine ? brand : Theme.of(context).colorScheme.surface,
                                  borderRadius: BorderRadiusDirectional.only(
                                    topStart: const Radius.circular(16),
                                    topEnd: const Radius.circular(16),
                                    bottomStart: Radius.circular(mine ? 4 : 16),
                                    bottomEnd: Radius.circular(mine ? 16 : 4),
                                  ),
                                  boxShadow: mine ? null : softShadow(context),
                                ),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text('${m['text'] ?? ''}', style: TextStyle(color: mine ? Colors.white : null, fontSize: 15)),
                                  const SizedBox(height: 2),
                                  Text(clock(asInt(m['atMs'])), style: TextStyle(fontSize: 11, color: mine ? Colors.white70 : hint)),
                                ]),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: quick.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => ActionChip(label: Text(quick[i]), onPressed: () => _send(quick[i])),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      controller: input,
                      textInputAction: TextInputAction.send,
                      onSubmitted: _send,
                      decoration: const InputDecoration(hintText: 'اكتب رسالة…'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'إرسال',
                    style: IconButton.styleFrom(
                        backgroundColor: brand,
                        foregroundColor: Colors.white,
                        fixedSize: const Size(50, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    onPressed: () => _send(input.text),
                    icon: const Icon(Icons.send_rounded),
                  ),
                ]),
              ),
            ),
          ]),
        );
      },
    );
  }
}
