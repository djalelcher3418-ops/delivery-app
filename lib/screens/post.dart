import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../market.dart';
import '../store.dart';
import '../ui.dart';

/// يصغّر الصورة إلى 900 بكسل ويضغطها حتى لا تتجاوز نحو 110 كيلوبايت
String? _shrink(Uint8List bytes) {
  final src = img.decodeImage(bytes);
  if (src == null) return null;
  final big = src.width > src.height ? src.width : src.height;
  final im = big > 900 ? img.copyResize(src, width: src.width >= src.height ? 900 : null, height: src.height > src.width ? 900 : null) : src;
  List<int> out = const [];
  for (final q in [78, 68, 58, 48, 40]) {
    out = img.encodeJpg(im, quality: q);
    if (out.length <= 110000) break;
  }
  return 'data:image/jpeg;base64,${base64Encode(out)}';
}

/// يصوّر أو يختار صورة ويرجعها data URL خفيفة (أو null إذا ألغى)
Future<String?> pickPhoto(BuildContext context) async {
  final src = await showModalBottomSheet<ImageSource>(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.photo_camera_rounded), title: const Text('صوّر الآن'), onTap: () => Navigator.pop(c, ImageSource.camera)),
        ListTile(
            leading: const Icon(Icons.photo_library_rounded), title: const Text('اختر من الصور'), onTap: () => Navigator.pop(c, ImageSource.gallery)),
      ]),
    ),
  );
  if (src == null) return null;
  final f = await ImagePicker().pickImage(source: src, maxWidth: 1400, maxHeight: 1400, imageQuality: 90);
  if (f == null) return null;
  return compute(_shrink, await f.readAsBytes());
}

class PostScreen extends StatefulWidget {
  const PostScreen({super.key});
  @override
  State<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  final title = TextEditingController(), price = TextEditingController(), desc = TextEditingController();
  late final name = TextEditingController(text: app.name);
  final photos = <String>[];
  String cat = '', zone = '', err = '';
  bool used = true, busy = false, picking = false;

  @override
  void initState() {
    super.initState();
    zone = '${app.currentZone?['id'] ?? ''}';
  }

  @override
  void dispose() {
    title.dispose();
    price.dispose();
    desc.dispose();
    name.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    setState(() => picking = true);
    try {
      final p = await pickPhoto(context);
      if (p != null) photos.add(p);
      if (p == null && mounted) setState(() {});
    } catch (_) {
      app.toast('تعذّر فتح الصور. اسمح للتطبيق باستعمال الكاميرا أو الصور.');
    }
    if (mounted) setState(() => picking = false);
  }

