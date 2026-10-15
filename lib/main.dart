import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';

import 'notify.dart';
import 'screens/chat.dart';
import 'screens/shell.dart';
import 'screens/stories.dart';
import 'screens/track.dart';
import 'screens/welcome.dart';
import 'status_bar.dart';
import 'store.dart';
import 'ui.dart';

// نفس مشروع Firebase الذي يستعمله الموقع (dilivery-93064)
const firebaseOptions = FirebaseOptions(
  apiKey: 'AIzaSyAnAmGrt_gFF7-Y1ZVoq4I5PEaoaKjXbrg',
  appId: '1:248490849459:web:57c1746b9ce6c363bb6cc6',
  messagingSenderId: '248490849459',
  projectId: 'dilivery-93064',
  authDomain: 'dilivery-93064.firebaseapp.com',
  storageBucket: 'dilivery-93064.firebasestorage.app',
);

final messengerKey = GlobalKey<ScaffoldMessengerState>();
final navKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: firebaseOptions);
  status.watch = app;
  status.batteryRelevant = () => app.activeOrders > 0;
  status.start();
  app.onToast = (m) {
    final s = messengerKey.currentState;
    if (s == null) return;
    s.hideCurrentSnackBar();
    s.showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating));
  };
  notify.onOpen = _openFromNotification;
  await notify.init();
  await app.init();
  runApp(const DeliveryApp());
}

// الضغط على إشعار يفتح متابعة الطلب أو المحادثة مع الموصّل
void _openFromNotification(String payload) {
  final nav = navKey.currentState;
  final i = payload.indexOf(':');
  if (nav == null || i < 0 || app.user == null) return;
  final kind = payload.substring(0, i), id = payload.substring(i + 1);
  nav.popUntil((r) => r.isFirst);
  if (kind == 'story') {
    final s = app.shop(id);
    if (s != null) nav.push(MaterialPageRoute(builder: (_) => StoryViewer(shopIds: [id])));
    return;
  }
  nav.push(MaterialPageRoute(builder: (_) => TrackScreen(orderId: id)));
  if (kind == 'chat') nav.push(MaterialPageRoute(builder: (_) => ChatScreen(orderId: id)));
}

ThemeData buildTheme(Brightness b) {
  final dark = b == Brightness.dark;
  final scheme = ColorScheme.fromSeed(seedColor: brand, brightness: b).copyWith(
    primary: dark ? const Color(0xFF6CC7A5) : brand,
    secondary: orange,
    surface: dark ? const Color(0xFF17201C) : Colors.white,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: b);
  final text = base.textTheme.apply(fontFamily: GoogleFonts.getFont('IBM Plex Sans Arabic').fontFamily);
  return base.copyWith(
    scaffoldBackgroundColor: dark ? const Color(0xFF0E1512) : const Color(0xFFF5FAF7),
    textTheme: text.copyWith(
      headlineSmall: GoogleFonts.getFont('Readex Pro', textStyle: text.headlineSmall, fontWeight: FontWeight.w600),
      titleLarge: GoogleFonts.getFont('Readex Pro', textStyle: text.titleLarge, fontWeight: FontWeight.w600),
      titleMedium: GoogleFonts.getFont('Readex Pro', textStyle: text.titleMedium, fontWeight: FontWeight.w600),
    ),
    cardTheme: base.cardTheme.copyWith(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: scheme.outlineVariant)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: scheme.outlineVariant)),
    ),
    // الأزرار الرئيسية سوداء بشكل كبسولة مثل زر «Get Started» في التصميم
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: dark ? const Color(0xFF6CC7A5) : ink,
        foregroundColor: dark ? const Color(0xFF0E1512) : Colors.white,
        disabledBackgroundColor: dark ? Colors.white12 : const Color(0xFFD5DDD9),
        minimumSize: const Size.fromHeight(54),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: const StadiumBorder(),
      side: BorderSide(color: dark ? Colors.white24 : const Color(0xFFDCE7E2)),
      selectedColor: brand.withValues(alpha: dark ? 0.35 : 0.16),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: const StadiumBorder(),
      ),
    ),
    snackBarTheme: SnackBarThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
  );
}

class DeliveryApp extends StatelessWidget {
  const DeliveryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Delivery',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: messengerKey,
      builder: (context, child) => StatusBars(child: child ?? const SizedBox.shrink()),
      navigatorKey: navKey,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          if (!app.ready) return const Scaffold(body: Center(child: CircularProgressIndicator()));
          return app.user == null ? const WelcomeScreen() : const Shell();
        },
      ),
    );
  }
}
