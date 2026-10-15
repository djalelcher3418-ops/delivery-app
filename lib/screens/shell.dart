import 'package:flutter/material.dart';

import '../store.dart';
import '../ui.dart';
import 'any.dart';
import 'cart.dart';
import 'home.dart';
import 'orders.dart';

/// التبويب الحالي — تغيّره الشاشات الأخرى (مثلاً بعد إرسال الطلب)
final ValueNotifier<int> tab = ValueNotifier<int>(0);

class Shell extends StatelessWidget {
  const Shell({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: tab,
      builder: (context, i, _) => ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          final cart = app.cartCount, active = app.activeOrders, unread = app.anyUnread;
          return Scaffold(
            body: IndexedStack(index: i, children: const [HomeScreen(), AnyScreen(), OrdersScreen(), CartScreen()]),
            bottomNavigationBar: BottomBar(
              index: i,
              onTap: (v) => tab.value = v,
              items: [
                const BarItem(Icons.home_outlined, Icons.home_rounded, 'الرئيسية'),
                const BarItem(Icons.shopping_bag_outlined, Icons.shopping_bag_rounded, 'اشترِ لي'),
                BarItem(Icons.receipt_long_outlined, Icons.receipt_long_rounded, 'طلباتي',
                    badge: unread ? '!' : (active > 0 ? '$active' : null)),
                BarItem(Icons.shopping_cart_outlined, Icons.shopping_cart_rounded, 'السلة', badge: cart > 0 ? '$cart' : null),
              ],
            ),
          );
        },
      ),
    );
  }
}

class BarItem {
  final IconData icon, active;
  final String label;
  final String? badge;
  const BarItem(this.icon, this.active, this.label, {this.badge});
}

/// شريط سفلي أبيض مدوّر: الأيقونة المختارة داخل دائرة خضراء مرفوعة
class BottomBar extends StatelessWidget {
  final int index;
  final List<BarItem> items;
  final ValueChanged<int> onTap;
  const BottomBar({super.key, required this.index, required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final hint = Theme.of(context).hintColor;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: dark ? const [] : [BoxShadow(color: const Color(0xFF1E4D3C).withValues(alpha: 0.10), blurRadius: 24, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Row(children: [
            for (int k = 0; k < items.length; k++)
              Expanded(
                child: Semantics(
                  selected: k == index,
                  button: true,
                  label: items[k].label,
                  child: InkResponse(
                    onTap: () => onTap(k),
                    radius: 36,
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                        width: k == index ? 46 : 40,
                        height: k == index ? 46 : 40,
                        transform: Matrix4.translationValues(0, k == index ? -6 : 0, 0),
                        decoration: BoxDecoration(
                          color: k == index ? brand : Colors.transparent,
                          shape: BoxShape.circle,
                          boxShadow: k == index ? [BoxShadow(color: brand.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 5))] : null,
                        ),
                        child: Badge(
                          isLabelVisible: items[k].badge != null,
                          label: Text(items[k].badge ?? ''),
                          child: Icon(k == index ? items[k].active : items[k].icon, color: k == index ? Colors.white : hint, size: 24),
                        ),
                      ),
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 220),
                        style: TextStyle(
                          fontFamily: Theme.of(context).textTheme.bodySmall?.fontFamily,
                          fontSize: 11.5,
                          fontWeight: k == index ? FontWeight.w700 : FontWeight.w500,
                          color: k == index ? brand : hint,
                        ),
                        child: Text(items[k].label, maxLines: 1),
                      ),
                    ]),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
