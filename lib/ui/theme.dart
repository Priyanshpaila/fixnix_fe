// lib/ui/theme.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart'; // uses `secure` from your ApiClient file

/// Palette choices shown in Profile (edit as you like)
const kBrandSeeds = <Color>[
  Color(0xFF01A759), // Green (default)
  Color(0xFF0B72E7), // Blue
  Color(0xFFFF6B6B), // Red/Coral
  Color(0xFFFF8F00), // Orange/Amber
  Color(0xFF006D77), // Teal
  Color(0xFF6750A4), // Purple
  Color(0xFF00897B), // Green-Teal
  Color(0xFF607D8B), // Blue Grey
];

const _kThemeSeedKey = 'theme_seed_argb';

ThemeData buildAppTheme(Color seed) {
  final scheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: Brightness.light,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFFF7F8FA),

    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      foregroundColor: scheme.onSurface,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
    ),

    cardTheme: CardThemeData(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.all(0),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
    ),

    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      elevation: 0,
    ),

    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),
  );
}

/// Controls the current seed color (persisted)
class ThemeController extends StateNotifier<Color> {
  ThemeController() : super(kBrandSeeds.first);

  bool _loaded = false;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;
    final argbStr = await secure.read(key: _kThemeSeedKey);
    if (argbStr != null) {
      final v = int.tryParse(argbStr);
      if (v != null) state = Color(v);
    }
    _loaded = true;
  }

  Future<void> setSeed(Color c) async {
    state = c;
    await secure.write(key: _kThemeSeedKey, value: c.value.toString());
  }
}

final themeControllerProvider = StateNotifierProvider<ThemeController, Color>(
  (_) => ThemeController(),
);

/// Use this in `main.dart` to block until the theme seed is restored.
final themeInitProvider = FutureProvider<void>((ref) async {
  await ref.read(themeControllerProvider.notifier).load();
});
