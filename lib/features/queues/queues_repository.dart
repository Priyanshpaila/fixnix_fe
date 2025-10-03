// ignore_for_file: unused_import

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';

final queuesRepoProvider = Provider((_) => QueuesRepository());

class QueuesRepository {
  Future<List<Map<String, dynamic>>> list({int limit = 100}) async {
    final res = await api.dio.get('/api/queues', queryParameters: {'limit': limit});
    final data = res.data;
    final list = (data is Map && data['items'] is List) ? data['items'] : (data is List ? data : []);
    return List<Map<String, dynamic>>.from(list.map((e) => Map<String, dynamic>.from(e)));
  }

  Future<Map<String, dynamic>> create(String name) async {
    final res = await api.dio.post('/api/queues', data: {'name': name});
    return Map<String, dynamic>.from(res.data);
  }
}
