import 'package:flutter/material.dart';
import '../ui/tokens.dart';
import '../features/tickets/tickets_repository.dart';
import 'chips.dart';

class TicketCard extends StatelessWidget {
  final Ticket t;
  final VoidCallback? onTap;
  const TicketCard({super.key, required this.t, this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Fx.rMd),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(Fx.rMd),
          boxShadow: Fx.cardShadow(Colors.black),
        ),
        child: Padding(
          padding: const EdgeInsets.all(Fx.l),
          child: Row(
            children: [
              // Leading badge
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  t.number.toString(),
                  style: TextStyle(fontWeight: FontWeight.w800, color: scheme.onPrimaryContainer),
                ),
              ),
              const SizedBox(width: Fx.l),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        StatusChip(t.status),
                        const SizedBox(width: 6),
                        PriorityChip(t.priority),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Fx.m),
              Icon(Icons.chevron_right_rounded, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}
