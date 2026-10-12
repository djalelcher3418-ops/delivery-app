import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/shell.dart';
import 'screens/welcome.dart';
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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: firebaseOptions);
  app.onToast = (m) {
    final s = messengerKey.currentState;
    if (s == null) return;
    s.hideCurrentSnackBar();
    s.showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating));
  };
  await app.init();
  runApp(const DeliveryApp());
}

ThemeData buildTheme(Brightness b) {
  final dark = b == Brightness.dark;
  final scheme = ColorScheme.fromSeed(seedColor: brand, brightness: b).copyWith(
    primary: dark ? const Color(0xFF3DBB8C) : brand,
    secondary: orange,
    surface: dark ? const Color(0xFF17201C) : Colors.white,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: b);
  final text = GoogleFonts.getTextTheme('IBM Plex Sans Arabic', base.textTheme);
  return base.copyWith(
    scaffoldBackgroundColor: dark ? const Color(0xFF0E1512) : const Color(0xFFF4F6F5),
    textTheme: text.copyWith(
      headlineSmall: GoogleFonts.getFont('Readex Pro', textStyle: text.headlineSmall, fontWeight: FontWeight.w600),
      titleLarge: GoogleFonts.getFont('Readex Pro', textStyle: text.titleLarge, fontWeight: FontWeight.w600),
      titleMedium: GoogleFonts.getFont('Readex Pro', textStyle: text.titleMedium, fontWeight: FontWeight.w600),
    ),
    cardTheme: base.cardTheme.copyWith(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: scheme.outlineVariant)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: scheme.outlineVariant)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
