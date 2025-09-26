import 'package:flutter/material.dart';
import '../ui/tokens.dart';

class StatusChip extends StatelessWidget {
  final String status;
  const StatusChip(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final s = status.toLowerCase();
    Color bg = Fx.statusNew;
    if (s.contains('progress')) bg = Fx.statusInProgress;
    if (s.contains('resolved') || s.contains('closed')) bg = Fx.statusResolved;
    if (s.contains('waiting')) bg = Fx.statusWaiting;

    return Chip(
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
      labelPadding: const EdgeInsets.symmetric(horizontal: 6),
      labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      backgroundColor: bg,
      label: Text(status),
    );
  }
}

class PriorityChip extends StatelessWidget {
  final String priority;
  const PriorityChip(this.priority, {super.key});

  @override
  Widget build(BuildContext context) {
    final p = priority.toUpperCase();
    Color bg = Fx.p3;
    if (p == 'P0') bg = Fx.p0;
    if (p == 'P1') bg = Fx.p1;
    if (p == 'P2') bg = Fx.p2;

    return Chip(
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
      labelPadding: const EdgeInsets.symmetric(horizontal: 6),
      labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      backgroundColor: bg,
      label: Text(p),
    );
  }
}
