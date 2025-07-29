class AuditLogRequest {
  final int page;
  final int limit;
  final int? userId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? lockerSerialNumber;

  const AuditLogRequest({
    this.page = 1,
    this.limit = 10,
    this.userId,
    this.dateFrom,
    this.dateTo,
    this.lockerSerialNumber,
  });

  Map<String, String> toQueryParameters() {
    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (userId != null) {
      params['userId'] = userId.toString();
    }

    if (dateFrom != null) {
      params['date_from'] = _formatDate(dateFrom!);
    }

    if (dateTo != null) {
      params['date_to'] = _formatDate(dateTo!);
    }

    if (lockerSerialNumber != null) {
      params['lockerSerialNumber'] = lockerSerialNumber!;
    }

    return params;
  }

  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
           '${date.month.toString().padLeft(2, '0')}-'
           '${date.day.toString().padLeft(2, '0')}';
  }

  AuditLogRequest copyWith({
    int? page,
    int? limit,
    int? userId,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? lockerSerialNumber,
  }) {
    return AuditLogRequest(
      page: page ?? this.page,
      limit: limit ?? this.limit,
      userId: userId ?? this.userId,
      dateFrom: dateFrom ?? this.dateFrom,
      dateTo: dateTo ?? this.dateTo,
      lockerSerialNumber: lockerSerialNumber ?? this.lockerSerialNumber,
    );
  }

  bool get hasFilters => userId != null || dateFrom != null || dateTo != null;

  @override
  String toString() => 'AuditLogRequest(page: $page, filters: $hasFilters)';
}