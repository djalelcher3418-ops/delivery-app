import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

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
  final surface = dark ? const Color(0xFF1A202B) : Colors.white;
  final onSurface = dark ? const Color(0xFFEDEFF3) : ink;
  final scheme = ColorScheme.fromSeed(seedColor: brand, brightness: b).copyWith(
    primary: dark ? const Color(0xFFF08A5D) : brand,
    onPrimary: dark ? const Color(0xFF10141C) : Colors.white,
    secondary: tea,
    surface: surface,
    onSurface: onSurface,
    outlineVariant: dark ? Colors.white24 : hairline,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: b, fontFamily: 'Plex');
  // النصوص بخط IBM Plex Sans Arabic، والعناوين بخط Baloo Bhaijaan 2 (كلاهما مضمّن في assets/fonts)
  final text = base.textTheme.apply(fontFamily: 'Plex', bodyColor: onSurface, displayColor: onSurface);
  TextStyle head(TextStyle? t, FontWeight w) => (t ?? const TextStyle()).copyWith(fontFamily: 'Baloo', fontWeight: w, height: 1.25);
  final shape14 = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
  return base.copyWith(
    scaffoldBackgroundColor: dark ? const Color(0xFF10141C) : paper,
    hintColor: dark ? const Color(0xFFA3ABBA) : muted,
    dividerColor: dark ? Colors.white12 : const Color(0xFFEEF0F4),
    textTheme: text.copyWith(
      headlineMedium: head(text.headlineMedium, FontWeight.w800),
      headlineSmall: head(text.headlineSmall, FontWeight.w800),
      titleLarge: head(text.titleLarge, FontWeight.w800),
      titleMedium: head(text.titleMedium, FontWeight.w700),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? const Color(0xFF10141C) : paper,
      foregroundColor: onSurface,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: head(text.titleLarge, FontWeight.w700).copyWith(color: onSurface, fontSize: 21),
    ),
    cardTheme: base.cardTheme.copyWith(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: scheme.outlineVariant)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: scheme.outlineVariant)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: scheme.primary, width: 1.6)),
    ),
    // الزر الرئيسي بلون الهريسة في الوضعين (النص الأبيض عليه مقروء)
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: brand,
        foregroundColor: Colors.white,
        disabledBackgroundColor: dark ? Colors.white12 : const Color(0xFFE3E7ED),
        disabledForegroundColor: dark ? Colors.white38 : muted,
        minimumSize: const Size.fromHeight(54),
        shape: shape14,
        textStyle: const TextStyle(fontFamily: 'Plex', fontWeight: FontWeight.w700, fontSize: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        foregroundColor: onSurface,
        textStyle: const TextStyle(fontFamily: 'Plex', fontWeight: FontWeight.w600, fontSize: 15),
        side: BorderSide(color: scheme.outlineVariant),
        shape: shape14,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: scheme.primary,
        shape: shape14,
        textStyle: const TextStyle(fontFamily: 'Plex', fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(minimumSize: const Size(44, 44))),
    // الشرائح: مستطيلات بزوايا 12، والمختارة نيلية
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: WidgetStateBorderSide.resolveWith(
          (s) => s.contains(WidgetState.selected) ? BorderSide.none : BorderSide(color: scheme.outlineVariant)),
      color: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? (dark ? const Color(0xFFEDEFF3) : ink) : surface),
      labelStyle: TextStyle(
        fontFamily: 'Plex',
        fontWeight: FontWeight.w600,
        color: WidgetStateColor.resolveWith(
            (s) => s.contains(WidgetState.selected) ? (dark ? const Color(0xFF10141C) : Colors.white) : onSurface),
      ),
      checkmarkColor: dark ? const Color(0xFF10141C) : Colors.white,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: dark ? const Color(0xFFEDEFF3) : ink,
        selectedForegroundColor: dark ? ink : Colors.white,
        foregroundColor: onSurface,
        side: BorderSide(color: scheme.outlineVariant),
        shape: shape14,
        textStyle: const TextStyle(fontFamily: 'Plex', fontWeight: FontWeight.w600, fontSize: 14.5),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    dialogTheme: base.dialogTheme.copyWith(
      backgroundColor: surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    badgeTheme: const BadgeThemeData(backgroundColor: tea, textColor: Colors.white),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: dark ? const Color(0xFFEDEFF3) : ink,
      contentTextStyle: TextStyle(color: dark ? ink : Colors.white, fontFamily: 'Plex'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
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
