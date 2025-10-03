// lib/features/tickets/tickets_repository.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';

// --- Models ---------------------------------------------------------------

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
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? resolvedAt;
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
    priority: (j['priority'] ?? 'P3').toString(),
    createdAt: DateTime.tryParse('${j['createdAt'] ?? ''}') ?? DateTime.now(),
    updatedAt: DateTime.tryParse('${j['updatedAt'] ?? ''}') ?? DateTime.now(),
    resolvedAt: (j['resolvedAt'] != null)
        ? DateTime.tryParse('${j['resolvedAt']}')
        : null,
    assignee: (j['assignee'] is Map)
        ? Assignee.fromJson(Map<String, dynamic>.from(j['assignee']))
        : null,
  );
}

// --- Repository -----------------------------------------------------------

class TicketsRepository {
  final ApiClient _client;
  TicketsRepository(this._client);

  Future<List<Ticket>> list({
    String? q,
    String? status,
    String? assigneeId,
    int page = 1,
    int limit = 50,
    String sort = '-createdAt',
  }) async {
    final res = await _client.dio.get(
      '/api/tickets',
      queryParameters: {
        if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
        if (status != null && status.isNotEmpty) 'status': status,
        if (assigneeId != null && assigneeId.isNotEmpty)
          'assigneeId': assigneeId,
        'page': page,
        'limit': limit,
        'sort': sort,
      },
    );
    final items = (res.data['items'] as List? ?? []);
    return items
        .map((e) => Ticket.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Ticket> getById(String id) async {
    final res = await _client.dio.get('/api/tickets/$id');
    return Ticket.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<Ticket> createTicket(
    String title,
    String description, {
    String? queueId,
    String? slaPolicyId,
    String? assigneeId,
    String? priority,
  }) async {
    final res = await _client.dio.post(
      '/api/tickets',
      data: {
        'title': title,
        'description': description,
        if (queueId != null) 'queueId': queueId,
        if (slaPolicyId != null) 'slaPolicyId': slaPolicyId,
        if (assigneeId != null) 'assigneeId': assigneeId,
        if (priority != null) 'priority': priority,
      },
    );
    return Ticket.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<Ticket> assign(String ticketId, String? assigneeId) async {
    final res = await _client.dio.post(
      '/api/tickets/$ticketId/assign',
      data: {'assigneeId': assigneeId},
    );
    return Ticket.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<Ticket> updateStatus(String ticketId, String status) async {
    final res = await _client.dio.post(
      '/api/tickets/$ticketId/status',
      data: {'status': status},
    );
    return Ticket.fromJson(Map<String, dynamic>.from(res.data as Map));
  }
}

// --- Providers ------------------------------------------------------------

final ticketsRepoProvider = Provider<TicketsRepository>((ref) {
  return TicketsRepository(api);
});

final ticketsListProvider = FutureProvider<List<Ticket>>((ref) async {
  final repo = ref.read(ticketsRepoProvider);
  return repo.list();
});
