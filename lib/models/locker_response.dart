import 'package:lockity_flutter/models/locker.dart';
import 'package:lockity_flutter/models/compartment.dart';

class LockerListResponse {
  final List<Locker> items;
  final int total;
  final int page;
  final int limit;
  final bool hasNextPage;
  final bool hasPreviousPage;

  const LockerListResponse({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
    required this.hasNextPage,
    required this.hasPreviousPage,
  });

  factory LockerListResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? {};
    final itemsList = data['items'] as List<dynamic>? ?? [];

    return LockerListResponse(
      items: itemsList.map((item) => Locker.fromJson(item)).toList(),
      total: _parseInt(data['total']),
      page: _parseInt(data['page']),
      limit: _parseInt(data['limit']),
      hasNextPage: data['has_next_page'] == true,
      hasPreviousPage: data['has_previous_page'] == true,
    );
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    if (value is double) return value.toInt();
    return 0;
  }

  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;
  int get totalPages => (total / limit).ceil();

  @override
  String toString() => 'LockerListResponse(items: ${items.length}, total: $total)';
}

class LockerOperationResponse {
  final bool success;
  final String message;

  const LockerOperationResponse({
    required this.success,
    required this.message,
  });

  factory LockerOperationResponse.fromJson(Map<String, dynamic> json) {
    return LockerOperationResponse(
      success: json['success'] == true,
      message: json['message']?.toString() ?? '',
    );
  }
}