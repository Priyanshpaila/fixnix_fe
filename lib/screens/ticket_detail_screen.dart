import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/tickets/tickets_repository.dart';
import '../widgets/chips.dart';
import '../ui/tokens.dart';

class TicketDetailScreen extends ConsumerWidget {
  final String ticketId;
  const TicketDetailScreen({super.key, required this.ticketId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(ticketsRepoProvider);

    return FutureBuilder(
      future: repo.getById(ticketId),
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snap.hasError || !snap.hasData) {
          return Scaffold(appBar: AppBar(), body: const Center(child: Text('Ticket not found')));
        }
        final t = snap.data!;

        return Scaffold(
          appBar: AppBar(),
          body: ListView(
            padding: const EdgeInsets.all(Fx.l),
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(Fx.l),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(Fx.rMd),
                  boxShadow: Fx.cardShadow(Colors.black),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('#${t.number}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 22)),
                    const SizedBox(height: 6),
                    Text(t.title, style: const TextStyle(fontSize: 18)),
                    const SizedBox(height: Fx.m),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      StatusChip(t.status),
                      PriorityChip(t.priority),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: Fx.l),

              // Placeholder sections you can wire later
              _Section(title: 'Activity', child: _EmptyHint(text: 'Activity timeline coming soon…')),
              const SizedBox(height: Fx.l),
              _Section(title: 'Comments', child: _EmptyHint(text: 'Comments UI coming soon…')),
            ],
          ),
          bottomNavigationBar: SafeArea(
            minimum: const EdgeInsets.all(Fx.l),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.timer_outlined),
                    onPressed: () {/* set waiting_customer via API */},
                    label: const Text('Wait Customer'),
                  ),
                ),
                const SizedBox(width: Fx.m),
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.check_circle),
                    onPressed: () {/* set resolved via API */},
                    label: const Text('Resolve'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Fx.l),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(Fx.rMd),
        boxShadow: Fx.cardShadow(Colors.black),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: Fx.m),
          child,
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint({required this.text});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(text, style: TextStyle(color: Theme.of(context).colorScheme.outline)),
      );
}
