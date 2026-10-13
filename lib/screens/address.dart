import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../store.dart';
import '../ui.dart';

/// عنوان التوصيل — يُحفظ في الهاتف ويُستعمل في كل الطلبات
class AddressForm extends StatefulWidget {
  const AddressForm({super.key});
  @override
  State<AddressForm> createState() => _AddressFormState();
}

class _AddressFormState extends State<AddressForm> {
  late final TextEditingController name = TextEditingController(text: app.name);
  late final TextEditingController addr = TextEditingController(text: app.addr);
  late final TextEditingController phone = TextEditingController(text: app.phone);
  bool locating = false;

  @override
  void dispose() {
    name.dispose();
    addr.dispose();
    phone.dispose();
    super.dispose();
  }

  Future<void> _locate() async {
    setState(() => locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        app.toast('شغّل GPS في الهاتف ثم أعد المحاولة.');
      } else {
        var perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
          app.toast('رفضت إذن الموقع. اسمح به من إعدادات الهاتف.');
        } else {
          final pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 20)),
          );
          app.lat = double.parse(pos.latitude.toStringAsFixed(6));
          app.lng = double.parse(pos.longitude.toStringAsFixed(6));
          app.save();
        }
      }
    } catch (_) {
      app.toast('تعذّر تحديد الموقع. شغّل GPS ثم أعد المحاولة.');
    }
    if (mounted) setState(() => locating = false);
  }

  void _use(Map<String, dynamic> p) {
    app.usePlace(p);
    addr.text = app.addr;
    setState(() {});
  }

  Future<void> _savePlace() async {
    final label = TextEditingController();
    String err = '';
    await showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setD) => AlertDialog(
          title: const Text('احفظ هذا العنوان'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Wrap(spacing: 8, children: [
              for (final s in ['البيت', 'العمل', 'بيت العائلة'])
                ActionChip(label: Text(s), onPressed: () => setD(() => label.text = s)),
            ]),
            const SizedBox(height: 8),
            TextField(
              controller: label,
              autofocus: true,
              decoration: InputDecoration(labelText: 'اسم العنوان', errorText: err.isEmpty ? null : err),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('إلغاء')),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: () {
                final e = app.savePlace(label.text);
                if (e.isNotEmpty) {
                  setD(() => err = e);
                } else {
                  Navigator.pop(c);
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    label.dispose();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final zones = app.activeZones, zone = app.currentZone;
    final hint = Theme.of(context).hintColor;
    final current = app.places.where(app.isPlace).firstOrNull;
    return Box(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('عنوان التوصيل', style: Theme.of(context).textTheme.titleMedium),
        if (app.places.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 4, children: [
            for (final p in app.places)
              InputChip(
                avatar: Icon(p['label'] == 'العمل' ? Icons.work_rounded : Icons.home_rounded, size: 18),
                label: Text('${p['label']}'),
                selected: app.isPlace(p),
                showCheckmark: false,
                onPressed: () => _use(p),
                onDeleted: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: Text('حذف «${p['label']}»؟'),
                      content: const Text('يُحذف من العناوين المحفوظة فقط.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('تراجع')),
                        TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('حذف')),
                      ],
                    ),
                  );
                  if (ok == true) {
                    app.deletePlace(p);
                    if (mounted) setState(() {});
                  }
                },
                deleteButtonTooltipMessage: 'حذف',
              ),
          ]),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: name,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: 'اسمك', hintText: 'مثال: محمد'),
          onChanged: (v) {
            app.name = v;
            app.save();
          },
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: zone?['id'],
          decoration: const InputDecoration(labelText: 'الحي'),
          items: [for (final z in zones) DropdownMenuItem(value: z['id'] as String, child: Text('${z['name']} · ${money(asInt(z['fee']))}'))],
          onChanged: (v) {
            if (v != null) app.setZone(v);
          },
        ),
        const SizedBox(height: 10),
        TextField(
          controller: addr,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: 'وصف العنوان (أقرب معلم، العمارة، الطابق)', hintText: 'مثال: قرب المسجد، العمارة الثانية'),
          onChanged: (v) {
            app.addr = v;
            app.save();
          },
        ),
        const SizedBox(height: 10),
        if (app.lat != null)
          Row(children: [
            const Icon(Icons.check_circle_rounded, color: brand, size: 20),
            const SizedBox(width: 6),
            const Expanded(child: Text('أُضيف موقعك على الخريطة', style: TextStyle(color: brand, fontWeight: FontWeight.w600))),
            TextButton(
              onPressed: () => setState(() {
                app.lat = null;
                app.lng = null;
                app.save();
              }),
              child: const Text('إزالة'),
            ),
          ])
        else
          OutlinedButton.icon(
            onPressed: locating ? null : _locate,
            icon: locating
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.my_location_rounded),
            label: Text(locating ? 'جارٍ تحديد موقعك…' : 'أضف موقعي الحالي ليصل الموصّل بسهولة'),
          ),
        if (current == null && app.addr.trim().isNotEmpty && app.zoneId.isNotEmpty)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: _savePlace,
              icon: const Icon(Icons.bookmark_add_rounded),
              label: const Text('احفظ هذا العنوان لطلباتك القادمة'),
            ),
          )
        else if (current != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('هذا عنوانك المحفوظ «${current['label']}»', style: TextStyle(color: hint, fontSize: 12)),
          ),
        const SizedBox(height: 10),
        TextField(
          controller: phone,
          keyboardType: TextInputType.phone,
          textDirection: TextDirection.ltr,
          decoration: const InputDecoration(labelText: 'رقم هاتفك', hintText: '05XX XX XX XX'),
          onChanged: (v) {
            app.phone = v;
            app.save();
          },
        ),
      ]),
    );
  }
}
