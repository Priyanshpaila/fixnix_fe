// ignore_for_file: unnecessary_null_comparison, deprecated_member_use

import 'package:flutter/material.dart';
import '../ui/tokens.dart';
import '../features/tickets/tickets_repository.dart';
import 'chips.dart';

/// Modern, responsive ticket card
/// - Compact, single-row layout on small screens
/// - Roomy layout with meta on larger screens
/// - Clean hover/focus states and accessible semantics
class TicketCard extends StatelessWidget {
  final Ticket t;
  final VoidCallback? onTap;

  const TicketCard({super.key, required this.t, this.onTap});

  // ------ Soft utils (null-safe) ------

  String? get _assigneeName {
    // Prefer nested assignee object, fall back to any legacy flat fields if present
    final byObj = t.assignee?.name.trim();
    if (byObj != null && byObj.isNotEmpty) return byObj;

    final legacy = (t as dynamic);
    try {
      final flat = (legacy.assigneeName ?? legacy.assignee ?? '') as String;
      return flat.trim().isEmpty ? null : flat.trim();
    } catch (_) {
      return null;
    }
  }

  String? get _updatedAgo {
    final dt = t.updatedAt;
    if (dt == null) return null;
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    if (d.inDays < 7) return '${d.inDays}d';
    return '${(d.inDays / 7).floor()}w';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, box) {
        final isCompact = box.maxWidth < 560;

        final leading = _LeadingBadge(number: t.number);
        final title = Text(
          t.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        );

        final metaChips = Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            StatusChip(t.status),
            PriorityChip(t.priority),
            if (_assigneeName != null)
              _InfoPill(
                icon: Icons.person_outline_rounded,
                label: _assigneeName!,
              ),
            if (_updatedAgo != null)
              _InfoPill(icon: Icons.schedule_rounded, label: _updatedAgo!),
          ],
        );

        final chevron = Icon(Icons.chevron_right_rounded, color: cs.outline);

        return Semantics(
          button: true,
          label: 'Ticket ${t.number}: ${t.title}',
          child: FocusableActionDetector(
            mouseCursor: SystemMouseCursors.click,
            child: Material(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Fx.rMd),
                side: BorderSide(color: cs.outlineVariant),
              ),
              elevation: 0,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(Fx.rMd),
                splashFactory: InkSparkle.splashFactory,
                child: Padding(
                  padding: const EdgeInsets.all(Fx.l),
                  child: isCompact
                      // ===== Compact (phones) =====
                      ? Row(
                          children: [
                            leading,
                            const SizedBox(width: Fx.l),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  title,
                                  const SizedBox(height: 8),
                                  metaChips,
                                ],
                              ),
                            ),
                            const SizedBox(width: Fx.m),
                            chevron,
                          ],
                        )
                      // ===== Wide (tablets/desktop) =====
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            leading,
                            const SizedBox(width: Fx.l),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  title,
                                  const SizedBox(height: 8),
                                  metaChips,
                                ],
                              ),
                            ),
                            const SizedBox(width: Fx.l),
                            // Right rail keeps a consistent height and a clear affordance
                            Align(
                              alignment: Alignment.topRight,
                              child: Tooltip(
                                message: 'Open ticket',
                                child: chevron,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/* ---------- Leading badge ---------- */
class _LeadingBadge extends StatelessWidget {
  final int number;
  const _LeadingBadge({required this.number});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        // Subtle diagonal sheen – feels more “premium”
        gradient: LinearGradient(
          colors: [cs.primaryContainer, cs.primaryContainer.withOpacity(.85)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: Text(
        number.toString(),
        maxLines: 1,
        overflow: TextOverflow.fade,
        softWrap: false,
        style: TextStyle(
          fontWeight: FontWeight.w900,
          letterSpacing: .2,
          color: cs.onPrimaryContainer,
        ),
      ),
    );
  }
}

/* ---------- Small info pill (assignee / time) ---------- */
class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: cs.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
