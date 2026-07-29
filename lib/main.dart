import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/constants.dart';
import 'state/app_state.dart';
import 'screens/buyer/buyer_home_screen.dart';

void main() {
  runApp(const SuanMarketApp());
}

class SuanMarketApp extends StatelessWidget {
  const SuanMarketApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primary = Color(AppColors.primaryValue);
    const accent = Color(AppColors.accentValue);

    return ChangeNotifierProvider(
      create: (_) => AppState()..restoreSession(),
      child: MaterialApp(
        title: 'Suan Mouakhom Market',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(AppColors.backgroundValue),
          colorScheme: ColorScheme.fromSeed(
            seedColor: primary,
            primary: primary,
            secondary: accent,
            surface: Colors.white,
          ),
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            backgroundColor: primary,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          cardTheme: const CardThemeData(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
          ),
          chipTheme: ChipThemeData(
            selectedColor: primary.withValues(alpha: 0.12),
            labelStyle: const TextStyle(fontSize: 13),
            side: BorderSide(color: Colors.grey.shade300),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
        ),
        // App opens directly to the public product storefront — no login
        // wall. Login only triggers when the person tries to buy something
        // or taps the account icon (see BuyerHomeScreen + ensureLoggedIn).
        home: const BuyerHomeScreen(),
      ),
    );
  }
}
