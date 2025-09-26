import 'package:flutter/material.dart';

/// App design tokens (single source of truth)
class Fx {
  // Spacing
  static const s = 8.0;
  static const m = 12.0;
  static const l = 16.0;
  static const xl = 24.0;

  // Radius
  static const rSm = 10.0;
  static const rMd = 16.0;
  static const rLg = 24.0;

  // Shadow
  static List<BoxShadow> cardShadow(Color c) => [
        BoxShadow(
          color: c.withOpacity(0.06),
          blurRadius: 18,
          spreadRadius: 0,
          offset: const Offset(0, 8),
        ),
      ];

  // Status colors
  static const statusNew = Color(0xFF1171EE);
  static const statusInProgress = Color(0xFFFFA000);
  static const statusResolved = Color(0xFF2DBE60);
  static const statusWaiting = Color(0xFF9C27B0);

  // Priority colors
  static const p0 = Color(0xFFB00020);
  static const p1 = Color(0xFFE53935);
  static const p2 = Color(0xFFF57C00);
  static const p3 = Color(0xFF388E3C);
}
