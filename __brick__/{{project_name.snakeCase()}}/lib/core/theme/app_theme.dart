import 'package:flex_seed_scheme/flex_seed_scheme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  static const Color _primary = Color(0xFF401596);
  static const Color _secondary = Color(0xFF625B71);
  static const Color _tertiary = Color(0xFF7D5260);

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = SeedColorScheme.fromSeeds(
      brightness: brightness,
      primaryKey: _primary,
      secondaryKey: _secondary,
      tertiaryKey: _tertiary,
      tones: FlexTones.vivid(brightness),
    );
    return ThemeData(colorScheme: scheme, pageTransitionsTheme: _pageTransitionsTheme);
  }

  static const PageTransitionsTheme _pageTransitionsTheme = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    },
  );
}

// Component sub-themes are added as private helpers and slotted into the
// ThemeData below. Reference `scheme.*` colours so light and dark inherit
// the same overrides correctly. Example:
//
//   return ThemeData(
//     colorScheme: scheme,
//     filledButtonTheme: _filledButtonTheme(scheme),
//   );
//
//   static FilledButtonThemeData _filledButtonTheme(ColorScheme scheme) =>
//       FilledButtonThemeData(
//         style: FilledButton.styleFrom(
//           minimumSize: const Size(0, 48),
//           padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
//         ),
//       );
