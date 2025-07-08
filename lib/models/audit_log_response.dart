import 'package:lockity_flutter/models/audit_log.dart';

class AuditLogResponse {
  final List<AuditLog> items;
  final int total;
  final int page;
  final int limit;
  final bool hasNextPage;
  final bool hasPreviousPage;

  const AuditLogResponse({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
    required this.hasNextPage,
    required this.hasPreviousPage,
  });

  factory AuditLogResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? {};
    final itemsList = data['items'] as List<dynamic>? ?? [];

    return AuditLogResponse(
      items: itemsList.map((item) => AuditLog.fromJson(item)).toList(),
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

    if (value is String) {
      return int.tryParse(value) ?? 0;
    }

    if (value is double) return value.toInt();

    return 0;
  }

  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;
  int get totalPages => (total / limit).ceil();
  bool get isFirstPage => page <= 1;
  bool get isLastPage => !hasNextPage;

  @override
  String toString() => 'AuditLogResponse(items: ${items.length}, total: $total)';
}