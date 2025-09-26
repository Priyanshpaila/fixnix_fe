import 'package:dio/dio.dart';
import '../../core/api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class Ticket {
  final String id;
  final int number;
  final String title;
  final String status;
  final String priority;

  Ticket({required this.id, required this.number, required this.title, required this.status, required this.priority});

  factory Ticket.fromJson(Map<String, dynamic> j) => Ticket(
    id: j['_id'] as String,
    number: (j['number'] as num?)?.toInt() ?? 0,
    title: j['title'] as String? ?? '',
    status: j['status'] as String? ?? '',
    priority: j['priority'] as String? ?? 'P3',
  );
}

class TicketsRepository {
  Future<List<Ticket>> list({String q = ''}) async {
    final res = await api.dio.get('/api/tickets', queryParameters: q.isEmpty ? null : {'q': q});
    final items = (res.data['items'] as List?) ?? [];
    return items.map((e) => Ticket.fromJson((e as Map).cast<String, dynamic>())).toList();
  }

  Future<Ticket> getById(String id) async {
    final res = await api.dio.get('/api/tickets', queryParameters: {'_id': id, 'limit': 1});
    final items = (res.data['items'] as List?) ?? [];
    if (items.isEmpty) throw DioException(requestOptions: RequestOptions(), error: 'Not found');
    return Ticket.fromJson((items.first as Map).cast<String, dynamic>());
  }

  Future<void> createTicket(String title, String description, {String? queueId, String? slaPolicyId}) async {
    await api.dio.post('/api/tickets', data: {
      'title': title,
      'description': description,
      if (queueId != null) 'queueId': queueId,
      if (slaPolicyId != null) 'slaPolicyId': slaPolicyId,
    });
  }
}

final ticketsRepoProvider = Provider((_) => TicketsRepository());
final ticketsListProvider = FutureProvider<List<Ticket>>((ref) async {
  return ref.read(ticketsRepoProvider).list();
});