  Future<void> _send() async {
    final t = title.text.trim(), n = name.text.trim();
    final p = parseInt(price.text);
    String e = '';
    if (photos.isEmpty) {
      e = 'أضف صورة واحدة على الأقل. الإعلانات بصور تُباع أسرع.';
    } else if (t.length < 4) {
      e = 'اكتب عنواناً واضحاً للإعلان.';
    } else if (cat.isEmpty) {
      e = 'اختر القسم.';
    } else if (p == null || p <= 0) {
      e = 'اكتب السعر بالدينار.';
    } else if (zone.isEmpty) {
      e = 'اختر الحي.';
    } else if (n.length < 2) {
      e = 'اكتب اسمك ليعرف المشتري من يراسل.';
    }
    if (e.isNotEmpty) {
      setState(() => err = e);
      return;
    }
    setState(() {
      busy = true;
      err = '';
    });
    if (n != app.name) {
      app.name = n;
      app.save();
    }
    final r = await market.post(title: t, desc: desc.text, cat: cat, price: p!, used: used, zoneId: zone, photos: photos);
    if (!mounted) return;
    if (r.err.isNotEmpty) {
      setState(() {
        busy = false;
        err = r.err;
      });
      return;
    }
    app.toast(r.review ? 'وصل إعلانك، ويُنشر بعد المراجعة.' : 'نُشر إعلانك في السوق.');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final hint = Theme.of(context).hintColor;
    final zones = app.activeZones;
    Widget label(String t) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(t, style: const TextStyle(fontWeight: FontWeight.w600)));
    return Scaffold(
      appBar: AppBar(
        title: const Text('إعلان جديد'),
        actions: const [
          Padding(padding: EdgeInsetsDirectional.only(end: 14), child: Center(child: Pill('مجاني دائماً', bg: teaSoft, fg: teaDark))),
        ],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
        label('الصور (حتى $maxPhotos)'),
        SizedBox(
          height: 88,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            if (photos.length < maxPhotos)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 10),
                child: Semantics(
                  button: true,
                  label: 'أضف صورة',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: picking ? null : _add,
                    child: Container(
                      width: 84,
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: accentOf(context), width: 2)),
                      child: picking
                          ? const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)))
                          : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(Icons.add_a_photo_outlined, color: accentOf(context)),
                              const SizedBox(height: 2),
                              Text('أضف صورة', style: TextStyle(fontSize: 12, color: accentOf(context), fontWeight: FontWeight.w600)),
                            ]),
                    ),
                  ),
                ),
              ),
            for (int i = 0; i < photos.length; i++)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 10),
                child: Stack(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.memory(_bytes(photos[i]), width: 84, height: 88, fit: BoxFit.cover, gaplessPlayback: true),
                  ),
                  PositionedDirectional(
                    top: 2,
                    end: 2,
                    child: IconButton(
                      tooltip: 'احذف الصورة',
                      style: IconButton.styleFrom(backgroundColor: Colors.black54, minimumSize: const Size(32, 32), fixedSize: const Size(32, 32)),
                      onPressed: () => setState(() => photos.removeAt(i)),
                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                    ),
                  ),
                ]),
              ),
          ]),
        ),
        const SizedBox(height: 16),
        TextField(controller: title, maxLength: 70, decoration: const InputDecoration(labelText: 'العنوان', hintText: 'مثال: Samsung A54 نظيف مع العلبة')),
        const SizedBox(height: 6),
        label('القسم'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final c in marketCats)
            ChoiceChip(label: Text(c.$2), selected: cat == c.$1, showCheckmark: false, onSelected: (_) => setState(() => cat = c.$1)),
        ]),
        const SizedBox(height: 16),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: TextField(
              controller: price,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'السعر', suffixText: 'دج'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              style: const ButtonStyle(minimumSize: WidgetStatePropertyAll(Size(0, 52))),
              segments: const [ButtonSegment(value: true, label: Text('مستعمل')), ButtonSegment(value: false, label: Text('جديد'))],
              selected: {used},
              onSelectionChanged: (v) => setState(() => used = v.first),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        TextField(
          controller: desc,
          minLines: 3,
          maxLines: 6,
          maxLength: 600,
          decoration: const InputDecoration(labelText: 'الوصف', hintText: 'ما يهم المشتري: الحالة، المقاس، سبب البيع…', alignLabelWithHint: true),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: zones.any((z) => z['id'] == zone) ? zone : null,
          decoration: const InputDecoration(labelText: 'الحي'),
          items: [for (final z in zones) DropdownMenuItem(value: '${z['id']}', child: Text('${z['name']}'))],
          onChanged: (v) => setState(() => zone = v ?? ''),
        ),
        const SizedBox(height: 16),
        TextField(controller: name, maxLength: 30, decoration: const InputDecoration(labelText: 'اسمك كما يراه المشتري')),
        const SizedBox(height: 4),
        Text('يبقى الإعلان $listingDays يوماً ويمكنك تجديده. رقم هاتفك لا يظهر لأحد؛ التواصل برسائل التطبيق.',
            style: TextStyle(color: hint, fontSize: 12.5, height: 1.6)),
        if (err.isNotEmpty) ...[
          const SizedBox(height: 12),
          Box(color: isDark(context) ? brand.withValues(alpha: 0.25) : brandSoft, child: Text(err, style: TextStyle(color: isDark(context) ? Colors.white : brandDark))),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: busy ? null : _send,
          child: busy
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
              : const Text('انشر الإعلان'),
        ),
      ]),
    );
  }

  final Map<String, Uint8List> _cache = {};
  Uint8List _bytes(String d) => _cache.putIfAbsent(d, () => base64Decode(d.substring(d.indexOf(',') + 1)));
}
