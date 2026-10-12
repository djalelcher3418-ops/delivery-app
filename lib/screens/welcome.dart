import 'package:flutter/material.dart';

import '../store.dart';
import '../ui.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});
  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool busy = false;
  String err = '';

  Future<void> _go() async {
    setState(() {
      busy = true;
      err = '';
    });
    try {
      await app.signInAnon();
    } catch (e) {
      setState(() {
        busy = false;
        err = errText(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: heroGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 20),
              Row(children: [
                ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.asset('assets/icon.png', width: 56, height: 56)),
                const SizedBox(width: 12),
                const Text('Delivery', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
              ]),
              const Spacer(),
              Text('محلات مدينتك،\nيصلك ما تطلبه إلى بابك',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700, height: 1.35)),
              const SizedBox(height: 16),
              const Wrap(spacing: 8, runSpacing: 8, children: [
                _Tag(Icons.restaurant_rounded, 'مطاعم ومخابز'),
                _Tag(Icons.local_grocery_store_rounded, 'خضر ومواد غذائية'),
                _Tag(Icons.shopping_bag_rounded, 'اشترِ لي أي شيء'),
                _Tag(Icons.map_rounded, 'تتبّع الموصّل على الخريطة'),
              ]),
              const Spacer(),
              if (err.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                  child: Text(err, style: const TextStyle(color: Color(0xFF8A3414), fontWeight: FontWeight.w600)),
                ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: brandDark),
                onPressed: busy ? null : _go,
                child: busy
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                    : const Text('ابدأ الطلب'),
              ),
              const SizedBox(height: 10),
              const Center(
                child: Text('بدون تسجيل · الدفع نقداً عند الاستلام', style: TextStyle(color: Colors.white70, fontSize: 13)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Tag(this.icon, this.text);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
        ]),
      );
}
