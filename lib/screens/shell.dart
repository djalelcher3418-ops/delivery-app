import 'package:flutter/material.dart';

import '../store.dart';
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
            bottomNavigationBar: NavigationBar(
              selectedIndex: i,
              onDestinationSelected: (v) => tab.value = v,
              destinations: [
                const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'الرئيسية'),
                const NavigationDestination(
                    icon: Icon(Icons.shopping_bag_outlined), selectedIcon: Icon(Icons.shopping_bag_rounded), label: 'اشترِ لي'),
                NavigationDestination(
                  icon: Badge(
                    isLabelVisible: active > 0 || unread,
                    label: Text(unread ? '!' : '$active'),
                    child: const Icon(Icons.receipt_long_outlined),
                  ),
                  selectedIcon: const Icon(Icons.receipt_long_rounded),
                  label: 'طلباتي',
                ),
                NavigationDestination(
                  icon: Badge(isLabelVisible: cart > 0, label: Text('$cart'), child: const Icon(Icons.shopping_cart_outlined)),
                  selectedIcon: const Icon(Icons.shopping_cart_rounded),
                  label: 'السلة',
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
