// lib/features/tickets/ticket_models.dart


class Assignee {
  final String id;
  final String name;
  final String email;

  const Assignee({required this.id, required this.name, required this.email});

  factory Assignee.fromJson(Map<String, dynamic> j) => Assignee(
        id: (j['id'] ?? j['_id'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        email: (j['email'] ?? '').toString(),
      );
}

class Ticket {
  final String id;
  final int number;
  final String title;
  final String description;
  final String status;
  final String priority;
  final String? requesterId;
  final String? queueId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? resolvedAt;
  final Map<String, dynamic>? sla;
  final Assignee? assignee;

  const Ticket({
    required this.id,
    required this.number,
    required this.title,
    required this.description,
    required this.status,
    required this.priority,
    required this.createdAt,
    required this.updatedAt,
    this.resolvedAt,
    this.requesterId,
    this.queueId,
    this.sla,
    this.assignee,
  });

  factory Ticket.fromJson(Map<String, dynamic> j) => Ticket(
        id: (j['id'] ?? j['_id'] ?? '').toString(),
        number: (j['number'] is int)
            ? j['number'] as int
            : int.tryParse('${j['number'] ?? 0}') ?? 0,
        title: (j['title'] ?? '').toString(),
        description: (j['description'] ?? '').toString(),
        status: (j['status'] ?? '').toString(),
        priority: (j['priority'] ?? '').toString(),
        requesterId: j['requesterId']?.toString(),
        queueId: j['queueId']?.toString(),
        createdAt: DateTime.tryParse('${j['createdAt'] ?? ''}') ?? DateTime.now(),
        updatedAt: DateTime.tryParse('${j['updatedAt'] ?? ''}') ?? DateTime.now(),
        resolvedAt: (j['resolvedAt'] != null)
            ? DateTime.tryParse('${j['resolvedAt']}') // may be null
            : null,
        sla: (j['sla'] is Map<String, dynamic>) ? j['sla'] as Map<String, dynamic> : null,
        assignee: (j['assignee'] is Map) ? Assignee.fromJson(Map<String, dynamic>.from(j['assignee'])) : null,
      );
}

// tiny helper for “x ago” text
String formatAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}
