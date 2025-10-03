// ignore_for_file: unused_import

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';

final slaRepoProvider = Provider((_) => SlaRepository());

class SlaRepository {
  Future<List<Map<String, dynamic>>> list({int limit = 100}) async {
    final res = await api.dio.get(
      '/api/sla',
      queryParameters: {'limit': limit},
    );
    final data = res.data;
    final list = (data is Map && data['items'] is List)
        ? data['items']
        : (data is List ? data : []);
    return List<Map<String, dynamic>>.from(
      list.map((e) => Map<String, dynamic>.from(e)),
    );
  }

  Future<Map<String, dynamic>> create({
    required String name,
    required int firstResponseMins,
    required int resolutionMins,
  }) async {
    final res = await api.dio.post(
      '/api/sla',
      data: {
        'name': name,
        'firstResponseMins': firstResponseMins,
        'resolutionMins': resolutionMins,
      },
    );
    return Map<String, dynamic>.from(res.data);
  }
}
